$src = 'C:\Users\buire\Downloads\r36s\rk3326-gameconsole-r36s-panel3.dtb'
$report = 'C:\Users\buire\AppData\Local\Temp\opencode\r36s\panel3-desc-clean.txt'
$b = [IO.File]::ReadAllBytes($src)

function BE([int]$o) {
    [uint32]((([int64]$b[$o]) -shl 24) -bor (([int64]$b[$o+1]) -shl 16) -bor (([int64]$b[$o+2]) -shl 8) -bor ([int64]$b[$o+3]))
}
$offStruct = [int](BE 8); $offStrings = [int](BE 12)
$sizeStrings = [int](BE 32); $sizeStruct = [int](BE 36)
$strings = [Text.Encoding]::ASCII.GetString($b, $offStrings, $sizeStrings)

$stack = New-Object System.Collections.Stack
$i = $offStruct; $end = $offStruct + $sizeStruct
$node = '/'
$out = New-Object System.Collections.Generic.List[string]

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
        if ($pn -eq 'panel_description') {
            $sb = New-Object System.Text.StringBuilder
            foreach ($byte in $v) {
                if ($byte -eq 10) { [void]$sb.Append([char]10) }
                elseif ($byte -eq 13) { }
                elseif ($byte -ge 32 -and $byte -le 126) { [void]$sb.Append([char]$byte) }
                else { [void]$sb.Append([char]32) }
            }
            $out.Add("VALEUR DE panel_description (noeud " + $node + ", " + $len + " octets)")
            $out.Add("================================================================")
            $out.Add($sb.ToString())
            $out.Add("================================================================")
        }
    }
    elseif ($tok -eq 4) { }
    else { $i = $end }
}

$out | Set-Content -LiteralPath $report -Encoding ASCII
