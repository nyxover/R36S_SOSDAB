$ErrorActionPreference = 'Continue'
$src = 'C:\Users\buire\Downloads\r36s\rk3326-gameconsole-r36s-panel3.dtb'
$report = 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\panel3-report.txt'
$L = New-Object System.Collections.Generic.List[string]

function Say($t) { $L.Add([string]$t) }

if (-not (Test-Path -LiteralPath $src)) {
    Say "INTROUVABLE : $src"
    $L | Set-Content -LiteralPath $report -Encoding UTF8
    exit 1
}

$b = [IO.File]::ReadAllBytes($src)
Say ("FICHIER   : " + $src)
Say ("TAILLE    : " + $b.Length + " octets")
Say ("MD5       : " + (Get-FileHash -LiteralPath $src -Algorithm MD5).Hash)
Say ("MAGIC dtb : " + ($b[0] -eq 0xD0 -and $b[1] -eq 0x0D -and $b[2] -eq 0xFE -and $b[3] -eq 0xED))
Say ""

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
        $v = New-Object byte[] $len
        if ($len -gt 0) { [Array]::Copy($b, $i, $v, 0, $len) }
        $i += (($len + 3) -band (-bnot 3))
        [void]$props.Add([pscustomobject]@{ Node = $node; Prop = $pn; Val = $v })
    }
    elseif ($tok -eq 4) { }
    else { $i = $end }
}

$u32 = {
    param($v)
    if ($v.Length -ne 4) { return $null }
    [uint32]((([int64]$v[0]) -shl 24) -bor (([int64]$v[1]) -shl 16) -bor (([int64]$v[2]) -shl 8) -bor ([int64]$v[3]))
}

$root = $props | Where-Object { $_.Node -eq '/' }
foreach ($p in $root) {
    if ($p.Prop -eq 'model' -or $p.Prop -eq 'compatible') {
        Say ("ROOT " + $p.Prop.PadRight(11) + ": " + ([Text.Encoding]::ASCII.GetString($p.Val) -replace '\x00', ' | '))
    }
}
Say ""

$targets = $props | Where-Object { $_.Node -match 'panel' -or $_.Node -match 'dsi' -or $_.Node -match 'display-timings' -or $_.Node -match 'backlight' }
$nodes = $targets | Select-Object -ExpandProperty Node -Unique

foreach ($n in $nodes) {
    Say ("NODE " + $n)
    foreach ($p in ($targets | Where-Object { $_.Node -eq $n } | Sort-Object Prop)) {
        if ($p.Prop -eq 'panel-init-sequence' -or $p.Prop -eq 'panel-exit-sequence') {
            $md5 = [BitConverter]::ToString([Security.Cryptography.MD5]::Create().ComputeHash($p.Val)).Replace('-', '')
            Say ("    {0,-28} {1,5} o   md5={2}" -f $p.Prop, $p.Val.Length, $md5)
        }
        elseif ($p.Val.Length -eq 4) {
            Say ("    {0,-28} {1}" -f $p.Prop, (& $u32 $p.Val))
        }
        else {
            $n2 = [Math]::Min($p.Val.Length, 24)
            $hex = ($p.Val[0..($n2 - 1)] | ForEach-Object { '{0:X2}' -f $_ }) -join ' '
            Say ("    {0,-28} ({1} o) {2}" -f $p.Prop, $p.Val.Length, $hex)
        }
    }
    Say ""
}

# taux de rafraichissement de chaque jeu de timings
Say "=== CADENCES ==="
$groups = $props | Where-Object { $_.Node -match 'display-timings/' } | Group-Object Node
foreach ($g in $groups) {
    $d = @{}
    foreach ($p in $g.Group) { $d[$p.Prop] = & $u32 $p.Val }
    if (-not $d['hactive']) { continue }
    $ht = $d['hactive'] + $d['hfront-porch'] + $d['hsync-len'] + $d['hback-porch']
    $vt = $d['vactive'] + $d['vfront-porch'] + $d['vsync-len'] + $d['vback-porch']
    $hz = [math]::Round($d['clock-frequency'] / ($ht * $vt), 2)
    Say ("{0,-52} {1}x{2} h={3}/{4}/{5} v={6}/{7}/{8} clk={9} ~{10} Hz" -f `
            ($g.Name -replace '.*display-timings/', ''), $d['hactive'], $d['vactive'], `
            $d['hfront-porch'], $d['hsync-len'], $d['hback-porch'], `
            $d['vfront-porch'], $d['vsync-len'], $d['vback-porch'], $d['clock-frequency'], $hz)
}

Say ""
Say "=== COPIE VERS LA CARTE ==="
$dst = 'I:\rk3326-gameconsole-r36s-panel3.dtb'
try {
    Copy-Item -LiteralPath $src -Destination $dst -Force
    $a = (Get-FileHash -LiteralPath $src -Algorithm MD5).Hash
    $c = (Get-FileHash -LiteralPath $dst -Algorithm MD5).Hash
    Say ("copie : " + $(if ($a -eq $c) { "OK $c" } else { "MISMATCH" }))
} catch {
    Say ("ECHEC copie : " + $_.Exception.Message)
}

$L | Set-Content -LiteralPath $report -Encoding UTF8
