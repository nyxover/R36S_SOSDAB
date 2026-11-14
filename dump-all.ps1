param([Parameter(Mandatory)][string]$Path, [string]$Filter = '')

$b = [IO.File]::ReadAllBytes($Path)
function BE([int]$o) {
    [uint32]((([int64]$b[$o]) -shl 24) -bor (([int64]$b[$o+1]) -shl 16) -bor (([int64]$b[$o+2]) -shl 8) -bor ([int64]$b[$o+3]))
}
$offStruct = [int](BE 8); $offStrings = [int](BE 12)
$sizeStrings = [int](BE 32); $sizeStruct = [int](BE 36)
$strings = [Text.Encoding]::ASCII.GetString($b, $offStrings, $sizeStrings)

$stack = New-Object System.Collections.Stack
$i = $offStruct; $end = $offStruct + $sizeStruct
$node = '/'

function Show([byte[]]$v) {
    if ($v.Length -eq 4) {
        return "= " + [uint32]((([int64]$v[0]) -shl 24) -bor (([int64]$v[1]) -shl 16) -bor (([int64]$v[2]) -shl 8) -bor ([int64]$v[3]))
    }
    $s = [Text.Encoding]::ASCII.GetString($v)
    if ($s -match '^[\x20-\x7E\s]+$' -and $s.Length -gt 0) { return '= "' + ($s -replace '\x00', '", "') + '"' }
    $n = [Math]::Min($v.Length, 12)
    return "($($v.Length)o) " + (($v[0..($n-1)] | ForEach-Object { '{0:X2}' -f $_ }) -join ' ')
}

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
        if ($Filter -eq '' -or $node -match $Filter) { ""; "NODE $node" }
    }
    elseif ($tok -eq 2) { if ($stack.Count) { $null = $stack.Pop() } }
    elseif ($tok -eq 3) {
        $len = [int](BE $i); $no = [int](BE ($i + 4)); $i += 8
        $z = $strings.IndexOf([char]0, $no); $pn = $strings.Substring($no, $z - $no)
        $v = New-Object byte[] $len
        if ($len -gt 0) { [Array]::Copy($b, $i, $v, 0, $len) }
        $i += (($len + 3) -band (-bnot 3))
        if ($Filter -eq '' -or $node -match $Filter) { "    {0,-28} {1}" -f $pn, (Show $v) }
    }
    elseif ($tok -eq 4) { }
    else { $i = $end }
}
