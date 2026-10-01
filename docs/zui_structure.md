# ZUI 底包结构解析（TB331FC）

> **数据来源**：对原厂线刷包的直接二进制解析（liblp / EXT4 / build.prop），**只读**，未写入任何分区
> **报告日期**：2026-10（**已修正 2026-09 版本的错误数据，见文末「修正记录」**）
> **源路径**：`E:\类\刷机\联想\TB331FC\刷机包\TB331FC_ZUI_16.0.544\image\`
> **包体**：`TB331FC_CN_OPEN_USER_Q00016_T_ZUI_16.0.544.zip`（4,770,905,665 B）
> **复现命令**：`python scripts/parse_super_lp.py super_1.img`、`python scripts/ext4_ls.py super_4.img`

---

## 一、系统版本

| 项目 | 值 |
|------|-----|
| 系统侧 Android | **14** |
| 系统侧 API Level (SDK) | **34** |
| 厂商侧 Android | **13** |
| 厂商侧 API Level (SDK) | **33** |
| first_api_level | 33 |
| Build ID | `UKQ1.230917.001` |
| 安全补丁 | `2024-10-05` |
| 版本增量 | `TB331FC_CN_OPEN_USER_Q00003.0_U_ZUI_16.0.544_ST_241115` |
| 构建日期 | 2024-11-15 |
| 指纹 | `Lenovo/TB331FC_PRC/TB331FC:14/UKQ1.230917.001/ZUI_16.0.544_241115_PRC:user/release-keys` |
| 设备名 | TB331FC / XiaoXin Pad 2024 |
| 构建类型 | user / release-keys |
| A/B 更新 | `ro.build.ab_update=true` |
| virtual A/B | `ro.virtual_ab.enabled=true`（compression / userspace snapshots 均开） |
| Treble | `ro.treble.enabled=true` |

### 逐分区版本（实测）

| 分区 | Android | SDK | 关键属性 |
|------|---------|-----|----------|
| system | 14 | 34 | `ro.system.build.version.*` |
| system_ext | 14 | 34 | `ro.system_ext.build.version.*` |
| product | 14 | 34 | `ro.product.build.version.*` |
| **vendor** | **13** | **33** | `ro.vendor.build.version.*` |
| **odm** | **13** | **33** | `ro.odm.build.version.*` |

- **混合 VNDK**：`ro.vndk.version=33`（厂商侧） vs `ro.product.vndk.version=34`（product 侧）

> **「半升级」形态**：联想把系统侧升到 Android 14，但 vendor/odm 仍停在 Android 13。
> 这意味着**任何 Android 15+ 的系统侧都缺少可用的 vendor 接口** —— 与源包是否同为小米无关。

---

## 二、内核与 GKI

| 项目 | 值 |
|------|-----|
| 内核版本 | `5.15.123-android13-8-00044-g5682afbff3e0-ab11501453` |
| 构建分支（banner 内路径） | `.../android/common-android13-5.15-2023-10/common/...` |
| **GKI 分支 / KMI** | **android13-5.15** |
| 编译器 | Android clang r450784e (14.0.7) |
| kernel raw 大小 | 46,819,840 B |
| boot 头 | v4，无独立 ramdisk（ramdisk 在 init_boot / vendor_boot） |
| 平台 | **bengal（SM6225 / 骁龙 685）** |
| ABI | arm64-v8a |

取证方式：从 `boot.img` 解出的 raw kernel 中直读 `Linux version ...` 字符串。

---

## 三、分区结构

### 3.1 物理分区（`partition.xml`，UFS，sector = 4096）

| 分区 | 大小 | 备注 |
|------|------|------|
| **super** | **12,582,912 KB = 12 GiB** | 逻辑分区容器（sparse） |
| userdata | 10,485,760 KB = 10 GiB | |
| metadata | 65,536 KB = 64 MiB | |
| persist | 32,768 KB = 32 MiB | |
| lenovocust | 307,200 KB = 300 MiB | |
| lenovoraw | 16,384 KB = 16 MiB | |
| boot_a/b | 98,304 KB = 96 MiB | 内核 |
| init_boot_a/b | 8,192 KB = 8 MiB | GKI ramdisk |
| vendor_boot_a/b | 98,304 KB ≈ 96 MiB | vendor ramdisk + cmdline |
| dtbo_a/b | 24,576 KB = 24 MiB | |
| recovery_a/b | 100 MiB | 独立 recovery |
| vbmeta_a/b | 64 KB | AVB |
| vbmeta_system_a/b | 64 KB | AVB |
| modem_a/b | 184,320 KB = 180 MiB | `NON-HLOS.bin` |
| bluetooth_a/b | 1,024 KB = 1 MiB | `BTFM.bin` |
| dsp_a/b | 32,768 KB = 32 MiB | `dspso.bin` |
| tz / hyp / rpm / keymaster / abl / xbl / xbl_config / devcfg / featenabler / imagefv / uefisecapp / qupfw / cmnlib* / storsec / mdtp* | 若干 | 固件链，A/B 双槽 |
| ssd / keystore / frp / lenovolock / oemowninfo / ALIGN_TO_128K_1 / cdt / ddr / misc | 若干 | 厂商锁 / 信息 / 对齐 |

**注意**：`GROW_LAST_PARTITION_TO_FILL_DISK=true` —— 分区尺寸是**打包时决定**的，非硬件固定
（对照：ZUI 15.1.105 售后包的逻辑分区尺寸与本包不同，见 §四）。

### 3.2 super 内逻辑分区（liblp 元数据实测，active slot A）

| 逻辑分区 | sectors | 大小 | 所属 group |
|----------|---------|------|------------|
| `system_a` | 10,729,736 | **5.12 GiB** | qti_dynamic_partitions_a |
| `vendor_a` | 1,330,616 | **649.71 MiB** | qti_dynamic_partitions_a |
| `product_a` | 1,160,960 | **566.88 MiB** | qti_dynamic_partitions_a |
| `system_ext_a` | 898,640 | **438.79 MiB** | qti_dynamic_partitions_a |
| `vendor_dlkm_a` | 115,104 | **56.20 MiB** | qti_dynamic_partitions_a |
| `odm_a` | 2,768 | **1.35 MiB** | qti_dynamic_partitions_a |
| `system_dlkm_a` | 856 | **428.00 KiB** | qti_dynamic_partitions_a |
| `system_b` `vendor_b` `product_b` `system_ext_b` `vendor_dlkm_b` `odm_b` `system_dlkm_b` | **0** | **0 B** | qti_dynamic_partitions_b |
| **合计（slot A）** | | **6.79 GiB** | |

| 元数据项 | 值 |
|----------|-----|
| block device | `super`，12.00 GiB，`first_logical_sector=2048`，`alignment=1 MiB` |
| group 上限 | `qti_dynamic_partitions_a` / `_b` 各 = **11.99 GiB** |
| geometry | @ offset 4096；header v10.2 |
| metadata | `metadata_max_size=65536`，`slot_count=3`，`logical_block_size=4096` |

### 3.3 extent 物理偏移（与线刷分片逐字节对应 —— 证明解析正确）

| 逻辑分区 | extent 偏移 | 大小 (B) | 对应分片 | 分片大小 (B) |
|----------|-------------|----------|----------|--------------|
| `odm_a` | 1,048,576 | 1,417,216 | `super_2.img` | 1,417,216 |
| `product_a` | 3,145,728 | 594,411,520 | `super_3.img` | 594,411,520 |
| `system_a` | 597,688,320 | 5,493,624,832 | `super_4.img` | 5,493,624,832 |
| `system_dlkm_a` | 6,092,226,560 | 438,272 | `super_5.img` | 438,272 |
| `system_ext_a` | 6,093,275,136 | 460,103,680 | `super_6.img` | 460,103,680 |
| `vendor_a` | 6,553,600,000 | 681,275,392 | `super_7.img` | 681,275,392 |
| `vendor_dlkm_a` | 7,235,174,400 | 58,933,248 | `super_8.img` | 58,933,248 |

> `super_1.img` = LP 元数据；`super_9..` 不存在。**每个分片恰好等于一个逻辑分区**。

### 3.4 文件系统

上表 7 个逻辑分区**全部为 EXT4**（superblock magic `0xEF53` @ offset 1080；extents + 64bit）。
卷标 = 分区名（`system` / `vendor` / `product` / `system_ext` / `odm` / `vendor_dlkm` / `system_dlkm`）。

### 3.5 system_a 内容画像

EXT4 递归解析：**5,834 条目**，其中 `/system` 占 **5293.5 MB / 5060 文件**。

顶层目录：

```
/acct /apex /config /data /data_mirror /debug_ramdisk /dev /linkerconfig
/lost+found /metadata /mnt /odm /odm_dlkm /oem /postinstall /proc /product
/second_stage_resources /storage /sys /system /system_dlkm /system_ext
/vendor /vendor_dlkm
```

> `/vendor` `/product` `/system_ext` `/odm` `/system_dlkm` `/vendor_dlkm` 在 `system_a` 内
> **只是空挂载点骨架**（0 B；`/odm/*`、`/vendor_dlkm/etc` 等为指向 `/system/*` 的符号链接）。
> 真正的数据在各自的逻辑分区里。

`/system/priv-app` 共 **109 个**。体积最大的条目（零售固件重度预装）：

| 路径 | 大小 |
|------|------|
| `/system/priv-app/PenService/PenService.apk` | 248.9 MB |
| `/system/priv-app/ZuiCamera/ZuiCamera.apk` | 217.3 MB |
| `/system/priv-app/ZuiWallpaperSetting/ZuiWallpaperSetting.apk` | 206.9 MB |
| `/system/priv-app/ZuiSystemUI/ZuiSystemUI.apk` | 197.2 MB |
| `/system/priv-app/LFHTianjiaoTablet/LFHTianjiaoTablet.apk` | 190.9 MB |
| `/system/preinstall/QQ_music/QQ_music.apk` | 180.7 MB |
| `/system/preinstall/Weibo_HDwm/Weibo_HDwm.apk` | 160.1 MB |
| `/system/preinstall/MotoReadyFor/MotoReadyFor.apk` | 142.8 MB |
| `/system/preinstall/Moffice_196/Moffice_196.apk` | 133.6 MB |
| `/system/preinstall/DouYin/DouYin.apk` | 117.4 MB |

---

## 四、对照基线：ZUI 15.1.105（售后专用包）

`E:\rom\240412_Lenovo_XiaoxinPad_2024_TB331FC_ZUI_15.1.105_纯净版_售后专用\images\super.img`
（12,884,901,888 B，**未分片**）

| 逻辑分区 | 大小 |
|----------|------|
| `system_a` | 5.01 GiB |
| `product_a` | **2.00 GiB** |
| `vendor_dlkm_a` | **1.00 GiB** |
| `vendor_a` | 636.89 MiB |
| `system_ext_a` | 467.77 MiB |
| `odm_a` | 1.21 MiB |
| `system_dlkm_a` | 428.00 KiB |
| 合计 | **9.09 GiB** |

**同一台机器、两份官方固件，逻辑分区尺寸不同** —— 说明 super 布局是软件可调的。

---

## 五、硬件相关属性（vendor）

| 领域 | 关键属性 |
|------|----------|
| 平台 | `ro.board.platform=bengal`、`ro.product.board=bengal`、`ro.soc.manufacturer=QTI` |
| GPU | `ro.hardware.egl=adreno`、`ro.hardware.vulkan=adreno` |
| 显示 | `ro.vendor.display.cabl=2`、`persist.sys.open.cabl=on`、`ro.surface_flinger.has_HDR_display=true`、`has_wide_color_display=true` |
| 音频 | `ro.vendor.dolby.dax.version=DAX3_3.8.5.20_r1`、`ro.vendor.audio.sdk.fluencetype=none` |
| 触控/笔 | `ro.vendor.config.lgsi.pen.event.name=himax-stylus`、`ro.vendor.config.lgsi.pen_info=0x617F:0x17EF:Lenovo Tab Pen Plus`、`ro.vendor.config.lgsi.pen.bluetooth_key.support=1` |
| 传感器 | `persist.vendor.sensors.*`（`support_direct_channel=false`、`enable.rt_task=false`） |
| 形态 | tablet / 11 寸 / WiFi（`radio.noril`） |

---

## 六、结论摘要

- TB331FC = **Android 14 系统 + Android 13 vendor + GKI 5.15.123（KMI `android13-5.15`）** 的 Treble A/B 设备。
- super 内 **7 个逻辑分区各自独立存在**（不是「product 是 system 里的目录」）。
- 全部逻辑分区为 **EXT4**。
- 硬件底（vendor / odm / boot / dtbo / 固件）与 **SM6225（bengal）** 强绑定，**不可**换成其它 SoC 的对应物。

---

## 修正记录（2026-10）

| # | 2026-09 版本的说法 | 实测结果 |
|---|-------------------|----------|
| 1 | `system_a` ≈ **5.79 GiB** | **5.12 GiB**（10,729,736 sectors = 5,493,624,832 B） |
| 2 | 「product / system_ext 是 system 内的目录，本机未单独挂载」 | `product_a` / `system_ext_a` / `vendor_a` / `odm_a` / `vendor_dlkm_a` / `system_dlkm_a` **均为独立 super 逻辑分区**，各有实际尺寸 |
| 3 | 「super 内逻辑分区」表述含糊 | 已补全 sectors / 字节 / extent 物理偏移，并与线刷分片逐字节对齐验证 |

详见 `移植可行性报告.md`。
