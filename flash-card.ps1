param(
    [switch]$Go
)

$L = New-Object System.Collections.Generic.List[string]
function Say($t) { $L.Add([string]$t) }
$report = 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\flash-report.txt'

$img = 'C:\Users\buire\Downloads\r36s\AURKNIX-RK3326.aarch64-20260809.img'

function Finish() {
    $L | Set-Content -LiteralPath $report -Encoding ASCII
    exit 0
}

Say "=== CARTE A ECRIRE ==="
if (-not (Test-Path -LiteralPath $img)) {
    Say ("IMAGE INTROUVABLE : " + $img)
    Finish
}
$imgLen = (Get-Item -LiteralPath $img).Length
Say ("{0}" -f $img)
Say ("{0:N0} octets ({1:N2} Go)" -f $imgLen, ($imgLen / 1GB))
Say ""

Say "=== RECHERCHE D UN DISQUE USB ==="
$usb = @()
try {
    $usb = @(Get-Disk | Where-Object { $_.BusType -eq 'USB' -and $_.Size -gt 2GB })
} catch {
    Say ("Get-Disk : " + $_.Exception.Message)
    Finish
}

if ($usb.Count -eq 0) {
    Say "AUCUN disque USB detecte (la carte n est pas vue par Windows)."
    Say ""
    Say "Rien n a ete modifie."
    Finish
}

if ($usb.Count -gt 1) {
    Say "PLUSIEURS disques USB detectes, arret par prudence :"
    foreach ($d in $usb) { Say ("  disk{0} : {1} | {2:N2} Go" -f $d.Number, $d.FriendlyName, ($d.Size / 1GB)) }
    Say "Ne laisse branchee que la carte SD."
    Finish
}

$disk = $usb[0]
Say ("Cible : disk{0} | {1} | {2:N2} Go | {3}" -f $disk.Number, $disk.FriendlyName, ($disk.Size / 1GB), $disk.OperationalStatus)

if ($disk.Size -lt $imgLen) {
    Say "La carte est plus petite que l image. Arret."
    Finish
}

Say ""
Say "=== VERIFICATIONS DE SECURITE ==="
$isSystem = $false
try {
    $sys = Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | Where-Object { $_.IsSystem -or $_.IsBoot }
    if ($sys) { $isSystem = $true }
} catch { }
if ($isSystem) {
    Say "Ce disque contient une partition systeme. Arret."
    Finish
}
Say "OK : disque USB, non systeme, taille suffisante."

if (-not $Go) {
    Say ""
    Say "MODE VERIFICATION SEULEMENT. Rien n a ete ecrit."
    Say "Relance avec le parametre -Go pour effacer la carte et ecrire l image."
    Finish
}

Say ""
Say "=== EFFACEMENT DE LA CARTE ==="
try {
    Clear-Disk -Number $disk.Number -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
    Say "Clear-Disk : OK"
} catch {
    Say ("Clear-Disk : " + $_.Exception.Message)
}

Say ""
Say "=== ECRITURE DE L IMAGE ==="
try {
    $src = [IO.File]::OpenRead($img)
    $dst = [IO.File]::Open('\\.\PhysicalDrive' + $disk.Number, [IO.FileMode]::Open, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $buf = New-Object byte[] (4MB)
    $total = 0L
    $last = 0
    while (($r = $src.Read($buf, 0, $buf.Length)) -gt 0) {
        $dst.Write($buf, 0, $r)
        $total += $r
        $pct = [int](($total * 100) / $imgLen)
        if ($pct -ge $last + 10) {
            $last = $pct - ($pct % 10)
            Say ("  ... {0} %  ({1:N2} Go)" -f $pct, ($total / 1GB))
            $L | Set-Content -LiteralPath $report -Encoding ASCII
        }
    }
    $dst.Flush()
    $src.Close()
    $dst.Close()
    Say ("Ecriture terminee : {0:N0} octets" -f $total)
} catch {
    Say ("ECHEC ecriture : " + $_.Exception.Message)
}

Say ""
Say "=== RAFRAICHISSEMENT ==="
Start-Sleep -Seconds 2
try {
    Update-HostStorageCache -ErrorAction SilentlyContinue
    Get-Disk | ForEach-Object { Say ("  disk{0} : {1} | {2:N2} Go" -f $_.Number, $_.FriendlyName, ($_.Size / 1GB)) }
} catch { }

Finish
