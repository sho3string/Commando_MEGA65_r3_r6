param(
    [string]$Zip = "commando.zip",
    [string]$Out = "commando_roms"
)

$ErrorActionPreference = "Stop"

# Always resolve relative input/output paths from the directory containing
# this script, rather than PowerShell's current working directory.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not [IO.Path]::IsPathRooted($Zip)) {
    $Zip = Join-Path $ScriptDir $Zip
}
if (-not [IO.Path]::IsPathRooted($Out)) {
    $Out = Join-Path $ScriptDir $Out
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$Expected = @{
    "cm04.9m"  = @(0x8000, 0x8438B694L); "cm03.8m"  = @(0x4000, 0x35486542L)
    "cm02.9f"  = @(0x4000, 0xF9CC4A74L); "vt01.5d"  = @(0x4000, 0x505726E0L)
    "vt05.7e"  = @(0x4000, 0x79F16E3DL); "vt06.8e"  = @(0x4000, 0x26FEE521L)
    "vt07.9e"  = @(0x4000, 0xCA88BDFDL); "vt08.7h"  = @(0x4000, 0x2019C883L)
    "vt09.8h"  = @(0x4000, 0x98703982L); "vt10.9h"  = @(0x4000, 0xF069D2F8L)
    "vt11.5a"  = @(0x4000, 0x7B2E1B48L); "vt12.6a"  = @(0x4000, 0x81B417D3L)
    "vt13.7a"  = @(0x4000, 0x5612DBD2L); "vt14.8a"  = @(0x4000, 0x2B2DEE36L)
    "vt15.9a"  = @(0x4000, 0xDE70BABFL); "vt16.10a" = @(0x4000, 0x14178237L)
    "vtb1.1d"  = @(0x100, 0x3ABA15A1L); "vtb2.2d"  = @(0x100, 0x88865754L)
    "vtb3.3d"  = @(0x100, 0x4C14C3F6L); "vtb4.1h"  = @(0x100, 0xB388C246L)
    "vtb5.6l"  = @(0x100, 0x712AC508L); "vtb6.6e"  = @(0x100, 0x0EAF5158L)
}

function Get-Crc32([byte[]]$Data) {
    [uint64]$crc = 0xFFFFFFFFL
    foreach ($b in $Data) {
        $crc = $crc -bxor [uint64]$b
        for ($i=0; $i -lt 8; $i++) {
            if ($crc -band 1) {
                $crc = (($crc -shr 1) -bxor 0xEDB88320L) -band 0xFFFFFFFFL
            }
            else {
                $crc = ($crc -shr 1) -band 0xFFFFFFFFL
            }
        }
    }
    return [uint32](($crc -bxor 0xFFFFFFFFL) -band 0xFFFFFFFFL)
}

function Interleave([byte[][]]$Lanes) {
    $len = $Lanes[0].Length
    foreach ($lane in $Lanes) {
        if ($lane.Length -ne $len) { throw "lane sizes differ" }
    }
    $out = [byte[]]::new($len * $Lanes.Count)
    for ($i=0; $i -lt $len; $i++) {
        for ($j=0; $j -lt $Lanes.Count; $j++) {
            $out[$i*$Lanes.Count+$j] = $Lanes[$j][$i]
        }
    }
    return $out
}

function Join-Bytes([byte[][]]$Parts) {
    $total = 0
    foreach ($p in $Parts) { $total += $p.Length }
    $out = [byte[]]::new($total)
    $pos = 0
    foreach ($p in $Parts) {
        [Array]::Copy($p, 0, $out, $pos, $p.Length)
        $pos += $p.Length
    }
    return $out
}

function Swap16([byte[]]$Data) {
    $out = [byte[]]::new($Data.Length)
    for ($i=0; $i -lt $Data.Length; $i+=2) {
        $out[$i] = $Data[$i+1]
        $out[$i+1] = $Data[$i]
    }
    return $out
}

function GfxSort-Hvvvvxx([byte[]]$Data) {
    $out = [byte[]]::new($Data.Length)
    for ($src=0; $src -lt $Data.Length; $src++) {
        $dst = $src -band (-bnot 0x7C)
        $dst = $dst -bor ((($src -shr 6) -band 1) -shl 2)
        $dst = $dst -bor ((($src -shr 2) -band 1) -shl 3)
        $dst = $dst -bor ((($src -shr 3) -band 1) -shl 4)
        $dst = $dst -bor ((($src -shr 4) -band 1) -shl 5)
        $dst = $dst -bor ((($src -shr 5) -band 1) -shl 6)
        $out[$dst] = $Data[$src]
    }
    return $out
}

New-Item -ItemType Directory -Force -Path $Out | Out-Null

$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $Zip))
try {
    $R = @{}
    foreach ($name in $Expected.Keys) {
        $entry = $archive.Entries | Where-Object FullName -eq $name
        if (-not $entry) { throw "Missing ROM: $name" }

        $ms = [IO.MemoryStream]::new()
        $stream = $entry.Open()
        try { $stream.CopyTo($ms) } finally { $stream.Dispose() }
        [byte[]]$data = $ms.ToArray()
        $ms.Dispose()

        $wantSize = $Expected[$name][0]
        [uint32]$wantCrc = $Expected[$name][1]
        [uint32]$gotCrc = Get-Crc32 $data
        if ($data.Length -ne $wantSize -or $gotCrc -ne $wantCrc) {
            throw ("{0}: expected 0x{1:X}/CRC {2:X8}, got 0x{3:X}/CRC {4:X8}" -f
                $name,$wantSize,$wantCrc,$data.Length,$gotCrc)
        }
        $R[$name] = $data
    }
}
finally { $archive.Dispose() }

$main = Join-Bytes @($R["cm04.9m"], $R["cm03.8m"])
$sound = $R["cm02.9f"]
$char = Swap16 $R["vt01.5d"]

$objUnsorted = Join-Bytes @(
    (Interleave @($R["vt08.7h"], $R["vt05.7e"])),
    (Interleave @($R["vt09.8h"], $R["vt06.8e"])),
    (Interleave @($R["vt10.9h"], $R["vt07.9e"]))
)
$obj = GfxSort-Hvvvvxx $objUnsorted

$tiles = Join-Bytes @(
    (Interleave @($R["vt11.5a"],$R["vt13.7a"],$R["vt15.9a"],$R["vt15.9a"])),
    (Interleave @($R["vt12.6a"],$R["vt14.8a"],$R["vt16.10a"],$R["vt16.10a"]))
)

$prom = Join-Bytes @(
    $R["vtb1.1d"],$R["vtb2.2d"],$R["vtb3.3d"],$R["vtb4.1h"],$R["vtb6.6e"]
)
$irq = $R["vtb5.6l"]

$Outputs = @{
    "commando_main.rom"  = $main
    "commando_sound.rom" = $sound
    "commando_char.rom"  = $char
    "commando_obj.rom"   = $obj
    "commando_tiles.rom" = $tiles
    "commando_prom.rom"  = $prom
    "commando_irq.rom"   = $irq
}

foreach ($name in $Outputs.Keys) {
    $path = Join-Path $Out $name
    [IO.File]::WriteAllBytes($path, $Outputs[$name])
    "{0,-22} {1:X6}" -f $name,$Outputs[$name].Length
}
