$L = New-Object System.Collections.Generic.List[string]
$L.Add("=== LETTRES PRESENTES ===")
foreach ($c in 67..90) {
    $d = ([char]$c).ToString() + ':\'
    if (Test-Path $d) {
        $lbl = ''
        try { $lbl = (Get-Volume -DriveLetter ([char]$c) -ErrorAction Stop).FileSystemLabel } catch { }
        $L.Add(("{0}  {1}" -f $d, $lbl))
    }
}
$L.Add("")
$L.Add("=== DISQUES ===")
try {
    Get-Disk | ForEach-Object { $L.Add(("disk {0}: {1} | {2} | {3} Go | {4}" -f $_.Number, $_.FriendlyName, $_.BusType, [math]::Round($_.Size/1GB,1), $_.OperationalStatus)) }
} catch { $L.Add("Get-Disk erreur : " + $_.Exception.Message) }
$L.Add("")
$L.Add("=== VOLUMES ===")
try {
    Get-Volume | ForEach-Object { $L.Add(("{0} {1} | {2} | {3} | libre {4} Go" -f $_.DriveLetter, $_.FileSystemLabel, $_.FileSystem, $_.DriveType, [math]::Round($_.SizeRemaining/1GB,2))) }
} catch { $L.Add("Get-Volume erreur : " + $_.Exception.Message) }
$L | Set-Content -LiteralPath 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\drives.txt' -Encoding ASCII
