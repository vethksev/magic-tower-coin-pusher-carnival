param(
    [string]$Tpz = "",
    [string]$Version = "4.7.1.stable"
)
$ErrorActionPreference = 'Stop'
$dest = Join-Path $env:APPDATA "Godot/export_templates/$Version"
if (Test-Path (Join-Path $dest 'windows_release_x86_64.exe')) {
    Write-Host "Templates already installed at $dest"
    exit 0
}
$tag = $Version.Replace('.stable', '-stable')
if (-not $Tpz) {
    $Tpz = Join-Path $env:TEMP "Godot_v${tag}_export_templates.tpz"
    if (-not (Test-Path $Tpz)) {
        $url = "https://github.com/godotengine/godot/releases/download/$tag/Godot_v${tag}_export_templates.tpz"
        Write-Host "Downloading $url"
        Invoke-WebRequest -Uri $url -OutFile $Tpz
    }
}
$tmp = Join-Path $env:TEMP "godot-templates-extract"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force $tmp | Out-Null
$zip = "$Tpz.zip"
Copy-Item $Tpz $zip -Force
Expand-Archive -Path $zip -DestinationPath $tmp -Force
New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
Move-Item (Join-Path $tmp 'templates') $dest
Remove-Item $zip -Force
Write-Host "Installed to $dest"
Get-ChildItem $dest -Filter 'windows_*x86_64.exe' | ForEach-Object { Write-Host $_.Name }
