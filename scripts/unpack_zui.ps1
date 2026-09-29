# unpack_zui.ps1
# 用途：只读解包 ZUI 底包关键镜像（boot/init_boot/vendor_boot），提取内核版本
# 时间：2026-09-29
# 依赖：magiskboot.exe（E:\rom\tools\platform-tools\magiskboot.exe）
# 用法：powershell -File scripts/unpack_zui.ps1
# 说明：不写原刷机包；输出到 E:\rom\port\hyperos\work\zui_boot

param(
    [string]$ZuiImageDir = 'E:\类\刷机\联想\TB331FC\刷机包\TB331FC_ZUI_16.0.544\image',
    [string]$OutDir = 'E:\rom\port\hyperos\work\zui_boot',
    [string]$Magiskboot = 'E:\rom\tools\platform-tools\magiskboot.exe'
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

foreach ($name in @('boot.img','init_boot.img','vendor_boot.img','dtbo.img')) {
    $src = Join-Path $ZuiImageDir $name
    if (Test-Path $src) {
        Copy-Item $src (Join-Path $OutDir $name) -Force
        Write-Host "[COPY] $name"
    }
}

Push-Location $OutDir
& $Magiskboot unpack boot.img
Pop-Location

$kernel = Join-Path $OutDir 'kernel'
if (Test-Path $kernel) {
    $bytes = [System.IO.File]::ReadAllBytes($kernel)
    $text = [System.Text.Encoding]::ASCII.GetString($bytes)
    if ($text -match 'Linux version [^\x00]{5,140}') {
        Write-Host "KERNEL: $($Matches[0])"
    }
}
Write-Host "Done -> $OutDir"
