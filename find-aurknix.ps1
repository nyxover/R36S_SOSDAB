$out = 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\search-report.txt'
$lines = New-Object System.Collections.Generic.List[string]

$lines.Add("=== DISQUES ===")
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $lines.Add(("{0}  utilise={1:N1} Go  libre={2:N1} Go" -f $_.Root, ($_.Used / 1GB), ($_.Free / 1GB)))
}

$dirs = @(
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\Desktop",
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\OneDrive",
    "$env:USERPROFILE\AppData\Local\Temp\opencode"
)

foreach ($d in $dirs) {
    if (Test-Path $d) {
        $lines.Add("=== NOM CONTENANT aurknix/rocknix/rk3326/r36s/gameconsole : $d ===")
        $hits = Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'aurknix|rocknix|rk3326|r36s|gameconsole' }
        if ($hits) {
            foreach ($h in $hits) { $lines.Add(("{0,12:N1} Mo  {1}" -f ($h.Length / 1MB), $h.FullName)) }
        } else {
            $lines.Add("(aucun)")
        }
    }
}

$lines.Add("=== GROS FICHIERS A LA RACINE DE CHAQUE DISQUE (> 300 Mo) ===")
foreach ($drv in (Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root })) {
    $lines.Add("--- $drv")
    try {
        $big = Get-ChildItem $drv -File -ErrorAction SilentlyContinue | Where-Object { $_.Length -gt 300MB }
        if ($big) {
            foreach ($f in $big) { $lines.Add(("{0,12:N1} Mo  {1}" -f ($f.Length / 1MB), $f.FullName)) }
        } else {
            $lines.Add("(aucun)")
        }
    } catch {
        $lines.Add("(erreur : " + $_.Exception.Message + ")")
    }
}

$lines.Add("=== TOUS LES .dtb DU PROFIL UTILISATEUR ===")
Get-ChildItem "$env:USERPROFILE" -Recurse -File -Filter '*.dtb' -ErrorAction SilentlyContinue |
    Select-Object -First 200 |
    ForEach-Object { $lines.Add(("{0,10} o  {1}" -f $_.Length, $_.FullName)) }

$lines | Set-Content -LiteralPath $out -Encoding UTF8
