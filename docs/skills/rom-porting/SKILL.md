---
name: rom-porting
description: 安卓 ROM 移植方法论（system 侧开包/直开/DSU 验证），蒸馏自酷安移植教程与 TB331FC 实战。当要把别人的 ROM（澎湃 HyperOS / ColorOS / Flyme / GSI 派生包）开到另一台机器上、只想改 system 不想动 vendor、需要决定替不替 init 与 libfs_mgr、要处理 apex/vndk 底包匹配、要补 selinux mapping、要把 init 宽容、要打包成 DSU 试开、要签 AVB/vbmeta、要在 fastbootd 建逻辑分区刷入、或者刷坏了要 9008 救砖时使用。也适用于回答「为什么卡开机动画/卡二/白屏/软重启」这类排障问题。
---

# 安卓 ROM 移植（system 侧）+ DSU 快速验证

本页是**方法论**，不是某台设备的说明书。设备专属事实（分区表、GPIO、镜像路径、内核版本）放在项目里的 `STATE.md` 与 `docs/`，本页只在末尾给索引。

## 何时用本页

- 手上有一个别的机器/别的品牌的 ROM 包（含 `system`/`product`/`system_ext`，常见 `my_*` 一类厂商子分区），想开到本机。
- 想**只动 system 侧**，保留本机 `vendor`/`vendor_dlkm`/`odm`/`boot`。
- 需要判断「这个底包能不能撑起这个移植包」（apex/vndk/first_api_level）。
- 要打包成 DSU 镜像先试开，或者要签 AVB、在 fastbootd 里建逻辑分区刷入。
- 刷坏了：只停在 fastboot / 连 recovery 都没了 / 掉 9008。

## 铁律

1. **vendor 尽量不动。** vendor 里是真固件（modem、DSP、WiFi/BT、摄像头 ISP 标定）。换 vendor = 换固件版本，风险与收益完全不对等。能靠改 system 解决的，绝不动 vendor。
2. **事实 / 推断 / 未知 三级分栏。** 观测到什么写什么；因果解释标「推断」；没有对照实验前不许说「唯一原因」「必然」「肯定是」。
3. **一个变量原则。** 一次只改一件事，改前先写清回滚手段。
4. **不碰 `abl`/`xbl`/`xbl_config`/`tz`/`hyp`。** 刷坏这些就得拆机或 JTAG。
5. 移植包能开起来 ≠ 能用。开机只是第一关，后面是 HAL、SELinux、解码能力、机型校验。

## 底包匹配：先算清楚，再动手

移植包能不能开在本机，取决于**移植包要求的最低 vendor 能力**与本机 vendor 的差距。

| 移植包 `system/system/apex` 里有 | 可用的底包 |
|---|---|
| `vndk30` | Android 11 底包起 |
| `vndk31` | Android 12 底包起 |
| `vndk32`/`vndk33` | A13 底包起 |
| （无 vndk 目录，纯文件 apex） | 与本机同代或更高 |

更硬的指标（比 vndk 靠谱）：

```bash
# 移植包（system.img 挂载后）
grep -E 'ro\.(llndk|vendor)\.api_level|ro\.board\.api_level|ro\.product\.first_api_level|ro\.system\.build\.version\.sdk' system/build.prop
# 本机 vendor
grep -E 'ro\.vendor\.build\.version\.(sdk|release)|ro\.vndk\.version' vendor/build.prop
```

- `ro.llndk.api_level` 高于本机 vendor 提供的等级 → 系统侧框架会降级/报错，`init` 里只有 `LOG(ERROR)` 级（`Unexpected vendor api level for `），**不是**立即致命；真正致命的多是 HAL/VINTF 与 SELinux。
- 想做「system 去适配 vendor」时，可改的只有 system 里那半边：`ro.llndk.api_level`（这属 system 的 `build_prop` 上下文）、`/system/etc/vintf/compatibility_matrix.*.xml`、`/system/etc/selinux/mapping`、`/system/etc/init/*.rc`。`ro.vendor.*` 属 vendor 属性命名空间，写进 system 的 `build.prop` 通常不生效——不要在这上面浪费轮次。

## 开包管线（按顺序做，每步可单独回退）

### 0. 解包
动态分区包：`lpunpack` / `payload_dumper` / 厂商工具；保持 `system`、`product`、`system_ext` 三个 ext4 原样。若包里是 `my_bigball`/`my_product`/`my_manifest` 这类厂商子分区，用「合并 my_ 分区」的思路把它们并进 `system` 外层（可先删 `my_*/dal-app` 减体积）。

### 1. 三件套（init / libfs_mgr）——**A12 以上必做**
从**本机底包**取同名文件替换移植包里的：

| 系统 | 要换的文件 |
|---|---|
| Android 12 | `system/bin/init` |
| Android 13+ | `system/bin/init`、`system/lib64/libfs_mgr.so`、`system/lib64/libfs_mgr_binder.so` |

理由（这是酷安那套「直开 rom」的核心）：移植包的 init/fs_mgr 是按它的分区布局与 first-stage 逻辑编译的，换成本机版本后它才会按本机的 fstab/vbmeta 走。本机底包打不开时，可从任一份能开机的 GSI 里取这三个文件。

### 2. apex 形态 → `ro.apex.updatable`
看移植包 `system/system/apex`：

- 里面全是**文件夹**（解开的 apex）→ 本机 `vendor/build.prop` 写 `ro.apex.updatable=false`
- 里面全是**文件**（`.apex` 文件）→ `true`

写错这一项，表现通常是 `apexd` 阶段挂住或反复重启。注意：这一步要改 vendor 是例外，并且它是**一行属性**，不是换固件。

### 3. SELinux 三件套替换（卡开机动画第一嫌疑）
把本机底包的这三个目录整体覆盖移植包：

```
system/etc/selinux
product/etc/selinux
system_ext/etc/selinux
```

但**不要**无脑覆盖 `mapping/`：跨大版本移植时映射文件是救命的东西。开 C17（Android 17）这类新系统时反而要**补** `30.cil`/`30.0.compat.cil`（system 下两个，product/system_ext 下各一个 `30.cil`）。

### 4. init 宽容（先让它起来，再收紧）
两法，优先方法一（不需要动 boot 链）：

```diff
# system/etc/init/hw/init.rc  (on early-init 段)
 write /proc/sys/kernel/sysrq 0
+write /sys/fs/selinux/enforce 0
```

```cil
# vendor/etc/selinux/vendor_sepolicy.cil 末尾
(allow init kernel (security (setenforce)))
```

方法二是给 `boot`/`init_boot`/`vendor_boot` 打宽容补丁（改 cmdline `androidboot.selinux=permissive` 或内核 `security=` 参数），新天玑与部分高通 ABL 不认，别默认它可用。宽容只是排障手段，最终要回到 Enforcing 并把 `avc: denied` 逐条补策略。

### 5. 属性与机型清理
- `my_manifest/build.prop`（或 `system/build.prop`）里 `ro.product.first_api_level` 前面加 `#`。
- 机型名/品牌改成自己的（否则 OTA、机型校验、云服务全乱）。
- 删掉只在原厂平台有意义的东西：`priv-app/com.qualcomm.location`、`sys_graphic_enhancement_config.json`、`sys_game_manager_config.json`、`my_product/etc/sys_game*`、带中文关键词的预装文件。

### 6. 常见故障 → 改法对照表

| 现象 | 先查 | 改法 |
|---|---|---|
| 卡开机动画 | selinux | 三件套替换 → 补 mapping → 宽容 |
| 开机前就重启（几十秒内） | `avc: denied`、kernel panic | ramoops/console 取证；区分「vendor 侧固有 denied」与致命 |
| 同一份 system 内容，一次能起一次必崩，且没人改过 system | **vbmeta 链是否成立 → dm-verity 开没开** | 用 avbtool 比对 `vbmeta` chain 描述符里的公钥与被链分区实际公钥；只换 8 KB 的 `vbmeta` 做单变量复验，别动 system |
| WiFi 起不来 / 开机引导软重启 | bpf、wifi apex | `system/etc/bpf` 补两个 WiFi 处理文件；换移植包自带的 WiFi apex |
| 开机引导到「快捷键/手势」页就软重启 | 缺 lib | `system_ext/lib`、`lib64` 补缺失库（报错会点名） |
| 开发者选项闪退 | 缺属性 | 补 `ro.debuggable`、`persist.sys.*` 一类，见原包对比 |
| C17（Android 17）卡二 | SELinux/文件上下文 | mapping 补 `30.cil`+`30.0.compat.cil`；`plat_file_contexts` 加 `/dev/ion u:object_r:ion_device:s0`；`uevent.rc` 挪到 `vendor/etc` |
| 相机崩 | 机型校验 | 换 LineageOS Aperture 之类无机型校验的相机 |
| 投屏/接力白屏 | 解码能力 | 大概率硬件天花板，收手（低端 SoC 解不了高分辨率视频流） |
| 打包报 ASCII/编码错 | 文本文件 | 按报错删/改对应行（通常是非 ASCII 注释进了配置） |

## 打包与分区布局

- **动态分区包**：`product`/`system_ext` 可以各自单独打包、单独刷。
- **静态分区包**：必须把 `product`、`system_ext` **合进 system**，并把它们的 init 补齐到 `system/etc/init` 与 `system_ext/etc/init`（否则 first-stage 找不到 sub-partition 就停）。
- 目标分区尺寸必须 ≥ 镜像尺寸，逻辑分区尺寸要是 **4096 的倍数**。

## AVB / vbmeta：最容易把人卡死的一环

必须记住的四条：

1. **footer 必须落在分区内。** `avbtool add_hash_footer --partition_size <分区大小>` 要求镜像本体 ≤ `分区大小 - footer预留(64 KiB) - 元数据`。直接对 1.75 GB 的 ext4 签名会报：
   `Image size of 1749999616 exceeds maximum image size of 1749929984 in order to fit in a partition size of 1749999616`
   → 顺序是 `e2fsck -fy` → 改内容 → `resize2fs` 缩到分区 ~98% → `truncate` → `add_hash_footer` → 补零到分区尺寸。
2. **`--do_not_append_vbmeta_image` 会让 footer 写到 EOF 之外**，`avbtool info_image` 报 `Given image does not look like a vbmeta image.`。想自己生成 vbmeta 就别用这个开关，用 `add_hashtree_footer`/`add_hash_footer` 让它写进文件。
3. **两把 testkey 别混用**：`testkey_rsa4096`（公钥 sha1 通常是 `2597c218…`）用于 `vbmeta`；`testkey_rsa2048`（`cdbb7717…`）常被原厂当作 `vbmeta_system` 的 chain 子密钥。位置：`https://raw.githubusercontent.com/LineageOS/android_external_avb/lineage-21.0/test/data/testkey_rsa4096.pem`（同理 `testkey_rsa2048.pem`）。**AOSP 的 test key 在 `platform_external_avb/test/data/` 下，不在 build 仓库的 security 目录里。**
4. **`--flags 2`（disable-verity + disable-verification）不是万灵药。** 有些 ABL 会因此判 slot 不可启动；更常见的坑是：`vbmeta_system` 里的 hashtree 根摘要与设备上实际分区内容不一致时，ABL 直接判「unbootable」，连 recovery/fastbootd 都不放行。

### 典型翻车现场：只停在 fastboot，recovery 也进不去

```bash
fastboot getvar slot-unbootable        # → a: yes
fastboot --set-active=a                # 清掉 unbootable，重试计数重新赋值
fastboot getvar slot-retry-count
```
`slot-unbootable:*: yes` = 重试次数耗尽被 ABL 标记，此时从该槽启动**任何**东西都只回 fastboot。`--set-active` 或重刷原厂 `vbmeta` 对可解。

另一个不变量：**别在没刷匹配 boot 链的情况下单刷外来 `vbmeta`。** vbmeta 的 hash 描述符描述的是它那一代的 `boot`/`dtbo`/`init_boot`/`vendor_boot`，单独换 vbmeta 会让 `fastboot reboot fastboot` 直接报
`Failed to boot into userspace fastboot; one or more components might be unbootable.`
→ 要换就同一步把 boot 链四件一起刷（fastbootd 本身跑在 recovery 的 ramdisk 上）。

## fastbootd：逻辑分区的唯一入口

```bash
fastboot reboot fastboot              # 必须等，别用 PID 变化判断
fastboot getvar is-userspace          # → yes 才是真 fastbootd（PID 可能不变！）
fastboot snapshot-update cancel       # 释放 COW 快照占用（OTA 半途的机器会吃掉好几 GB）
fastboot delete-logical-partition system_a
fastboot create-logical-partition system_a <size>   # 4096 的倍数
fastboot flash system_a img
```

- `adb devices` 把 fastbootd 显示成 `recovery` 是正常的，别据此判断刷机失败。
- `max-download-size` 只有 256–768 MB 时，大镜像会被 fastboot 自动切片，一次刷 1.7 GB 要 60–100 s，属正常。
- 判断是否 fastbootd **只看 `getvar is-userspace`**；`fastboot devices` 打印的 `fastboot` 字样不带模式信息（拿它做正则判断会假阳性）。

## DSU：迭代最快的一条路（不用 root、不动分区）

DSU 的要求非常具体，踩空一次会浪费半小时：

1. **扩展名是硬门。** `InstallationAsyncTask.verifyAndPrepare` 只看 URL 后缀，只接受 `gz`/`gzip`/`zip`；给 `.img` 一定抛 `UnsupportedFormatException: Unsupported file format`。
2. **`KEY_SYSTEM_SIZE` 必须等于 gz 解压后的字节数**，写错会在 verify 阶段失败。
3. **镜像必须有 AVB footer**（gsid 要读 `AVBf`/`AVB0`），所以「裸 ext4 直接 gzip」不一定行，先 `add_hash_footer`。
4. 放 `/sdcard/Download` 即可，不需要 root、不需要特殊的 SELinux 标签目录。

```bash
gzip -1 -c system_signed.img > hyp4.img.gz
adb push hyp4.img.gz /sdcard/Download/x.img.gz
adb shell am start-activity -n com.android.dynsystem/com.android.dynsystem.VerificationActivity \
  -a android.os.image.action.START_INSTALL \
  -d file:///sdcard/Download/x.img.gz \
  --el KEY_SYSTEM_SIZE <解压字节数> --el KEY_USERDATA_SIZE <同样大小>
# 盯 logcat：DynamicSystemInstallationService: status: READY, cause: INSTALL_COMPLETED 即为装好
```

重启进入 DSU 用 `com.android.dynsystem.ACTION_REBOOT_TO_DYN_SYSTEM`（`am start-foreground-service -n com.android.dynsystem/.DynamicSystemInstallationService -a …`），或点通知里的「重启」。

**装好但重启回原系统**，按这个顺序查：
- 是否真的调了 REBOOT_TO_DYN_SYSTEM（logcat 里应有 `ShutdownThread: Rebooting, reason: dynsystem`）；
- first-stage 能不能看见 GSI 元数据（`metadata` 必须在 `first_stage_mount` 里）；
- GSI 的 AVB 公钥是否存在于 first-stage（vendor_boot 的 ramdisk 里没有 `/avb/*-gsi.avbpubkey` 时，fs_mgr 校验 GSI 会失败并回落正常启动——可以改 vendor_boot 里的 fstab 去掉 system 行的 `avb_keys`）；
- shell 读不到 `/metadata/gsi`、`/data/gsi` 是正常的（标签限制），别拿 `ls` 失败当证据。

## 救砖：从轻到重

1. `fastboot --set-active=a` / 重刷原厂 boot 链 + vbmeta → 多数「只回 fastboot」都能救。
2. 停在 900E（Qualcomm HS-USB Diagnostics）：长按电源复位；能进 recovery 时 `adb reboot edl` 直进 EDL，比按键可靠。
3. 9008 EDL 全量恢复（Windows，厂商 firehose）：

```bash
# 端口写裸 COMx，别写 \\.\COMx（QSaharaServer 在 Windows 上写全反而打不开）
QSaharaServer.exe -p COM4 -s 13:prog_firehose_sm6225_ddr.elf
fh_loader.exe --port=COM4 --memoryname=ufs --lun=0 --sendxml=rawprogram0.xml \
  --search_path=<image目录> --mainoutputdir=<输出> --noprompt --showpercentagecomplete --zlpawarehost=1
# 每个 LUN 跑 rawprogramN.xml，再每个 LUN 跑 patchN.xml，最后 --reset
```

- `--reset` 之后不要只看 `adb devices`，用 `Get-PnpDevice` 看 PnP：设备可能先以 `WPD / MTP`（`VID_17EF`）出现，说明系统已经起来了，只是 USB 调试没开。
- `fh_loader` 每个 LUN 结束必须看到 `All Finished Successfully`；只看到回显命令行 = 没执行。

## 反模式清单（都是踩过的）

- 拿外来 `vbmeta` 单独刷，不带同代 boot 链 → 丢 fastbootd。
- 对整块 ext4 直接签 footer（超分区上限）。
- 给 DSU 喂 `.img`（必须 gz/gzip/zip）。
- 用 115200 串口推几百 KB 文件（会话会被打断）。
- 把 PowerShell here-string 塞进 `wsl -- bash -lc`（引号被拆，命令半截）。
- 在 PowerShell 里写 `function Run($args)`（`$args` 是自动变量，参数全丢）。
- 用 `adb devices` 输出里的 `device` 字样做正则判断模式（`List of devices attached` 会命中）。
- 用 `Get-ChildItem -Recurse -Include *a*,*b*` 找文件（退化成全盘遍历，几万行输出）。
- 只看「能开机」就宣布成功（要继续验 HAL、相机、WiFi、触控、音频）。

## 设备实例（TB331FC / khaje / SM6225-AD）

别在本页硬记数值，去项目里查：

- 设备现状与回滚表：`E:\rom\work\docs\STATE.md`
- 用户约束与验收标准：`E:\rom\work\docs\user-requirements.md`
- 动作协议（先翻→再想→再做→再记）：`E:\rom\work\docs\ACTION-PROTOCOL.md`、`E:\rom\work\docs\ACTION-LOG.md`
- GPIO 反解（每个引脚带 文件:行号 证据）：`E:\rom\work\docs\gpio-reverse-2026-10-25.md`、`E:\rom\work\docs\gpio-table-dtbo03.md`
- 酷安原始教程摘录：`references/coolapk-posts.md`

该机已知硬约束：vendor 为 Android 13 / API 33 / VNDK 33（连 ZUI17(A15) 的 vendor 也还是 33），所以「上游 A17 系统 + 本机 vendor」会撞 LLNDK/HAL 代差——**但代差不等于不能开机**：2026-10-26 该机在 vendor 一字未动的前提下，A17（澎湃 4.0 / SDK 37）实测启动到桌面（`boot_completed=1`、29 颗传感器在跑），代差表现为个别 vendor 进程崩溃（`imsdaemon` SIGSEGV）而非启动中止。ABL 只认联想签名链且会在重试耗尽后标 `slot-unbootable`；`fastboot boot`（临时引导）被禁用；不受支持时进 900E 而不是报错。

> 方法论层面值得带走的一条：**算出「vendor 世代不够」之后，不要直接跳到「所以不可行」。** 代差的真实后果要用一次真机启动去量，而不是从属性值推。跨世代移植里「init 记录了代差」和「init 因代差中止启动」是两件不同的事，前者只是 `LOG(ERROR)`。

## 参考来源

- 酷安 `54016435`（直开 rom：init/libfs_mgr 三件套 + apex/vndk 底包匹配 + selinux 三件套）
- 酷安 `74410987`（ColorOS 开包：my_* 合并、passwd/group、apex vndk30、bpf WiFi、C17 mapping/ion/uevent.rc）
- 酷安 `68516435`（ColorOS15 思路：DNA 工具、property_contexts 改法、两种 init 宽容）
- 酷安 `73850847`（同机型 HyperOS 2.0：只覆盖 system，vendor/odm 留原厂；自修复脚本思路）
- 酷安 `73851871`（平板移植刷机流程：MD5 校验、刷 super/vbmeta 全家、`-w`、首开 5–15 min）
