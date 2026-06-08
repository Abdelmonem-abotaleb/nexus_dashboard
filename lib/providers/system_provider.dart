import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';

typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment,
      bool runInShell,
      ProcessStartMode mode,
    });

const Duration _windowsStatsTimeout = Duration(seconds: 8);
const Duration systemStatsPollInterval = Duration(seconds: 30);
const Duration systemHardwarePollInterval = Duration(minutes: 5);

({double used, double total}) parseStatPair(
  String output, {
  required num fallbackUsed,
  required num fallbackTotal,
}) {
  final parts = output.trim().split(',');
  final used = parts.isNotEmpty ? double.tryParse(parts[0]) : null;
  final total = parts.length > 1 ? double.tryParse(parts[1]) : null;

  return (
    used: used ?? fallbackUsed.toDouble(),
    total: total ?? fallbackTotal.toDouble(),
  );
}

double? parseNullableDouble(String output) {
  final value = double.tryParse(output.trim());
  if (value == null || value.isNaN || value.isInfinite) return null;
  return value;
}

List<DiskActivity> parseDiskActivities(String output) {
  final trimmed = output.trim();
  if (trimmed.isEmpty) return [];

  return trimmed
      .split(';')
      .map((entry) {
        final parts = entry.split('\t');
        final label = parts.isNotEmpty ? parts[0].trim() : '';
        final readBytes = parts.length > 1 ? double.tryParse(parts[1]) : null;
        final writeBytes = parts.length > 2 ? double.tryParse(parts[2]) : null;

        if (label.isEmpty) return null;
        return DiskActivity(
          label: label,
          readBytesPerSecond: readBytes ?? 0,
          writeBytesPerSecond: writeBytes ?? 0,
        );
      })
      .whereType<DiskActivity>()
      .toList();
}

List<GpuActivity> parseGpuActivities(String output) {
  final trimmed = output.trim();
  if (trimmed.isEmpty) return [];

  return trimmed
      .split(';')
      .map((entry) {
        final parts = entry.split('\t');
        final name = parts.isNotEmpty ? parts[0].trim() : '';
        final usage = parts.length > 1 ? double.tryParse(parts[1]) : null;
        final temperature = parts.length > 2
            ? parseNullableDouble(parts[2])
            : null;

        if (name.isEmpty) return null;
        return GpuActivity(
          name: name,
          usagePercent: usage ?? 0,
          temperatureC: temperature,
        );
      })
      .whereType<GpuActivity>()
      .toList();
}

Future<String> runPowerShellStatsScript(
  String script, {
  Duration timeout = _windowsStatsTimeout,
  ProcessStarter processStarter = Process.start,
}) async {
  final process = await processStarter('powershell', [
    '-NoProfile',
    '-NonInteractive',
    '-WindowStyle',
    'Hidden',
    '-Command',
    script,
  ]);
  final stdout = utf8.decodeStream(process.stdout);
  final stderr = utf8.decodeStream(process.stderr);

  final exitCode = process.exitCode.timeout(
    timeout,
    onTimeout: () {
      process.kill();
      throw TimeoutException('PowerShell stats command timed out', timeout);
    },
  );
  final results = await Future.wait<Object>([
    stdout,
    stderr,
    exitCode.then((code) => code as Object),
  ], eagerError: true);
  final output = results[0] as String;
  final errorOutput = results[1] as String;
  final code = results[2] as int;
  if (code != 0 && output.trim().isEmpty) {
    throw ProcessException('powershell', const [], errorOutput, code);
  }
  return output;
}

class SystemProvider extends ChangeNotifier {
  final ProcessStarter _processStarter;
  final DateTime Function() _now;
  SystemStats _stats = SystemStats.empty();
  Timer? _timer;
  double _cpuUsage = 0;
  bool _fetching = false;
  bool _monitoringEnabled = false;
  DateTime? _lastHardwareFetch;
  final String _hostname = Platform.localHostname.isNotEmpty
      ? Platform.localHostname
      : 'DESKTOP';
  double? _cachedCpuTemperatureC;
  List<GpuActivity> _cachedGpus = const [];

  SystemStats get stats => _stats;
  double get cpuUsage => _cpuUsage;
  bool get monitoringEnabled => _monitoringEnabled;

  SystemProvider({
    bool monitoringEnabled = true,
    ProcessStarter processStarter = Process.start,
    DateTime Function()? now,
  }) : _processStarter = processStarter,
       _now = now ?? DateTime.now {
    if (monitoringEnabled) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    if (_monitoringEnabled) return;
    _monitoringEnabled = true;
    _fetchStats();
    _timer = Timer.periodic(systemStatsPollInterval, (_) => _fetchStats());
  }

  void setMonitoringEnabled(bool enabled) {
    if (enabled) {
      _startMonitoring();
      return;
    }
    if (!_monitoringEnabled) return;
    _monitoringEnabled = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetchStats() async {
    if (!_monitoringEnabled) return;
    if (_fetching) return;
    _fetching = true;
    var shouldNotify = false;
    try {
      if (Platform.isWindows) {
        shouldNotify = await _fetchWindowsStats();
      } else {
        _stats = SystemStats.empty();
        shouldNotify = true;
      }
    } catch (e) {
      // Use defaults on error
    } finally {
      _fetching = false;
    }
    if (shouldNotify) {
      notifyListeners();
    }
  }

  Future<bool> _fetchWindowsStats() async {
    try {
      final fast = await _fetchWindowsFastStats();
      if (_shouldFetchHardwareStats()) {
        await _fetchWindowsHardwareStats();
      }
      _cpuUsage = fast.cpuUsage;
      _stats = SystemStats(
        cpuUsage: fast.cpuUsage,
        cpuTemperatureC: _cachedCpuTemperatureC,
        gpus: _cachedGpus,
        ramUsage: fast.ramUsage,
        ramTotal: fast.ramTotal,
        disks: fast.disks,
        osName: fast.osName,
        hostname: _hostname,
      );
      return true;
    } catch (e) {
      // Keep last known stats
      return false;
    }
  }

  bool _shouldFetchHardwareStats() {
    final lastFetch = _lastHardwareFetch;
    if (lastFetch == null) return true;
    return _now().difference(lastFetch) >= systemHardwarePollInterval;
  }

  Future<
    ({
      double cpuUsage,
      double ramUsage,
      double ramTotal,
      List<DiskActivity> disks,
      String osName,
    })
  >
  _fetchWindowsFastStats() async {
    final output = await runPowerShellStatsScript(r'''
$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$os = Get-CimInstance Win32_OperatingSystem
$ramUsed = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1MB, 2)
$ramTotal = [math]::Round($os.TotalVisibleMemorySize/1MB, 2)
$osName = if ($os.Caption) { $os.Caption } else { 'Windows' }
$diskRows = @()
try {
  $diskRows = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -ErrorAction Stop |
    Where-Object { $_.Name -ne '_Total' } |
    Sort-Object Name |
    ForEach-Object {
      $read = [math]::Round([double]$_.DiskReadBytesPersec, 0)
      $write = [math]::Round([double]$_.DiskWriteBytesPersec, 0)
      "$($_.Name)`t$read`t$write"
    }
} catch {}
$diskActivity = ($diskRows -join ';')
Write-Output "$cpu|$ramUsed,$ramTotal|$diskActivity|$osName"
''', processStarter: _processStarter);
    final parts = output.trim().split('|');
    final cpuUsage = parts.isNotEmpty ? double.tryParse(parts[0]) ?? 0.0 : 0.0;
    final ramStats = parseStatPair(
      parts.length > 1 ? parts[1] : '',
      fallbackUsed: _stats.ramUsage,
      fallbackTotal: _stats.ramTotal,
    );
    final disks = parseDiskActivities(parts.length > 2 ? parts[2] : '');
    final osName = parts.length > 3 && parts[3].trim().isNotEmpty
        ? parts[3].trim()
        : _stats.osName;
    return (
      cpuUsage: cpuUsage,
      ramUsage: ramStats.used,
      ramTotal: ramStats.total,
      disks: disks,
      osName: osName,
    );
  }

  Future<void> _fetchWindowsHardwareStats() async {
    final output = await runPowerShellStatsScript(r'''
function Get-HardwareMonitorTemperature {
  param([string]$Pattern)
  foreach ($namespace in @('root/LibreHardwareMonitor', 'root/OpenHardwareMonitor')) {
    try {
      $sensor = Get-CimInstance -Namespace $namespace -ClassName Sensor -ErrorAction Stop |
        Where-Object {
          $_.SensorType -eq 'Temperature' -and
          ($_.Name -match $Pattern -or $_.Identifier -match $Pattern)
        } |
        Sort-Object @{
          Expression = {
            if ($_.Name -match 'Package|Tctl|Tdie|Hot Spot|Junction') { 0 }
            elseif ($_.Name -match 'Core|Edge|GPU') { 1 }
            else { 2 }
          }
        } |
        Select-Object -First 1
      if ($sensor -and $null -ne $sensor.Value) {
        return [math]::Round([double]$sensor.Value, 1)
      }
    } catch {}
  }
  return $null
}

$cpuTemp = $null
$cpuTemp = Get-HardwareMonitorTemperature -Pattern 'CPU|Processor|Package|Tctl|Tdie|/intelcpu|/amdcpu'
try {
  if ($null -eq $cpuTemp) {
    $thermal = Get-CimInstance -Namespace root/wmi -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop |
      ForEach-Object { [math]::Round(($_.CurrentTemperature / 10) - 273.15, 1) } |
      Where-Object { $_ -gt 0 -and $_ -lt 125 }
    if ($thermal) {
      $cpuTemp = [math]::Round(($thermal | Measure-Object -Average).Average, 1)
    }
  }
} catch {}
try {
  if ($null -eq $cpuTemp) {
    $counterTemps = (Get-Counter '\Thermal Zone Information(*)\Temperature' -ErrorAction Stop).CounterSamples |
      ForEach-Object { [math]::Round($_.CookedValue - 273.15, 1) } |
      Where-Object { $_ -gt 0 -and $_ -lt 125 }
    if ($counterTemps) {
      $cpuTemp = [math]::Round(($counterTemps | Measure-Object -Average).Average, 1)
    }
  }
} catch {}
$gpuUsage = 0
try {
  $gpuSum = (Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop |
    Where-Object { $_.Name -match 'engtype_(3D|Compute|Copy|VideoDecode|VideoEncode)' } |
    Measure-Object -Property UtilizationPercentage -Sum).Sum
  if ($null -ne $gpuSum) {
    $gpuUsage = [math]::Round([math]::Min(100, $gpuSum), 0)
  }
} catch {}
$gpuTemp = $null
try {
  $nvidiaSmiCandidates = @(
    'nvidia-smi',
    "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
  )
  foreach ($nvidiaSmi in $nvidiaSmiCandidates) {
    try {
      if ($nvidiaSmi -ne 'nvidia-smi' -and -not (Test-Path -LiteralPath $nvidiaSmi)) {
        continue
      }
      $nvidiaTemp = (& $nvidiaSmi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null | Select-Object -First 1)
      if ($nvidiaTemp) {
        $gpuTemp = [double]$nvidiaTemp
        break
      }
    } catch {}
  }
} catch {}
if ($null -eq $gpuTemp) {
  try {
    if (Test-Path -LiteralPath "$env:WINDIR\System32\atiadlxx.dll") {
      Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NexusAmdAdl {
  public delegate IntPtr ADL_MAIN_MALLOC_CALLBACK(int size);
  [DllImport("atiadlxx.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern int ADL2_Main_Control_Create(ADL_MAIN_MALLOC_CALLBACK callback, int enumConnectedAdapters, out IntPtr context);
  [DllImport("atiadlxx.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern int ADL2_Main_Control_Destroy(IntPtr context);
  [DllImport("atiadlxx.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern int ADL2_OverdriveN_Temperature_Get(IntPtr context, int adapterIndex, int temperatureType, out int temperature);
  public static IntPtr Alloc(int size) { return Marshal.AllocHGlobal(size); }
  public static double? ReadTemperatureC() {
    IntPtr context;
    int created = ADL2_Main_Control_Create(Alloc, 1, out context);
    if (created != 0 || context == IntPtr.Zero) return null;
    try {
      double? best = null;
      for (int adapter = 0; adapter < 8; adapter++) {
        for (int type = 0; type < 8; type++) {
          int temp;
          int result = ADL2_OverdriveN_Temperature_Get(context, adapter, type, out temp);
          if (result != 0) continue;
          double celsius = temp / 1000.0;
          if (celsius <= 0 || celsius >= 125) continue;
          if (best == null || celsius > best.Value) best = celsius;
        }
      }
      return best;
    } finally {
      ADL2_Main_Control_Destroy(context);
    }
  }
}
'@
      $amdTemp = [NexusAmdAdl]::ReadTemperatureC()
      if ($null -ne $amdTemp) {
        $gpuTemp = [math]::Round([double]$amdTemp, 1)
      }
    }
  } catch {}
}
if ($null -eq $gpuTemp) {
  $gpuTemp = Get-HardwareMonitorTemperature -Pattern 'GPU|Hot Spot|Junction|Edge|/gpu'
}
$gpuNames = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
  Where-Object { $_.Name } |
  Select-Object -ExpandProperty Name)
$gpuUsageValues = @()
try {
  $activeLuids = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUAdapterMemory -ErrorAction Stop |
    Where-Object { $_.DedicatedUsage -gt 1MB -or $_.SharedUsage -gt 1MB } |
    Sort-Object Name |
    ForEach-Object {
      if ($_.Name -match 'luid_(.+?)_phys') { $Matches[1] }
    })
  $engineCounters = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop |
    Where-Object { $_.Name -match 'engtype_(3D|Compute|Copy|VideoDecode|VideoEncode)' })
  foreach ($luid in $activeLuids) {
    $escapedLuid = [regex]::Escape("luid_$luid")
    $sum = ($engineCounters |
      Where-Object { $_.Name -match $escapedLuid } |
      Measure-Object -Property UtilizationPercentage -Sum).Sum
    if ($null -eq $sum) { $sum = 0 }
    $gpuUsageValues += [math]::Round([math]::Min(100, [double]$sum), 0)
  }
} catch {}
if ($gpuNames.Count -eq 0) {
  $gpuNames = @('GPU')
  $gpuUsageValues = @($gpuUsage)
}
$gpuRows = @()
for ($i = 0; $i -lt $gpuNames.Count; $i++) {
  $usage = if ($i -lt $gpuUsageValues.Count) { $gpuUsageValues[$i] } else { 0 }
  $temp = if ($i -eq ($gpuNames.Count - 1) -and $null -ne $gpuTemp) { $gpuTemp } else { '' }
  $gpuRows += "$($gpuNames[$i])`t$usage`t$temp"
}
$gpuActivity = ($gpuRows -join ';')
Write-Output "$cpuTemp|$gpuActivity"
''', processStarter: _processStarter);
    final parts = output.trim().split('|');
    _cachedCpuTemperatureC = parts.isNotEmpty
        ? parseNullableDouble(parts[0])
        : null;
    _cachedGpus = parseGpuActivities(parts.length > 1 ? parts[1] : '');
    _lastHardwareFetch = _now();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _monitoringEnabled = false;
    super.dispose();
  }
}
