# A17（HyperOS 4 / SDK 37）system-only 实测流程

> 约束（用户 m01540）：**vendor 分区一律不动**，只改 system 侧，让 system 去适配 API 33 的 vendor。
> 因此优先走 **DSU**（动态系统），它天然只替换 system、不碰 super 里的 vendor/product。

## 0. 资产清单

| 文件 | 大小 | 说明 |
|---|---|---|
| `E:\rom\work\a17stage\system_A.img` | 1,749,999,616 | 仅在 build.prop 追加 `ro.vendor.api_level=33` |
| `E:\rom\work\a17stage\system_B.img` | 1,749,999,616 | 再加 `ro.llndk.api_level=202404`（切换框架侧兼容矩阵档位） |
| `E:\rom\work\a17stage\system_A.img.gz` / `system_B.img.gz` | ~750 MB | DSU 只认 gz/gzip/zip |
| `E:\rom\work\tools\avb_custom_rsa4096.avbpubkey` | — | 自签公钥（sha1 `0654ee14517036020bc2c4a3f2035e7ccebdc510`） |

两个镜像都已用 `avbtool add_hash_footer` 重签：partition `system`、`SHA256_RSA4096`、salt `…0001`、rollback_index 0，分区尺寸与原始一致；ext4 先 `e2fsck -fy` 修复再缩到 427000 块（footer 需占尾部 64 KiB）。构建后 `e2fsck -fn` 干净。

## 1. 安装（设备在系统里，adb 可用，**不需要 root**）

```powershell
$adb='C:\platform-tools\platform-tools\adb.exe'
& $adb push E:\rom\work\a17stage\system_A.img.gz /sdcard/Download/a17_A.img.gz
& $adb shell am start-activity -n com.android.dynsystem/com.android.dynsystem.VerificationActivity `
    -a android.os.image.action.START_INSTALL `
    -d file:///sdcard/Download/a17_A.img.gz `
    --el KEY_SYSTEM_SIZE 1749999616 --el KEY_USERDATA_SIZE 2147483648
```

预期：`status: IN_PROGRESS … 100%` → `READY / INSTALL_COMPLETED`，result=1。
若报签名不符，追加 `--es KEY_PUBKEY /data/local/tmp/avb_custom_rsa4096.avbpubkey`（先把 pubkey push 到该路径）。

## 2. 重启进动态系统

```powershell
& $adb shell am start-foreground-service -n com.android.dynsystem/.DynamicSystemInstallationService `
    -a com.android.dynsystem.ACTION_REBOOT_TO_DYN_SYSTEM
```

## 3. 判定

- **进了 A17**：`adb shell getprop ro.system.build.version.sdk` → 37；`sys.boot_completed=1`。→ 说明 system 侧适配 succeeded，进入下一步（触控/显示/网络逐项）。
- **又回 stock**：`getprop ro.build.version.sdk` 仍是 35 → 记录发生时间、`adb logcat -b all -d` 里 `init|libgsi|gsid|dm-` 相关行，换 `system_B.img.gz` 再来一轮。

## 4. 为什么先 A 后 B

- A 只加 `ro.vendor.api_level=33`：这是 init/`libvendorsupport.so` 计算「vendor 侧能力」的输入之一，把真实值写进 system，避免它从 vendor 命名空间读不到时取默认值。
- B 再把 `ro.llndk.api_level` 从 202604 降到 202404：`/system/etc/vintf/` 里有 `compatibility_matrix.202404/202504/202604.xml` 三档，改这个属性等于让框架按低档矩阵校验 vendor，从而不要求 API 33 vendor 提供 A17 才有的 HAL。
- 两版都是「只动 system」，vendor 分区完全没碰。

## 5. 备用路线（DSU 走不通时）

fastbootd 里刷 b 槽：`snapshot-update cancel`（释放 4.87 GB COW）→ `create-logical-partition system_b 1749999616` 等 → 刷 A17 三件套 + 460 的 vendor 四件套 + boot/vendor_boot/dtbo/init_boot → `--set-active=b`。
代价：动的是 b 槽的 super 逻辑分区（a 槽的 vendor 不动），且需要 7.03 GB，接近 super 余量上限。
