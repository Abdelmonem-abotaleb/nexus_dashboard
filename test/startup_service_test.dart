import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_dashboard/services/startup_service.dart';

void main() {
  test(
    'enables startup by writing the current executable to HKCU Run',
    () async {
      final calls = <({String executable, List<String> args})>[];
      final service = StartupService(
        operatingSystem: 'windows',
        executablePath: r'F:\Apps\Nexus\nexus_dashboard.exe',
        runCommand: (executable, args) async {
          calls.add((executable: executable, args: args));
          return ProcessResult(1, 0, '', '');
        },
      );

      await service.setEnabled(true);

      expect(calls.single.executable, 'reg');
      expect(calls.single.args, [
        'add',
        StartupService.runKey,
        '/v',
        StartupService.valueName,
        '/t',
        'REG_SZ',
        '/d',
        r'"F:\Apps\Nexus\nexus_dashboard.exe"',
        '/f',
      ]);
    },
  );

  test('disables startup by deleting the HKCU Run value', () async {
    final calls = <({String executable, List<String> args})>[];
    final service = StartupService(
      operatingSystem: 'windows',
      executablePath: r'F:\Apps\Nexus\nexus_dashboard.exe',
      runCommand: (executable, args) async {
        calls.add((executable: executable, args: args));
        return ProcessResult(1, 0, '', '');
      },
    );

    await service.setEnabled(false);

    expect(calls.single.executable, 'reg');
    expect(calls.single.args, [
      'delete',
      StartupService.runKey,
      '/v',
      StartupService.valueName,
      '/f',
    ]);
  });

  test('reports enabled only when the Run entry exists', () async {
    final enabledService = StartupService(
      operatingSystem: 'windows',
      executablePath: r'F:\Apps\Nexus\nexus_dashboard.exe',
      runCommand: (executable, args) async => ProcessResult(
        1,
        0,
        r'NexusDashboard    REG_SZ    "F:\Apps\Nexus\nexus_dashboard.exe"',
        '',
      ),
    );
    final disabledService = StartupService(
      operatingSystem: 'windows',
      executablePath: r'F:\Apps\Nexus\nexus_dashboard.exe',
      runCommand: (executable, args) async =>
          ProcessResult(1, 1, '', 'not found'),
    );

    expect(await enabledService.isEnabled(), isTrue);
    expect(await disabledService.isEnabled(), isFalse);
  });

  test('is disabled on unsupported platforms', () async {
    final service = StartupService(
      operatingSystem: 'linux',
      executablePath: '/tmp/nexus_dashboard',
      runCommand: (executable, args) async => ProcessResult(1, 0, '', ''),
    );

    expect(service.isSupported, isFalse);
    expect(await service.isEnabled(), isFalse);
  });
}
