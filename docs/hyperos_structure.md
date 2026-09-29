# HyperOS 包结构解析（yupei）

> 解析时间：2026-09-29 · 只读分析，未写入任何分区
> 源路径：`E:\rom\yupei-ota_full-OS4.0.5.0.XPZCNXM-user-17.0-4fe489f542\`
> 包名：`yupei-ota_full-OS4.0.5.0.XPZCNXM-user-17.0-4fe489f542`
> 分析产物：`E:\rom\port\hyperos\work\hyperos_extract\`

## 一、系统版本

| 项目 | 值 |
|------|-----|
| ROM | HyperOS 4.0.5.0.XPZCNXM |
| Android 版本 | **17** |
| Build ID | CP2A.260605.016 |
| 系统指纹 | `Xiaomi/missi/missi:17/CP2A.260605.016/17OS4.0.260913.205532236.QCPDCN.S:user/release-keys` |
| product 指纹 | `Xiaomi/yupei/miproduct:17/CP2A.260605.016/OS4.0.5.0.XPZCNXM:user/release-keys` |
| odm 指纹 | `Xiaomi/yupei/yupei:15/AQ3A.250226.002/OS4.0.5.0.XPZCN:user/release-keys` |
| 形态 | 全量 AB OTA（`payload.bin` 9,922,252,710 B ≈ 9.24 GiB） |
| 元数据 | `METADATA_SIZE=346993`，payload 版本 2 |
| 包内 APEX | 含 `com.android.vndk.v34` 等（兼容 VNDK 34 客户端） |

### 混合版本现象（与 ZUI 类似，但更极端）

| 分区 | Android | 说明 |
|------|---------|------|
| system | **17**（missi） | 框架 |
| product | **17**（miproduct） | 应用/设备特性 |
| system_ext | 17 系 | 框架扩展 |
| odm | **15** | ODM 侧仍停在 15 |
| system_dlkm | **15** | 内核模块配套 android15 GKI |

## 二、内核与 GKI

| 项目 | 值 |
|------|-----|
| 内核版本 | `6.6.118-android15-8-gc4127a25dcf3-ab15863337-4k` |
| GKI 分支 | **android15-6.6** |
| KMI | **android15-6.6**（`6.6.118-android15-8`） |
| boot 格式 | header v4，kernel 36,801,024 B + kernel_dtb 2,325,312 B，无独立 ramdisk |
| system_dlkm vermagic | `6.6.118-android15-8-gc4127a25dcf3-ab15863337-4k SMP preempt mod_unload` |
| 意义 | system_dlkm/vendor_dlkm 模块 **只能** 跑在 android15-6.6 KMI 上 |

## 三、payload 分区清单及大小

单位：KiB（payload-dumper-go `-l -m`），并换算人类可读。

| 分区 | KiB | 可读 | 类别 |
|------|-----|------|------|
| product | 6,144,300 | **6.0 GiB** | 系统 |
| odm | 1,599,616 | 1.5 GiB | 硬件 |
| vendor | 1,691,072 | **1.6 GiB** | 硬件 |
| system | 954,656 | 978 MiB | 系统 |
| system_ext | 804,228 | 824 MiB | 系统 |
| mi_ext | 445,564 | 456 MiB | 小米扩展 |
| dsp | 65,536 | 67 MiB | 固件 |
| vendor_dlkm | 56,568 | 58 MiB | 内核模块 |
| modem | 114,764 | 118 MiB | 固件 |
| boot | 98,304 | 101 MiB | 启动 |
| vendor_boot | 98,304 | 101 MiB | 启动 |
| recovery | 102,400 | 105 MiB | 启动 |
| system_dlkm | 14,936 | 15 MiB | 内核模块 |
| dtbo | 18,432 | 19 MiB | 启动 |
| vm-bootsys | 20,480 | 21 MiB | 虚拟化 |
| tz | 4,124 | 4.2 MiB | 固件 |
| uefi | 2,740 | 2.8 MiB | 固件 |
| bluetooth | 1,628 | 1.7 MiB | 固件 |
| hyp | 1,564 | 1.6 MiB | 固件 |
| imagefv | 6,152 | 6.3 MiB | 固件 |
| init_boot | 8,192 | 8.4 MiB | 启动 |
| abl | 328 | 336 KiB | 固件 |
| aop | 328 | 336 KiB | 固件（新一代） |
| aop_config | 24 | 25 KiB | 固件 |
| cpucp | 236 | 242 KiB | 固件（新一代） |
| cpucp_dtb | 16 | 16 KiB | 固件 |
| devcfg | 56 | 57 KiB | 固件 |
| featenabler | 104 | 106 KiB | 固件 |
| idmanager | 68 | 70 KiB | 固件 |
| keymaster | 444 | 455 KiB | 固件 |
| mi_product | 340 | 348 KiB | 小米扩展 |
| multiimgqti | 12 | 12 KiB | 固件 |
| pvmfw | 1,024 | 1 MiB | 固件（pKVM） |
| qupfw | 64 | 66 KiB | 固件 |
| shrm | 148 | 152 KiB | 固件（新一代） |
| soccp_dcd | 16 | 16 KiB | 固件 |
| soccp_debug | 144 | 148 KiB | 固件 |
| spuservice | 92 | 94 KiB | 固件 |
| uefisecapp | 200 | 205 KiB | 固件 |
| vbmeta | 12 | 12 KiB | AVB |
| vbmeta_system | 4 | 4.1 KiB | AVB |
| xbl / xbl_config / xbl_ramdump | 1,144 / 276 / 868 | ~1.2 MiB | 固件 |
| countrycode | 1,024 | 1 MiB | 区域 |

**系统侧合计（可移植层）**：system + product + system_ext + mi_ext + mi_product ≈ **9.26 GiB**  
**硬件侧合计（不应混用）**：vendor + odm + vendor_dlkm + 固件 ≈ **3.4+ GiB**

## 四、与 TB331FC 空间对照

| 项 | HyperOS yupei | TB331FC ZUI |
|----|---------------|-------------|
| system_a 实际可用 | （需与 product 合并） | **5.79 GiB** |
| HyperOS 系统侧 | **~9.26 GiB** | 装不下 |
| super 总容量 | （源机更大） | **12 GiB**（含 vendor/odm） |

→ 即使内核兼容，**product 体积也超过 TB331FC 整个 system 分区**，必须 debloat 或重划 super。

## 五、固件层信号（SoC 代际）

payload 含 `aop` / `cpucp` / `shrm` / `soccp` / `pvmfw` / `uefi` 等分区，属于**较新一代高通平台**固件布局，与 TB331FC 的 bengal/SM6225（khaje，2022 中端）明显不同代。

## 六、结论摘要

- yupei 包是 **HyperOS 4 / Android 17 系统 + android15-6.6 GKI** 的全量 OTA。
- 与 ZUI 相比：Android 跨 **3 个大版本**，KMI 从 **android13-5.15 → android15-6.6** 完全换代。
- 系统侧体积约 **9.3 GiB**，超出 TB331FC system_a（5.79 GiB）。
- vendor/固件对应另一颗 SoC，**不能**与 TB331FC 硬件互换。
