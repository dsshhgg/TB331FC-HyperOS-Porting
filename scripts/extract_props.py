# extract_props.py
# 用途：从 ZUI super 分片或 HyperOS payload 产物中扫描 ro.* / androidboot.* 属性
# 时间：2026-09-29
# 依赖：Python 3（仅标准库）
# 用法：
#   python scripts/extract_props.py --dir "E:\类\刷机\...\image"
#   python scripts/extract_props.py --file E:\rom\port\hyperos\work\hyperos_extract\kernel
# 说明：只读扫描，输出关键属性；不写镜像

from __future__ import annotations

import argparse
import os
import re

KEYS = (
    "ro.build.version",
    "ro.system.build",
    "ro.product.build",
    "ro.build.fingerprint",
    "ro.build.version.sdk",
    "ro.build.version.release",
    "ro.product.model",
    "ro.product.device",
    "ro.board.platform",
    "ro.hardware",
    "ro.vndk.version",
    "ro.product.first_api_level",
    "ro.treble.enabled",
    "androidboot.",
)

PROP_RE = re.compile(rb"(ro\.[a-zA-Z0-9._]+=|androidboot\.[a-zA-Z0-9._]+=)([^\x00\n]{1,120})")
LINUX_RE = re.compile(rb"Linux version [^\x00]{5,140}")


def scan_bytes(data: bytes, found: dict[str, str]) -> None:
    for m in PROP_RE.finditer(data):
        key = m.group(1).decode("ascii", "replace")
        val = m.group(2).decode("ascii", "replace")
        if any(k in key for k in KEYS) or key.startswith("androidboot."):
            found[key + val.split("=", 1)[0] if False else key] = val
            found[key.rstrip("=")] = val
    for m in LINUX_RE.finditer(data):
        found["__linux_banner__"] = m.group().decode("ascii", "replace")


def scan_file(path: str, found: dict[str, str]) -> None:
    size = os.path.getsize(path)
    with open(path, "rb") as f:
        prev = b""
        while True:
            chunk = f.read(4 * 1024 * 1024)
            if not chunk:
                break
            scan_bytes(prev + chunk, found)
            prev = chunk[-256:]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", help="目录，扫描其中 .img / kernel")
    ap.add_argument("--file", help="单个文件")
    args = ap.parse_args()

    found: dict[str, str] = {}
    if args.file:
        scan_file(args.file, found)
    elif args.dir:
        for name in sorted(os.listdir(args.dir)):
            if name.endswith(".img") or name in ("kernel", "kernel_dtb"):
                scan_file(os.path.join(args.dir, name), found)
                print(f"scanned {name}")
    else:
        ap.error("need --dir or --file")

    for k in sorted(found):
        print(f"{k}={found[k]}")


if __name__ == "__main__":
    main()
