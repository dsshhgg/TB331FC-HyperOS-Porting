# STATE — 当前状态（单一事实源，每次动作后更新）

最后更新：2026-11-01 02:30 +08:00

## 设备
- 型号：联想小新 Pad 2024 `TB331FC`（khaje / SM6225-AD / 8+128）
- 引导：unlocked，A/B + 独立 recovery，super 12 GB（`0x300000000`）
- 当前 adb 序列号：`SN-REDACTED-A`（9008 全量刷 544 后序列号由 SN-REDACTED-B 变成这个）
- **当前状态：ZUI16 544（A14 / SDK 34）正常开机，声音与录音已修复（用户确认）。**
  - 2026-11-01 02:22 通过 9008 + fh_loader 单写 `persist.img` 修复（32 MB，`{SUCCESS}`，40.97 MBps）
  - 修复前真机 persist 回读为**整块全零**（`non-zero bytes = 0`），这是声音+录音同时消失的真因
- 上一个**可用**状态：同 ZUI16 544；A17 三件套实验已结束（见「A17 的真实边界」节）

## 关键镜像 / 回滚件
| 用途 | 路径 | 备注 |
|---|---|---|
| 9008 全量刷（544/A14，已验证可用） | `E:\rom\TB331FC\刷机包\TB331FC_ZUI_16.0.544\image\` | rawprogram0..5.xml + super_1..8 + 全部 elf/mbn；工具在同级 `tool\`（QSaharaServer/fh_loader，端口写裸 `COM4`） |
| A15 460 raw 分区 | `E:\rom\work\zui17_images\` | system 5,835,497,472 等；含 vbmeta/vbmeta_system |
| A17 分区镜像 | `E:\rom\work\hyperos_out\` | `hyperos4_a17_product_ext4.img` 2,999,996,416、`hyperos4_a17_system_ext_ext4_v2.img` 1,549,996,032 |
| A17 system（已签名/带 footer） | `E:\rom\work\a17stage\system_A.img` | 1,749,999,616，testkey 签名，只加了 `ro.vendor.api_level=33` |
| A17 system（另加 llndk） | `E:\rom\work\a17stage\system_B.img` | 另加 `ro.llndk.api_level=202404` |
| vbmeta（自签 testkey flags=2） | `E:\rom\work\a17stage\vbmeta_a_tk_flags2.img`(8192) / `vbmeta_system_a_tk_flags2.img`(4096) | **ABL 不放行（已实测）** |
| 原厂 testkey 私钥 | `E:\rom\work\tools\testkey_rsa4096.pem` | pubkey sha1 `2597c218…` = 设备信任的那把 |

## 工具链
- adb/fastboot：`C:\platform-tools\platform-tools\`
- WSL：`Ubuntu24`（`E:\WSL\Ubuntu24`，用户 <WSL 口令已脱敏>，root 可 `-u root`），有 dtc / aarch64-gcc / openssl / python3
- avbtool：`E:\rom\work\tools\avbtool.py`（204,692 B，需 WSL 里的 openssl）
- relay（GitHub API 用）：`E:\rom\work\tools\connect_proxy.py` → 127.0.0.1:8899

## 未决问题
1. **ABL 为何不放行 flags=2 + testkey 签名的 vbmeta**？10-18 那次能起 ~10 秒用的是**原厂 vbmeta**（hash 不匹配也照起）。→ 后续实测已解：ABL 判据是 vbmeta_system 的 hashtree 描述符必须与分区实际内容一致（见下方 10-25 18:26 条）。
2. 若必须保留原厂 vbmeta，则 system/product/system_ext 的 hashtree 校验会失败（尺寸不同）→ 需在**不改 vendor** 的前提下让 system 侧容错。
3. ~~设备当前在 bootloader~~ → 已解决，设备现为 ZUI16 544 正常开机。
4. **本次 persist 已恢复，但写的是通用镜像**：`bluetooth_address` 恢复为非 null，MAC 为镜像内通用值（非本机出厂 MAC）。若要恢复原机 MAC，需从原始备份找回，当前无备份。
5. **是否清 data 未执行**：用户曾要求清 data，但 persist 修复后声音已恢复，清 data 未做。如需清，走 recovery 或 fastbootd。

---

## 2026-11-01 02:30 更新（声音+录音同时消失 → persist 全零，已修复）

- **症状**：声音和录音同时消失；`audioadsprpcd`/`adsprpcd` 25 分钟内重启 57 次；声卡 60 秒内注册/注销翻转 56 次。
- **真因**：9008 下回读真机 `persist`（`/dev/block/sda2`，32 MB）→ **`non-zero bytes = 0 (0.00%)`，整块全零**；刷机包 `persist.img` 有 22,695 个非零字节。
- **为何刷官方包无效**：`rawprogram0.xml` 里 persist 是 `filename=""`，**只定义分区几何、不写内容**，官方刻意不写它。
- **修复**：`fh_loader --port=\\.\COM4 --sendxml=write_persist.xml --zlpawarename=ufs --noprompt --verbose --reset` → `{SUCCESS}`、40.97 MBps，设备自动重启，症状消失（用户确认）。
- **QSaharaServer 不可用**：两试两败（`Unable to read packet header. Only read 0 bytes.`），但设备 `BusReportedDeviceDesc` 已是 `QUSB_BULK_CID:043A_SN:...` → firehose 早已就绪，**fh_loader 可直接连**。
- **本机误判三连**（详录见 skill 7.8.6）：①把 `remote_heap_config.so` 缺失当病因（实测官方 `dspso.bin` 里命中 0 次，是探测性 warning）；②用 `uptime` 判"没刷机"（同版本覆盖刷写不重装预装应用，该判据无效）；③把"persist 未挂载"沿用了 A17 的结论（那次是部分缺失，这次是全零，严重度不同）。
- **留证**：`E:\rom\work\edl\real_persist.img`（修复前回读，全零）、`real_persist_BEFORE.img`、`fh_wp.txt`（写入日志）、`sahara_out*.txt`。

## 2026-10-25 18:26 更新（A17 boot 门 = vbmeta_system 描述符必须与分区一致）
- 实测结论：`vbmeta_a` 换成自签 flags=2 → fastbootd 不进；换回原厂 544 `vbmeta`/`vbmeta_system` → fastbootd 仍不进；直接 reboot → 90 s 恒停在 `18D1:D00D`。
- 因此 **ABL 的唯一判据是「vbmeta_system 里的 hashtree 根摘要 == 设备上 system/product/system_ext 的实际内容」**；把这三块换成 A17 后，任何«描述符对不上»的 vbmeta 都会让 ABL 判定 slot 不可启动，连 recovery/fastbootd 都不放行。
- 对策已做完（纯 system 侧）：给三件套追加 hashtree footer 并生成与之严格对应的 vbmeta 对
  - `E:\rom\work\a17stage\system_tree.img` 1,728,512,000（ext4 缩到 98% 后加树）
  - `product_tree.img` 2,963,148,800、`system_ext_tree.img` 1,530,961,920
  - `vbmeta_system_a_D.img`（三个 hashtree 描述符，testkey 签）、`vbmeta_a_D.img`（544 boot 链四个 hash 描述符 + chain→vbmeta_system[testkey]）
- 当前设备**不可启动且进不了 fastbootd** → 必须先用 9008 全量恢复 544，然后在**同一个 fastbootd 会话**里一次性：删/建分区(1,749,999,616 / 2,999,641,6? 注：product 分区尺寸仍用 2,999,996,416) → 刷三件套 → 刷 vbmeta_a_D/vbmeta_system_a_D → reboot。
- 设备侧待办（需要人）：关机后按住 音量+ / 音量- 再插 USB 进入 9008（`fastboot oem edl` 在 544 上返回 unknown command）。

## 2026-10-25 18:57 更新（**A17 已能起，崩在 900E**）
- 打通 ABL：把 system/product/system_ext 做成**带 hashtree footer** 的镜像（`*_tree.img`），再用这些真实根摘要生成 `vbmeta_system_a_D.img`，配套 `vbmeta_a_D.img`（544 boot 链描述符 + chain→testkey）—— **ABL 放行**，不再卡 bootloader。
- 首次启动现象：5 秒内 USB 变成 `VID_05C6&PID_900E`（Qualcomm HS-USB Diagnostics）→ **A17 system 在 544（A14 / API33）vendor 上确实被拉起，但数秒内崩溃进 900E**；与 2026-10-18 记录一致。
- 设备现状：停在 900E（需人工长按电源复位）。a 槽 = A17 tree 版三件套 + vbmeta_a_D/vbmeta_system_a_D；boot/vendor_boot/dtbo/vendor 仍是原厂 544。
- 下一步取证方案：给 544 `vendor_boot` 开 ramoops console（已有 `vendor_boot_zui16_ramoops.img`），把它的 hash descriptor 也放进 `vbmeta_a`（否则 ABL 又判不可启动）→ 启动 A17 → 崩 → **warm reset** 回原厂系统读 `/sys/fs/pstore/console-ramoops`。

## 2026-10-26 05:53 现状（A17 D1 实验待执行）
- 事实：`E:\rom\work\a17stage` 已就绪 system_D.img / product_D.img / system_ext_D.img（真 hashtree+footer，97% 收缩一次成功），vbmeta_system_E.img（testkey_rsa2048）。
- 事实：`E:\rom\work\tools\flash_a17_d1.ps1` 语法检查通过；脚本只动 a 槽三块逻辑分区 + vbmeta_system_a，vbmeta_a/boot/vendor_boot/dtbo/vendor 全不动。
- 事实：当前 PC 侧无任何设备节点（adb/fastboot/PnP 均空）→ 需平板连 USB 并进 bootloader（电源+音量减）或开 USB 调试后 `adb reboot bootloader`。
- 待验：llndk 202604→33 能否跨过 900E；若仍 900E，下一杠杆是 /system/etc/vintf 兼容矩阵与 selinux mapping。

## 2026-10-27 06:55 当前状态（观测）
- 设备：原厂 ZUI16 544（A14）已通过 9008 全量回刷恢复，USB 以 17EF:7E5F（MTP）稳定枚举；adb/ fastboot 均不可用（USB 调试未开）。
- A17 相关：a 槽三件套已被 544 原厂内容覆盖；E:\rom\work\a17stage\ 保留全部历史镜像（system_A/B/C/D/E/G、product_D/F、system_ext_D、vbmeta_system_A/E/F/G2/H/I、vbmeta_a_C/D、带 hashtree 的 *_D）。
- 历史可用组合（15:xx 实测开过机）：system_G + product_D(2,999,996,416) + system_ext_D + vbmeta_system_H（vbmeta_a 原厂 544 不动）。
- 已知失败：product_F（3,600,003,072，含 GCam 552 MB + Via + ro.build.type=userdebug）+ vbmeta_system_I → 不能开机。
## 设备现状（2026-10-27 18:24 更新）
- 系统：原厂 ZUI16 544（Android 14 / SDK 34），MTP 可见，adb 需手动打开 USB 调试；序列号 SN-REDACTED-A。
- 分区：a 槽已由 9008 全量恢复为 544 原厂（super 内逻辑分区回到原厂 5.49/0.59/0.46 GB 布局），vbmeta_a 原厂，vbmeta_system_a 原厂。
- A17 资产（未删除）：E:\rom\work\a17stage\ 的 system_G/product_D/system_ext_D、vbmeta_system_H、vbmeta_a_D、vbmeta_system_J 等；A17 关键结论 = 干净内容 + H + 任一 vbmeta_a 均 900E（约 20 s）。
- 未决：900E 的崩溃层级未证明；建议下一步给 544 vendor_boot 开 ramoops console 取证（需能读 pstore 的 root 通道）。

## 设备现状（2026-10-27 18:40 更新）
- 系统：原厂 ZUI16 544（A14 / SDK 34）已启动，MTP `17EF:7E5F` 可见；adb 空（USB 调试默认关）。这是靠 18:23 的 9008 全量回刷恢复的（rawprogram0..5 + patch0..5 全 OK，日志 `E:\rom\work\logs\edl_restore_20261027.log`）。
- 分区：a 槽全部回到 544 原厂（含 vbmeta_a / vbmeta_system_a 原厂）；super 空闲约 4.5 GB（原厂布局 5.49/0.59/0.46 GB）。
- A17 资产未删：`E:\rom\work\a17stage\` 的 system_A~G、product_D/F、system_ext_D、vbmeta_a_C/D、vbmeta_system_E/F/G2/H/I/J/min/flags2。

## 关键结论（2026-10-27 18:40，avbtool 实测）
- 10-26 能开机的真实机制 = **vbmeta 链密钥对不上**：`vbmeta_a_D.img` 的 chain 描述符指向 vbmeta_system 公钥 sha1 `2597c218…`（rsa4096），而实际 `vbmeta_system_H.img` 是 rsa2048 签名、公钥 `cdbb7717…` → ABL 链式校验不成立 → 系统分区不启用 dm-verity → A17 起到桌面（有 getprop 证据 release=17/sdk=37/29 sensors）。
- 反之：原厂 544 `vbmeta_a` 的 chain 指向 `cdbb7717…`（与 H 匹配）→ verity 生效 → A17 约 20 s 崩进 900E。
- 单一可开机组合：`vbmeta_a = vbmeta_a_D.img` + `vbmeta_system_a = vbmeta_system_H.img` + `system_G` + `product_D` + `system_ext_D` + 原厂 boot/vendor_boot/dtbo/init_boot/vendor。
- ABL 硬规则（三组实验）：`vbmeta_system` 必须 **flags=0 且带 hashtree 描述符**；flags=2 或缺描述符 → 直接停 bootloader 不启动。`vbmeta_a` 若描述符写错，会让 fastbootd 与 recovery 一起不可用（用原厂 vbmeta_a 可恢复）。
- 待验证（唯一矛盾点）：10-27 18:11「干净三块 + H + vbmeta_a_D」也 900E —— 需在干净状态重做一次该单变量，才能确认链密钥机制是否完整解释。

## 更正（2026-10-31 23:4x，从三个会话档案复核后写下）

- ❌ **撤回**「A17 / 澎湃 4.0 → 启动即中止 → 结构性不可行」。已安装 skill 与知识库里的这条说法解释不了下面的设备回显。
- 观测事实（档案 `7366fc24` 的 tool/result 原文，非转述）：
  - `release=17`、`sdk=37`、`boot_completed=1`（seq 7322）
  - `Total 29 h/w sensors, 29 running`，含 `bmi3x0 Accelerometer / Gyroscope` BOSCH ver 306（seq 7343）
  - 指纹 `Lenovo/miproduct_yupei/TB331FC:17/CP2A.260605.016/OS4.0.5.0.XPZCNXM:user/release-keys`（seq 7380）
  - `package:mark.via`、`package:com.android.MGC_8_8_224`（Via + GCam 已装，seq 7580）
- 观测事实（avbtool 2026-10-31 独立重跑）：`vbmeta_a_D` 公钥 sha1 `2597c218…`(RSA4096)，其 chain→vbmeta_system 亦为 `2597c218…`；`vbmeta_system_H` 实为 `cdbb7717…`(RSA2048) → 不匹配。
- 措辞更正：上面「单一可开机组合」应为「**已观测到起到过桌面的组合之一**」（`ro.llndk.api_level` 与 init 的 `Unexpected vendor api level for` 只证明记录了代差，不证明中止启动）。
- 当前判断（推断，带反证条件）：链密钥不匹配 → verity 不启用 → A17 能起；若干净状态只换 `vbmeta_a` 而不"一进一崩"，此推断错。
- 未闭合：10-27 18:11 同一组合仍 20 s 900E（当时 `system_ext_a` 刚被 Resizing、`--set-active` 报 `Unable to set slot`）。

## 挂起的功能诉求（用户还没放弃）
1. 预装 Google 相机（GCam）+ Via 浏览器，保留小米全家桶（m02815）
2. DPI/字体（当前 300 + font_scale 1.05，用户嫌小）、分辨率是否降（m02811）
3. 设置默认打开 WiFi 页、小米互联不完整（m02811）
4. GPIO 逆向报告（m02206/m02811，已有 v2 版 `docs/gpio-reverse-2026-10-25.md`）
5. 重打包刷机包（m02819）
6. Frida/root 窗口层级工具链已就绪（`E:\rom\work\a17toolkit\`），待 A17 再开机后实测（m03168）

## 2026-11-07 更新（澎湃4：记录一致性收尾 + 判定实验就绪）

- 观测事实：全量复查 90 个文件（两份 skill、45+10 份记忆、work\docs 11、E:\rom\docs 20），
  发现 25 条仍把已撤回结论当现行口径的残留，分布在 6 个文件。skill 侧 4 条已就地改齐
  （knowledge-base 0.1 / 5.6 / 9.7 第3条 + rom-porting 设备硬约束段），版本记录补 v1.5–v1.7。
- 观测事实：`E:\rom\docs` 4 份历史文档（澎湃4可行性结论 / 会话复盘a1c5aa16 / 实验记录notz双补丁 /
  实验记录三镜像干净刷入）正文此前**无任何撤回标注**。现每份文末追加「更正（2026-11-07）」节 +
  关键行就地加标记，正文原句逐字保留（已用脚本断言 verbatim，行号不偏移）。
- 新增脚本 `E:\rom\work\tools\a17_single_var_vbmeta.ps1`（296 行，0 parse error，0 非 ASCII 字节，
  prep/off/on/report 四模式全部 dry-run 通过）。它把 6.1.1 那个矛盾变成一次只差 8 KB 的单变量实验：
  内容完全不变，只换 `vbmeta_a`（原厂 544 ↔ `vbmeta_a_D`），预期一进一崩；读数 = `ro.boot.veritymode`
  与 USB 类别（`05C6:900E` / `18D1:D00D` / `17EF:`）。**尚未跑真机**，设备今天未连接。
- `grab_a17_logs.ps1` 补了第 8 节：persist 挂载 / `bluetooth_address` / sensors registry /
  adsp 与声卡环计数 / `btime`+`bootreason`+setupwizard 痕迹。279 行，0 非 ASCII。
- ⚠️ **基线已变（本条最重要）**：10-27 之前所有 A17 观测都取自 persist **整块全零** 的机器。
  11-01 写回 persist 后 ACDB 与传感器标定才真正可用，旧数字与新一次实验**不可比**，重跑必须重记。
- 事故记录（不改历史这条规矩我被自己绊了）：批量插入标记时用 pwsh 内联数组做多段中文拼接，
  4 行正文被截成只剩标记（澎湃4可行性结论 L6/L424、会话复盘 L84/L102），**原句一度丢失**。
  已用 `_repair_doc_annotation.py` 按事先抓取的原文逐字复原并验证；详见 OPLOG 同日条目与
  记忆 `PowerShell-5.1-三个静默坑` 新增的坑 4。
- 未决：设备未连（`adb devices` 空、无 fastboot 节点）。澎湃4 线推进需要的全部东西都在盘上就绪，
  缺的只是把平板接上跑 `-Variant prep` → `off` → `on`。
