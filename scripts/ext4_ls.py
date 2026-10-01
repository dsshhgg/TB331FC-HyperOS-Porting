#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
用途  : 纯 Python 只读解析 EXT4 镜像（ZUI 底包 super 逻辑分区即 EXT4），
        支持递归列目录 / 导出文件 / 汇总 HAL 清单。用于《vendor 合并补丁清单》取证。
时间  : 2026-10 移植可行性评估
依赖  : Python 3 标准库（无 e2fsprogs / WSL 依赖）
用法  :
  python ext4_ls.py <img>                      # 递归列出 / （含大小）
  python ext4_ls.py <img> --path /lib64/hw     # 只列某目录
  python ext4_ls.py <img> --out list.txt       # 结果写文件
  python ext4_ls.py <img> --extract /etc/build.prop --dest out.prop
  python ext4_ls.py <img> --info               # 只打印超级块信息
说明  : 本脚本只读取镜像，不写入镜像；--extract 的落盘目标是用户指定路径。
"""

from __future__ import annotations

import argparse
import os
import struct
import sys

EXT4_SUPER_MAGIC = 0xEF53
EXT4_EXT_MAGIC = 0xF30A
S_IFMT = 0o170000
S_IFDIR = 0o040000
S_IFREG = 0o100000
S_IFLNK = 0o120000

INCOMPAT_64BIT = 0x80
INCOMPAT_EXTENTS = 0x40
RO_COMPAT_HUGE_FILE = 0x8


class Ext4Error(Exception):
    pass


class Ext4:
    def __init__(self, path):
        self.path = path
        self.fh = open(path, "rb")
        self._read_super()

    # ---------- 基础 ----------
    def close(self):
        self.fh.close()

    def _read_at(self, off, size):
        if off < 0:
            raise Ext4Error("negative offset")
        self.fh.seek(off)
        data = self.fh.read(size)
        if len(data) != size:
            # 允许末尾不足（镜像截断）时返回已有数据
            return data
        return data

    def _read_super(self):
        sb = self._read_at(1024, 1024)
        if len(sb) < 264:
            raise Ext4Error("superblock too small")
        # 逐字段解包（显式偏移，避免长格式串错位）
        self.inodes_count = struct.unpack_from("<I", sb, 0)[0]
        self.blocks_count_lo = struct.unpack_from("<I", sb, 4)[0]
        self.free_blocks_lo = struct.unpack_from("<I", sb, 12)[0]
        self.free_inodes = struct.unpack_from("<I", sb, 16)[0]
        self.first_data_block = struct.unpack_from("<I", sb, 20)[0]
        log_block_size = struct.unpack_from("<I", sb, 24)[0]
        self.blocks_per_group = struct.unpack_from("<I", sb, 32)[0]
        self.inodes_per_group = struct.unpack_from("<I", sb, 40)[0]
        self.mnt_count = struct.unpack_from("<H", sb, 52)[0]
        self.max_mnt_count = struct.unpack_from("<H", sb, 54)[0]
        self.magic = struct.unpack_from("<H", sb, 56)[0]
        self.state = struct.unpack_from("<H", sb, 58)[0]
        self.errors = struct.unpack_from("<H", sb, 60)[0]
        self.minor_rev = struct.unpack_from("<H", sb, 62)[0]
        self.lastcheck = struct.unpack_from("<I", sb, 64)[0]
        self.creator_os = struct.unpack_from("<I", sb, 72)[0]
        self.rev_level = struct.unpack_from("<I", sb, 76)[0]
        self.first_ino = struct.unpack_from("<I", sb, 84)[0]
        self.inode_size = struct.unpack_from("<H", sb, 88)[0]
        self.block_group_nr = struct.unpack_from("<H", sb, 90)[0]
        if self.magic != EXT4_SUPER_MAGIC:
            raise Ext4Error("bad ext4 magic 0x%04X" % self.magic)
        self.block_size = 1024 << log_block_size
        self.feature_compat, self.feature_incompat, self.feature_ro_compat = \
            struct.unpack_from("<III", sb, 92)
        self.uuid = sb[104:120].hex()
        self.volume_name = sb[120:136].split(b"\x00")[0].decode("utf-8", "replace")
        self.last_mounted = sb[136:200].split(b"\x00")[0].decode("utf-8", "replace")
        if self.inode_size == 0:
            self.inode_size = 128
        self.desc_size = 32
        if self.feature_incompat & INCOMPAT_64BIT:
            self.desc_size = struct.unpack_from("<H", sb, 254)[0] or 64
            self.blocks_count = self.blocks_count_lo | (struct.unpack_from("<I", sb, 336)[0] << 32)
        else:
            self.blocks_count = self.blocks_count_lo
        self.groups = (self.blocks_count - self.first_data_block + self.blocks_per_group - 1) // self.blocks_per_group
        self._gdt_off = (self.first_data_block + 1) * self.block_size

    def _group_desc(self, g):
        off = self._gdt_off + g * self.desc_size
        d = self._read_at(off, self.desc_size)
        inode_table_lo, = struct.unpack_from("<I", d, 8)
        inode_table = inode_table_lo
        if self.desc_size >= 64:
            hi, = struct.unpack_from("<I", d, 40)
            inode_table |= hi << 32
        return inode_table

    def inode(self, ino):
        if ino < 1 or ino > self.inodes_count:
            raise Ext4Error("inode %d out of range" % ino)
        g = (ino - 1) // self.inodes_per_group
        idx = (ino - 1) % self.inodes_per_group
        off = self._group_desc(g) * self.block_size + idx * self.inode_size
        raw = self._read_at(off, self.inode_size)
        if len(raw) < 128:
            raise Ext4Error("short inode %d" % ino)
        mode, uid, size_lo, _a, _c, _m, _d, gid, links, blocks_lo, flags = \
            struct.unpack_from("<HHIIIIIHHII", raw, 0)
        i_block = raw[40:100]
        size_high, = struct.unpack_from("<I", raw, 108) if len(raw) >= 112 else (0,)
        size = size_lo
        # 普通文件在启用 LARGE_FILE 时以 i_size_high 作为高 32 位；其它类型仅用 lo
        if (mode & S_IFMT) == S_IFREG and (self.feature_ro_compat & 0x2):
            size |= size_high << 32
        return {
            "ino": ino, "mode": mode, "uid": uid, "gid": gid, "size": size,
            "links": links, "blocks": blocks_lo, "flags": flags, "i_block": i_block,
        }

    # ---------- 数据块映射 ----------
    def _extent_map(self, node, out, depth):
        if depth > 5:
            raise Ext4Error("extent depth too large")
        magic, entries, _max, d = struct.unpack_from("<HHHH", node, 0)
        if magic != EXT4_EXT_MAGIC:
            raise Ext4Error("bad extent magic 0x%04X" % magic)
        for i in range(entries):
            off = 12 + i * 12
            if d == 0:
                ee_block, ee_len, ee_start_hi, ee_start_lo = struct.unpack_from("<IHHI", node, off)
                if ee_len > 32768:      # 未初始化 extent
                    ee_len -= 32768
                out.append((ee_block, ee_len, (ee_start_hi << 32) | ee_start_lo))
            else:
                ei_block, ei_leaf_lo, ei_leaf_hi, _u = struct.unpack_from("<IIHH", node, off)
                leaf = self._read_at(((ei_leaf_hi << 32) | ei_leaf_lo) * self.block_size, self.block_size)
                self._extent_map(leaf, out, d + 1)

    def block_map(self, inode):
        """返回 [(logical_block, length, physical_block)]；非 extent 文件返回 None。"""
        ib = inode["i_block"]
        if self.feature_incompat & INCOMPAT_EXTENTS:
            out = []
            self._extent_map(ib, out, struct.unpack_from("<H", ib, 6)[0])
            return out
        return None

    def read_file(self, inode):
        size = inode["size"]
        if size == 0:
            return b""
        out = bytearray()
        emap = self.block_map(inode)
        if emap is not None:
            for lblock, length, pblock in sorted(emap):
                if lblock * self.block_size >= size:
                    break
                n = min(length * self.block_size, size - lblock * self.block_size)
                out += self._read_at(pblock * self.block_size, n)
            return bytes(out[:size])
        # 间接块（老式）：仅处理 i_block[0..11] 直接块 + 单级间接
        for i in range(12):
            p, = struct.unpack_from("<I", inode["i_block"], i * 4)
            if p == 0:
                break
            out += self._read_at(p * self.block_size, self.block_size)
        if len(out) < size:
            p, = struct.unpack_from("<I", inode["i_block"], 48)
            if p:
                ptrs = self._read_at(p * self.block_size, self.block_size)
                for i in range(self.block_size // 4):
                    q, = struct.unpack_from("<I", ptrs, i * 4)
                    if q == 0:
                        break
                    out += self._read_at(q * self.block_size, self.block_size)
                    if len(out) >= size:
                        break
        return bytes(out[:size])

    # ---------- 目录 ----------
    def list_dir(self, ino):
        inode = self.inode(ino)
        if inode["mode"] & S_IFMT != S_IFDIR:
            raise Ext4Error("inode %d is not a directory" % ino)
        data = self.read_file(inode)
        entries = []
        pos = 0
        while pos + 8 <= len(data):
            e_ino, rec_len, name_len, file_type = struct.unpack_from("<IHBB", data, pos)
            if rec_len < 8 or pos + rec_len > len(data):
                break
            if e_ino != 0 and name_len > 0:
                name = data[pos + 8:pos + 8 + name_len].decode("utf-8", "replace")
                if name not in (".", ".."):
                    entries.append((e_ino, name, file_type))
            pos += rec_len
        return entries

    def resolve(self, path):
        ino = 2  # root
        for part in [p for p in path.split("/") if p]:
            found = None
            for e_ino, name, _t in self.list_dir(ino):
                if name == part:
                    found = e_ino
                    break
            if found is None:
                raise Ext4Error("not found: %s" % path)
            ino = found
        return ino

    def walk(self, ino=2, prefix="", out=None, max_entries=2_000_000):
        if out is None:
            out = []
        for e_ino, name, ftype in self.list_dir(ino):
            path = prefix + "/" + name
            if ftype == 2:  # directory
                out.append((path + "/", 0, "dir", e_ino))
                self.walk(e_ino, path, out, max_entries)
            else:
                try:
                    i = self.inode(e_ino)
                    kind = {1: "file", 7: "link", 3: "chr", 4: "blk", 5: "fifo", 6: "sock"}.get(ftype, "?")
                    out.append((path, i["size"], kind, e_ino))
                except Ext4Error:
                    out.append((path, 0, "err", e_ino))
            if len(out) > max_entries:
                raise Ext4Error("too many entries, aborting")
        return out


def human(n):
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return "%.2f %s" % (n, unit)
        n /= 1024.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--path", default="/")
    ap.add_argument("--out")
    ap.add_argument("--extract")
    ap.add_argument("--dest")
    ap.add_argument("--info", action="store_true")
    ap.add_argument("--no-recurse", action="store_true")
    args = ap.parse_args()

    fs = Ext4(args.image)
    try:
        print("image      : %s (%d bytes)" % (args.image, os.path.getsize(args.image)), file=sys.stderr)
        print("block_size : %d  inode_size: %d  desc_size: %d" % (
            fs.block_size, fs.inode_size, fs.desc_size), file=sys.stderr)
        print("volume     : %r  last_mounted: %r" % (fs.volume_name, fs.last_mounted), file=sys.stderr)
        print("blocks     : %d (%.2f GiB)  groups: %d  inodes: %d" % (
            fs.blocks_count, fs.blocks_count * fs.block_size / 1024**3, fs.groups, fs.inodes_count), file=sys.stderr)
        feat = []
        if fs.feature_incompat & INCOMPAT_EXTENTS:
            feat.append("extents")
        if fs.feature_incompat & INCOMPAT_64BIT:
            feat.append("64bit")
        print("features   : incompat=0x%08X ro_compat=0x%08X [%s]" % (
            fs.feature_incompat, fs.feature_ro_compat, ",".join(feat)), file=sys.stderr)
        if args.info:
            return 0

        if args.extract:
            ino = fs.resolve(args.extract)
            data = fs.read_file(fs.inode(ino))
            dest = args.dest or os.path.basename(args.extract)
            with open(dest, "wb") as fh:
                fh.write(data)
            print("[extracted] %s -> %s (%d bytes)" % (args.extract, dest, len(data)), file=sys.stderr)
            return 0

        if args.no_recurse:
            ino = fs.resolve(args.path)
            rows = [(args.path.rstrip("/") + "/" + n, fs.inode(i)["size"] if t != 2 else 0,
                     "dir" if t == 2 else "file", i) for i, n, t in fs.list_dir(ino)]
        else:
            ino = fs.resolve(args.path)
            rows = fs.walk(ino, args.path.rstrip("/"))

        lines = []
        for path, size, kind, ino_ in sorted(rows):
            lines.append("%12d\t%s\t%s" % (size, kind, path))
        text = "\n".join(lines)
        if args.out:
            with open(args.out, "w", encoding="utf-8") as fh:
                fh.write(text + "\n")
            print("[written] %s (%d entries)" % (args.out, len(rows)), file=sys.stderr)
        else:
            print(text)
        return 0
    finally:
        fs.close()


if __name__ == "__main__":
    sys.exit(main())
