# 体积报告 · A 档拼包结果

> 日期：2026-09-29 · 路线：ZUI 原厂内核 + HyperOS 系统侧
> 状态：**A 档达标**（未执行任何刷写）

---

## 1. 目标与结果

| 档位 | 目标 | 结果 |
|------|------|------|
| **A（理想）** | **< 4.5 GiB**，直接刷 system_a | ✅ **2.99 GiB / 3059 MB** |
| B（极限） | 4.5–5.5 GiB，需 `resize-logical-partition` | 未触发 |

**结论：优先 A 档已达成，无需扩容分区。**

产物：`E:\rom\port\hyperos\out\system_a_hyperos4_A.img`  
EROFS · lz4hc · 压缩率 67.6% · 9320 文件

---

## 2. Debloat 过程（product 优先）

| 阶段 | product 解包树 |
|------|----------------|
| 初始 | **6090.6 MB** |
| 砍后 | **2484.2 MB** |
| 释放 | **3606.4 MB** |

### 已删除（按体积）

**data-app（主战场，约 2.3 GB）**  
CadLauncher 319 · WpsLauncher 261 · MiShop 211 · MiMediaEditor 208 · CAJLauncher 176 · MIUIMusicPAD 122 · Creation 117 · SmartHome 99 · MIUIVideoPad 93 · BaiduIME 82 · MIpayPad 81 · MiuiScanner 79 · MIUIGameCenterPad 61 · MIUIWeather 60 · iFlytekIME 57 · MIUIDuokanReaderPad 54 · 以及 VIP/换机/遥控/小爱引擎/清理等

**priv-app**  
MIUIBrowserPad 125 · MIUIAICR 87 · MIUIFindDeviceCN 86 · MiuiCamera 79 · MIUIAod 50 · 游戏中心/小游戏 65 · GmsCore 29 · Backup 27 · 负一屏 23 · MirrorOS4 22 · 黄页/云备份/弹幕等

**app**  
talkback 52 · HybridPlatform 55 · AiasstVision 47 · VoiceTrigger 42 · 应用商店 39 · PaymentService 25 · 统计/日志/CIT/运营商 等

**media**  
AI 壁纸 55 · yupei 壁纸 65 · os4_fonts 93 · 大主题 20

### 保留（开机/核心）

MiuiHome · MISettings · SystemUI 相关 · FileExplorer · 输入法 SogouIME · 相册/笔记/时钟/日历/计算器 · 账号/云同步核心 · MiSound · WebViewGoogle64 · TB331FC.xml 已注入 `product/etc/device_features/`

---

## 3. 合并树体积 → 镜像

| 树 | 解包 MB |
|----|---------|
| system | 1052 |
| system_ext | 985 |
| product（debloat 后） | 2484 |
| **合计（不含 mi_ext）** | **4520.5** |
| EROFS 打包后 | **3059.1 MB（2.99 GiB）** |

未纳入 mi_ext（448 MB）；若要 HyperOS 小米扩展可 `-IncludeMiExt`，预计再增约 250–300 MB 打包体积，仍可能低于 4.5 GiB。

---

## 4. 分区对照

| 项 | 值 |
|----|-----|
| TB331FC `system_a` | 5.79 GiB |
| 本次 A 档镜像 | **2.99 GiB** |
| 余量 | ≈ **2.8 GiB**（可回加部分应用） |
| 是否需要 `resize-logical-partition` | **否** |

---

## 5. 文件

| 路径 | 说明 |
|------|------|
| `out/system_a_hyperos4_A.img` | 可刷产物（**待确认再刷**） |
| `scripts/debloat_product.ps1` | 精简脚本 |
| `scripts/pack_system_a.ps1` | 打包脚本 |
| `out/MD5SUMS.txt` | 校验 |

---

## 6. 下一步（禁止自动刷写）

1. 你确认镜像与 debloat 清单  
2. （可选）回加应用 / 加 mi_ext / 注入 `_boot_fix` 补丁  
3. 出刷写脚本（只 `flash system`，保留 boot/vendor）  
4. **等你明确说「可以刷」再动分区**
