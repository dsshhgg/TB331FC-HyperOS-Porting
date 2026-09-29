# HyperOS 移植可行性报告

> 对象：把 **HyperOS 4（yupei / Android 17）** 移植到 **联想 TB331FC**（底包 **ZUI 16.0.544**）
> 日期：2026-09-29 · 只做解析对比，未执行任何分区写入
> 依据：`docs/zui_structure.md`、`docs/hyperos_structure.md`、实测 boot/kernel 字符串、care_map 指纹、payload 分区表

---

## 一句话结论

**不可行（完整移植 yupei HyperOS 4 系统 + 混用 vendor）。**  
内核 KMI 跨代、SoC 不同、Android 跨 3 个大版本、系统侧体积超出分区。  
若目标是「在 TB331FC 上跑 HyperOS 体验」，应改为 **降级源包** 或 **GSI 路线**（见文末建议）。

---

## 1. Android 版本差距

| 侧 | Android | SDK | Build |
|----|---------|-----|-------|
| ZUI 系统 | 14 | 34 | UKQ1.230917.001 |
| ZUI vendor | **13** | **33** | TKQ1.230227.001 |
| HyperOS system/product | **17** | （SDK 37 级） | CP2A.260605.016 |
| HyperOS odm/system_dlkm | **15** | | AQ3A.250226.002 |

| 差距项 | 评估 |
|--------|------|
| 系统框架 | 14 → 17，**跨 3 个大版本** |
| API / 权限 / SELinux / init 语法 | 大量破坏性变更 |
| VNDK | ZUI vendor=33，product=34；HyperOS 仍带 `vndk.v34` APEX，但系统期望更新的 HAL 接口 |
| Treble | 两边都开了，但 Treble **不保证** 跨 3 个 Android 大版本仍兼容 |

**影响：** 即便强行塞入 system/product，system_server 与 ZUI vendor 的 HIDL/AIDL HAL、属性、SELinux 域会对不上，表现为开不了机或大面积功能崩溃。

---

## 2. GKI 内核兼容性（一票否决项）

| 侧 | 内核字符串 | GKI / KMI |
|----|------------|-----------|
| ZUI | `5.15.123-android13-8-00044-g5682afbff3e0-ab11501453` | **android13-5.15** |
| HyperOS | `6.6.118-android15-8-gc4127a25dcf3-ab15863337-4k` | **android15-6.6** |

| 检查项 | 结果 |
|--------|------|
| 主版本 | 5.15 vs 6.6，**不兼容** |
| KMI 年代 | android13 vs android15，**不兼容** |
| 模块 vermagic | HyperOS `system_dlkm` = `6.6.118-android15-8-...` |
| 能否用 ZUI 内核跑 HyperOS vendor 模块 | **否**（符号/CRC/vermagic 全不对） |
| 能否用 HyperOS 内核跑 ZUI vendor 模块 | **否**（同理；且设备树/固件绑 SM6225） |

GKI 的 KMI 稳定性只在同一 `androidXX-5.15` / `androidXX-6.6` 生成线内成立。  
**android13-5.15 与 android15-6.6 是两条内核产品线，不能混装模块。**

---

## 3. 架构 / SoC 差异

| 项 | TB331FC（ZUI） | yupei HyperOS |
|----|----------------|---------------|
| 平台代号 | **bengal**（SM6225，骁龙 685） | 较新一代高通（payload 含 aop/cpucp/shrm/soccp/pvmfw/uefi） |
| 定位 | 2022 中端平板 | 小米平板高端产品线（用户标注 6 Pro；codename **yupei**） |
| 显示 HAL | Adreno，`ro.vendor.display.cabl=2` | 对应另一 GPU/Display 栈 |
| 固件布局 | xbl/abl/tz/rpm/keymint + bengal 特有 | 多出 aop、cpucp、shrm、soccp、pvmfw 等 |

**影响：** bootloader / xbl / abl / tz / keymint / modem / dsp **绝不可**跨机互刷。  
vendor/odm 里的 `.so` HAL 与固件节点绑定该 SoC，放到 TB331FC 上无法工作。

---

## 4. vendor HAL 差异（显示 / 触摸 / 音频 / 传感器）

详见 `docs/vendor_diff.md`。摘要：

| 领域 | ZUI（必须保留） | HyperOS（不可直接用） | 移植结论 |
|------|-----------------|----------------------|----------|
| 显示 | Adreno + cabl，SM6225 display HAL | 另一 SoC 的 HWC/Composer | **保留 ZUI** |
| 触摸/手写笔 | NVT/ himax-stylus + Lenovo Tab Pen Plus | 小米笔/另一触控 IC | **保留 ZUI** |
| 音频 | Dolby DAX3 + 高通 audio HAL | 小米音频策略 / 可能无 DAX3 | **保留 ZUI**，需属性对齐 |
| 传感器 | SM6225 sensors HAL | 另一 SoC 传感器栈 | **保留 ZUI** |
| 相机 | 联想相机 blob | 小米相机（机型校验） | **保留 ZUI** + 换通用相机 |

**原则：硬件认底包（ZUI），UI 认源包（且源包需可被 ZUI vendor 驱动）。**

---

## 5. 空间硬约束

| 项 | 大小 |
|----|------|
| HyperOS 系统侧（system+product+system_ext+mi_ext+mi_product） | **≈ 9.26 GiB** |
| TB331FC `system_a` | **5.79 GiB** |
| TB331FC `super` | 12 GiB（已含 vendor/odm） |

HyperOS 的 **product 单独就 6.0 GiB**，已超过 TB331FC 整个 system 分区。  
不 debloat、不重划 super 的前提下，**镜像物理装不下**。

---

## 6. 综合判定

| 维度 | 评级 | 说明 |
|------|------|------|
| Android 版本差距 | ❌ | 14/13 → 17，跨 3 代 |
| GKI KMI | ❌ **否决** | android13-5.15 vs android15-6.6 |
| SoC / 固件 | ❌ **否决** | SM6225 vs 新一代高通 |
| vendor HAL | ❌ | 显示/触控/音频/传感器全不对 |
| 分区空间 | ❌ | 9.3 GiB > 5.79 GiB |
| Treble / GSI | ⚠️ 部分可行 | 设备已 Treble，适合 **GSI** 而非整包移植 |

### 结论

**不可行** —— 指「用 yupei HyperOS 4 的 system/product 直接替换，底包只留 ZUI boot/vendor」这条完整移植路径。

不推荐强行拼包的原因（按致命程度）：

1. **KMI 不兼容**：没有共同内核 ABI，模块与 HAL 无法共存。  
2. **SoC 不同**：vendor 与固件链不可互换。  
3. **空间不足**：系统侧超出 system_a。  
4. **API 跨 3 代**：即便前 3 条解决，框架与 vendor 接口仍会连锁崩。

---

## 7. 若要在 TB331FC 上得到 HyperOS：推荐替代路线

| 路线 | 做法 | 预期 | 难度 |
|------|------|------|------|
| **A. GSI（最推荐）** | ZUI 全底 + **HyperOS/AOSP GSI（arm64-ab）** 替换 system | 有 HyperOS/类原生体验，硬件由 ZUI vendor 驱动 | 中 |
| **B. 降级源包** | 找 **HyperOS 1.0 / Android 13–14** 平板包，与 ZUI KMI 同代再拼 | 兼容性最好 | 中高 |
| **C. 既有验证包** | 酷安 weiPluto **HyperOS 2.0 TB331FC 专包**（已内置 KSU + 原厂镜像） | 已有可刷产物 | 低 |
| **D. 完整移植 yupei A17** | 本报告路径 | **不可行** | — |

### 对路线 A 的补充

- TB331FC `ro.treble.enabled=true`，A/B + GKI 5.15，符合 GSI 画像。  
- 仍须：`fastboot -w`、用 ZUI 的 boot/vendor_boot/vendor/odm、关 AVB 验证。  
- 手写笔/相机/杜比等仍靠 ZUI vendor + 属性/脚本修补（见既有 `_boot_fix` 经验）。

---

## 8. 未执行项声明

- 未对任何设备执行 `fastboot flash` / 分区写入。  
- 未修改原刷机包 `E:\类\刷机\**`。  
- 解包输出均在 `E:\rom\port\hyperos\work\`。

---

## 9. 证据索引

| 证据 | 位置 |
|------|------|
| ZUI 内核 banner | `work/zui_boot/kernel` → `5.15.123-android13-...` |
| HyperOS 内核 banner | `work/hyperos_extract/kernel` → `6.6.118-android15-...` |
| ZUI 属性 | super 扫描，见 `docs/zui_structure.md` |
| HyperOS 指纹 | `care_map.pb` / `payload_properties.txt` |
| HyperOS 分区表 | `payload-dumper-go -l`，见 `docs/hyperos_structure.md` |
| ZUI 分区表 | `partition.xml` |
