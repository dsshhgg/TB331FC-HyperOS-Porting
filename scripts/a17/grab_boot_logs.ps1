# Wait for the tablet to appear on adb, then grab everything we can before it crashes.
# ASCII only (PowerShell 5.1 + BOM-less UTF-8 issue). Run:
#   powershell -NoProfile -ExecutionPolicy Bypass -File E:\rom\work\tools\grab_boot_logs.ps1
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$adb = 'C:\platform-tools\platform-tools\adb.exe'
$fb = 'C:\platform-tools\platform-tools\fastboot.exe'
$out = 'E:\rom\work\logs\bootcatch_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
New-Item -ItemType Directory -Force -Path $out | Out-Null
$idx = Join-Path $out 'index.txt'
function L([string]$m) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m
  $line | Tee-Object -FilePath $idx -Append
}
function Sh([string]$c) { (& cmd /c "`"$adb`" -s $global:sn shell $c 2>&1") -join "`n" }
function AdbDev {
  $r = (& cmd /c "`"$adb`" devices 2>&1")
  foreach ($l in $r) { if ($l -match '^(\S+)\s+(device|recovery)$') { return $Matches[1] } }
  return $null
}

L "== bootcatch start, out=$out =="
L "waiting up to 15 min for adb device (power on the tablet now)"
$sn = $null
for ($i = 0; $i -lt 900; $i++) {
  $sn = AdbDev
  if ($sn) { L "adb device appeared at +$($i)s : $sn"; break }
  $pnp = (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -match 'VID_05C6|VID_18D1|VID_17EF' } |
    ForEach-Object { ($_.InstanceId -split '\\')[1] }) -join ','
  if ($i % 10 -eq 0) { L "+$($i)s usb=[$pnp]" }
  Start-Sleep -Seconds 1
}
if (-not $sn) { L "ABORT: no adb device in 15 min"; exit 2 }
$global:sn = $sn

# Fire everything immediately, newest-first priority: logcat, dmesg, props.
L "grabbing logcat (all buffers)..."
& cmd /c "`"$adb`" -s $sn logcat -b all -d -v threadtime > `"$out\logcat.txt`" 2>&1"
L ("  logcat lines: " + ((Get-Content (Join-Path $out 'logcat.txt') -ErrorAction SilentlyContinue | Measure-Object -Line).Lines))

L "grabbing dmesg..."
Sh 'dmesg' | Set-Content -Path (Join-Path $out 'dmesg.txt') -Encoding utf8
L ("  dmesg lines: " + ((Get-Content (Join-Path $out 'dmesg.txt') -ErrorAction SilentlyContinue | Measure-Object -Line).Lines))

L "grabbing props..."
$props = @(
  'ro.build.version.sdk','ro.system.build.version.sdk','ro.build.version.release',
  'ro.build.display.id','ro.build.fingerprint','ro.llndk.api_level','ro.vendor.api_level',
  'ro.board.api_level','ro.product.first_api_level','ro.boot.verifiedbootstate',
  'sys.boot_completed','init.svc.zygote','init.svc.surfaceflinger','init.svc.adbd',
  'ro.mi.os.version.name','ro.boot.slot_suffix','ro.crypto.state','vold.decrypt'
)
$lines = @()
foreach ($p in $props) { $lines += ("{0} = {1}" -f $p, ((Sh ("getprop " + $p)) -replace "`r?`n", ' ')) }
$lines | Set-Content -Path (Join-Path $out 'props.txt') -Encoding utf8
L "props:"
$lines | ForEach-Object { L "  $_" }

L "grabbing avc / crash markers..."
Sh "logcat -d -b all | grep -iE 'avc: denied|FATAL|panic|Watchdog|vendor api|llndk|init:'" |
  Set-Content -Path (Join-Path $out 'markers.txt') -Encoding utf8
L ("  markers lines: " + ((Get-Content (Join-Path $out 'markers.txt') -ErrorAction SilentlyContinue | Measure-Object -Line).Lines))

L "grabbing pstore dir listing (needs root; may fail)..."
Sh 'ls -la /sys/fs/pstore' | Set-Content -Path (Join-Path $out 'pstore_ls.txt') -Encoding utf8

L "== done; files in $out =="
Get-ChildItem $out | Select-Object Name, Length | ForEach-Object { L ("  {0} {1} B" -f $_.Name, $_.Length) }
