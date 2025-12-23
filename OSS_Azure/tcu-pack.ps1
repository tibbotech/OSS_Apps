param(
  [string]$Dir = ".",
  [string]$OutFile,
  [string]$ReleaseTag
)
$TIOS_PATH = '.\OSS_Azure_APP1\Platforms\WM2000\firmware\tios-wm2000-4_03_08.bin'
$APP0_PATH = '.\OSS_Azure_APP0\OSS_Azure_APP0.tpc'
$APP1_PATH = '.\OSS_Azure_APP1\OSS_Azure_APP1.tpc'
$ErrorActionPreference = 'Stop'
function RB($p){ [IO.File]::ReadAllBytes($p) }
function SigB($b,$len){ $lim = [Math]::Min($len,$b.Length); $b[0..($lim-1)] }
function FindStart($hay,[byte[]]$sig){ for($i=0;$i -le $hay.Length - $sig.Length;$i++){ $m=$true; for($j=0;$j -lt $sig.Length;$j++){ if($hay[$i+$j] -ne $sig[$j]){ $m=$false; break } } if($m){ return $i } } return -1 }
function PadToBlock([byte[]]$data,[int]$block){ if($data.Length % $block -ne 0){ $pad = $block - ($data.Length % $block); $out = New-Object byte[] ($data.Length + $pad); [Array]::Copy($data,0,$out,0,$data.Length); return $out } else { return $data } }
if([string]::IsNullOrWhiteSpace($Dir)){ $Dir = "." }
$fwPath = $TIOS_PATH
if(-not (Test-Path $fwPath)){ throw "Firmware file not found: $fwPath" }
$app0Path = $APP0_PATH
$app1Path = $APP1_PATH
if(-not (Test-Path $app0Path)){ throw "Missing APP0 file: $app0Path" }
if(-not (Test-Path $app1Path)){ throw "Missing APP1 file: $app1Path" }
$relDir = $null
if(-not [string]::IsNullOrWhiteSpace($ReleaseTag)){
  $m = [regex]::Match($ReleaseTag, '(\d+)\.(\d{2})\.(\d{2})')
  if(-not $m.Success){ throw "Invalid ReleaseTag: $ReleaseTag" }
  $major = $m.Groups[1].Value
  $minor = $m.Groups[2].Value
  $patch = $m.Groups[3].Value
  $verUnderscores = "$major`_$minor`_$patch"
  $verHyphens = "$major-$minor-$patch"
  $relRoot = '.\Release_Files'
  $relDir = Join-Path $relRoot $verUnderscores
  if(-not (Test-Path $relDir)){ New-Item -ItemType Directory -Path $relDir | Out-Null }
  if([string]::IsNullOrWhiteSpace($OutFile)){
    $OutFile = Join-Path $relDir ("OSS_Azure_FW_" + $verHyphens + ".tcu")
  }
}
if([string]::IsNullOrWhiteSpace($OutFile)){
  $fwName = Split-Path -Leaf $fwPath
  $ver = ($fwName -replace '^tios-wm2000-','' -replace '\.bin$','' -replace '_','.')
  $OutFile = Join-Path (Split-Path -Parent $fwPath) ("WM2000-tios-" + $ver + ".tcu")
}
$bFwB = RB $fwPath
$bA0B = RB $app0Path
$bA1B = RB $app1Path
# Build UNCOMPRESSED_TIOS_APP with manifest header (reference-free)
$BLOCK_SIZE = 4096
$app0Padded = PadToBlock $bA0B $BLOCK_SIZE
$app1Padded = PadToBlock $bA1B $BLOCK_SIZE
$tiosAndApps = New-Object byte[] ($bFwB.Length + $app0Padded.Length + $app1Padded.Length)
[Array]::Copy($bFwB,0,$tiosAndApps,0,$bFwB.Length)
[Array]::Copy($app0Padded,0,$tiosAndApps,$bFwB.Length,$app0Padded.Length)
[Array]::Copy($app1Padded,0,$tiosAndApps,$bFwB.Length+$app0Padded.Length,$app1Padded.Length)
# Manifest fields
$MANIFEST_VERSION = "01.00.00"
$deviceType = "WM2000"
$fwName2 = Split-Path -Leaf $fwPath
$tiosVersion = ($fwName2 -replace '^tios-\w+-','' -replace '\.bin$','' -replace '_','.')
$fields = @($deviceType,"","",$tiosVersion,"","","","","",$MANIFEST_VERSION)
$enc = [Text.Encoding]::ASCII
$manifestSize = 0
$fieldBytes = @()
foreach($f in $fields){ $bytes = $enc.GetBytes($f); $fieldBytes += ,$bytes; $manifestSize += 2 + $bytes.Length }
$msManifest = New-Object System.IO.MemoryStream
foreach($bytes in $fieldBytes){ $lenBytes = [BitConverter]::GetBytes([UInt16]$bytes.Length); $msManifest.Write($lenBytes,0,$lenBytes.Length); $msManifest.Write($bytes,0,$bytes.Length) }
$manifestBuf = $msManifest.ToArray()
# Compose container: numFiles=2 (manifest, UNCOMPRESSED_TIOS_APP)
$items = @(
    @{ type = 9; data = $manifestBuf },
    @{ type = 6; data = $tiosAndApps }
)
$fileLength = 0
foreach($it in $items){ $fileLength += 12 + $it.data.Length }
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([Int32]$items.Length)
$bw.Write([Int32]$fileLength)
foreach($it in $items){
  $sum = [UInt32]0
  foreach($b in $it.data){ $sum = ($sum + $b) }
  $checksum = [UInt32](((-bnot $sum) + 1) -band 0xFFFFFFFF)
  $bw.Write([Int32]$it.type)
  $bw.Write([Int32]$it.data.Length)
  $bw.Write([UInt32]$checksum)
  $bw.Write($it.data)
}
$bw.Flush(); $bw.Dispose()
[IO.File]::WriteAllBytes($OutFile, $ms.ToArray())
# Copy app files to output directory
$outDir = Split-Path -Parent $OutFile
Copy-Item -Path $app0Path -Destination (Join-Path $outDir 'OSS_Azure_APP0.tpc') -Force
Copy-Item -Path $app1Path -Destination (Join-Path $outDir 'OSS_Azure_APP1.tpc') -Force
# Verify offsets
$outB = RB $OutFile
$oFw = FindStart $outB (SigB $bFwB 512)
$oA0 = FindStart $outB (SigB $bA0B 256)
$oA1 = FindStart $outB (SigB $bA1B 256)
Write-Host ("Created: " + $OutFile)
Write-Host ("fwStart="+$oFw+" a0Start="+$oA0+" a1Start="+$oA1+" totalLen="+$outB.Length)