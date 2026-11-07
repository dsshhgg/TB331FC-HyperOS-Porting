# auto-recover: wait for device in fastboot, then flash known-good system_D
$ErrorActionPreference='Continue'
$fb='C:\platform-tools\platform-tools\fastboot.exe'
$W='E:\rom\work\a17stage'
$log='E:\rom\work\logs\recover_D.log'
function L($m){ $t=(Get-Date).ToString('HH:mm:ss'); "$t $m" | Tee-Object -FilePath $log -Append }
"=== start $(Get-Date -Format s) ===" | Set-Content $log

function Get-Dev { ((& $fb devices 2>&1) -join ' ') }

L 'waiting for fastboot device...'
$ok=$false
for($i=0;$i -lt 600;$i++){
  $d = Get-Dev
  if($d -match '\tfastboot'){ L "found: $d"; $ok=$true; break }
  Start-Sleep -Seconds 3
}
if(-not $ok){ L 'TIMEOUT waiting for fastboot'; exit 2 }

# make sure we are in fastbootd (userspace) for logical partitions
$u = ((& $fb getvar is-userspace 2>&1) -join ' ')
L "is-userspace: $u"
if($u -notmatch 'is-userspace: yes'){
  L 'reboot fastboot'
  & $fb reboot fastboot 2>&1 | Out-Null
  $rdy=$false
  for($i=0;$i -lt 60;$i++){
    Start-Sleep -Seconds 3
    $u2 = ((& $fb getvar is-userspace 2>&1) -join ' ')
    if($u2 -match 'is-userspace: yes'){ L "fastbootd ready after $($i*3)s"; $rdy=$true; break }
  }
  if(-not $rdy){ L 'fastbootd not ready, abort'; exit 3 }
}

L 'flash system_a <- system_D.img'
$sw=[Diagnostics.Stopwatch]::StartNew()
(& $fb flash system_a "$W\system_D.img" 2>&1) | Select-Object -Last 2 | ForEach-Object { L $_ }
L "system_D flashed in $([int]$sw.Elapsed.TotalSeconds)s"

L 'flash vbmeta_system_a <- vbmeta_system_E.img'
(& $fb flash vbmeta_system_a "$W\vbmeta_system_E.img" 2>&1) | Select-Object -Last 2 | ForEach-Object { L $_ }

L 'reboot'
& $fb reboot 2>&1 | Select-Object -Last 1 | ForEach-Object { L $_ }
L 'done'
