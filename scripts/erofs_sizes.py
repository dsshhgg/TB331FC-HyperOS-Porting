#!/usr/bin/env python3
# erofs_sizes.py
# 用途：解析 EROFS 镜像，递归统计目录/文件体积，输出 debloat 用 CSV
# 时间：2026-09-29
# 依赖：Python 3 标准库
# 用法：python scripts/erofs_sizes.py --image product.img --csv product_sizes.csv

from __future__ import annotations

import argparse
import csv
import struct
import sys
from pathlib import Path

# EROFS on-disk (little-endian)
# Superblock @ 1024
#   magic u32 0xE0F5E1E2, checksum, feature_compat, blkszbits u8, ...
# Inode (32 bytes base) + optional xattr
#   i_format u16, i_xattr_icount u16, i_mode u16, i_nlink u16,
#   i_size u32, i_reserved u32, i_u (union), i_ino u32, i_uid u16, i_gid u16, i_reserved2 u32

EROFS_MAGIC = 0xE0F5E1E2
EROFS_INODE_FLAT_PLAIN = 0
EROFS_INODE_FLAT_COMPRESSION_LEGACY = 1
EROFS_INODE_FLAT_INLINE = 2
EROFS_INODE_FLAT_COMPRESSION = 3
EROFS_INODE_CHUNK_BASED = 4
EROFS_INODE_FLAT_COMPRESSION_FULL = 5

DIRENT_SIZE = 12  # typically: nid u64, nameoff u16, file_type u8, reserved u8


def read_super(data: bytes) -> dict:
    sb = data[1024:1024 + 128]
    magic, checksum, feature_compat = struct.unpack_from("<III", sb, 0)
    if magic != EROFS_MAGIC:
        raise SystemExit(f"not EROFS: magic={magic:#x}")
    blkszbits = sb[12]
    # see erofs_fs.h: after blkszbits: sb_extslots, root_nid u16, inos u64, ...
    # offsets vary slightly by version; use common layout:
    # 0 magic, 4 checksum, 8 feature_compat, 12 blkszbits, 13 sb_extslots,
    # 14 root_nid u16, 16 inos u64, 24 build_time u64, 32 build_time_nsec u32,
    # 36 blocks u32, 40 meta_blkaddr u32, 44 xattr_blkaddr u32
    root_nid = struct.unpack_from("<H", sb, 14)[0]
    inos = struct.unpack_from("<Q", sb, 16)[0]
    blocks = struct.unpack_from("<I", sb, 36)[0]
    meta_blkaddr = struct.unpack_from("<I", sb, 40)[0]
    return {
        "blkszbits": blkszbits,
        "blksz": 1 << blkszbits,
        "root_nid": root_nid,
        "inos": inos,
        "blocks": blocks,
        "meta_blkaddr": meta_blkaddr,
    }


def nid_to_off(nid: int, meta_blkaddr: int, blksz: int) -> int:
    return meta_blkaddr * blksz + nid * 32


def parse_inode(data: bytes, off: int, blksz: int) -> dict:
    fmt, xattr_icount, mode, nlink = struct.unpack_from("<HHHH", data, off)
    isize = struct.unpack_from("<I", data, off + 8)[0]
    raw_blkaddr = struct.unpack_from("<I", data, off + 16)[0]
    ino = struct.unpack_from("<I", data, off + 24)[0]
    inode_layout = fmt & 0x07
    # i_size for inline/compressed may be in different field; use isize for plain
    return {
        "format": fmt,
        "layout": inode_layout,
        "mode": mode,
        "nlink": nlink,
        "size": isize,
        "raw_blkaddr": raw_blkaddr,
        "ino": ino,
        "xattr_icount": xattr_icount,
        "off": off,
    }


def dir_entries(data: bytes, inode: dict, blksz: int) -> list[tuple[int, str, int]]:
    """Return list of (nid, name, file_type)."""
    layout = inode["layout"]
    size = inode["size"]
    nameoff = None
    entries = []
    # Inline directory: data at end of inode block after inode+xattr
    # Simplified: read `size` bytes of dirent table starting after inode
    xattr_len = inode["xattr_icount"] * 4 if inode["xattr_icount"] else 0
    # Actually i_xattr_icount is in 4-byte units of xattr_ibody
    inode_size = 32
    # For EROFS_INODE_FLAT_INLINE, dir data is in the last block of the inode
    # For EROFS_INODE_FLAT_PLAIN, dir data is at raw_blkaddr
    if layout == EROFS_INODE_FLAT_INLINE:
        # directory data follows inode+xattr in the same block
        start = inode["off"] + inode_size + xattr_len
        # but typically packed at end of block: nameoff table first
        # Standard: first 12 bytes of dirent area is nameoff list...
        # Simpler approach used by many tools: the inline dir size is `i_size`
        # and data starts at `inode_off + inode_size + xattr` rounded?
        # Official: for inline, `i_size` is dir size; data lives in the block
        # after inode structure.
        raw = data[start:start + size]
    elif layout == EROFS_INODE_FLAT_PLAIN:
        start = inode["raw_blkaddr"] * blksz
        raw = data[start:start + size]
    else:
        return entries

    if len(raw) < DIRENT_SIZE:
        return entries

    # nameoff: first u16 of first dirent is name offset of first name,
    # names follow the nameoff table. Common format:
    # dirent[i] = nid u64, nameoff u16, file_type u8, reserved u8
    # names from nameoff[0] to end
    ndirent = 0
    # parse sequentially: read nameoff from first entry
    first_nameoff = struct.unpack_from("<H", raw, 8)[0]
    if first_nameoff < DIRENT_SIZE or first_nameoff > len(raw):
        return entries
    # number of dirents = first_nameoff / 12
    ndirent = first_nameoff // DIRENT_SIZE
    names_blob = raw[first_nameoff:]
    for i in range(ndirent):
        base = i * DIRENT_SIZE
        if base + DIRENT_SIZE > len(raw):
            break
        nid = struct.unpack_from("<Q", raw, base)[0]
        noff = struct.unpack_from("<H", raw, base + 8)[0]
        ftype = raw[base + 10]
        # name from names_blob relative to first_nameoff
        rel = noff - first_nameoff
        if rel < 0 or rel >= len(names_blob):
            continue
        end = names_blob.find(b"\x00", rel)
        if end < 0:
            end = len(names_blob)
        name = names_blob[rel:end].decode("utf-8", "replace")
        if name in (".", ".."):
            continue
        entries.append((nid, name, ftype))
    return entries


def walk(data: bytes, nid: int, meta_blkaddr: int, blksz: int, path: str, rows: list, depth=0):
    if depth > 24:
        return
    off = nid_to_off(nid, meta_blkaddr, blksz)
    if off + 32 > len(data):
        return
    inode = parse_inode(data, off, blksz)
    is_dir = (inode["mode"] & 0o170000) == 0o040000
    rows.append({
        "path": path or "/",
        "size": inode["size"],
        "mode": oct(inode["mode"]),
        "type": "dir" if is_dir else "file",
        "nid": nid,
    })
    if is_dir:
        for cnid, name, ftype in dir_entries(data, inode, blksz):
            child = (path + "/" + name) if path else "/" + name
            walk(data, cnid, meta_blkaddr, blksz, child, rows, depth + 1)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", required=True)
    ap.add_argument("--csv", default="erofs_sizes.csv")
    args = ap.parse_args()

    data = Path(args.image).read_bytes()
    sb = read_super(data)
    print(f"blksz={sb['blksz']} root_nid={sb['root_nid']} inos={sb['inos']} blocks={sb['blocks']}", file=sys.stderr)

    rows: list[dict] = []
    walk(data, sb["root_nid"], sb["meta_blkaddr"], sb["blksz"], "", rows)

    with open(args.csv, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["path", "size", "type", "mode", "nid"])
        w.writeheader()
        w.writerows(rows)

    # summary by top-level
    from collections import defaultdict
    agg = defaultdict(int)
    for r in rows:
        parts = r["path"].strip("/").split("/")
        key = "/" + parts[0] if parts[0] else "/"
        if r["type"] == "file":
            agg[key] += r["size"]
    print("=== top-level file bytes ===")
    total = 0
    for k, v in sorted(agg.items(), key=lambda x: -x[1]):
        total += v
        print(f"{k:30} {v/1024/1024:10.2f} MB")
    print(f"{'TOTAL':30} {total/1024/1024:10.2f} MB  rows={len(rows)}")


if __name__ == "__main__":
    main()
