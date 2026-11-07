$ErrorActionPreference='Continue'
[Console]::OutputEncoding=[Text.Encoding]::UTF8
$fb='C:\platform-tools\platform-tools\fastboot.exe'
$adb='C:\platform-tools\platform-tools\adb.exe'
$W='E:\rom\work\a17stage'

function FB { param([string[]]$a) & $fb @a 2>&1 }
function Wait-Dev { param([string]$mode,[int]$sec=120)
  $t=0
  while($t -lt $sec){
    $out = (cmd /c "`"$fb`" devices 2>&1") -join "`n"
    if($mode -eq 'fastboot' -and $out -match '\tfastboot'){ return $true }
    Start-Sleep -Seconds 3; $t+=3
  }
  return $false
}

"== reboot to fastbootd =="
$ad = (cmd /c "`"$adb`" devices 2>&1") -join "`n"
if($ad -match '\tdevice'){
  & $adb reboot fastboot 2>&1 | Out-Null
} else {
  FB @('reboot','fastboot')
}
if(-not (Wait-Dev 'fastboot' 150)){ "NO FASTBOOT"; exit 1 }
Start-Sleep -Seconds 3
"is-userspace: " + ((FB @('getvar','is-userspace')) -join ' ')

"== current sizes =="
FB @('getvar','partition-size:system_a') | ForEach-Object { $_ }
FB @('getvar','snapshot-update','cancel') | Out-Null

"== flash system_a =="
$sw=[Diagnostics.Stopwatch]::StartNew()
FB @('flash','system_a',"$W\system_E.img") | Select-Object -Last 3
$sw.Stop(); "system_E took $([int]$sw.Elapsed.TotalSeconds)s"

"== flash vbmeta_system_a =="
FB @('flash','vbmeta_system_a',"$W\vbmeta_system_F.img") | Select-Object -Last 2

"== reboot =="
FB @('reboot') | Out-Null
Start-Sleep -Seconds 5
"done"
