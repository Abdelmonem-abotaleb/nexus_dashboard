import 'dart:io';

String resolveWindowsPath(String path) {
  return path.replaceAll('%USERNAME%', Platform.environment['USERNAME'] ?? '');
}

bool isUwpOrProtocol(String path) {
  if (path.startsWith('shell:')) return true;
  if (RegExp(r'^[A-Za-z]:').hasMatch(path)) return false;
  if (Uri.tryParse(path)?.hasScheme ?? false) return true;
  return path.isNotEmpty && !path.contains('\\') && !path.contains('/');
}

bool isAppxAppUserModelId(String path) {
  return path.contains('!') && !path.contains('\\') && !path.contains('/');
}

Future<String> extractWindowsAppIcon({
  required String executablePath,
  required String appId,
}) async {
  if (!Platform.isWindows) return '';

  final resolvedPath = resolveWindowsPath(executablePath);
  if (isAppxAppUserModelId(resolvedPath)) {
    return _extractWindowsStoreAppIcon(
      appUserModelId: resolvedPath,
      appId: appId,
    );
  }
  if (isUwpOrProtocol(resolvedPath)) {
    return resolvedPath.contains(':')
        ? ''
        : _extractWindowsShellShortcutIcon(
            appUserModelId: resolvedPath,
            appId: appId,
          );
  }
  if (!File(resolvedPath).existsSync()) {
    return '';
  }

  final appData = Platform.environment['APPDATA'];
  if (appData == null || appData.isEmpty) return '';

  final iconDir = Directory('$appData\\NexusDashboard\\icons');
  if (!iconDir.existsSync()) {
    iconDir.createSync(recursive: true);
  }

  final safeId = appId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  final iconPath = '${iconDir.path}\\$safeId.png';

  final result = await Process.run(
    'powershell',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      r'''
Add-Type -AssemblyName System.Drawing
$exePath = $env:NEXUS_ICON_EXE_PATH
$outputPath = $env:NEXUS_ICON_OUTPUT_PATH
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon($exePath)
if ($null -eq $icon) { exit 2 }
$bitmap = $icon.ToBitmap()
$bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bitmap.Dispose()
$icon.Dispose()
''',
    ],
    environment: {
      'NEXUS_ICON_EXE_PATH': resolvedPath,
      'NEXUS_ICON_OUTPUT_PATH': iconPath,
    },
  );

  if (result.exitCode == 0 && File(iconPath).existsSync()) {
    return iconPath;
  }
  return '';
}

Future<String> _extractWindowsShellShortcutIcon({
  required String appUserModelId,
  required String appId,
}) async {
  final appData = Platform.environment['APPDATA'];
  if (appData == null || appData.isEmpty) return '';

  final iconDir = Directory('$appData\\NexusDashboard\\icons');
  if (!iconDir.existsSync()) {
    iconDir.createSync(recursive: true);
  }

  final safeId = appId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  final iconPath = '${iconDir.path}\\$safeId.png';
  final result = await Process.run(
    'powershell',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      r'''
Add-Type -AssemblyName System.Drawing

$appUserModelId = $env:NEXUS_APP_AUMID
$outputPath = $env:NEXUS_ICON_OUTPUT_PATH
$shell = New-Object -ComObject Shell.Application
$shortcuts = New-Object -ComObject WScript.Shell
$roots = @(
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs",
  "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
)

foreach ($root in $roots) {
  if (-not (Test-Path -LiteralPath $root)) { continue }
  foreach ($link in Get-ChildItem -LiteralPath $root -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue) {
    $folder = $shell.Namespace($link.DirectoryName)
    if ($null -eq $folder) { continue }
    $item = $folder.ParseName($link.Name)
    if ($null -eq $item -or $item.ExtendedProperty('System.AppUserModel.ID') -ne $appUserModelId) {
      continue
    }

    $iconLocation = $shortcuts.CreateShortcut($link.FullName).IconLocation
    $iconFile = $iconLocation -replace ',\s*-?\d+$', ''
    if (-not (Test-Path -LiteralPath $iconFile)) { continue }

    $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconFile)
    if ($null -eq $icon) { continue }
    $bitmap = $icon.ToBitmap()
    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bitmap.Dispose()
    $icon.Dispose()
    exit 0
  }
}
exit 2
''',
    ],
    environment: {
      'NEXUS_APP_AUMID': appUserModelId,
      'NEXUS_ICON_OUTPUT_PATH': iconPath,
    },
  );

  if (result.exitCode == 0 && File(iconPath).existsSync()) {
    return iconPath;
  }
  return '';
}

Future<String> _extractWindowsStoreAppIcon({
  required String appUserModelId,
  required String appId,
}) async {
  final appData = Platform.environment['APPDATA'];
  if (appData == null || appData.isEmpty) return '';

  final iconDir = Directory('$appData\\NexusDashboard\\icons');
  if (!iconDir.existsSync()) {
    iconDir.createSync(recursive: true);
  }

  final safeId = appId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  final iconPath = '${iconDir.path}\\$safeId.png';

  final result = await Process.run(
    'powershell',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      r'''
Add-Type -AssemblyName System.Drawing

function Resolve-AppAsset {
  param([string]$InstallLocation, [string]$Logo)
  if ([string]::IsNullOrWhiteSpace($InstallLocation) -or [string]::IsNullOrWhiteSpace($Logo)) {
    return $null
  }

  $assetPath = Join-Path $InstallLocation ($Logo -replace '/', '\')
  $dir = Split-Path $assetPath -Parent
  $name = [System.IO.Path]::GetFileNameWithoutExtension($assetPath)
  $ext = [System.IO.Path]::GetExtension($assetPath)
  $candidates = @(
    "$dir\$name.targetsize-256$ext",
    "$dir\$name.targetsize-256_altform-unplated$ext",
    "$dir\$name.targetsize-256_altform-lightunplated$ext",
    "$dir\$name.targetsize-128$ext",
    "$dir\$name.targetsize-96_altform-unplated$ext",
    "$dir\$name.targetsize-96$ext",
    "$dir\$name.targetsize-48_altform-unplated$ext",
    "$dir\$name.targetsize-48$ext",
    "$dir\$name.scale-400$ext",
    "$dir\$name.scale-200$ext",
    "$dir\$name.scale-150$ext",
    "$dir\$name.scale-100$ext",
    $assetPath
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  $fallback = Get-ChildItem -LiteralPath $dir -Filter "$name*$ext" -ErrorAction SilentlyContinue |
    Sort-Object Length -Descending |
    Select-Object -First 1
  if ($fallback) { return $fallback.FullName }
  return $null
}

$aumid = $env:NEXUS_APP_AUMID
$outputPath = $env:NEXUS_ICON_OUTPUT_PATH
if ([string]::IsNullOrWhiteSpace($aumid) -or $aumid -notmatch '!') { exit 2 }

$familyName, $applicationId = $aumid -split '!', 2
$package = Get-AppxPackage -ErrorAction SilentlyContinue |
  Where-Object { $_.PackageFamilyName -eq $familyName } |
  Select-Object -First 1
if ($null -eq $package -or [string]::IsNullOrWhiteSpace($package.InstallLocation)) { exit 3 }

$manifestPath = Join-Path $package.InstallLocation 'AppxManifest.xml'
if (-not (Test-Path -LiteralPath $manifestPath)) { exit 4 }

[xml]$manifest = Get-Content -LiteralPath $manifestPath
$app = $manifest.Package.Applications.Application |
  Where-Object { $_.Id -eq $applicationId } |
  Select-Object -First 1
if ($null -eq $app) {
  $app = $manifest.Package.Applications.Application | Select-Object -First 1
}
if ($null -eq $app) { exit 5 }

$visuals = $app.VisualElements
$logos = @(
  $visuals.Square44x44Logo,
  $visuals.Square150x150Logo,
  $visuals.Logo
)

foreach ($logo in $logos) {
  $asset = Resolve-AppAsset -InstallLocation $package.InstallLocation -Logo $logo
  if ($asset) {
    $image = [System.Drawing.Image]::FromFile($asset)
    $image.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $image.Dispose()
    exit 0
  }
}
exit 6
''',
    ],
    environment: {
      'NEXUS_APP_AUMID': appUserModelId,
      'NEXUS_ICON_OUTPUT_PATH': iconPath,
    },
  );

  if (result.exitCode == 0 && File(iconPath).existsSync()) {
    return iconPath;
  }
  return '';
}
