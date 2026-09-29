# TB331FC-HyperOS-Porting

联想小新平板 2024（TB331FC）移植 Xiaomi HyperOS 4.0 项目。

## 设备信息
- 设备：Lenovo Xiaoxin Pad 2024（TB331FC）
- 平台：Qualcomm SM6225-AD（Snapdragon 685）
- 内核：GKI 5.15.123-android13（KMI: android13-5.15）
- 底包：ZUI 16.0.544 官方固件

## 移植源
- 源机型：Xiaomi Pad 6 Pro（yupei）
- ROM：HyperOS 4.0 / Android 17
- 包名：yupei-ota_full-OS4.0.5.0.XPZCNXM-user-17.0-4fe489f542

## 移植策略
**硬件靠 ZUI，上层靠 HyperOS；内核用原厂，不换 yupei 内核。**

- 保留 ZUI：boot / init_boot / vendor_boot / dtbo / vendor / odm / firmware
- 移植 HyperOS：system / system_ext / product（已 debloat）

## 核心结论（2026-09-29）
**完整移植 yupei HyperOS 4（含内核/vendor）不可行。**

| 维度 | 结论 |
|------|------|
| GKI KMI | android13-5.15 vs android15-6.6，不兼容（否决） |
| SoC | SM6225 vs 新一代高通，固件/驱动不可互换 |
| Android | 14/13 → 17，跨 3 个大版本 |
| 空间 | 原始系统侧 ~9.3 GiB > system_a 5.79 GiB |

**已推进路线：** ZUI 原厂内核 + 只换系统侧，并完成 A 档精简打包。

| 档位 | 目标 | 结果 |
|------|------|------|
| A（理想） | < 4.5 GiB，直接刷 system_a | **3059 MB（2.99 GiB）** |
| B（极限） | 4.5–5.5 GiB | 未触发 |

## 当前进度
- [x] ZUI 底包解包 + 结构分析 → `docs/zui_structure.md`
- [x] HyperOS 包解包 + 结构分析 → `docs/hyperos_structure.md`
- [x] 可行性评估报告 → `docs/feasibility_report.md`
- [x] vendor 差异清单 → `docs/vendor_diff.md`
- [x] 原厂内核路线锁定 → `docs/port_stock_kernel.md`
- [x] Debloat + A 档打包 → `docs/size_report.md`（镜像 3059 MB，未刷）
- [ ] 首次试刷（等确认）
- [ ] 开机调试

## 文档索引
| 文档 | 内容 |
|------|------|
| `docs/feasibility_report.md` | 移植可行性（结论：完整移植不可行） |
| `docs/可行性分析.md` | 同上（中文文件名） |
| `docs/zui_structure.md` | ZUI 底包结构 |
| `docs/hyperos_structure.md` | HyperOS 源包结构 |
| `docs/vendor_diff.md` | vendor/硬件差异 |
| `docs/port_stock_kernel.md` | 原厂内核移植路线 |
| `docs/size_report.md` | A 档体积报告 |
| `docs/DEBLOAT_APPLIED.md` | 已删除应用清单 |
| `docs/移植日志.md` | 时间线 |

## 脚本
见 `scripts/README.md`。大镜像不进仓库，路径在 `E:\rom\port\hyperos\assets\` 与 `out\`。

## 分支策略
- `main` / `dev`：分析成果与脚本（当前同步至 `7c401af`）
- 实验改动请走新分支

## 环境依赖
- OrangeFox / TWRP（TB331FC 专属）
- payload-dumper-go
- erofs-utils（extract / mkfs）
- magiskboot

## 免责声明
本项目仅供学习交流，刷机风险自负，请务必备份原厂全部分区。  
**未经确认不得执行 fastboot flash 或任何分区写入。**
