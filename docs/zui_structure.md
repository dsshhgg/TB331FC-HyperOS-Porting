# ZUI 底包结构解析（TB331FC）

> 解析时间：2026-09-29 · 只读分析，未写入任何分区
> 源路径：`E:\类\刷机\联想\TB331FC\刷机包\TB331FC_ZUI_16.0.544\image\`
> 分析产物：`E:\rom\port\hyperos\work\zui_boot\`

## 一、系统版本

| 项目 | 值 |
|------|-----|
| Android 版本 | **14** |
| API Level (SDK) | **34** |
| first_api_level | 33 |
| Build ID | UKQ1.230917.001 |
| 安全补丁 | 2024-10-05 |
| 版本增量 | TB331FC_CN_OPEN_USER_Q00003.0_U_ZUI_16.0.544_ST_241115 |
| 显示版本 | TB331FC_CN_OPEN_USER_Q00003.0_U_ZUI_16.0.544_ST_241115 |
| 构建日期 | 2024-11-15 |
| 指纹 | `Lenovo/TB331FC_PRC/TB331FC:14/UKQ1.230917.001/ZUI_16.0.544_241115_PRC:user/release-keys` |
| 设备名 | TB331FC / XiaoXin Pad 2024 |
| 构建类型 | user / release-keys |
| AB 更新 | 是 (`ro.build.ab_update=true`) |
| Treble | 已启用 (`ro.treble.enabled=true`) |

### 混合版本现象（重要）

| 分区 | Android | SDK | 说明 |
|------|---------|-----|------|
| system / system_ext / product | 14 | 34 | 系统侧 |
| vendor / vendor_dlkm | **13** | **33** | 厂商侧未跟着升 |
| VNDK | 33（vendor）/ 34（product） | | `ro.vndk.version=33`，`ro.product.vndk.version=34` |

## 二、内核与 GKI

| 项目 | 值 |
|------|-----|
| 内核版本 | `5.15.123-android13-8-00044-g5682afbff3e0-ab11501453` |
| GKI 分支 | **android13-5.15** |
| KMI | **android13-5.15**（`5.15.123-android13-8`） |
| 编译器 | Android clang r450784e |
| boot 格式 | header v4，kernel raw 46,819,840 B，无 ramdisk（ramdisk 在 init_boot / vendor_boot） |
| 平台 | bengal（SM6225 / 骁龙 685） |
| ABI | arm64-v8a |

## 三、分区结构

### 物理分区（partition.xml，UFS，sector=4096）

| 分区 | 大小 | 备注 |
|------|------|------|
| super | **12 GiB** (12,582,912 KB) | 逻辑分区容器，sparse |
| userdata | 10 GiB | |
| metadata | 64 MiB | |
| persist | 32 MiB | |
| boot_a/b | 96 MiB | 内核 |
| init_boot_a/b | 8 MiB | GKI ramdisk |
| vendor_boot_a/b | 96 MiB | vendor ramdisk + cmdline |
| dtbo_a/b | 24 MiB | |
| recovery_a/b | 100 MiB | |
| vbmeta_a/b | 64 KiB | |
| vbmeta_system_a/b | 64 KiB | |
| modem_a/b | 180 MiB | NON-HLOS.bin |
| bluetooth_a/b | 1 MiB | BTFM.bin |
| dsp_a/b | 32 MiB | |
| tz / hyp / rpm / keymaster / abl / xbl … | 若干 | 固件链，A/B 双槽 |
| lenovocust | 300 MiB | 联想定制 |
| lenovoraw / lenovolock / oemowninfo | 若干 | 厂商锁/信息 |

### super 内逻辑分区（A/B）

来自 `ro.product.ab_ota_partitions` 与 super 扫描：

| 逻辑分区 | 说明 |
|----------|------|
| system_a | 主系统（本机上 system/product/system_ext 同挂 ext4，见既有调研） |
| product_a | 存在但本机曾观测为未单独挂载 |
| system_ext_a | 同上 |
| vendor_a | HAL / 驱动 |
| odm_a | ODM 定制 |
| system_dlkm / vendor_dlkm / odm_dlkm | 内核模块 |

### super 分片镜像（线刷包）

| 文件 | 大小 |
|------|------|
| super_1.img | 396 KiB |
| super_2.img | 1.35 MiB |
| super_3.img | 567 MiB |
| super_4.img | **5.12 GiB** |
| super_5.img | 428 KiB |
| super_6.img | 439 MiB |
| super_7.img | 650 MiB |
| super_8.img | 56 MiB |
| super_empty.img | 5 KiB |

## 四、硬件相关属性（vendor）

| 领域 | 关键属性 |
|------|----------|
| 显示 | `ro.hardware.egl=adreno`，`ro.hardware.vulkan=adreno`，`ro.vendor.display.cabl=2` |
| 音频 | Dolby DAX3 `DAX3_3.8.5.20_r1`，`ro.vendor.audio.sdk.fluencetype=none` |
| 触控/笔 | `himax-stylus`，`ro.vendor.config.lgsi.pen_info=0x617F:0x17EF:Lenovo Tab Pen Plus` |
| 平台 | `ro.board.platform=bengal`，`ro.soc.manufacturer=QTI` |
| 形态 | tablet，11 寸，WiFi（`device.nettype=wifi`，`radio.noril=*`） |

## 五、结论摘要

- TB331FC 是 **Android 14 系统 + Android 13 vendor + GKI 5.15.123 (android13-5.15)** 的 Treble A/B 设备。
- 启动链完整（xbl/abl/tz/rpm/keymint + boot/init_boot/vendor_boot/dtbo/vbmeta）。
- 硬件底（vendor/odm/boot）与 SM6225 绑定，**不能**直接换成其它 SoC 的 vendor。
