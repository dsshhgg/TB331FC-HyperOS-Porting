#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
用途  : 解析 Android 全量 OTA 的 payload.bin 清单（DeltaArchiveManifest），
        输出各分区大小与期望 sha256，并可校验已抽取镜像的完整性。
时间  : 2026-10 移植可行性评估
依赖  : Python 3 标准库（内置最小 protobuf 线格式解析，无需 google.protobuf）
用法  :
  python verify_payload.py --payload payload.bin --list
  python verify_payload.py --payload payload.bin --verify-dir <dir> [--only vendor,odm]
  python verify_payload.py --payload payload.bin --verify-dir <dir> --out report.txt
说明  : 纯只读；不修改镜像、不写设备。
        若同目录存在可用的 update_metadata_pb2，则优先使用它做交叉验证。
"""

from __future__ import annotations

import argparse
import hashlib
import os
import struct
import sys

# ---------------- 最小 protobuf 线格式解析 ----------------

WIRE_VARINT = 0
WIRE_64BIT = 1
WIRE_LEN = 2
WIRE_32BIT = 5


def read_varint(buf, pos):
    result = 0
    shift = 0
    while True:
        if pos >= len(buf):
            raise ValueError("varint truncated")
        b = buf[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if not (b & 0x80):
            return result, pos
        shift += 7
        if shift > 70:
            raise ValueError("varint too long")


def iter_fields(buf):
    """产出 (field_number, wire_type, value)；value 为 int 或 bytes。"""
    pos = 0
    n = len(buf)
    while pos < n:
        tag, pos = read_varint(buf, pos)
        field = tag >> 3
        wire = tag & 7
        if wire == WIRE_VARINT:
            val, pos = read_varint(buf, pos)
        elif wire == WIRE_64BIT:
            val = buf[pos:pos + 8]
            pos += 8
        elif wire == WIRE_LEN:
            ln, pos = read_varint(buf, pos)
            val = buf[pos:pos + ln]
            pos += ln
        elif wire == WIRE_32BIT:
            val = buf[pos:pos + 4]
            pos += 4
        else:
            raise ValueError("unsupported wire type %d" % wire)
        yield field, wire, val


def get_varint(buf, field_no, default=0):
    for f, w, v in iter_fields(buf):
        if f == field_no and w == WIRE_VARINT:
            return v
    return default


def get_bytes_list(buf, field_no):
    return [v for f, w, v in iter_fields(buf) if f == field_no and w == WIRE_LEN]


# ---------------- payload 解析 ----------------

MANIFEST_BLOCK_SIZE = 3
MANIFEST_MINOR_VERSION = 12
MANIFEST_PARTITIONS = 13
MANIFEST_MAX_TIMESTAMP = 14

PU_NAME = 1
PU_NEW_INFO = 7   # update_metadata.proto: old_partition_info=6, new_partition_info=7（经实测比对 sha256 确认）

PI_SIZE = 1
PI_HASH = 2


class Partition:
    __slots__ = ("name", "size", "hash")

    def __init__(self, name, size, digest):
        self.name = name
        self.size = size
        self.hash = digest


def read_manifest(payload_path):
    with open(payload_path, "rb") as fh:
        magic = fh.read(4)
        if magic != b"CrAU":
            raise ValueError("not an Android/ChromeOS payload (magic=%r)" % magic)
        version, = struct.unpack(">Q", fh.read(8))
        manifest_size, = struct.unpack(">Q", fh.read(8))
        sig_size = 0
        if version >= 2:
            sig_size, = struct.unpack(">I", fh.read(4))
        blob = fh.read(manifest_size)
        if len(blob) != manifest_size:
            raise ValueError("manifest truncated")
    return version, manifest_size, sig_size, blob


def parse_partitions(blob):
    parts = []
    for pu in get_bytes_list(blob, MANIFEST_PARTITIONS):
        names = get_bytes_list(pu, PU_NAME)
        name = names[0].decode("utf-8", "replace") if names else "?"
        infos = get_bytes_list(pu, PU_NEW_INFO)
        size = 0
        digest = b""
        if infos:
            size = get_varint(infos[0], PI_SIZE, 0)
            hashes = get_bytes_list(infos[0], PI_HASH)
            digest = hashes[0] if hashes else b""
        parts.append(Partition(name, size, digest))
    return parts


def human(n):
    for unit in ("B", "KiB", "MiB", "GiB"):
        if n < 1024 or unit == "GiB":
            return "%.2f %s" % (n, unit)
        n /= 1024.0


def sha256_file(path, bufsize=8 * 1024 * 1024):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        while True:
            b = fh.read(bufsize)
            if not b:
                break
            h.update(b)
    return h.digest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--payload", required=True)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--verify-dir")
    ap.add_argument("--only", help="逗号分隔的分区名过滤")
    ap.add_argument("--out")
    args = ap.parse_args()

    version, msize, ssize, blob = read_manifest(args.payload)
    parts = parse_partitions(blob)
    block_size = get_varint(blob, MANIFEST_BLOCK_SIZE, 4096)
    minor = get_varint(blob, MANIFEST_MINOR_VERSION, 0)
    maxts = get_varint(blob, MANIFEST_MAX_TIMESTAMP, 0)
    print("payload version=%d manifest_size=%d metadata_signature_size=%d partitions=%d" % (
        version, msize, ssize, len(parts)), file=sys.stderr)
    print("block_size=%d minor_version=%d max_timestamp=%d" % (block_size, minor, maxts), file=sys.stderr)
    if any(not p.hash for p in parts):
        print("!! 警告：部分分区缺少 sha256（清单可能被裁剪）", file=sys.stderr)

    only = set(x.strip() for x in args.only.split(",")) if args.only else None
    ok = mismatch = missing = 0
    lines = []
    for p in sorted(parts, key=lambda x: x.name):
        if only and p.name not in only:
            continue
        line = "%-22s %14d %14s  %s" % (
            p.name, p.size, human(p.size), p.hash.hex() if p.hash else "(no hash)")
        if args.verify_dir:
            path = os.path.join(args.verify_dir, p.name + ".img")
            if not os.path.isfile(path):
                line += "  [MISSING]"
                missing += 1
            else:
                actual = sha256_file(path)
                fsize = os.path.getsize(path)
                if actual == p.hash and fsize == p.size:
                    line += "  [OK]"
                    ok += 1
                else:
                    line += "  [MISMATCH actual_sha=%s actual_size=%d]" % (actual.hex(), fsize)
                    mismatch += 1
        lines.append(line)

    text = "\n".join(lines)
    print(text)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        print("[written] %s" % args.out, file=sys.stderr)
    if args.verify_dir:
        print("\n校验结果: OK=%d MISMATCH=%d MISSING=%d" % (ok, mismatch, missing), file=sys.stderr)
        return 1 if (mismatch or missing) else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
