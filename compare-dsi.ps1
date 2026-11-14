param([Parameter(Mandatory)][string[]]$Path)

function Rotate([byte[]]$v, [int]$len) {
    if ($len -ne 4 -or $v.Length -lt 4) { return $null }
    return [uint32]((([int64]$v[0]) -shl 24) -bor (([int64]$v[1]) -shl 16) -bor (([int64]$v[2]) -shl 8) -bor ([int64]$v[3]))
}

function Hex([byte[]]$v) {
    if ($v.Length -eq 0) { return '(vide)' }
    $n = [Math]::Min($v.Length, 16)
    (($v[0..($n-1)] | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
}

function Inspect([string]$file) {
    $b = [IO.File]::ReadAllBytes($file)
    function BE([int]$o) {
        [uint32]((([int64]$b[$o]) -shl 24) -bor (([int64]$b[$o+1]) -shl 16) -bor (([int64]$b[$o+2]) -shl 8) -bor ([int64]$b[$o+3]))
    }
    $offStruct = [int](BE 8); $offStrings = [int](BE 12)
    $sizeStrings = [int](BE 32); $sizeStruct = [int](BE 36)
    $strings = [Text.Encoding]::ASCII.GetString($b, $offStrings, $sizeStrings)

    $stack = New-Object System.Collections.Stack
    $i = $offStruct; $end = $offStruct + $sizeStruct
    $node = '/'
    $props = @()

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
            $z = $strings.IndexOf([char]0, $no); $pn = $strings.Substring($no, $z - $no)
            $v = New-Object byte[] $len
            if ($len -gt 0) { [Array]::Copy($b, $i, $v, 0, $len) }
            $i += (($len + 3) -band (-bnot 3))
            $props += [pscustomobject]@{ Node = $node; Prop = $pn; Val = $v }
        }
        elseif ($tok -eq 4) { }
        else { $i = $end }
    }

    $name = [IO.Path]::GetFileName($file)
    $model = ($props | Where-Object { $_.Prop -eq 'model' -and $_.Node -eq '/' } | Select-Object -First 1)
    $compat = ($props | Where-Object { $_.Prop -eq 'compatible' -and $_.Node -eq '/' } | Select-Object -First 1)
    "=================================================================="
    "$name   ($($b.Length) octets)   md5=$((Get-FileHash $file -Algorithm MD5).Hash)"
    if ($model) { "  model      = " + ([Text.Encoding]::ASCII.GetString($model.Val).TrimEnd([char]0) -replace '\x00', ' | ') }
    if ($compat) { "  compatible = " + ([Text.Encoding]::ASCII.GetString($compat.Val).TrimEnd([char]0) -replace '\x00', ' | ') }

    $targets = @('/dsi@ff450000', '/dsi@ff450000/panel@0', '/backlight')
    foreach ($t in $targets) {
        $g = $props | Where-Object { $_.Node -eq $t }
        if (-not $g) { continue }
        "  --- $t"
        foreach ($p in $g | Sort-Object Prop) {
            if ($p.Prop -eq 'panel-init-sequence' -or $p.Prop -eq 'panel-exit-sequence') {
                $md5 = [BitConverter]::ToString([Security.Cryptography.MD5]::Create().ComputeHash($p.Val)).Replace('-','')
                "      {0,-26} {1,5} o  md5={2}" -f $p.Prop, $p.Val.Length, $md5
            }
            elseif ($p.Val.Length -eq 4) {
                "      {0,-26} {1,10}   [{2}]" -f $p.Prop, (Rotate $p.Val 4), (Hex $p.Val)
            }
            else {
                "      {0,-26} {1,5} o   {2}" -f $p.Prop, $p.Val.Length, (Hex $p.Val)
            }
        }
    }

    # jeux de timings
    $groups = $props | Where-Object { $_.Node -match 'display-timings' -and $_.Node -match 'panel@0' } | Group-Object Node
    if ($groups) { "  --- jeux de timings" }
    foreach ($g in $groups) {
        $d = @{}
        foreach ($p in $g.Group) { $d[$p.Prop] = Rotate $p.Val 4 }
        $hz = if ($d['clock-frequency'] -and $d['hactive']) {
            $ht = $d['hactive'] + $d['hfront-porch'] + $d['hsync-len'] + $d['hback-porch']
            $vt = $d['vactive'] + $d['vfront-porch'] + $d['vsync-len'] + $d['vback-porch']
            [math]::Round($d['clock-frequency'] / ($ht * $vt), 2)
        } else { '?' }
        "      {0,-24} {1}x{2}  h={3}/{4}/{5}  v={6}/{7}/{8}  clk={9}  ~{10}Hz" -f `
            ($g.Name -replace '.*/display-timings',''), $d['hactive'], $d['vactive'], `
            $d['hfront-porch'], $d['hsync-len'], $d['hback-porch'], `
            $d['vfront-porch'], $d['vsync-len'], $d['vback-porch'], $d['clock-frequency'], $hz
    }
    ""
}

foreach ($p in $Path) { Inspect $p }
