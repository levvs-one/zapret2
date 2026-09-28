# Downloads the pinned zapret2 release and assembles the engine directory
# that is bundled next to prosvet.exe.
param(
  [string]$Out = "build/engine"
)
$ErrorActionPreference = "Stop"

$Version = "v1.0.5.2"
$Sha256 = "f585590bea6da82ac2c74926f6ac17e6204ee8b53e455c2ba2edae0c58c5d4ac"
$Url = "https://github.com/bol-van/zapret2/releases/download/$Version/zapret2-$Version.zip"

$root = Split-Path -Parent $PSScriptRoot
$tmp = Join-Path ([IO.Path]::GetTempPath()) "prosvet-engine"
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $tmp | Out-Null

$zip = Join-Path $tmp "zapret2.zip"
Invoke-WebRequest -Uri $Url -OutFile $zip
$actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
if ($actual -ne $Sha256) { throw "zapret2 checksum mismatch: $actual" }
Expand-Archive -Path $zip -DestinationPath $tmp

$src = Join-Path $tmp "zapret2-$Version"
$dst = Join-Path $root $Out
Remove-Item -Recurse -Force $dst -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $dst, "$dst/lua", "$dst/lists", "$dst/windivert" | Out-Null

Copy-Item "$src/binaries/windows-x86_64/*" $dst
foreach ($f in "zapret-lib.lua", "zapret-antidpi.lua", "zapret-auto.lua") {
  Copy-Item "$src/lua/$f" "$dst/lua/"
}
Copy-Item "$src/docs/LICENSE.txt" "$dst/LICENSE.zapret2.txt"
Copy-Item "$root/engine/lua/*" "$dst/lua/"
Copy-Item "$root/engine/lists/*" "$dst/lists/"
Copy-Item "$root/engine/windivert/*" "$dst/windivert/"
Set-Content -Path "$dst/VERSION" -Value "zapret2 $Version"
Write-Host "engine ready: $dst"
