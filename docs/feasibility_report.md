# (Moved) HyperOS Porting Feasibility Report

> **This document has been upgraded and merged into → [`移植可行性报告.md`](移植可行性报告.md)**
>
> Migrated: 2026-10
> Reason: the 2026-09 revision contained several data errors (system_a size, whether product/system_ext
> are separate partitions, total system-side size, source device identification). It has been fully
> rewritten from raw binary measurements.

**Canonical document: [`移植可行性报告.md`](移植可行性报告.md)** (Chinese).

## Verdict (unchanged)

Porting the full `yupei` HyperOS 4 (Android 17 / KMI `android15-6.6`) onto TB331FC
(KMI `android13-5.15`) is **NOT feasible**. Blockers:

1. GKI/KMI generation gap — `android13-5.15` vs `android15-6.6`
2. Different SoC generation — `bengal`/SM6225 vs `oryon`/Snapdragon 8 Elite class
3. Correction: `yupei` is **Xiaomi Pad 8**, not Xiaomi Pad 6 Pro

**Recommended path:** GSI (keep all ZUI firmware/vendor, replace system), or a downgraded
source package sharing the `android13-5.15` KMI.
