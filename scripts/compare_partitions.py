# compare_partitions.py
# 用途：对比 ZUI / HyperOS 分区清单、内核 KMI 与体积约束，输出结论摘要
# 时间：2026-09-29
# 依赖：Python 3（仅标准库）
# 用法：python scripts/compare_partitions.py

"""
只读分析脚本：汇总两侧版本/KMI/分区体积，打印可行性摘要。
不读写任何块设备，不做 fastboot。
"""

from __future__ import annotations

# 实测数据（2026-09-29 解析结果，见 docs/*.md）
ZUI = {
    "android": 14,
    "sdk": 34,
    "vendor_android": 13,
    "vendor_sdk": 33,
    "kernel": "5.15.123-android13-8-00044-g5682afbff3e0-ab11501453",
    "kmi": "android13-5.15",
    "platform": "bengal (SM6225)",
    "system_a_bytes": 5_794_435_072,
    "super_bytes": 12 * 1024**3,
}

HYPEROS = {
    "android": 17,
    "kernel": "6.6.118-android15-8-gc4127a25dcf3-ab15863337-4k",
    "kmi": "android15-6.6",
    "platform": "newer QCOM (aop/cpucp/shrm/soccp/pvmfw)",
    "system_side_gib": 9.26,
    "product_gib": 6.0,
}


def main() -> None:
    print("=== ZUI (TB331FC) ===")
    for k, v in ZUI.items():
        print(f"  {k}: {v}")
    print("=== HyperOS (yupei) ===")
    for k, v in HYPEROS.items():
        print(f"  {k}: {v}")

    print("\n=== 对比 ===")
    print(f"  Android 差距: {HYPEROS['android'] - ZUI['android']} 个大版本")
    print(f"  KMI: {ZUI['kmi']}  vs  {HYPEROS['kmi']}  -> {'兼容' if ZUI['kmi'] == HYPEROS['kmi'] else '不兼容'}")
    need = int(HYPEROS["system_side_gib"] * 1024**3)
    have = ZUI["system_a_bytes"]
    print(f"  系统侧体积: 需要 {need / 1024**3:.2f} GiB, 可用 {have / 1024**3:.2f} GiB -> {'装得下' if need <= have else '装不下'}")

    blockers = []
    if ZUI["kmi"] != HYPEROS["kmi"]:
        blockers.append("GKI KMI 跨代（否决）")
    if ZUI["platform"] != HYPEROS["platform"]:
        blockers.append("SoC/固件平台不同（否决）")
    if HYPEROS["android"] - ZUI["android"] >= 3:
        blockers.append("Android 跨 3+ 大版本")
    if need > have:
        blockers.append("系统侧体积超出 system_a")

    print("\n=== 结论 ===")
    if blockers:
        print("  不可行（完整移植 yupei HyperOS 4）")
        for b in blockers:
            print(f"   - {b}")
        print("  建议: GSI / 降级源包(HyperOS1 或 A13-14) / 既有 TB331FC 专包")
    else:
        print("  可进一步评估")


if __name__ == "__main__":
    main()
