# Restore the last known-bootable A17 combo:
#   system_a      = system_G.img   (digest cc180c18...)
#   product_a     = product_D.img  (digest 832596f2...)
#   system_ext_a  = system_ext_D.img (digest 83f7fa74...)
#   vbmeta_system_a = vbmeta_system_H.img
# Waits for bootloader, enters fastbootd, flashes, reboots. ASCII only.
$ErrorActionPreference = 'Continue'
$fb  = 'C:\platform-tools\platform-tools\fastboot.exe'
$adb = 'C:\platform-tools\platform-tools\adb.exe'
$st  = 'E:\rom\work\a17stage'
$log = 'E:\rom\work\logs\restore_known_good.log'
function L($m) { $s = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; $s; Add-Content -Path $log -Value $s }
function FB([string[]]$a) { (cmd /c ('"' + $fb + '" ' + ($a -join ' ') + ' 2>&1')) -join ' ' }

Set-Content -Path $log -Value ""
L "start"

# 1. wait for any usb device (bootloader or recovery or adb)
$sn = $null
for ($i = 0; $i -lt 180; $i++) {
    $d = FB @('devices')
    if ($d -match '(\w+)\s+fastboot') { $sn = $Matches[1]; L "bootloader $sn"; break }
    $r = (cmd /c ('"' + $adb + '" devices 2>&1')) -join ' '
    if ($r -match '(\w+)\s+(recovery|device)') {
        $sn = $Matches[1]; $mode = $Matches[2]; L "adb $sn $mode"
        if ($mode -eq 'recovery') { (cmd /c ('"' + $adb + '" -s ' + $sn + ' reboot fastboot 2>&1')) | Out-Null; L "asked recovery -> fastboot" }
        break
    }
    Start-Sleep -Seconds 5
}
if (-not $sn) { L "no device found, abort"; exit 1 }

# 2. wait for fastbootd
$ok = $false
for ($i = 0; $i -lt 120; $i++) {
    $d = FB @('devices')
    if ($d -match '(\w+)\s+fastboot') {
        $us = FB @('-s', $sn, 'getvar', 'is-userspace')
        if ($us -match 'is-userspace: yes') { $ok = $true; L "fastbootd ready"; break }
        if ($i -eq 0) { FB @('-s', $sn, 'reboot', 'fastboot') | Out-Null; L "asked bootloader -> fastbootd" }
    }
    Start-Sleep -Seconds 5
}
if (-not $ok) { L "fastbootd not available, abort"; exit 2 }

# 3. flash known good
L ("del product_a: " + (FB @('-s', $sn, 'delete-logical-partition', 'product_a')))
L ("new product_a: " + (FB @('-s', $sn, 'create-logical-partition', 'product_a', '2999996416')))
L ("flash product_D: " + (FB @('-s', $sn, 'flash', 'product_a', "$st\product_D.img")))
L ("flash system_G: " + (FB @('-s', $sn, 'flash', 'system_a', "$st\system_G.img")))
L ("flash system_ext_D: " + (FB @('-s', $sn, 'flash', 'system_ext_a', "$st\system_ext_D.img")))
L ("flash vbmeta_system_H: " + (FB @('-s', $sn, 'flash', 'vbmeta_system_a', "$st\vbmeta_system_H.img")))
L ("reboot: " + (FB @('-s', $sn, 'reboot')))
L "done"
