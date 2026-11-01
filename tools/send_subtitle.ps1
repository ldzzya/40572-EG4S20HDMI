param(
    [Parameter(Mandatory=$true)][string]$Port,
    [Parameter(Mandatory=$true)][AllowEmptyString()][string]$Text
)
$ErrorActionPreference = 'Stop'
if ($Text.Length -gt 80 -or $Text -match '[^\x20-\x7e]') {
    throw 'Use 0 to 80 printable ASCII characters (English, digits, punctuation).'
}
$serial = New-Object System.IO.Ports.SerialPort $Port,115200,([System.IO.Ports.Parity]::None),8,([System.IO.Ports.StopBits]::One)
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.Encoding = [System.Text.Encoding]::ASCII
$serial.ReadTimeout = 1500
$serial.WriteTimeout = 1500
$serial.DtrEnable = $false
$serial.RtsEnable = $false
try {
    $serial.Open()
    $serial.DiscardInBuffer()
    $serial.Write("TEXT $Text`n")
    $reply = [char]$serial.ReadChar()
    switch ($reply) {
        'K' { Write-Output 'Subtitle committed at video frame boundary.' }
        'B' { throw 'FPGA is committing another subtitle. Wait and send again.' }
        'E' { throw 'FPGA rejected the line. Check baud rate, encoding and length.' }
        default { throw "Unexpected reply: $reply" }
    }
}
finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
