# HyperOS 源包结构解析（`yupei`）

> **数据来源**：对官方全量 OTA `payload.bin` 的直接解析（DeltaArchiveManifest + 解包镜像实测）
> **报告日期**：2026-10（**已修正 2026-09 版本的机型与体积错误，见文末「修正记录」**）
> **源路径**：`E:\rom\yupei-ota_full-OS4.0.5.0.XPZCNXM-user-17.0-4fe489f542\`
> **复现命令**：`python scripts/verify_payload.py --payload payload.bin --list`

---

## 〇、机型标识（⚠️ 与任务描述不符）

任务描述为「移植源：**小米平板 6 Pro**」，但包内标识一致指向 **`yupei`**：

| 证据 | 值 |
|------|-----|
| product 指纹 | `Xiaomi/yupei/miproduct:17/CP2A.260605.016/OS4.0.5.0.XPZCNXM:user/release-keys` |
| odm 指纹 | `Xiaomi/yupei/yupei:15/AQ3A.250226.002/OS4.0.5.0.XPZCN:user/release-keys` |
| 设备特性文件 | `product/etc/device_features/yupei.xml`（`is_pad=true`、`vendor=qcom`、`is_xiaomi=true`、`is_ltpo_screen=false`） |
| **CPU 微架构** | `ro.bionic.cpu_variant=**oryon**` |
| 构建时间 | 2026-09-13 |

- **小米平板 6 Pro 的 codename 是 `liuqin`**（骁龙 8+ Gen 1，Kryo 核）。
- 本包 `ro.bionic.cpu_variant=oryon` → 高通**自研 Oryon 核**，属骁龙 8 Elite 世代。
- 公开信息：*「Xiaomi Pad 8（Yupei）推送小米澎湃OS 4 Beta版OTA更新」*
  （[微博](https://weibo.com/2/detail/5346368950370913)、
  [快科技：小米平板8系列搭载骁龙8 Elite](https://m.mydrivers.com/newsview/1074359.html)、
  [chinaz：小米平板8系列通过认证](https://www.chinaz.com/2025/0808/1702897.shtml)）。

> **结论：`yupei` = Xiaomi Pad 8（骁龙 8 Elite 级），不是小米平板 6 Pro。**
> SoC 代差因此比任务预设更大（8+ Gen 1 → 8 Elite），移植难度只增不减。

---

## 一、系统版本

| 项目 | 值 |
|------|-----|
| ROM | HyperOS **4.0.5.0.XPZCNXM** |
| 系统侧 Android | **17** |
| 系统侧 API Level (SDK) | **37** |
| Build ID | `CP2A.260605.016` |
| 版本增量 | `17OS4.0.260913.205532236.QCPDCN.S` |
| 安全补丁 | `2026-08-01` |
| 构建时间 | 2026-09-13 |
| system 指纹 | `Xiaomi/missi/missi:17/CP2A.260605.016/17OS4.0.260913.205532236.QCPDCN.S:user/release-keys` |
| product 指纹 | `Xiaomi/yupei/miproduct:17/CP2A.260605.016/OS4.0.5.0.XPZCNXM:user/release-keys` |
| odm 指纹 | `Xiaomi/yupei/yupei:15/AQ3A.250226.002/OS4.0.5.0.XPZCN:user/release-keys` |
| 形态 | 全量 A/B OTA，payload 版本 2 |
| payload.bin | 9,922,252,710 B（≈9.24 GiB） |
| manifest | 346,969 B，分区数 **45** |
| metadata_signature | 267 B |
| max_timestamp | 1,789,309,904 |
| 包内 APEX | 含 `com.android.vndk.v34` 等 |

### 逐分区版本（实测）

| 分区 | Android | SDK | 关键属性 / 证据 |
|------|---------|-----|-----------------|
| system | **17** | **37** | `ro.build.version.release/sdk` |
| system_ext | 17 | 37 | `ro.system_ext.build.version.*` |
| product | **17** | **37** | `ro.product.build.version.*` |
| **vendor** | **15** | **35** | `ro.vendor.build.version.*`；指纹 `Xiaomi/mivendor/mivendor:15/AQ3A.250226.002/OS4.0.5.0.XPZCN` |
| **odm** | **15** | — | `ro.odm.build.*`，`AQ3A.250226.002` |
| system_dlkm | 15 | — | 与 android15 GKI 模块配套 |

- `ro.product.first_api_level=35`
- `ro.product.vendor.device=mivendor`、`ro.vendor.product.cpu.abilist=arm64-v8a`

> **与 ZUI 同样的「半升级」形态，但整体前移 2 代**：系统侧 17，厂商侧 15。

---

## 二、内核与 GKI

从 `boot.img`（100,663,296 B）解出的 raw kernel（34,475,712 B）中直读：

```
Linux version 6.6.118-android15-8-gc4127a25dcf3-ab15863337-4k
  (kleaf@build-host) ... clang version 18.0.0 ... #1 SMP PREEMPT
```

| 项目 | 值 |
|------|-----|
| 内核版本 | `6.6.118-android15-8-gc4127a25dcf3-ab15863337-4k` |
| **GKI 分支 / KMI** | **android15-6.6** |
| `system_dlkm` vermagic | `6.6.118-android15-8-gc4127a25dcf3-ab15863337-4k SMP preempt mod_unload` |
| boot 头 | v4，kernel + `kernel_dtb`(2,325,312 B)，无独立 ramdisk |
| 意义 | `system_dlkm` / `vendor_dlkm` 模块**只能**跑在 android15-6.6 KMI 上 |

---

## 三、payload 分区清单（45 个，字节数实测）

| 分区 | 字节 | 大小 | 类别 |
|------|------|------|------|
| **product** | 6,291,763,200 | 5.86 GiB | 系统 |
| **vendor** | 1,731,657,728 | 1.61 GiB | 硬件 |
| **odm** | 1,638,006,784 | 1.53 GiB | 硬件 |
| **system** | 977,567,744 | 932.28 MiB | 系统 |
| **system_ext** | 823,529,472 | 785.38 MiB | 系统 |
| **mi_ext** | 456,257,536 | 435.12 MiB | 小米扩展 |
| vendor_dlkm | 57,925,632 | 55.24 MiB | 内核模块 |
| system_dlkm | 15,294,464 | 14.59 MiB | 内核模块 |
| recovery | 104,857,600 | 100 MiB | 启动 |
| boot | 100,663,296 | 96 MiB | 启动 |
| vendor_boot | 100,663,296 | 96 MiB | 启动 |
| dsp | 68,681,728 | 65.5 MiB | 固件 |
| modem | 120,586,240 | 115 MiB | 固件 |
| dtbo | 18,874,368 | 18 MiB | 启动 |
| init_boot | 8,388,608 | 8 MiB | 启动 |
| imagefv | 6,299,648 | 6.01 MiB | 固件 |
| tz | 4,325,376 | 4.12 MiB | 固件 |
| uefi | 2,883,584 | 2.75 MiB | 固件 |
| bluetooth | 1,667,072 | 1.59 MiB | 固件 |
| hyp | 1,601,536 | 1.53 MiB | 固件 |
| xbl | 1,171,456 | 1.12 MiB | 固件 |
| pvmfw | 1,048,576 | 1 MiB | 固件（pKVM） |
| countrycode | 1,048,576 | 1 MiB | 区域 |
| xbl_ramdump | 888,832 | 868 KiB | 固件 |
| keymaster | 465,920 | 455 KiB | 固件 |
| xbl_config | 289,792 | 283 KiB | 固件 |
| uefisecapp | 209,920 | 205 KiB | 固件 |
| aop | 344,064 | 336 KiB | **新一代固件** |
| abl | 344,064 | 336 KiB | 固件 |
| cpucp | 241,664 | 236 KiB | **新一代固件** |
| shrm | 155,648 | 152 KiB | **新一代固件** |
| soccp_debug | 151,552 | 148 KiB | **新一代固件** |
| featenabler | 108,544 | 106 KiB | 固件 |
| spuservice | 96,256 | 94 KiB | 固件 |
| idmanager | 71,680 | 70 KiB | 固件 |
| qupfw | 67,584 | 66 KiB | 固件 |
| devcfg | 57,344 | 56 KiB | 固件 |
| aop_config | 25,600 | 25 KiB | **新一代固件** |
| vm-bootsys | 21,504,000 | 20.5 MiB | 虚拟化 |
| cpucp_dtb | 16,384 | 16 KiB | **新一代固件** |
| soccp_dcd | 16,384 | 16 KiB | **新一代固件** |
| multiimgqti | 12,288 | 12 KiB | 固件 |
| vbmeta | 12,288 | 12 KiB | AVB |
| vbmeta_system | 4,096 | 4.1 KiB | AVB |
| mi_product | 348,160 | 340 KiB | 小米扩展 |
| aop_config / cpucp_dtb / soccp_dcd 等 | — | — | 见上 |

### 合计

| 分类 | 分区 | 合计 |
|------|------|------|
| **系统侧（可移植层）** | system + product + system_ext + mi_ext + mi_product | **8,549,466,112 B = 7.96 GiB** |
| **硬件侧（不应混用）** | vendor + odm + vendor_dlkm | **3,427,590,144 B = 3.19 GiB** |

---

## 四、文件系统

`system` / `system_ext` / `product` / `mi_ext` / `mi_product` / `vendor` / `odm` **全部为 EROFS**
（magic `0xE0F5E1E2` @ offset 1024），压缩算法 lz4hc。

`dump.erofs -s` 输出（vendor 为例）：

```
Filesystem magic number:                      0xE0F5E1E2
Filesystem blocksize:                         4096
Filesystem blocks:                            414831
Filesystem root nid:                          58
Filesystem features:                          sb_csum mtime xattr_filter 0padding
Required upstream Linux kernel version:       5.4
```

> **工具兼容性记录**：`erofs-utils 1.8.10-gee46dd74`（`dump.erofs` / `extract.erofs` / `fsck.erofs`）
> 在 `vendor.img` 与 `odm.img` 上**无法解析部分目录项** —— 根目录中 `bin` `etc` `firmware`
> `lib` `lib64` `rfs` `mitee` 等条目指向的 nid（如 53020288）落在镜像内全零区域，工具报
> `bogus i_mode (0) @ nid ...`。
> **这不是解包损坏**：`vendor.img` / `odm.img` 的 sha256 与官方 payload 清单**完全一致**（见 §五）。
> 对 `system` / `system_ext` / `product` / `mi_ext` 四个镜像解析正常。
> 本次因此改用字符串扫描建立 HyperOS vendor 的 HAL 画像（见 `移植可行性报告.md` §6）。

---

## 五、解包完整性与体积对照

### 5.1 sha256 校验（全部通过）

```
python scripts/verify_payload.py --payload payload.bin --verify-dir <dir>
```

| 镜像 | 大小 (B) | sha256（前 16 位） | 结果 |
|------|----------|--------------------|------|
| system | 977,567,744 | `8c52109b9d0c66e4…` | **OK** |
| system_ext | 823,529,472 | `392bad5e346242be…` | **OK** |
| product | 6,291,763,200 | `420ab3e1ef213129…` | **OK** |
| mi_ext | 456,257,536 | `511839c3827bd400…` | **OK** |
| mi_product | 348,160 | `fbcd937f347000c5…` | **OK** |
| vendor | 1,731,657,728 | `15379e30f12f3f12…` | **OK** |
| odm | 1,638,006,784 | `8b42094e120bf7f2…` | **OK** |
| vendor_dlkm | 57,925,632 | `194e7b0d604c1d22…` | **OK** |

> 校验过程中曾误报 `vendor` 不匹配，原因是 `payload-dumper-go` 仍在后台写入大文件；
> 待其结束后复测通过。**教训：大分区解包必须等到进程结束并核对哈希后再使用。**

### 5.2 与 TB331FC 空间对照

| 项 | HyperOS `yupei` | TB331FC ZUI |
|----|-----------------|-------------|
| 系统侧合计 | **7.96 GiB** | system_a **5.12 GiB** |
| 硬件侧合计 | 3.19 GiB | vendor+odm+dlkm ≈ **0.69 GiB** |
| super 物理容量 | （源机布局未在 payload 内） | 12.00 GiB |
| super group 上限 | — | 11.99 GiB |
| super slot A 已用 | — | 6.79 GiB |
| **super 可用余量** | — | **≈ 5.20 GiB** |

**重排验算**：保留 ZUI 硬件侧（0.691 GiB）+ 放入 HyperOS 系统侧（7.962 GiB） = **8.653 GiB ≤ 11.99 GiB** ✅

> **结论：体积不是否决项。** 可通过 `fastboot resize-logical-partition` 或重打包 `super.img`
> 容纳，无需改 GPT。（详见 `移植可行性报告.md` §7。）

---

## 六、固件层信号（SoC 代际）

payload 含 `aop` / `aop_config` / `cpucp` / `cpucp_dtb` / `shrm` / `soccp_dcd` / `soccp_debug` /
`pvmfw` / `uefi` / `spuservice` / `idmanager` 等分区，属**新一代高通平台固件布局**；
配合 `ro.bionic.cpu_variant=oryon`，可判定为骁龙 8 Elite 世代平台。

对照 TB331FC（`bengal` / SM6225 / 骁龙 685，2022 中端）：**两代以上差异**，固件与 vendor 不可互换。

---

## 七、结论摘要

- `yupei` = **HyperOS 4 / Android 17 系统 + Android 15 vendor + GKI 6.6.118（KMI `android15-6.6`）** 的全量 OTA。
- 机型为 **Xiaomi Pad 8**（Oryon 核 / 骁龙 8 Elite 级），**不是**小米平板 6 Pro。
- 系统侧体积 **7.96 GiB**，超出 TB331FC `system_a`（5.12 GiB），但在 super group 余量内可解。
- vendor / odm / 固件对应**另一颗 SoC**，**不能**与 TB331FC 硬件互换。
- 解包产物 8 个镜像 sha256 **全部校验通过**，数据可信。

---

## 修正记录（2026-10）

| # | 2026-09 版本的说法 | 实测结果 |
|---|-------------------|----------|
| 1 | 源机型「用户标注 6 Pro；codename **yupei**」（未定论） | **`yupei` = Xiaomi Pad 8**；小米平板 6 Pro 的 codename 是 `liuqin`。依据：`ro.bionic.cpu_variant=oryon` + product/odm 指纹 + 公开资料 |
| 2 | 系统侧合计 ≈ **9.26 GiB** | **7.96 GiB**（8,549,466,112 B 精确求和；原值为十进制 GB 与 GiB 混算的误差） |
| 3 | 「必须 debloat 或重划 super，否则物理装不下」 | 表述过强：**super group 余量 5.20 GiB，重排后 8.65 GiB 可容纳**，无需改 GPT。真正的否决项是 KMI 与 SoC |
| 4 | 未记录 | 补充：`vendor.img` / `odm.img` 的 erofs-utils 解析缺口（非解包损坏） |

详见 `移植可行性报告.md`。
