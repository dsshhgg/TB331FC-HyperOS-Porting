# Flash the A17 combo that demonstrably booted to desktop (2026-10-26).
# ASCII-only on purpose (PS 5.1 misreads BOM-less UTF-8 Chinese).
#
# Target state after run:
#   system_a     <- system_G.img       (1,749,999,616)
#   product_a    <- product_D.img      (2,999,996,416)
#   system_ext_a <- system_ext_D.img   (1,549,996,032)
#   vbmeta_system_a <- vbmeta_system_H.img  (4096, testkey_rsa2048, flags=0, 3 hashtree)
#   vbmeta_a     <- vbmeta_a_D.img     (8192, testkey_rsa4096, flags=0, hashes + chain)
#   boot / vendor_boot / dtbo / init_boot / vendor / odm / vendor_dlkm stay stock 544
#
# ORDER MATTERS: vbmeta_a_D is flashed LAST (in bootloader). Per prior finding,
# vbmeta_a_D in place makes fastbootd and recovery unbootable, so all fastbootd
# work must finish before it goes in. --set-active=a runs BEFORE that last write,
# so a failed slot fix aborts while recovery is still usable.
#
# Env:
#   A17_DRYRUN=1   rehearse: no fastboot command is executed, no waiting
#   A17_NO_GRAB=1  skip the automatic log capture after a successful boot
#
# Exit codes: 0 ok booted | 2 no fastboot device | 3 no fastbootd | 4 missing payload
#             5 payload flash failed | 6 slot fix failed | 10 boot crashed/timeout | 11 dryrun done

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$DRY = [bool]$env:A17_DRYRUN
$fb  = 'E:\rom\work\a17toolkit\bin\fastboot.exe'
$adb = 'E:\rom\work\a17toolkit\bin\adb.exe'
$stage = 'E:\rom\work\a17stage'
$logDir = 'E:\rom\work\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ('flash_a17_working_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + $(if ($DRY) { '_DRYRUN' } else { '' }) + '.log')
$utf8 = New-Object System.Text.UTF8Encoding($false)

# BUG FIX 5: Tee-Object -Append writes UTF-16LE; use explicit UTF-8 no BOM.
function L([string]$m) {
  $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m
  Write-Host $line
  [System.IO.File]::AppendAllText($log, $line + "`r`n", $utf8)
}
function FB([string[]]$a) {
  if ($DRY) { L ('  [DRY] fastboot ' + ($a -join ' ')); return @() }
  return (& $fb @a 2>&1)
}
function FBtxt([string[]]$a) { return ((FB $a | Out-String) -replace "`r?`n", ' ').Trim() }
function Get-Serial {
  if ($DRY) { return 'DRYSERIAL' }
  foreach ($l in (& $fb devices 2>&1)) { if ($l -match '^(\S+)\s+fastboot') { return $Matches[1] } }
  return $null
}
function In-Fastbootd {
  if ($DRY) { return $true }
  return ((FB @('getvar', 'is-userspace') | Out-String) -match 'is-userspace:\s*yes')
}
function AdbOnline {
  foreach ($l in (& $adb devices 2>&1)) { if ($l -match '^(\S+)\s+(device|recovery)') { return $Matches[1] } }
  return $null
}
# BUG FIX: this used to (a) match VID_ unanchored against the WHOLE InstanceId, so
# any unrelated device whose instance string merely mentioned VID_05C6 was included,
# and (b) project segment [1] -- which is 'VID_xxxx&PID_yyyy&MI_00' but for composite
# or non-composite devices can be something else entirely, and never carries the
# compact form the callers compare against. Now: anchor on ^USB\, take segment [1],
# anchor the VID/PID, and emit '05C6:900E' style ids.
function UsbIds {
  $r = @()
  foreach ($d in (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue)) {
    if ($d.InstanceId -notmatch '^USB\\') { continue }
    $seg = $d.InstanceId -split '\\'
    if ($seg.Count -lt 2) { continue }
    if ($seg[1] -notmatch '^VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})') { continue }
    $v = $Matches[1] + ':' + $Matches[2]
    if ($v -match '^(05C6|18D1|17EF|19D2):') { $r += $v }
  }
  return ($r -join ',')
}

L '== flash A17 working combo start =='
L ('log: ' + $log)
if ($DRY) { L 'MODE: DRYRUN (nothing is executed, no waiting)' }

# ---------- 1. wait for a fastboot device ----------
$sn = Get-Serial
if (-not $DRY -and -not $sn) {
  L 'waiting up to 600s for fastboot device (POWER+VOLDOWN, or adb reboot bootloader)'
  for ($i = 0; $i -lt 120 -and -not $sn; $i++) {
    Start-Sleep -Seconds 5
    $sn = Get-Serial
    if ($sn) { L ('device appeared at +{0}s: {1}' -f ($i * 5), $sn) }
  }
}
if (-not $sn) {
  L ('ABORT: no fastboot device. usb=[' + (UsbIds) + ']')
  L '  if you see 900E -> Qualcomm crash dump, hold Vol+ and Vol- then replug for 9008'
  exit 2
}
L ('fastboot serial: ' + $sn)

# ---------- 2. payload check ----------
$parts = @(
  @{ n = 'system_a';     sz = 1749999616; img = (Join-Path $stage 'system_G.img');     dig = 'cc180c18' },
  @{ n = 'product_a';    sz = 2999996416; img = (Join-Path $stage 'product_D.img');    dig = '832596f2' },
  @{ n = 'system_ext_a'; sz = 1549996032; img = (Join-Path $stage 'system_ext_D.img'); dig = '83f7fa74' }
)
$vbmSys = Join-Path $stage 'vbmeta_system_H.img'
$vbmMain = Join-Path $stage 'vbmeta_a_D.img'
foreach ($p in $parts) { if (-not (Test-Path $p.img)) { L ('ABORT missing ' + $p.img); exit 4 } }
foreach ($f in @($vbmSys, $vbmMain)) { if (-not (Test-Path $f)) { L ('ABORT missing ' + $f); exit 4 } }
foreach ($p in $parts) { L ('payload {0} {1:N0} B (want {2:N0})' -f $p.n, (Get-Item $p.img).Length, $p.sz) }
L ('payload vbmeta_system_H {0} B / vbmeta_a_D {1} B' -f (Get-Item $vbmSys).Length, (Get-Item $vbmMain).Length)
foreach ($p in $parts) {
  if ((Get-Item $p.img).Length -ne $p.sz) { L ('ABORT size mismatch on ' + $p.img); exit 4 }
}

# ---------- 3. get into fastbootd ----------
if ($DRY) {
  L '[DRY] assume fastbootd is reachable, skip reboot-into-fastbootd'
} elseif (-not (In-Fastbootd)) {
  L 'bootloader detected -> fastboot reboot fastboot'
  FB @('reboot', 'fastboot') | Out-Null
  $ok = $false
  for ($i = 0; $i -lt 36 -and -not $ok; $i++) {
    Start-Sleep -Seconds 5
    if (Get-Serial) { if (In-Fastbootd) { $ok = $true; L ('fastbootd ready at +{0}s' -f ($i * 5)) } }
  }
  if (-not $ok) {
    L 'ABORT: fastbootd unreachable'
    L '  usual cause: vbmeta_a in place is NOT the stock 544 one -> fastbootd refuses to start'
    L '  fix: fastboot flash vbmeta_a <stock 544 vbmeta.img>, then retry this script'
    exit 3
  }
} else {
  L 'already in fastbootd'
}

L ('current-slot: ' + (FBtxt @('getvar', 'current-slot')))
L ('slot-unbootable:a: ' + (FBtxt @('getvar', 'slot-unbootable:a')))
FB @('snapshot-update', 'cancel') | ForEach-Object { L ('  snapshot cancel: ' + $_) }

# ---------- 4. recreate + flash logical partitions ----------
foreach ($p in $parts) { FB @('delete-logical-partition', $p.n) | ForEach-Object { L "  del $($p.n): $_" } }
foreach ($p in $parts) { FB @('create-logical-partition', $p.n, "$($p.sz)") | ForEach-Object { L "  new $($p.n): $_" } }

# BUG FIX 9: verify the partition really is the size we asked for (hex output).
foreach ($p in $parts) {
  $v = FBtxt @('getvar', ('partition-size:' + $p.n))
  L ('  size ' + $p.n + ' -> ' + $v)
  if (-not $DRY) {
    $hex = $null
    if ($v -match '0x([0-9a-fA-F]+)') { $hex = $Matches[1] }
    if ($hex) {
      $got = [Convert]::ToInt64($hex, 16)
      if ($got -ne $p.sz) { L ('ABORT: ' + $p.n + ' is ' + $got + ' B, want ' + $p.sz); exit 5 }
    } else { L ('  WARN: cannot parse partition size for ' + $p.n) }
  }
}

$sw = [Diagnostics.Stopwatch]::StartNew()
# BUG FIX 13: a FAILED flash must abort, not fall through into wipe + vbmeta_v writes.
$flashFailed = $false
foreach ($p in $parts) {
  $t = [Diagnostics.Stopwatch]::StartNew()
  L ('flashing {0} <- {1}' -f $p.n, $p.img)
  $out = FB @('flash', $p.n, $p.img)
  ($out | Where-Object { $_ -match '\S' } | Select-Object -Last 3) | ForEach-Object { L "  $_" }
  L ('  {0} done in {1}s' -f $p.n, [int]$t.Elapsed.TotalSeconds)
  if ((($out | Out-String) -match 'FAILED|error:|Invalid|too large')) { L ('!! FAILED while flashing ' + $p.n); $flashFailed = $true; break }
}
if ($flashFailed) {
  L 'ABORT: a payload flash failed. vbmeta_a still stock -> recovery/fastbootd remain usable.'
  L ('  total ' + [int]$sw.Elapsed.TotalSeconds + 's, log ' + $log)
  exit 5
}

L 'flashing vbmeta_system_a <- vbmeta_system_H.img'
$o = FB @('flash', 'vbmeta_system_a', $vbmSys)
($o | Where-Object { $_ -match '\S' }) | ForEach-Object { L "  $_" }
if ((($o | Out-String) -match 'FAILED|error:')) { L 'ABORT: vbmeta_system_a flash failed'; exit 5 }

# ---------- 5. erase userdata/metadata so A17 gets a clean /data ----------
# Known quirk on this device: `fastboot -w` only ERASES, it does not reformat
# ("File system type raw not supported"). A17 reformats /data itself on first
# boot, so we tolerate that message and fall back to explicit erase.
L 'fastboot -w (expect File system type raw not supported -- benign)'
$wout = FB @('-w') | Out-String
($wout -split "`r?`n" | Where-Object { $_ -match '\S' }) | Select-Object -Last 6 | ForEach-Object { L "  $_" }
if ($wout -match 'not supported|FAILED|error:') {
  L '  -w reported an error -> explicit erase userdata + metadata'
  FB @('erase', 'userdata') | ForEach-Object { L "  erase userdata: $_" }
  FB @('erase', 'metadata') | ForEach-Object { L "  erase metadata: $_" }
}

# ---------- 6. back to bootloader, fix slot, THEN flash vbmeta_a_D ----------
L 'reboot bootloader'
FB @('reboot', 'bootloader') | Out-Null
$got = $false
if ($DRY) { $got = $true } else {
  for ($i = 0; $i -lt 40 -and -not $got; $i++) {
    Start-Sleep -Seconds 3
    if (Get-Serial) { if (-not (In-Fastbootd)) { $got = $true; L ('back in bootloader at +{0}s' -f ($i * 3)) } }
  }
}
if (-not $got) { L 'WARN: could not confirm bootloader mode; proceeding anyway' }

# BUG FIX 4: slot fix runs BEFORE the vbmeta_a write. Previously a failed
# `--set-active=a` surfaced only after vbmeta_a_D was already in place, i.e.
# exactly when recovery/fastbootd stop working and the only way out is 9008.
L 'set active slot = a (must happen while recovery is still usable)'
$sa = (FB @('--set-active=a') | Out-String).Trim()
($sa -split "`r?`n" | Where-Object { $_ -match '\S' }) | ForEach-Object { L ('  ' + $_) }
if (-not $DRY -and $sa -match 'FAILED|Unable|error|Unknown') {
  L '  --set-active=a failed -> fallback: set_active a'
  $sa2 = (FB @('set_active', 'a') | Out-String).Trim()
  ($sa2 -split "`r?`n" | Where-Object { $_ -match '\S' }) | ForEach-Object { L ('  ' + $_) }
  if ($sa2 -match 'FAILED|Unable|error|Unknown') {
    L 'ABORT: cannot make slot a active. vbmeta_a NOT touched; device stays bootable via recovery.'
    L '  hint: fastboot --set-active=a after `fastboot erase metadata`, or check slot-unbootable:a'
    exit 6
  }
}
L ('  slot-unbootable:a now: ' + (FBtxt @('getvar', 'slot-unbootable:a')))

L 'flashing vbmeta_a <- vbmeta_a_D.img (LAST step)'
$o = FB @('flash', 'vbmeta_a', $vbmMain)
($o | Where-Object { $_ -match '\S' }) | ForEach-Object { L "  $_" }
if ((($o | Out-String) -match 'FAILED|error:')) { L 'ABORT: vbmeta_a flash failed (device still bootable via recovery)'; exit 5 }
L ('total flash time ' + [int]$sw.Elapsed.TotalSeconds + 's')

# ---------- 7. reboot and watch ----------
L 'fastboot reboot'
FB @('reboot') | Out-Null

$crash = $false
$adbSn = $null
if ($DRY) {
  L '[DRY] skip boot watch'
} else {
  # BUG FIX 2: remember whether adb really appeared; never report success on timeout.
  $seen = @{}
  for ($i = 1; $i -le 72 -and -not $crash -and -not $adbSn; $i++) {
    Start-Sleep -Seconds 5
    $pnp = UsbIds
    $adbSn = AdbOnline
    $line = ('+{0}s usb=[{1}] adb=[{2}]' -f ($i * 5), $pnp, $(if ($adbSn) { $adbSn } else { '' }))
    if (-not $seen.ContainsKey($line)) { L $line; $seen[$line] = 1 }
    if ($pnp -match '900E') { L '!! 900E Qualcomm crash dump'; $crash = $true }
    elseif ($pnp -match '9008') { L '!! 9008 EDL mode'; $crash = $true }
  }
}

if ($crash) {
  L 'RESULT: did NOT boot (device dropped into a crash/EDL mode)'
  L '  do NOT reflash blindly. Rescue path: 9008 + QSaharaServer + fh_loader (see knowledge base)'
  L ('== end. log: ' + $log + ' ==')
  exit 10
}
if ($DRY) {
  L 'RESULT: DRYRUN rehearsal finished, no device touched'
  L ('== end. log: ' + $log + ' ==')
  exit 11
}
if (-not $adbSn) {
  L 'RESULT: no adb within 360s and no crash id seen -- state unknown, check the screen'
  L ('== end. log: ' + $log + ' ==')
  exit 10
}

L ('RESULT: adb online (' + $adbSn + ') -> capture low-level logs now')
L ('== end. log: ' + $log + ' ==')

# ---------- 8. optional auto-capture ----------
if (-not $env:A17_NO_GRAB) {
  $grab = 'E:\rom\work\tools\grab_a17_logs.ps1'
  if (Test-Path $grab) {
    L 'running grab_a17_logs.ps1 to capture low-level logs'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $grab 2>&1 | ForEach-Object { L "  $_" }
  } else { L ('WARN: missing ' + $grab) }
}
exit 0
