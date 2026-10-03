# backup_partitions.ps1
# 用途：TB331FC 试刷前的分区只读导出（备份）。本脚本**只读设备**，不写入任何分区。
# 时间：2026-10
# 依赖：adb / fastboot（platform-tools）；设备需已解锁并允许 adb root 或处于 fastboot 模式
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts/backup_partitions.ps1
#       -> 默认 dry-run：只打印计划，不接触设备
#   powershell -ExecutionPolicy Bypass -File scripts/backup_partitions.ps1 -Execute
#       -> 真正执行导出（仍然只读）
#   powershell -ExecutionPolicy Bypass -File scripts/backup_partitions.ps1 -Execute -Mode adb
#
# ⚠️ 重要声明
#   1. 本脚本**不做** fastboot flash / erase / format / 任何分区写入。
#   2. 本脚本**未在真机验证过**。首次使用请先用 dry-run 审查命令，再逐条手动确认。
#   3. 备份不是万无一失：若设备已有问题，备份下来的可能是坏数据。
#      真正的兜底是 **9008（EDL）救砖包 + prog_firehose**，请先确认其可用性。
#   4. 备份产物含个人数据（persist / 用户数据），注意保管。

param(
    [switch]$Execute,
    [ValidateSet('auto','fastboot','adb')]
    [string]$Mode = 'auto',
    [string]$OutDir = 'E:\rom\port\hyperos\backup',
    [string]$Adb = 'adb',
    [string]$Fastboot = 'fastboot'
)

$ErrorActionPreference = 'Stop'

# ---- 需要备份的分区 ----------------------------------------------------------
# A/B 设备：_a / _b 都备（当前 slot 之外的那份是回滚保险）
$slotParts = @(
    'boot', 'init_boot', 'vendor_boot', 'dtbo', 'vbmeta', 'vbmeta_system', 'recovery'
)
# 非 A/B / 独立分区
$plainParts = @(
    'persist', 'lenovocust', 'modem', 'bluetooth', 'dsp', 'tz', 'xbl', 'abl',
    'devinfo', 'frp', 'fsg', 'logfs'
)
# 动态分区：整块 super 太大，这里只记录元数据；单独分区由下面的 logical 列表导出
$logicalParts = @(
    'system', 'system_ext', 'product', 'vendor', 'odm', 'vendor_dlkm', 'system_dlkm'
)

function Write-Plan([string]$text) { Write-Host "  $text" }

Write-Host "=== TB331FC 分区备份 ==="
Write-Host "输出目录: $OutDir"
Write-Host "模式    : $Mode$(if (-not $Execute) { '  (DRY-RUN，不会接触设备)' })"
Write-Host ""

if (-not $Execute) {
    Write-Host "[DRY-RUN] 计划执行的动作："
    foreach ($p in $slotParts) {
        Write-Plan "fastboot fetch ${p}_a  -> $OutDir\${p}_a.img"
        Write-Plan "fastboot fetch ${p}_b  -> $OutDir\${p}_b.img"
    }
    foreach ($p in $plainParts) {
        Write-Plan "fastboot fetch $p -> $OutDir\$p.img"
    }
    foreach ($p in $logicalParts) {
        Write-Plan "adb root; adb exec-out dd if=/dev/block/mapper/$p of=$OutDir\$p.img"
    }
    Write-Host ""
    Write-Host "[DRY-RUN] 另需手工留存（脚本不代做）："
    Write-Plan "liblp 元数据：adb exec-out dd if=/dev/block/by-name/super bs=4096 count=1"
    Write-Plan "分区表：      fastboot getvar all 2>&1 | Tee-Object $OutDir\getvar_all.txt"
    Write-Plan "属性快照：    adb shell getprop > $OutDir\getprop.txt"
    Write-Host ""
    Write-Host "确认无误后加 -Execute 真正执行。"
    exit 0
}

# ---- 真正执行 ----------------------------------------------------------------
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# 自动判断设备当前处于哪种模式
if ($Mode -eq 'auto') {
    $devs = & $Fastboot devices 2>$null
    if ($devs) { $Mode = 'fastboot' } else { $Mode = 'adb' }
    Write-Host "自动判定模式: $Mode"
}

$failed = @()

if ($Mode -eq 'fastboot') {
    Write-Host "--- fastboot fetch（只读导出） ---"
    $all = @()
    foreach ($p in $slotParts) { $all += "${p}_a"; $all += "${p}_b" }
    $all += $plainParts
    foreach ($p in $all) {
        $dst = Join-Path $OutDir "$p.img"
        Write-Host "fetch $p -> $dst"
        # fastboot fetch 在部分 bootloader 上不可用；失败则记录，改用 9008 或 TWRP
        & $Fastboot fetch $p $dst 2>&1 | ForEach-Object { Write-Host "    $_" }
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $dst)) { $failed += $p }
    }
    & $Fastboot getvar all 2>&1 | Tee-Object (Join-Path $OutDir 'getvar_all.txt') | Out-Null
}
else {
    Write-Host "--- adb root + dd（只读导出） ---"
    & $Adb root 2>&1 | ForEach-Object { Write-Host "    $_" }
    Start-Sleep -Seconds 2
    & $Adb wait-for-device
    foreach ($p in $logicalParts) {
        $dst = Join-Path $OutDir "$p.img"
        Write-Host "dd /dev/block/mapper/$p -> $dst"
        # exec-out 走二进制安全通道；不要用 adb shell（会做换行转换）
        & "$Adb" exec-out "dd if=/dev/block/mapper/$p bs=1048576" > $dst
        if (-not (Test-Path $dst) -or (Get-Item $dst).Length -eq 0) { $failed += $p }
    }
    & $Adb shell getprop > (Join-Path $OutDir 'getprop.txt')
}

# 备份清单与哈希
$manifest = Join-Path $OutDir 'BACKUP_MANIFEST.txt'
"# TB331FC 备份清单  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $manifest -Encoding utf8
Get-ChildItem $OutDir -Filter *.img | ForEach-Object {
    "{0}  {1,15:N0} B  sha256={2}" -f $_.Name, $_.Length, (Get-FileHash $_.FullName -Algorithm SHA256).Hash |
        Out-File $manifest -Append -Encoding utf8
}

Write-Host ""
Write-Host "=== 完成 ==="
Write-Host "产物: $OutDir"
Write-Host "清单: $manifest"
if ($failed.Count) {
    Write-Warning "以下分区导出失败，必须另行处理（TWRP / 9008）后再考虑试刷：$($failed -join ', ')"
    exit 2
}
Write-Host "全部导出成功。**在确认 9008 救砖可用之前，不要开始试刷。**"
