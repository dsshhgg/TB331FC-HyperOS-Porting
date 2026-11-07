# Grab low-level logs from the booted A17 device as fast as possible.
# ASCII-only (PS 5.1 + BOM-less UTF-8 Chinese issue).
#
# What we want and why:
#   logcat -b all      : everything, including the 'events'/'crash' buffers
#   logcat -b kernel   : kernel ring buffer as exposed to userspace (key for 900E)
#   /sys/fs/pstore     : console-ramoops from the PREVIOUS crash, if pstore enabled
#   /proc/last_kmsg    : older kernels expose the previous panic here
#   dmesg              : needs root; try anyway, record the refusal
#   tombstones         : native crashes (imsdaemon etc.)
#   dropbox            : system_server / watchdog / kernel panic records
#
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File E:\rom\work\tools\grab_a17_logs.ps1
#
# Exit codes: 0 captured | 2 no adb device | 7 capture ran but boot_completed != 1

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$adb = 'E:\rom\work\a17toolkit\bin\adb.exe'
$out = 'E:\rom\work\logs\a17boot_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
New-Item -ItemType Directory -Force -Path $out | Out-Null
$idx = Join-Path $out 'index.txt'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$global:sn = $null

function L([string]$m) {
  $line = '[{0}] {1}' -f (Get-Date -Format 'HH:mm:ss.fff'), $m
  Write-Host $line
  [System.IO.File]::AppendAllText($idx, $line + "`r`n", $utf8)
}
function AdbDev {
  $r = & $adb devices 2>&1
  foreach ($l in $r) { if ($l -match '^(\S+)\s+(device|recovery)$') { return $Matches[1] } }
  return $null
}
function Sh([string]$c) {
  $o = & $adb -s $global:sn shell $c 2>&1
  return ($o | Out-String)
}
# BUG FIX: `> file` under PS 5.1 writes UTF-16LE, so every capture landed as UTF-16
# and grep/tail downstream saw mojibake. Everything goes through this instead.
function Save([string]$name, [string]$text) {
  $p = Join-Path $out $name
  [System.IO.File]::WriteAllText($p, $text, $utf8)
  return $p
}
function SaveBytes([string]$name, [byte[]]$bytes) {
  $p = Join-Path $out $name
  [System.IO.File]::WriteAllBytes($p, $bytes)
  return $p
}
function Sz([string]$name) {
  $p = Join-Path $out $name
  $i = Get-Item $p -ErrorAction SilentlyContinue
  if ($i) { return [int]$i.Length } else { return 0 }
}
# BUG FIX: logcat is streamed via -d into a PS pipeline before, which is fine, but
# writing it through Save() keeps one encoding. Use --pid-less full dump.
function Logcat([string]$buf, [string]$name) {
  $o = & $adb -s $global:sn logcat -b $buf -d -v threadtime 2>&1
  $txt = ($o | Out-String)
  $null = Save $name $txt
  L ('  ' + $name + ': ' + (Sz $name) + ' B')
  return $txt
}
# BUG FIX: this used to (a) match VID_ unanchored against the WHOLE InstanceId, so
# any unrelated device whose instance string merely mentioned VID_05C6 was included,
# and (b) project segment [2], which for most USB devices is the parent/port id and
# never contains the vid:pid pair at all. Now: anchor on ^USB\, take segment [1],
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

L ('== grab_a17_logs start, out=' + $out + ' ==')

# ---- 0. wait for adb. Stop early on 900E/9008: those never yield logs. ----
# BUG FIX: the old loop slept a full 900s even when the device had visibly
# dropped into a Qualcomm crash-dump port, wasting the whole window.
$sn = AdbDev
$global:sn = $sn
if (-not $sn) {
  L 'no adb device; waiting up to 900s (boot order: screen on -> adb online)'
  for ($i = 0; $i -lt 900 -and -not $sn; $i++) {
    Start-Sleep -Seconds 1
    if ($i -gt 60 -and $i % 15 -eq 0) {
      $pnp = UsbIds
      if ($i % 60 -eq 0) { L ('+{0}s usb=[{1}]' -f $i, $pnp) }
      if ($pnp -match '900E|9008') {
        L ('ABORT: device is in ' + $Matches[0] + ' (crash dump / EDL). No logs are obtainable here.')
        L '  A17 never reached userspace. Use pstore on a LATER boot, or read the 900E dump offline.'
        exit 2
      }
    }
    $sn = AdbDev
    $global:sn = $sn
  }
}
if (-not $sn) {
  L 'ABORT: no adb device after 900s'
  exit 2
}
L ('device: ' + $sn + ' -- grabbing immediately')

# ---- 1. the single most important grab: everything, right now ----
L 'logcat -b all (full buffers)'
$all = Logcat 'all' 'logcat_all.txt'
L 'logcat -b kernel'
$null = Logcat 'kernel' 'logcat_kernel.txt'
L 'logcat -b crash'
$null = Logcat 'crash' 'logcat_crash.txt'
L 'logcat -b events'
$null = Logcat 'events' 'logcat_events.txt'

# ---- 2. previous-crash evidence ----
L '/sys/fs/pstore listing + contents'
$pstoreLs = Sh 'ls -la /sys/fs/pstore 2>&1'
$null = Save 'pstore_ls.txt' $pstoreLs
$pstoreN = ($pstoreLs -split "`n" | Where-Object { $_ -match 'console|dmesg|pmsg|ftrace' }).Count
L ('  pstore entries: ' + $pstoreN)
if ($pstoreN -eq 0) {
  L '  NOTE: pstore is empty or absent. Waking pstore needs kernel support for'
  L '        ramoops + a crash that leaves DRAM powered; both may be off in this kernel.'
}
foreach ($f in @('console-ramoops-0', 'console-ramoops', 'dmesg-ramoops-0', 'pmsg-ramoops-0', 'dmesg-ramoops-1')) {
  $c = Sh ('cat /sys/fs/pstore/' + $f + ' 2>/dev/null | head -c 200000')
  if ($c -and $c.Trim().Length -gt 0 -and $c -notmatch 'No such file') {
    $null = Save ('pstore_' + $f + '.txt') $c
    L ('  read pstore/' + $f + ' -> ' + $c.Length + ' chars')
  }
}
L '/proc/last_kmsg'
$lk = Sh 'cat /proc/last_kmsg 2>/dev/null | head -c 200000'
if ($lk -and $lk.Trim().Length -gt 0 -and $lk -notmatch 'No such file') {
  $null = Save 'last_kmsg.txt' $lk
  L ('  ' + $lk.Length + ' chars')
} else { L '  absent (normal on kernels >= 4.19 without CONFIG_PSTORE)' }

# ---- 3. dmesg (needs root; try su, then fall back) ----
L 'dmesg (try direct, then su)'
$dm = Sh 'dmesg 2>&1 | tail -c 200000'
if ($dm -match 'permission denied|Operation not permitted|not allowed') {
  L '  direct dmesg denied -> trying su'
  $dm = Sh 'su -c dmesg 2>/dev/null | tail -c 200000'
}
# BUG FIX: 'dmesg' in Sh() is one string; the old code passed `su -c dmesg` unquoted
# and some shells split it into `su -c dmesg` => su ran with no command.
$null = Save 'dmesg.txt' $dm
L ('  dmesg bytes: ' + (Sz 'dmesg.txt'))
L 'kernel ring via /dev/kmsg (root only, but try)'
$km = Sh 'cat /dev/kmsg 2>&1 | head -c 200000'
if ($km -match 'permission denied|Operation not permitted') {
  $km = Sh 'su -c "cat /dev/kmsg" 2>/dev/null | head -c 200000'
}
$null = Save 'dev_kmsg.txt' $km

# ---- 4. tombstones + dropbox ----
L 'tombstones'
$tls = Sh 'ls -la /data/tombstones 2>&1'
$null = Save 'tombstones_ls.txt' $tls
$tb = Sh 'for f in /data/tombstones/tombstone_*; do echo "===== $f"; head -c 20000 "$f"; done 2>/dev/null | head -c 400000'
if ($tb -and $tb.Trim().Length -gt 0) { $null = Save 'tombstones.txt' $tb; L ('  tombstones ' + $tb.Length + ' chars') }
L 'dropbox (crash / system_server / kernel)'
$db = Sh 'dumpsys dropbox --print 2>/dev/null | tail -c 300000'
$null = Save 'dropbox.txt' $db

# ---- 5. props + services ----
L 'props'
$props = @(
  'ro.build.version.release', 'ro.build.version.sdk', 'ro.system.build.version.sdk',
  'ro.build.fingerprint', 'ro.build.display.id', 'ro.build.type', 'ro.debuggable',
  'ro.llndk.api_level', 'ro.vendor.api_level', 'ro.board.api_level', 'ro.board.first_api_level',
  'ro.product.first_api_level', 'ro.vndk.version', 'ro.boot.verifiedbootstate',
  'ro.boot.slot_suffix', 'ro.crypto.state', 'vold.decrypt', 'sys.boot_completed',
  'init.svc.zygote', 'init.svc.surfaceflinger', 'init.svc.adbd', 'ro.mi.os.version.name',
  'ro.hardware', 'ro.board.platform', 'ro.soc.model', 'persist.sys.timezone',
  'ro.boot.veritymode', 'ro.boot.flash.locked', 'persist.sys.boot.reason'
)
$lines = @()
foreach ($p in $props) { $lines += ('{0} = {1}' -f $p, ((Sh ('getprop ' + $p)) -replace "`r?`n", ' ').Trim()) }
$null = Save 'props.txt' ($lines -join "`r`n")
$lines | ForEach-Object { L ('  ' + $_) }

$bc = ($lines | Where-Object { $_ -match '^sys\.boot_completed' }) -join ''
L ('boot_completed line: [' + $bc + ']')
$booted = ($bc -match '=\s*1')

L 'init service state'
$svc = Sh 'getprop | grep -E "init.svc.(zygote|surfaceflinger|servicemanager|vold|apexd|adbd|hwservicemanager)"'
$null = Save 'init_svc.txt' $svc

# ---- 6. the markers that matter for this investigation ----
# BUG FIX: the old marker grep re-ran `logcat -b all` on device. On a device that
# just booted, that races the buffer and can hang; grep the file we already have.
L 'markers: vendor api / avc / panic / Watchdog / llndk / verity'
$mark = $all -split "`n" | Where-Object { $_ -match '(?i)avc: denied|FATAL|panic|Watchdog|vendor api|llndk|Unexpected vendor|verity|dm-verity|init: |Executable|SIGSEGV|SIGABRT|avb|vbmeta' }
$null = Save 'markers.txt' ($mark -join "`r`n")
L ('  markers lines: ' + $mark.Count)

L 'uptime / load / boot reason'
$up = Sh 'uptime; cat /proc/loadavg; getprop persist.sys.boot.reason'
$null = Save 'uptime.txt' $up

# ---- 7. package + sensor sanity (proves we are on the A17 combo) ----
L 'installed 3rd-party packages + sensors'
$pk = Sh 'pm list packages -3 2>/dev/null | head -40'
$null = Save 'packages.txt' $pk
$pkgN = ($pk -split "`n" | Where-Object { $_ -match '^package:' }).Count
L ('  3rd-party packages: ' + $pkgN)

# ---- 8. post-2026-11-01 baseline: persist is repaired, so A17 runs MUST be judged
# on a healthy persist. Before 11-01 every A17 observation came from a tablet whose
# persist block was all zero, so audio/sensor numbers then are not comparable.
# These are the three fast checks + the audio loop counters, all cheap and decisive.
L 'persist / audio / sensor sanity (the 11-01 baseline)'
$pers = Sh 'grep persist /proc/mounts 2>&1; echo ---; ls -d /mnt/vendor/persist/sensors/registry/registry 2>&1; echo ---; settings get global bluetooth_address; echo ---; ls /mnt/vendor/persist 2>&1 | head -20'
$null = Save 'persist_sanity.txt' $pers
L ('  /proc/mounts has persist line: ' + ($pers -match '(?m)persist'))
L ('  sensors registry present      : ' + ($pers -notmatch 'No such file'))
$btLine = ($pers -split "`n" | Where-Object { $_ -match '^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$|^null$' } | Select-Object -First 1)
L ('  bluetooth_address             : ' + ($btLine -replace "`r", ''))
if ($pers -notmatch '(?m)persist') {
  L '  WARN: persist NOT mounted. ACDB/audio calibration is gone again ->'
  L '        sound and recording will both fail regardless of what A17 does.'
  L '        Fix the block (fh_loader write_persist.xml), then rerun this grab.'
}
$bt = Sh 'settings get global bluetooth_address'
if (($bt -replace "`r?`n", '') -match 'null') { L '  WARN: BT MAC is null -> persist content still broken' }

L 'audio loop counters (from the logcat buffer already captured, no device round trip)'
$adspN = (($all -split "`n" | Where-Object { $_ -match 'adsp daemon will restart' }).Count)
$cardN = (($all -split "`n" | Where-Object { $_ -match 'sound card status changed' }).Count)
$rpcN  = (($all -split "`n" | Where-Object { $_ -match 'sscrpcd|audioadsprpcd' }).Count)
L ('  "adsp daemon will restart" lines  : ' + $adspN)
L ('  "sound card status changed" lines : ' + $cardN)
L ('  sscrpcd/audioadsprpcd lines       : ' + $rpcN)
$aud = @{ adsp_restart = $adspN; soundcard_flip = $cardN; adsprpc_lines = $rpcN } | ConvertTo-Json -Compress
$null = Save 'audio_counters.json' $aud
if ($adspN -gt 20 -or $cardN -gt 20) {
  L '  BAD: restart/flip storm present -> this is the persist-symptom signature.'
} else {
  L '  OK: no adsp/sound-card restart storm in this buffer window.'
}
$au = Sh 'dumpsys audio 2>/dev/null | head -60'
$null = Save 'dumpsys_audio.txt' $au

L 'sensor registry health (29 h/w sensors was the 10-26 success marker)'
$sen = Sh 'dumpsys sensorservice 2>/dev/null | grep -E "h\/w sensors|Total .* sensors" | head -5'
$null = Save 'sensorservice.txt' $sen
L ('  ' + (($sen -split "`n" | Where-Object { $_ -match 'sensors' } | Select-Object -First 2) -join ' / '))

# Judging "did this actually boot fresh / was it flashed": NEVER use uptime (it only
# proves no reboot inside the window). Use btime + bootreason + setupwizard traces.
L 'boot identity: btime / bootreason / first-run traces'
$idn = Sh 'grep -m1 btime /proc/stat; echo ---; getprop ro.boot.bootreason; getprop persist.sys.boot.reason; getprop ro.boot.slot_suffix; echo ---; getprop ro.system.build.version.release; getprop ro.system.build.version.sdk; echo ---; logcat -b events -d -s events_log:V wm_create_activity:V 2>/dev/null | grep -i -m5 setupwizard'
$null = Save 'boot_identity.txt' $idn
foreach ($l in (($idn -split "`n") | Where-Object { $_ -notmatch '^---$' -and $_.Trim() -ne '' })) { L ('  ' + $l.Trim()) }
L '  NOTE: btime epoch is the boot second; ro.build fingerprint alone does NOT prove'
L '        which partition set is installed. Read the three together.'

L '== done =='
Get-ChildItem $out -File | Sort-Object Length -Descending | Select-Object -First 20 |
  ForEach-Object { L ('  {0,10:N0} B  {1}' -f $_.Length, $_.Name) }

if (-not $booted) {
  L 'WARN: sys.boot_completed is not 1 -- framework did not finish booting'
  exit 7
}
L 'RESULT: captured on a fully booted system'
exit 0
