$ErrorActionPreference = 'Stop'
$L = New-Object System.Collections.Generic.List[string]
function Say($t) { $L.Add([string]$t) }
$report = 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\install-panel3-report.txt'

try {
    $cand = 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\candidates'
    $kA = Join-Path $cand 'rk3326-r36s-panel3-porches.dtb'
    $kB = Join-Path $cand 'rk3326-r36s-panel3-flags.dtb'
    $uB = Join-Path $cand 'uboot-panel3.dtb'

    if (-not (Test-Path 'I:\boot.ini')) {
        Say "CARTE ABSENTE : I:\boot.ini inaccessible."
        Say "Rebranche la carte SD puis relance ce script."
        $L | Set-Content -LiteralPath $report -Encoding ASCII
        exit 1
    }

    foreach ($f in @($kA, $kB, $uB)) {
        Copy-Item -LiteralPath $f -Destination ('I:\' + (Split-Path $f -Leaf)) -Force
    }
    Say "DTB copies :"
    foreach ($f in @($kA, $kB, $uB)) {
        $name = Split-Path $f -Leaf
        $a = (Get-FileHash -LiteralPath $f -Algorithm MD5).Hash
        $b = (Get-FileHash -LiteralPath ('I:\' + $name) -Algorithm MD5).Hash
        Say ("  {0,-40} {1}" -f $name, $(if ($a -eq $b) { "OK $b" } else { "MISMATCH" }))
    }

    # boot.ini -> variante A
    $bootIni = 'I:\boot.ini'
    Copy-Item -LiteralPath $bootIni -Destination ($bootIni + '.bak') -Force
    $txt = [IO.File]::ReadAllText($bootIni)
    $lines = $txt -split "`n"
    $done = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^(\s*load\s+mmc\s+1:1\s+\$\{dtb_loadaddr\}\s+)(\S+)\s*$') {
            $lines[$i] = $Matches[1] + 'rk3326-r36s-panel3-porches.dtb'
            $done = $true
        }
    }
    if (-not $done) { throw 'ligne dtb_loadaddr introuvable' }
    $out = ($lines -join "`n")
    if (-not $out.EndsWith("`n")) { $out += "`n" }
    [IO.File]::WriteAllBytes($bootIni, (New-Object Text.ASCIIEncoding).GetBytes($out))
    Say ("boot.ini -> rk3326-r36s-panel3-porches.dtb  ($((Get-Item $bootIni).Length) octets)")

    # u-boot
    foreach ($nm in @('rg351mp-uboot.dtb', 'rg351v-uboot.dtb', 'rg351p-uboot.dtb')) {
        Copy-Item -LiteralPath $uB -Destination ('I:\' + $nm) -Force
    }
    $want = (Get-FileHash -LiteralPath $uB -Algorithm MD5).Hash
    Say ("u-boot installe :")
    foreach ($nm in @('rg351mp-uboot.dtb', 'rg351v-uboot.dtb', 'rg351p-uboot.dtb')) {
        $got = (Get-FileHash -LiteralPath ('I:\' + $nm) -Algorithm MD5).Hash
        Say ("  {0,-24} {1}" -f $nm, $(if ($got -eq $want) { "OK $got" } else { "MISMATCH" }))
    }

    $bytes = [IO.File]::ReadAllBytes($bootIni)
    Say ("verif finale : boot.ini " + $bytes.Length + " o / CR=" + ($bytes -contains 0x0D) + " / BOM=" + ($bytes[0] -eq 0xEF))
    Say ""
    Say "PRET : ejecte la carte et demarre."
}
catch {
    Say ("ERREUR : " + $_.Exception.Message)
}
$L | Set-Content -LiteralPath $report -Encoding ASCII
