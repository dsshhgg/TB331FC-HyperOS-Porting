#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
用途  : 解析 Android 动态分区（super）的 liblp 元数据，输出逻辑分区清单与大小。
        用于 TB331FC(ZUI) 底包 super 结构取证 —— 纯只读，不做任何写入/解包。
时间  : 2026-10 移植可行性评估
依赖  : 仅 Python 3 标准库
用法  : python parse_super_lp.py <super_empty.img | super_1.img ...>
        例：python parse_super_lp.py "E:\\类\\刷机\\联想\\TB331FC\\刷机包\\TB331FC_ZUI_16.0.544\\image\\super_empty.img"

说明  : 优先解析 super_empty.img（lpmake 产出的纯元数据，非 sparse）。
        若传入的是 Android sparse 镜像，先按 sparse 格式还原头部再解析。
        参考 liblp/include/liblp/metadata_format.h
"""

import struct
import sys
import os

LP_PARTITION_RESERVED_BYTES = 4096
LP_METADATA_GEOMETRY_MAGIC = 0x616C4467
LP_METADATA_GEOMETRY_SIZE = 4096
LP_METADATA_HEADER_MAGIC = 0x414C5030
SPARSE_MAGIC = 0xED26FF3A


def read_exact(f, n):
    b = f.read(n)
    if len(b) != n:
        raise EOFError("short read: want %d got %d" % (n, len(b)))
    return b


def detect_sparse(path):
    with open(path, "rb") as f:
        head = f.read(4)
    if len(head) < 4:
        return False
    return struct.unpack("<I", head)[0] == SPARSE_MAGIC


def unsparse_prefix(path, need_bytes):
    """把 sparse 镜像还原出前 need_bytes 字节（足够容纳 geometry+metadata）。"""
    out = bytearray()
    with open(path, "rb") as f:
        magic, major, minor, file_hdr_sz, chunk_hdr_sz, blk_sz, total_blks, total_chunks, _csum = \
            struct.unpack("<IHHHHIIII", read_exact(f, 28))
        f.seek(file_hdr_sz)
        for _ in range(total_chunks):
            chunk_type, _res, chunk_sz, total_sz = struct.unpack("<HHII", read_exact(f, 12))
            body = chunk_sz * blk_sz
            payload = total_sz - chunk_hdr_sz
            if chunk_type == 0xCAC1:      # raw
                out += read_exact(f, payload)
            elif chunk_type == 0xCAC2:    # fill
                fill = read_exact(f, 4)
                out += fill * (body // 4)
                if payload > 4:
                    f.seek(payload - 4, os.SEEK_CUR)
            elif chunk_type == 0xCAC3:    # don't care
                out += b"\x00" * body
                if payload:
                    f.seek(payload, os.SEEK_CUR)
            elif chunk_type == 0xCAC4:    # crc32
                f.seek(payload, os.SEEK_CUR)
            else:
                raise ValueError("unknown sparse chunk type 0x%X" % chunk_type)
            if len(out) >= need_bytes:
                break
    return bytes(out[:need_bytes])


def find_geometry_offset(buf):
    """geometry 在真实 super 内位于 4096；在 lpmake 单独产出的 super_empty.img 内位于 0。"""
    for off in (0, LP_PARTITION_RESERVED_BYTES):
        if len(buf) >= off + 4:
            magic, = struct.unpack_from("<I", buf, off)
            if magic == LP_METADATA_GEOMETRY_MAGIC:
                return off
    raise ValueError("no LP geometry magic at 0 or %d" % LP_PARTITION_RESERVED_BYTES)


def parse_geometry(buf, off):
    if len(buf) < off + 52:
        raise ValueError("buffer too small for geometry")
    magic, struct_size, checksum, metadata_max_size, slot_count, logical_block_size = \
        struct.unpack_from("<II32sIII", buf, off)
    if magic != LP_METADATA_GEOMETRY_MAGIC:
        raise ValueError("bad geometry magic 0x%08X" % magic)
    return {
        "offset": off,
        "struct_size": struct_size,
        "metadata_max_size": metadata_max_size,
        "metadata_slot_count": slot_count,
        "logical_block_size": logical_block_size,
        "checksum": checksum.hex(),
    }


def parse_header(buf, off):
    magic, major, minor, header_size = struct.unpack_from("<IHHI", buf, off)
    if magic != LP_METADATA_HEADER_MAGIC:
        raise ValueError("bad metadata header magic 0x%08X at %d" % (magic, off))
    header_checksum = buf[off + 12:off + 44]
    tables_size, = struct.unpack_from("<I", buf, off + 44)
    tables_checksum = buf[off + 48:off + 80]
    tables_off = off + header_size
    descs = {}
    for i, name in enumerate(("partitions", "extents", "groups", "block_devices")):
        o, n, es = struct.unpack_from("<III", buf, off + 80 + i * 12)
        descs[name] = {"offset": o, "num_entries": n, "entry_size": es}
    return {
        "major": major, "minor": minor, "header_size": header_size,
        "tables_size": tables_size, "tables_offset": tables_off,
        "header_checksum": header_checksum.hex(), "tables_checksum": tables_checksum.hex(),
        "descriptors": descs,
    }


def parse_tables(buf, hdr):
    base = hdr["tables_offset"]
    d = hdr["descriptors"]
    tables = {}

    def entries(kind):
        desc = d[kind]
        out = []
        for i in range(desc["num_entries"]):
            off = base + desc["offset"] + i * desc["entry_size"]
            out.append(buf[off:off + desc["entry_size"]])
        return out

    parts = []
    for e in entries("partitions"):
        name = e[0:36].split(b"\x00")[0].decode("utf-8", "replace")
        attributes, first_extent_index, num_extents, group_index = struct.unpack_from("<IIII", e, 36)
        parts.append({
            "name": name, "attributes": attributes,
            "first_extent_index": first_extent_index, "num_extents": num_extents,
            "group_index": group_index, "raw": e,
        })

    extents = []
    for e in entries("extents"):
        num_sectors, = struct.unpack_from("<Q", e, 0)
        target_type, = struct.unpack_from("<I", e, 8)
        # 旧版 target_data 为 u32，新版为 u64；按 entry_size 判定
        if len(e) >= 24:
            target_data, = struct.unpack_from("<Q", e, 12)
            target_source, = struct.unpack_from("<I", e, 20)
        else:
            target_data, = struct.unpack_from("<I", e, 12)
            target_source, = struct.unpack_from("<I", e, 16)
        extents.append({"num_sectors": num_sectors, "target_type": target_type,
                        "target_data": target_data, "target_source": target_source})

    groups = []
    for e in entries("groups"):
        name = e[0:36].split(b"\x00")[0].decode("utf-8", "replace")
        flags, = struct.unpack_from("<I", e, 36)
        maximum_size, = struct.unpack_from("<Q", e, 40)
        groups.append({"name": name, "flags": flags, "maximum_size": maximum_size})

    bdevs = []
    for e in entries("block_devices"):
        first_logical_sector, = struct.unpack_from("<Q", e, 0)
        alignment, alignment_offset = struct.unpack_from("<II", e, 8)
        size, = struct.unpack_from("<Q", e, 16)
        partition_name = e[24:60].split(b"\x00")[0].decode("utf-8", "replace")
        flags, = struct.unpack_from("<I", e, 60)
        bdevs.append({"first_logical_sector": first_logical_sector,
                      "alignment": alignment, "alignment_offset": alignment_offset,
                      "size": size, "partition_name": partition_name, "flags": flags})

    tables["partitions"] = parts
    tables["extents"] = extents
    tables["groups"] = groups
    tables["block_devices"] = bdevs
    return tables


def human(n):
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if n < 1024 or unit == "TiB":
            return "%.2f %s" % (n, unit)
        n /= 1024.0


def find_header_offset(buf, start, scan=512 * 1024):
    """在 geometry 之后扫描有效的 metadata header（lpmake 的槽位排布随版本变化，
    这里以「magic + 主版本号 + 表描述符可解析」为准，避免硬编码偏移）。"""
    limit = min(len(buf), start + scan)
    off = start
    while off + 256 <= limit:
        try:
            hdr = parse_header(buf, off)
        except Exception:  # noqa: BLE001
            off += 4096
            continue
        if hdr["major"] != 10 or hdr["header_size"] < 80 or hdr["tables_size"] == 0:
            off += 4096
            continue
        try:
            tables = parse_tables(buf, hdr)
        except Exception:  # noqa: BLE001
            off += 4096
            continue
        if tables["partitions"] and tables["extents"]:
            return off, hdr, tables
        off += 4096
    raise ValueError("no valid LP metadata header found after %d" % start)


def report(path):
    print("=" * 78)
    print("文件: %s" % path)
    sparse = detect_sparse(path)
    print("格式: %s" % ("Android sparse" if sparse else "raw"))

    probe = LP_PARTITION_RESERVED_BYTES + LP_METADATA_GEOMETRY_SIZE
    buf = unsparse_prefix(path, probe) if sparse else open(path, "rb").read(probe)
    geo_off = find_geometry_offset(buf)
    geo = parse_geometry(buf, geo_off)
    print("geometry @ %d: metadata_max_size=%d slot_count=%d logical_block_size=%d" % (
        geo_off, geo["metadata_max_size"], geo["metadata_slot_count"], geo["logical_block_size"]))

    hdr_off = geo_off + LP_METADATA_GEOMETRY_SIZE
    need = hdr_off + geo["metadata_max_size"] * 8
    buf = unsparse_prefix(path, need) if sparse else open(path, "rb").read(need)

    hdr_off, hdr, tables = find_header_offset(buf, hdr_off)
    print("header   @ %d: v%d.%d header_size=%d tables_size=%d" % (
        hdr_off, hdr["major"], hdr["minor"], hdr["header_size"], hdr["tables_size"]))

    print("\n-- block_devices --")
    for b in tables["block_devices"]:
        print("  %-20s size=%-14s first_logical_sector=%d alignment=%d" % (
            b["partition_name"] or "(unnamed)", human(b["size"]), b["first_logical_sector"], b["alignment"]))

    print("\n-- groups --")
    for g in tables["groups"]:
        print("  %-20s flags=0x%X maximum_size=%s" % (g["name"], g["flags"], human(g["maximum_size"])))

    print("\n-- partitions --")
    print("  %-22s %14s %14s  %s" % ("name", "sectors", "size", "group"))
    total = 0
    rows = []
    for p in tables["partitions"]:
        sectors = 0
        for i in range(p["num_extents"]):
            e = tables["extents"][p["first_extent_index"] + i]
            sectors += e["num_sectors"]
        size = sectors * 512
        total += size
        grp = tables["groups"][p["group_index"]]["name"] if p["group_index"] < len(tables["groups"]) else "?"
        rows.append((p["name"], sectors, size, grp))
    for name, sectors, size, grp in sorted(rows, key=lambda r: -r[2]):
        print("  %-22s %14d %14s  %s" % (name, sectors, human(size), grp))
    print("  %-22s %14s %14s" % ("TOTAL", "", human(total)))

    print("\n-- extents (super 内字节偏移) --")
    for p in tables["partitions"]:
        if p["num_extents"] == 0:
            continue
        cursor = 0
        print("  %s:" % p["name"])
        for i in range(p["num_extents"]):
            e = tables["extents"][p["first_extent_index"] + i]
            nbytes = e["num_sectors"] * 512
            kind = {0: "linear", 1: "zero"}.get(e["target_type"], "type%d" % e["target_type"])
            print("      [%d] %-6s offset=%-14d size=%-14d src=%d" % (
                i, kind, e["target_data"] * 512, nbytes, e["target_source"]))
            cursor += nbytes
    return rows


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    for p in args:
        if not os.path.isfile(p):
            print("!! 不存在: %s" % p)
            continue
        try:
            report(p)
        except Exception as exc:  # noqa: BLE001
            print("!! 解析失败 %s: %s" % (p, exc))
    return 0


if __name__ == "__main__":
    sys.exit(main())
