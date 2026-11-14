import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

class NativeCpuSample {
  final int idle;
  final int kernel;
  final int user;
  final DateTime timestamp;

  const NativeCpuSample({
    required this.idle,
    required this.kernel,
    required this.user,
    required this.timestamp,
  });
}

class NativeStatsService {
  NativeStatsService._();

  static final NativeStatsService instance = NativeStatsService._();

  NativeCpuSample? _lastCpuSample;

  int _fileTimeToUint64(FILETIME ft) {
    return (ft.dwHighDateTime << 32) | ft.dwLowDateTime;
  }

  /// Returns current CPU usage percentage (0.0 - 100.0) based on delta since last call.
  /// If this is the first call, takes a baseline and returns null or estimates.
  double? getCpuUsage() {
    if (!Platform.isWindows) return null;

    final idleTime = calloc<FILETIME>();
    final kernelTime = calloc<FILETIME>();
    final userTime = calloc<FILETIME>();

    try {
      final success = GetSystemTimes(idleTime, kernelTime, userTime);
      if (success == 0) return null;

      final currentIdle = _fileTimeToUint64(idleTime.ref);
      final currentKernel = _fileTimeToUint64(kernelTime.ref);
      final currentUser = _fileTimeToUint64(userTime.ref);
      final now = DateTime.now();

      final previous = _lastCpuSample;
      _lastCpuSample = NativeCpuSample(
        idle: currentIdle,
        kernel: currentKernel,
        user: currentUser,
        timestamp: now,
      );

      if (previous == null) {
        return null;
      }

      final deltaIdle = currentIdle - previous.idle;
      final deltaKernel = currentKernel - previous.kernel;
      final deltaUser = currentUser - previous.user;
      final totalSystem = deltaKernel + deltaUser;

      if (totalSystem <= 0) return 0.0;

      final busy = totalSystem - deltaIdle;
      final usage = (busy / totalSystem) * 100.0;
      return usage.clamp(0.0, 100.0);
    } catch (_) {
      return null;
    } finally {
      free(idleTime);
      free(kernelTime);
      free(userTime);
    }
  }

  /// Returns ({double usedGb, double totalGb}) or null if unsupported.
  ({double usedGb, double totalGb})? getMemoryUsage() {
    if (!Platform.isWindows) return null;

    final memStatus = calloc<MEMORYSTATUSEX>();
    try {
      memStatus.ref.dwLength = sizeOf<MEMORYSTATUSEX>();
      final success = GlobalMemoryStatusEx(memStatus);
      if (success == 0) return null;

      final totalBytes = memStatus.ref.ullTotalPhys;
      final availBytes = memStatus.ref.ullAvailPhys;
      final usedBytes = totalBytes - availBytes;

      const bytesInGb = 1024 * 1024 * 1024;
      final totalGb = totalBytes / bytesInGb;
      final usedGb = usedBytes / bytesInGb;

      return (
        usedGb: double.parse(usedGb.toStringAsFixed(1)),
        totalGb: double.parse(totalGb.toStringAsFixed(1)),
      );
    } catch (_) {
      return null;
    } finally {
      free(memStatus);
    }
  }
}
