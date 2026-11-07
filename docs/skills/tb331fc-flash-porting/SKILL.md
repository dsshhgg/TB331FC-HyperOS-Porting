---
name: tb331fc-flash-porting
description: '联想小新 Pad 2024（TB331FC，代号 khaje，骁龙 685 / SM6225-AD）刷机、Root、系统移植与救砖知识库。用于：解锁 Bootloader、KernelSU/APatch/Magisk 修补 init_boot 或刷 boot、ZUI/HyperOS/GSI 系统移植、TWRP/OrangeFox 可行性判断与编译、fastboot/9008/900E 救砖、槽位回滚、ABL 白名单与 AVB 逆向。动手前先读本页的禁止清单，可避免重复已验证的死路。'
---

# TB331FC 刷机与移植 · 操作导读

本 skill 对应设备：**联想小新 Pad 2024 / TB331FC**（`khaje`，骁龙 685 / SM6225-AD），仅 WiFi。
完整知识库（约 1600 行，含全部实测记录、命令、逆向细节）在 `references/knowledge-base.md`。

## 怎么用

1. 先看本页的路线判断、铁律与禁止清单，确认要做的事不在死路里。
2. 需要细节时，在 `references/knowledge-base.md` 里按章节编号定位：用 `grep` 搜 `## 5.`、`### 7.2.1` 这类标题，再用 `read` 的 `offset/limit` 只读该段。不要整篇通读。
3. 原文标注含义：`【实测】` 本机已验证 · `【结论】` 多份证据收敛 · `【待核】` 有冲突 · `【禁止】` 已证伪，别再试。
4. 原文主体日期 2026-10-18；**澎湃 4 / A17 口径以 2026-10-31 复核（6.1.1）为准，persist 与音频以 2026-11-01 实证（7.8）为准，记录一致性收尾 2026-11-07**。涉及"当前状态"的判断，先看本节下方「当前状态」的日期。

## 设备一页纸

| 项 | 值 |
|---|---|
| 分区方案 | **A/B（slot-count=2）+ 独立 recovery 分区** |
| recovery / boot | 100MB（`0x6400000`）/ 96MB |
| vbmeta | 分区 64KB；**文件** ZUI16=8KB（Flags=0），ZUI15=64KB（Flags=2） |
| init_boot / vendor_boot | 8MB / 96MB（vendor_boot 含 cmdline 与触控固件） |
| super | 12GB 动态分区 |
| abl / xbl | `0x100000` / `0x380000`，**Critical Partition：fastboot 禁刷，只能 9008** |
| 解锁态 | `unlocked: yes`，`secure: yes`；`version-bootloader` 为空，无法读 ABL 版本 |
| vbmeta_vendor | 无 |

**AVB 真相**：根 vbmeta 是 `SHA256_RSA4096`，公钥即 AOSP `testkey_rsa4096`；ABL 内嵌钉钥也是 testkey4096（`ValidateVbmetaPublicKey` memcmp 1032 字节）。所以 **AVB 这层能过，但不代表第三方 recovery 能启动**——ABL 另有独立于 AVB 的 recovery 白名单。

## 三条路线，一句话结论

| 路线 | 结论 | 依据 |
|---|---|---|
| 第三方 Recovery（TWRP / OrangeFox） | ❌ **死路，别再投入** | ABL recovery 原厂签名白名单【实测】 |
| Root / 内核（KernelSU / APatch / 定制 boot） | ✅ **唯一活路** | 不经过 recovery，社区已验证 |
| 换 system（A14 GSI / HyperOS 2.0） | ✅ **已验证可用**的常规路线 | 【实测】 |
| 换 system（A17 / 澎湃 4.0） | ⚠️ **实测起到过桌面**，但可复现性未闭合（见「A17 的真实边界」） | 【实测】 |

## 三条铁律

1. **启动链必须成套**：boot / init_boot / vendor_boot / vbmeta / system 必须来自同一发布套件。混搭 = 900E。
2. **一次只改一个分区**：改完确认能开机，再动下一个。
3. **任何镜像实验后立刻成对回滚槽位**（命令见下方"救砖"），禁止未回滚就连试多个镜像。

## 禁止清单（已证伪，别再投入）

**Recovery / AVB 伪装**
- 仅改 OrangeFox 编译参数、内核打包方式、清空 cmdline
- testkey vbmeta `flags=3`、`flags=0` + 全哈希重算
- TWRP / OF ramdisk 套原厂头；有效内容改 1 bit + 匹配哈希
- `of_algnone`：footer alg=NONE + 自洽哈希 + 原厂 salt/prop/96MB 头
- 把 OF 镜像塞进 boot 分区（即使"头部一字不差"的 96MB 版 + 匹配 vbmeta）
- 用 64KB vbmeta 解决 ZUI16 启动（反导致系统无法启动）
- TWRP 20260827 / 20260814 / repack 三个版本 → 一律回 fastboot

**固件 / 解锁**
- 9008 降级 ZUI15 abl：写入成功、读回一致，**第三方 rec 仍被拦**；且 ZUI15 abl + ZUI16 系统起不来
- 运行时翻 flag（`oem unlock` 唯一入口需 Lenovo 签发的 `unlock.img`）
- 私钥伪造（Elm 链 RSA-2048，无泄露证据）
- 改 `sn_AAAAAAAA.img` 十六进制里的 `AAAAAAAA` 为自身 SN（免邮件技巧，2026-10-18 实测不可用）

**系统**
- ~~澎湃 4.0 / A17「启动即中止、结构性不可行」~~ → ❌ **此说已撤回**：A17 实测起到过桌面（`release=17`/`boot_completed=1`/29 颗传感器/GCam+Via 已装）。见下方「A17 的真实边界」。
- 澎湃 4.0（A17）去掉 `tz_log_dlkm` + 关 `qseelogd` 后仍 900E（2026-10-24 真机实测，≤10 s；见 `E:\rom\docs\实验记录_A17_notz双补丁_2026-10-20.md` §7）。这说明**补丁方向不对**，不等于 A17 不可行。

## A17 的真实边界（2026-10-31 复核，重要）

**观测事实**：A17（澎湃 4.0）在 TB331FC 上**起到过桌面**，证据是设备回显 —— `release=17`、`sdk=37`、`boot_completed=1`、`dumpsys sensorservice` = `Total 29 h/w sensors, 29 running`（BOSCH bmi3x0）、`package:mark.via` 与 `package:com.android.MGC_8_8_224`（Via + GCam）已安装。

**起到桌面的那一套**：

| 分区 | 内容 |
|---|---|
| `vbmeta_a` | `vbmeta_a_D.img`（8192 B，testkey_rsa4096，flags=0，含哈希描述符 + chain→vbmeta_system） |
| `vbmeta_system_a` | `vbmeta_system_H.img`（4096 B，testkey_rsa2048，flags=0，三条 hashtree） |
| `system_a` / `product_a` / `system_ext_a` | `system_G` / `product_D` / `system_ext_D` |
| boot / vendor_boot / dtbo / init_boot / vendor / odm / vendor_dlkm | 原厂 ZUI16 544 |

**机制（avbtool 实测）**：`vbmeta_a_D` 的 chain 指向 `2597c218…`(rsa4096)，而 `vbmeta_system_H` 的公钥是 `cdbb7717…`(rsa2048) —— **对不上** → 链式校验不成立 → 系统分区不启用 dm-verity → 能起来（推断）。原厂 `vbmeta_a` 的 chain 正好指向 `cdbb7717…` → verity 生效 → 约 20 s 崩 900E（推断）。

**未闭合**：2026-10-27 同一组合（干净重刷三块 + H + `vbmeta_a_D`）也 900E，当时 `system_ext_a` 刚被 Resizing、`--set-active` 报过错。**定论只差一次干净状态下的单变量复验**：只换 8 KB 的 `vbmeta_a`，看是否一进一崩。

→ 该复验已写成脚本：`E:\rom\work\tools\a17_single_var_vbmeta.ps1`（`-Variant prep/off/on/report`，已 dry-run 校验、**未跑真机**；台账落 `E:\rom\work\logs\a17_single_var_result.txt`）。`off` 预测起桌面、`on` 预测 20 s 900E；两边同行为则机制被推翻，照实记。

⚠️ **基线已变（做 A17 实验前必读）**：10-27 之前所有 A17 观测都取自 persist **整块全零** 的机器，11-01 才写回修好。旧日志里的传感器数、音频行为、崩溃时序都**不能**当现在的预期。重跑必须重记。

→ 详细证据与反证条件见记忆 `A17-TB331FC-可开机配置与900E分界`。

## 当前状态（2026-11-07 刷新）

- 设备：**原厂 ZUI 16.0.544（A14 / SDK 34）正常开机**，声音与录音 11-01 已修好（用户两次确认，间隔 9.5 h）。A17 三件套**当前不在机上**，资产在 `E:\rom\work\a17stage\`。
- 澎湃 4 线：能起桌面已被证实，可复现性靠一次 8 KB 单变量实验收尾（脚本已就绪，缺设备）。
- OrangeFox 编译产物已发布（GitHub `dsshhgg/TB331FC-TWRP`，分支 `fox-12.1`），但**设备上进不去**（此条自 10-18 未变）
- 主路径仍是 **KernelSU / APatch 刷 boot**
- 2026-10-18 原文（保留不改历史）：设备为完全干净原厂链（a 槽），ZUI 16.0.544 可开机。

## Playbook A · 解锁 Bootloader

只走官方通道，没有捷径：

```text
① 开发者选项开 USB 调试 + OEM 解锁
② fastboot getvar all 2>result.txt  → 取 ufs_sn 与 serialno
③ 电脑访问 https://m.zui.com/iunlock → 板块选「拯救者 Y700 五代」
   序列号 = serialno，Bootloader_sn = ufs_sn（填反必失败）
   sn.img 必须 356 字节；建议中午 12 点前申请（否则"今日满额"）；每账号每年 3 台
④ fastboot flash unlock sn.img
   fastboot oem unlock-go        # 也见 unlock_go，哪个通用哪个
   音量键选 UNLOCK THE BOOTLOADER → 电源键确认 → 黄色感叹号 = 成功
```

常见报错：`Flashing is not allow in lock state` → 需先降级；`sn.img` 非 356 字节 → `ufs_sn` 填错，重申请。
解锁即失保、不可回锁；**非官方回锁极大概率变砖**。

## Playbook B · Root（唯一活路）

两条路，别混：

| 目标 | 改哪个分区 | 做法 |
|---|---|---|
| KernelSU / Magisk 修补 ramdisk | **`init_boot`** | 管理器"选择并修补一个文件"→ 刷回**当前槽位** |
| 换整个 GKI 内核（自带 KSU + SusFS） | **`boot`** | 刷 [yxyyds666/TB331FC-Kernel](https://github.com/yxyyds666/TB331FC-Kernel) 的 `boot-main.img` |
| APatch | boot 或 kernel patch | 本机已备 APK |

现成内核基线 `android13-5.15.167_r00`（与 stock KMI 一致），最新 1.3.2，仓库自带 `boot_a.img` 回滚。
⚠️ **不要注入非空 boot cmdline**（高通 ABL 缺陷会不开机）。

**修补 init_boot 必须保留的两项**【实测，最易踩】：

| 文件 | 大小 | 丢了会怎样 |
|---|---|---|
| `lib/firmware/novatek_ts_fw.bin` | 196,608 B | 触控失效 |
| `system/etc/ramdisk/build.prop` | 1,302 B | 密度错误（240 密度修复） |

典型症状：root 拿到了，但屏点不动或显示比例怪 → 用原厂 `init_boot_a_原始.img` 重新修补。

```bash
fastboot flash init_boot patched.img      # 在 b 槽就刷 init_boot_b
fastboot reboot
adb shell su -c id                         # 期望 uid=0
adb shell getprop ro.boot.vbmeta.device_state    # locked / unlocked
adb shell getprop ro.boot.verifiedbootstate      # green / orange
```

fastboot 受限时走 **9008 回读/回写 init_boot**（见 `7.2.1`，免 fastboot）。

**红线**
- 不要叠刷：HyperOS v2 包已内置 KernelSU boot，再刷 `boot-main.img` 会冲突（root 冲突 / 不开机 / 模块异常）
- 旧 Magisk / 其它 root 先清理
- 管理器检测不到 → 先确认刷的确实是**当前槽位**的 init_boot

**boot loop 血案**：`kai_init.sh` 在 stage1 执行 `exec 3>>/dev/kmsg`，当时 `/dev/kmsg` 不存在 → rootfs 建普通文件 → PID1 泄漏 fd3 → `system_server` 每 5 秒崩一次（`Not allowlisted (3): /null`）。修法 `fastboot flash init_boot_a ib_patched.img`；教训：`exec 3>>/dev/kmsg` 前必须 `[ -c /dev/kmsg ]`。

## Playbook C · 系统移植（HyperOS / GSI）

**已知的 vendor 边界（不是死刑判决）**：设备侧 `ro.board.api_level=33`、`ro.vendor.api_level=33`、`ro.vndk.version=33`；A17 的 `init` 里有串 `Unexpected vendor api level for`，且 A17 的 `ro.llndk.api_level=202604`。vendor 是闭源 blob 改不了。
**但**：实测 A17 起到过桌面（见上方「A17 的真实边界」），所以 vendor 代差在这台机器上**不是阻断启动的点**——它顶多影响稳定性/外设（例：`imsdaemon` 每 ~10 s SIGSEGV 一次，属 A17 框架与 vendor IMS 不兼容）。旧版「结构性不可行」已撤回。
GSI 不含内核，天生跑在原厂 KMI 上——KMI 不是卡点。

**已验证可行：HyperOS 2.0 MysticGSI（自包含镜像）**，成品部署 3 步：

```text
第1步 刷系统
  fastboot reboot fastboot
  fastboot flash system 05_镜像/GSI/system_a_完全自包含.img     # 5,794,435,072 B
  fastboot -w                                                  # 从原厂首次刷必做
  fastboot reboot

第2步 装 KernelSU
  KernelSU_v3.3.0 修补 init_boot_a_原始.img（保留上面两项！）
  fastboot flash init_boot <patched>.img → 重启

第3步 装 KSU 模块退小米账号
  管理器 → 模块 → 从本地安装 → tb331fc_drop_xiaomi_account.zip
```

**为什么刷一个 system 就够**：自包含镜像内自带 `/product`、`/system_ext` 目录，反向遮蔽了独立的 `product_a` / `system_ext_a`（它们刷进去但从不挂载）；原厂 ZUI 下二者才是独立真分区。两种启动状态不矛盾。

**super 切片可直接刷**【实测，重大发现】：`TB331FC_ZUI_16.0.544\image\super_*.img` 就是各逻辑分区的原始 ext4，可 `fastboot flash system_a/product_a/system_ext_a`，不必 QFIL/9008（已验证两次）。
`super_4.img`=system_a、`super_3.img`=product_a、`super_6.img`=system_ext_a。
腾空间顺序：**先缩 product/system_ext，再扩 system**。

**开机自修复骨架**（移植核心机制）：`/system_ext/etc/init/miuibooster.rc` 起 `tb331fc_boot`，跑 `/system_ext/etc/tb331fc/_boot_fix.sh`。约束：
- 必须 `logwrapper + sh`（`/data` 是 nosuid，init 不能直接 exec）
- 必须 `seclabel u:r:su:s0`
- **永不 exit / 永不 kill**（oneshot 退出 → init 回收 cgroup → 杀掉 booster/笔看护）
- rc 放 second stage（init_boot ramdisk 里的 `*.rc` 不生效）

移植通用原则与"开包 13 项排查"（三件套、SELinux mapping、permissive、BPF、cache 软链、media.settings.xml、init.gsi.rc、GSI 属性、overlay、keymaster、sensorservice 等）见原文 `3.2`–`3.5`。

## Playbook D · 救砖与回滚

| 模式 | PID | 能否 QFIL |
|---|---|---|
| **900E** | `05C6:900E` | ❌ 还在 Sahara（`mode=02` memory dump），fh_loader / QSaharaServer 全超时；软件侧无解 |
| **9008** | `05C6:9008` | ✅ 标准 EDL |

进 9008：先充 20 分钟（0% 极易掉线）→ 长按电源 15–30 秒关机 → **同时按住音量+ 与 音量−** → 插 USB → "叮"后松开。失败可放余电 1 分钟重试，或用 `WuXingEdl.exe`，最后才拆机短接。
`adb reboot edl`：本机曾 `unknown command`，但社区教程成功——**两说都试**（系统内 adb、先点"读信息"）。

**QFIL 整包**：ufs + `0 - no validation` + Flat Build + Reset after download；`fh_loader --memoryname=ufs`（漏存储类型是上次失败真因）。
⚠️ **严禁勾选"全部格式化"**（丢 IMEI / SN / 校准数据）。

**fastbootd 救砖（比 9008 快，已验证两次）**：

```bash
adb reboot fastboot
fastboot flash system_a     super_4.img
fastboot flash product_a    super_3.img
fastboot flash system_ext_a super_6.img
fastboot -w
fastboot reboot
```

**槽位坑（实验后必做）**：

```bash
fastboot --set-active=a
fastboot flash boot_a   stock-boot.img
fastboot flash vbmeta_a stock-vbmeta.img
fastboot reboot
```

**900E 根因**：不是 system 单独坏，而是启动链与 system/vbmeta 不是同一发布套件（vbmeta 连大小都不同：65536 B vs 8192 B），外加 super 可能被 EROFS 试刷弄脏。

## persist 分区：官方刷机永远修不了的那块（2026-11-01 实证）

**症状**：声音和录音**同时**消失；`audioadsprpcd` / `adsprpcd` 每秒重启；声卡每秒"注册→注销"翻转；`sscrpcd` 反复报 `/mnt/vendor/persist/...` ENOENT。

**真因：`persist`（`/dev/block/sda2`，32 MB）整块全零。**

**为什么反复刷官方包没用**：`rawprogram0.xml` 里 persist 那行是

```xml
<program ... filename="" label="persist" num_partition_sectors="8192"
         physical_partition_number="0" start_byte_hex="0x8000" start_sector="8" />
```

`filename=""` = 只定义分区几何，**不写任何内容**。同理 `userdata_N.img` 是稀疏镜像、只覆盖非零扇区，所以**刷官方包不会清用户数据**。

**三个快速判据**（不用进 EDL 就能先判断）：

| 判据 | 健康值 | persist 全零时 |
|---|---|---|
| `cat /proc/mounts \| grep persist` | 有 persist 一行 | **没有** |
| `settings get global bluetooth_address` | 真实 MAC | **null**（BT MAC 变成随机 `22:22:...`） |
| `ls /mnt/vendor/persist/sensors/registry/registry` | 存在 | ENOENT |

**修法（只写 32 MB persist，不动别的分区）**：

1. 进 9008（音量+ + 音量− 插 USB）
2. **别依赖 QSaharaServer**——它会 `Unable to read packet header. Only read 0 bytes.`，但此时设备的 `BusReportedDeviceDesc` 已是 `QUSB_BULK_CID:043A_SN:...`，说明 firehose 阶段早已就绪，**fh_loader 可直接连**
3. 工作目录用**纯 ASCII**（如 `E:\rom\work\edl\`）

```bat
fh_loader.exe --port=\\.\COM4 --sendxml=write_persist.xml --zlpawarehost=1 ^
              --memoryname=ufs --noprompt --verbose --reset
```

两个易错点：
- 端口必须写 **`\\.\COM4`**，裸 `COM4` 会警告
- **只有 `--sendxml`，没有 `--readxml`**；读也是 `--sendxml`，XML 里用 `<read>` 元素

读 persist 的 XML：

```xml
<read SECTOR_SIZE_IN_BYTES="4096" file_sector_offset="0" filename="real_persist.img"
      label="persist" num_partition_sectors="8192" physical_partition_number="0"
      size_in_KB="32768.0" sparse="false" start_byte_hex="0x8000" start_sector="8" />
```

实测回读真机 persist：**`non-zero bytes = 0 (0.00%)`**（32 MB 全零），而刷机包 persist.img 有 22,695 个非零字节。写回后 `{SUCCESS}`、40.97 MBps，症状消失。

**写前必先回读备份**。通用镜像里的 MAC 是通用值；但原分区若已全零（MAC 为 null），写它只是改善，不会更差。

### 本节附带的三条误判教训

1. **日志里紧挨错误的那条 `No such file` 未必是根因。** 本次 `remote_heap_config.so` 的 `fopen` 失败被我当成病因，实测官方 `dspso.bin` 里它**命中 0 次**——官方根本没有这个文件，那只是探测性 warning。
2. **不能用 `uptime` 判"刷没刷机"。** 它只证明"区间内没重启"。要看 `btime` + `ro.boot.bootreason` + 有没有 `com.zui.setupwizard` 启动痕迹。同版本覆盖刷写**不会重装预装应用**，拿"预装应用还在"判没刷是错的。
3. **同一个现象名不等于同一个事实。** A17 那次 persist 也"未挂载"但音频正常（部分缺失）；这次是整块全零。**严重度必须看介质本身，不能看现象标签。**

## 快速排障

| 现象 | 根因 | 修法 |
|---|---|---|
| root 成功但触控失效 / 显示比例怪 | 修补 init_boot 丢了 novatek 固件 / build.prop | 用原厂 init_boot 重修补，保留两项 |
| 刷完只回 fastboot / 卡第一屏 | 启动链混搭、boot 用了源包 | 成套换回底包 boot/vbmeta |
| `system_server` 5 秒一崩 | PID1 fd 泄漏（`/dev/kmsg`） | 刷修好的 init_boot |
| 920E / 900E | 套件混搭 / vbmeta 链或描述符不对 | 按 7.6 对齐套件；A17 见上方「A17 的真实边界」 |
| **同一份 A17 内容，一次能起桌面、一次必崩**，中间没人改过 system | `vbmeta_a` 链公钥 ↔ `vbmeta_system` 实际公钥是否匹配，决定 dm-verity 开没开 | 跑 `tools\a17_single_var_vbmeta.ps1 -Variant off` 再 `-Variant on`（只差 `vbmeta_a` 的单变量复验），并读 `ro.boot.veritymode` |
| 蓝牙耳机无弹窗 / 一连就软重启 | `micloudbluetooth.db` 缺 deviceId；DAX 属性未设 | 见原文 `6.6` 的表 |
| QFIL 刷写失败 | 漏 `--memoryname=ufs` 或勾了全格式化 | 改参数；绝不全格式化 |
| **声音+录音同时没了** | **persist 分区全零（官方刷机不写它）** | **见上方「persist 分区」节：fh_loader 单刷 persist.img** |
| **MAC 变随机值 / `bluetooth_address` 为 null** | **persist 丢失（真实 MAC 存那里）** | **同上，单刷 persist** |

## 本地资产（E:\rom）

```text
E:\rom\extracted\GSI_Kit\05_镜像\      # system_a_完全自包含.img、init_boot/boot/vendor_boot/vbmeta 原厂镜像（救砖底牌）
E:\rom\release\OrangeFox-TB331FC\      # OF 镜像、vbmeta、avbtool.py、testkey_rsa4096.pem
E:\rom\release\ZUI15-extract\          # ZUI15 abl/boot/recovery/vbmeta + rawprogram*.xml
E:\rom\240412_..._ZUI_15.1.105_纯净版_售后专用\   # 只读原厂包
```

工具：QFIL（ufs / no validation / Flat Build）、`prog_firehose_sm6225_ddr.elf`、platform-tools；`sqlite3` 必须与 `libsqlite.so` 成对（见 `6.7.2`）。
仓库：内核 `yxyyds666/TB331FC-Kernel`；OF `dsshhgg/TB331FC-TWRP`（`fox-12.1`）；整机 LineageOS `gitanillo87/TB331FC`（深水区，需 `extract-files.sh` 抽 blob）。

## 维护

- 新的实测结论先改 `references/knowledge-base.md` 对应章节，再同步本页的"禁止清单 / 当前状态"。
- 本页只放判断与最短路径；命令细节、字节级逆向、时间线留在原文，避免两处漂移。
