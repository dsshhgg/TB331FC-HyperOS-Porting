# 体积报告 · A 档拼包结果

> 日期：2026-10（v2 重建） · 路线：**ZUI 原厂内核 + HyperOS 系统侧**
> 状态：**A 档达标**（未执行任何刷写）
> 变更：v1 基于**不完整抽取树**，已废弃；本版全链由 sha256 校验过的原镜像重解后重建。

---

## 1. 目标与结果

| 档位 | 目标 | 结果 |
|------|------|------|
| **A（理想）** | **< 4.5 GiB（4608 MB）**，直接刷 `system_a` | ✅ **3.468 GiB / 3551.2 MB** |
| B（极限） | 4.5–5.5 GiB，需 `resize-logical-partition` | 未触发，**也不需要** |

**结论：A 档达标，且无需扩容分区。**

| 项 | 值 |
|----|-----|
| 产物 | `out/system_a_hyperos4_A.img` |
| 大小 | **3,723,653,120 B（3.468 GiB / 3551.2 MB）** |
| SHA256 | `F0998B55CF317380AD66ABABD52006592E1EBD455B62A7217F2A05383B428EF9` |
| MD5 | `4C96C73CC96DC23E9FF4C226022C51D3` |
| 格式 | EROFS · lz4hc · 压缩率 **67.5%** · inode **10,359** |
| 旧产物（已弃用） | `out/system_a_hyperos4_A.img.incomplete-tree`（2.99 GiB） |

---

## 2. 为什么重建（v1 缺件）

v1 的树由 `extract.erofs` 抽出，**抽不全**（该问题 `port_stock_kernel.md` §3 早有记录，但当时未重解）。
从 sha256 校验过的原镜像重新解包后对照：

| 分区 | v1 树 | 重解后 | v1 缺失 |
|------|-------|--------|---------|
| system | 3,621 文件 / 1051.7 MB | **4,582 文件 / 1392.5 MB** | **961 个**（`lib64` 495、`usr/keylayout` 189、`usr/hyphen-data` 106、`usr/idc` 27…） |
| system_ext | 3,373 文件 / 984.5 MB | **3,448 文件 / 1301.2 MB** | 75 个 |
| product | — | 1,624 → debloat 后 1,424 | 与镜像侧 2,182 条目核对一致 |
| mi_ext | 79 文件 | 79 文件 / 448.3 MB | 0（完整） |

即 v1 缺 **1,036 个文件**，含**约一半 system 库（495 个 `.so`）和全部输入布局**
（`keylayout`/`idc`，缺了直接影响触摸与按键）。v1 镜像因此不能用于试刷，否则会把
「镜像缺件」和「兼容性不通」混在一起。

重建同时修复了 `pack_system_a.ps1` 的**两个构建缺陷**（详见主报告 §8A.6）：

1. `Resolve-Root` 以 `etc`/`bin` 为判据，会误选**镜像根**而非真正的 `/system` 内容
   → 改为优先选含 `build.prop` 的最深一层。
2. system 内容里的分区挂载点符号链接 `product→/product`、`system_ext→/system_ext`
   与合并目标目录撞名，robocopy 报 `ERROR 267 (0x10B)` 而中止
   → 合并前移除这两个工件（`media`/`vendor` 保留，镜像内确认仍是符号链接）。

> 注：v1 树因缺件恰好**不含**这几个符号链接，所以旧构建没撞上——**完整性缺陷掩盖了构建 bug**。

---

## 3. Debloat 过程（product）

| 阶段 | product 树 |
|------|-----------|
| 全量（重解） | **7,393.3 MB** |
| 砍后 | **2,570.1 MB** |
| 释放 | **4,823.2 MB** |

### 已删除（按体积，清单见 `DEBLOAT_APPLIED.md`）

- **data-app（主战场，3.23 GiB）**：CadLauncher · WpsLauncher · MiShop · MiMediaEditor ·
  CAJLauncher · MIUIMusicPAD · Creation · SmartHome · MIUIVideoPad · BaiduIME · MIpayPad ·
  MiuiScanner · MIUIGameCenterPad · MIUIWeather · iFlytekIME · MIUIDuokanReaderPad 等 28 项
- **priv-app**：MIUIBrowserPad · MIUIAICR · MIUIFindDeviceCN · MiuiCamera · MIUIAod ·
  游戏中心/小游戏 · GmsCore · Backup · 负一屏 · MirrorOS4 · 黄页/云备份/弹幕 等 18 项
- **app**：talkback · SwitchAccess · AiasstVision · VoiceTrigger · 应用商店 ·
  HybridPlatform · PaymentService · 统计/日志/CIT 等 31 项
- **media**：AI 壁纸 54.8 · yupei 壁纸 65.1 · os4_fonts 93.1 · MILanProVF.mtz 19.6

### 保留（开机/核心）

MiuiHome · MISettings · SystemUI 相关 · FileExplorer · SogouIME · 相册/笔记/时钟/日历/计算器 ·
账号/云同步核心 · MiSound · WebViewGoogle64
· TB331FC.xml 已注入 `product/etc/device_features/`

---

## 4. 合并树体积 → 镜像

| 树 | 解包 MB | 文件 |
|----|---------|------|
| system（置镜像根） | 1,392.5 | 4,557 |
| product（debloat 后） | 2,570.2 | 1,424 |
| system_ext | 1,301.2 | 3,445 |
| **合计（不含 mi_ext）** | **5,263.9** | **9,425** |
| **EROFS 打包后** | **3,551.2 MB（3.468 GiB）** | inode 10,359 |

未纳入 `mi_ext`（448.3 MB / 76 文件）；若要小米扩展可 `-IncludeMiExt`，
预计再增约 300 MB 打包体积，仍在 4.5 GiB 以内。

---

## 5. 分区对照（**修正**）

| 项 | 值 |
|----|-----|
| TB331FC `system_a` | **5.12 GiB = 5,493,624,832 B** |
| 本次 A 档镜像 | **3.468 GiB = 3,723,653,120 B** |
| 余量 | **1.65 GiB = 1,769,971,712 B** |
| 是否需要 `resize-logical-partition` | **否** |

> ⚠️ v1 文档写 `system_a = 5.79 GiB` 是**错的**，实测为 **5.12 GiB**
> （见主 README「数据修正」表）。余量按正确值重算。

### 镜像内容校验

| 检查项 | 结果 |
|--------|------|
| `/lib64` 条目 | **1,002**（v1 镜像仅 503） |
| `/usr/keylayout` 条目 | **190**（v1 树缺 189） |
| `/apex` 条目 | 36 |
| 关键 HIDL/LLNDK 库 | `libhidlbase` `libhidltransport` `libhwbinder` `libutils` `libhardware` `libhardware_legacy` `libion` `libsync` `libgralloctypes` `libvndksupport` `libbase` `libcutils` —— **12/12 存在** |
| 符号链接 | `media`（→`/product/media`）、`vendor`（→`/vendor`）在镜像内**仍为符号链接** |

---

## 6. ⚠️ 布局警示：只刷 system_a 会被遮蔽

合并镜像是**「单分区合并」**设计：HyperOS 的 `system` 内容置于镜像根，
`product` 与 `system_ext` 作为**子目录**并入（镜像内 `/product`、`/system_ext`）。
但 TB331FC 上 `/product`、`/system_ext` 是**独立分区**（ZUI 的 `product_a` / `system_ext_a`）。

**若只刷 `system_a`**：设备上的 `/product`、`/system_ext` 解析到 **ZUI 的 A14 内容**，
镜像内的 HyperOS A17 `product` / `system_ext` **不会被引用**；镜像根的 `/media`
（→ `/product/media`）同样指向 ZUI 的内容。

→ 试刷若失败，**无法区分**「兼容性不通」与「product/system_ext 被遮蔽」。
若要 HyperOS 的 product/system_ext 生效，必须**同时替换或清空 `product_a` / `system_ext_a`**
（分区写入，需另行确认）。

---

## 7. 文件

| 路径 | 说明 |
|------|------|
| `out/system_a_hyperos4_A.img` | 可刷产物（**待确认再刷**） |
| `out/system_a_hyperos4_A.img.incomplete-tree` | v1 缺件镜像（备查，勿刷） |
| `out/merge_root/` | 合并树（9,425 文件 / 5,263.9 MB） |
| `work/trusted_trees/` | 重解可信树（源） |
| `scripts/debloat_product.ps1` | 精简脚本 |
| `scripts/pack_system_a.ps1` | 打包脚本（已修 2 处缺陷） |
| `scripts/backup_partitions.ps1` | 试刷前备份（默认 dry-run，只读设备） |
| `out/MD5SUMS.txt` | 校验 |

---

## 8. 下一步（禁止自动刷写）

1. 你确认镜像与 debloat 清单
2. **先定 `product_a` / `system_ext_a` 的处理方案**（见 §6）——否则 S1 结果无法判读
3. 跑 `scripts/backup_partitions.ps1 -Execute` 做全分区备份，并确认 9008 救砖可用
4. （可选）回加应用 / 加 mi_ext / 注入 `_boot_fix` 补丁
5. 出刷写脚本（只 `flash system`，保留 boot/vendor）
6. **等你明确说「可以刷」再动分区**
