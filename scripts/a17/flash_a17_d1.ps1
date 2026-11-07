# A17 single-variable experiment D1 (ASCII-only on purpose: PowerShell 5.1 misreads BOM-less UTF-8).
# Flash ONLY slot-a logical partitions + vbmeta_system_a; keep vbmeta_a / boot / vendor_boot / vendor untouched.
# Run: powershell -ExecutionPolicy Bypass -File E:\rom\work\tools\flash_a17_d1.ps1
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$fb = 'C:\platform-tools\platform-tools\fastboot.exe'
$adb = 'C:\platform-tools\platform-tools\adb.exe'
$stage = 'E:\rom\work\a17stage'
$logDir = 'E:\rom\work\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("flash_d1_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".log")

function L([string]$m) {
  $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
  $line | Tee-Object -FilePath $log -Append
}
function FBS([string[]]$a) { & $fb -s $global:sn @a 2>&1 }
function Get-Serial {
  $raw = & cmd /c "`"$fb`" devices 2>&1"
  foreach ($l in $raw) { if ($l -match '^(\S+)\s+fastboot') { return $Matches[1] } }
  return $null
}
function In-Fastbootd {
  $u = (FBS @('getvar', 'is-userspace') | Out-String)
  return ($u -match 'is-userspace:\s*yes')
}

L "== flash_a17_d1 start =="
$sn = Get-Serial
if (-not $sn) {
  L "no fastboot device; waiting up to 300s -- enter bootloader with POWER+VOLDOWN"
  for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 5
    $sn = Get-Serial
    if ($sn) { L "device appeared at +$($i * 5)s: $sn"; break }
  }
}
if (-not $sn) { L "ABORT: no fastboot device"; exit 2 }
$global:sn = $sn

if (-not (In-Fastbootd)) {
  L "not in fastbootd -> fastboot reboot fastboot"
  FBS @('reboot', 'fastboot') | Out-Null
  $ok = $false
  for ($i = 0; $i -lt 36; $i++) {
    Start-Sleep -Seconds 5
    $sn = Get-Serial
    if (-not $sn) { continue }
    $global:sn = $sn
    if (In-Fastbootd) { L "fastbootd ready at +$($i * 5)s"; $ok = $true; break }
  }
  if (-not $ok) { L "ABORT: fastbootd not reachable"; exit 3 }
} else { L "already in fastbootd" }

L ("slot: " + ((FBS @('getvar', 'current-slot') | Out-String) -replace "`r?`n", ' '))
FBS @('snapshot-update', 'cancel') | ForEach-Object { L "  cancel: $_" }

$parts = @(
  @{ n = 'system_a'; sz = 1749999616; img = (Join-Path $stage 'system_D.img') },
  @{ n = 'product_a'; sz = 2999996416; img = (Join-Path $stage 'product_D.img') },
  @{ n = 'system_ext_a'; sz = 1549996032; img = (Join-Path $stage 'system_ext_D.img') }
)
foreach ($p in $parts) {
  if (-not (Test-Path $p.img)) { L ("ABORT: missing " + $p.img); exit 4 }
}
foreach ($p in $parts) { FBS @('delete-logical-partition', $p.n) | ForEach-Object { L "  del $($p.n): $_" } }
foreach ($p in $parts) { FBS @('create-logical-partition', $p.n, "$($p.sz)") | ForEach-Object { L "  new $($p.n): $_" } }
foreach ($p in $parts) {
  $sz = (FBS @('getvar', ("partition-size:" + $p.n)) | Out-String) -replace "`r?`n", ' '
  L "  size $($p.n) -> $sz"
}

$sw = [Diagnostics.Stopwatch]::StartNew()
foreach ($p in $parts) {
  $t = [Diagnostics.Stopwatch]::StartNew()
  $gb = [math]::Round((Get-Item $p.img).Length / 1GB, 2)
  L "flashing $($p.n) <- $($p.img) ($gb GB)"
  FBS @('flash', $p.n, $p.img) | Where-Object { $_ -match '\S' } | Select-Object -Last 3 | ForEach-Object { L "  $_" }
  L "  done in $([int]$t.Elapsed.TotalSeconds)s"
}

$vs = Join-Path $stage 'vbmeta_system_E.img'
L "flashing vbmeta_system_a <- $vs (vbmeta_a stays stock)"
FBS @('flash', 'vbmeta_system_a', $vs) | ForEach-Object { L "  $_" }
L "total flash time $([int]$sw.Elapsed.TotalSeconds)s"

L "fastboot reboot"
FBS @('reboot') | Out-Null
$seen = @{}
for ($i = 1; $i -le 48; $i++) {
  Start-Sleep -Seconds 5
  $pnp = (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -match 'VID_05C6|VID_18D1|VID_17EF' } |
    ForEach-Object { ($_.InstanceId -split '\\')[1] }) -join ','
  $adbDev = (& $adb devices 2>&1 | Select-String -Pattern "`t(device|recovery|sideload)" | ForEach-Object { $_.Line }) -join ';'
  $line = "+$($i * 5)s usb=[$pnp] adb=[$adbDev]"
  if (-not $seen.ContainsKey($line)) { L $line; $seen[$line] = 1 }
  if ($pnp -match '900E|9008') { L "!! crash/EDL detected"; break }
  if ($adbDev -match 'device') { L "!! adb online"; break }
}
L "== flash_a17_d1 end (log: $log) =="
