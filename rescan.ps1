$L = New-Object System.Collections.Generic.List[string]
function Say($t) { $L.Add([string]$t) }

Say "=== avant rescan ==="
try { Get-Disk 5 | ForEach-Object { Say ("disk5 : {0} | {1} | {2} Go | {3}" -f $_.FriendlyName, $_.BusType, [math]::Round($_.Size/1GB,1), $_.OperationalStatus) } } catch { Say ("disk5 : " + $_.Exception.Message) }

try {
    Update-HostStorageCache -ErrorAction Stop
    Say "Update-HostStorageCache : OK"
} catch { Say ("Update-HostStorageCache : " + $_.Exception.Message) }

Start-Sleep -Seconds 2

Say ""
Say "=== apres rescan ==="
try {
    Get-Disk | ForEach-Object { Say ("disk{0} : {1} | {2} | {3} Go | {4}" -f $_.Number, $_.FriendlyName, $_.BusType, [math]::Round($_.Size/1GB,1), $_.OperationalStatus) }
} catch { Say ("Get-Disk : " + $_.Exception.Message) }

Say ""
Say "=== partitions du disque 5 ==="
try {
    Get-Partition -DiskNumber 5 -ErrorAction Stop | ForEach-Object { Say ("  part {0} : {1} o  lettre={2}" -f $_.PartitionNumber, $_.Size, $_.DriveLetter) }
} catch { Say ("  aucune : " + $_.Exception.Message) }

Say ""
Say "=== test acces I: ==="
$L.Add("Test-Path I:\boot.ini = " + (Test-Path 'I:\boot.ini'))
try {
    $fs = [IO.File]::Open('\\.\PhysicalDrive5', 'Open', 'Read', 'ReadWrite')
    $buf = New-Object byte[] 512
    $null = $fs.Read($buf, 0, 512)
    $fs.Close()
    Say ("acces brut PhysicalDrive5 : OK  (premiers octets : " + (($buf[0..7] | ForEach-Object { '{0:X2}' -f $_ }) -join ' ') + ")")
} catch {
    Say ("acces brut PhysicalDrive5 : ECHEC -> " + $_.Exception.Message)
}

$L | Set-Content -LiteralPath 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\rescan.txt' -Encoding ASCII
