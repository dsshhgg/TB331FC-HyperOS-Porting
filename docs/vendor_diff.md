# vendor 差异清单（HyperOS `yupei` vs ZUI TB331FC）

> **本文件内容已升级并合并到 →**
> [`移植可行性报告.md`](移植可行性报告.md) §6（硬件驱动逐层对比）
> [`vendor合并补丁清单.md`](vendor合并补丁清单.md)（可执行的保留/补丁清单）
>
> 迁移日期：2026-10。原版的「体积对照」表使用了不准确的数字（`system` / `product` 侧），
> 且把「HyperOS system ≈ 6.0 GiB 超过 system_a 5.79 GiB」当作否决项 —— 实测该约束**可通过
> 重排 super 逻辑分区解决**，不是否决项。

---

## 判定（不变）

| 分区 | 策略 | 原因 |
|------|------|------|
| `boot` / `init_boot` / `vendor_boot` / `dtbo` | **必须 ZUI** | 内核 + 设备树 + vendor ramdisk 绑 SM6225 |
| `vbmeta` / `vbmeta_system` | ZUI（或关闭验证） | AVB 链 |
| `vendor` / `vendor_dlkm` | **必须 ZUI** | 显示 / 触摸 / 音频 / 传感器 HAL 全在这里 |
| `odm` / `odm_dlkm` | **必须 ZUI** | ODM 定制、笔、面板 |
| `system` / `system_ext` / `product` | 源包（需同代 KMI 或走 GSI） | 框架与应用 |
| `mi_ext` / `mi_product` | 可选（debloat 后） | 小米扩展 |
| `xbl` `abl` `tz` `rpm` `keymint` `modem` `dsp` `hyp` … | **必须 ZUI** | bootloader 与安全固件，跨机必砖 |

**核心原则：硬件认底包（ZUI），UI 认源包 —— 且源包必须能被 ZUI vendor 驱得动。**

在 `yupei`（Android 17 / KMI `android15-6.6`）前提下，**不存在可合并的 vendor 补丁清单**：
两侧 vendor 的显示（HWC 2.x→3.x）、触摸（Himax/Lenovo Pen Plus → 小米 MPPT 笔）、
音频（ACDB per-SoC）、传感器（HAL 版本 + 校准 + 器件）**没有任何一层可互换**。

详见 [`vendor合并补丁清单.md`](vendor合并补丁清单.md)。
