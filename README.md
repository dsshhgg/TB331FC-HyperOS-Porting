# TB331FC-HyperOS-Porting

联想小新平板 2024（TB331FC）移植 Xiaomi HyperOS 4.0 项目。

## 设备信息
- 设备：Lenovo Xiaoxin Pad 2024 (TB331FC)
- 平台：Qualcomm SM6225-AD (Snapdragon 685)
- 内核：GKI 5.15.123-android13（KMI: android13-5.15）
- 底包：ZUI 16.0.544 官方固件

## 移植源
- 源机型：Xiaomi Pad 6 Pro (yupei)
- ROM：HyperOS 4.0 / Android 17
- 包名：yupei-ota_full-OS4.0.5.0.XPZCNXM-user-17.0-4fe489f542

## 移植策略
**硬件靠 ZUI，上层靠 HyperOS**
- 保留 ZUI：boot / dtbo / vendor / odm / firmware
- 移植 HyperOS：system / system_ext / product / mi_ext

## 当前进度
- [x] ZUI 底包解包 + 结构分析 → `docs/zui_structure.md`
- [x] HyperOS 包解包 + 结构分析 → `docs/hyperos_structure.md`
- [x] 可行性评估报告 → `docs/feasibility_report.md`（结论：**不可行**完整移植）
- [x] vendor 差异清单 → `docs/vendor_diff.md`
- [ ] 首次试刷
- [ ] 开机调试

## 核心结论（2026-09-29）
**完整移植 yupei HyperOS 4 到 TB331FC 不可行。**
- GKI KMI：`android13-5.15` vs `android15-6.6`（否决）
- SoC：SM6225 vs 新一代高通（否决）
- Android：14/13 → 17（跨 3 代）
- 空间：系统侧 ~9.3 GiB > system_a 5.79 GiB
- 替代：GSI / 降级源包 / 既有 TB331FC 专包

## 环境依赖
- OrangeFox Recovery（TB331FC 专属）：见 [TB331FC-TWRP](https://github.com/dsshhgg/TB331FC-TWRP) fox-12.1 分支
- payload_dumper
- erofs-utils / simg2img
- magiskboot

## 分支策略
- `main`：稳定版移植成果、正式发布
- `dev`：日常开发（主要开发分支）
- `exp-xxx`：实验性改动

## 免责声明
本项目仅供学习交流，刷机风险自负，请务必备份原厂全部分区。
