# ACTION-LOG — 动作流水（每次动作后追加，不要改写历史）

格式：`时间 | 动作 | 关键命令/对象 | 结果 | 证据 | 回滚点 | 遗留`

---

2026-10-25T15:0x+08 | 造 A17 system 变体（A/B 两版）+ 自签 testkey vbmeta | `E:\rom\work\tools\build_a17_system.sh`、`make_vbmeta_testkey.sh` | OK | `a17stage\system_A.img` sha256 `7fdfbba4…`、`system_B.img` sha256 `eb1dd7d3…`、`vbmeta_a_tk_flags2.img` 8192 B pubkey sha1 `2597c218…` | 无（只生成本地文件） | AVB footer 必须留尾部 64 KiB；`resize2fs` 到 427000 块再签名

2026-10-25T16:0x+08 | 9008 全量恢复 ZUI16 544（A14） | `QSaharaServer.exe -p COM4 -s 13:prog_firehose_sm6225_ddr.elf` + `fh_loader.exe --sendxml=rawprogram0..5.xml` + `patch0..5.xml` + `--reset` | OK（全部 All Finished Successfully） | 设备重新枚举，adb 出现（序列号 `SN-REDACTED-A`，需在平板点「允许」） | 再刷 544 全量包 | 恢复后设备能进系统、能授权 adb

2026-10-25T17:1x+08 | 把 a 槽三件套换成 A17 + 自签 flags=2 vbmeta | `fastboot reboot fastboot` → `delete-logical-partition system_a/product_a/system_ext_a` → `create-logical-partition`(1749999616 / 2999996416 / 1549996032) → `flash` 三件套 + `vbmeta_a`/`vbmeta_system_a`（testkey flags=2） | 刷写全部 OKAY（system 75.8 s / product 92.5 s / system_ext 45.2 s） | 分区尺寸回读 `system_a 0x684EE000`、`product_a 0xB2D05000`、`system_ext_a 0x5C631000`；`vendor_a 0x289B7000` 未动 | 544 全量包（9008）或 460 raw 镜像 | —

2026-10-25T17:20+08 | 重启观察 A17 是否能起 | `fastboot reboot` + 200 s 轮询 USB/adb | **FAIL：始终 `18D1:D00D`（bootloader），无 adb、无 900E、无动画** | 200 行轮询日志全同 | 同上 | 疑点：ABL 可能拒绝 flags=2 的 vbmeta（但 10-18 用原厂 vbmeta 曾起 ~10 s）

2026-10-25T17:30+08 | 落地用户动作协议 | 新建 `ACTION-PROTOCOL.md` / `STATE.md` / `ACTION-LOG.md` + 记忆文件 `TB331FC-动作协议-先翻再想再做再记` | OK | 见三文件 | 无 | 后续每个动作按四步走
2026-10-25T17:40+08 | GPIO 反解报告 v2（补齐 NFC/相机/霍尔/编解码器，全部带行号） | `gpio_table.py` 解析 dtbo_03（112 条属性）→ `gpio-table-dtbo03.md`；重写 `gpio-reverse-2026-10-25.md` | OK | 触控 irq 80/reset 86、屏 reset 82/TE 81、背光 27、BT 87、功放 102/106·97/96·65/25·103/85、NFC 71/31/69/70、相机 20/18·21/24、UFS 113、SD/SIM 88、PD 93、充电 36/84/75、霍尔 66、vol_up 5 | 无（只读分析） | GPIO86 与 NFC clkreq pinctrl 疑似双占用（列为未定项，给了验证命令）
2026-10-25T17:56+08 | 构建 system_C（A17 system + `ro.llndk.api_level=33`/`ro.vendor.api_level=33`/`ro.vendor.build.version.sdk=33`） | `build_system_C.sh`（WSL root）→ `E:\rom\work\a17stage\system_C.img` 1,749,999,616 sha256 47d3d8ae…；testkey 签名 pubkey 2597c218… | OK | 未刷（等设备可进 fastbootd） | 末次 `e2fsck -fn` 仍报 Inode 7(resize inode) i_size 提示，属 resize2fs 已知噪声，下次构建加一轮 `-fy`
2026-10-25T17:59+08 | 构建 vbmeta 对（flags=2 + boot 链描述符 + chain→testkey） | `build_vbmeta_C.sh` → `vbmeta_a_C.img` 8192 / `vbmeta_system_a_C.img` 4096，含 boot/dtbo/init_boot/vendor_boot 四个 hash descriptor | 刷入 OKAY | **仍进不了 fastbootd**：`Failed to boot into userspace fastboot; one or more components might be unbootable`
2026-10-25T18:02+08 | 换回原厂 544 `vbmeta_a`/`vbmeta_system_a` 复测 | — | 刷入 OKAY | **依旧进不了 fastbootd**（同一报错）→ 排除「自签 vbmeta 被拒」这一假设
2026-10-25T18:05+08 | 直接 `fastboot reboot` 观察 90 s | — | — | USB 恒为 `18D1:D00D`（bootloader），无 adb、无 900E → ABL 判定 slot a 不可启动，连 recovery（fastbootd）也不放行
2026-10-25T18:20+08 | 给 A17 三件套追加 hashtree footer 并生成正确描述符 | `build_hashtree.sh`（avbtool `add_hashtree_footer --do_not_generate_fec`，先 resize2fs 到 98%） | OK | `system_tree.img` 1,728,512,000 sha 8e03ef6a…、`product_tree.img` 2,963,148,800 sha 60496795…、`system_ext_tree.img` 1,530,961,920 sha 2965d3d1…；描述符 `desc_{system,product,system_ext}.img` 各 2176 B，Root Digest 9cd816ef…/197f1514…/9aceef96…
2026-10-25T18:22+08 | `fastboot oem edl` 失败（unknown command） | — | 失败 | 设备停在 bootloader 无法自进 9008 → 需人工：关机后按住音量+/- 再插 USB 进入 EDL
2026-10-25T18:29+08 | 9008 全量恢复 544（用户手动进 EDL，COM4） | QSaharaServer + fh_loader rawprogram0..5 + patch0..5 + reset | 全部 `All Finished Successfully`，reset 后 10 s 枚举成 18D1:D001（adb 报 `recovery`） | 设备可用；fastbootd 恢复可用（`is-userspace: yes`）
2026-10-25T18:52+08 | 在**同一 fastbootd 会话**里刷入 A17（hashtree 版 + 匹配 vbmeta） | `delete-logical-partition` ×3(OKAY) → `create-logical-partition` system_a 1,749,999,616 / product_a 2,999,996,416 / system_ext_a 1,549,996,032(全 OKAY) → flash `system_tree.img`(61 s) / `product_tree.img`(101 s) / `system_ext_tree.img`(50 s) 全 OKAY → flash `vbmeta_a_D.img` / `vbmeta_system_a_D.img` OKAY → `reboot` | OK | **关键验证：ABL 放行了**（不再卡在 bootloader）
2026-10-25T18:56+08 | 首次 A17 真机启动观察 | 5 s 内 USB 变 `VID_05C6&PID_900E`（Qualcomm HS-USB Diagnostics），无 adb 无 fastboot | — | **与 2026-10-18 那次现象完全一致**：A17 system 在 544（A14/API33）vendor 上起得动，但数秒内崩进 900E。下一步取证：给 544 vendor_boot 开 ramoops console 并放进 vbmeta 描述符，崩后 warm reset 回原厂读 `/sys/fs/pstore/console-ramoops`
2026-10-25T18:57+08 | 记录结论：vbmeta 描述符一致性是 ABL 放行的唯一门槛（已用 hashtree 方案打通），崩溃点是另一回事（内核/驱动层） | — | — | 结论入 STATE
2026-10-25T22:35+08 | **更正上一条的措辞**：把「A17 的 system 真的被拉起来了」降级为「设备离开了 fastboot 并崩进 900E，但**崩溃阶段未知**」 | 复核今日全部工具输出 | — | 已观测（事实）：①补齐 hashtree+匹配 vbmeta 后 `fastboot reboot` 5 s 内 USB=`VID_05C6&PID_900E`；②在此之前（描述符不匹配时）同一台设备 `fastboot reboot` 后 90 s 恒为 `18D1:D00D`，无 900E；③18:29 全量恢复 544 后设备能正常进 recovery/系统。未证明（推断）：A17 是崩在内核 early、init first-stage、还是 system_server；未证明：描述符不匹配是 ABL 拒启的**唯一**原因（未做「原厂分区 + 自签 vbmeta」对照实验）。 | 待补对照实验：保持 vbmeta_a_D/vbmeta_system_a_D 不变、把三块换回原厂 544 → 若能正常启动，则证明 900E 由 A17 内容引起而非 vbmeta 改动引起
2026-10-25T22:41+08 | 固化「做事要讲证据」规矩（m02359/m02368） | 写记忆 `记忆：证据优先-事实与推断必须分开`（type=work_method, priority=99）；更新 `user-requirements.md` 第 F 节 12~15 条、`ACTION-PROTOCOL.md` 补「三级分栏/反证条件/禁用词」 | OK | 以后所有结论按「观测事实 / 推断 / 未知」分栏输出 | 无
2026-10-25T23:10+08 | **定位「fb 且 rec 消失」真因**：a 槽被 ABL 标记 `slot-unbootable: yes`（重试耗尽），此时 ABL 拒绝从该槽启动**任何**目标（system/recovery/fastbootd），只停在 fastboot；`fastboot --set-active=a` 清除后恢复 | 观测：`getvar slot-unbootable:a` → yes→(set-active 后)no、`slot-retry-count:a` 6→7；`fastboot reboot recovery` 前后对比：前 100 s 无任何 adb 设备（一直 18D1:D00D），后 10 s 出现 `SN-REDACTED-A recovery`（18D1:D001） | OK | 以后每次「卡在 fastboot 起不来」先查 `slot-unbootable`/`slot-retry-count` 四项 | 见下条被推翻的两个假设
2026-10-25T23:10+08 | **推翻两个先前假设**（保留记录）：①「vbmeta 缺 recovery 描述符导致 recovery 不启动」——已把原厂 544 vbmeta 刷回（含 recovery 描述符，且该描述符 digest 与 `recovery.img` 前 14,577,664 B 实测吻合 `57af3911…`），recovery 仍起不来 → 假设不成立；②「recovery 分区内容不匹配」——把 544 `recovery.img` 直接刷进 `recovery_a` 后仍起不来 → 假设不成立。真因是 slot-unbootable（上一条）。 | 观测见左 | OK | 结论：这套 ABL 的「不能启动」优先看槽状态，其次才是 AVB 细节 | 无
2026-10-25T23:10+08 | **新发现（可用钥匙）**：AOSP `testkey_rsa2048.pem` 的公钥 sha1 = `cdbb77177f731920bbe0a0f94f84d9038ae0617d`，**正是原厂 544 `vbmeta.img` 里 chain→vbmeta_system 指定的那把钥匙** → 我们可以用官方 testkey 自行签发 `vbmeta_system`，同时保持原厂 `vbmeta_a` 不动即可通过链验证。已产出 `E:\rom\work\a17stage\vbmeta_system_G.img`（4096 B，SHA256_RSA2048，含 A17 三块 hashtree 根摘要，pubkey sha1 与链一致）。 | 证据：`avbtool extract_public_key` 输出 sha1 与 `info_image` 里 Chain Partition 的 pubkey sha1 逐字符相同 | OK | 下次做 A17 实验可直接用「原厂 vbmeta_a + 自签 vbmeta_system_G」这套组合，无需再造 vbmeta_a | 待设备恢复后验证
2026-10-25T23:11+08 | **按用户 m02430「先刷回原系统」执行 9008 全量回刷 544**（rawprogram0..5 + patch0..5 + reset），设备由 recovery 经 `adb reboot edl` 进入 9008（COM4） | 观测：`adb -s SN-REDACTED-A reboot edl` 后 2 s 枚举 `Qualcomm HS-USB QDLoader 9008 (COM4)` | 进行中 | 完成后需验证：能进系统、`ro.build.version.release=14`、slot-unbootable:a=no | 若失败退回 fastbootd 逐分区方案
2026-10-25T23:23+08 | 9008 全量回刷完成但设备未上 USB | 观测：rawprogram0、0..5 全部 `All Finished Successfully`（rawprogram0 178 s、rawprogram4 17 s），patch0..5 全 ok=1 err=0，`--reset` 已发出；此后 200 s 轮询 + 手动复查，`VID_18D1/17EF/05C6` 全无、`adb devices` 空、`fastboot devices` 空 | 待确认 | 需要用户看屏幕：黑屏/充电图标 = 关机或纯充电；Lenovo logo = 卡开机；无任何 USB 枚举说明连 bootloader 都没进 | 下一步：长按电源 10~15 s 断电再开机；若仍是黑屏则再进 9008 重刷或查电池

## 2026-10-26 05:53 重建 A17 三件套（真 hashtree footer）+ 备好 D1 刷机脚本
- 事实：uild_hashtree2.sh 去掉 --do_not_append_vbmeta_image，三块 97% 一次过；产出 system_D/product_D/system_ext_D（Root Digest 依次 490ccf7d…/832596f2…/83f7fa74…）与 vbmeta_system_E.img（testkey_rsa2048，pubkey sha1 cdbb7717…）。
- 事实：lash_a17_d1.ps1 已过语法检查，等设备进 bootloader/fastbootd 即可执行；实验设计=只换 a 槽三块 + vbmeta_system_a，vbmeta_a 与 vendor 全栈不动（单变量）。
- 未知：llndk 由 202604 降 33 后能否跨过 900E（本次即为该单变量实验）。

## 2026-10-26 18:5x 传感器修复（system_G）
- 观测：system_F 上 persist 未挂载，sscrpcd 报 /mnt/vendor/persist/sensors/registry/registry ENOENT，dumpsys sensorservice = No Sensors。
- 动作：system_G 只追加 on post-fs-data 的 mkdir 链（/mnt/vendor, /mnt/vendor/persist, .../sensors, .../sensors/registry, .../sensors/registry/registry），刷 system_a + vbmeta_system_H。
- 结果：dumpsys sensorservice 列出 29 h/w sensors（32 条 sensor 条目），含 bmi3x0 Accelerometer / Gyroscope（BOSCH ver 306）→ 自动旋转恢复。
- 备注：registry 落在未挂载的目录树（tmpfs）上，重启后由 sscrpcd 重建；校准数据不持久（推断），若旋转精度异常再做持久化。
- 其他：imsdaemon（/vendor/bin/imsdaemon，lib-imscommon.so registerImsFactoryHal 空指针）每 ~10 s 崩一次，属 A17 框架与 vendor IMS 不兼容；已 settings put global hide_error_dialogs 1 静音。

## 2026-10-27 06:50 9008 全量回刷原厂 544（还原到能开机）
- 触发：product_F（含 552 MB GCam APK）刷入后无法开机 → fastbootd 起不来 → 只在 recovery / 900E 之间循环（观测：23:29–23:35 连续 7 分钟只有 900E）。
- 动作：先试已知可开机组合回滚（product_D + vbmeta_system_H，82 s + 4 KB，全部 OKAY，slot-unbootable:a=no）→ 重启仍崩 900E；改为保底路线：从 recovery db reboot edl → 9008（COM5）→ QSaharaServer 传 prog_firehose_sm6225_ddr.elf（666689 B，Sahara completed）→ fh_loader rawprogram0..5（rawprogram0 180 s）→ patch0..5 → reset，全部 All Finished Successfully。
- 结果（观测）：06:54:23 设备以 VID_17EF&PID_7E5F「小新Pad 2024」枚举并持续稳定 → 原厂 544 系统已启动；adb 不可用属正常（出厂 USB 调试未开）。
- 结论：设备已恢复可开机。A17 的三件套（system_G/product_D/system_ext_D + vbmeta_system_H）仍是历史可用组合，但 product 换成 3.6 GB + GCam 预装的 product_F 会让开机失败（原因未定，两个候选：PM 扫描 552 MB APK、或 hashtree/分区尺寸不匹配）。
- 教训：①任何 .ps1 在 PS 5.1 下无 BOM 中文会乱码 → 一律内联或加 BOM；②db devices 解析必须用 (?m)^(\S+)\s+(device|recovery)\s*$，否则会把 "List of devices attached" 里的 "of" 当序列号；③& script.ps1 会被执行策略拦，必须内联执行。
## 2026-10-27 07:20 工具链落地（a17toolkit）
- 依用户选择（m03332：先做 Frida/root 工具链，再动设备）搭建 E:\rom\work\a17toolkit\。
- 已就绪并验证：adb 37.0.1（自带 AdbWinApi/AdbWinUsbApi）、fastboot、rida-server-17.24.3-android-arm64（84,715,688 B，与 host frida 17.24.3 匹配）、jadx 1.5.1（--version 实测）、apktool 2.11.1（java -jar --version 实测）、host 侧 frida/frida-tools 17.24.3 + androguard 4.1.4、JDK 21.0.11、Python 3.12.10。
- 脚本（全部语法校验通过）：scripts\push_frida.ps1、wm_dump.ps1（PowerShell Parser 0 错误）、wm_hook.js、systemui_hook.js（
ode --check 通过）。
- 文档：docs\README.md（目录、运行方式、执行策略、6 条已踩坑、5 步窗口层级排查套路）。
- 观测：wm_dump.ps1 只需 USB 调试（shell 权限即可跑 dumpsys/uiautomator），不需要 root；Frida 需要 root（userdebug 或 KSU）。
## 2026-10-27 18:24 救砖完成：9008 全量回刷 544，设备恢复可开机
- 事实：EDL(COM5) QSaharaServer 666689 B Sahara completed；rawprogram0..5 与 patch0..5 全部 "All Finished Successfully"；reset 后 18:23:36 枚举 MTP、18:23:45 出现「小新Pad 2024」→ 原厂 ZUI16 544(A14) 已启动；adb 空（USB 调试默认关闭）。
- 事实：本次恢复前，A17 组合在「三个分区逐块重刷、内容一致、vbmeta_system_H」条件下仍于约 20 s 崩到 900E；把 vbmeta_a 换回 vbmeta_a_D 后同样 900E（18:11:23）。
- 结论（推断，未证实）：900E 与 vbmeta_a 身份、与分区内容完整性均无关；崩溃发生在 ABL 放行之后的内核/init 阶段，需要 ramoops 或串口才能定位。
- 教训：vbmeta_a 若缺少/写错描述符，会让 fastbootd 与 recovery 一起不可用（本次用原厂 vbmeta_a 恢复）；进入 fastbootd 的可靠路径 = bootloader → 原厂 vbmeta_a → fastboot reboot recovery → adb reboot fastboot。
## 2026-10-27 18:40 查清「10-26 那次为什么能开机」= vbmeta 链密钥对不上（证据 + 落盘）
- 观测（avbtool info_image）：vbmeta_a_D.img 的 Chain Partition 描述符指向 vbmeta_system 公钥 sha1 = 2597c218aae470a130f61162feaae70afd97f011（SHA256_RSA4096）；而实际刷入的 vbmeta_system_H.img 由 testkey_rsa2048 签名，公钥 sha1 = cdbb77177f731920bbe0a0f94f84d9038ae0617d（SHA256_RSA2048）。两者不匹配。
- 推断（有对照，待补一次干净复验）：vbmeta_a_D 在位时 ABL 的链式校验不成立 → 系统分区不启用 dm-verity → A17 能起到桌面；原厂 544 vbmeta_a 的 chain 正指向 cdbb7717…（与 H 匹配）→ verity 生效 → A17 约 20 s 崩到 900E。
- 未闭合：10-27 18:11 那次「干净三块 + H + vbmeta_a_D」也 900E，与上述机制矛盾；当时 system_ext_a 刚被 fastbootd Resizing 过、--set-active 报过 Unable to set slot。定论需在干净状态重做这条单变量。
- 记录：新建记忆 记忆：A17-TB331FC-唯一可开机配置（priority 95），含可开机配置表、链密钥机制、五条硬约束、9008 救砖步骤、未闭合疑点。
- 教训：E:\rom\work\docs 下的 md 是 UTF-8 无 BOM，读取必须 Get-Content -Encoding UTF8，否则显示成 GBK 乱码（文件本身没坏）。
- 用户重申协议（m03633）：每个动作「先翻 → 思索 → 进行 → 记忆」，照 ACTION-PROTOCOL.md 执行。
## 2026-10-31 23:4x 撤回「A17 结构性不可行」——A17 实测起到过桌面（更正 + 证据）
- 起因：用户重新提交三个会话档案（b43 / cff / 7366），要求"记得使用记忆系统"。按 ACTION-PROTOCOL 先翻 user-requirements / STATE / ACTION-LOG / OPLOG / 记忆库后，发现**已安装 skill 与历史实测互相矛盾**。
- 观测事实（设备回显，非转述；全部来自档案 `7366fc24` 的 tool/result 原文）：
  - `release=17`、`boot_completed=1`（seq 7322）
  - `Total 29 h/w sensors, 29 running`，含 `bmi3x0 Accelerometer / Gyroscope` BOSCH ver 306（seq 7343）
  - 指纹 `Lenovo/miproduct_yupei/TB331FC:17/CP2A.260605.016/OS4.0.5.0.XPZCNXM:user/release-keys`（seq 7380）
  - `package:mark.via`、`package:com.android.MGC_8_8_224`（Via + GCam 已装，seq 7580）
- 观测事实（avbtool 独立复核，本次重跑）：`vbmeta_a_D` 公钥 sha1 `2597c218…`(RSA4096)，其 chain 指向的 vbmeta_system 公钥**也是** `2597c218…`；`vbmeta_system_H` 实际为 `cdbb7717…`(RSA2048) → **不匹配**。
- 被撤回的说法：skill `tb331fc-flash-porting` 里「A17 → 启动即中止 → 结构性不可行」「A17 放弃」，以及知识库 §0.3 / §6.1 / §6.9 的对应条目。它解释不了上面四条回显。
- 已改（4 处 skill + 1 份记忆）：
  - `SKILL.md`：路线表拆成 A14 与 A17 两行；新增「A17 的真实边界」段；Playbook C 的"硬边界"改为"已知的 vendor 边界（不是死刑判决）"；排障表「A17 放弃」改为指向新段
  - `references\knowledge-base.md`：§0.3 撤回条目；新增 §6.1.1（含组合表、机制、反证条件、ABL 三规则、imsdaemon 非阻断故障）；§6.2 标题「唯一可行」→「已验证可用」；§6.9 撤回
  - 记忆：新建 `A17-TB331FC-可开机配置与900E分界.memory.md`(95)；旧 `A17-TB331FC-唯一可开机配置.memory.md` 停用为 `.disable`
- 仍**未闭合**：2026-10-27 18:11 同一组合（干净三块 + H + vbmeta_a_D）仍 20 s 900E，当时 `system_ext_a` 刚被 Resizing、`--set-active` 报 `Unable to set slot`。定论只差一次**干净状态单变量复验**：只刷 8 KB `vbmeta_a`，看是否一进一崩。
- 教训：①结论写进 skill 前必须指到**具体 tool/result 回显**，"init 里有某串"只证明它打了日志，不证明它中止启动；②同一组合两次结果不同时，应标"未闭合"而不是挑一个当结论；③本机 `search_memory` 仍恒返回 0 条，只能按文件名 `read`（`Get-ChildItem` 遍历）。

- 2026-11-01 修 bug（无设备操作，静态+试运行级验证）：`flash_a17_working.ps1` 与 `grab_a17_logs.ps1` 各修一轮；`make_vboot_ramoops.py` 去掉硬编码 WSL 发行版。
- 最值得记住的坑：PS 5.1 里 `L 'x[' + $a + ']'`（裸字符串后接 `+`）**不报错但只传第一个参数**，后半截被静默丢弃——日志会看起来"少了一半"而不报警。所有拼接必须套括号。
- 第二个坑：`wsl -l -q` 的 stdout 是 **UTF-16LE**，Python `text=True` 会按 cp936 解成 `U\x00b\x00u\x00...`，用它做发行版探测永远匹配不上；必须自己读 bytes 再 `decode('utf-16-le')`。
- 第三个坑：PS 5.1 的 `>` 重定向和 `Tee-Object -Append` 都产 **UTF-16LE/BOM** 文件，中文日志下游会乱码；一律用 `[System.IO.File]::WriteAllText($p,$t,(New-Object System.Text.UTF8Encoding($false)))`。
- 安全顺序修正：`--set-active=a` 必须在 `vbmeta_a_D` 写入**之前**执行并校验，否则 slot 修失败时才恰逢 recovery/fastbootd 已被 vbmeta_a 打断，只剩 9008。
- 设备状态：仍未接入（`adb`/`fastboot` 空、PnP 无目标 VID、只有 COM1）。真机验证待插机后执行。

- 2026-11-01：**声音+录音同时消失 = persist 分区整块全零**。官方 `rawprogram0.xml` 里 persist 是 `filename=""`（只定义几何、不写内容），所以**反复刷官方包永远修不好**。用 9008 + `fh_loader --sendxml` 单写 `persist.img`（32 MB）即恢复，用户确认修好。
- 三个快速判据（不必进 EDL）：`/proc/mounts` 无 persist 行、`settings get global bluetooth_address` = null、`/mnt/vendor/persist/sensors/registry/registry` ENOENT。
- 进 9008 后 **QSaharaServer 会失败**（`Only read 0 bytes`），但设备 `BusReportedDeviceDesc` 已是 `QUSB_BULK_CID:043A_SN:...`，说明 firehose 就绪，**fh_loader 直接连即可**。
- fh_loader 三个参数坑：端口必须 `\\.\COM4`；**没有 `--readxml`**，读也用 `--sendxml`；必须 `--memoryname=ufs`。
- 顺带确认：`userdata` 是稀疏镜像只覆盖非零扇区，**刷官方包不会清用户数据**；同版本覆盖刷写也不重装预装应用。判"刷没刷"要看 `btime` + `ro.boot.bootreason` + `setupwizard` 启动痕迹，**不能用 `uptime`，也不能看 `/data` 有无旧文件**。
- 本机三次误判教训：①日志里紧挨错误的 `No such file` 可能只是探测（`remote_heap_config.so` 官方 `dspso.bin` 里命中 0 次）；②同一现象名≠同一事实（A17 那次 persist"未挂载"是部分缺失、音频正常，这次是全零）；③先在介质层取证，再下因果结论。
- 未执行：用户要求的"清 data"因 persist 修复后声音已恢复而未做。未闭合：写入的是通用 persist 镜像，MAC 为通用值，非本机出厂 MAC。

- 2026-11-01T11:58 复验：用户隔约 9.5 小时再次确认「恢复了」。persist 修复**持久有效**，不是一次性重启蒙对；这条把原先"仅用户一次确认"的弱证据升级了。

- 2026-11-07T11:2x 只读审计 90 个文件（子代理）：澎湃4/A17 已撤回结论仍有 25 条残留，分布 6 文件；据此改齐 skill 四处口径 + 版本记录 v1.5–v1.7。
- 2026-11-07T11:2x 新脚本 `tools\a17_single_var_vbmeta.ps1`：把 A17 可复现性矛盾做成只差 8 KB `vbmeta_a` 的单变量实验（prep/off/on/report，dry-run 全过，未跑真机）；`grab_a17_logs.ps1` 补 persist/音频环计数/`btime` 取证段。
- 2026-11-07T11:4x `E:\rom\docs` 4 份历史文档补「更正」节与行内标记（正文原句逐字保留）；过程中 pwsh 内联拼接把 4 行截断，已按抽取到的原文复原并只读复核，教训进 `PowerShell-5.1-三个静默坑` 坑 4。
- 2026-11-07T11:5x 关键提醒写进所有记录层：**10-27 前的 A17 观测全部取自 persist 全零的机器，基线已变，重跑必须重记。**
