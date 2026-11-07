# TB331FC 救砖速查卡（900E / 刷错 system 后恢复）

> **用途**：刷入非原厂 system（A17 三镜像、GSI 等）后设备掉进 **900E** 或无法开机时，按本卡恢复原厂可开机状态。
> **验证次数**：3 次实测成功（2026-10-17 T7、2026-10-17 T8、2026-10-18 15:24–15:31）。
> **结论先行**：**不需要 QFIL，不需要 9008，不需要 TWRP**。只要设备还能回到 bootloader fastboot 或自行走到 fastbootd，就能纯 fastboot 恢复。
> 详细实验记录见 `E:\rom\docs\实验记录_A17三镜像干净刷入_2026-10-18.md` §5。

---

## 0. 一分钟判断：现在是什么状态

| 现象 | 判定 | 该做什么 |
|---|---|---|
| `Get-PnpDevice` 出现 `Qualcomm HS-USB Diagnostics 900E (COM6)`，`USB\VID_05C6&PID_900E\...` | **900E** = Sahara 崩溃转储模式 | **什么都别做，等 3–7 分钟**（见 §1） |
| `fastboot devices` 有序列号，`fastboot getvar is-userspace` = **no** | bootloader fastboot | 直接进 §3 |
| `fastboot devices` 有序列号，`fastboot getvar is-userspace` = **yes** | fastbootd（userspace） | 直接进 §2 或 §3 |
| `adb devices` 有序列号，`sys.boot_completed` = 1 | 已恢复，正常开机 | 收工 |
| 设备黑屏、无 USB 枚举 | 可能真砖 | 见 §6 |

---

## 1. 900E：什么都别做，等

**900E ≠ 9008。** 900E 是 **Sahara 崩溃转储模式**（`mode=02` memory dump），不是 EDL 刷机模式：

- firehose / QFIL / `fh_loader.exe` / `QSaharaServer.exe` **全部接不进去**（实测全部超时）。
- 设备会**自行退出** 900E，约 **3–7 分钟**后回到 **bootloader fastboot**（实测 15:14:41 reboot → 15:21:47 自行回到 fastboot，约 7 分钟）。
- 900E 枚举是**间歇性**的（实测 15:17:51 在、15:18:15 无、15:19:13 又在、15:19:48 消失）⇒ **必须连续轮询**，不能凭单次 `Get-PnpDevice` 判定"没了"。

轮询命令（PowerShell，每 15 s 一次）：

```powershell
while ($true) {
  $d = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
       Where-Object { $_.InstanceId -like "*VID_05C6&PID_900E*" }
  $f = & C:\platform-tools\platform-tools\fastboot.exe devices
  "{0}  900E={1}  fastboot={2}" -f (Get-Date -Format HH:mm:ss), [bool]$d, ($f -join ' ')
  if ($f) { break }
  Start-Sleep -Seconds 15
}
```

**唯一需要物理干预的情况**：设备一直卡在 900E 超过 **10 分钟**不退出。此时**完全关机**（长按电源 15 s 以上），再按 §6 走。

---

## 2. 进入 fastbootd（准备改逻辑分区）

> ⚠️ **`fastboot reboot fastboot` 在 system 不可启动时一定失败**：
> `fastboot: error: Failed to boot into userspace fastboot; one or more components might be unbootable.`
> 这是**正常现象**，不代表设备坏了——fastbootd 本身就跑在 system 里，system 起不来自然进不去。

**正确做法：等设备自己走到 fastbootd。** 实测在 900E 自行退出后约 2 分钟，`fastboot getvar is-userspace` 就变成 `yes`。

```powershell
$fb = "C:\platform-tools\platform-tools\fastboot.exe"
& $fb devices
& $fb getvar is-userspace   # 要 yes 才能做 resize / flash logical partition
& $fb getvar current-slot   # 应为 a
```

如果设备停在 bootloader fastboot（`is-userspace: no`），再试一次 `fastboot reboot fastboot`；仍失败就等，或先进 recovery 再退出来触发。

---

## 3. 回滚（核心步骤）

### 3.1 先看清当前尺寸

```powershell
$fb = "C:\platform-tools\platform-tools\fastboot.exe"
& $fb getvar partition-size:system_a
& $fb getvar partition-size:product_a
& $fb getvar partition-size:system_ext_a
```

**原厂尺寸（回滚目标）**：

| 分区 | 原厂尺寸（字节） | 十六进制 |
|---|---|---|
| `system_a` | **5,493,624,832** | `0x147721000` |
| `product_a` | **594,411,520** | `0x236E0000` |
| `system_ext_a` | **460,103,680** | `0x1B6CA000` |

### 3.2 Resize 还原 —— **顺序不能错**

> ⚠️ **先缩后扩，且必须先缩 product/system_ext，最后再扩 system。**
> 反过来会在 super 组空间不足时失败（组上限 12,876,513,280 B）。

```powershell
$fb = "C:\platform-tools\platform-tools\fastboot.exe"

# 第一步：把被扩大的两个先缩回原厂
& $fb resize-logical-partition product_a    594411520
& $fb resize-logical-partition system_ext_a 460103680

# 第二步：再把被缩小的 system 扩回原厂
& $fb resize-logical-partition system_a     5493624832
```

三条都要 `OKAY`。若报空间不足，检查是不是把顺序做反了。

### 3.3 刷回 ZUI16 原厂三镜像

镜像位置：`E:\rom\TB331FC\刷机包\TB331FC_ZUI_16.0.544\image\`

| 镜像 | 大小（字节） | 目标分区 | 实测耗时 |
|---|---|---|---|
| `super_4.img` | 5,493,624,832 | `system_a` | 214.9 s（21 个 sparse 分片） |
| `super_3.img` | 594,411,520 | `product_a` | 19.5 s（3 片） |
| `super_6.img` | 460,103,680 | `system_ext_a` | 15.7 s（2 片） |

```powershell
$fb  = "C:\platform-tools\platform-tools\fastboot.exe"
$img = "E:\rom\TB331FC\刷机包\TB331FC_ZUI_16.0.544\image"

& $fb flash system_a     "$img\super_4.img"
& $fb flash product_a    "$img\super_3.img"
& $fb flash system_ext_a "$img\super_6.img"
```

> `Invalid sparse file format at header magic` 是 fastboot 对 raw 镜像的**正常提示**（随后自动转 sparse 分片发送），**不是错误**。
> `super_4/3/6.img` 就是各逻辑分区的**原始 ext4**，可以直接 `fastboot flash <分区>`，不需要先 `fastboot update`。

### 3.4 擦 userdata + metadata，然后重启

```powershell
$fb = "C:\platform-tools\platform-tools\fastboot.exe"
& $fb -w
& $fb reboot
```

> `File system type raw not supported` / `wipe task partition not found: cache` 属**正常提示**，可忽略。
> `-w` 是必须的：原厂 `/data` 是加密 f2fs，不擦会卡在开机。

---

## 4. 验证恢复

重启后约 **159 s**（实测 15:29:00 → 15:31:45）应能连上 adb：

```powershell
$adb = "E:\rom\tools\platform-tools\adb.exe"
& $adb wait-for-device
& $adb shell getprop sys.boot_completed        # 要 1
& $adb shell getprop ro.build.version.incremental
# 期望：TB331FC_CN_OPEN_USER_Q00003.0_U_ZUI_16.0.544_ST_241115
& $adb shell getprop init.svc.bootanim         # 要 stopped
& $adb shell "ps -A | grep -E 'system_server|zygote64'"   # 两个都要在
```

实测恢复后的健康值：`sys.boot_completed=1`、`system_server` 存活、`zygote64` 存活、`/proc/uptime` ≈191 s、电池 86%。

---

## 5. 只刷过 system 的情况（没动 resize）

如果只做过 `fastboot flash system` 而**没做过 resize**（例如刷 kit GSI），回滚更简单——直接刷原厂 `super_4.img` 即可，**跳过 §3.2**：

```powershell
$fb = "C:\platform-tools\platform-tools\fastboot.exe"
& $fb flash system_a "E:\rom\TB331FC\刷机包\TB331FC_ZUI_16.0.544\image\super_4.img"
& $fb -w
& $fb reboot
```

---

## 6. 真黑屏 / 无 USB 枚举

1. **完全关机**：长按电源键 **15 s 以上**（不是 10 s，实测 10 s 不够）。
2. 保持**音量 + 和音量 − 同时按住**，再插 USB 线。
3. 若出现 `Qualcomm HS-USB QDLoader 9008 (COMx)`（`VID_05C6&PID_9008`）⇒ 这才是真 EDL，可用 QFIL / `fh_loader.exe`。
4. 若仍是 900E ⇒ 回到 §1 继续等。

> **实测结论：本项目 3 次救砖都没有用到 9008/QFIL。** 9008 只在真正刷坏 bootloader 分区（abl/xbl）时才需要，而本项目**从不动 abl/xbl**。

---

## 7. 绝对不要做的事

| ❌ 不要 | 原因 |
|---|---|
| 在 900E 状态下反复拔插 USB / 强行重启 | 会打断 Sahara dump，可能延长或恶化 900E 停留时间 |
| 用 `fastboot reboot fastboot` 当作"回滚入口" | system 不可启动时必失败，容易误判为设备损坏 |
| 刷 `dtbo.img`（原厂 8,388,608 B）到 dtbo 分区 | 分区实际是 25,165,824 B，尺寸不匹配。回滚要用分区级镜像，别拿 `dtbo.img` 直接顶 |
| 刷 vbmeta 想"关掉校验" | 本机 bootloader 已 unlocked + `verifiedbootstate=orange`，本就不需要。刷错 vbmeta 反而多一个变量 |
| 用 QFIL 处理 900E | 900E 是 Sahara dump，firehose 接不进，必然超时 |
| 刷 TWRP | 本项目明确禁用 TWRP 路线 |

---

## 8. 关键路径速查

| 用途 | 路径 |
|---|---|
| fastboot（v37.0.1） | `C:\platform-tools\platform-tools\fastboot.exe` |
| adb（v33.0.1） | `E:\rom\tools\platform-tools\adb.exe` |
| ZUI16 原厂三镜像 | `E:\rom\TB331FC\刷机包\TB331FC_ZUI_16.0.544\image\super_{4,3,6}.img` |
| 启动链备份（6 件） | `E:\rom\release\tmp\_a17try\chain_backup\` |
| 10-08 启动链备份 | `E:\rom\release\TB331FC-boot-backup-20261008\bk\` |
| 完整救砖包（ZUXOS 1.1.10.460） | `E:\rom\release\TB331FC-rollback-zui17\TB331FC_ZUI_17.0.460_250608_full.zip`（4,742,067,910 B，解出 30 分区） |
| 实验记录 | `E:\rom\docs\实验记录_A17三镜像干净刷入_2026-10-18.md` |
| 可行性报告 | `E:\rom\docs\澎湃4可行性结论_2026-10-18.md` |
| 会话复盘（900E 首次踩坑） | `E:\rom\docs\会话复盘_session-a1c5aa16.md` |

---

## 9. 一句话总结

> **掉 900E 就等 3–7 分钟；设备自己会回到 fastboot/fastbootd；先缩 product/system_ext 再扩 system；刷 `super_4/3/6.img`；`fastboot -w`；`fastboot reboot`。全程不用 QFIL。**
