# vendor 合并补丁清单（TB331FC × HyperOS）

> **日期**：2026-10
> **配套文档**：`移植可行性报告.md`
> **前提声明**：见下。

---

## 0. 触发条件说明（重要）

任务要求「**如果可行**，再输出《vendor 合并补丁清单》」。

`移植可行性报告.md` 的结论是 **不可行**（GKI/KMI 跨代 + SoC 代际不同一票否决），
**因此「从 yupei 向 ZUI vendor 做合并」这一动作本身不成立** ——
不存在「需要从 yupei vendor 取哪些文件补进 ZUI vendor」的场景，因为
`yupei` 的 vendor/odm/vendor_dlkm 与 TB331FC 的硬件**没有任何一层可以互换**（报告 §6.6）。

本文档因此改为输出三份**真正可执行**的清单：

| 清单 | 适用场景 | 现在能否执行 |
|------|----------|--------------|
| **A. ZUI 资产白名单（绝对不可被覆盖）** | 任何路线 | ✅ 立即适用 |
| **B. GSI 路线下的 vendor 侧补丁点** | 走报告 §9 路线 A | ✅ 立即适用 |
| **C. 同代源包降级后的 vendor 合并点（预研）** | 若将来找到 `android13-5.15` 同代平板包 | ⏳ 条件性 |

**明确不做的事**：不从 `yupei` 的 `vendor` / `odm` / `vendor_dlkm` / `system_dlkm` / 任何固件分区
取任何一个文件。

---

## A. ZUI 资产白名单（绝对不可被覆盖）

以下资产**在任何路线下都不得被源包覆盖**，否则轻则驱动全失、重则变砖。

### A.1 固件链（跨机刷写 = 必砖）

```
xbl.img / xbl.elf            xbl_config.elf        xbl_ramdump
abl.elf                      tz.mbn                hyp.mbn
rpm.mbn                      keymint.mbn           devcfg.mbn
featenabler.mbn              imagefv.elf           uefi_sec.mbn
qupv3fw.elf (qupfw)          cmnlib / cmnlib64     storsec.mbn
multi_image.mbn              sec.elf               apdp.mbn
NON-HLOS.bin (modem)         BTFM.bin (bluetooth)  dspso.bin (dsp)
logfs_ufs_8mb.bin            gpt_main*.bin         gpt_backup*.bin
```

> `abl` / `xbl` 为 **Critical Partition**，fastboot 通常禁止刷写；跨机刷 = 9008 救砖。

### A.2 启动链（绑 SM6225 与面板）

```
boot.img          # 内核 5.15.123-android13-8，KMI android13-5.15
init_boot.img     # GKI ramdisk
vendor_boot.img   # vendor ramdisk + cmdline（触控/面板参数在此）
dtbo.img          # 设备树 overlay，绑 bengal
vbmeta.img / vbmeta_system.img
recovery.img      # 底包链；实验可用 TB331FC 专用 OrangeFox
```

### A.3 super 内必须保留的逻辑分区

```
vendor_a         649.71 MiB   ← 四大硬件栈 HAL 全在这里
odm_a              1.35 MiB
vendor_dlkm_a     56.20 MiB
system_dlkm_a    428.00 KiB
```

### A.4 vendor 内逐目录保留清单（A.3 的展开）

来源：`work/zui_trees/vendor_a.list.txt`（EXT4 递归解析，3,200 条目）。

**显示栈**

```
/bin/hw/vendor.qti.hardware.display.composer-service
/bin/hw/vendor.qti.hardware.display.allocator-service
/bin/hw/vendor.display.color@1.0-service
/bin/hw/vendor.lenovo.hardware.display-service
/lib/hw/android.hardware.graphics.mapper@4.0-impl-qti-display.so
/lib/hw/gralloc.default.so
/lib/hw/vulkan.adreno.so
/lib/egl/libEGL_adreno.so  lib/egl/libGLESv2_adreno.so  lib/egl/libq3dtools_adreno.so
/lib/libdisplayconfig.qti.so  lib/libdisplayqos.so  lib/libdisplaydebug.so
/lib/libadreno_utils.so  lib/libadreno_app_profiles.so
/etc/display/**            /etc/vintf/manifest/vendor.qti.hardware.display.*.xml
/etc/vintf/manifest/vendor.lenovo.hardware.display-service.xml
/etc/init/init.qti.display_boot.rc  /bin/init.qti.display_boot.sh
```
关键属性：`ro.vendor.display.cabl=2`、`persist.sys.open.cabl=on`、
`ro.surface_flinger.has_HDR_display=true`、`has_wide_color_display=true`

**触摸 / 手写笔栈（最高优先级，丢了就没笔）**

```
/bin/hw/vendor.lenovo.hardware.touchscreen-service
/bin/hw/motorola.hardware.input@1.1-service
/lib64/vendor.lenovo.hardware.touchscreen-V1-ndk.so
/lib64/motorola.hardware.input@1.1.so   lib64/motorola.hardware.input@1.0.so
/lib/libTrustedInput.so   lib/libTrustedInputTZ.so   lib/libTouchInputVM.so
/firmware/Himax_firmware.bin            ← 触控 IC 固件
/firmware/Himax_mpfw.bin
/etc/excluded-input-devices.xml
/etc/vintf/manifest/vendor.lenovo.hardware.touchscreen-service.xml
/etc/vintf/manifest/motorola.hardware.input@1.1-service.xml
```
关键属性（**必须逐条保留**）：
```
ro.vendor.config.lgsi.pen.event.name = himax-stylus
ro.vendor.config.lgsi.pen_info = 0x617F:0x17EF:Lenovo Tab Pen Plus
ro.vendor.config.lgsi.pen.bluetooth_key.support = 1
```

**音频栈**

```
/bin/hw/android.hardware.audio.service_64
/bin/hw/vendor.dolby.hardware.dms@2.0-service
/bin/hw/vendor.dolby.media.c2@1.0-service
/bin/hw/vendor.qti.media.c2audio@1.0-service
/bin/audioadsprpcd   bin/audioflacapp
/lib64/hw/audio.primary.bengal.so          ← 注意 bengal 后缀
/lib64/hw/audio.usb.bengal.so
/lib64/hw/sound_trigger.primary.bengal.so
/lib64/hw/android.hardware.audio@2.0/4.0/5.0/6.0/7.0-impl.so
/lib64/hw/android.hardware.audio.effect@*.so
/etc/acdbdata/**            ← ACDB 校准（per-SoC，绝不可换）
/etc/audio/**   /etc/audio_effects.xml   /etc/audio_policy_volumes.xml
/etc/dolby/**
/etc/audio_cal.wav
```
关键属性：`ro.vendor.dolby.dax.version=DAX3_3.8.5.20_r1`、
`ro.vendor.audio.sdk.fluencetype=none`、`vendor.audio.*`（60+ 项）

**传感器栈**

```
/bin/hw/android.hardware.sensors@2.1-service.multihal
/bin/hw/vendor.qti.hardware.sensorscalibrate@1.0-service
/bin/sensors.qti   bin/init.qcom.sensors.sh
/etc/sensors/**     ← bengal_lsm6dso_0.json / bengal_ak991x_0.json /
                       bengal_bmp285_0.json / bengal_tmd2725.json /
                       bengal_aw9610x_0.json / bengal_default_sensors.json …
/etc/init/vendor.sensors.qti.rc   vendor.sensors.sscrpcd.rc
/etc/permissions/android.hardware.sensor.*.xml
```
关键属性：`persist.vendor.sensors.*`（`support_direct_channel=false`、
`enable.rt_task=false`、`hal_trigger_ssr=false` …）

**相机栈**

```
/bin/hw/android.hardware.camera.provider@2.4-service_64
/lib64/hw/camera.qcom.so   lib64/hw/com.qti.chi.override.so
/lib/camera/com.qti.sensor.elm_lce_s5k4h7_front_ii.so
/lib/camera/com.qti.sensor.elm_lce_s5k4h7_rear_i.so
/lib/camera/com.qti.sensor.elm_sunwin_sc820cs_rear_ii.so
/lib/camera/com.qti.eeprom.*.so   lib/camera/com.qti.flash.lm3644.so
/etc/camera/camxoverridesettings.txt
```

**平台 / 安全 / 其它**

```
/lib64/hw/vendor.qti.hardware.qseecom@1.0-impl.so
/bin/hw/vendor.qti.hardware.secureprocessor@1.0
/bin/hw/android.hardware.security.keymint-service-qti
/bin/hw/vendor.qti.hardware.keymaster@4.0-service-qti   (如有)
/bin/hw/android.hardware.gatekeeper@1.0-service-qti
/etc/vintf/**               ← 整体保留，只做「追加」不做「替换」
/etc/selinux/**             ← precompiled_sepolicy 系列
/build.prop                 ← 只做追加，不做替换
```

### A.5 不要动的物理分区

```
persist / metadata / lenovocust / lenovoraw / lenovolock / oemowninfo / frp / ssd / keystore
```

---

## B. GSI 路线下的 vendor 侧补丁点（当前可执行）

对应报告 §9 路线 A：**ZUI 全底 + 通用 system（GSI）**。此时 vendor 侧只做「兼容性追加」，
**不做任何文件替换**。

| 优先级 | 对象 | 动作 | 说明 |
|--------|------|------|------|
| P0 | `vbmeta.img` / `vbmeta_system.img` | 关闭验证：`--disable-verity --disable-verification`，或刷 flags=2 的 vbmeta | GSI 与 ZUI boot 签名不同 |
| P0 | `vendor/build.prop` | **仅追加**：把 GSI 需要的属性补上，不删原有项 | 例如 `ro.vndk.version`、`ro.treble.enabled` 保持 |
| P0 | `vendor/etc/vintf/manifest.xml` | **仅追加**框架所需的 HAL 声明 | 不要替换整个 manifest |
| P0 | `/system/etc/init/*.rc` 与 GSI 的 `.rc` | 用 `_boot_fix` 思路修补 first-stage init | 保留 ZUI 的 `init.qti.display_boot` / `sensors` / `touch` |
| P1 | `vendor/etc/selinux/**` | 以 ZUI 为底，用 `magiskpolicy` / `sepolicy.rule` 按需放行 | 不重编 precompiled_sepolicy |
| P1 | `product/etc/device_features/TB331FC.xml` | **必须新建/注入** | 通信共享、平板形态、笔等开关 |
| P1 | 手写笔 | 确认 `ro.vendor.config.lgsi.pen_info` 与 `himax-stylus` 在 GSI 下仍被读到 | 丢了笔就回退属性修补 |
| P2 | 相机 | GSI 自带相机 App 通常不可用 → 换通用相机 App | 不移植小米相机 |
| P2 | 音频 | 确认 `DAX3` 服务被拉起；必要时补 `libmisoundfx` 类桥接库 | 杜比不生效通常是属性/服务未起 |

**验证顺序**（每步只前进一步）：能开机 → 显示正常 → 触摸正常 → 音频出声 → 传感器 → 笔 → 相机。

---

## C. 同代源包降级后的 vendor 合并点（预研，暂不可执行）

> **前置条件**：找到一份与 TB331FC **同为 `android13-5.15` KMI、Android 13–14 世代**的
> 小米/联想平板包（例如 HyperOS 1.x 平板包）。**当前素材 `yupei`（A17 / android15-6.6）不满足。**
> 在条件满足前，本节**不作为执行依据**。

假设条件满足，合并时的关注点：

| 优先级 | 路径 / 对象 | 动作 | 理由 |
|--------|-------------|------|------|
| P0 | `vendor/lib64/hw/**`、`vendor/bin/hw/**` | **全部保留 ZUI** | 显示/触摸/音频/传感器 HAL 绑 `bengal` |
| P0 | `vendor/etc/acdbdata/**` | **全部保留 ZUI** | ACDB 是 per-SoC + per-主板校准 |
| P0 | `vendor/etc/sensors/config/**` | **全部保留 ZUI** | 器件级 JSON 配置 |
| P0 | `vendor/firmware/**`（`Himax_*.bin`） | **全部保留 ZUI** | 触控 IC 固件 |
| P0 | `vendor/build.prop`、`odm/build.prop` | 保留 ZUI，仅**追加**兼容属性 | 属性是硬件描述，跨机即错 |
| P0 | `vendor/etc/vintf/manifest.xml` 及其分片 | 保留 ZUI，仅**追加**源包需要的 framework HAL 声明 | VINTF 声明与本地实现必须一致 |
| P1 | `vendor/etc/selinux/**` | 以 ZUI 为底，按需 `magiskpolicy` 放行 | 系统侧新增域需要额外允许 |
| P1 | `odm/etc/**`（笔相关） | 保留 ZUI，仅补 `device_features` 开关 | Lenovo Pen Plus vs 小米笔协议不同 |
| P2 | `product/etc/device_features/<device>.xml` | **必须新建**（以 ZUI/联想特性为底） | 平板形态、手写笔、通信共享开关 |
| P2 | `/vendor/lib64/libqti*`、`libdisplay*` 等平台库 | 全部保留 ZUI | 编译期绑 SoC |
| ❌ | `vendor/lib/modules/**`、`vendor_dlkm/**`、`system_dlkm/**` | **禁止混用** | 必须与内核 vermagic 完全一致 |
| ❌ | `vendor/bin/hw/android.hardware.*-service` | **禁止替换** | 服务二进制与内核/HAL 接口版本绑定 |

**合并后的自检清单**

```
[ ] 内核 vermagic 与所有 .ko 的 vermagic 一致
[ ] /vendor/etc/vintf/manifest.xml 中每个 HAL 都有本地实现（vintf 校验通过）
[ ] ro.vendor.build.fingerprint 保持 ZUI（或按需改写但字段完整）
[ ] 手写笔：getevent 能看到 himax-stylus 事件
[ ] 音频：DAX3 服务已启动，ACDB 未被替换
[ ] 传感器：sensors.qti 起来，全部 sensor 可枚举
[ ] 显示：HWC 使用 2.x composer（与 ZUI 一致）
```

---

## D. 明确「不要引入」的清单（来自 yupei）

```
vendor/**                 odm/**
vendor_dlkm/**            system_dlkm/**
boot / init_boot / vendor_boot / dtbo / recovery
vbmeta / vbmeta_system
xbl* abl* tz hyp rpm keymint modem(NON-HLOS) dsp bluetooth(BTFM)
aop aop_config cpucp cpucp_dtb shrm soccp_dcd soccp_debug pvmfw uefi
uefisecapp qupfw devcfg featenabler imagefw idmanager multiimgqti spuservice
vm-bootsys countrycode
```

**理由**：以上全部属于「另一颗 SoC（Oryon 世代）的硬件描述与固件链」，
与 TB331FC（`bengal` / SM6225）无一可互换；混入即出现「开不了机 / 黑屏 / 无触摸」。

---

## E. 执行前置条件（不可跳过）

1. 任何分区写入前，**必须**先完成 `boot / init_boot / vendor_boot / dtbo / vbmeta / vbmeta_system /
   recovery / super 内全部分区 / persist / lenovocust` 的**完整备份**（`scripts/backup_partitions.ps1`）。
2. 确认设备当前 slot、`unlocked` 状态、9008 可用性。
3. **本清单不构成刷机指令**。执行前需逐条确认。

---

*本清单为分析产物，不含任何 fastboot 写入命令。*
