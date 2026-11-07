# A17 (HyperOS 4.0 / Android 17 / SDK 37) DECISIVE SINGLE-VARIABLE TEST.
# ASCII-only on purpose: PS 5.1 misreads BOM-less UTF-8 Chinese in .ps1 files.
#
# WHAT IS UNRESOLVED
#   2026-10-26 : vbmeta_a = vbmeta_a_D  + payload(G/D/D) + vbmeta_system_H -> booted to desktop.
#   2026-10-27 : the SAME combination, reflashed clean        -> ~20 s then 900E.
#   The only difference seen in the logs back then: system_ext_a had just been
#   fastbootd-"Resizing", and --set-active=a had returned "Unable to set slot".
#   Neither is proof. So the mechanism ("chain pubkey mismatch -> verity disabled ->
#   boots; stock chain matches -> verity enabled -> crashes") is still an INFERENCE.
#
# THIS SCRIPT KILLS THAT AMBIGUITY
#   Everything is held identical (system_G / product_D / system_ext_D / vbmeta_system_H /
#   stock boot+vendor_boot+dtbo+init_boot+vendor). Only ONE 8 KiB partition changes:
#
#     -Variant off  vbmeta_a = a17stage\vbmeta_a_D.img      chain pubkey MISMATCH
#                                                 -> expected: verity disabled, boots
#     -Variant on   vbmeta_a = 544 image\vbmeta.img chain pubkey MATCHES H's key
#                                                 -> expected: verity enforcing, ~20 s 900E
#
#   One boots and one crashes  => mechanism CONFIRMED.
#   Both behave the same       => mechanism REFUTED, look elsewhere (write it down).
#
#   The direct readout is ro.boot.veritymode on the booted run (enforcing vs not).
#   If the run crashes there is no userspace, so the USB port class IS the readout.
#
# BASELINE WARNING (2026-11-01)
#   Every pre-11-01 A17 observation was taken on a tablet whose persist partition was
#   ALL ZERO. persist is now repaired, so ACDB / sensor calibration / registry exist.
#   Treat a rerun as a NEW experiment, not a replication: results are only comparable
#   with each other (on vs off), NOT with the 10-26 / 10-27 notes.
#
# Usage
#   powershell -ExecutionPolicy Bypass -File a17_single_var_vbmeta.ps1 -Variant prep
#   powershell -ExecutionPolicy Bypass -File a17_single_var_vbmeta.ps1 -Variant off
#   powershell -ExecutionPolicy Bypass -File a17_single_var_vbmeta.ps1 -Variant on
#   powershell -ExecutionPolicy Bypass -File a17_single_var_vbmeta.ps1 -Variant report
#   A17_DRYRUN=1 in the environment rehearses without touching the device.
#
# Exit codes
#    0 booted to userspace |  2 no fastboot device |  4 missing payload file
#   20 crash port 900E     | 21 stuck in bootloader | 22 no verdict before timeout
#   25 dry run finished    | 26 wrong fastboot mode for this variant
#
# Rollback (always available, do NOT panic):
#   stock vbmeta_a + stock vbmeta_system_a restore the tablet to a bootable 544 at once:
#     fastboot flash vbmeta_a        "E:\rom\TB331FC\...\image\vbmeta.img"
#     fastboot flash vbmeta_system_a "E:\rom\TB331FC\...\image\vbmeta_system.img"
#   abl/xbl are never touched by this script. Worst case: 9008 full restore, ~6 min.

param(
  [Parameter(Mandatory = $true)][ValidateSet('prep','off','on','report')][string]$Variant,
  [ValidateRange(30,600)][int]$WaitSec = 180,
  [switch]$NoReboot,
  [switch]$Yes
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$DRY = [bool]$env:A17_DRYRUN

$fb     = 'E:\rom\work\a17toolkit\bin\fastboot.exe'
$adb    = 'E:\rom\work\a17toolkit\bin\adb.exe'
$stage  = 'E:\rom\work\a17stage'
$stock  = 'E:\rom\TB331FC\' + [char]0x5237 + [char]0x673A + [char]0x5305 + '\TB331FC_ZUI_16.0.544\image'
$logDir = 'E:\rom\work\logs'
$result = Join-Path $logDir 'a17_single_var_result.txt'
$utf8   = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$script:log = Join-Path $logDir ('a17_single_var_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + $Variant + $(if ($DRY) { '_DRYRUN' } else { '' }) + '.log')

function L([string]$m) {
  $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss'), $m
  Write-Host $line
  [System.IO.File]::AppendAllText($script:log, $line + "`r`n", $utf8)
}
function FB([string[]]$a) { if ($DRY) { L ('  [DRY] fastboot ' + ($a -join ' ')); return @() }; return (& $fb @a 2>&1) }
function FBtxt([string[]]$a) { return ((FB $a | Out-String) -replace "`r?`n", ' ').Trim() }
function ADBtxt([string[]]$a) {
  if ($DRY) { L ('  [DRY] adb ' + ($a -join ' ')); return '' }
  return ((& $adb @a 2>&1) | Out-String)
}
function AdbDev {
  if ($DRY) { return $null }
  foreach ($l in ((& $adb devices 2>&1) | Out-String) -split "`r?`n") {
    if ($l -match '^(\S+)\s+device$') { return $Matches[1] }
  }
  return $null
}
# USB id probe: anchored on ^USB\, take the hardware segment, emit vid:pid pairs.
function UsbIds {
  $r = @()
  foreach ($d in (Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue)) {
    if ($d.InstanceId -notmatch '^USB\\') { continue }
    $seg = $d.InstanceId -split '\\'
    if ($seg.Count -lt 2) { continue }
    if ($seg[1] -notmatch '^VID_([0-9A-Fa-f]{4})&PID_([0-9A-Fa-f]{4})') { continue }
    $v = $Matches[1].ToUpper() + ':' + $Matches[2].ToUpper()
    if ($v -match '^(05C6|18D1|17EF|19D2):') { $r += $v }
  }
  return ($r | Select-Object -Unique)
}
function NeedFile([string]$p) {
  if ($DRY) { return $true }
  if (-not (Test-Path $p)) { L ('MISSING FILE: ' + $p); return $false }
  return $true
}
function Ask([string]$q) {
  if ($Yes -or $DRY) { L ('  (auto-yes) ' + $q); return $true }
  $a = Read-Host ($q + ' [y/N]')
  return ($a -match '^[yY]')
}

# ---------------------------------------------------------------- report mode
if ($Variant -eq 'report') {
  if (-not (Test-Path $result)) { L ('no results yet: ' + $result); exit 0 }
  L '=== collected verdicts (append-only ledger) ==='
  foreach ($l in ([System.IO.File]::ReadAllLines($result, $utf8))) { L ('  ' + $l) }
  L '=== how to read it ==='
  L '  need BOTH variants present, payload identical, only vbmeta_a differing.'
  L '  off=booted + on=900E            -> chain/verity mechanism CONFIRMED'
  L '  off and on behave the same      -> mechanism REFUTED (record it, do not force it)'
  L '  anything else (bootloader/EDL)  -> experiment did not measure what it claims'
  exit 0
}

# ---------------------------------------------------------------- payload mode
$payload = @(
  @{ part = 'system_a';     file = (Join-Path $stage 'system_G.img');     size = 1749999616 },
  @{ part = 'product_a';    file = (Join-Path $stage 'product_D.img');    size = 2999996416 },
  @{ part = 'system_ext_a'; file = (Join-Path $stage 'system_ext_D.img'); size = 1549996032 }
)
$Hfile  = Join-Path $stage 'vbmeta_system_H.img'
$Dfile  = Join-Path $stage 'vbmeta_a_D.img'
$Afile  = Join-Path $stock 'vbmeta.img'

L ('== a17_single_var mode=' + $Variant + ' dryrun=' + $DRY + ' ==')
L ('log: ' + $script:log)

foreach ($f in @($Dfile, $Afile, $Hfile)) { if (-not (NeedFile $f)) { exit 4 } }
if ($Variant -eq 'prep') { foreach ($p in $payload) { if (-not (NeedFile $p.file)) { exit 4 } } }

# If we are talking to an android in userspace, get it into bootloader first.
$sn = AdbDev
if (-not $DRY -and $sn) {
  L ('adb device found: ' + $sn + ' (system is up)')
  if (-not (Ask 'reboot it into bootloader fastboot now?')) { L 'refusing to continue without bootloader'; exit 2 }
  $null = ADBtxt @('-s', $sn, 'reboot', 'bootloader')
  for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 1
    if ((FBtxt @('devices')) -match '\S\s+fastboot') { break }
  }
}

$devs = FBtxt @('devices')
if (-not $DRY -and $devs -notmatch '\S\s+fastboot') {
  L ('no fastboot device. PnP now: ' + ((UsbIds) -join ','))
  L '  get the tablet into bootloader: power + volume-down, or adb reboot bootloader.'
  L '  if it is stuck in 900E: hold power 15-30 s to force-reset, then the key combo again.'
  exit 2
}
L ('fastboot sees: ' + $devs)

$userspace = (FBtxt @('getvar', 'is-userspace')) -match 'yes'
if ($DRY) {
  # No device to ask: fake the mode this variant needs, so BOTH gate branches
  # (prep/fastbootd and off-off/bootloader) actually get exercised in rehearsal.
  $userspace = ($Variant -eq 'prep')
  L ('  [DRY] faking is-userspace=' + $userspace + ' to match variant ' + $Variant)
}
L ('is-userspace = ' + $userspace + '  (true means fastbootd, false means bootloader)')
if ($Variant -eq 'prep' -and -not $userspace) {
  L 'ABORT: prep writes LOGICAL partitions -> needs fastbootd.'
  L '  from a booted system: adb reboot fastboot    (or fastboot reboot fastboot)'
  exit 26
}
if ($Variant -ne 'prep' -and $userspace) {
  L 'ABORT: toggling vbmeta_a is done in BOOTLOADER fastboot, not fastbootd.'
  L '  with vbmeta_a_D in place fastbootd/recovery are known to be unbootable, so use'
  L '  the power+volume-down key combo to reach bootloader.'
  exit 26
}

# slot-unbootable can be set by earlier failed boots and silently blocks everything.
$unboot = FBtxt @('getvar', 'slot-unbootable')
L ('slot-unbootable: ' + $unboot)
if ($unboot -match 'yes') {
  L 'clearing it (--set-active=a resets the retry counter; required for a fair test)'
  L ('  ' + (FBtxt @('--set-active=a')))
}

if ($Variant -eq 'prep') {
  L '--- prep: write the A17 payload (this is the long part, ~2 min per GB) ---'
  foreach ($p in $payload) {
    L ('flashing ' + $p.part + ' <- ' + (Split-Path $p.file -Leaf) + ' (' + $p.size + ' B)')
    $os = (FB @('flash', $p.part, $p.file) | Out-String)
    if (-not $DRY -and $os -notmatch 'OKAY') { L ('FAILED: ' + ($os -replace "`r?`n", ' ')); exit 5 }
    L ('  result: ' + (($os -split "`r?`n" | Where-Object { $_ -match 'OKAY|FAILED|total time' } | Select-Object -Last 2) -join ' | '))
  }
  L ('flashing vbmeta_system_a <- ' + (Split-Path $Hfile -Leaf))
  $null = FB @('flash', 'vbmeta_system_a', $Hfile)
  L 'leaving vbmeta_a UNTOUCHED on purpose - the toggling variants do that in bootloader.'
  $null = FBtxt @('--set-active=a')
  L 'prep done. Reboot into BOOTLOADER (power+volume-down after it dies, or fastboot reboot bootloader)'
  L 'then run: -Variant off   and later   -Variant on'
  exit 0
}

# ---------------------------------------------------------------- vbmeta toggle
$chosen = @{ off = $Dfile; on = $Afile }[$Variant]
$expect = @{ off = 'verity disabled -> boots to desktop'; on = 'verity enforcing -> ~20 s -> 05C6:900E' }[$Variant]
L ('--- variant ' + $Variant + ': vbmeta_a <- ' + (Split-Path $chosen -Leaf) + ' ---')
L ('predicted outcome (that is the hypothesis under test): ' + $expect)
L '  boot chain stays stock 544: boot / vendor_boot / dtbo / init_boot / vendor are NOT touched.'

$null = FB @('flash', 'vbmeta_a', $chosen)
$check = FBtxt @('getvar', 'slot-retry-count')
L ('after flash, slot-retry-count: ' + $check)
$null = FBtxt @('--set-active=a')
if ($NoReboot) { L '-NoReboot given: stopping before reboot. Run again without it.'; exit 0 }
if (-not (Ask 'reboot the tablet now and start classifying the boot?')) { L 'not rebooting, stopping.'; exit 0 }

L 'rebooting...'
$null = FB @('reboot')

# ---- classify: poll USB classes + adb. This IS the readout.
L ('observing for ' + $WaitSec + 's (screen matters: if it reaches the UI, tell me)')
$verdict = 'timeout'; $t0 = Get-Date; $seen = @{}
for ($i = 0; $i -lt $WaitSec; $i++) {
  Start-Sleep -Seconds 1
  if ($DRY) { L '  [DRY] fake run: assuming predicted verdict'; $verdict = $(if ($Variant -eq 'off') { 'booted' } else { 'crash900E' }); break }
  $ids = UsbIds
  foreach ($x in $ids) { if (-not $seen.ContainsKey($x)) { $seen[$x] = $i; L ('+{0}s new usb {1}' -f $i, $x) } }
  $j = ($ids -join ',')
  if ($j -match '05C6:900E') { $verdict = 'crash900E'; break }
  if ($j -match '05C6:9008') { $verdict = 'edl9008'; break }
  $s2 = AdbDev
  if ($s2 -or ($j -match '17EF:')) { $verdict = 'booted'; $sn = $s2; break }
  if ($j -match '18D1:D00D' -and $i -gt 45) { $verdict = 'bootloader'; break }
  if ($i % 20 -eq 19) { L ('  +' + ($i + 1) + 's still nothing conclusive, usb=[' + $j + ']') }
}
$el = [int]((Get-Date) - $t0).TotalSeconds

$note = ''
if ($verdict -eq 'booted') {
  L ('BOOTED after ~' + $el + 's (variant ' + $Variant + ') -> hypothesis direction SUPPORTED')
  if ($sn) {
    foreach ($g in @(
      @('shell','getprop ro.build.version.release'),
      @('shell','getprop ro.build.version.sdk'),
      @('shell','getprop ro.boot.veritymode'),
      @('shell','getprop ro.boot.verifiedbootstate'),
      @('shell','getprop ro.boot.bootreason'),
      @('shell','grep -E "persist" /proc/mounts'),
      @('shell','settings get global bluetooth_address'),
      @('shell','ls -d /mnt/vendor/persist/sensors/registry/registry 2>&1'),
      @('shell','dumpsys sensorservice 2>/dev/null | grep -E "h/w sensors"'),
      @('shell','getprop sys.boot_completed')
    )) {
      $out = (ADBtxt @('-s', $sn) + $g) -replace "`r?`n", ' '
      L ('  ' + ($g -join ' ') + '  ==>  ' + $out.Trim())
      $note += ($g[1] + '=' + $out.Trim() + '; ')
    }
    L '  (persist line matters: repaired on 11-01, this proves A17 mounts it too)'
  } else {
    L '  booted per USB class but adb is not authorised -> veritymode not readable.'
    L '  turn on USB debugging and run grab_a17_logs.ps1 to finish the readout.'
  }
  $code = 0
} elseif ($verdict -eq 'crash900E') {
  L ('CRASHED to 900E after ~' + $el + 's (variant ' + $Variant + ')')
  L '  software side cannot read anything from 900E. Force-reset: hold power 15-30 s.'
  L '  then power+volume-down to reach bootloader and run the OTHER variant.'
  $code = 20
} elseif ($verdict -eq 'bootloader') {
  L ('STUCK in bootloader (18D1:D00D) after ~' + $el + 's - ABL refused the slot, not a crash')
  L '  that is a THIRD behaviour, not predicted by either hypothesis -> report it as such.'
  $code = 21
} elseif ($verdict -eq 'edl9008') {
  L 'device fell to 9008 EDL. Use the stock 9008 full restore if needed.'
  $code = 20
} else {
  L ('NO VERDICT within ' + $WaitSec + 's. usb seen: ' + (($seen.Keys | Sort-Object) -join ','))
  L '  timeout is not evidence. Re-run with a larger -WaitSec or watch the screen.'
  $code = 22
}

# ---- append to the ledger (UTF-8 no BOM; PS 5.1 '>' would write UTF-16LE)
$row = '{0}`t{1}`t{2}`t{3}s`t{4}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Variant, $verdict, $el, $note
$row = $row.Replace('`t', "`t")
if (-not $DRY) { [System.IO.File]::AppendAllText($result, $row + "`r`n", $utf8) }
L ('ledger row: ' + ($row -replace "`t", ' | '))
L 'next: -Variant report to see both sides; -Variant <other> for the contrast run.'
if ($DRY) { exit 25 }
exit $code
