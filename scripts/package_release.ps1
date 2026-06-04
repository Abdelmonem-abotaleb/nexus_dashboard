param(
  [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$buildDir = Join-Path $root "build\windows\x64\runner\$Configuration"
$packageDir = Join-Path $root "dist"
$zipPath = Join-Path $packageDir "nexus_dashboard_windows_$($Configuration.ToLower()).zip"
$installerScript = Join-Path $root "scripts\nexus_dashboard.iss"

function Find-InnoCompiler {
  $command = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  $registryPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )
  foreach ($path in $registryPaths) {
    $install = Get-ItemProperty $path -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -like "Inno Setup*" -and $_.InstallLocation } |
      Select-Object -First 1 -ExpandProperty InstallLocation
    if ($install) {
      $candidate = Join-Path $install "ISCC.exe"
      if (Test-Path $candidate) {
        return $candidate
      }
    }
  }

  $fallbacks = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
  )
  foreach ($candidate in $fallbacks) {
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  return $null
}

Push-Location $root
try {
  flutter build windows --release
  New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
  if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
  }
  Compress-Archive -Path (Join-Path $buildDir "*") -DestinationPath $zipPath
  Write-Host "Packaged Nexus Dashboard: $zipPath"

  $iscc = Find-InnoCompiler
  if ($iscc) {
    & $iscc "/DProjectDir=$root" "/DSourceDir=$buildDir" "/DOutputDir=$packageDir" $installerScript
    Write-Host "Built Nexus Dashboard installer in $packageDir"
  } else {
    Write-Host "Inno Setup not found; skipped installer build. Install Inno Setup and rerun this script to create the .exe installer."
  }
} finally {
  Pop-Location
}
