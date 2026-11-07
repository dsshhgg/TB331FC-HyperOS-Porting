# DSH 会话复盘：TB331FC 救砖与澎湃 4.0 GSI 可行性（session-a1c5aa16）

> 数据来源：`D:\Downloads\dsh-session-session-e1892a4e-15a5-470b-863f-53e79c0ac548.zip` → `session.v4.jsonl`
> 1,962 事件 / 15,718,484 字符 / JSON 解析失败 0 行 / assistant 消息 364 条 / 工具调用 367 次
> 时间：2026-10-17 16:20:14 — 22:05:13（Asia/Shanghai），跨度 5 小时 45 分

---

## 一、一句话概括

这台机器（联想小新 Pad 2024，TB331FC）在一次**误刷 A17 系统镜像**后掉进 Qualcomm 900E 崩溃转储，随后靠 fastbootd 刷回原厂 `super_*.img` 完整救回；会话最终结论是**澎湃 4.0（A17）刷不了，唯一可行的是 A14 底座的 HyperOS 2.0 MysticGSI**，而真正的门禁是 **vendor API level 33**，不是 KMI。

---

## 二、12 个回合总览

| 回合 | 时间 | 耗时 | 步数 | 工具 | 用户消息 | 结束原因 |
|---|---|---|---|---|---|---|
| T1 | 16:20:14 | 20.2 min | 91 | 102 | 附件 zip 路径 | completed |
| T2 | 16:47:32 | 28.2 min | 53 | 52 | 平板开不了机 | completed |
| T3 | 17:22:59 | 7.5 min | 19 | 18 | xiufu | completed |
| T4 | 17:31:07 | 2.3 min | 6 | 5 | nengkaipengpai4gsima | aborted(user) |
| T5 | 17:33:47 | 12.2 min | 41 | 41 | 澎湃4.0 GSI懂？ | aborted(user) |
| T6 | 18:03:36 | 11.8 min | 35 | 34 | 1（+中途插话） | aborted(user) |
| T7 | 18:15:41 | 23.4 min | 31 | 30 | 不用备份其实本地都有刷机包了 | completed |
| T8 | 19:57:45 | 11.5 min | 21 | 20 | 咋回事现在 | completed |
| T9 | 20:09:38 | 10.1 min | 27 | 26 | KMI直接原版不就好了吗不然用GSI的 | completed |
| T10 | 20:20:47 | 1.6 min | 5 | 4 | 你就说有没有办法 要不你写个日志扫描 | interrupted |
| T11 | 21:11:25 | 12.8 min | 36 | 35 | jixu | **max-tokens** |
| T12 | 22:04:59 | 0.2 min | 1 | 0 | ？ | **max-tokens** |

- 3 次 `completed` 后被用户打断（T4/T5/T6）、1 次 `interrupted`（T10）、**2 次 max-tokens 收尾（T11/T12）**。
- 回合间长空档：T8 前 +78.7 min、T11 前 +49.0 min、T12 前 +40.7 min —— 用户离席/思考。
- T12 是**空回复**：模型只产出 7,259 字符推理就撞上限，用户什么也没收到。

---

## 三、主线剧情

### T1｜分析「上一个会话」的导出包
用户只丢了一个 zip 路径。会话打开分析后给出结论：那个会话（`session-e1892a4e`）3 个 turn 全部以 `max-tokens` 收尾，原因是 **`maxTokens=32768` 被 reasoning 吃掉 80.1%**（output 374,185 tok 中 reasoning 299,678 tok）；另有 80 次 bili 拒绝 DSH 原生压缩（需 `BILI_ALLOW_DSH_COMPACTION=1`）。建议：提高 maxTokens、降 reasoningEffort、清理压缩冲突。
> 讽刺的是：**本会话后来自己也在 T11/T12 栽在同一个 max-tokens 上。**

### T2–T3｜「平板开不了机」→ boot loop 诊断 → 修复
- 不是变砖，是 **boot loop**：`system_server` 进程数 0、`/data/tombstones` 64 个、每约 5 秒崩一次。
- 崩溃签名：`Abort message: 'JNI FatalError called: (system_server) Not allowlisted (3): /null'`，栈在 `libandroid_runtime.so` 的 `FileDescriptorInfo::CreateFromFd`。
- 根因链：**PID1 泄漏 fd3 → `/null`**。`readlink /proc/1/fd/3` = `/null`，来源是 v4 `ib_copier.img` 里的 `kai_init.sh` 在 stage1 执行 `exec 3>>/dev/kmsg`，而当时 `/dev/kmsg` 不存在，于是在 rootfs 建了普通文件，随后变 deleted，readlink 解析成 `/null`。
- 修复：`fastboot flash init_boot_a ib_patched.img`（sha256 `F18DC14A…D68B152`）。刷后 `boot_completed=1`、system_server 存活、tombstone 0、KSU root 可用。
- 教训：**`exec 3>>/dev/kmsg` 必须先 `[ -c /dev/kmsg ]` 判断，绝不能在 PID1 留 fd**。修正版 `kai_init_v5_FIXED.sh` 已写出，**未打包未刷**。

### T4–T6｜澎湃 4.0 GSI 就绪度
- 用户问「能不能开澎湃4 GSI」。助手一度误读为「4G SIM」后纠正。
- 关键门槛确认：设备在 **fastbootd**（`is-userspace: yes`，PID 4EE0）。此前「没有 fastbootd」的判断是错的——fastbootd 在 ramdisk 里。
- 用户插话（原话）：**「你或许应该换种方式 我感觉别人都做得到你做不到这是问题啊 你就像没学到精髓一下乱闯」**。助手承认「一直在反复试探」，并提炼四条：先读已验证文档、用现成脚本、写分区前先备份、逻辑分区必须进 fastbootd 且 resize 用带槽位名。
- 挂载拓扑实测出现**文档与现实的冲突**：
  - GSI_Kit 文档（`01_发布稿/技术记录-踩坑与原理.md` 561–583 行）说 `/`、`/system`、`/system_ext`、`/product` 全在同一个 ext4（dm-2），只需刷一个 `system_a`；
  - 实测 ZUI16：`/`→dm-7（system-verity）、`/system`→dm-7、**`/system_ext`→dm-8（独立）**、**`/product`→dm-13（独立）** → 这两个分区真的会挂载，只刷 system_a 会被遮住。这正是 `flash_hyperos4_three.ps1` 要写三个分区的原因。

### T7｜刷入 A17 三镜像 → 掉进 900E
- 关键发现（推翻了之前的判断）：`TB331FC_ZUI_16.0.544\image\super_*.img` **不是只能 EDL 刷的物理切片，它们就是各逻辑分区的原始 ext4 镜像**：`super_4.img`=5,493,624,832=system_a、`super_3.img`=594,411,520=product_a、`super_6.img`=460,103,680=system_ext_a。
- dry-run 通过：system 缩到 1,749,999,616（腾 3.74 GiB）、product 扩到 2,999,996,416、system_ext 扩到 1,549,996,032，合计 10,043,617,280 < 组上限 12,876,513,280。
- 执行刷入（不带 `-Wipe`）→ 重启后掉 **Qualcomm 900E 崩溃转储模式（COM6）**，`fh_loader`/`QSaharaServer` 全部超时。

### T8｜救回原厂
- 900E 期间读到 48 字节 Sahara 头 `01 00 00 00 30 00 00 00 … mode=02`（memory dump），确认无法用 firehose 接入。
- 设备**自己退出 900E** → bootloader fastboot → recovery（adbd 崩 `Could not set SELinux context for subprocess` → `Fatal signal 6`）→ **fastbootd**。
- 按「先缩 product/system_ext 再扩 system」还原尺寸后刷回 `super_4/3/6.img`（system 21 个 sparse 包，177 秒）→ **完全恢复原厂 ZUI 16.0.544**：`boot_completed=1`、system_server=1799、tombstone=0、KSU root 可用、前台 launcher 正常。
- 助手自述错误：**「`tb331fc_hyperos_readme.md` 里早就写明 KMI `android13-5.15` vs `android15-6.6` 完整移植不可行……我把『未被证否』当成了『大概率能成』。」**
- 参考文档：`E:\rom\docs\救砖_900E转9008教程.md`（900E=PID `05C6:900E`，Sahara；9008=PID `05C6:9008`，标准 EDL）、`E:\rom\docs\排查_900E根因.md`。

### T9｜纠正 KMI 误解，定位真正门禁
用户一句「KMI直接原版不就好了吗不然用GSI的」点破了逻辑错误：
- **GSI 不含内核**，天生跑在原厂 KMI 上；「用原版 KMI」和「用 GSI」是同一条路。之前把「完整移植不可行（含换内核）」套到「只换 system」上是错的，已撤回。
- 真正的阻碍是 **vendor API level**：设备侧 `ro.board.api_level=33`、`ro.vendor.api_level=33`、`ro.vndk.version=33`；A17 镜像要求 `ro.llndk.api_level=202604`。A17 的 `init` 里有串 `Unexpected vendor api level for`（ZUI16 的 init 里 0 条）→ 启动即中止 → 900E。vendor 是闭源 blobs，改不了。
- 对照表：

| | kit GSI（能启动） | A17 三镜像（掉 900E） |
|---|---|---|
| `ro.build.version.sdk` | 34 | 37 |
| `ro.mi.os.version.name` | OS2.0 | — |
| `ro.llndk.api_level` | 无 | 202604 |
| `ro.debuggable` | 1 | 0 |

- 结论：〔⚠️ 2026-11-07 更正：本条已撤回，见文末「更正」节〕**澎湃 4.0 刷不了（结构性原因）；能跑的是 A14 底座的 HyperOS 2.0 MysticGSI**（`E:\rom\extracted\GSI_Kit\05_镜像\GSI\system_a_完全自包含.img`，5,794,435,072 B，三步：`fastboot reboot fastboot` → `fastboot flash system <img>` → 重启，从原厂首次刷需 `fastboot -w`）。
- 遗留疑点（未验证）：只刷 system_a 时原厂 product_a/system_ext_a 会遮住 GSI 内同名目录，可能需用 `make_ext4fs.exe` 额外打包并刷入这两个子树。
- 助手最后问「要不要直接刷 kit GSI？」，**用户未回答**。

### T10–T11｜「有没有办法」→ 日志扫描
- 用户要「日志扫描」。T10 查 ramoops/pstore/bootstat/metadata/gsi 全部无收获，被 interrupted。
- T11 找到 **Lenovo 持久化 kernellog**（`/data/local/newlog/aplog/kernellog*`，6 个轮转约 22 MB），拉到 `E:\rom\release\tmp\kernellogs`，写扫描器 `E:\rom\release\tmp\scan_bootlog.py`。
- 结论：**6 个内核日志全是 ZUI 启动，没有一次 HyperOS 启动**（`missi` 是 `missing` 的误匹配）。
- 转去逆向 A17 `init` 的 vendor api level 门禁（capstone 反汇编），定位到 `0x0f627c` 起读 `ro.vendor.api_level`，默认常量 `0x0F4240 = 1,000,000`，与 `ro.build.version.sdk`（`w21=0x2710=10000`）比较，失败后 `bl #0x282378` 且 w0=4（疑似 LOG(FATAL)）。
- **T11 以 max-tokens 结束**，扫描器判定逻辑的 bug（kernellog.3/.4 误判 FAIL-MID、需按轮转序而非时间戳排序）未修完。

### T12｜「？」→ 空回复
用户等不到答复发了一个「？」。模型只产出 7,259 字符推理（内容是「该汇总『有没有办法』+ 交付扫描器」的计划），无正文、无工具，撞 max-tokens 结束。**用户实际未收到任何回复。**

---

## 四、关键结论

1. 〔⚠️ 2026-11-07 更正：本条已撤回，见文末「更正」节〕**澎湃 4.0（A17/SDK37/GKI6.6）在 TB331FC 上结构性不可行** —— 卡点是 vendor API level 33（闭源），不是 KMI，也不是"用不用 GSI"。
2. **唯一可行路线**〔2026-11-07 更正：「唯一」不成立，A17 亦起到过桌面〕：A14 底座的 HyperOS 2.0 MysticGSI（GSI_Kit 那套），需 `fastboot -w`，`/data` 当时占 3.6 GB。
3. **救砖路径已被验证两次**：原厂包 `super_4/3/6.img` 可直接 `fastboot flash system_a/product_a/system_ext_a`，不必 QFIL/9008。顺序必须**先缩 product/system_ext 再扩 system**。
4. **900E ≠ 9008**：900E 是 Sahara 崩溃转储，firehose 接不进；软件侧无解，只能等设备自行退出或物理断电进 9008。
5. **boot loop 根因是 PID1 的 fd 泄漏**（`exec 3>>/dev/kmsg` 在 `/dev/kmsg` 不存在时创建普通文件）。

---

## 五、工具与上下文管理

| 项 | 数值 |
|---|---|
| 工具调用总数 | 367 |
| `pwsh` | **330（89.9%）** |
| `compress` | 19（18 成功 / 1 失败） |
| `decompress` / `search_context` / `acp_status` | 5 / 5 / 3 |
| `read` | 2 |
| hindsight / mnemon / MCP 资源 | 各 1 |
| 压缩节省（自报累计） | 单次最大 ~743,732 tokens（T11 一次重压 13 块） |

- 推理 vs 正文（字符）：**reasoning 2,442,466 / text 25,661 ≈ 99%**。T2 最夸张（877,263 推理 / 5,163 正文）。T4、T10、T12 正文为 0。
- usage：输出 token 合计约 **865,519**，输入（非缓存）约 **1,625,951**，cacheRead 约 **19,724,288**。`reasoningTokens` 仅 T1 上报（59,830），workbuddy-ai 路由从 T2 起恒为 0。
- 6 条错误类 tool/result：2× `unknown tool "read"`（T1）、1× 压缩 ref 失效（T1S88）、1× MCP server 不存在（T3）、1× `tool call aborted`（T5）、1× Hindsight 401。

## 六、模型与配置

- **T1**：`our-free-model/deepseek-v4.1-flash-free`，`reasoningEffort=deep`，`maxTokens=32768`，contextWindow 128,000，tools 48。
- **T2 起**：`workbuddy-ai/deepseek-v4.1-flash`，`reasoningEffort` 经 `xhigh` → `max`，**config 里不再有 maxTokens**，contextWindow 1,000,000，tools 48。
- **T11 step1** 经 developer/message 动态追加 `read_original_image` → tools 49。
- 会话预设：session 头 `agentPreset=standard`，但 seq9 有 `agent-preset/selected minimal`（两者矛盾）。
- 权限：开局 `workspace-write` + `ask`，用户随即改成 `danger-full-access` + `never`。

## 七、失败与教训

1. **max-tokens 是这次会话真正的杀手**：T11、T12 均因此截断，T12 用户完全没得到回复。reasoning 占 99% 字符是元凶。
2. **"未被证否"≠"大概率能成"**：把 A17 system 刷到 A14 kernel 上，直接导致 900E。已有文档（`tb331fc_hyperos_readme.md`、`排查_900E根因.md`）早就写明了结论，没读透就动手。
3. **反复试探而非读现成方案**：用户点名批评「你就像没学到精髓一下乱闯」。GSI_Kit README 的三步早已跑通，却因 `grep /system/bin/fastbootd` 找不到就否定整条路。
4. **结论前后矛盾**：super 切片"只能 EDL 刷"→ 后被自己推翻；"没有 fastbootd"→ 后被推翻；"KMI 不通"→ 被用户一句话推翻。多次自我纠正是好的，但代价是大量回合。
5. **日志扫描方向初期错误**：先查 ramoops/pstore（全空），后来才想到 Lenovo 持久化 kernellog。

## 八、未完成事项（会话结束时仍开放）

1. **回答用户「有没有办法」的最终答复未产出**（T12 空回复）——这是最严重的未交付。
2. `scan_bootlog.py` 判定逻辑待修（FAIL-MID 误判、需按文件轮转序排序）。
3. A17 init vendor api level 门禁逆向未完成（能否 patch init 绕过 + 处理 AVB/dm-verity）。
4. 是否刷 GSI_Kit 的 A14 HyperOS 2.0，仍等用户决定。
5. 用户此前问「要我把这次救砖的完整步骤写进 `E:\rom\docs\` 吗？」未获答复。
6. `kai_init_v5_FIXED.sh` 已写出但**未打包未刷入**。

---

## 附：导出包身份说明

zip 文件名是 `dsh-session-session-e1892a4e-…`，但内部 session 头是 `session-a1c5aa16-cca9-4d69-a1de-d59790d099cb`。字符串 `e1892a4e` 在 jsonl 中出现 51 次，全部来自**本会话第一条用户消息所附的上一个会话导出包路径**。即：文件名沿用了会话里被引用的附件名（或用户重命名），**内容与文件名不是同一个会话**。已从 zip 流式重读校验：单 entry、uncompressed 16,140,427 B、行数 1,962、首行与解包副本逐字一致，无篡改。

---

## 更正（2026-11-07 追加；正文除带「更正」标记的行外一字未改，历史行号保持不变）

**撤回的判断**：本文里「A17 / 澎湃 4.0 结构性不可行 / 不建议继续投入 / 放弃 A17 / 唯一可行路线」一类结论。

**撤回依据是一手设备回显，不是重新推断**（档案 `session-7366fc24` 的 tool/result 原文）：

| 观测 | 原始输出 | 出处 |
|---|---|---|
| 系统版本 | `release=17`、`sdk=37`、`sys.boot_completed=1` | seq 7322 |
| 传感器 | `Total 29 h/w sensors, 29 running`（BOSCH bmi3x0 acc/gyro ver 306） | seq 7343 |
| 指纹 | `Lenovo/miproduct_yupei/TB331FC:17/CP2A.260605.016/OS4.0.5.0.XPZCNXM:user/release-keys` | seq 7380 |
| 用户态 | `package:mark.via`、`package:com.android.MGC_8_8_224` 已装 | seq 7580 |

**现在的准确表述**：A17 在 TB331FC 上**能启动到桌面**，未闭合的是**可复现性**——2026-10-27 同一组合仍 20 s 900E，当时 `system_ext_a` 刚被 fastbootd Resizing、`--set-active=a` 报过 `Unable to set slot`。

**卡点定位也跟着改了**：不是 vendor API level 33 代差（`Unexpected vendor api level for` 只是 init 的 LOG 级记录），不是 `tz_log_dlkm`，也不是缺 `remote_heap_config.so`（实测官方 `dspso.bin` 里该串命中 0 次）。剩下的疑点在 **vbmeta 链公钥 → dm-verity 是否启用**（推断，反证条件与判定脚本见下）。

**本文的保留价值**：解包/签名/刷机命令、字节级取证、回滚流程仍然有效，作为**历史取证材料**使用；**不要据此停止投入**。

**基线提醒**：本文所有真机观测都取自 persist **整块全零** 的机器（2026-11-01 才写回修好），旧观测与现在的表现不可比。

**现行口径**：skill `tb331fc-flash-porting` 的 `references/knowledge-base.md` §6.1.1 · `E:\rom\work\docs\STATE.md` 的「更正」节 · 记忆 `A17-TB331FC-可开机配置与900E分界`。判定实验 `E:\rom\work\tools\a17_single_var_vbmeta.ps1`（只换 8 KB 的 `vbmeta_a` 的单变量复验，已 dry-run 校验、未跑真机）。

**同口径重读**：11（会话总结论「A17 刷不了」）、74（把 `Unexpected vendor api level for` 读成「启动即中止 ⇒ 900E」；实际只是 init 的 LOG 级记录）。
