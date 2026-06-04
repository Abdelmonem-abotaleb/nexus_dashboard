import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/models.dart';

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

class SystemProvider extends ChangeNotifier {
  SystemStats _stats = SystemStats.empty();
  Timer? _timer;
  double _cpuUsage = 0;

  SystemStats get stats => _stats;
  double get cpuUsage => _cpuUsage;

  SystemProvider() {
    _startMonitoring();
  }

  void _startMonitoring() {
    _fetchStats();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchStats());
  }

  Future<void> _fetchStats() async {
    try {
      if (Platform.isWindows) {
        await _fetchWindowsStats();
      } else {
        _stats = SystemStats.empty();
      }
      notifyListeners();
    } catch (e) {
      // Use defaults on error
    }
  }

  Future<void> _fetchWindowsStats() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-command',
        r'''
$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$os = Get-CimInstance Win32_OperatingSystem
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
$ramUsed = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory)/1MB, 2)
$ramTotal = [math]::Round($os.TotalVisibleMemorySize/1MB, 2)
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
Write-Output "$cpu|$ramUsed,$ramTotal|$diskActivity|$env:COMPUTERNAME|$cpuTemp|$gpuActivity"
''',
      ]);
      final parts = result.stdout.toString().trim().split('|');
      _cpuUsage = parts.isNotEmpty ? double.tryParse(parts[0]) ?? 0 : 0;
      final ramStats = parseStatPair(
        parts.length > 1 ? parts[1] : '',
        fallbackUsed: 0,
        fallbackTotal: 16,
      );
      final disks = parseDiskActivities(parts.length > 2 ? parts[2] : '');
      final hostname = parts.length > 3 ? parts[3].trim() : '';
      final cpuTemperatureC = parts.length > 4
          ? parseNullableDouble(parts[4])
          : null;
      final gpus = parseGpuActivities(parts.length > 5 ? parts[5] : '');

      _stats = SystemStats(
        cpuUsage: _cpuUsage,
        cpuTemperatureC: cpuTemperatureC,
        gpus: gpus,
        ramUsage: ramStats.used,
        ramTotal: ramStats.total,
        disks: disks,
        osName: 'Windows 11',
        hostname: hostname.isNotEmpty ? hostname : 'DESKTOP',
      );
    } catch (e) {
      // Keep last known stats
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
