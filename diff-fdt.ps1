param(
    [Parameter(Mandatory)][string]$A,
    [Parameter(Mandatory)][string]$B
)

function Load([string]$file) {
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
    $map = [ordered]@{}

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
            if ($pn -eq 'phandle' -or $pn -eq 'linux,phandle') { continue }
            $key = "$node|$pn"
            $map[$key] = $v
        }
        elseif ($tok -eq 4) { }
        else { $i = $end }
    }
    return $map
}

function Desc([byte[]]$v) {
    if ($null -eq $v) { return '<absent>' }
    if ($v.Length -eq 4) {
        $n = [uint32]((([int64]$v[0]) -shl 24) -bor (([int64]$v[1]) -shl 16) -bor (([int64]$v[2]) -shl 8) -bor ([int64]$v[3]))
        return "$n"
    }
    $s = [Text.Encoding]::ASCII.GetString($v)
    if ($s -match '^[\x20-\x7E\s]+$') { return '"' + ($s -replace '\x00', '", "') + '"' }
    return "($($v.Length)o) " + (([BitConverter]::ToString($v)) -replace '-','')
}

$ma = Load $A
$mb = Load $B

$aName = Split-Path $A -Leaf
$bName = Split-Path $B -Leaf

"=== $aName   vs   $bName ==="
""
$allKeys = @($ma.Keys) + @($mb.Keys) | Select-Object -Unique | Sort-Object

$diffs = 0
foreach ($k in $allKeys) {
    $va = $ma[$k]; $vb = $mb[$k]
    $da = Desc $va; $db = Desc $vb
    if ($da -ne $db) {
        $diffs++
        "$k"
        "    A: $da"
        "    B: $db"
    }
}
""
"proprietes differentes : $diffs"
