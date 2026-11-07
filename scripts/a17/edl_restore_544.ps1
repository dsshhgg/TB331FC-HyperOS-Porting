param(
    [Parameter(Mandatory = $true)][string]$ToolDir,
    [Parameter(Mandatory = $true)][string]$ImgDir,
    [string]$Com = ''
)
# Full EDL (9008) restore of stock ZUI 16.0.544 onto the tablet.
# Directory names are passed in as parameters to keep this file pure ASCII.
$ErrorActionPreference = 'Continue'
$adb = 'C:\platform-tools\platform-tools\adb.exe'
$log = 'E:\rom\work\logs\edl_restore_544.log'
Set-Content -Path $log -Value ""
function L($m) { $s = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m; $s; Add-Content -Path $log -Value $s }

if (-not $Com) {
    for ($i = 0; $i -lt 60; $i++) {
        $d = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'VID_05C6&PID_9008' }
        if ($d -and $d.FriendlyName -match '\((COM\d+)\)') { $Com = $Matches[1]; break }
        Start-Sleep -Seconds 2
    }
}
if (-not $Com) { L "no 9008 port found, abort"; exit 1 }
L "9008 on $Com"

$sahara = Join-Path $ToolDir 'QSaharaServer.exe'
$fh = Join-Path $ToolDir 'fh_loader.exe'
$ddr = Join-Path $ToolDir 'prog_firehose_sm6225_ddr.elf'
L "sahara start"
& $sahara -p $Com -s "13:$ddr" 2>&1 | ForEach-Object { L ("  sahara> " + $_) }
Start-Sleep -Seconds 2

foreach ($n in 0..5) {
    $xml = Join-Path $ImgDir ("rawprogram$n.xml")
    if (-not (Test-Path $xml)) { L "skip rawprogram$n (missing)"; continue }
    $out = & $fh --port=$Com --memoryname=ufs --lun=$n --sendxml=$xml --search_path=$ImgDir --mainoutputdir=$ToolDir --noprompt --showpercentagecomplete --zlpawarehost=1 2>&1
    $ok = if (($out -join "`n") -match 'All Finished Successfully') { 'OK' } else { 'CHECK' }
    L "rawprogram$n : $ok"
}
foreach ($n in 0..5) {
    $xml = Join-Path $ImgDir ("patch$n.xml")
    if (-not (Test-Path $xml)) { L "skip patch$n (missing)"; continue }
    $out = & $fh --port=$Com --memoryname=ufs --lun=$n --sendxml=$xml --search_path=$ImgDir --mainoutputdir=$ToolDir --noprompt --zlpawarehost=1 2>&1
    $ok = if (($out -join "`n") -match 'All Finished Successfully') { 'OK' } else { 'CHECK' }
    L "patch$n : $ok"
}
& $fh --port=$Com --memoryname=ufs --reset --noprompt 2>&1 | ForEach-Object { L ("  reset> " + $_) }
L "done"
