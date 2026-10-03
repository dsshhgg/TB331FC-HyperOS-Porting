# debloat_product.ps1
# 用途：按 A 档目标精简 HyperOS product 树（优先砍 data-app）
# 时间：2026-09-29
# 依赖：已解包的 product 树
# 用法：powershell -File scripts/debloat_product.ps1 [-WhatIf]
# 说明：只删 work/trees 下副本，不碰源 img 与原刷机包

param(
    [string]$Tree = 'E:\rom\port\hyperos\work\trees\product\product',
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# A档: final image < 4.5 GiB. Cut data-app first (~2.7 GB).

$cutDataApp = @(
    'CadLauncher', 'WpsLauncher', 'wps-lite', 'CAJLauncher',
    'MiShop', 'MiMediaEditor', 'Creation', 'SmartHome',
    'MIUIMusicPAD', 'MIUIVideoPad', 'MIUIDuokanReaderPad',
    'BaiduIME', 'iFlytekIME',
    'MIpayPad_NO_NFC', 'MiuiScanner', 'MIUIGameCenterPad',
    'MIUIWeather', 'OS4VipAccountPad', 'MIUIHuanji',
    'XMRemoteController', 'MiRemoteControl',
    'MIUIXiaoAiSpeechEngine', 'HyperGalleryPluginCn',
    'MIUICleanMaster', 'VoiceAssistProxy',
    'MIUIEmail', 'MIUIMiDrive'
)

$cutPrivApp = @(
    'MIUIBrowserPad', 'MIUIAICR', 'MIUIFindDeviceCN',
    'MiuiCamera', 'MIUIAod', 'MiGameCenterSDKService', 'MiniGameService',
    'MiuiExtraPhoto', 'GmsCore', 'GooglePlayServicesUpdater',
    'Backup', 'MIUIPersonalAssistantPadOS4', 'MirrorOS4',
    'MIUIYellowPagePad', 'MIUICloudBackup', 'MiuiBarrage',
    'kidspace', 'VoiceAssistAndroidT'
)

$cutApp = @(
    'talkback', 'SwitchAccess', 'AiasstVision', 'VoiceTrigger',
    'MIUISuperMarketPad', 'HybridPlatform', 'PaymentService',
    'MIUIReporter', 'AnalyticsCore', 'SecurityOnetrackService',
    'MiBugReportOS4', 'CatchLog', 'MiuiCit',
    'ConferenceDialer', 'DeviceInfoQR', 'RideModeAudio',
    'MSLgRdp', 'uimgbaservice', 'remotesimlockservice',
    'ThirdAppAssistant',
    'GoogleExtShared', 'GoogleLocationHistory', 'GooglePrintRecommendationService',
    'MiPCExpend', 'com.xiaomi.macro', 'com.xiaomi.ugd'
)

$cutRel = @(
    'media/wallpaper/ai_wallpaper',
    'media/wallpaper/yupei_d',
    'media/theme/os4_fonts',
    'media/theme/MILanProVF.mtz'
)

function Remove-TreePath {
    param([string]$Rel)
    $p = Join-Path $Tree $Rel
    if (-not (Test-Path $p)) { return 0 }
    $item = Get-Item $p
    if ($item.PSIsContainer) {
        $sz = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    } else {
        $sz = $item.Length
    }
    if ($null -eq $sz) { $sz = 0 }
    $mb = [math]::Round($sz / 1MB, 1)
    if ($WhatIf) {
        Write-Host "[CUT?] $Rel  ($mb MB)"
    } else {
        Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[CUT]  $Rel  ($mb MB)"
    }
    return [long]$sz
}

if (-not (Test-Path $Tree)) { throw "tree not found: $Tree" }
$before = (Get-ChildItem $Tree -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host "BEFORE: $([math]::Round($before / 1MB, 1)) MB"

$freed = [long]0
foreach ($n in $cutDataApp) {
    $freed += Remove-TreePath "data-app/$n"
}
foreach ($n in $cutPrivApp) {
    $freed += Remove-TreePath "priv-app/$n"
}
foreach ($n in $cutApp) {
    $freed += Remove-TreePath "app/$n"
}
foreach ($rel in $cutRel) {
    $freed += Remove-TreePath $rel
}

if (-not $WhatIf) {
    $da = Join-Path $Tree 'data-app'
    if (Test-Path $da) {
        Get-ChildItem $da -Directory -ErrorAction SilentlyContinue |
            Where-Object { -not (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue) } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

$after = (Get-ChildItem $Tree -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host "AFTER:  $([math]::Round($after / 1MB, 1)) MB"
Write-Host "FREED:  $([math]::Round($freed / 1MB, 1)) MB"
