$ErrorActionPreference = 'Stop'
$L = New-Object System.Collections.Generic.List[string]
function Say($t) { $L.Add([string]$t) }

$kerSrc = 'C:\Users\buire\AppData\Local\Temp\opencode\r36s-backup-20261114\rk3326-r36s-linux.dtb'
$ubSrc  = 'C:\Users\buire\AppData\Local\Temp\opencode\r36s-backup-20261114\rg351mp-uboot.dtb'
$outDir = 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\candidates'

if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

function Read-Fdt($path) {
    $b = [IO.File]::ReadAllBytes($path)
    function BE([int]$o) {
        [uint32]((([int64]$b[$o]) -shl 24) -bor (([int64]$b[$o+1]) -shl 16) -bor (([int64]$b[$o+2]) -shl 8) -bor ([int64]$b[$o+3]))
    }
    $offStruct = [int](BE 8); $offStrings = [int](BE 12)
    $sizeStrings = [int](BE 32); $sizeStruct = [int](BE 36)
    $strings = [Text.Encoding]::ASCII.GetString($b, $offStrings, $sizeStrings)

    $stack = New-Object System.Collections.Stack
    $i = $offStruct; $end = $offStruct + $sizeStruct
    $node = '/'
    $props = New-Object System.Collections.ArrayList

    while ($i -lt $end) {
        $tok = [int](BE $i); $i += 4
        if ($tok -eq 1) {
            $z = $i; while ($b[$z] -ne 0) { $z++ }
            $nm = [Text.Encoding]::ASCII.GetString($b, $i, $z - $i)
            $i += ((($z - $i + 1) + 3) -band (-bnot 3))
            $stack.Push($nm)
            $arr = @($stack.ToArray()); [Array]::Reverse($arr)
            $parts = @($arr | Where-Object { $_ -ne '' })
            $node = if ($parts.Count -eq 0) { '/' } else { '/' + ($parts -join '/') }
        }
        elseif ($tok -eq 2) { if ($stack.Count) { $null = $stack.Pop() } }
        elseif ($tok -eq 3) {
            $len = [int](BE $i); $no = [int](BE ($i + 4)); $i += 8
            $zz = $strings.IndexOf([char]0, $no); $pn = $strings.Substring($no, $zz - $no)
            $valOff = $i
            $i += (($len + 3) -band (-bnot 3))
            [void]$props.Add([pscustomobject]@{ Node = $node; Prop = $pn; Off = $valOff; Len = $len })
        }
        elseif ($tok -eq 4) { }
        else { $i = $end }
    }
    return @{ Bytes = $b; Props = $props }
}

function Set-U32($bytes, $props, $node, $prop, $value) {
    $p = $props | Where-Object { $_.Node -eq $node -and $_.Prop -eq $prop } | Select-Object -First 1
    if (-not $p) { return $false }
    if ($p.Len -ne 4) { return $false }
    $v = [uint32]$value
    $bytes[$p.Off]     = [byte](($v -shr 24) -band 0xFF)
    $bytes[$p.Off + 1] = [byte](($v -shr 16) -band 0xFF)
    $bytes[$p.Off + 2] = [byte](($v -shr 8) -band 0xFF)
    $bytes[$p.Off + 3] = [byte]($v -band 0xFF)
    return $true
}

function Get-U32($props, $node, $prop) {
    $p = $props | Where-Object { $_.Node -eq $node -and $_.Prop -eq $prop } | Select-Object -First 1
    if (-not $p) { return $null }
    return $p
}

$panel = '/dsi@ff450000/panel@0'
$tim   = '/dsi@ff450000/panel@0/display-timings/60Hz'

# ---------- noyau : variante A (porches seuls) ----------
$k = Read-Fdt $kerSrc
Say ("BASE NOYAU : " + $kerSrc + "  (" + $k.Bytes.Length + " o)")
$okA = $true
$okA = (Set-U32 $k.Bytes $k.Props $tim 'clock-frequency' 29000000) -and $okA
$okA = (Set-U32 $k.Bytes $k.Props $tim 'hfront-porch' 150) -and $okA
$okA = (Set-U32 $k.Bytes $k.Props $tim 'hsync-len' 4) -and $okA
$okA = (Set-U32 $k.Bytes $k.Props $tim 'hback-porch' 150) -and $okA
$okA = (Set-U32 $k.Bytes $k.Props $tim 'vfront-porch' 16) -and $okA
$okA = (Set-U32 $k.Bytes $k.Props $tim 'vsync-len' 2) -and $okA
$okA = (Set-U32 $k.Bytes $k.Props $tim 'vback-porch' 14) -and $okA
$outA = Join-Path $outDir 'rk3326-r36s-panel3-porches.dtb'
[IO.File]::WriteAllBytes($outA, $k.Bytes)
Say ("A / porches seuls -> " + $(if ($okA) { 'OK' } else { 'ECHEC' }) + "  " + $outA)

# ---------- noyau : variante B (porches + dsi,flags 0xE03) ----------
$k2 = Read-Fdt $kerSrc
$okB = $true
$okB = (Set-U32 $k2.Bytes $k2.Props $tim 'clock-frequency' 29000000) -and $okB
$okB = (Set-U32 $k2.Bytes $k2.Props $tim 'hfront-porch' 150) -and $okB
$okB = (Set-U32 $k2.Bytes $k2.Props $tim 'hsync-len' 4) -and $okB
$okB = (Set-U32 $k2.Bytes $k2.Props $tim 'hback-porch' 150) -and $okB
$okB = (Set-U32 $k2.Bytes $k2.Props $tim 'vfront-porch' 16) -and $okB
$okB = (Set-U32 $k2.Bytes $k2.Props $tim 'vsync-len' 2) -and $okB
$okB = (Set-U32 $k2.Bytes $k2.Props $tim 'vback-porch' 14) -and $okB
$okB = (Set-U32 $k2.Bytes $k2.Props $panel 'dsi,flags' 0x0E03) -and $okB
$outB = Join-Path $outDir 'rk3326-r36s-panel3-flags.dtb'
[IO.File]::WriteAllBytes($outB, $k2.Bytes)
Say ("B / porches + flags -> " + $(if ($okB) { 'OK' } else { 'ECHEC' }) + "  " + $outB)

# ---------- u-boot : porches seuls ----------
$u = Read-Fdt $ubSrc
Say ("BASE UBOOT : " + $ubSrc + "  (" + $u.Bytes.Length + " o)")
$okU = $true
$okU = (Set-U32 $u.Bytes $u.Props $tim 'clock-frequency' 29000000) -and $okU
$okU = (Set-U32 $u.Bytes $u.Props $tim 'hfront-porch' 150) -and $okU
$okU = (Set-U32 $u.Bytes $u.Props $tim 'hsync-len' 4) -and $okU
$okU = (Set-U32 $u.Bytes $u.Props $tim 'hback-porch' 150) -and $okU
$okU = (Set-U32 $u.Bytes $u.Props $tim 'vfront-porch' 16) -and $okU
$okU = (Set-U32 $u.Bytes $u.Props $tim 'vsync-len' 2) -and $okU
$okU = (Set-U32 $u.Bytes $u.Props $tim 'vback-porch' 14) -and $okU
$outU = Join-Path $outDir 'uboot-panel3.dtb'
[IO.File]::WriteAllBytes($outU, $u.Bytes)
Say ("U / u-boot porches  -> " + $(if ($okU) { 'OK' } else { 'ECHEC' }) + "  " + $outU)

# ---------- verification par relecture ----------
Say ""
Say "=== VERIFICATION (relecture des fichiers produits) ==="
foreach ($f in @($outA, $outB, $outU)) {
    $r = Read-Fdt $f
    Say ("--- " + (Split-Path $f -Leaf) + "  md5=" + (Get-FileHash -LiteralPath $f -Algorithm MD5).Hash)
    foreach ($p in @('clock-frequency', 'hfront-porch', 'hsync-len', 'hback-porch', 'vfront-porch', 'vsync-len', 'vback-porch')) {
        $pp = Get-U32 $r.Props $tim $p
        if ($pp) {
            $v = [uint32]((([int64]$r.Bytes[$pp.Off]) -shl 24) -bor (([int64]$r.Bytes[$pp.Off+1]) -shl 16) -bor (([int64]$r.Bytes[$pp.Off+2]) -shl 8) -bor ([int64]$r.Bytes[$pp.Off+3]))
            Say ("    {0,-18} {1}" -f $p, $v)
        } else {
            Say ("    {0,-18} ABSENT" -f $p)
        }
    }
    $fl = Get-U32 $r.Props $panel 'dsi,flags'
    if ($fl) {
        $v = [uint32]((([int64]$r.Bytes[$fl.Off]) -shl 24) -bor (([int64]$r.Bytes[$fl.Off+1]) -shl 16) -bor (([int64]$r.Bytes[$fl.Off+2]) -shl 8) -bor ([int64]$r.Bytes[$fl.Off+3]))
        Say ("    dsi,flags          0x{0:X4}" -f $v)
    }
    $ht = 640 + 150 + 4 + 150
    $vt = 480 + 16 + 2 + 14
    Say ("    cadence calculee   " + [math]::Round(29000000 / ($ht * $vt), 2) + " Hz")
}

$L | Set-Content -LiteralPath 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\panel3-build-report.txt' -Encoding ASCII
