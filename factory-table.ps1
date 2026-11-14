param([Parameter(Mandatory)][string[]]$Path)

$rows = @()

foreach ($file in $Path) {
    $b = [IO.File]::ReadAllBytes($file)
    if ($b.Length -lt 40) { continue }
    if (-not ($b[0] -eq 0xD0 -and $b[1] -eq 0x0D -and $b[2] -eq 0xFE -and $b[3] -eq 0xED)) { continue }

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

    $u32 = {
        param($v)
        if ($v.Length -ne 4) { return $null }
        [uint32]((([int64]$v[0]) -shl 24) -bor (([int64]$v[1]) -shl 16) -bor (([int64]$v[2]) -shl 8) -bor ([int64]$v[3]))
    }

    $panel = $props | Where-Object { $_.Node -eq '/dsi@ff450000/panel@0' }
    $get = { param($n) $p = $panel | Where-Object { $_.Prop -eq $n } | Select-Object -First 1; if ($p) { & $u32 $p.Val } else { $null } }

    $init = $panel | Where-Object { $_.Prop -eq 'panel-init-sequence' } | Select-Object -First 1
    $initMd5 = if ($init) { [BitConverter]::ToString([Security.Cryptography.MD5]::Create().ComputeHash($init.Val)).Replace('-','') } else { '' }

    $phandles = @{}
    foreach ($p in $props) { if (($p.Prop -eq 'phandle' -or $p.Prop -eq 'linux,phandle') -and $p.Val.Length -eq 4) { $phandles[[int](& $u32 $p.Val)] = $p.Node } }
    $nm = $props | Where-Object { $_.Prop -eq 'native-mode' -and $_.Node -match 'display-timings$' } | Select-Object -First 1
    $nmName = if ($nm) { $k = [int](& $u32 $nm.Val); if ($phandles[$k]) { ($phandles[$k] -split '/')[-1] } else { "?$k" } } else { '-' }

    $groups = $props | Where-Object { $_.Node -match 'display-timings' -and $_.Node -match 'panel@0' -and $_.Node -ne '/dsi@ff450000/panel@0/display-timings' } | Group-Object Node
    $desc = @()
    foreach ($g in $groups) {
        $d = @{}
        foreach ($p in $g.Group) { $d[$p.Prop] = & $u32 $p.Val }
        if (-not $d['hactive']) { continue }
        $ht = $d['hactive'] + $d['hfront-porch'] + $d['hsync-len'] + $d['hback-porch']
        $vt = $d['vactive'] + $d['vfront-porch'] + $d['vsync-len'] + $d['vback-porch']
        $hz = [math]::Round($d['clock-frequency'] / ($ht * $vt), 2)
        $desc += ("{0}:{1}Hz(h{2}/{3}/{4} v{5}/{6}/{7} c{8})" -f ($g.Name -split '/')[-1], $hz, $d['hfront-porch'], $d['hsync-len'], $d['hback-porch'], $d['vfront-porch'], $d['vsync-len'], $d['vback-porch'], $d['clock-frequency'])
    }

    $rows += [pscustomobject]@{
        Fichier  = Split-Path $file -Parent | Split-Path -Leaf
        Taille   = $b.Length
        Init     = "$($init.Val.Length)o/$($initMd5.Substring(0,8))"
        Prep     = & $get 'prepare-delay-ms'
        Reset    = & $get 'reset-delay-ms'
        InitD    = & $get 'init-delay-ms'
        En      = & $get 'enable-delay-ms'
        Native   = $nmName
        Timings  = ($desc -join ' ')
    }
}

$rows | Format-Table -AutoSize -Wrap Fichier, Taille, Init, Prep, Reset, InitD, En, Native
""
foreach ($r in $rows) { "{0,-46} {1}" -f $r.Fichier, $r.Timings }
