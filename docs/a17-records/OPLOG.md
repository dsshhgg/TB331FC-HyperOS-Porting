# OPLOG — 全量操作记录（逐动作留痕）

> 用户指令（m03662，2026-10-29）：「把所有的操作记录，修改了哪个文件、哪个代码、调用了哪个工具、运行什么指令，都记在记忆文件」。
> 本文件是**执行明细**；`ACTION-LOG.md` 是结论级摘要；`STATE.md` 是当前状态；记忆文件是跨会话知识。
> 规矩：一条动作一条记录，**append-only**，不覆盖历史；命令写全（可复制复跑）；时间不确定的标 `~`。

## 记录格式

```
### YYYY-MM-DDTHH:MM+08 | 一句话动作
- 工具: 工具名 + 绝对路径
- 命令: 实际执行的命令行（可复现，路径写全）
- 改动: 被写的文件 / 设备分区 / 注册表项（写明前后差异）
- 产出: 新建或修改的文件（含大小、sha256 摘要时写上）
- 结果: 观测输出关键行（错误原文照抄）
- 备注: 推断 / 待验证 / 回滚方式
```

---

## 2026-10-29（本记录制度启用）

### 2026-10-29T12:20+08 | 建立操作留痕制度
- 工具: `write` / `pwsh` / `edit`
- 命令: 无（文档创建）
- 改动: 新建 `E:\rom\work\docs\OPLOG.md`（本文件）；更新 `E:\rom\work\docs\ACTION-PROTOCOL.md` 第 4 步（追加"同时写 OPLOG"）；新建记忆 `记忆：全量操作记录-文件级留痕`
- 产出: OPLOG.md（含 2026-10-24 起的关键动作回溯补记）
- 结果: OK
- 备注: 回溯条目时间标 `~`；从本条起每个动作都新增一条

---

## 2026-10-24（设备树 + 环境起步，回溯补记）

### ~2026-10-24T12:13+08 | 建 A14 设备树仓库并推送
- 工具: `git`（`C:\Program Files\Git\cmd\git.exe`）、`E:\rom\work\tools\connect_proxy.py`、`gh_api.ps1`
- 命令: `POST /user/repos`（api.github.com 经 relay 8899）→ `dsshhgg/android_device_lenovo_TB331FC`；`git -c http.proxy=http://127.0.0.1:8899 push -u origin main`
- 改动: 远端新仓库 main 分支（67 文件 / 70.1 MiB，commit `69d3f3e2`）
- 产出: `E:\rom\work\devtree\`（BoardConfig.mk、device.mk、lineage_TB331FC.mk、AndroidProducts.mk、rootdir/、prebuilts/、vendor blob 清单等）
- 结果: `* [new branch] main -> main`；API 校验 HEAD `69d3f3e2`
- 备注: 推送卡点是 Steam++ 把 github.com 钉 127.0.0.1；用自写 CONNECT 中继绕过

### ~2026-10-24T17:23+08 | 导入 WSL 构建环境
- 工具: `wsl.exe`
- 命令: `wsl --import UbuntuTB E:\rom\release\tmp\wsl\UbuntuTB <noble-root.tar.xz> --version 2`
- 改动: 新 distro `UbuntuTB`
- 结果: Ubuntu 24.04.5、8 CPU、7.9 GB、`/` 1007G
- 备注: 原 `Ubuntu` distro 的 ext4.vhdx 已丢失（死条目）

### ~2026-10-24T18:0x+08 | 刷主线 Linux（B 槽）成功
- 工具: `fastboot.exe`
- 命令: `fastboot --set-active=b` → `flash boot_b boot_b-2026-10-24.img` → `flash vendor_boot_b …` → `flash dtbo_b dtbo_minimal.img` → `flash init_boot_b init_boot_empty.img` → `flash vbmeta_b vbmeta_stock.img` → `reboot`
- 改动: B 槽 boot/vendor_boot/dtbo/init_boot/vbmeta
- 产出: `E:\rom\work\linuximg\dtbo_minimal.img` 282,624 B、`init_boot_empty.img` 8,192 B
- 结果: 起 Linux 6.14.0-rc5-next，串口 COM7 出 root shell
- 备注: `E:\rom\work\tools\mkdtbo_min.py`、`dtb/mkv4.py`

### ~2026-10-24T21:30+08 | 解包 ZUI17 460 并抽出 vendor blob 树
- 工具: WSL `losetup`/`rsync`、`E:\rom\work\tools\extract_blobs.sh`
- 命令: `wsl -d UbuntuTB -u root bash /mnt/e/rom/work/tools/extract_blobs.sh`
- 改动: 无（只读挂载）
- 产出: `E:\rom\work\vendor\lenovo\TB331FC\proprietary\`（798 MB / 3048 文件）
- 结果: vendor 2790 文件 741 MB、vendor_dlkm 229/57 MB、odm 10/1.3 MB

---

## 2026-10-25（A17 首次刷入 + vbmeta 规则 + GPIO 报告）

### ~2026-10-25T17:59+08 | 刷 vbmeta_C 对（flags=2）
- 工具: `fastboot.exe`
- 命令: `flash vbmeta_a vbmeta_a_C.img` → `flash vbmeta_system_a vbmeta_system_a_C.img` → `reboot fastboot`
- 改动: vbmeta_a、vbmeta_system_a
- 结果: `Failed to boot into userspace fastboot; one or more components might be unbootable.`（60 s 内 `is-userspace: no`）
- 备注: 回滚 = 刷原厂 544 `vbmeta.img` / `vbmeta_system.img`

### ~2026-10-25T18:29+08 | 9008 全量回刷 544（第 1 次）
- 工具: `QSaharaServer.exe`、`fh_loader.exe`（`E:\rom\TB331FC\刷机包\TB331FC_ZUI_16.0.544\tool\`）
- 命令: `QSaharaServer -p COM4 -s 13:prog_firehose_sm6225_ddr.elf`；`fh_loader --port COM4 --memoryname=ufs --lun=N --sendxml=rawprogramN.xml --search_path=… --mainoutputdir=… --noprompt --showpercentagecomplete --zlpawarehost=1`（N=0..5）；`patchN.xml` 同上；`--reset`
- 改动: 全部分区回到 544 原厂
- 结果: `All Finished Successfully` ×6 + ×6；reset 后进 recovery/fastbootd

### ~2026-10-25T18:52+08 | 三块 hashtree 版 + vbmeta_D 刷入 → 900E
- 工具: `fastboot.exe`
- 命令: `delete-logical-partition system_a/product_a/system_ext_a` → `create-logical-partition system_a 1749999616 / product_a 2999996416 / system_ext_a 1549996032` → `flash system_a system_tree.img` → `flash product_a product_tree.img` → `flash system_ext_a system_ext_tree.img` → `flash vbmeta_a vbmeta_a_D.img` → `flash vbmeta_system_a vbmeta_system_a_D.img` → `reboot`
- 改动: a 槽三块逻辑分区 + 两个 vbmeta
- 结果: 5 s 后 USB = `VID_05C6&PID_900E`（Qualcomm HS-USB Diagnostics）
- 备注: 首次证明「ABL 放行后崩在系统阶段」

### ~2026-10-25T20:4x+08 | 写 GPIO 反解报告（v1）
- 工具: `E:\rom\work\tools\extract_dt.py`、WSL `dtc`、`gpio_report.py`
- 命令: `python extract_dt.py <vendor_boot.img>`；`dtc -I dtb -O dts`；`python gpio_report.py`
- 产出: `E:\rom\work\dtwork\{vb460,vbdev,dtbo460}\`、`E:\rom\work\docs\gpio-reverse-2026-10-25.md`
- 结果: 触控 irq 80 / reset 86、屏 reset 82、TE 81、背光 27、BT 87 等

### ~2026-10-25T22:40+08 | 固化"证据优先"规矩
- 工具: `write`
- 改动: 新建 `记忆：证据优先-事实与推断必须分开`（priority 99）；更新 `user-requirements.md` F 节、`ACTION-PROTOCOL.md`
- 结果: OK

---

## 2026-10-26（传感器修复 + 首次真正进桌面）

### ~2026-10-26T05:53+08 | 重做带真 footer 的三件套（build_hashtree2）
- 工具: WSL bash、`avbtool.py`
- 命令: `wsl -d Ubuntu24 -u root bash /mnt/e/rom/work/tools/build_hashtree2.sh`
- 产出: `system_D.img` 1,749,999,616（digest `490ccf7d…`）、`product_D.img` 2,999,996,416（`832596f2…`）、`system_ext_D.img` 1,549,996,032（`83f7fa74…`）、`vbmeta_system_E.img` 4,096
- 结果: 97% 收缩一次成功，`avbtool info_image` 正常
- 备注: 旧脚本用 `--do_not_append_vbmeta_image` 导致 footer 落空（已修正）

### ~2026-10-26T12:36+08 | 刷 D1 组合（system_D/product_D/system_ext_D + vbmeta_system_H）
- 工具: `E:\rom\work\tools\flash_a17_d1.ps1`（内联调用 `fastboot.exe`）
- 命令: 删/建三块 → `flash system_a system_D.img`(55 s) → `flash product_a product_D.img`(92 s) → `flash system_ext_a system_ext_D.img`(40 s) → `flash vbmeta_system_a vbmeta_system_H.img` → `reboot`
- 结果: +35 s 出 adb `SN-REDACTED-A device`，日志证明 A17 起来（`release=17`/`sdk=37`）
- 备注: 随后 `adb shell` 打死 adbd（`shell_service.cpp:380`）

### ~2026-10-26T13:24+08 | 抓到 system_server 崩溃堆栈
- 工具: `adb.exe`、`capture_lc.ps1`
- 命令: `adb logcat -d -b all > dump_028.txt`
- 产出: `E:\rom\work\logs\lc_071201\dump_028.txt`（1.19 MB / 8814 行）
- 结果: `Invalid @IntRange(to = 178): 201` @ `AppOpsManagerStubImpl.validateMiuiOp:37` ← `AppOpsService.writeRecentAccesses:5896`
- 备注: 推断与遗留 /data 有关；`erase userdata`+`metadata` 后不再崩

### ~2026-10-26T17:0x+08 | 构建并刷 system_E（debug 版）
- 工具: `E:\rom\work\tools\build_system_E.sh`、`fastboot.exe`
- 命令: 改 `/system/build.prop`（userdebug/secure=0/adb.secure=0/debuggable=1）+ 加 `/system/etc/init/mount_persist.rc` → `flash system_a system_E.img`(65 s) + `flash vbmeta_system_a vbmeta_system_F.img`
- 产出: `system_E.img` sha256 `8b1d5d3e…`
- 结果: 能到锁屏，但 `ro.build.type` 仍 user（被 /product 覆盖）、`adb root` 无效
- 备注: mount_persist.rc 因无 SELinux xattr 被 init 跳过

### ~2026-10-26T17:3x+08 | USB 枚举事故与恢复
- 工具: `pnputil`、`reg`
- 命令: 写 `HKLM\SYSTEM\CurrentControlSet\Enum\USB\VID_17EF&PID_7E60\…\Device Parameters\DeviceInterfaceGUIDs`；`pnputil /restart-device`；`pnputil /remove-device`
- 改动: 注册表 DeviceInterfaceGUIDs；设备驱动节点
- 结果: remove-device 把 ADB 接口删掉 → 用户拔插 USB 后恢复 `17EF:7E6B`
- 备注: **别再对 D001/7E60 节点做 remove-device**，只在必要时 `restart-device`

### ~2026-10-26T18:0x+08 | system_F（init.rc 加 mount_all）→ 黑屏 5 分钟
- 工具: `build_system_F.sh`、`fastboot.exe`
- 命令: 在 `/system/etc/init/hw/init.rc` 追加 `on post-fs-data` + `mount_all /vendor/etc/fstab.default --early` → `flash system_a system_F.img`(43 s) + `vbmeta_system_G2.img`
- 结果: 60 s 内零 USB 枚举；约 5 分钟后自行起来（persist 的 `wait` 拖慢 init）
- 备注: 教训 = 黑屏先等 10 分钟再判死

### ~2026-10-26T18:32+08 | system_G（只 mkdir 不挂载）→ 传感器复活
- 工具: `build_system_G.sh`、`fastboot.exe`
- 命令: `flash system_a system_G.img`(42 s) + `flash vbmeta_system_a vbmeta_system_H.img` → `reboot`
- 产出: `system_G.img` digest `cc180c18…`
- 结果: `dumpsys sensorservice` = `Total 29 h/w sensors, 29 running`；用户确认「转屏恢复了」「相机能」
- 备注: persist 仍未挂载，registry 落在 tmpfs，重启由 sscrpcd 重建

---

## 2026-10-27（product_F 失败 → 工具链 → 链密钥机制）

### ~2026-10-27T07:0x+08 | 搭 Frida/root 工具链
- 工具: `pip`、`curl`（gh-proxy）、python `lzma`
- 命令: `pip install -i https://pypi.tuna.tsinghua.edu.cn/simple frida frida-tools androguard`；下载 `frida-server-17.24.3-android-arm64.xz` 24,624,060 B 并解压
- 产出: `E:\rom\work\a17toolkit\`（bin/adb.exe、fastboot.exe、frida-server 84,715,688 B、jadx 1.5.1、apktool 2.11.1；scripts/{push_frida.ps1,wm_dump.ps1,wm_hook.js,systemui_hook.js}；docs/README.md）
- 结果: adb 37.0.1、frida 17.24.3、jadx/apktool 版本实测通过
- 备注: 需 root 才能 push frida-server；userdebug/KSU 才行

### ~2026-10-27T12:15+08 | 抓窗口/图层基线（544）
- 工具: `E:\rom\work\a17toolkit\scripts\wm_dump.ps1`
- 命令: `powershell -NoProfile -ExecutionPolicy Bypass -File wm_dump.ps1 -Serial SN-REDACTED-A`
- 产出: `E:\rom\work\logs\wm\20261027-121509\`（window-windows 58,263 B、sf-list 4,218 B 等）
- 结果: 118 层、`StatusBar#122`、`NotificationShade#120`、1200×1920 @240dpi

### ~2026-10-27T12:5x+08 | 构建 product_F（GCam+Via+userdebug）→ 刷入后开不了机
- 工具: `build_product_F.sh`、`build_vbmeta_I.sh`、`fastboot.exe`
- 命令: `resize2fs prod.img 864000` → `truncate -s 3538944000` → 改 `/etc/build.prop` + 放 `/product/app/{GCam,Via}` + `setfattr` 打标 → `add_hashtree_footer --partition_size 3600003072` → `create-logical-partition product_a 3600003072` → `flash product_a product_F.img`(89 s) + `vbmeta_system_I.img`
- 产出: `product_F.img` 3,600,003,072 B（digest `e7105b1b…`）
- 结果: 240 s 无 adb → 落 recovery；fastbootd 起不来
- 备注: 原因未定（PM 扫 552 MB APK 崩 / hashtree 尺寸不匹配）

### ~2026-10-27T13:0x+08 | 回滚到已知组合（product_D + vbmeta_system_H）→ 仍 900E
- 工具: `fastboot.exe`
- 命令: `delete-logical-partition product_a` → `create-logical-partition product_a 2999996416` → `flash product_a product_D.img`(82 s) → `flash vbmeta_system_a vbmeta_system_H.img` → `reboot`
- 结果: 300 s 无 adb，持续 900E（23:29–23:35 采样 36 次）
- 备注: 与 10-26 成功矛盾 → 说明还有别的变量

### ~2026-10-27T18:23+08 | 9008 全量回刷 544（第 3 次）→ 恢复可开机
- 工具: `QSaharaServer.exe` / `fh_loader.exe`
- 命令: 同前（COM5），日志 `E:\rom\work\logs\edl_restore_20261027.log`
- 结果: 18:23:36 MTP 枚举 → 18:23:45「小新Pad 2024」→ 544 已启动
- 备注: workdir 用 `../image` 相对路径避开中文路径

### ~2026-10-27T18:30+08 | 查清链密钥机制 + 写记忆
- 工具: `avbtool.py`（WSL）、`write`
- 命令: `avbtool info_image --image vbmeta_a_D.img` / `vbmeta_system_H.img`；`avbtool extract_public_key`
- 产出: `记忆：A17-TB331FC-唯一可开机配置`；`ACTION-LOG.md` +1 条；`STATE.md` 两个新章节
- 结果: `vbmeta_a_D` chain → `2597c218…`(rsa4096)，`vbmeta_system_H` 公钥 `cdbb7717…`(rsa2048) → 不匹配 → verity 不启用 → 能开机
- 备注: 未闭合 = 10-27 18:11 同样配置也 900E

---

## 待办（下一步动作要写在这里）

- [ ] 干净状态单变量复验：只换 `vbmeta_a_D`，看是否恢复可开机（需用户批准写分区）
- [ ] 若可开机 → 用 ramoops 版 vendor_boot 抓 900E 前内核日志（`vendor_boot_zui16_ramoops.img`）
- [ ] 挂起功能：GCam + Via 预装、DPI/字体、设置默认 WiFi 页、小米互联、GPIO 报告定稿、重打包刷机包

### 2026-10-29T12:26+08 | 把留痕制度写进协议与记忆
- 工具: `write` / `edit`
- 命令: 无（文档编辑）
- 改动: `E:\rom\work\docs\ACTION-PROTOCOL.md` 第 4 步拆成 4a（OPLOG 明细）+ 4b（ACTION-LOG 摘要）；新建记忆 `记忆：全量操作记录-文件级留痕`（priority 97）
- 产出: 上述两文件
- 结果: OK
- 备注: 从本条起，之后每个动作都按同一格式继续追加
### 2026-10-31T23:4x+08 | 复原三个会话档案 + 修正"A17 结构性不可行"这条错误结论
- 工具: `Expand-Archive`、`python`（`E:\rom\session_dump\digest.py`）、`wsl -d Ubuntu24 -u root` + `E:\rom\work\tools\avbtool.py`、`write` / `edit` / `Move-Item`
- 命令:
  - `Expand-Archive -Path E:\rom\dsh-session-session-7366fc24-9d7a-42e2-9e1e-ae794d50b2fc.zip -DestinationPath E:\rom\session_dump\dsh-session-session-7366fc24-...`
  - `python E:\rom\session_dump\digest.py <session.v4.jsonl> E:\rom\session_dump\out_7366`
  - `wsl -d Ubuntu24 -u root -e bash -c "cd /mnt/e/rom/work/a17stage && python3 /mnt/e/rom/work/tools/avbtool.py info_image --image vbmeta_a_D.img"`
  - 同上 `vbmeta_system_H.img`
- 改动:
  - 新建记忆 `记忆：A17-TB331FC-可开机配置与900E分界`（5,383 B，priority 95）
  - 旧记忆 `A17-TB331FC-唯一可开机配置.memory.md` → 改名 `.memory.md.disable`（停用，不删）
  - `C:\Users\Administrator\.dsh\skills\tb331fc-flash-porting\SKILL.md`（12,999 → 15,341 B）改 4 处
  - `...\references\knowledge-base.md`（69,986 → 71,381 B）改 4 处含新增 6.1.1
- 产出: 上述文件；`E:\rom\session_dump\_boot_evid.txt`、`_a17evid.txt`、`_a17run.txt`、`_tail7366b.txt`（提取中间件）
- 结果:
  - 独立复核 avbtool：`vbmeta_a_D` 公钥 sha1 `2597c218aae470a130f61162feaae70afd97f011` / SHA256_RSA4096 / chain→vbmeta_system 也是 `2597c218…`；`vbmeta_system_H` 为 `cdbb77177f731920bbe0a0f94f84d9038ae0617d` / SHA256_RSA2048 → 确认不匹配
  - 设备回显确认 A17 起到桌面：`release=17`、`boot_completed=1`（档案 7366 seq 7322）、`Total 29 h/w sensors, 29 running`（seq 7343）、`package:mark.via` + `package:com.android.MGC_8_8_224`（seq 7580）、指纹 `...TB331FC:17/CP2A.260605.016/OS4.0.5.0.XPZCNXM`
  - 上一会话（7366）末轮死因：`Context length exceeded (code=4026)`，重试 5 次全失败；磁盘清理 A/B/C/D/E 实际已完成（`ext4.vhdx` 50.36 → 4.55 GB，E 盘空闲 27 → 55.5 GB）
- 备注:
  - **推断**（附反证条件）：链密钥不匹配 → verity 不启用 → A17 能起。若干净状态只换 `vbmeta_a` 而不随之"一进一崩"，此推断错
  - **未知**：2026-10-27 同一组合仍 900E 的原因（当时 Resizing / set-active 报错）；定论需一次干净状态单变量复验
  - 回滚：skill 改动可 `git` 无关，需回退就从本条描述的 4 处文本还原；记忆旧文件仍在 `.disable` 后缀下
### ~2026-11-01T00:25+08 | 修正两个刷机/抓日志脚本的已知 bug（设备仍未接入）

- 命令: 无设备操作；只做静态检查 + `A17_DRYRUN=1 A17_NO_GRAB=1` 试运行 + 隔离单测
- 结果:
  - `flash_a17_working.ps1` 试运行前后两次对比：修前卡 DRY 分支空等 180 s 后 `ABORT: fastbootd unreachable`（exit 1）；修后 0 s 走完全流程（exit 11）
  - 实测确认 bug：①`L 'x[' + 'y' + ']'` 只打印 `x[`，**后续内容被静默丢弃**（PS 把 `+` 当位置参数，函数只收第一个）；②PnP `InstanceId` 分段结构实测为 `[0]=USB [1]=VID_xxxx&PID_yyyy [2]=端口号`，旧代码取 `[2]` 永远拿不到 vid:pid
  - 修复清单（`flash_a17_working.ps1` 11 处）：DRY 分支跳过等待/探测；`L()` 由 `Tee-Object -Append`（写 UTF-16LE，实测首字节 `5B 30 30 3A` 已是 UTF-8，但原写法会产生 UTF-16）改为 `[System.IO.File]::AppendAllText` + UTF8NoBOM；`L` 裸字符串 `+` 拼接补括号；`--set-active=a` 从末尾**提前到 `vbmeta_a_D` 写入之前**并加失败中止（exit 6）+`set_active` 回退；flush 失败改为中止（exit 5）；`getvar partition-size` 解析 `0x..` 十六进制并比对期望值；等待超时不再无条件报成功；`UsbIds` 改为锚定 `^USB\` + `VID_/PID_` 锚定 + 输出 `05C6:900E` 格式
  - 修复清单（`grab_a17_logs.ps1` 8 处）：所有抓取改走 `Save`/`WriteAllText` UTF8NoBOM（原来 `>` 重定向是 UTF-16LE）；adb 等待循环见到 900E/9008 立即退出（原来白等满 900 s）；pstore 为空时给出 kernel 支持可能未开的提示；`su -c dmesg` / `cat /dev/kmsg` 加引号；markers 改为 grep 本地已抓文件而非在设备上重跑 `logcat -b all`（避免与刚启动的缓冲区竞争）；新增 `logcat -b events`、`packages.txt`、`sys.boot_completed` 判定并以 exit 7 区分"抓到但没起完"
  - `make_vboot_ramoops.py`: 硬编码 `-d UbuntuTB` 改为自动探测（`WSL_DISTRO` 可覆盖），探测失败给出可读报错。**实测发现**：`wsl -l -q` 输出为 UTF-16LE，Python `text=True` 按 cp936 解码会得到 `U\x00b\x00u\x00...`，所以探测必须自己解码字节——已按此实现
- 备注:
  - 观测：本机 dtc 在 `Ubuntu24`(1.7.0) 与 `UbuntuTB` 都有，`Ubuntu` 也在列；探测实测选中 `Ubuntu24`
  - 观测：两个 PS 脚本均为 0 parse errors、纯 ASCII（本轮新脚本沿用该约束）
  - 仍未闭合的事项不变：2026-10-27 18:11 同组合仍 900E 的原因，需干净状态单变量只换 `vbmeta_a` 复验；该复验按用户指示排在"先装可用组合"之后
  - 回滚：两脚本为本轮整文件重写，旧版本仅存在于本 OPLOG 描述中；如需回退按上述清单逆向还原
  - 设备状态：`adb devices` / `fastboot devices` 均空，PnP 无 `05C6/18D1/17EF/19D2`，仅 `COM1`（非 EDL 口）→ 无法执行真机验证，以上均为静态 + 试运行级验证

### 2026-11-01T02:30+08 | 修好 TB331FC 声音+录音同时消失（persist 全零）

- 症状起点: 用户报「平板声音和录音都没了」。设备 ZUI16 544，adb 在线 `SN-REDACTED-A`。
- 观测（修复前）:
  - `audioadsprpcd` / `adsprpcd` 25 分钟内重启 **57 次**（`adsp daemon will restart after 25ms`）
  - 声卡 60 秒内注册/注销翻转 **56 次**（`sound card status changed 1` ↔ `0`）
  - AudioFlinger `underruns=197 overruns=5`；音频策略配置**正常**（`Built-In Mic` / `Built-In Back Mic` / `speaker` 都在）
  - `persist` **未挂载**（`/proc/mounts` 89 条无 persist）；`settings get global bluetooth_address` = **null**，BT MAC 随机 `MAC-REDACTED`
  - `sscrpcd` 反复报 `/mnt/vendor/persist/sensors/registry/registry` ENOENT
- 诊断过程（含三次误判，详录见 skill 7.8.6）:
  1. 先把 `remote_heap_config.so` 缺失当病因 → 离线扫官方 `dspso.bin`（32 MB）得 `remote_heap_config hits=0`（`apps_std` 229 次、ELF 60 个）→ **官方根本没这文件，是探测性 warning，推断作废**
  2. 用 `uptime` 反推开机时刻判「用户没刷机」→ 错。`btime`=01:32:33 正是刷完后的首启；`uptime` 只能证明区间内没重启
  3. 沿用 A17 档案里「persist 未挂载但音频正常」的结论 → 错。那次是部分缺失，这次是整块全零，严重度不同
- 决定性证据（9008 回读 + 比对）:
  ```
  real  non-zero bytes = 0 (0.00%)      ← 真机 persist 32 MB 整块全零
  stock non-zero bytes = 22695 (0.07%)  ← 刷机包 persist.img
  differing byte positions = 22695
  ```
- 命令（工具链）:
  - 工作目录 `E:\rom\work\edl\`（纯 ASCII，规避中文路径）
  - **QSaharaServer 两试两败**：`-p COM4` 与 `\\.\COM4` 均 `Unable to read packet header. Only read 0 bytes.`；但设备 `BusReportedDeviceDesc = QUSB_BULK_CID:043A_SN:86C1CC00` → firehose 已就绪
  - 回读: `fh_loader.exe --port=\\.\COM4 --sendxml=read_persist.xml --zlpawarehost=1 --memoryname=ufs --noprompt --verbose` → exit 0、`All Finished Successfully`
  - 写入: `fh_loader.exe --port=\\.\COM4 --sendxml=write_persist.xml --zlpawarehost=1 --memoryname=ufs --noprompt --verbose --reset` → `{SUCCESS}`、`Overall to target 0.781 seconds (40.97 MBps)`、自动 `Sending <power>`
  - 参数坑：`fh_loader` **没有 `--readxml`**（读也用 `--sendxml`，XML 里 `<read>`）；端口必须 `\\.\COM4`；必须 `--memoryname=ufs`
- 结果:
  - 写后 COM4 消失，约 20 秒出现 `VID_17EF&PID_7E60`，用户确认**声音和录音恢复**
  - persist 镜像 SHA256 `C98F42604397A1A71565FD27E0AE8CD44071368BDEDD6203381BE36391E50304`（33,554,432 B）
- 备注:
  - **推断**（附反证条件）：全零 persist → 挂载失败 → ACDB 音频校准 + 传感器注册表 + 真 MAC 全丢 → 音频 HAL 拿不到校准反复重连 DSP → 死循环。若某天 persist 正常挂载但音频仍坏，此推断错
  - **未闭合**：写入的是**通用** persist 镜像，MAC 为镜像内通用值，非本机出厂 MAC；原机 persist 已全零，无原始备份可恢复
  - **未执行**：用户提出「把 data 分区清了」，persist 修复后声音已恢复，故未清 data
  - 留证：`real_persist.img`（修复前，全零）、`real_persist_BEFORE.img`、`fh_wp.txt`、`sahara_out.txt`、`sahara_out2.txt`
  - 回滚：persist 可重刷任意版本 persist.img；本次无风险动作

## 2026-11-07T11:0x–11:5x +08:00 · 澎湃4 记录一致性收尾 + 判定实验就绪（含一次自我破坏与复原）

设备状态：未连接。`C:\platform-tools\platform-tools\adb.exe devices -l` 输出仅表头；
`Get-PnpDevice` 无 `VID_17EF/05C6/18D1` 节点。本轮全部为 PC 侧记录与工具工作，未对设备下发任何命令。

### 1. 先翻（不凭记忆动手）

- `read` STATE.md(114 行) / rom-porting SKILL.md / tb331fc SKILL.md(307 行) /
  A17 记忆(66 行) / knowledge-base 相关段（0.1–0.4、5.6、6.1–6.2、9.7、版本记录）。
- 事实收集命令：`Get-ChildItem` 记忆目录按 mtime 排序；`Select-String` 统计 skill 中
  A17/澎湃/HyperOS 命中（knowledge-base 31 处、SKILL 15 处）；扫 `LastWriteTime > 10-31`
  的 work 目录文件，确认这 5 天没有新真机事实（`E:\rom\release\tmp` 那批是 PCL/Java 缓存噪声，与本项目无关）。

### 2. 委派只读审计（不改文件）

子代理 `febbe8ad` 扫 90 文件，输出 25 条 (A) 类残留 / 6 文件，并逐条给出行号+原文+改法，
同时把 (B) 已标注撤回、(C) 单次实验现象两类分开，避免我把「当时的失败记录」也当错误删掉。
这份清单是本轮所有改动的依据。

### 3. 再做（改了什么，为什么）

- `knowledge-base.md`
  - 0.1 路线表：A14 与 A17 拆成两行，A17 行给 ⚠️「起到过桌面，可复现性未闭合」。
  - 0.4 当前状态：改到 2026-11-07，并加「persist 修复后基线已变」警告；保留 10-18 原文一句。
  - 5.6 层级总表：`换 system（A17） ❌` → ⚠️。这是全库唯一还在把 ❌ 用在 A17 行上的格子。
  - 6.1.1：写入判定实验的四模式表 + 读数定义 + 顺序约束（`vbmeta_a_D` 在位时 fastbootd/recovery 不可用）。
  - 9.7 第 3 条：`但即便绕过，闭源 vendor 仍是结构性障碍` 用删除线撤回，理由=A17 未绕过该门禁就起过桌面；
    新增第 10（单变量复验未跑）、11（旧观测取自 persist 全零机器）、12（4 份历史文档已补更正）条。
  - 版本记录补 v1.5 / v1.6 / v1.7 —— 之前 10-31 与 11-01 两轮改动只改了正文，没进版本表。
- `tb331fc SKILL.md`：知识库行数 1369→约 1600；日期口径从「原文 2026-10-18」改为分节口径；
  A17 节加脚本指针与基线警告；「当前状态」刷新；排障表加一行「同一份 A17 内容一次能起一次必崩 → 先查 vbmeta 链」。
- `rom-porting SKILL.md`（方法论页）：删掉「必然撞 LLNDK/HAL 代差」里的**必然**（违反证据规矩第 13 条），
  改成本机反例；故障表加「同内容一进一崩 → 查 vbmeta 链公钥」；并加一句可迁移教训：
  **算出「vendor 世代不够」不等于「所以不可行」，代差的真实后果要用量出来，不是推出来。**
- 新脚本 `tools\a17_single_var_vbmeta.ps1`：设计要点见脚本头。dry-run 里揪出两个真 bug——
  残留的 `-s fastboot` 参数、以及 DRY 模式下 `is-userspace` 恒为 no 导致 prep 分支永远跑不到。
- `tools\grab_a17_logs.ps1` 第 8 节：见 STATE。要点是**不重复抓 logcat**（环计数直接 grep 已落盘文本），
  并明确「判有没有刷机用 `btime`+`bootreason`+setupwizard 痕迹，不许用 `uptime`」。

### 4. 事故：我把历史改坏了，以及怎么复原的

- 现象：用 pwsh 内联 `@( @('原文','标记' + $MARKER + '原文') )` 做原地标注，写完后
  `澎湃4可行性结论:6` 只剩 `- 结论：`(5 字符)，`:424` 只剩标记(33 字符)，`会话复盘:84/:102` 同类。
  **原句被删除**，直接违反规矩第 15 条「补更正、不改历史」。
- 定位：同批次里用**单个纯字符串**（无 `+` 拼接）的条目全部正常（notz:206/207、三镜像:194 的标记、
  复盘:103），凡 new 值走了 `'a' + $MARK + 'b'` 的都只剩开头一段 → 拼接在传参环节被打断。
- 复原：先用只读脚本把受损行按 `L<n> len=<x> >>文本<<` 打印确认，再写
  `tools\_repair_doc_annotation.py`：内嵌从改动**之前**那次抽取里得到的原句，
  写入前断言当前内容 == 期望的受损内容（防止二次误伤），写完断言总行数不变（行号不得偏移），
  不符则拒绝落盘。四条全部命中，逐字复原。第二遍 `_repair_doc_annotation2.py` 补上
  第一次静默跳过的 `三镜像:194`，并把标记位置理顺（`- 结论：〔更正〕原文`）。
- 验证：`logs\_verify_docs_20261107.py` 只读复核 —— 15 项原句 verbatim 检查中 14 项 True，
  唯一 False 是我把「整行无标记」当成了匹配串（标记插在行内，句子本身完整），
  已单行打印 111 字符全文确认 `- 结论：` + 两句原话都在。四文件均含「更正节 + 同口径重读清单」。
- 教训落库：`PowerShell-5.1-三个静默坑` 追加坑 4；同时修正该记忆里第 1 条静态检查——
  `Parser::ParseFile` 在这台机上第一个 `[ref]` 收到的是 **Token[]**（2136 项），
  拿它的 `.Count` 当 parse error 数是错的，正解是合并两个 ref 后按类型名 `ParseError` 过滤。

### 5. 记（四层同步）

STATE 新节 / OPLOG 本节 / ACTION-LOG 三条 / A17 记忆加基线与实验 / PS 记忆加坑 4，
并把 A17 与 PS 两份记忆同步到 `记忆库`。

### 6. 下一步（设备一接上就能做，顺序固定）

1. `a17_single_var_vbmeta.ps1 -Variant prep`（fastbootd，约 6 GB）
2. 进 bootloader → `-Variant off` → 记 verdict + `ro.boot.veritymode`
3. `-Variant on` → 记 verdict（预期 20 s 900E，需长按电源复位）
4. `-Variant report` 看两边是否一进一崩；结论按「观测/推断/未知」写回 STATE + 记忆
5. 若 off 侧起来：立刻跑 `grab_a17_logs.ps1`，重点看第 8 节 persist 与音频环计数
   —— 这是新基线下第一个必须重测的东西。
