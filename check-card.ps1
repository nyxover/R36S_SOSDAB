$L = New-Object System.Collections.Generic.List[string]
function Say($t) { $L.Add([string]$t) }

$img = 'C:\Users\buire\Downloads\r36s\AURKNIX-RK3326.aarch64-20260809.img'
Say "=== IMAGE DISPONIBLE ==="
if (Test-Path -LiteralPath $img) {
    $i = Get-Item -LiteralPath $img
    Say ("{0}" -f $i.FullName)
    Say ("{0:N0} octets  ({1:N2} Go)" -f $i.Length, ($i.Length / 1GB))
} else {
    Say ("INTROUVABLE : " + $img)
}

Say ""
Say "=== DISQUES ==="
Get-Disk | ForEach-Object {
    Say ("disk{0} : {1} | {2} | {3} Go | {4}" -f $_.Number, $_.FriendlyName, $_.BusType, [math]::Round($_.Size / 1GB, 2), $_.OperationalStatus)
}

Say ""
Say "=== LETTRE I: ==="
Say ("Test-Path I:\ = " + (Test-Path 'I:\'))
if (Test-Path 'I:\') {
    try {
        $v = Get-Volume -DriveLetter I -ErrorAction Stop
        Say ("volume I: {0} | {1} | {2} Go | libre {3} Go" -f $v.FileSystemLabel, $v.FileSystem, [math]::Round($v.Size / 1GB, 2), [math]::Round($v.SizeRemaining / 1GB, 2))
    } catch { Say ("Get-Volume I: " + $_.Exception.Message) }
}

Say ""
Say "=== ACCES BRUT ==="
foreach ($n in @(5, 6)) {
    try {
        $fs = [IO.File]::Open('\\.\PhysicalDrive' + $n, 'Open', 'Read', 'ReadWrite')
        $buf = New-Object byte[] 512
        $null = $fs.Read($buf, 0, 512)
        $fs.Close()
        Say ("PhysicalDrive{0} : OK  MBR/GPT : {1}" -f $n, (($buf[0..3] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '))
    } catch {
        Say ("PhysicalDrive{0} : ECHEC" -f $n)
    }
}

$L | Set-Content -LiteralPath 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\check-card.txt' -Encoding ASCII
