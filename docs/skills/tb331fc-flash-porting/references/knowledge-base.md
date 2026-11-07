# TB331FC 刷机与移植 · 全套知识库（总纲）

> 设备：**联想小新 Pad 2024 / TB331FC**（代号 `khaje`，骁龙 685 / SM6225-AD）
> 整理日期：2026-10-18 · 基于 37 份本地资料去重合并
> 阅读方式：第 0 章是速查，第 1–3 章是通用理论，第 4–8 章是本机实战，第 9 章是附录。
> **标注约定**：`【实测】`= 本机已验证；`【结论】`= 多份证据收敛；`【待核】`= 有冲突或证据不足；`【禁止】`= 已证伪，别再做。

---

## 目录

- [0. 速查卡（先读这一页）](#0-速查卡先读这一页)
- [1. 设备档案](#1-设备档案)
- [2. 基础理论](#2-基础理论)
- [3. 通用移植方法论](#3-通用移植方法论)
- [4. Recovery 路线：全链路证伪](#4-recovery-路线全链路证伪)
- [5. Root / 内核路线：唯一活路](#5-root--内核路线唯一活路)
- [6. System 移植路线：HyperOS / GSI](#6-system-移植路线hyperos--gsi)
- [7. 救砖与回滚](#7-救砖与回滚)
- [8. 逆向与芯片漏洞资料](#8-逆向与芯片漏洞资料)
- [9. 附录：命令 / 工具 / 路径 / 发布](#9-附录命令--工具--路径--发布)

---

## 0. 速查卡（先读这一页）

### 0.1 三条路线，一句话结论

| 路线 | 结论 | 依据 |
|---|---|---|
| **第三方 Recovery**（TWRP / OrangeFox） | ❌ **死路，别再投入** | ABL 存在独立于 AVB 的 recovery 原厂签名白名单【实测】 |
| **Root / 内核**（KernelSU / APatch / 定制 boot） | ✅ **唯一活路** | 不依赖 recovery，社区已验证【结论】 |
| **换 system**（HyperOS 2.0 / A14 GSI） | ✅ 已验证可用的常规路线 | 见 6.2；自包含镜像一把过 |
| **换 system**（澎湃 4.0 / A17，SDK 37） | ⚠️ **实测起到过桌面**，可复现性未闭合 | 「vendor API level 33 封顶」已于 2026-10-31 **撤回**，见 6.1.1 |

### 0.2 三条铁律（血的教训换来的）

1. **启动链必须成套**。boot / init_boot / vendor_boot / vbmeta / system 必须来自**同一发布套件**。混搭 = 900E。
2. **一次只改一个分区**。改完验证能开机，再动下一个。
3. **任何镜像实验后立刻成对回滚槽位**（见 7.4）。

### 0.3 已证伪清单（**禁止**重复投入）

**镜像侧（AVB / 镜像伪装）**
- 仅改 OF 编译参数 / 内核打包方式 / 清空 cmdline
- testkey vbmeta flags=3、flags=0 + 全哈希重算
- TWRP / OF ramdisk 套原厂头
- 有效内容改 1 bit + 匹配哈希（证明锁定的是**有效内容**而非 padding）
- `of_algnone`：footer alg=NONE + 自洽哈希 + 原厂 salt/prop/96MB 头
- 把 OF 镜像塞进 boot 分区（含"头部一字不差"的 96MB 正确版 + 匹配 vbmeta）
- 用 64KB vbmeta 解决 ZUI16 启动（反导致系统无法启动）

**固件侧**
- 9008 降级 ZUI15 abl（写入成功、读回校验一致，第三方 rec **仍被拦**；且 ZUI15 abl + ZUI16 系统起不来）
- 运行时翻 flag（`oem unlock` 唯一入口需 Lenovo 签发的 `unlock.img`）
- 私钥伪造（Elm 链 RSA-2048，公开检索零泄露证据）
- TWRP 20260827 / 20260814 / repack 去假日期三个版本 → 一律回 fastboot

**系统侧**
- ~~澎湃 4.0 / Android 17 GSI：vendor API level 33 vs 要求 `ro.llndk.api_level=202604` → 启动即中止 → 900E~~ → ❌ **此条已撤回（2026-10-31 复核）**：A17 实测起到过桌面，见 6.1.1。
- 澎湃 4.0（A17）即使去掉 `tz_log_dlkm` + 关 `qseelogd`，真机仍在 ≤10 s 掉 900E（2026-10-24 实测，见 `E:\rom\docs\实验记录_A17_notz双补丁_2026-10-20.md` §7）。这只说明**补丁方向不对**，不等于 A17 不可行。
- A14 GSI（HyperOS 2.0 MysticGSI）是**已验证可用的常规路线**，但不再是"唯一可行"。

**解锁侧**
- ~~改 `sn_AAAAAAAA.img` 十六进制中的 `AAAAAAAA` 为自身 SN~~ 免邮件技巧 → ❌ **不可用**（2026-10-18 实测，见 1.4）

### 0.4 当前状态（2026-11-07 刷新；2026-10-18 原文见本节末，不改历史）

- 设备：**原厂 ZUI 16.0.544（A14 / SDK 34）正常开机**，a 槽 9008 全量回到原厂；`persist` 已于 2026-11-01 修复（见 7.8）。
- **澎湃 4.0（A17）当前不在机上**。10-26 起到过桌面那一套的资产全在 `E:\rom\work\a17stage\`；一键刷回 `tools\flash_a17_working.ps1`（已 dry-run 校验，**未跑过真机**）；判定实验 `tools\a17_single_var_vbmeta.ps1`（见 6.1.1 末）。
- ⚠️ **基线变了（重要）**：10-27 之前**所有** A17 观测都取自 persist **整块全零** 的机器。persist 修好后 ACDB / 传感器标定 / registry 都可用，旧观测只能与旧观测比，**不能拿来预测现在的表现**；重跑必须重记。
- OrangeFox 编译产物已发布（GitHub `dsshhgg/TB331FC-TWRP` 分支 `fox-12.1`），**但设备上进不去**（自 10-18 起未变）。
- 主路径仍是：**KernelSU / APatch 刷 boot**。
- 2026-10-18 原文：设备为完全干净原厂链（a 槽），ZUI 16.0.544 可开机。

### 0.5 从零到 Root 的最短路径（社区已验证）

```text
① 开发者选项开 USB 调试 + OEM 解锁
② fastboot getvar all 2>result.txt  → 取出 ufs_sn 与 serialno
③ 电脑访问 m.zui.com/iunlock → 板块选「拯救者 Y700 五代」
   序列号=serialno，Bootloader_sn=ufs_sn → 取回 sn.img（必须 356 字节）
   ※ 无免申请捷径，改十六进制那招不可用（见 1.4）
④ fastboot flash unlock sn.img → fastboot oem unlock-go
   音量键选 UNLOCK THE BOOTLOADER → 电源键确认 → 黄色感叹号 = 解锁成功
⑤ 取原厂 init_boot（线刷包解出，或 9008 回读当前槽位）
⑥ KSU / Magisk / APatch 修补 → fastboot flash init_boot patched.img
   （fastboot 受限时走 7.2.1 的 9008 回写通道）
⑦ adb shell su -c id  → uid=0 即成功
```

> 想省事可直接刷现成内核：见 5.2 的 `boot-main.img`（自带 KernelSU + SusFS），刷 **`boot`** 而非 init_boot。

---

## 1. 设备档案

### 1.1 硬件

| 项 | 参数 |
|---|---|
| 商品名 | 联想小新 Pad 2024 |
| 型号 | **TB331FC**（料号 `TB331FC TAB 8G+128GLG-CN`） |
| 发布 | 2023-10（舒视版 2024-05） |
| SoC | 高通骁龙 685 **SM6225-AD**（bengal / khaje）+ Adreno 610 |
| CPU | 4×Kryo 265 Gold (A73) 2.8GHz + 4×Kryo 265 Silver (A53) 1.9GHz |
| 内存/存储 | 8GB LPDDR4x + 128GB/256GB UFS 2.2，支持 MicroSD（≤1TB） |
| 屏幕 | 11 英寸 1920×1200，90Hz，16:10 |
| 网络 | **仅 WiFi**（无 SIM），蓝牙 5.1 |
| 摄像头 | 前后各 800 万 |
| 电池/重量 | 465g |
| 系统 | ZUI 15（A13）→ **ZUI 16.0.544（A14）** → ZUI 17 |

**易混淆机型**（刷错必砖）：

| 型号 | 机型 |
|---|---|
| **TB331FC** | 小新 Pad 2024（本机，骁龙 685） |
| TB323FU | 小新 Pad 2024 国际版（Global ROM，可参考互刷） |
| TB371FC | 小新 Pad Pro 12.7（骁龙 870，另一套教程） |
| TB322FC | 旧 ZUI，**无白名单**（佐证白名单是联想后来加的） |

### 1.2 分区与启动【实测】

| 项 | 值 |
|---|---|
| 分区方案 | **A/B（slot-count=2）+ 独立 recovery 分区** |
| `recovery` | `0x6400000` = 100MB |
| `boot` | `0x6000000` = 96MB |
| `vbmeta` | 分区 `0x10000` = 64KB；**文件** ZUI16=8KB(Flags=0)，ZUI15=64KB(Flags=2) |
| `super` | 12GB 动态分区 |
| `abl` / `xbl` | `0x100000` / `0x380000`，**Critical Partition（fastboot 禁刷，只能 9008）** |
| `init_boot` | 8MB |
| `vendor_boot` | 96MB（含 **cmdline** 与触控固件） |
| 解锁状态 | `unlocked: yes`，`secure: yes` |
| `version-bootloader` | **空**（无法读 abl 版本，只能靠"能否进 rec"判断） |
| `vbmeta_vendor` | 无 |

**原厂 recovery 头特征**：header v4，`kernel=0`（GKI 从 boot 带内核），`os_version=0`，`sig_size=0`，**cmdline 为空**。

**原厂 boot kernel** raw 大小 `46,819,840`；AVB 对 recovery 的哈希只覆盖有效内容 `14,577,664` 字节（padding 不计）。

### 1.3 AVB 信任链【实测】

| 对象 | 算法 / 密钥 |
|---|---|
| **根 vbmeta** | ALG=2 **SHA256_RSA4096**，公钥 sha1 `2597c218aae470a130f61162feaae70afd97f011` ≡ **AOSP `testkey_rsa4096.pem`** |
| `vbmeta_system` | ALG=1 SHA256_RSA2048，公钥 sha1 `cdbb7717…`（与根 vbmeta 的 4096 钥不同）【待核：09 文档记为"≠testkey"，另有资料认为该指纹即 AOSP testkey RSA2048，二者系与不同 PEM 比对所致】 |
| 嵌入镜像内的 vbmeta | ALG=**NONE**（无签名，仅哈希簿记） |
| ABL 内嵌钉钥 | 就是 testkey4096，`ValidateVbmetaPublicKey` memcmp 1032 字节 |

**关键**：AVB 这层**能过**（testkey 公开），但**不足以启动第三方 recovery**——ABL 还另有独立校验。详见第 4 章。

### 1.4 官方解锁与固件

**解锁（ZUI 官方通道）**：https://m.zui.com/iunlock

```bash
adb reboot bootloader          # 屏幕显示 SN 与 DEVICE STATE - locked
fastboot flash unlock sn.img   # 刷入官方邮件中的解锁文件
fastboot oem unlock-go         # 也见 fastboot oem unlock_go（下划线写法）
# 点音量上下键让 UNLOCK THE BOOTLOADER 亮起 → 电源键确认 → 自动重启 + 黄色感叹号 = 成功
```

- 每账号每年限 **3 台**；新设备有等待期；部分硬件不支持
- ~~免邮件技巧：改 `sn_AAAAAAAA.img` 十六进制中的 `AAAAAAAA` 为自身 SN~~ → ❌ **已证伪，不可用**（见下方"免邮件技巧已证伪"）
- 解锁即失保、不可回锁、官方 FOTA 失效（实测刷回官方 CN ROM 后仍可 OTA）

**申请 sn.img 的实操细节**【社区教程，2026-07】

来源：酷安 @栞那daisuki《联想小新平板2024解锁Bootloader并获取Root权限教程》（2026-07-24）

| 步骤 | 要点 |
|---|---|
| 1. 取号 | `fastboot getvar all 2>result.txt`，在 result.txt 里找 **`ufs_sn`** 和 **`serialno`** |
| 2. 填表 | 联想解锁站**用电脑访问**（手机访问不行）；板块选 **「拯救者 Y700 五代」**（列表无 TB331FC 选项） |
| 3. 字段映射 | **序列号 = `serialno`**，**Bootloader_sn = `ufs_sn`**（填反必失败） |
| 4. 邮箱 | 建议网易邮箱 |
| 5. 时机 | **建议中午 12 点前申请**，否则大概率提示"今日满额" |
| 6. 校验 | 下载的 `sn.img` **必须是 356 字节**，不是就说明填错了 `ufs_sn`，重申请 |

**常见报错**

| 报错 | 处理 |
|---|---|
| `Flashing is not allow in lock state` | 需**降级**后再解（联系教程作者或 @昱夕） |
| 文件报错 | 检查 `sn.img` 是否 356b、申请时 `ufs_sn` 是否填错 |

> ⚠️ 与本机既有记录的**口径差异**：本机资料写的是 `fastboot oem unlock-go`，教程写 `unlock_go`；且教程未提 `flashing unlock_critical`。两种写法都记，实测时哪个通过用哪个。

**❌ 免邮件技巧已证伪（2026-10-18）**

**原说法**（流传于同系 TB371FC 教程）：把 `sn_AAAAAAAA.img` 用十六进制编辑器把 `AAAAAAAA` 换成自己的 SN，即可跳过邮件申请。

**实测结论：不可用。**

**为什么必然不可用**（与上表互证）：

1. **`sn.img` 是服务端签发的，不是纯文本模板**。356 字节是固定长度，其中含针对该设备号的校验数据；本地改十六进制会破坏校验 → `oem unlock` 的验签函数（`abl` 内 `0x85214`）直接失败，打印 `oem unlock fail`（字符串 @0x9e9c6，见 4.5 节 ABL 侧逆向）。
2. **"自己的 SN" 本身有歧义**：`getvar all` 里同时存在 `serialno` 与 `ufs_sn` 两个号，而解锁站要求**序列号=serialno、Bootloader_sn=ufs_sn**（见上表）。改单个 `AAAAAAAA` 无从对应这两个字段。
3. 与 §4.5 一致：`oem unlock` 是**唯一**能把 flag `0xd4bad` 置 1 的入口，且必须先通过 Lenovo 签发的 `unlock.img` 验签 —— 这层签名就是该技巧绕不过的墙。

> ⇒ **没有免申请通道**。唯一正规路径 = 上表的官方申请（注意 12 点前、电脑访问、板块选 Y700 五代）。

**固件来源**

| 来源 | 链接 / 位置 |
|---|---|
| 联想官方 CDN（ZUI 17.0.460，4.4GB） | `https://ota-cdn.lenovo.com/firmware/2025618123959620-7715.zip` |
| lolinet 镜像（~13.5GB） | `https://mirrors.lolinet.com/firmware/lenowow/2024/Xiaoxin_Pad_2024/` |
| 本地 ZUI 15.1.105 全量包 | `240412_Lenovo_XiaoxinPad_2024_TB331FC_ZUI_15.1.105_…` |
| 线刷包结构 | `prog_firehose_ddr.elf` + `rawprogram*.xml` + `patch*.xml`（QFIL Flat Build） |

> ⚠️ QFIL **严禁勾选"全部格式化"**（会丢 IMEI/SN/校准数据）。

---

## 2. 基础理论

### 2.1 分区结构

| 分区 | 作用 |
|---|---|
| bootloader (ABL) | 初始化硬件，决定进系统 / fastboot / recovery；**本机含 recovery 白名单** |
| boot | 内核 + ramdisk（正常启动） |
| recovery | 内核（本机为 GKI，从 boot 带）+ recovery 程序 |
| init_boot | Android 13+ 的 ramdisk；本机 KSU LKM 注入点 |
| vendor_boot | vendor ramdisk + **cmdline**（触控固件、SELinux 开关） |
| system | Android 框架与应用（GSI 替换的就是它） |
| vendor | 厂商 HAL / 驱动（**闭源 blob，改不了**） |
| vbmeta | AVB 验证元数据 |
| super | 动态分区容器，内含 system/product/system_ext/vendor/odm 逻辑分区 |
| dtbo | 设备树叠加（触控/显示相关） |

**A/B 槽位**：

```bash
fastboot getvar current-slot
fastboot set_active a         # 或 fastboot --set-active=a
```

### 2.2 刷机方式对比

| 方式 | 入口 | 风险 | 常清数据 | 用途 |
|---|---|---|---|---|
| OTA | 系统更新 | 低 | 否 | 官方升级 |
| 卡刷 | Recovery 刷 zip | 中 | 看 ROM | 第三方 ROM、Magisk |
| 线刷 | fastboot / 厂商工具 | 中高 | 多数会清 | 救砖、降级 |
| **fastbootd** | `adb reboot fastboot`（用户态） | 中 | 否 | **刷动态分区（super 内逻辑分区）必用** |
| 深层线刷 | 高通 9008/EDL、MTK SP Flash、Odin | 高 | 是 | 硬砖急救 |

### 2.3 关键模式辨析（本机特有）

| 模式 | 设备管理器 | PID | 说明 |
|---|---|---|---|
| **fastboot（bootloader）** | Android Bootloader Interface | — | 刷物理分区 |
| **fastbootd** | Android Fastbootd | — | **用户态**，刷 super 内逻辑分区；`getvar is-userspace` = yes |
| **900E** | Qualcomm HS-USB **Diagnostics 900E** | `05C6:900E` | Sahara **崩溃转储**，firehose 装不进 |
| **9008** | Qualcomm HS-USB **QDLoader 9008** | `05C6:9008` | 标准 EDL，可 QFIL 整包 |

### 2.4 AVB / 启动状态

- **green** = 锁定 + 官方密钥；**yellow** = 锁定 + 用户自定义密钥；**orange** = 已解锁
- 锁定态：AVB 失败是致命的；解锁态：任何签名都能启动（仅 orange 警告）
- 关验证：`fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img`

### 2.5 本机 Bootloader 限制【实测】

| 命令 | 状态 |
|---|---|
| `fastboot boot xxx.img` | ❌ **不支持**（`unknown command`，连官方镜像都不行） |
| `fastboot fetch` | ❌ 不支持 |
| `fastboot flash abl/xbl` | ❌ Critical Partition，禁刷 |
| `fastboot reboot recovery` | ⚠️ 对第三方 rec 不可靠 |
| `adb reboot recovery` | ✅ 可靠 |
| 实体键 音量上+电源 | ✅ |
| 进 9008 | 完全关机 → 同时按住 音量+ 与 音量− → 插 USB（另有一说仅音量+，两法都试） |

### 2.6 Root 方式对比

| 方式 | 注入点 | 特点 |
|---|---|---|
| Magisk | boot / init_boot 修补 | 生态最全，用户态痕迹多 |
| **KernelSU** | 内核级（本机打 `init_boot` LKM） | 内核态，配合 SusFS 隐藏更好 |
| **APatch** | boot / kernel patch | 本机已备 APK |
| GKI 定制内核 | 直接刷 `boot` | 本机有现成社区内核（见 5.2） |

> **KSU LKM vermagic 可以不一致**——两边都有 `modversions` 时内核 `same_magic()` 跳过 UTS_RELEASE，只比 flags。KMI 对得上即可。

---

## 3. 通用移植方法论

### 3.1 刷机包（卡刷 zip）结构

```
rom.zip
├── META-INF/com/google/android/
│   ├── update-binary       # recovery 执行的安装器
│   └── updater-script      # Edify 脚本：机型校验/挂载/格式化/写入
├── system/{app,framework,lib,lib64,bin,etc,media,build.prop}
├── boot.img
└── (vendor/ 等)
```

移植主要改动：`system` 下少数目录 + `boot.img` + `META-INF` 刷机脚本。

### 3.2 移植核心原则

> **保留系统框架与 UI（system 的 app/framework），替换所有硬件相关部分（驱动、库、bin、boot.img、刷机脚本）。**

**底包 vs 源包**（本机已正式锁定 2026-09-26）：

| 角色 | 作用 | TB331FC 用什么 |
|---|---|---|
| **底包（base）** | 硬件适配：boot / vendor / odm / 内核 / HAL / 固件 | **原厂 ZUI 16.0.544** |
| **源包（source）** | 系统体验：system / product / system_ext / UI | HyperOS（pipa 小米平板 6 / yupei HyperOS4） |

> **硬件认底包，UI 认源包。不要拿别的机型 boot/vendor 当底。**

### 3.3 标准流程（八步）

1. **解包对比**（Beyond Compare：底包左、源包右，"差异项但不含孤立项"）
2. 替换 `system/app`、`system/framework`
3. **处理硬件目录**：`system/lib(64)`、`bin` **不要整目录覆盖**，底包驱动 so 必须保留；`system/etc` 通常保留底包
4. 替换驱动/RIL 相关（`libril.so`、`libreference-ril.so` 等）
5. 替换 `boot.img`（用底包的，否则卡第一屏）
6. 改 `build.prop`（`ro.product.model/device`、`ro.build.display.id`；**保留源包的 `ro.xda.version`/`ro.modversion`**）
7. 改 `META-INF`：删首行机型 assert，确认挂载点与分区大小，签名打包
8. Recovery 四清/格式化 data → 刷入 → 测试

### 3.4 开包 13 项常规处理（社区教程精华，按顺序排查）

| # | 处理项 | 操作 | 不处理的表现 |
|---|---|---|---|
| 8.1 | **换三件套** | `init` + `libfs_mgr.so` + `libfs_mgr_binder.so` 换成同安卓版本 GSI/类原生文件（A13+ 需换 lib64） | 卡一重启 / 直接进 fastboot |
| 8.2 | **SELinux** | 删 `system_ext/etc/selinux`、`product/etc/selinux` 下 mapping 文件夹；或整体换同版本 SELinux。**底包 SELinux 别换** | 重启到 fastboot / 卡一重启到 rec |
| 8.3 | **换底包** | 按 `system_ext/apex` 下 VNDK 版本选底包（vndk30→A11、31→A12、32→A12.1…） | 卡一 |
| 8.4 | **宽容 permissive** | 刷 permissive v5 补丁；或小新 patch 3 | 一屏重启 fastboot / 卡一 / 卡二 |
| 8.5 | **处理 BPF** | 按内核版本换 `libbpf_android.so` 或 `com.android.tethering.apex/capex` | 卡一 20 秒重启；卡二 data 只加载 <200MB |
| 8.6 | **删 cache 软链** | 删 system 根 cache 软链，建同名空文件夹（静态分区需处理） | 卡二 / 卡一 |
| 8.7 | **删 media.settings.xml 配置** | 删 build.prop 中 `media.settings.xml=…` 一行 | 卡二 / 卡一重启 |
| 8.8 | **加 init.gsi.rc** | 放 `system_ext/etc/init` 并补权限 | 卡二 |
| 8.9 | **补 GSI build 属性** | 见下方代码块 | 不加可能重启 |
| 8.10 | **删底包 overlay** | 删 `vendor/overlay` 下底包 overlay | 卡二重启（flyme 常见） |
| 8.11 | **权限问题** | 换打包工具/底包；A11 底需补 `rw-system`、`vndk.rc` | 无限软重启 / 卡二 |
| 8.12 | **keymaster** | 换底包，或刷写 keymaster 分区 | 卡二 / 卡一 |
| 8.13 | **替换 sensorservice** | 换本机 `libsensorservice`（flyme/color 常见） | 卡二 |

**8.9 必补属性**：

```properties
# GSI
ro.cp_system_other_odex=0
ro.nnapi.extensions.deny_on_product=true
# Other
ro.crypto.metadata_init_delete_all_keys.enabled=false
persist.sys.disable_rescue=true
ro.control_privapp_permissions=disable
# MIUI / 澎湃机型追加
ro.miui.region=cn
# apex 规则二选一：看 system/apex 是文件夹还是文件
ro.apex.updatable=false    # system/apex 是文件夹时
ro.apex.updatable=true     # system/apex 是文件时
```

**BPF / 内核版本门槛**：

| 系统版本 | 最低内核要求 |
|---|---|
| 安卓 13 | 4.9（4.4 需处理 BPF） |
| 安卓 14 | 4.14（4.4/4.9 需处理） |
| 安卓 15 | 4.19 |
| 安卓 16 beta2+ | 5.4 |

### 3.5 分区结构判断（看卡刷包）

| 卡刷包特征 | 分区方案 |
|---|---|
| br/dat 结构，无独立 odm | 静态 A/B |
| br/dat 结构，有 odm | 动态 only A |
| super 打包或 payload 打包 | **动态 A/B（本机）** |

**文件系统**：老机型多只认 ext4；本机 system 为 **ext4**，无 EROFS。

### 3.6 GSI 基础

**命名规则（phhusson）**：`system-<processor>-<partition>-<gapps>-<su>.img`

- processor: `arm64` / `arm` / `a64`
- partition: `a`(A-only) / `b`(A/B)
- gapps: `v`(vanilla) / `g` / `o`(Go) / `f`(FLOSS)
- su: `S`(带 root) / `N`

**刷 GSI 标准流程**：

```bash
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
adb reboot fastboot                      # 进 fastbootd（不是 bootloader）
fastboot flash system system.img
fastboot -w                              # 换 ROM/降级必做
fastboot reboot
```

空间不足时：`fastboot delete-logical-partition product_a`（后缀与 system 槽位一致）

**刷前检查**：

```bash
adb shell getprop ro.treble.enabled   # 必须 true
adb shell getprop ro.product.cpu.abi  # arm64-v8a → arm64 GSI
adb shell getprop ro.vndk.version     # 33
```

### 3.7 TWRP / OrangeFox 编译

**两条路线**：源码编译设备树 / `twrpdtgen` 从 boot.img（A/B）或 recovery.img（A-only）自动生成模板。

**环境**：Ubuntu 20.04+，磁盘 ≥50GB（TWRP）或 ≥45GB（fox_12.1）/ 85GB（fox_14.1），内存 8GB+，Python 2.7。

```bash
# TWRP
repo init --depth=1 -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1
# OrangeFox
repo init -u https://gitlab.com/OrangeFox/Manifest.git -b fox_12.1

python3 -m twrpdtgen -o <manufacturer>/<device> /path/to/boot.img   # 生成设备树
```

**关键配置**

| 文件 | 作用 |
|---|---|
| `BoardConfig.mk` | 分区大小、内核参数、`TW_*` recovery 选项、加密 |
| `recovery.fstab` / `twrp.fstab` | **data 解密成败的关键** |
| `AndroidProducts.mk`、`<device>.mk` | lunch 目标 |
| `recovery/root/` | keymaster、init（影响解密） |

**OrangeFox 专属**：`FOX_*` / `OF_*` 变量**必须 export 在 shell 或 `vendorsetup.sh`，不能写进 .mk**。

常用：`FOX_AB_DEVICE=1`、`OF_AB_DEVICE_WITH_RECOVERY_PARTITION=1`、`OF_DEFAULT_KEYMASTER_VERSION=4.1`、`FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1`、`ALLOW_MISSING_DEPENDENCIES=true`、`LC_ALL=C`。

**云端构建（无本地环境）**：GitHub Actions —— `kinguser981/OrangeFox-Recovery-Builder-2024`、UWU-TEAM Builder、Colab Jupyter 方案。

---

## 4. Recovery 路线：全链路证伪

> 这是本机投入最多、结论最硬的一章。**结论已定，别再重复实验。**

### 4.1 时间线

| 日期 | 事件 |
|---|---|
| 2026-09 | OrangeFox 设备树搭建完成，本地/CI 编译通过 |
| 2026-10-03 | **决定性实验**：ZUI15 原厂 recovery 刷入 `recovery_a` → ✅ 能进；自编译 OF → ❌ 被拦 |
| 2026-10-03 | **9008 换 ZUI15 abl**：写入成功、读回确认两槽均为 ZUI15 `349b5b40…`，第三方 rec **仍被拦** |
| 2026-10-05 | `of_algnone` 失败 → **镜像侧假设全部证伪** |
| 2026-10-06 | 静态逆向：`VerifiedBootDxe`（XBL）终审门定位完成 |

### 4.2 决定性实验

```
把 ZUI15 原厂 recovery（联想签名，与 ZUI16 那份内容差 14,256,200 字节）
  刷进 recovery_a  →  ✅ 能进 recovery
我们编译的 OrangeFox   →  ❌ 被拦
```

⇒ **门槛是"联想对 recovery 镜像的签名"，与 ZUI 版本无关。**

### 4.3 启动行为对照表【实测】

| vbmeta | recovery | 结果 |
|---|---|---|
| 原厂原样 | 原厂 | ✅ 可进 |
| 原厂 + disable-verity | OF / TWRP | ⏭ 跳过 rec，进系统 |
| testkey flags=3 + chain | OF（原厂模板头） | ❌ 回 fastboot |
| testkey flags=0 + 全哈希 | OF（哈希已重算） | ❌ 回 fastboot |
| 原厂 | 有效内容改 1 bit + 匹配 testkey vbmeta | ❌ |
| 原厂 | **padding 改 1 字节** | ✅ 仍可进 |
| 原厂 | OF 塞进 boot 分区 + 匹配 vbmeta | ❌ 仍显示原厂 recovery 菜单 |
| 任意 | `of_algnone`（footer alg=NONE + 自洽哈希） | ❌ 回 fastboot |

**三条推论**

1. AVB 侧已可伪造（testkey + 更新哈希）仍失败 → 拦截不在 AVB 层
2. 有效内容改 1 bit 即拒绝，padding 可改 → 锁定的是约 14.5MB **有效区**
3. 三条入口（fastboot reboot recovery / adb reboot recovery / 实体键）均无效 → 不是入口问题

### 4.4 白名单的静态位置（只读不刷）

**信任链分层**：

```
ABL (libavb)
  └─ 读 vbmeta.img → ValidateVbmetaPublicKey 对钉钥(testkey4096)/avb_custom_key
     → avb_vbmeta_image_verify → boot state
           ↓
XBL (VerifiedBootDxe)  ← ★ 白名单在这里，与 AVB 钥无关
  └─ +0x28 LoadImageAndAuth：名/长度/哈希/签名 校验 → state ∈ {0,1,2,3}
  └─ +0x18 终审门：state=3 ⇒ 恒返 0x50 ⇒ ABL 报 'VBVerifyImage failed' ⇒ 回 fastboot
```

**放行仅三态**：

| state | 含义 | 是否放行 |
|---|---|---|
| 0 | GREEN，oem 验签通过 | ✅ |
| 1 | 解锁机，跳过验证 | ✅（但本机 ABL 另有 recovery 签名校验） |
| 2 | ORANGE，**内嵌密钥验签成功**（`[0xe1f2]=1`） | ✅ |
| 3 | UNDEFINED，`[0xe1f2]=0` | ❌ **恒返 0x50** |

**关键**：XBL 内嵌的 OEM 证书（`cert@0xa406`）是**第三把 RSA2048**，既非 testkey4096 也非 vbmeta_system 钥 → **XBL 白名单与 ABL 的 AVB 根信任是两套独立信任域**。这解释了为什么 testkey 重签没用。

### 4.5 ABL 侧拦截链（字节级）

```
0x1be18: blr [proto+0x28]   ; LoadImageAndAuth
        失败 → x21=错误码 → 0x1b810 汇合
0x1b810: tst w20,#0xff      ; w1=0 → 恒 eq → 死代码
0x1b844: bl 0x2cf40          ; 读全局 flag 0xd4bad（1=unlocked / 0=locked）
0x1b848: tst w0,#0xff        ; flag==0 → 无视错误续行（本机已解锁，flag≠0 → 必须鉴权成功）
0x1b8a0: b 0x1b818          ; 鉴权失败 → 0x1b828 mov x0,x21 → ret 错误码
        → 调用者 cbz x0 不过 → 回 fastboot
0x6a30  = 真正执行恢复启动的函数
```

`state==3` 的另一条路：打印 "Your device is corrupt…" → 忙等 10 秒 → `0x34f70` **关机**（实测未出现，说明走的是回 fastboot 分支）。

**fastboot 写旗路径**（§4.2 破解）：`flashing lock`→(0,0)、`oem unlock`→(0,1)、`unlock_critical`→(1,1)、`lock_critical`→(1,0)。置 1 的唯一入口 = `oem unlock` 且需 Lenovo 签发 `unlock.img` ⇒ **运行时翻旗路线 = 官方解锁，与"免验签"矛盾**。

### 4.6 补丁点（**只读记录，当前一律不执行**）

| ID | 地址 | 现指令 | 改为 | 说明 |
|---|---|---|---|---|
| **PA**（首选） | 0x1b828 | `mov x0,x21` | `mov x0,xzr` | 唯一共享返回点，恒返 0 → 中和全部拦截；风险：加载硬错误也归零 → 可能挂死 |
| PB-b | 0x1bb78 | `mov x21,x0` | `mov x21,xzr` | +0x20 finalize 强制成功（PA 的最小等价替代） |
| PB-a | 0x1b8a0 | `b 0x1b818` | `b 0x1b8a4` | **本机冗余**（flag=0 不走此路） |
| P2 | 0x1b844 | `bl 0x2cf40` | `movz w0,#0` | flag 恒读 0 |
| P3（保险） | 0x34fa8 | `mov w0,#2` | `mov w0,#1` | 仅在实测出现 10 秒红屏关机时考虑 |

**不执行的技术依据**（离线证据链未闭合）：
1. XBL 对 abl 的完整性/签名校验是否存在——离线无法证伪，改 .text 可能直接引导失败
2. +0x28 半程依赖 TZ 接受镜像 → PA 可能拿到未就绪镜像
3. +0x20 之后、0x6a30 之前是否还有协议侧最终否决（离线不可见）

### 4.7 私钥伪造可行性

| # | 证书 | 位置 | spki_sha1 |
|---|---|---|---|
| 1 | CN=Elm Attestation CA（叶子） | abl 0x1238 | `3572e20361f22fb3c41efd4c1554e144e1317ede` |
| 2 | CN=Elm Attestation CA, O=QUALCOMM, OU=Lenovo | 0x1622 | `d36457330c004f0b12131dffc3d58385efe03a59` |
| 3 | CN=Elm Root CA, O=LENOVO（自签根） | 0x1a40 | `3e100b8e0ac6c23641a5ce084fb58f6ba30f4a97` |

**检索结论：零命中。** RSA-2048 不可分解 ⇒ 路线无可行性证据，仅保留按指纹监控泄露库的低优先级动作。

**最接近的先例**：`Lenovo testkey vulnerability`（polygraphene / TB322FC）—— ZUI 1.5.10.138 **及更早**可免解锁用 EDL 刷 testkey recovery。**本机 ZUI15.1.105 起已拦**【实测】，佐证白名单是联想后来加的。

**社区动向**：全网无人公开绕过本机 recovery 白名单；绕过案例均为 boot/root 路线。

### 4.8 OrangeFox 构建备忘（可复现，虽然刷了也进不去）

```bash
source build/envsetup.sh
export FOX_USE_TWRP_RECOVERY_IMAGE_BUILDER=1
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
lunch fox_TB331FC-eng        # 或 twrp_TB331FC-eng（取决于 vendorsetup.sh）
mka adbd recoveryimage
```

必须：`FOX_AB_DEVICE=1`、`OF_AB_DEVICE_WITH_RECOVERY_PARTITION=1`、**cmdline 必须为空**（构建会注入 `buildvariant=eng`，发布前清零 header cmdline 字段）、可打包原厂 kernel、头 `os_version=0`/`sig_size=0`、CI/本地**禁用 ccache**、不要用已废弃的 `FOX_VERSION`。

**刷入（原厂 abl 下预期失败，仅供流程）**：

```bash
fastboot --disable-verity --disable-verification flash vbmeta_a vbmeta.img
fastboot --disable-verity --disable-verification flash vbmeta_b vbmeta.img
fastboot flash recovery_a OrangeFox-*.img
fastboot flash recovery_b OrangeFox-*.img
fastboot --set-active=a
adb reboot recovery
```

---

## 5. Root / 内核路线：唯一活路

### 5.1 为什么这条路能走通

Root 走 **boot / init_boot 分区**，不经过 recovery 分区，因此**不触发 ABL 的 recovery 白名单**。

### 5.2 现成社区内核 ★ 直接可用

**[yxyyds666/TB331FC-Kernel](https://github.com/yxyyds666/TB331FC-Kernel)**

| 项 | 内容 |
|---|---|
| 基线 | Google GKI `android13-5.15.167_r00`（**与 stock KMI 一致**） |
| 特性 | 原版 KernelSU（325xx+）、SusFS 2.2.0 隐藏、矩阵云编译 |
| 变体 | `boot-main.img`（日常）/ `boot-debug.img`（排障）/ `boot-feature.img`（实验） |
| 最新版 | 1.3.2（2026-08-09） |
| 回滚 | 仓库自带 `boot_a.img`（96MiB 原厂） |

```text
https://github.com/yxyyds666/TB331FC-Kernel/releases/download/1.3.2/boot-main.img
```

> ⚠️ **不要注入非空 boot cmdline** —— 高通 ABL 有缺陷会不开机（作者实测）。

### 5.3 boot 还是 init_boot？（两类资料对照）

| 路线 | 改哪个分区 | 来源 |
|---|---|---|
| **KSU / Magisk 修补 ramdisk** | **`init_boot`** | 社区教程（2026-07）实测；本机 boot loop 修复也是 `fastboot flash init_boot_a ib_patched.img`【实测】 |
| **换整个内核（GKI）** | **`boot`** | `boot-main.img` 自带 KernelSU，刷 `boot` |
| APatch | boot 或 kernel patch | 本机已备 APK |

> ⇒ **要 KernelSU/Magisk → 打 `init_boot`；要换内核 → 刷 `boot`。两者别混**（见 5.4 红线）。

### 5.3.0 ⚠️ 打 init_boot 补丁必须保留的两项【实测，最易踩】

修补 `init_boot` 时若 ramdisk 被精简/重建，**必须保留**这两个文件，否则：

| 文件 | 大小 | 丢了会怎样 |
|---|---|---|
| `lib/firmware/novatek_ts_fw.bin` | 196,608 B | **触控失效**（novatek 触摸屏固件） |
| `system/etc/ramdisk/build.prop` | 1,302 B | **密度错误**（240 密度修复） |

> ⇒ 典型症状：root 拿到了，但**屏点不动或显示比例怪**。修法是用原厂 `init_boot_a_原始.img` 重新修补。

### 5.3.1 实操流程（社区教程版，含无 fastboot 的 9008 通道）

**A 路：有 fastboot（最快）**

```bash
# 1. 取原厂 init_boot（从线刷包 images/ 解出，或用刷机匣 9008 回读当前槽位的 init_boot）
# 2. root 管理器（KSU / Magisk / APatch）→ 安装 → 选择并修补该文件
# 3. 刷入同槽位
fastboot flash init_boot patched.img      # 当前在 b 槽就刷 init_boot_b
fastboot reboot
```

**B 路：fastboot 受限 → 9008 回读/回写**（见 7.2.1）

```
刷机匣读信息 → adb reboot edl → 回读 init_boot → 传平板修补 → 传回电脑 → 再进 9008 → 刷入 → 重启
```

**验证**：

```bash
adb shell su -c id                                  # 期望 uid=0
adb shell getprop ro.boot.vbmeta.device_state      # locked / unlocked
adb shell getprop ro.boot.verifiedbootstate        # green / orange
```

> ⚠️ 管理器检测不到 → 先确认刷的是不是**当前槽位**的 `init_boot`，以及文件是否真刷入。
```

**验证**：

```bash
adb shell su -c id                                  # 期望 uid=0
adb shell getprop ro.boot.vbmeta.device_state      # locked / unlocked
adb shell getprop ro.boot.verifiedbootstate        # green / orange
```

### 5.4 红线

- **不要叠刷**：HyperOS v2 包已内置 KernelSU boot，**再刷 `boot-main.img` 会冲突**（root 冲突 / 不开机 / 模块异常）
- 旧 Magisk / 其它 root 先清理
- 管理器检测不到 → 先确认包内 boot 是否真刷入
- 非官方回锁 BL 极大概率变砖

### 5.5 boot loop 血案：PID1 fd 泄漏【实测】

**现象**：`system_server` 进程数 0、`/data/tombstones` 64 个、每约 5 秒崩一次
**签名**：`Abort message: 'JNI FatalError called: (system_server) Not allowlisted (3): /null'`，栈在 `libandroid_runtime.so` 的 `FileDescriptorInfo::CreateFromFd`

**根因链**：

```
kai_init.sh 在 stage1 执行  exec 3>>/dev/kmsg
  → 当时 /dev/kmsg 不存在
  → 在 rootfs 建了普通文件 → 随后变 deleted
  → readlink /proc/1/fd/3 = /null
  → PID1 泄漏 fd3 → system_server 崩溃循环
```

**修复**：`fastboot flash init_boot_a ib_patched.img`
**替代救援**：fastboot 不可用时，用 7.2.1 的 9008 回写 `init_boot`。
**教训**：`exec 3>>/dev/kmsg` 必须先 `[ -c /dev/kmsg ]` 判断，**绝不能在 PID1 留 fd**。

### 5.6 层级可行性总表

| 层级 | 可行性 | 做法 |
|---|---|---|
| 换 kernel | ✅ 高 | 刷 `boot-main.img`，5 分钟 |
| Kernel 级 root | ✅ | 自带 KernelSU，不必再补 init_boot |
| 换 system（A14 底座） | ✅ | HyperOS 2.0 GSI / GSI_Kit |
| 换 system（A17 / 澎湃 4.0） | ⚠️ 起到过桌面，可复现性未闭合 | 见 6.1.1。旧口径「❌ vendor API level 33 封顶」已于 2026-10-31 **撤回**（该格漏改，2026-11-07 补齐） |
| 整机 LineageOS | ⚠️ 中 | 见下 |
| 第三方 Recovery | ❌ | 第 4 章 |
| 其它厂商 vendor | ❌ | 易砖 |
| bootloader / TZ / 固件 | ❌ | 不可换 |

**LineageOS 整机（可选深水区）**：[gitanillo87/TB331FC](https://github.com/gitanillo87/TB331FC) 设备树 —— `lineage_TB331FC`，基线 ZUI 15.1.265 / A13，`proprietary-files.txt` **2993 行**，需用 `extract-files.sh` 从真机/固件抽 blob 后才能完整编出卡刷包。

---

## 6. System 移植路线：HyperOS / GSI

### 6.1 硬边界：vendor API level【实测，2026-10-17】

| | 能启动（HyperOS 2.0 / A14） | 掉 900E（A17 三镜像） |
|---|---|---|
| `ro.build.version.sdk` | 34 | 37 |
| `ro.mi.os.version.name` | OS2.0 | — |
| `ro.llndk.api_level` | 无 | **202604** |
| `ro.debuggable` | 1 | 0 |

**设备侧**：`ro.board.api_level=33`、`ro.vendor.api_level=33`、`ro.vndk.version=33`

A17 的 `init` 中有串 `Unexpected vendor api level for`（ZUI16 的 init 里 0 条）。**旧结论据此写成「启动即中止 → 结构性不可行」——该结论已在 2026-10-31 撤回**，因为 A17 实测起到过桌面（见 6.1.1）。这条串只证明 init **记录**了 vendor 代差，不证明它中止启动。

> ⚠️ **纠正一个常见误解**：GSI 不含内核，天生跑在原厂 KMI 上。"用原版 KMI"和"用 GSI"是同一条路。KMI 不是这里的卡点。

### 6.1.1 ★ A17 实测能开机：真实边界（2026-10-31 复核）

**观测事实（设备自己回显，非转述）**：

| 项 | 输出 |
|---|---|
| 系统 | `release=17`、`sdk=37`、`boot_completed=1` |
| 指纹 | `Lenovo/miproduct_yupei/TB331FC:17/CP2A.260605.016/OS4.0.5.0.XPZCNXM:user/release-keys` |
| 传感器 | `Total 29 h/w sensors, 29 running`，含 `bmi3x0 Accelerometer / Gyroscope`（BOSCH ver 306） |
| 应用 | `package:mark.via`（Via）、`package:com.android.MGC_8_8_224`（GCam）已装 |

**起到桌面的分区组合（10-26）**：

| 分区 | 内容 |
|---|---|
| `vbmeta_a` | `E:\rom\work\a17stage\vbmeta_a_D.img`（8192 B，testkey_rsa4096，flags=0，含 boot/dtbo/init_boot/vendor_boot 哈希描述符 + chain→vbmeta_system） |
| `vbmeta_system_a` | `vbmeta_system_H.img`（4096 B，testkey_rsa2048，flags=0，三条 hashtree 描述符） |
| `system_a` / `product_a` / `system_ext_a` | `system_G.img` / `product_D.img` / `system_ext_D.img` |
| boot / vendor_boot / dtbo / init_boot / vendor / odm / vendor_dlkm | 原厂 ZUI16 544 |

`system_G` 的增量只有 `on post-fs-data` 一串 `mkdir`（建 `/mnt/vendor/persist/sensors/registry/registry`）→ `sscrpcd` 不再报 ENOENT → 29 颗传感器复活、自动旋转恢复。

**机制（avbtool 实测，2026-10-31 独立复核）**：
- `vbmeta_a_D.img`：公钥 sha1 `2597c218aae470a130f61162feaae70afd97f011`，`SHA256_RSA4096`；其 Chain Partition descriptor 指向 `vbmeta_system` 的公钥 **同样是 `2597c218…`(rsa4096)**。
- `vbmeta_system_H.img`：公钥 sha1 `cdbb7717f731920bbe0a0f94f84d9038ae0617d`，`SHA256_RSA2048`。
- 两者**不匹配** → 链式校验不成立 → 系统分区不启用 dm-verity → A17 起到桌面（推断）。
- 原厂 544 `vbmeta_a` 的 chain 指向 `cdbb7717…`（与 H 匹配）→ verity 生效 → 约 20 s 崩 900E（推断）。
- 反证条件：干净状态下只换 `vbmeta_a`、其余不变，若结果不随之一进一崩，则此机制错。

**未闭合矛盾**：2026-10-27 18:11，三块逐块重刷干净（6/6、11/11、6/6 全 OKAY）+ `vbmeta_system_H` + `vbmeta_a_D`，**仍 20 s 900E**；当时 `system_ext_a` 刚被 fastbootd `Resizing`、`--set-active=a` 报过 `Unable to set slot`。定论只差一次干净状态单变量复验（只需刷 8 KB 的 `vbmeta_a`）。

**该复验已做成脚本（2026-11-07，尚未跑真机）**：`E:\rom\work\tools\a17_single_var_vbmeta.ps1`

| 模式 | 做什么 | 预测（就是被检验的假设） |
|---|---|---|
| `-Variant prep` | 在 fastbootd 刷 `system_G`/`product_D`/`system_ext_D` + `vbmeta_system_H`，**故意不碰 `vbmeta_a`** | 备好对照基线 |
| `-Variant off` | 在 bootloader 把 `vbmeta_a` 换成 `vbmeta_a_D.img`，重启并按 USB 类别判定 | 链公钥不匹配 → verity 不启用 → **起桌面** |
| `-Variant on` | 同一套内容不变，只把 `vbmeta_a` 换回原厂 544 `vbmeta.img` | 链公钥匹配 → verity 生效 → **约 20 s 掉 900E** |
| `-Variant report` | 打印台账 `E:\rom\work\logs\a17_single_var_result.txt` | 一进一崩 = 机制成立；两边同行为 = 机制**被推翻**，照实记 |

- 直接读数：能起的那次读 `ro.boot.veritymode`（`enforcing` vs 非 enforcing）；崩溃那次没有用户态，**USB 类别就是读数**（`05C6:900E` / `18D1:D00D` / `17EF:`）。
- 顺序约束：`vbmeta_a_D` 在位时 fastbootd 与 recovery 不可用，所以所有 fastbootd 的活必须在换 `vbmeta_a` **之前**干完。
- ⚠️ 重跑必须先记住：现在 persist 是好的，10-26/10-27 的数据不是同一基线。

**ABL 硬规则（三组实验收敛）**：
1. `vbmeta_system` 必须 **flags=0 且带 hashtree 描述符**；flags=2 或缺描述符 → ABL 拒绝启动，停 bootloader。
2. `vbmeta_a` 描述符写错 → **fastbootd 与 recovery 一起不可用**（`Failed to boot into userspace fastboot`）；写回原厂 `vbmeta_a` 立刻恢复。**别再往 `vbmeta_a` 里写自定义描述符**。
3. `slot-unbootable:a: yes` 会让 ABL 拒绝从 a 槽启动任何东西（含 recovery）；`fastboot --set-active=a` 可清除并重置 retry。

**A17 上的已知非阻断故障**：`imsdaemon`（`/vendor/bin/imsdaemon`）每 ~10 s SIGSEGV 一次（`lib-imscommon.so registerImsFactoryHal` 空指针），属 A17 框架与 vendor IMS 不兼容，可用 `settings put global hide_error_dialogs 1` 静音。

### 6.2 已验证可用：HyperOS 2.0 MysticGSI

文件：`E:\rom\extracted\GSI_Kit\05_镜像\GSI\system_a_完全自包含.img`（5,794,435,072 B）

```bash
fastboot reboot fastboot                 # 进 fastbootd
fastboot flash system system_a_完全自包含.img
fastboot -w                              # 从原厂首次刷必做
fastboot reboot
```

> ✅ **遗留疑点已解决（2026-10-20）**：只刷 `system_a` **不会**被原厂 `product_a`/`system_ext_a` 遮住——
> 因为自包含镜像内**自带** `/product`、`/system_ext` 目录，反而是它们**遮住了**那两个独立分区（见 6.3）。
> 这正是 `system_a_完全自包含.img` 刷一个就够的原理。

### 6.2.1 ★ 完整部署只要 3 步（成品镜像路线）

前提：已解锁 + **同型号** TB331FC（`/vendor`、`/odm` 用原厂 ZUI 的，本镜像不动它们）。

```text
第1步 刷系统镜像
  fastboot reboot fastboot
  fastboot flash system 05_镜像/GSI/system_a_完全自包含.img
  fastboot reboot
  ※ 从原厂 ZUI 第一次刷，还要 fastboot -w 才能起来

第2步 装 KernelSU（拿 root）
  装 KernelSU_v3.3.0_*.apk → 「选择并修补一个文件」选 init_boot_a_原始.img
  → fastboot flash init_boot <修补产物>.img → 重启
  ⚠️ 必须保留 ramdisk 两项（见 5.3.0）：novatek_ts_fw.bin + ramdisk/build.prop
  验证：adb shell which su 有输出、管理器显示"工作中"

第3步 装 KSU 模块（小米账号手动退出）
  管理器 → 模块 → 从本地安装 → tb331fc_drop_xiaomi_account.zip
  模块卡片有「操作」按钮，想退账号点一下
```

**做完 3 步就完事**：不用推脚本、不用挂 rc、不用装相机、不用改只读分区。

**校验**：

```bash
adb shell getenforce                       # Enforcing
adb shell getprop init.svc.tb331fc_boot    # running
adb shell tail -30 /data/local/tmp/_boot_fix.log
adb shell "dumpsys package org.lineageos.aperture | grep codePath"              # /system_ext/app/...
adb shell "dumpsys package com.miui.mishare.connectivity | grep privateFlags"    # 含 PRIVILEGED
```

**回退**：见 7.5（fastbootd 刷 super 切片）或直接刷回原厂四件套（见 9.2.1 的 `05_镜像/`）。

### 6.3 挂载拓扑（★ 冲突已解：两处记录是**两种启动状态**，不矛盾）

**① 跑 HyperOS GSI 时**（`技术记录` §十一，实测）：

```
/ 、/system 、/system_ext 、/product   ← 全在同一 ext4（dm-2 = system_a，fsid 相同）
/product 只是 GSI system 镜像里的普通目录，/system/product 是它的软链
/vendor (dm-5) 、/odm (dm-0)          ← 各自独立
product_a(dm-1) / system_ext_a(dm-4)  ← 刷进去了但从未挂载，被 system 镜像里的同名目录遮住
```

**② 跑原厂 ZUI 16.0.544 时**（实机实测 2026-10-17）：

```
/            → dm-7  (system-verity)
/system      → dm-7
/system_ext  → dm-8  ★ 独立，会真挂载
/product     → dm-13 ★ 独立，会真挂载
```

**⇒ 两者不矛盾**：原厂 ROM 下 product/system_ext 是独立的真分区；刷入自包含 GSI 后，
`system_a` 内部的同名目录**反向遮蔽**了它们（dm-1 / dm-4 存在但从未挂载）。

> 💡 这条同时解释了 `flash_hyperos4_three.ps1` 为何要写三个分区：
> **原厂态**下三者独立，必须分别刷；而**成品自包含镜像**已把三者合一，刷一个即可。

### 6.4 super 切片可直接刷【实测，重大发现】

`TB331FC_ZUI_16.0.544\image\super_*.img` **不是只能 EDL 刷的物理切片，它们就是各逻辑分区的原始 ext4 镜像**：

| 文件 | 大小 | 对应 |
|---|---|---|
| `super_4.img` | 5,493,624,832 | `system_a` |
| `super_3.img` | 594,411,520 | `product_a` |
| `super_6.img` | 460,103,680 | `system_ext_a` |

⇒ **可直接 `fastboot flash system_a/product_a/system_ext_a`，不必 QFIL/9008。已验证两次。**

**resize dry-run 参考值**（腾空间）：system 缩到 `1,749,999,616`、product 扩到 `2,999,996,416`、system_ext 扩到 `1,549,996,032`，合计 `10,043,617,280` < 组上限 `12,876,513,280`。
**顺序必须：先缩 product/system_ext，再扩 system。**

### 6.5 开机自修复骨架（移植的核心机制）

```
/system_ext/etc/init/miuibooster.rc
  service tb331fc_boot
    /system/bin/logwrapper /system/bin/sh /system_ext/etc/tb331fc/_boot_fix.sh
    class main · user root · oneshot · seclabel u:r:su:s0
```

| 约束 | 原因 |
|---|---|
| 必须 `logwrapper + sh` | `/data` 是 nosuid，init 不能直接 exec 其上的文件 |
| 必须 `seclabel u:r:su:s0` | 否则 runcon/pm/settings/magiskpolicy 都跑不了 |
| **永不 exit / 永不 kill** | oneshot 退出 → init 回收 cgroup → 杀掉 booster/笔看护 |
| 路径在 `/system_ext/etc/tb331fc/` | 不依赖 `/data`，恢复出厂仍在 |
| `rc` 放 second stage | first stage（`init_boot` ramdisk）里的 `*.rc` 不会生效 |

**开机序列**：手写笔驱动重建 → 拉 miuibooster → 补音频/渲染属性 → 修开发者选项 avc → **一次**注入 81 条 SELinux → 恢复蓝牙规格库 → 补相机权限 → 启用互传/剪贴板 → Joyose → 常驻守护。

### 6.6 典型故障 → 根因 → 修法

| 现象 | 根因 | 修法 |
|---|---|---|
| **蓝牙耳机无弹窗/无流转** | `micloudbluetooth.db` 缺 deviceId 条目 → `cloudSupport=false` | 4 张表插入 `('1.1_1.27','01011A06')` 等；`chown bluetooth:bluetooth` + `chmod 660`，删 `-journal`；`_boot_fix.sh` 开机 grep 缺则整库还原；另放行 `allow bluetooth vendor_audio_prop file {open read getattr map}` |
| **蓝牙耳机一连就软重启** | `ro.vendor.audio.dolby.dax.support` 未设 → MIUI 误判 → 选 MiSound → 无 `libmisoundfx.so` → system_server 崩 | 设 `ro.vendor.audio.dolby.dax.support=true`（本机真有 DAX3）+ `persist.vendor.audio.misound.disable=true` |
| **手写笔无压感** | inputflinger 枚举时序 | 必须在枚举**前**把 `support_pen` 置 1（`_penfix_apply.sh` + 常驻看护） |
| **开发者选项闪退** | `system_app` 写 `logpersistd` 属性/exec logcat 被 SELinux 拒 → `onResume` FATAL | `magiskpolicy --live` 三条 allow（见下） |
| **通信共享"移动数据"磁贴不可用** | 缺 `/product/etc/device_features/TB331FC.xml` → FeatureParser 静态 map 为空 → NPE | KSU 模块在 `post-fs-data` bind 挂载含 xml 的完整目录；**必须整机重启**（空 map 在 zygote） |
| **小米相机机型不匹配** | `MiuiCamera` 多处校验，改属性无效 | 改用 LineageOS **Aperture**（标准 Camera2），放 `/system_ext/app/`（**不要 priv-app**） |
| **小米互传普通安装 FATAL** | SettingsProvider 只放行 SYSTEM/SHELL/root 或 PRIVILEGED | 必须放 `/product/priv-app/MIShare/`（`chcon system_file`） |
| **退出小米账号异常** | accounts 库残留 | 删 `accounts_de.db`/`accounts_ce.db` 中 `type='com.xiaomi'` 行；刷新用 `kill -9 $(pidof system_server)`。**禁止 `stop`/`start`** |
| **相机装了没权限/扫不到** | 系统应用需显式授权 | `pm grant org.lineageos.aperture` 四项：CAMERA / RECORD_AUDIO / ACCESS_FINE_LOCATION / ACCESS_COARSE_LOCATION。**不要用 `pgrep -f _boot_fix.sh` kill**——会匹配到 `logwrapper` 父进程把自己带走 |

**空间提醒**【实测】：`dm-2` 通常只剩约 **100 MB**。MIShare 13.7 MB 放得下，**MiuiCamera 197 MB 放不下**（且有机型校验，别折腾）。

**开发者选项 avc 修复**：

```sh
magiskpolicy --live \
  "allow system_app logpersistd_logging_prop property_service set" \
  "allow system_app logpersistd_logging_prop file { read open getattr map }" \
  "allow system_app logd_exec file { read open getattr map execute execute_no_trans }"
```

### 6.7 SELinux 策略注入原则

- 全程 **Enforcing**，用 `magiskpolicy --live`
- **合并成一次调用**（覆盖语义）
- 该放行的放行（服务查找、属性、HAL binder、自连 socket）
- 只静音的用 `dontaudit`（`platform_app` 读 `/data/system`、`surfaceflinger` 翻 ksu 目录等）
- **不要放行** `update_engine` 的 `syslog`（本来就跑不通，放行弊大于利）

效果：应用层 avc 清零；开机早期 vendor 一次性 avc 保留为固定噪声。

### 6.7.1 Permissive → Enforcing 的改法【实测】

GSI 默认可能是 Permissive，而本套件的修复是**为 Enforcing 设计**的（先确认 `adb shell getenforce`）。

**方法：改 `vendor_boot` 里 cmdline 的两个字符串，等长原地替换**：

```
enforcing=0                      → enforcing=1
androidboot.selinux=permissive   → androidboot.selinux=enforcing
```

> 🔑 **必须等长**，否则 cmdline 长度变了会导致解析异常。
> 套件 `05_镜像/vendor_boot/` 里有两份可直接换刷对比：
> `vendor_boot_a_原始_permissive.img`（原始） / `vendor_boot_a_当前_enforcing.img`（改后）。

```sh
fastboot flash vendor_boot vendor_boot_a_当前_enforcing.img
```

### 6.7.2 sqlite3 必须和 libsqlite.so 配对【实测】

设备上**没有** `sqlite3`。单拷二进制会报：

```
SQLite header and source version mismatch
```

**必须用配套的同源 `libsqlite.so`**，从同一份镜像（如 LineageOS 21 GSI）里成对取出，并用：

```sh
LD_LIBRARY_PATH=<libsqlite.so 所在目录> ./sqlite3 xxx.db
```

> 套件 `06_工具/sqlite3/` 与 KSU 模块 `bin/` 下的两文件都已配好对。

### 6.8 改只读分区（可逆，重启恢复）

```sh
dmctl replace system_a linear 0 10729736 8:10 1167360 linear 10729736 587520 8:10 14397024
dmctl resume  system_a
mount -o remount,rw /
# ...改...
sync
mount -o remount,ro /
```

**导出成品镜像的 dd 坑**：

```
dm-2 = 5,794,435,072 B = 1,414,657 × 4096  ≠ 1 MiB 整数倍（5525.996 MiB）
错误：bs=1M count=5526  → 少最后 4 KB
正确：bs=4096 或 bs=1M 不写 count
```

校验 `miuibooster.rc` 在导出镜像内偏移（super 偏移减去 `1167360×512`）：

```sh
dd if=system_a_完全自包含.img bs=1 skip=5093064704 count=1038 | md5sum
```

### 6.9 明确不要浪费时间的

| 项 | 原因 |
|---|---|
| 小米相机 MiuiCamera | 多处机型校验，改属性无效 |
| 妙享桌面高分辨率画面 | 骁龙 685 解码天花板 |
| OTA | GSI 上 `update_engine` 跑不通 |
| 给 update_engine 放行 syslog | 无收益有风险 |
| ~~A17 / 澎湃 4.0~~ | ~~vendor API level 33 结构性不可行~~ → **已撤回**：A17 实测能起到桌面（见 6.1.1），卡点不在 vendor 代差 |

### 6.10 不关 AVB 的替代方案

若约束是"不能关 AVB"：

| 路线 | 做法 | 难度 |
|---|---|---|
| A. **avbroot** 保留校验、自定义信任根 | `fastboot flash avb_custom_key <pubkey>` 后重签 recovery | 高，需 BL 支持 |
| B. **重建 AVB 拓扑** | HyperOS-Port-Python 以 stock vbmeta 为模板补 footer、保持链路校验 | 中 |
| C. **放弃 TWRP**（推荐） | fastbootd 刷 system + 9008 救砖 | **低** |

检查是否支持自定义信任根：

```bat
fastboot getvar partition-size:avb_custom_key
```

> 结论：**不关 AVB ⇒ 基本放弃 TWRP**（本机反正是死路，无所谓）。

---

## 7. 救砖与回滚

### 7.1 900E vs 9008

| 模式 | PID | 能否 QFIL |
|---|---|---|
| **900E** | `05C6:900E` | ❌ 还在 Sahara，装不进 firehose |
| **9008** | `05C6:9008` | ✅ 标准 EDL |

实测 900E 时：48 字节 Sahara 头 `01 00 00 00 30 00 00 00 … mode=02`（memory dump）；`fh_loader` / `QSaharaServer` 全部超时。

**900E 软件侧无解**，只能等设备自行退出或物理断电进 9008。

### 7.2 进入 9008（推荐顺序）

1. **电量**：0% 时先充 20 分钟以上（0% 时 9008 极易掉线）
2. **方法 A（官方组合键）**：长按电源 15–30 秒完全关机 → **同时按住 音量+ 与 音量−**（两键都按住不松）→ **再插 USB** → 听到"叮"后松开
   > 另有一处记录为"关机后按住音量+插 USB"，两法都试
3. **方法 B**：拔 USB → 长按电源 30 秒放余电 → 等 1 分钟 → 重做方法 A
4. **方法 C**：`WuXingEdl.exe` 工具
5. **方法 D**：拆机短接测试点（最后手段，风险自担）

> ⚠️ **关于 `adb reboot edl` 的冲突记录（务必两说都试）**
>
> - **本机既有实测**：`fastboot oem edl` / `adb reboot edl` 全部返回 `unknown command`，判定此路不通。
> - **社区教程（2026-07，酷安 @栞那daisuki）**：`adb reboot edl` **成功进 9008**，且是整篇教程的核心步骤（用刷机匣回读/回写 `init_boot`）。
>
> **可能的分歧原因**【待核】：① 系统版本差异（教程机可能非 ZUI 16.0.544）；② 需先装好驱动、且命令必须在**系统内 adb**（非 fastboot 态）执行；③ 教程配合"刷机匣先点读信息"的时序。
>
> ⇒ **不要因为一次 `unknown command` 就放弃**：下次进 9008 前，先在系统开机态试 `adb reboot edl`，失败再走方法 A。

### 7.2.1 9008 回读 / 回写单分区（刷机匣路线）★ 免 fastboot

教程用法：进 9008 后**不走 QFIL 整包**，而是直接对单个分区回读与回写——绕过本机 fastboot 的诸多限制。

1. 刷机匣 → **QC/高通 > 深度刷机** → 选好引导文件（`prog_firehose_sm6225_ddr.elf`）→ 点**读信息**
2. 搞机助手 Cmd：`adb reboot edl` → 刷机匣应识别到 9008 设备（失败查驱动/引导文件/数据线）
3. 找到**当前系统所在槽位**的 `init_boot` 分区 → 勾选 → **回读**（建议存桌面）
4. 回读文件传回平板 → root 管理器修补
5. 修补后文件传回电脑 → 刷机匣再点读信息 → `adb reboot edl` → **刷入对应 init_boot 分区** → 重启

> ⚠️ 槽位必须对应：当前在 a 槽就操作 `init_boot_a`，刷错槽位不生效（甚至起不来）。
> 💡 这条路的价值：**无需 fastboot 也能改 init_boot**，可作为 5.5 节 boot loop 的替代救援手段。

检查：

```powershell
Get-PnpDevice -PresentOnly | ? { $_.FriendlyName -match '9008|900E|QDLoader' }
```

### 7.3 QFIL 整包刷回

**图形方式（稳）**：

1. QFIL → **Select Port** 选 9008 口
2. **Select Programmer** → `prog_firehose_sm6225_ddr.elf`
3. **Load XML** → `rawprogram0.xml`（+ `patch0.xml`）
4. **Download**（含 super 多镜像，时间较长）

**Firehose 配置**：Device type = **ufs**，Validation mode = **0 - no validation**，勾选 Reset after download，Build type = Flat Build。

**命令行**：

```bat
QSaharaServer.exe -s 13:prog_firehose_sm6225_ddr.elf -p \\.\COM3
fh_loader.exe --port=\\.\COM3 --search_path=..\image --sendxml=rawprogram0.xml ^
  --memoryname=ufs --zlpawarehost=1 --noprompt --showpercentagecomplete
```

> 🔑 **关键参数**：`--memoryname=ufs`（上次失败真因不是 LUN 参数，而是漏了存储类型）
> ⚠️ `fh_loader` 写 LUN4（abl）曾报 `Failed to open SDCC ... lun:4`；勿依赖包内 `flash.bat`（`-s %1` 空序列号会挂）

### 7.4 ⚠️ 槽位坑（任何镜像实验后必读）

recovery 测试失败后设备会回落 fastboot 且**槽位可能错乱**（b 槽残留测试镜像 → 系统起不来）。

**任何 recovery/vbmeta 实验后立即执行**：

```bash
fastboot --set-active=a
fastboot flash boot_a     stock-boot.img     # 成对回滚，勿只回滚单槽
fastboot flash vbmeta_a   stock-vbmeta.img
fastboot reboot
```

**禁止未回滚就连试多个镜像。**

### 7.5 fastbootd 救砖（已验证两次，比 9008 快）

```bash
adb reboot fastboot        # 或 fastboot reboot fastboot
# 先缩 product / system_ext，再扩 system
fastboot flash system_a     super_4.img
fastboot flash product_a    super_3.img
fastboot flash system_ext_a super_6.img
fastboot -w
fastboot reboot
```

### 7.6 900E 根因：套件混搭【实测】

| 分区 | 作者套件 | ZUI 线刷包 | 一致？ |
|---|---|---|---|
| boot | `4e5164d7…` | `ca6e201c…` | ❌ |
| init_boot | `f8d1c530…` | `56dd77fa…` | ❌ |
| vendor_boot | `c57a9d21…`(permissive) | `edc9f03c…` | ❌ |
| vbmeta | **65536 B** `9ba41745…` | **8192 B** `76158477…` | ❌ **大小都不同** |

**结论**：不是作者的 system 单独坏，而是**启动链与 system/vbmeta 不是同一发布套件**，外加 super 可能被 EROFS 试刷弄脏 → 无法通过启动校验 → 900E。

**方案 A（推荐）**：恢复作者 HyperOS2 全套（全部来自 `GSI_Kit\05_镜像\`，同一来源）

```bat
fastboot flash boot        boot_a_原始.img
fastboot flash init_boot   init_boot_a_原始.img
fastboot flash vendor_boot vendor_boot_a_原始_permissive.img
fastboot flash vbmeta      vbmeta_a_原始.img      :: 64KB
fastboot reboot fastboot
fastboot flash system      system_a_完全自包含.img
fastboot -w
fastboot reboot
```

**方案 B**：ZUI 完全线刷（9008 或 fastboot 整包，含 super_1..8）
**方案 C**：实验包（HyperOS4 EROFS）末块 `Invalid argument`，**先不要当开机镜像**

> `fastboot -w` 只清 userdata/metadata，**修不好 boot/AVB/super**。

### 7.7 常见报错速查

| 报错 / 现象 | 处理 |
|---|---|
| `FAILED (remote: 'Flashing is not allowed')` | BL 未解锁，或 OEM Unlocking 未勾选 |
| `Command not allowed` | 先 `--disable-verity --disable-verification flash vbmeta` |
| `Not enough space to resize partition` | `fastboot delete-logical-partition product_a` |
| Status 7 / 机型验证失败 | 注释 updater-script 首行 assert（机型真不符会变砖） |
| 刷完没信号 | 单刷 `modem.img` / `non-hlos.bin` |
| System UI 已停止 | 删 `/data/system/package_cache` 重启 |
| 卡第一屏/无限重启 | 单刷底包 `boot.img`；检查 `system/bin`、`system/etc` 是否误替换 |
| 软砖（能进 fastboot/rec） | 线刷完整固件 |
| 硬砖（连 fastboot 都没有） | 9008 / SP Flash / Odin |
| **声音和录音同时没了** | **persist 分区全零，见 7.8** |
| **`bluetooth_address` 为 null / MAC 变成随机值** | **persist 丢失，见 7.8** |

### 7.8 persist 分区全零：官方刷机永远修不了的一块（2026-11-01 实证）

#### 7.8.1 症状与机理

**观测**：声音和录音**同时**消失。两者共用音频 DSP 底座，所以同时挂指向共同上游，不是 App 层。

修复前的完整证据链：

| 观测项 | 实测值 |
|---|---|
| `audioadsprpcd` + `adsprpcd` 重启 | 25 分钟内 **57 次**（`adsp daemon will restart after 25ms`） |
| 声卡注册/注销翻转 | 60 秒内 **56 次**（`sound card status changed 1` ↔ `0`） |
| AudioFlinger | `underruns=197 overruns=5`——数据写了 HAL，下游不消费 |
| 音频策略配置 | **正常**：`Built-In Mic`、`Built-In Back Mic`、`speaker` 都在 |
| 音频进程 | 都活着：`audioserver`、`android.hardware.audio.service_64`、`audioadsprpcd` |
| `persist` 挂载 | **未挂载**（`/proc/mounts` 89 条里一条都没有） |
| `settings get global bluetooth_address` | **null**（BT MAC 显示随机值 `MAC-REDACTED`） |
| `sscrpcd` | 反复报 `/mnt/vendor/persist/sensors/registry/registry` ENOENT |

**机理**：全零分区挂载失败 → 传感器注册表、音频校准（ACDB）、真实 MAC 全部取不到。音频 HAL 拿不到校准就不断重连 DSP，`Connection reset by peer` 后自杀重启，声卡跟着重新注册，形成死循环。

#### 7.8.2 决定性判据：回读比对非零字节

在 9008 下把真机 persist 读出来，与刷机包 `persist.img` 比：

```
real  size = 33554432        stock size = 33554432
real  non-zero bytes = 0 (0.00%)       ← 真机：32 MB 一个非零字节都没有
stock non-zero bytes = 22695 (0.07%)   ← 刷机包：有内容
differing byte positions = 22695
```

**这一条就能定死。** 判据不是"文件在不在"，而是**非零字节数**。

#### 7.8.3 为什么官方刷机包修不了它

`rawprogram0.xml` 里 persist 是：

```xml
<program SECTOR_SIZE_IN_BYTES="4096" file_sector_offset="0" filename="" label="persist"
         num_partition_sectors="8192" partofsingleimage="false"
         physical_partition_number="0" readbackverify="false"
         size_in_KB="32768.0" sparse="false" start_byte_hex="0x8000" start_sector="8" />
```

**`filename=""`** = 只定义分区几何，**不写内容**。官方刻意不写 persist，因为它是设备唯一分区（MAC / 校准 / SN 相关）。

`patch0.xml` 里也不含 persist，所以单刷 persist **不需要 patch**。

#### 7.8.4 顺带：刷官方包不会清用户数据

`userdata` 是稀疏镜像（`userdata_1..10.img`，合计约 66 MB 非零，占 103 GB 的 `/data` 的零头），**只覆盖非零扇区**，其余原样保留。所以：

- 判断"刷没刷"**不能**看 `/data` 里有没有旧文件
- 判断依据是 `btime`（`grep btime /proc/stat` 换算开机时刻）+ `ro.boot.bootreason` + 有没有 `com.zui.setupwizard` 启动痕迹
- 同版本覆盖刷写也**不会**重装预装应用，`pm list packages -3` 里全是 `com.zui.*` 是正常的

#### 7.8.5 实操：只写 persist

**准备**（ASCII 目录，避开中文路径）：

```
E:\rom\work\edl\
  fh_loader.exe
  QSaharaServer.exe
  prog_firehose_sm6225_ddr.elf
  persist.img                      (从刷机包 image\ 拷入)
  read_persist.xml / write_persist.xml
```

**关键：跳过 QSaharaServer**

```
QSaharaServer -p COM4 -s 13:prog_firehose_sm6225_ddr.elf
→ ERROR: sahara_rx_data:276 Unable to read packet header. Only read 0 bytes.
→ ERROR: sahara_main:982 Sahara protocol error
```

两试两败。但此时查设备属性：

```
DEVPKEY_Device_BusReportedDeviceDesc = QUSB_BULK_CID:043A_SN:86C1CC00
```

`QUSB_BULK` 表示已进入 bulk/firehose 命令阶段，`043A` 是 QFIL 的"sahara 已完成"状态码。**firehose 早已就绪，sahara 失败不影响**，直接用 fh_loader。

**读**（`--sendxml`，不是 `--readxml`）：

```xml
<?xml version="1.0" ?>
<data>
  <read SECTOR_SIZE_IN_BYTES="4096" file_sector_offset="0" filename="real_persist.img"
        label="persist" num_partition_sectors="8192" physical_partition_number="0"
        size_in_KB="32768.0" sparse="false" start_byte_hex="0x8000" start_sector="8" />
</data>
```

```bat
fh_loader.exe --port=\\.\COM4 --sendxml=read_persist.xml --zlpawarehost=1 ^
              --memoryname=ufs --noprompt --verbose
```

**写**：

```xml
<?xml version="1.0" ?>
<data>
  <program SECTOR_SIZE_IN_BYTES="4096" file_sector_offset="0" filename="persist.img"
           label="persist" num_partition_sectors="8192" partofsingleimage="false"
           physical_partition_number="0" readbackverify="false" size_in_KB="32768.0"
           sparse="false" start_byte_hex="0x8000" start_sector="8" />
</data>
```

```bat
fh_loader.exe --port=\\.\COM4 --sendxml=write_persist.xml --zlpawarehost=1 ^
              --memoryname=ufs --noprompt --verbose --reset
```

实测输出：`{SUCCESS}` → `Overall to target 0.781 seconds (40.97 MBps)` → 自动 `Sending <power>` 重启，COM4 消失，约 20 秒后出现 `VID_17EF&PID_7E60`。

**四个易错点**：

| 坑 | 正确做法 |
|---|---|
| 端口写裸 `COM4` | 必须 `\\.\COM4` |
| 想用 `--readxml` | 没有这个参数，读也走 `--sendxml`，XML 里用 `<read>` 元素 |
| 漏 `--memoryname=ufs` | 必须带 |
| 在中文路径下跑 | 换纯 ASCII 目录 |

**写入前必须回读备份**。通用 persist 镜像里的 MAC 是通用值；但若原分区已全零（`bluetooth_address` 为 null），写它只是改善，不会更差。

#### 7.8.6 本节附带的三条误判教训

**教训 1：日志里紧挨错误的那条 `No such file` 未必是根因。**

日志反复出现：

```
apps_std_fopen_with_env failed with 0x2 for remote_heap_config.so (No such file or directory)
Error 0x2: open_mod_table_handle_invoke failed ... sc:0x13050100
```

我按这个判"文件被刷丢了"。离线扫官方 `dspso.bin`（32 MB，即 `dsp_a` 分区内容）后：

```
remote_heap_config  hits=0     ← 官方原版根本没有
apps_std            hits=229
ELF headers         = 60
```

那是**探测性 warning**，不是病因。真正失败的 RPC 是 `sc:0x13050100`，前面那行 `fopen` 只是探路失败。**先离线比对镜像内容，再判"文件丢了"。**

**教训 2：不能用 `uptime` 判"刷没刷机"。**

我拿两个时刻的 `uptime` 反推开机时刻相同，就断言"没重启 = 没刷"。那只证明**这两点之间**没重启。而且两条"旁证"全错：

- "第三方应用还在 26 个" → 看列表全是 **ZUI 预装**，预装存在正是刷完机的正常样子
- "setupwizard 没跑" → 实际有 `wm_create_activity: com.zui.setupwizard/.DefaultActivity`

**教训 3：同一个现象名不等于同一个事实。**

A17 那次 persist 也"未挂载"但音频正常（部分缺失）；这次是整块全零。**严重度必须看介质本身，不能看现象标签。**

---

## 8. 逆向与芯片漏洞资料

### 8.1 解包链（已验证）

```
abl ELF → ph2 固件卷(0x40000) → FIRMWARE_VOLUME_IMAGE
  → GUID LZMA 段(EE4E5898…) → 解压 970952 B
  → 8字节前缀 + 内层 FV(FvLength=0xed0c0)
     └ APPLICATION "LinuxLoader" ← ABL 本体
        PE32+ ARM64，970756 B，ImageBase=0，.text=784KB
        .text VA=0x1000..0xc0000 / .data=0xc0000..0xeb000（VA==文件偏移）
```

**全 abl 只有一个 PE** → VerifiedBoot 协议实现体不在 ABL 内（后证实 = XBL 内 `VerifiedBootDxe`，65536 B PE32）。

### 8.2 关键字符串 → 引用点（xref 地图）

| 字符串 VA | 内容 | 引用点 |
|---|---|---|
| 0xae1d9 | Recovery partition doesn't exist; continue normal boot | 0x1b074 |
| 0x9887e | Recovery partition has no kernel | 0x1b148 |
| 0xaaa52 | Device is unlocked, Skipping boot verification | 0x1baa0（state==1） |
| 0xa27dc | **Your device is corrupt. It can't be trusted and will not boot.** | 0x1b954（state==3） |
| 0xaa9ac | LoadImageAndAuth failed %r | 0x1b88c |
| 0xac1c0 | VBVerifyImage failed with: %r | 0x1be5c |
| 0xa8507 | ERROR: Failed to load recovery Image: %r | 0x1e7bc |

### 8.3 VerifiedBoot 协议方法表

- GUID `8e5eff91-21b6-47d3-af2b-c15a01e020ec`；实例存 `[ctx+0x430]`

| 槽 | 函数 | 对应 ABL 调用 |
|---|---|---|
| +0x08 | 0x156c | SendBootState 族 |
| +0x10 | 0x14a4 | DeviceInit（锁机→state=0；解锁→state=1） |
| **+0x18** | **0x1f88** | **终审门**（state=3 ⇒ 恒返 0x50） |
| +0x20 | 0x1a80 | finalize |
| **+0x28** | **0x2444** | **LoadImageAndAuth（白名单比对主体）** |

**VerifySignature（0x368c）**：`cmp w22,#2` → **alg 必须 == 2（SHA256）**，否则 `'Hash algorithm not supported'` → 返回 -3。

### 8.4 芯片漏洞（骁龙 685 / SM6225-AD）

| 类别 | 内容 |
|---|---|
| 规模 | 累计 56~241 条 CVE（口径不同），CISA KEV 在野利用 3~7 条，最高 CVSS v4 9.3 / v3 9.8 |
| **在野利用** | **CVE-2025-21479**（8.6，Adreno GPU 微码）、**CVE-2025-21480**（8.6）、**CVE-2025-27038**（7.5，Chrome UAF）—— 2025-06-03 加入 KEV，补丁 2025-05 发 OEM |
| 高危代表 | CVE-2025-21483（**9.8 Critical**）、CVE-2023-33054（9.1） |
| Adreno 610 | CVE-2019-10567、CVE-2020-11179（Project Zero：改 TTBR0 得任意物理内存读写，沙箱逃逸到内核） |
| **EDL/9008** | **ALEPH-2017028**（Firehose peek/poke → PBL/EL3 任意代码执行，可翻 devinfo 解锁位）；**CVE-2026-25262**（Sahara `SAHARA_CMD_RECV_DATA` Write-What-Where，BootROM 级任意地址写；**SM6225 不在官方名单但机制可疑可测**） |

**补丁状态自查**：

```bash
adb shell getprop ro.build.version.security_patch   # 本机 ZUI16 = 2024-10-05
adb shell getprop ro.build.version.release
adb shell getprop ro.boot.verifiedbootstate
adb shell getprop ro.boot.vbmeta.device_state
```

> 安全补丁停在 2024-09 之前 ⇒ 8.4 三条在野利用大概率未修。
> **升不升级是一权衡**：升级修漏洞，但可能改 AVB 策略 / 熔断（参考欧加系 2026 年起大面积推送熔断版本）。

**对玩机的意义**：9008 底层写入不校验 BL 锁；Firehose `read` 可在不解锁时**备份全部分区**（XDA 帖中锁定机用户的核心诉求）。

### 8.5 立场

- 本文档不构成刷写指引；**当前立场：abl 只读不写**
- 9008 工具包保留作救砖底牌，不作实验
- 仅供自有设备研究；绕过厂商安全机制可能违反用户协议

---

## 9. 附录：命令 / 工具 / 路径 / 发布

### 9.1 命令速查

```bash
# —— 状态查询 ——
fastboot getvar all                 # 全量（本机输出 ~19KB）
fastboot getvar current-slot
fastboot getvar unlocked
fastboot getvar is-userspace        # yes = 在 fastbootd
adb shell getprop ro.build.version.security_patch
adb shell getprop ro.treble.enabled
adb shell getprop ro.vndk.version
adb shell getenforce

# —— 基础操作 ——
adb reboot bootloader / fastboot / recovery
adb reboot edl                      # ⚠️ 本机曾报 unknown command，但社区教程成功，两说都试（见 7.2）
fastboot oem unlock-go              # 或 fastboot oem unlock_go
fastboot --set-active=a
fastboot flash boot|init_boot|vendor_boot|dtbo|vbmeta|recovery|system <img>
fastboot --disable-verity --disable-verification flash vbmeta vbmeta.img
fastboot erase cache
fastboot -w                          # 清 data（慎用）
fastboot delete-logical-partition product_a

# —— 日志 ——
adb logcat
adb shell dmesg
adb shell ls /data/local/newlog/aplog/kernellog*    # ★ Lenovo 持久化内核日志（6 个轮转 ~22MB）
adb shell ls /data/tombstones
```

### 9.2 本地路径

```
# 只读原厂（勿修改）
E:\类\刷机\联想\TB331FC\                      # ZUI16 原厂包、9008 工具、APatch
E:\rom\240412_Lenovo_XiaoxinPad_2024_TB331FC_ZUI_15.1.105_纯净版_售后专用\

# 可写工作区
E:\rom\release\OrangeFox-TB331FC\            # OF 镜像、vbmeta、avbtool.py、testkey_rsa4096.pem
E:\rom\release\ZUI15-extract\                # ZUI15 abl/boot/recovery/vbmeta + rawprogram*.xml
E:\rom\port\tools\TB331FC-OrangeFox\         # 设备树工作副本
E:\rom\extracted\GSI_Kit\05_镜像\            # 原始 + system 备份（5.5GB），救砖底牌
E:\rom\kernel\                               # 定制内核下载目标
```

GitHub：`https://github.com/dsshhgg/TB331FC-TWRP` 分支 **`fox-12.1`**
（clone 被 Watt Toolkit 卡住时：改用 API / `https://gh-proxy.com/` 加速 Release 下载）

### 9.2.1 部署套件（TB331FC_GSI_Kit）目录结构

```text
TB331FC_GSI_Kit/
├── README.md                       部署步骤（3 步）
├── MD5SUMS.txt
├── 01_发布稿/   酷安发布稿.md（精简：能用什么/不足在哪）· 技术记录-踩坑与原理.md（14 节）
├── 02_部署文件/ 只有「从零重做」才需要，正常部署用不到
│     _boot_fix.sh · _penfix_apply.sh · magiskpolicy
│     micloudbluetooth_fixed.db · MIShare_351.apk
│     ⚠️ 这份路径写死 /data/local/tmp/，配套「从零」用；
│        镜像里内置的那份路径是 /system_ext/etc/tb331fc/。两份等价、位置不同
├── 03_应用APK/  Aperture.apk（镜像已内置，仅留底）· KernelSU_v3.3.0_*.apk
├── 04_KSU模块/  tb331fc_drop_xiaomi_account.zip（可直接「从本地安装」）+ 解开版
├── 05_镜像/
│   ├── GSI/      system_a_完全自包含.img ★★★（5.4GB）· 原始 GSI zip（未改动留底）
│   ├── init_boot/init_boot_a_原始.img        8MB  ← KSU 补丁就打它
│   ├── boot/     boot_a_原始.img             96MB
│   ├── vendor_boot/ 原始_permissive.img  96MB · 当前_enforcing.img 96MB
│   └── vbmeta/   vbmeta_a_原始.img · vbmeta_a_patched.img
└── 06_工具/      platform-tools/ · QFIL/ · sqlite3/（★必须成对使用）
```

### 9.3 工具与仓库

| 用途 | 链接 |
|---|---|
| **TB331FC 定制内核（KSU+SusFS）** | https://github.com/yxyyds666/TB331FC-Kernel |
| TB331FC TWRP | https://github.com/yxyyds666/TB331FC-TWRP |
| LOS 设备树 | https://github.com/gitanillo87/TB331FC |
| 同平台内核参考 | https://github.com/AndroDumb/android_kernel_motorola_sm6225_5.15 |
| HyperOS 移植工具 | https://github.com/toraidl/HyperOS-Port-Python |
| HyperOS4 Windows 分支 | https://github.com/Z-Fovik-RT/HyperOS4.0-Port-Windows-Python |
| 解包厨房 | https://github.com/ColdWindScholar/MIO-KITCHEN-SOURCE |
| avbroot（保留 AVB 重签） | https://github.com/chenxiaolong/avbroot |
| testkey 重签工具箱 | https://github.com/alltechdev/haha-you-used-testkeys |
| phhusson GSI | https://github.com/phhusson/treble_experimentations |
| vendor_hardware_overlay | https://github.com/phhusson/vendor_hardware_overlay |
| A16 GSI 列表 | https://github.com/AzusaMermaid/GSI-List-Android-16 |
| 联想平板 A16 GSI 指南 | https://github.com/Simon0Harms/Lenovo-Tab-P11-5G-TB-J607Z-Android-16-GSI-Guide |

**Windows 图形工具（社区教程用）**

| 工具 | 用途 |
|---|---|
| **搞机助手 PC** | 扩展功能：**安卓驱动**安装、Cmd 命令行（adb/fastboot） |
| **刷机匣** | 主页：**安装刷机驱动**；QC/高通 > 深度刷机：选引导文件 → **读信息 → 9008 回读/回写单分区** |
| 9008 引导文件 | `prog_firehose_sm6225_ddr.elf`（线刷包内） |

> 💡 两个工具的驱动**都要装**（各装各的）。数据线勿用杂牌，否则 9008 易掉线。

**酷安参考帖**：《联想小新平板2024解锁Bootloader并获取Root权限教程》@栞那daisuki，2026-07-24（解锁申请字段映射 + sn.img 356b 校验 + 9008 改 init_boot 全流程）

**B 站教程**：`BV1cGRLYpEEs`（系统移植入门，含解打包/分区/AVB/拼包）、`BV1dF4m1P7j4`（修澎湃 bug）、哈哈omo「移植小米澎湃OS」合集（约 30P）

### 9.4 下载清单（按目标）

| 目标 | 需要下载 | 体积 |
|---|---|---|
| Root / 刷模块 | **无需下载**：APatch + KernelSU 已在本地 | 0 |
| 换内核 | `boot-main.img`（TB331FC-Kernel 1.3.2） | ~几十 MB |
| 刷 GSI | Google vbmeta.img（`https://dl.google.com/developers/android/qt/images/gsi/vbmeta.img`） | KB~GB |
| 救砖 / 回最新官方 | ZUI 17.0.460 线刷包 | 4.4GB |
| ROM 移植对比 | 7-Zip + Beyond Compare | ~20MB |
| 自编 TWRP/OrangeFox | 源码 manifest 45~50GB+ | ⚠️ **本机成品也进不去，慎下** |
| 自编 GSI | phhusson 三件套 + Ubuntu 120GB 磁盘 | ⚠️ 大件 |

**最小推荐组合**：`boot-main.img` + Google vbmeta.img + 7-Zip + Beyond Compare ≈ 几十 MB。

> ☒ **不建议下载**：付费"救砖包"/"内部解锁工具"（联想 CDN 免费）、来路不明的"强解 BL 工具"（多为骗局或带马）。

### 9.5 发布检查清单

**目录结构**

```text
TB331FC_发布包_vX.Y/
├─ 00_必读_README.md          风险、机型限制、刷机三步、回滚
├─ 01_教程/                   刷机操作手册 / 移植原理速查 / 救砖900E转9008 / A16资料
├─ 02_文档_勘误与FAQ.md
├─ 03_工具/                   platform-tools / scripts / 工具来源说明
├─ 04_镜像/                   system_a_xxx.img（注明 ext4 或 erofs）+ MD5SUMS.txt + 来源说明
├─ 05_KSU模块/
├─ 06_回滚/                   指向 ZUI 原厂或备份方法
└─ VERSION.txt                版本、日期、设备型号
```

**发布前必查**

- [ ] 仅含 **TB331FC** 可用内容，无其它机型误导
- [ ] 主镜像 **MD5/SHA256** 已算好写入 MD5SUMS
- [ ] 步骤与实机验证一致（或标明"理论/自测未完成"）
- [ ] 含**回滚 / 救砖**说明
- [ ] 含**数据清除 / 风险 / 保修 / 游戏**警告
- [ ] 未打包隐私数据、无本机 dump 中的账号
- [ ] 版本号 `MAJOR.MINOR.PATCH` + 日期
- [ ] 若含 TWRP/内核：标明**已知 bug**、是否推荐

**风险句（粘贴用）**

> 本资源仅适用于联想小新 Pad 2024（TB331FC）。刷机需解锁 Bootloader，可能导致失去保修、数据丢失甚至无法开机。请自行备份并准备原厂线刷/救砖包。作者不对刷机后果负责。请勿用于非法用途。

**腾讯游戏特别警告**：解锁 BL + 非官方系统 + 关闭 AVB = ACE 高风险，封号概率极高。SusFS/KernelSU 只能挡部分用户态检测；已封设备可能被关联追封。**这台机器不要登录重要腾讯账号**，也不要与已封账号共用实名/支付/IP。

### 9.6 全套资料索引（原始文件对照）

| 主题 | 原始文件 |
|---|---|
| 通用教程 | `01-刷机基础`、`02-刷机包移植`、`03-TWRP移植`、`04-GSI移植`、`05-OrangeFox移植`、`06-不解BL使用第三方Recovery` |
| 设备与芯片 | `07-TB331FC设备资料与芯片漏洞`、`08-下载清单` |
| 白名单逆向 | `09-ABL白名单静态逆向`（v3.2） |
| OF 实战 | `TB331FC-OrangeFox-完整手册`、`-最完整复盘`、`-移植总结`、`TB331FC-recovery-whitelist-report`、`TB331FC-AI交接提示词` |
| 踩坑 | `TB331FC-踩坑与机型问题复盘`、`排查_900E根因`、`救砖_900E转9008教程`、`会话复盘_session-a1c5aa16` |
| 系统移植 | `移植原理速查`、`底包选用说明`、`二次移植路线图`、`安全移植清单_教程版`、`A16_移植资料汇总`、`HyperOS_v2_调研笔记`、`开包移植系统教程.docx` |
| Root/内核 | `内核源码调研_TB331FC`、`TWRP_安全刷入说明`、`TWRP重编方案`、`移植方案_保留AVB`、`本地自建移植环境` |
| 解锁+Root 实操 | 酷安 @栞那daisuki《联想小新平板2024解锁Bootloader并获取Root权限教程》（2026-07-24） |
| 发布 | `发布包_总装说明`、`酷安帖草稿` |
| 日志脚本 | `getvar_all.txt`、`getvar_after_flash.txt`、`of*.log`、`edl*.log`、`port_trace.txt`、`patch_bootfix.sh`、`vendorsetup.sh`、`验证清单.md` |

### 9.7 未竟事项（开放问题）

1. **只刷 `system_a` 是否会被原厂 `product_a`/`system_ext_a` 遮住** —— 需实测，可能要额外打包刷这两个子树
2. `vbmeta_system` 公钥 sha1 `cdbb7717…` 是否等同 AOSP testkey RSA2048 —— 两份资料口径不一
3. A17 `init` 的 vendor api level 门禁能否 patch 绕过（capstone 已定位 `0x0f627c` 起读 `ro.vendor.api_level`，默认常量 `0x0F4240=1,000,000`）。~~但即便绕过，闭源 vendor 仍是结构性障碍~~ → **后半句 2026-11-07 撤回**：A17 在**没有**绕过该门禁的情况下就起到过桌面（6.1.1），说明它不是启动阻断点；绕过它属于「也许更稳」，不属于「能不能开」
4. `+0x20 finalize` 内部逐行、`0x3808` 验签尾段、`[0xe1f1]` 语义
5. `scan_bootlog.py` 判定逻辑待修（kernellog.3/.4 误判 FAIL-MID、需按轮转序而非时间戳排序）
6. `kai_init_v5_FIXED.sh` 已写出但**未打包未刷入**
7. **`adb reboot edl` 到底能不能进 9008** —— 本机实测 `unknown command`，社区教程成功。分歧原因待查（系统版本？需系统内 adb？时序？）。**下次进 9008 前务必先试一次**
8. **解锁站选「拯救者 Y700 五代」为何对 TB331FC 有效** —— 是同一套 sn 签发后端，还是仅为字段复用？影响换机/换号时的可复现性
9. `Flashing is not allow in lock state` 降级方案的具体版本目标未记录
10. **A17 可复现性的单变量复验没跑过**：`tools\a17_single_var_vbmeta.ps1` 已 dry-run 校验（296 行、0 语法错、0 非 ASCII 字节），只差设备。跑完这一条，6.1.1 的机制推断才算有结论（成立或被推翻都行，别留着）
11. **A17 的旧观测全部产自 persist 全零的机器**（11-01 才修好）：10-26 那次「29 颗传感器」是靠 `system_G` 里 `mkdir /mnt/vendor/persist/sensors/registry/registry` 兜出来的；现在 persist 有真内容、ACDB 可用，**传感器与音频在 A17 下的表现必须重测**，旧数字不可比
12. **`E:\rom\docs` 里 4 份 10-18/10-20/复盘文档的正文仍写着「结构性不可行」**：按规矩不改历史，2026-11-07 已在各文件顶部补「更正」条目；读那几份时先看头部横幅

---

## 版本记录

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-10-18 | 37 份资料去重合并，建立总纲；标注实测/结论/待核三级可信度 |
| v1.1 | 2026-10-18 | 并入酷安解锁+Root 教程：解锁申请字段映射（`serialno`→序列号 / `ufs_sn`→Bootloader_sn）、板块选「拯救者 Y700 五代」、sn.img 356b 校验、12 点前申请、9008 回读/回写 `init_boot` 通道；新增 `adb reboot edl` 冲突记录与 0.5 最短路径 |
| v1.2 | 2026-10-18 | 实测证伪「改 sn_AAAAAAAA.img 十六进制免邮件」技巧，补「免邮件技巧已证伪」说明并与 ABL 验签（0x85214 / `oem unlock fail`）互相印证；同步更新 0.3 证伪清单与 0.5 最短路径 |
| v1.3 | 2026-10-18 | 合并原 1.4 / 1.4.1 / 1.4.2 为单一 1.4「官方解锁与固件」（解锁命令 → 申请细节 → 常见报错 → 免邮件证伪 → 固件来源），内链同步改为 1.4 |
| v1.4 | 2026-10-20 | 并入部署套件 README：① 6.2.1 成品镜像「3 步部署」全流程与校验；② 6.3 挂载拓扑冲突**已解**（GSI 态 vs 原厂态两种状态，非矛盾），6.2 遗留疑点关闭；③ 新增 5.3.0 init_boot 补丁必留 ramdisk 两项；④ 新增 6.7.1 Permissive→Enforcing 改法、6.7.2 sqlite3 与 libsqlite.so 必须配对；⑤ 9.2.1 部署套件目录结构 |
| v1.5 | 2026-10-31 | **撤回「A17/澎湃 4.0 结构性不可行」**。从三个会话档案复原一手设备回显（`release=17`/`sdk=37`/`boot_completed=1`/`Total 29 h/w sensors, 29 running`/Via+GCam 已装），新增 6.1.1「A17 实测能开机：真实边界」+ avbtool 链公钥机制与反证条件；0.3 / 6.1 / 8.x 相关 ❌ 口径同步改为「未闭合」 |
| v1.6 | 2026-11-01 | 新增 7.8「persist 分区：官方刷机永远修不了的那块」：真因 = `/dev/block/sda2` 整块全零（回读 `non-zero bytes = 0`），`rawprogram0.xml` 里 persist `filename=""` 故官方刷机不写它；补 `userdata_N.img` 稀疏（刷官方包不清数据）、三个免拆判据、`fh_loader` 直连（本机 `QSaharaServer` 两试两败）、`<read>` 回读取证法与三条误判教训；0.3 / 快速排障补 2 行 |
| v1.7 | 2026-11-07 | 澎湃 4 记录**一致性收尾**（全量复查 90 个文件，25 条 (A) 类残留）：0.1 拆出 A17 行、0.4 当前状态刷新并加「persist 修复后基线已变」警告、5.6 总表 ❌→⚠️、9.7 第 3 条后半句撤回并新增第 10/11/12 条；6.1.1 末尾落定单变量判定实验脚本 `tools\a17_single_var_vbmeta.ps1`（prep/off/on/report，dry-run 校验未跑真机）；`grab_a17_logs.ps1` 补 persist/音频环计数/`btime` 取证段；`rom-porting` 方法论页同步「代差≠不可行」与「同内容一进一崩先查 vbmeta 链」 |