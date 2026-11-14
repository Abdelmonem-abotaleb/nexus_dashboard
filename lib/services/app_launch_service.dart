import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../models/models.dart';
import '../providers/dashboard_provider.dart';
import 'launch_window_service.dart';

class AppLaunchService {
  AppLaunchService._();

  static final AppLaunchService instance = AppLaunchService._();

  static bool isUwpOrProtocol(String path) {
    if (path.startsWith('shell:')) return true;
    if (RegExp(r'^[A-Za-z]:').hasMatch(path)) return false;
    if (Uri.tryParse(path)?.hasScheme ?? false) return true;
    return path.isNotEmpty && !path.contains('\\') && !path.contains('/');
  }

  /// Launches an app or target without any cmd.exe console flashing.
  Future<void> launchTarget(String rawPath) async {
    final path = rawPath.replaceAll(
      '%USERNAME%',
      Platform.environment['USERNAME'] ?? '',
    );

    if (Platform.isWindows) {
      if (isUwpOrProtocol(path)) {
        String launchTarget = path;
        if (!path.startsWith('shell:') && !path.contains(':')) {
          launchTarget = 'shell:AppsFolder\\$path';
        }
        _launchWithShellExecute(launchTarget);
        return;
      }

      final file = File(path);
      if (!file.existsSync()) {
        throw FileSystemException('Executable does not exist', path);
      }

      final dir = file.parent.existsSync() ? file.parent.path : null;
      try {
        await Process.start(
          path,
          const [],
          runInShell: false,
          mode: ProcessStartMode.detached,
          workingDirectory: dir,
        );
      } catch (_) {
        // Fallback to ShellExecute for tricky permission or shell targets
        _launchWithShellExecute(path, workingDirectory: dir);
      }
    } else {
      await Process.start(path, const [], runInShell: false);
    }
  }

  void _launchWithShellExecute(String target, {String? workingDirectory}) {
    final operation = 'open'.toNativeUtf16();
    final file = target.toNativeUtf16();
    final dir = workingDirectory != null ? workingDirectory.toNativeUtf16() : nullptr;

    try {
      final result = ShellExecute(
        0,
        operation,
        file,
        nullptr,
        dir,
        SW_SHOWNORMAL,
      );
      if (result <= 32) {
        throw ProcessException(
          'ShellExecute',
          [target],
          'ShellExecute failed with error code $result',
          result,
        );
      }
    } finally {
      free(operation);
      free(file);
      if (dir != nullptr) {
        free(dir);
      }
    }
  }

  /// Coordinates dashboard window release and restoration when launching external app.
  Future<void> launchAppWithPolicy({
    required AppShortcut app,
    required DashboardProvider dashboard,
  }) async {
    final policy = LaunchWindowPolicy.fromDashboard(dashboard);
    await prepareWindowForExternalLaunch(policy);
    var launched = false;
    try {
      await launchTarget(app.executablePath);
      launched = true;
    } finally {
      if (launched) {
        await finishSuccessfulExternalLaunch(policy);
      } else {
        await restoreWindowAfterFailedExternalLaunch(policy);
      }
    }
  }
}
