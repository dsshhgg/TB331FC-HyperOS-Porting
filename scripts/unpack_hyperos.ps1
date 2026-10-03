# unpack_hyperos.ps1
# 用途：只读列出 HyperOS payload 分区，并抽取 boot/system_dlkm 以确认内核 KMI
# 时间：2026-09-29
# 依赖：payload-dumper-go.exe（E:\rom\port\tools\payload-dumper-go.exe）、magiskboot.exe
# 用法：powershell -File scripts/unpack_hyperos.ps1
# 说明：不做全量解包；禁止任何分区写入

param(
    [string]$Payload = 'E:\rom\yupei-ota_full-OS4.0.5.0.XPZCNXM-user-17.0-4fe489f542\payload.bin',
    [string]$OutDir = 'E:\rom\port\hyperos\work\hyperos_extract',
    [string]$Dumper = 'E:\rom\port\tools\payload-dumper-go.exe',
    [string]$Magiskboot = 'E:\rom\tools\platform-tools\magiskboot.exe'
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Write-Host '=== partitions ==='
& $Dumper -l $Payload

Write-Host '=== extract boot,init_boot,system_dlkm ==='
& $Dumper -p boot,init_boot,system_dlkm -o $OutDir $Payload

Push-Location $OutDir
if (Test-Path 'boot.img') { & $Magiskboot unpack boot.img }
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
