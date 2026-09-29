# vendor 差异清单（HyperOS yupei vs ZUI TB331FC）

> 日期：2026-09-29 · 只读对比
> 原则：**硬件认底包（ZUI），UI/框架可换；vendor/odm/固件默认全部保留 ZUI。**

---

## 1. 总原则

| 分区 | 策略 | 原因 |
|------|------|------|
| boot / init_boot / vendor_boot / dtbo | **必须 ZUI** | 内核 + 设备树 + vendor ramdisk 绑 SM6225 |
| vbmeta | ZUI（或 disable 验证） | AVB 链 |
| vendor / vendor_dlkm | **必须 ZUI** | HAL、传感器、触控、音频、显示驱动 |
| odm / odm_dlkm | **必须 ZUI** | ODM 定制、笔、面板 |
| system / system_ext / product | 可考虑源包（需降级或 GSI） | 框架与应用 |
| mi_ext / mi_product | 谨慎，可选 debloat 后引入 | 小米扩展 |
| xbl/abl/tz/rpm/keymint/modem/dsp/hyp/… | **必须 ZUI** |  bootloader 与安全固件，跨机必砖 |

---

## 2. 分区体积对照

| 分区 | ZUI TB331FC | HyperOS yupei | 可否替换 |
|------|-------------|---------------|----------|
| vendor | 在 super 内（较小，bengal） | **1.6 GiB** | ❌ 禁止换成 HyperOS |
| odm | 在 super 内 | **1.5 GiB** | ❌ 禁止 |
| vendor_dlkm | 有 | 58 MiB（6.6 模块） | ❌ KMI 不同 |
| system_dlkm | 有 | 15 MiB（6.6 模块） | ❌ KMI 不同 |
| system | ~2 GiB 级 | 978 MiB | ⚠️ 需同代/GSI |
| product | 同 system 挂载拓扑 | **6.0 GiB** | ⚠️ 体积超限 |
| system_ext | 有 | 824 MiB | ⚠️ 同上 |
| mi_ext | 无 | 456 MiB | 可选 |

---

## 3. 关键 HAL / 驱动对照

### 3.1 显示（Display / HWC / GPU）

| 项 | ZUI（保留） | HyperOS（不用） |
|----|-------------|-----------------|
| GPU | Adreno（`ro.hardware.egl=adreno`） | 另一 Adreno 代际 |
| HWC / Composer | SM6225 display HAL | 对应新 SoC |
| 色彩/亮度 | `ro.vendor.display.cabl=2` | 小米显示扩展 |
| 结论 | **全部保留 ZUI vendor 显示栈** | 不移植 |

### 3.2 触摸 / 手写笔

| 项 | ZUI（保留） | HyperOS（不用） |
|----|-------------|-----------------|
| 触控 | TB331FC 原厂（含 NVT 系） | 小米平板触控 |
| 手写笔 | `himax-stylus`，Lenovo Tab Pen Plus（`0x617F:0x17EF`） | 澎湃笔/其它 IC |
| 固件/配置 | vendor_boot + odm | — |
| 结论 | **必须 ZUI**；笔压感靠既有 penfix 路线 | 不移植 |

### 3.3 音频

| 项 | ZUI（保留） | HyperOS（不用） |
|----|-------------|-----------------|
| HAL | 高通 audio（fluencetype=none） | 小米音频策略 |
| 音效 | **Dolby DAX3** `DAX3_3.8.5.20_r1` | MiSound 等 |
| 已知坑 | `ro.vendor.audio.dolby.dax.support` 等属性需对齐 | 缺 libmisoundfx 会崩 |
| 结论 | **保留 ZUI 音频 HAL + DAX3**；上层音效应用可换 | 不整包替换 |

### 3.4 传感器

| 项 | ZUI（保留） | HyperOS（不用） |
|----|-------------|-----------------|
| sensors HAL | SM6225 / bengal | 另一 SoC |
| 结论 | **保留 ZUI** | 不移植 |

### 3.5 相机

| 项 | ZUI（保留） | HyperOS（不用） |
|----|-------------|-----------------|
| 相机 HAL/blob | 联想相机 | 小米相机（多处机型校验） |
| 结论 | **保留 ZUI**；应用层可用 Aperture 等通用相机 | MiuiCamera 不建议 |

---

## 4. 「必须保留 ZUI」清单

```
boot.img
init_boot.img
vendor_boot.img
dtbo.img
vbmeta.img / vbmeta_system.img
recovery.img          # 实验可用 OrangeFox，但底包 recovery 仍算 ZUI 链
super 内：vendor_a / vendor_dlkm_a / odm_a / odm_dlkm_a
固件：xbl* abl* tz hyp rpm keymint(mbn) modem(NON-HLOS) bluetooth(BTFM) dsp
      devcfg featenabler imagefv uefi_sec qupfw cmnlib* multiimg* storsec …
lenovocust / lenovoraw / oemowninfo / persist   # 不要动
```

## 5. 「可从 HyperOS 引入」清单（仅在可行前提下）

> 本报告判定完整移植不可行；下列仅针对「降级源包」或「GSI」成功后的框架层。

```
system/**           # 框架（需与 ZUI vendor 同代或走 GSI）
system_ext/**
product/**          # 必须 debloat，目标 ≤ 3.5–4 GiB
mi_ext/**           # 可选
mi_product/**       # 可选
```

**明确不要引入：**  
`vendor/**`、`odm/**`、`vendor_dlkm/**`、`system_dlkm/**`、`boot`、`init_boot`、`vendor_boot`、`dtbo`、一切 xbl/abl/tz/modem/dsp/aop/cpucp/shrm/soccp/pvmfw。

---

## 6. 若走「vendor 合并」时的补丁关注点（预研，非执行）

> 因 KMI/SoC 否决，**不建议**对 yupei vendor 做合并。  
> 若未来源包降级到与 ZUI 同代（android13-5.15 / Android 13–14），再考虑：

| 优先级 | 路径/对象 | 动作 |
|--------|-----------|------|
| P0 | `vendor/etc/vintf/**` | 保留 ZUI manifest，只补 system 需要的 framework HAL 声明 |
| P0 | `vendor/build.prop` / `odm/build.prop` | 保留 ZUI，仅追加兼容属性 |
| P0 | `vendor/lib64/hw/audio*` / dolby | 保留 ZUI |
| P0 | `vendor/lib64/hw/sensors*` / display | 保留 ZUI |
| P1 | `odm/etc/pen*` / himax | 保留 ZUI |
| P1 | `vendor/etc/selinux/**` | 以 ZUI 为底，按需 `magiskpolicy` 修补 |
| P2 | `product/etc/device_features/TB331FC.xml` | **必须新建**（通信共享等） |

---

## 7. 结论

- **vendor 100% 用 ZUI，HyperOS 的 vendor/odm/固件全部丢弃。**  
- 显示、触摸、音频、传感器四大硬件栈均不可从 yupei 移植。  
- 在当前 yupei A17 / android15-6.6 前提下，**不存在可合并的 vendor 补丁清单**；替代路线见 `feasibility_report.md` §7。
