param(
    [string]$Godot = 'D:/Tools/Godot/4.7.1/Godot_v4.7.1-stable_win64_console.exe',
    [ValidatePattern('^[0-9]+\.[0-9]+(?:\.[0-9]+)?$')]
    [string]$Version = '0.1.0',
    [switch]$SkipZip
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$buildRoot = Join-Path $projectRoot ('windows-v' + $Version)
$presetFile = Join-Path $projectRoot 'export_presets.cfg'
$exeFile = Join-Path $buildRoot 'MagicTowerCoinPusher.exe'
$zipFile = Join-Path (Split-Path $projectRoot -Parent) ('MagicTowerCoinPusher-Windows-v' + $Version + '.zip')

if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot'))) { throw 'project.godot not found beside tools/.' }
if (-not (Test-Path -LiteralPath $Godot)) { throw "Godot not found: $Godot" }
$templateRoot = Join-Path $env:APPDATA 'Godot/export_templates/4.7.1.stable'
$releaseTemplate = Join-Path $templateRoot 'windows_release_x86_64.exe'
$debugTemplate = Join-Path $templateRoot 'windows_debug_x86_64.exe'
if (-not (Test-Path -LiteralPath $releaseTemplate)) { throw "Run tools/install_export_templates.ps1 first. Missing: $releaseTemplate" }

New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$originalPresets = Get-Content -LiteralPath $presetFile -Raw
$configured = $originalPresets.Replace('custom_template/release=""', 'custom_template/release="' + $releaseTemplate.Replace('\', '/') + '"')
$configured = $configured.Replace('custom_template/debug=""', 'custom_template/debug="' + $debugTemplate.Replace('\', '/') + '"')
$parts = @($Version.Split('.')); while ($parts.Count -lt 4) { $parts += '0' }
$fileVersion = $parts -join '.'
$configured = [regex]::Replace($configured, '(?m)^application/(file_version|product_version)="[^"]*"', { param($m) 'application/' + $m.Groups[1].Value + '="' + $fileVersion + '"' })
$configured = [regex]::Replace($configured, '(?m)^export_path="[^"]*"', 'export_path="windows-v' + $Version + '/MagicTowerCoinPusher.exe"')
$started = Get-Date
try {
    [System.IO.File]::WriteAllText($presetFile, $configured, [System.Text.UTF8Encoding]::new($false))
    $log = Join-Path $buildRoot 'export.log'
    $err = Join-Path $buildRoot 'export.errors.log'
    $p = Start-Process -FilePath $Godot -ArgumentList @('--headless', '--path', ('"' + $projectRoot + '"'), '--export-release', '"Windows Desktop"', ('"' + $exeFile + '"')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $log -RedirectStandardError $err
    if ($p.ExitCode -ne 0) { Get-Content $err | Write-Host; throw "Export failed with exit code $($p.ExitCode)" }
    $bad = Select-String -LiteralPath $log, $err -Pattern '(^|\s)(SCRIPT ERROR|ERROR):'
    if ($bad) { $bad | ForEach-Object { Write-Host $_.Line }; throw 'Export reported engine errors.' }
    $exe = Get-Item -LiteralPath $exeFile
    if ($exe.Length -lt 1000000 -or $exe.LastWriteTime -lt $started) { throw 'No fresh executable produced.' }
    Write-Host ("EXE: {0} ({1:N1} MB)" -f $exeFile, ($exe.Length / 1MB))
} finally {
    [System.IO.File]::WriteAllText($presetFile, $originalPresets, [System.Text.UTF8Encoding]::new($false))
}
if (-not $SkipZip) {
    if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
    Compress-Archive -Path (Join-Path $buildRoot '*.exe') -DestinationPath $zipFile
    Write-Host "ZIP: $zipFile"
}
