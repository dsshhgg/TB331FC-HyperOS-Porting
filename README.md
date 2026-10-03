# TB331FC-HyperOS-Porting

联想小新平板 2024（TB331FC）移植 Xiaomi HyperOS 4.0 项目。

## 设备信息
- 设备：Lenovo Xiaoxin Pad 2024（TB331FC）
- 平台：Qualcomm SM6225-AD（Snapdragon 685，`bengal`）
- 内核：GKI `5.15.123-android13-8`（**KMI: android13-5.15**）
- 底包：ZUI 16.0.544 官方固件（系统侧 Android 14 / SDK 34，厂商侧 Android 13 / SDK 33）

## 移植源
- 源机型：**Xiaomi Pad 8**（codename **`yupei`**）⚠️ *不是小米平板 6 Pro —— 6 Pro 的 codename 是 `liuqin`*
- ROM：HyperOS 4.0 / Android 17（SDK 37），厂商侧 Android 15 / SDK 35
- 包名：`yupei-ota_full-OS4.0.5.0.XPZCNXM-user-17.0-4fe489f542`
- CPU 微架构：`oryon`（高通自研 Oryon 核，骁龙 8 Elite 世代）
- 内核：GKI `6.6.118-android15-8`（**KMI: android15-6.6**）

## 移植策略
**硬件靠 ZUI，上层靠 HyperOS；内核用原厂，不换 yupei 内核。**

- 保留 ZUI：boot / init_boot / vendor_boot / dtbo / vendor / odm / vendor_dlkm / system_dlkm / firmware
- 移植 HyperOS：system / system_ext / product / mi_ext

## 核心结论（2026-10 复核）
**完整移植 `yupei` HyperOS 4（含内核/vendor）不可行。**

| 维度 | 结论 | 量化 |
|------|------|------|
| GKI KMI | ❌ **否决** | `android13-5.15` vs `android15-6.6` |
| SoC / 固件 | ❌ **否决** | `bengal`(SM6225) vs `oryon`(骁龙 8 Elite 级) |
| Android | ❌ | 系统 14→17（+3），厂商 13→15（+2） |
| vendor HAL | ❌ | 显示 / 触摸 / 音频 / 传感器 **四层全不可互换** |
| 空间 | ⚠️ **可解** | 系统侧 7.96 GiB；super 余量 5.20 GiB，重排后 8.65 GiB ≤ 11.99 GiB |
| 文件系统 | ⚠️ 可解 | ZUI=EXT4，yupei=EROFS，可转换 |
| vendor API level | ❌ **新发现** | ZUI `ro.board.api_level=33` vs A17 `ro.llndk.api_level=202604`（差约 3 年接口面） |

### 两条路线的区分（2026-10 v2 更正）

| 路线 | 结论 |
|------|------|
| **完整移植**（换内核 + vendor + system） | ❌ **不可行** —— KMI + SoC 双否决 |
| **保留原厂内核/vendor，只换 system 侧**（本项目锁定策略） | ⚠️ **超出官方兼容包线，但未被证否** —— 真正的关卡是 vendor API level / VNDK / BPF，**只能实测判定** |

> **推荐**：先做最小代价实测（只刷 `system_a`，S1），再决定是否转 GSI 或降级源包。
> 详见 [`docs/移植可行性报告.md`](docs/移植可行性报告.md) §8A（机制级取证）与 §9（路线表）。
>
> ⚠️ 注意：合并镜像把 HyperOS 的 `product` / `system_ext` 放在镜像内，
> 只刷 `system_a` 时会被 ZUI 的 `product_a` / `system_ext_a` **遮蔽**（报告 §8A.6）。

### ⚠️ 数据修正（2026-10）

早期文档（2026-09）存在若干错误，本版已用二进制实测数据全面修正：

| 项 | 旧值（错） | 实测值 |
|----|-----------|--------|
| TB331FC `system_a` | 5.79 GiB | **5.12 GiB**（5,493,624,832 B） |
| product / system_ext | 「system 内的目录」 | **独立的 super 逻辑分区**（566.88 MiB / 438.79 MiB） |
| HyperOS 系统侧合计 | 9.26 GiB | **7.96 GiB**（8,549,466,112 B） |
| 空间是否否决项 | 「物理装不下」 | **不是否决项**（可重排 super） |
| 源机型 | 小米平板 6 Pro | **Xiaomi Pad 8（`yupei`）** |

## 当前进度
- [x] ZUI 底包解包 + 结构分析（liblp / EXT4 实测）→ `docs/zui_structure.md`
- [x] HyperOS 包解包 + 结构分析 → `docs/hyperos_structure.md`
- [x] 解包完整性校验（8 个镜像 sha256 全部与官方 payload 清单一致）
- [x] 可行性评估报告 → `docs/移植可行性报告.md`
- [x] vendor 硬件栈逐层对比 → 报告 §6
- [x] vendor 保留/补丁清单 → `docs/vendor合并补丁清单.md`
- [x] 原厂内核路线锁定 → `docs/port_stock_kernel.md`
- [x] Debloat + A 档打包 → `docs/size_report.md`
- [x] **重解可信树 + A 档镜像重建（v2）** —— 旧树缺 1,036 文件（`lib64` 495 / `keylayout` 189 / `idc` 27）；
      新镜像 3.468 GiB / SHA256 `F0998B…8EF9`，12/12 关键 HIDL 库到位，`/lib64` 1,002 条，
      ZUI `system_a` 分区余量 1.65 GiB（**无需 resize**）→ 报告 §8A.6
- [x] 试刷前备份脚本 `scripts/backup_partitions.ps1`（默认 dry-run，只读设备）
- [ ] 路线选择（实测 S1 / GSI / 降级源包 / 放弃）—— **等确认**
- [ ] 首次试刷（等确认）

## 文档索引
| 文档 | 内容 |
|------|------|
| [`docs/移植可行性报告.md`](docs/移植可行性报告.md) | **主报告**：版本差距 / KMI / 分区 / 空间 / 硬件栈 / 结论 |
| [`docs/vendor合并补丁清单.md`](docs/vendor合并补丁清单.md) | ZUI 资产白名单 + GSI 补丁点 + 条件性合并点 |
| [`docs/zui_structure.md`](docs/zui_structure.md) | ZUI 底包结构（已修正） |
| [`docs/hyperos_structure.md`](docs/hyperos_structure.md) | HyperOS 源包结构（已修正） |
| [`docs/vendor_diff.md`](docs/vendor_diff.md) | vendor 差异（已迁移至主报告 §6） |
| [`docs/可行性分析.md`](docs/可行性分析.md) / [`docs/feasibility_report.md`](docs/feasibility_report.md) | 旧版跳转页 |
| [`docs/port_stock_kernel.md`](docs/port_stock_kernel.md) | 原厂内核移植路线 |
| [`docs/size_report.md`](docs/size_report.md) | A 档体积报告 |
| [`docs/DEBLOAT_APPLIED.md`](docs/DEBLOAT_APPLIED.md) | 已删除应用清单 |
| [`docs/移植日志.md`](docs/移植日志.md) | 时间线 |

## 脚本
见 [`scripts/README.md`](scripts/README.md)。大镜像不进仓库，路径在 `E:\rom\port\hyperos\assets\` 与 `out\`。

| 脚本 | 用途 |
|------|------|
| `scripts/parse_super_lp.py` | 解析 super 的 liblp 元数据（逻辑分区 / 大小 / extent） |
| `scripts/ext4_ls.py` | 纯 Python 只读 EXT4 镜像遍历与导出 |
| `scripts/extract_props.py` | 扫描镜像中的 `ro.*` / `androidboot.*` 属性 |
| `scripts/verify_payload.py` | 解析 payload 清单并校验解包镜像 sha256 |

## 分支策略
- `main` / `dev`：分析成果与脚本
- 实验改动请走新分支

## 环境依赖
- OrangeFox / TWRP（TB331FC 专属）
- payload-dumper-go
- erofs-utils（extract / mkfs）
- magiskboot
- Python 3（本仓库分析脚本零第三方依赖）

## 免责声明
本项目仅供学习交流，刷机风险自负，请务必备份原厂全部分区。  
**未经确认不得执行 fastboot flash 或任何分区写入。**
