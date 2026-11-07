# 不关 AVB 的移植 / 刷机 / 恢复方案

> 约束：**不能关 AVB**（不刷 flags=3 的 vbmeta）  
> 设备：TB331FC · 目标：HyperOS/GSI 移植、TWRP、刷 system

---

## 一、先分清三条路

| 路线 | AVB | 产物 | 难度 |
|------|-----|------|------|
| **A. 保持 AVB，重签链路** | 开（自定义 root of trust） | avbroot 式 OTA / 签名 boot·recovery | 高，需 `avb_custom_key` |
| **B. 只刷「过校验」的分区** | 开 | 用 fastbootd 刷 **已按原厂 AVB 描述符对齐** 的镜像，或只动不校验的分区 | 中 |
| **C. 放弃 TWRP，只用 fastbootd + 9008** | 开 | 教程 + system 线刷，不改 recovery | **低，推荐** |

官方 TWRP 对本机 README 写明：**必须关 AVB** 才能进第三方 recovery。  
因此：**AVB 不能关 ⇒ 默认放弃「原版 TWRP 直接 flash」。**

---

## 二、路线 A：avbroot（保留校验、自定义密钥）

**项目：** https://github.com/chenxiaolong/avbroot （964★）

| 能力 | 说明 |
|------|------|
| 改 A/B OTA | 改 boot/recovery/system 后 **重签** |
| 保留 AVB | 用 **自己的 AVB 公钥** 替换 bootloader 信任根 |
| 命令 | `fastboot flash avb_custom_key <pubkey>` |
| 后续 | 可锁 BL（有条件）、recovery 可侧载签名 OTA |

### 前提（缺一不可）

1. 设备支持 **`avb_custom_key`**（见 avbroot issue #299 机型表）  
2. 会生成/导入密钥；明白 **硬砖风险**（作者反复警告）  
3. TB331FC / 联想 **未必** 在支持列表 → **需实测** `fastboot getvar` / 尝试 `flash avb_custom_key`

### 与 TWRP

- 不是「随便刷 recovery.img」  
- 要 **重新 pack 并签名 recovery**（`avbroot avb pack` + 私钥）  
- 之后 bootloader 用 **你写的 avb_custom_key** 校验  

### 适用

- 想 **锁 BL / 过部分检测**  
- 愿意维护密钥与签名流水线  

---

## 三、路线 B：不改信任根，只动「能过校验」的层面

| 做法 | 说明 | 可行性 |
|------|------|--------|
| **只用 fastbootd 刷 system** | super 内逻辑分区；**vbmeta_system** 仍可能校验 system | 视 GSI/镜像是否带正确 AVB footer |
| **打包时补 AVB footer** | HyperOS-Port-Python 支持「**自定义 AVB 链 / 从 stock vbmeta 重建拓扑**」 | ✅ 工具链支持 |
| **avbtool 更新 Hash 描述符** | 把 recovery/system 的 digest 写回 vbmeta（不关验证） | ⚠️ 要会 avbtool，易配错 |
| **GSI 标准做法** | 很多 GSI 默认 `--disable-verification` | 与你约束冲突 |

### HyperOS-Port-Python 的 AVB 能力（重点）

仓库：`toraidl/HyperOS-Port-Python` / Windows 分支 `Z-Fovik-RT/HyperOS4.0-Port-Windows-Python`

- 禁用 AVB（你不需要）  
- **重建 AVB 拓扑**：以 stock `vbmeta` / `vbmeta_system` 为模板，为目标镜像补 footer、重算并 **保持链路校验**  
- 对非动态分区做尺寸保护  

→ **这是「不关 AVB 做 HyperOS 移植」的最现实工具路线。**

### 步骤草案（HyperOS + 保留 AVB）

```text
1. 保留 ZUI: boot / vendor_boot / vbmeta（原厂）
2. 用移植工具处理源包 system/product/system_ext
3. 打开「重建 AVB / 对齐 stock vbmeta」选项（不要 disable-verification）
4. 产出 payload / super
5. fastbootd 刷入
6. 不刷第三方 recovery；用原厂 recovery + fastbootd
```

---

## 四、路线 C：不碰 TWRP（推荐给日常发布）

```text
AVB 原厂不动
recovery 原厂不动
刷机 = fastbootd flash system / super
救砖 = 9008 + ZUI 线刷
```

| 优点 | 缺点 |
|------|------|
| 不引入 AVB/recovery 砖机 | 没有 TWRP 备份 GUI |
| 与作者 GSI 套件同思路 | 跨 ROM 备份要靠 dd/线刷 |
| 发布投诉少 | 高级玩法受限 |

**备份替代：**  
`adb shell dd` 关键分区 / 9008 全包 / fastboot 拉分区（若 BL 允许）。

---

## 五、TWRP 在「不关 AVB」下还剩什么

| 方式 | 说明 |
|------|------|
| ❌ 直接 `flash recovery.img` | 必被 Hash 拒 |
| ❌ `fastboot boot recovery.img` | 本机 BL **不支持** |
| ⚠️ avbroot 签名 recovery + avb_custom_key | 仅当 BL 支持自定义信任根 |
| ✅ **原厂 recovery** | 保留官方；够格式化/部分救砖 |
| ✅ **fastbootd**（系统内或原厂 recovery 菜单） | 刷逻辑分区 |

**结论：不关 AVB ⇒ 基本放弃 TWRP；发布包写清楚即可。**

---

## 六、给 TB331FC 的建议落地顺序

1. **发布/日用：路线 C**（fastbootd + ZUI 回滚）  
2. **要更完整 HyperOS：** 用 HyperOS-Port-Python **重建 AVB 链**（路线 B）  
3. **要 TWRP/锁 BL：** 实测 `fastboot flash avb_custom_key`，再考虑 avbroot（路线 A）  
4. **不要**再刷「关 AVB 的 vbmeta」——与你的约束冲突，且曾与 900E 风险叠加  

---

## 七、实测清单（有设备时）

```bat
fastboot getvar unlocked
fastboot getvar is-userspace
:: 若存在则支持自定义信任根（需文档/机型确认）
fastboot getvar partition-size:avb_custom_key
```

- `avb_custom_key` 不存在 → 只能 B/C  
- 存在 → 可评估 avbroot  

---

## 八、资料链接

| 资源 | 链接 |
|------|------|
| avbroot | https://github.com/chenxiaolong/avbroot |
| avbroot 支持机型 issue | https://github.com/chenxiaolong/avbroot/issues/299 |
| HyperOS 移植（AVB 重建） | https://github.com/toraidl/HyperOS-Port-Python |
| HyperOS4 Windows 移植 | https://github.com/Z-Fovik-RT/HyperOS4.0-Port-Windows-Python |
| 联想平板 A16 GSI（官方 recovery 思路） | https://github.com/Simon0Harms/Lenovo-Tab-P11-5G-TB-J607Z-Android-16-GSI-Guide |
