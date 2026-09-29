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
| HyperOS 系统侧 ≈ 9.3 GiB > system_a 5.79 GiB | **必须 debloat**（目标解包树 ≤ 5.2 GiB / EROFS 后 ≤ 5.4 GiB） |
| Android 17 框架 vs vendor 13 HAL | 属性/SELinux/`_boot_fix` 类修补；已知可救桌面/笔/音频/互传 |
| EROFS 老工具抽不全 | 换新版 `fsck.erofs`/`extract.erofs` 或重解 payload |
| 机型校验（相机等） | 换通用相机 / 改 prop；避免 priv-app 白名单坑 |

---

## 4. 目标产物（仍禁止未确认刷写）

```text
out/
  system_ported.img     # EROFS 或 ext4，含 system+product+system_ext（合并或按原拓扑）
  flash_stock_kernel.ps1  # 只替换 system，显式保留 boot/vendor 等
  MD5SUMS.txt
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
| S2 | 重解 HyperOS system/product/system_ext/mi_ext | ⏳ |
| S3 | Debloat 到体积达标 | ⏳ |
| S4 | 注入 TB331FC.xml + 音频/笔/SELinux 补丁 | 待 S3 |
| S5 | 打包 `out/system_ported.img` + 校验 | 待 S4 |
| S6 | 你确认后才讨论刷写 | 禁止自动执行 |

---

## 6. 与可行性报告的关系

`feasibility_report.md` 结论「**完整移植 yupei（含 vendor/内核）不可行**」不变。  
本文档表示：**在不动内核/vendor 的前提下，继续做系统侧拼包**——这是剩余的可行窗口，不是推翻 KMI 结论。

风险仍在：A17 框架 + A13 vendor 可能功能残缺；优先保证开机、显示、触控、音频、笔。
