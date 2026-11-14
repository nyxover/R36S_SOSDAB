# install-panel3-simple.ps1
# Installation du DTB corrected pour R36S V12 (bandes verticales)
# Usage : .\install-panel3-simple.ps1 [-DriveLetter I] [-Go]
#
# Pre-requis : carte SD branchee, partition BOOT visible dans Windows.
# Le script copie rk3326-r36s-panel3-adjust.dtb + uboot-panel3.dtb et
# modifie boot.ini pour pointer vers le DTB corrige.

param(
    [string]$DriveLetter = "I",
    [switch]$Go
)

$ErrorActionPreference = "Stop"
$L = New-Object System.Collections.Generic.List[string]
function Say($t) { $L.Add([string]$t) }

# --- Localisation des fichiers ---
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dtb  = Join-Path $root "rk3326-r36s-panel3-adjust.dtb"
$ub   = Join-Path $root "uboot-panel3.dtb"
$dest = "${DriveLetter}:\"

Say "=== R36S SOSDAB - installation DTB panel3 ==="
Say ""

if (-not (Test-Path -LiteralPath $dtb)) {
    Say "ERREUR : $dtb introuvable."
    exit 1
}
if (-not (Test-Path -LiteralPath $ub)) {
    Say "ERREUR : $ub introuvable."
    exit 1
}
if (-not (Test-Path -LiteralPath (Join-Path $dest "boot.ini"))) {
    Say "ERREUR : ${DriveLetter}:\boot.ini introuvable."
    Say "La carte SD n'est pas montee ou la lettre de lecteur est incorrecte."
    Say "Essaie : .\install-panel3-simple.ps1 -DriveLetter F"
    exit 1
}

Say "Carte detectede : ${DriveLetter}:\"
Say ("  DTB corrige : " + (Split-Path $dtb -Leaf) + " (" + (Get-Item $dtb).Length + " o)")
Say ("  u-boot      : " + (Split-Path $ub -Leaf) + " (" + (Get-Item $ub).Length + " o)")
Say ""

if (-not $Go) {
    Say "MODE VERIFICATION. Rien n'a ete modifie."
    Say "Relance avec -Go pour installer."
    exit 0
}

# --- Copie des DTB ---
Say "--- COPIE DES FICHIERS ---"
try {
    Copy-Item -LiteralPath $dtb -Destination (Join-Path $dest "rk3326-r36s-panel3-adjust.dtb") -Force
    Say ("  " + (Split-Path $dtb -Leaf) + " -> OK")
} catch {
    Say ("  ERREUR copie DTB : " + $_.Exception.Message)
    exit 1
}
try {
    foreach ($n in @("rg351mp-uboot.dtb", "rg351v-uboot.dtb", "rg351p-uboot.dtb")) {
        Copy-Item -LiteralPath $ub -Destination (Join-Path $dest $n) -Force
        Say ("  " + $n + " -> OK")
    }
} catch {
    Say ("  ERREUR copie u-boot : " + $_.Exception.Message)
    exit 1
}

# --- Mise a jour boot.ini ---
Say ""
Say "--- MISE A JOUR boot.ini ---"
$bootIni = Join-Path $dest "boot.ini"
Copy-Item -LiteralPath $bootIni -Destination ($bootIni + ".bak") -Force
Say "  sauvegarde : boot.ini.bak"

$lines = [IO.File]::ReadAllText($bootIni) -split "`n"
$found = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^(\s*load\s+mmc\s+1:1\s+\$\{dtb_loadaddr\}\s+)(\S+)\s*$') {
        $old = $Matches[2]
        $lines[$i] = $Matches[1] + "rk3326-r36s-panel3-adjust.dtb"
        Say ("  " + $old + " -> rk3326-r36s-panel3-adjust.dtb")
        $found = $true
    }
}
if (-not $found) {
    Say "  ERREUR : ligne dtb_loadaddr introuvable dans boot.ini"
    exit 1
}

$out = ($lines -join "`n")
if (-not $out.EndsWith("`n")) { $out += "`n" }
[IO.File]::WriteAllBytes($bootIni, (New-Object Text.ASCIIEncoding).GetBytes($out))
Say ("  ecriture OK (" + (Get-Item $bootIni).Length + " o)")

# --- Verification ---
Say ""
Say "--- VERIFICATION ---"
$hash = (Get-FileHash -LiteralPath (Join-Path $dest "rk3326-r36s-panel3-adjust.dtb") -Algorithm MD5).Hash
Say ("  DTB installe : md5 " + $hash)
$vi = [IO.File]::ReadAllBytes($bootIni)
Say ("  boot.ini : " + $vi.Length + " o / CR=" + ($vi -contains 0x0D) + " / BOM=" + ($vi[0] -eq 0xEF))

Say ""
Say "INSTALLATION TERMINEE."
Say "Ejecte la carte, reinsere-la dans la console et demarre."
Say ""
Say "Si l'ecran reste noir : verifie que boot.ini pointe bien vers"
Say "rk3326-r36s-panel3-adjust.dtb et non vers un autre DTB."