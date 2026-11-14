param(
    [Parameter(Mandatory)][string]$In,
    [Parameter(Mandatory)][string]$Out,
    [Parameter(Mandatory)][string]$Prop,
    [Parameter(Mandatory)][string]$PathSuffix,
    [Parameter(Mandatory)][int]$From,
    [Parameter(Mandatory)][int]$To
)

$b = [IO.File]::ReadAllBytes($In)

function BE([int]$o) {
    [uint32]((([int64]$b[$o]) -shl 24) -bor (([int64]$b[$o+1]) -shl 16) -bor (([int64]$b[$o+2]) -shl 8) -bor ([int64]$b[$o+3]))
}

if ($b[0] -ne 0xD0 -or $b[1] -ne 0x0D -or $b[2] -ne 0xFE -or $b[3] -ne 0xED) { throw "not a FDT" }
$offStruct = [int](BE 8); $offStrings = [int](BE 12)
$sizeStrings = [int](BE 32); $sizeStruct = [int](BE 36)
$strings = [Text.Encoding]::ASCII.GetString($b, $offStrings, $sizeStrings)

$stack = New-Object System.Collections.Stack
$i = $offStruct; $end = $offStruct + $sizeStruct
$nodePath = ""
$hits = @()

while ($i -lt $end) {
    $tok = [int](BE $i); $i += 4
    if ($tok -eq 1) {
        $z = $i; while ($b[$z] -ne 0) { $z++ }
        $nm = [Text.Encoding]::ASCII.GetString($b, $i, $z - $i)
        $i += ((($z - $i + 1) + 3) -band (-bnot 3))
        $stack.Push($nm)
        $arr = @($stack.ToArray())
        [Array]::Reverse($arr)
        $nodePath = "/" + (($arr | Where-Object { $_ -ne "" }) -join "/")
    }
    elseif ($tok -eq 2) { if ($stack.Count) { $null = $stack.Pop() } }
    elseif ($tok -eq 3) {
        $len = [int](BE $i); $no = [int](BE ($i + 4)); $i += 8
        $z = $strings.IndexOf([char]0, $no); $pn = $strings.Substring($no, $z - $no)
        if ($pn -eq $Prop -and $nodePath.EndsWith($PathSuffix) -and $len -eq 4) {
            $val = [int](BE $i)
            $hits += [pscustomobject]@{ Offset = $i; Value = $val; Path = $nodePath }
        }
        $i += (($len + 3) -band (-bnot 3))
    }
    elseif ($tok -eq 4) { }
    else { $i = $end }
}

if ($hits.Count -ne 1) {
    throw ("attendu 1 propriete, trouve {0} : {1}" -f $hits.Count, (($hits | ForEach-Object { "$($_.Path)=$($_.Value)" }) -join ' ; '))
}
$h = $hits[0]
if ($h.Value -ne $From) { throw ("valeur inattendue : {0} (attendu {1})" -f $h.Value, $From) }

"cible : {0}" -f $h.Path
"offset valeur = 0x{0:X}  {1} -> {2}" -f $h.Offset, $From, $To

$new = [byte[]]$b.Clone()
$new[$h.Offset]   = [byte](($To -shr 24) -band 0xFF)
$new[$h.Offset+1] = [byte](($To -shr 16) -band 0xFF)
$new[$h.Offset+2] = [byte](($To -shr 8)  -band 0xFF)
$new[$h.Offset+3] = [byte]($To -band 0xFF)

# verification : seuls 4 octets doivent differer
$diffs = @()
for ($k = 0; $k -lt $b.Length; $k++) { if ($b[$k] -ne $new[$k]) { $diffs += $k } }
"octets modifies : {0} -> {1}" -f $diffs.Count, (($diffs | ForEach-Object { '0x{0:X}' -f $_ }) -join ',')
foreach ($d in $diffs) {
    if ($d -lt $h.Offset -or $d -ge ($h.Offset + 4)) { throw ("octet modifie hors zone : 0x{0:X}" -f $d) }
}

[IO.File]::WriteAllBytes($Out, $new)
"ecrit : $Out ($($new.Length) octets)"
