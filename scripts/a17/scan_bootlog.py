# -*- coding: utf-8 -*-
"""scan_bootlog.py - 扫描 Lenovo kernellog* 持久化内核日志, 按启动会话切分并给出判定

v2 (2026-10-18) 修订:
  1) 新增 FAIL-ZYGOTE-LOOP 判定: zygote 反复 SIGABRT 重启 (boot loop) 不再误落 FAIL-MID
  2) 文件按「轮转时间戳」(每文件首行时间) 排序, 不再按文件名序号
     (设备 RTC 坏时钟会导致序号与时间不单调: .3=05:52, .4=21:24)
  3) RE_CRASH 增加内核日志里真实存在的 zygote signal 6 形态
     (Java 层 Abort message/JNI FatalError 不进内核日志, 原正则命中恒为 0)
  4) 新增 /null stray-fd avc 计数与「我方 KSU init_boot」识别
     (ksuinit / init.bin / allow_shell=1 / KAI_ 标记)
  5) 输出增加 boot 起始时间与 zygote 崩溃次数
"""
import io, os, re, sys, glob

DEFAULT_DIR = r"E:\rom\release\tmp\kernellogs"

RE_BOOT    = re.compile(r"Booting Linux on physical CPU")
RE_KVER    = re.compile(r"Linux version (\S+)")
RE_CMD     = re.compile(r"Kernel command line: (.*)")
RE_FP      = re.compile(r"Setting property 'ro\.build\.fingerprint' to '([^']+)'")
RE_DISP    = re.compile(r"Setting property 'ro\.build\.display\.id' to '([^']+)'")
RE_DONE    = re.compile(r"processing action \(sys\.boot_completed=1\)")
RE_VENDOR  = re.compile(r"Unexpected vendor api level")
RE_PANIC   = re.compile(r"Kernel panic|Unable to handle kernel|Internal error: Oops|synchronous external abort")
RE_WDT     = re.compile(r"watchdog|WDT bark|apps_wdog")
RE_MOUNT   = re.compile(r"(Failed to mount|Unable to mount|mount_with_alternatives|Invalid f2fs superblock|Invalid ext4)")
RE_AVC     = re.compile(r"avc:\s+denied")
RE_NULLAVC = re.compile(r'avc:\s+denied.*path="/null"')
RE_SVCFAIL = re.compile(r"Command '([^']{0,90})' action=\S+ .*? failed")
# 内核日志中真实可见的崩溃形态 (Java 层 abort 不进内核日志)
RE_CRASH   = re.compile(
    r"Fatal signal|Abort message|JNI FatalError|F DEBUG|tombstone"
    r"|Service '([\w.]+)' \(pid \d+\) received signal (6|11)"
)
RE_ZYG6    = re.compile(r"Service 'zygote' \(pid \d+\) received signal 6")
RE_SS      = re.compile(r"system_server")
RE_ZYG     = re.compile(r"started service 'zygote'")
RE_RESET   = re.compile(r"reboot,|bootloader|kernel_panic|hard_reset|watchdog")
# 我方 KSU init_boot 专有标记 (产线固件不可能出现)
RE_KSUINIT = re.compile(r"ksuinit|init\.bin: init first stage started|load kernelsu with params|KernelSU: shell is allowed at init")
RE_KAI     = re.compile(r"KAI_[A-Z]+")
RE_LINETS  = re.compile(r"^\[([A-Z][a-z]{2} [A-Z][a-z]{2} +\d+ \d{2}:\d{2}:\d{2} \d{4})\]")

# 判定阈值
ZYG_LOOP_MIN = 5     # zygote SIGABRT 超过该次数且未 booted => boot loop


def read_lines(path):
    with io.open(path, "r", encoding="utf-8", errors="replace") as fh:
        return [l.rstrip("\r\n") for l in fh]


def first_ts(lines):
    """取文件首行的时间戳, 作为轮转序排序键"""
    for l in lines[:5]:
        m = RE_LINETS.match(l)
        if m:
            return m.group(1)
    return ""


def split_boots(lines):
    starts = [i for i, l in enumerate(lines) if RE_BOOT.search(l)]
    if not starts:
        return [(0, len(lines))] if lines else []
    out = []
    for n, s in enumerate(starts):
        e = starts[n + 1] if n + 1 < len(starts) else len(lines)
        out.append((s, e))
    return out


def analyse(lines, s, e):
    seg = lines[s:e]
    d = {"lines": len(seg), "kver": None, "build": None, "display": None,
         "booted": False, "vendor_gate": 0, "panic": 0, "wdt": 0,
         "mount": 0, "avc": 0, "nullavc": 0, "svcfail": 0, "crash": 0,
         "zyg6": 0, "ksuinit": 0, "kai": 0,
         "system_server": 0, "zygote": 0, "svcfail_samples": [], "mount_samples": []}
    for l in seg:
        m = RE_KVER.search(l)
        if m and not d["kver"]:
            d["kver"] = m.group(1)
        m = RE_FP.search(l)
        if m:
            d["build"] = m.group(1)
        m = RE_DISP.search(l)
        if m:
            d["display"] = m.group(1)
        if RE_DONE.search(l):
            d["booted"] = True
        if RE_VENDOR.search(l):
            d["vendor_gate"] += 1
        if RE_PANIC.search(l):
            d["panic"] += 1
        if RE_WDT.search(l):
            d["wdt"] += 1
        if RE_AVC.search(l):
            d["avc"] += 1
        if RE_NULLAVC.search(l):
            d["nullavc"] += 1
        if RE_CRASH.search(l):
            d["crash"] += 1
        if RE_ZYG6.search(l):
            d["zyg6"] += 1
        if RE_KSUINIT.search(l):
            d["ksuinit"] += 1
        if RE_KAI.search(l):
            d["kai"] += 1
        if RE_SS.search(l):
            d["system_server"] += 1
        if RE_ZYG.search(l):
            d["zygote"] += 1
        if RE_MOUNT.search(l):
            d["mount"] += 1
            if len(d["mount_samples"]) < 2:
                d["mount_samples"].append(l[:160])
        m = RE_SVCFAIL.search(l)
        if m:
            d["svcfail"] += 1
            if len(d["svcfail_samples"]) < 2:
                d["svcfail_samples"].append(m.group(1))
    d["first"] = seg[0][:110] if seg else ""
    d["last"] = seg[-1][:110] if seg else ""
    return d


def verdict(d):
    if d["vendor_gate"]:
        return "FAIL-VENDOR-API"
    if d["panic"]:
        return "FAIL-PANIC"
    # boot loop: zygote 反复崩且始终未完成开机
    if (not d["booted"]) and d["zyg6"] >= ZYG_LOOP_MIN:
        return "FAIL-ZYGOTE-LOOP"
    if d["booted"] and d["system_server"] > 0:
        return "OK"
    if d["booted"]:
        return "BOOTED-NO-SYSTEM_SERVER"
    if d["lines"] < 300:
        return "FAIL-EARLY(截断)"
    return "FAIL-MID"


def rom_of(a):
    """优先用我方标记识别, 再退回 fingerprint"""
    build = a.get("build")
    if a.get("ksuinit") or a.get("kai"):
        return "KSU-init_boot(我方)"
    if not build:
        return "?"
    if "ZUI_16" in build or "TB331FC:14" in build:
        return "ZUI16(A14)"
    if "CP2A" in build or ":17/" in build:
        return "HyperOS4(A17)"
    return build.split(":")[-1][:24]


def main():
    d = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DIR
    files = sorted(glob.glob(os.path.join(d, "kernellog*")))
    files = [p for p in files if not p.endswith(".bak")]
    if not files:
        print("no kernellog found in", d)
        return 1
    # 按每文件首行时间戳排序 (轮转序), 无法解析的排后面
    keyed = []
    for p in files:
        lines = read_lines(p)
        keyed.append((first_ts(lines), os.path.basename(p), p, lines))
    keyed.sort(key=lambda t: (t[0] == "", t[0], t[1]))

    rows = []
    print("### 轮转序 (按每文件首行时间戳排序, 非文件名序号)")
    for ts, base, p, lines in keyed:
        print("    %-13s first_ts=%s  lines=%d" % (base, ts or "?", len(lines)))
        for n, (s, e) in enumerate(split_boots(lines)):
            a = analyse(lines, s, e)
            a["file"] = base
            a["idx"] = n
            a["ts"] = ts
            a["rom"] = rom_of(a)
            a["verdict"] = verdict(a)
            rows.append(a)
    print()

    print("=" * 116)
    print("%-13s %-3s %-18s %-19s %-7s %7s %5s %5s %5s %5s %5s  %s" % (
        "file", "#", "ROM", "verdict", "booted", "lines", "avc", "nul", "zyg6", "ss", "kai", ""))
    print("-" * 116)
    for a in rows:
        print("%-13s %-3d %-18s %-19s %-7s %7d %5d %5d %5d %5d %5d" % (
            a["file"], a["idx"], a["rom"], a["verdict"],
            "Y" if a["booted"] else "-", a["lines"], a["avc"], a["nullavc"],
            a["zyg6"], a["system_server"], a["kai"]))
    print("=" * 116)
    print()

    for a in rows:
        if a["verdict"] == "OK":
            continue
        print("### %s #%d  %s   (boot_ts=%s)" % (a["file"], a["idx"], a["verdict"], a.get("ts") or "?"))
        print("    kver : %s" % (a["kver"] or "?"))
        print("    first: %s" % a["first"])
        print("    last : %s" % a["last"])
        if a["vendor_gate"]:
            print("    !! Unexpected vendor api level x%d" % a["vendor_gate"])
        if a["zyg6"]:
            print("    !! zygote received signal 6 x%d (zygote started x%d)" % (a["zyg6"], a["zygote"]))
        if a["nullavc"]:
            print("    !! stray-fd avc path=\"/null\" x%d (stray fd 被所有子进程继承)" % a["nullavc"])
        if a["ksuinit"] or a["kai"]:
            print("    ** 我方 KSU init_boot 启动 (ksuinit x%d, KAI_ x%d)" % (a["ksuinit"], a["kai"]))
        for s in a["mount_samples"]:
            print("    mnt: %s" % s)
        for s in a["svcfail_samples"]:
            print("    svc: %s" % s)
        print()

    ok = [a for a in rows if a["verdict"] == "OK"]
    print("总计 %d 次启动: OK=%d, 失败=%d" % (len(rows), len(ok), len(rows) - len(ok)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
