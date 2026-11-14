param([Parameter(Mandatory)][string[]]$Path)

function Dump([string]$file) {
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
    $phandles = @{}   # phandle int -> path
    $native = @()     # objects

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
            if ($len -eq 4) {
                $val = [uint32]((([int64]$b[$i]) -shl 24) -bor (([int64]$b[$i+1]) -shl 16) -bor (([int64]$b[$i+2]) -shl 8) -bor ([int64]$b[$i+3]))
                if ($pn -eq 'phandle' -or $pn -eq 'linux,phandle') { $phandles[[int]$val] = $node }
                if ($pn -eq 'native-mode') { $native += [pscustomobject]@{ Offset = $i; Value = [int]$val; Node = $node } }
            }
            $i += (($len + 3) -band (-bnot 3))
        }
        elseif ($tok -eq 4) { }
        else { $i = $end }
    }

    "=== $([IO.Path]::GetFileName($file)) ==="
    foreach ($n in $native) {
        $tgt = $phandles[$n.Value]
        "  native-mode = $($n.Value)  (offset 0x{0:X})" -f $n.Offset
        "    -> phandle $($n.Value) : " + $(if ($tgt) { $tgt } else { '(introuvable)' })
    }
}

foreach ($p in $Path) { Dump $p }
