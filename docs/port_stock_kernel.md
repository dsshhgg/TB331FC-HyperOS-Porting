# 原厂内核移植路线（已锁定）

> 状态：**已确认** · 日期：2026-09-29
> 决策：**用 ZUI 原厂内核继续移植**（不替换 boot / init_boot / vendor_boot）

---

## 1. 锁定内容

| 层 | 策略 | 文件 |
|----|------|------|
| 内核 | **ZUI 原厂** `5.15.123-android13`，KMI **android13-5.15** | `boot.img` `init_boot.img` |
| vendor ramdisk / 触控 cmdline | **ZUI 原厂** | `vendor_boot.img` |
| 设备树 | **ZUI 原厂** | `dtbo.img` |
| vendor / odm / dlkm | **ZUI 原厂** | super 内逻辑分区 |
| 固件链 | **ZUI 原厂** | xbl/abl/tz/rpm/keymint/modem/dsp… |
| recovery | ZUI 或 TB331FC 专用 OrangeFox（实验） | 不参与系统替换 |
| AVB | 可 disable（`vbmeta` flags） | 验证问题，非硬件 |
| **system / system_ext / product / mi_ext** | **HyperOS 源（精简后）** | 唯一替换面 |

**一句话：硬件与内核 100% ZUI，只换系统侧。**

---

## 2. 为什么必须锁原厂内核

1. yupei 内核是 `6.6.118-android15`，KMI 与 ZUI vendor 模块不通用 → 换了就无驱动。  
2. TB331FC 设备树/固件绑 SM6225，换 SoC 内核无法点亮屏/笔/传感器。  
3. 已有定制内核（TB331FC-Kernel）同属 **5.15 android13 KMI**，属于可选增强，不是移植前提。

---

## 3. 系统侧约束（接受并处理）

| 问题 | 处理 |
|------|------|
| HyperOS 系统侧 ≈ 9.3 GiB > system_a 5.12 GiB | **必须 debloat**（A 档已达标：3.468 GiB，无需 resize） |
| Android 17 框架 vs vendor 13 HAL | 属性/SELinux/`_boot_fix` 类修补 |
| ~~EROFS 老工具抽不全~~ | ✅ **已解决（2026-10 v2）**：用 `extract.erofs -x` 从 sha256 校验过的原镜像重解 → `work/trusted_trees/`，并与镜像侧条目数逐分区对照。旧树缺 1,036 个文件 |
| 机型校验（相机等） | 换通用相机 / 改 prop；避免 priv-app 白名单坑 |

---

## 3.5 ⚠️ 本路线真正的关卡（2026-10 机制级取证，详见主报告 §8A）

「用原厂内核」正确地去掉了 **KMI 模块混装**与**四层硬件栈**问题，这一点本路线成立。
但剩下三道卡在 **A17 系统用户态 ↔ A13 vendor 用户态**的契约上，**与内核无关，换内核也绕不过去**：

| # | 关卡 | 实测证据 | 性质 |
|---|------|----------|------|
| 1 | **vendor API level** | ZUI `ro.board.api_level=33` vs A17 `ro.llndk.api_level=202604`；A17 `init` 内含 `ro.vendor.api_level` 计算与 `Unexpected vendor api level` 报错串 | **最硬**，差约 3 年接口面 |
| 2 | **VNDK 被移除** | A17 `/system/apex` 无任何 `com.android.vndk.*`（ZUI A14 有 `vndk.current`）；但 A17 `/system/lib64` **仍提供** `libhidlbase`/`libhwbinder`/`libutils` 等 | 风险，未证否 |
| 3 | **BPF 程序覆盖** | A17 至少 4 个 BPF 程序依赖 ZUI 5.15 内核**不存在**的符号（`shmem_swapin_folio`/`bpf_iter_ksym`/`mm_calculate_totalreserve_pages`/`android_vendor_lmk`）；`netbpfload.rc` 有 `wait_for_prop bpf.progs_loaded 1` + "will hang if bpfloader fails"，但 A17 `bpfloader` 含 `min_kver`/`max_kver` 门控与 `skipping`/`ignoring` 语义 | 预计**非致命**（推断） |

**另需更正一个早期误解**：并非「A17 必须配 6.18 代 GKI」——
`yupei` 自身即 **Android 17 + `android15-6.6` GKI**，证明 Android 版本与 GKI 代际解耦。

**本路线评级**：**超出官方兼容包线，但未被证否**。三关都是运行期行为，
**静态分析无法定论，只能实测**。详见主报告 §8A.5 的 S1–S4 步骤。

---

## 4. 目标产物（仍禁止未确认刷写）

```text
out/
  system_a_hyperos4_A.img   # EROFS，含 system+product+system_ext（单分区合并）3.468 GiB
  MD5SUMS.txt
  （刷写脚本待写：只替换 system，显式保留 boot/vendor 等）
```

刷写原则（**待你确认前不执行**）：

```text
保留：boot / init_boot / vendor_boot / dtbo / vendor / odm / 全部固件
只刷：system（或 super 内 system/product/system_ext）
可选：vbmeta disable-verification
必须：备份 + fastboot -w 准备
```

---

## 5. 执行步骤

| 步骤 | 内容 | 状态 |
|------|------|------|
| S1 | 锁定原厂内核路线（本文档） | ✅ |
| S2 | 重解 HyperOS system/product/system_ext/mi_ext | ✅ **（v2：可信树 `work/trusted_trees/`，与镜像侧条目数对照通过）** |
| S3 | Debloat 到体积达标 | ✅ **（product 7,393.3 → 2,570.1 MB）** |
| S4 | 注入 TB331FC.xml + 音频/笔/SELinux 补丁 | ⏳ TB331FC.xml 已注入；其余待办 |
| S5 | 打包 `out/system_a_hyperos4_A.img` + 校验 | ✅ **（3.468 GiB / SHA256 `F0998B…8EF9`，12/12 关键库到位）** |
| S6 | 试刷前备份 + 确认救砖 | ⏳ `scripts/backup_partitions.ps1`（默认 dry-run） |
| S7 | 你确认后才讨论刷写 | 禁止自动执行 |

> ⚠️ 刷 S1 之前必须先定 **`product_a` / `system_ext_a` 的处理方案**：
> 合并镜像内的 HyperOS `product`/`system_ext` 在只刷 `system_a` 时会被 ZUI 分区**遮蔽**，
> 否则试刷失败无法区分「兼容性不通」与「被遮蔽」。见 `size_report.md` §6。

---

## 6. 与可行性报告的关系

`feasibility_report.md` 结论「**完整移植 yupei（含 vendor/内核）不可行**」不变。  
本文档表示：**在不动内核/vendor 的前提下，继续做系统侧拼包**——这是剩余的可行窗口，不是推翻 KMI 结论。

⚠️ **但「完整移植不可行」不蕴含「本路线可行」**（早期版本曾这样表述，已更正）。
本路线是**独立的、未被证否的**候选，其成败取决于 §3.5 的三道关卡，**只能实测判定**。

风险仍在：A17 框架 + A13 vendor 可能功能残缺；优先保证开机、显示、触控、音频、笔。
