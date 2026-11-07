param(
    [string]$PortName = 'COM7',
    [int]$Baud = 115200,
    [string]$Command = '',
    [int]$WaitMs = 3000,
    [int]$SettleMs = 400
)
$ErrorActionPreference = 'Stop'
$port = New-Object System.IO.Ports.SerialPort $PortName, $Baud, 'None', 8, 'One'
$port.DtrEnable = $true
$port.ReadTimeout = 800
$port.WriteTimeout = 3000
try {
    $port.Open()
    Start-Sleep -Milliseconds 250
    # drain
    while ($port.BytesToRead -gt 0) { [void]$port.ReadExisting() }
    if ($Command) {
        $port.Write($Command + "`r")
    }
    $sb = New-Object System.Text.StringBuilder
    $deadline = (Get-Date).AddMilliseconds($WaitMs)
    while ((Get-Date) -lt $deadline) {
        try { [void]$sb.Append($port.ReadExisting()) } catch { }
        Start-Sleep -Milliseconds 60
    }
    $sb.ToString()
} finally {
    if ($port.IsOpen) { $port.Close() }
    $port.Dispose()
}
