#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
用途  : 只读扫描镜像（super 分片 / 逻辑分区 img / 内核）中的 build 属性与内核 banner，
        用于 ZUI 底包与 HyperOS 源包的版本取证。
时间  : 2026-10 移植可行性评估（替代 2026-09-29 初版，修正原实现的键值拼接缺陷）
依赖  : Python 3 标准库
用法  : python extract_props.py --file <path>
        python extract_props.py --dir  <dir> [--glob "super_*.img"]
        python extract_props.py --file <path> --out <txt> [--all]
说明  : 纯只读。--all 输出全部 ro.*/androidboot.*，默认只输出「决策相关」白名单键。
"""

from __future__ import annotations

import argparse
import os
import re
import sys

# 决策相关属性：版本 / API / 指纹 / 平台 / VNDK / Treble / A-B / 硬件栈
KEY_PATTERNS = [
    re.compile(p) for p in (
        r"^ro\.build\.version\.(release|sdk|sdk_full|security_patch|incremental|release_or_codename)$",
        r"^ro\.build\.(id|fingerprint|date|date\.utc|type|tags|flavor|host|user)$",
        r"^ro\.(system|product|vendor|odm|system_ext|bootimage)\.build\.(version\.sdk|version\.release|fingerprint|date)$",
        r"^ro\.product\.(brand|name|device|model|manufacturer|board|first_api_level)$",
        r"^ro\.(board|soc)\.(platform|manufacturer|model)$",
        r"^ro\.hardware(\.\w+)?$",
        r"^ro\.treble\.enabled$",
        r"^ro\.build\.ab_update$",
        r"^ro\.(product\.)?vndk\.version$",
        r"^ro\.vendor\.build\.version\.sdk$",
        r"^ro\.vndk\.version$",
        r"^ro\.product\.vndk\.version$",
        r"^ro\.vendor\.display\.\w+$",
        r"^ro\.vendor\.audio\.\w+$",
        r"^ro\.vendor\.config\.\w+$",
        r"^ro\.boot\.\w+$",
        r"^ro\.crypto\.\w+$",
        r"^ro\.sf\.\w+$",
        r"^ro\.opengles\.\w+$",
        r"^ro\.zygote\b.*$",
        r"^androidboot\.\w+$",
        r"^ro\.dynamic_partitions$",
        r"^ro\.virtual_ab.*$",
    )
]

PROP_RE = re.compile(rb"(ro\.[A-Za-z0-9._]{1,60}|androidboot\.[A-Za-z0-9._]{1,60})=([\x20-\x7E]{0,200})")
LINUX_RE = re.compile(rb"Linux version [\x20-\x7E]{5,220}")
CHUNK = 8 * 1024 * 1024
OVERLAP = 512


def wanted(key: str, show_all: bool) -> bool:
    if show_all:
        return True
    return any(p.match(key) for p in KEY_PATTERNS)


def scan_stream(fh, found: dict[str, str], show_all: bool) -> None:
    prev = b""
    while True:
        chunk = fh.read(CHUNK)
        if not chunk:
            break
        data = prev + chunk
        for m in PROP_RE.finditer(data):
            key = m.group(1).decode("ascii", "replace")
            val = m.group(2).decode("ascii", "replace").strip("\x00").strip()
            if not val or wanted(key, show_all) is False:
                continue
            found.setdefault(key, val)
        for m in LINUX_RE.finditer(data):
            found.setdefault("__kernel_banner__", m.group().decode("ascii", "replace").strip("\x00"))
        prev = data[-OVERLAP:]


def scan_path(path: str, found: dict[str, str], show_all: bool) -> None:
    try:
        with open(path, "rb") as fh:
            scan_stream(fh, found, show_all)
    except OSError as exc:
        print("!! 无法读取 %s: %s" % (path, exc), file=sys.stderr)


def iter_targets(args) -> list[str]:
    if args.file:
        return [args.file]
    pat = re.compile(args.glob.replace(".", r"\.").replace("*", ".*") + "$")
    out = []
    for name in sorted(os.listdir(args.dir)):
        full = os.path.join(args.dir, name)
        if os.path.isfile(full) and pat.match(name):
            out.append(full)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--dir")
    src.add_argument("--file")
    ap.add_argument("--glob", default="*")
    ap.add_argument("--out")
    ap.add_argument("--all", action="store_true", help="输出全部匹配属性而非白名单")
    args = ap.parse_args()

    found: dict[str, str] = {}
    targets = iter_targets(args)
    if not targets:
        print("!! 没有匹配的文件", file=sys.stderr)
        return 2
    for t in targets:
        print("scanned: %s" % t, file=sys.stderr)
        scan_path(t, found, args.all)

    lines = ["%s=%s" % (k, v) for k, v in sorted(found.items())]
    text = "\n".join(lines)
    print(text)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
        print("\n[written] %s" % args.out, file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
