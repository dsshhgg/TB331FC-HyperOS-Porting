[Console]::OutputEncoding=[Text.Encoding]::UTF8
# Waits for the device to appear in fastboot, then reports full state. Does NOT flash.
$fb  = 'E:\rom\tools\platform-tools\fastboot.exe'
$adb = 'C:\platform-tools\platform-tools\adb.exe'
$log = 'E:\rom\release\tmp\fb_state.log'

function Note($m){ $line = "[{0}] {1}" -f (Get-Date -Format HH:mm:ss), $m; $line | Tee-Object -FilePath $log -Append }

"=== wait start $(Get-Date -Format s) ===" | Out-File -FilePath $log -Encoding utf8
$deadline = (Get-Date).AddMinutes(15)
$found = $false
while((Get-Date) -lt $deadline){
  $fbl = ((& $fb devices 2>&1) | Where-Object { $_ -match '\tfastboot' }) -join ' '
  if($fbl){ $found = $true; Note "FASTBOOT: $fbl"; break }
  $adbl = ((& $adb devices 2>&1) | Where-Object { $_ -match "\t(device|recovery|sideload)" }) -join ' '
  if($adbl){ Note "ADB: $adbl" }
  Start-Sleep -Seconds 4
}
if(-not $found){
  Note 'no fastboot within 15 min'
  exit 0
}
Note '== getvar dump =='
foreach($k in 'current-slot','slot-count','unlocked','is-userspace','slot-successful:a','slot-successful:b','slot-retry-count:a','slot-retry-count:b','max-download-size','product','partition-size:boot_a','partition-size:vendor_boot_a','partition-size:boot_b','partition-size:vendor_boot_b'){
  $out = (& $fb getvar $k 2>&1 | Where-Object { $_ -match ':' }) -join ' '
  Note "$k -> $out"
}
Note '== done =='
