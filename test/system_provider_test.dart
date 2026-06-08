import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_dashboard/providers/system_provider.dart';

void main() {
  test('parses comma-separated stat output into doubles', () {
    expect(parseStatPair('7.5,15.9', fallbackUsed: 0, fallbackTotal: 16), (
      used: 7.5,
      total: 15.9,
    ));
  });

  test('falls back when stat output is malformed', () {
    expect(parseStatPair('', fallbackUsed: 0, fallbackTotal: 512), (
      used: 0.0,
      total: 512.0,
    ));
    expect(parseStatPair('abc', fallbackUsed: 1, fallbackTotal: 2), (
      used: 1.0,
      total: 2.0,
    ));
  });

  test('parses nullable double values', () {
    expect(parseNullableDouble('42.5'), 42.5);
    expect(parseNullableDouble(''), isNull);
    expect(parseNullableDouble('abc'), isNull);
  });

  test('parses physical disk read and write activity', () {
    final disks = parseDiskActivities('0 C:\t1048576\t2097152;1 D:\t524288\t0');

    expect(disks, hasLength(2));
    expect(disks[0].label, '0 C:');
    expect(disks[0].readBytesPerSecond, 1048576);
    expect(disks[0].writeBytesPerSecond, 2097152);
    expect(disks[1].label, '1 D:');
    expect(disks[1].readMegabytesPerSecond, 0.5);
    expect(disks[1].writeMegabytesPerSecond, 0);
  });

  test('parses multiple gpu activity rows', () {
    final gpus = parseGpuActivities(
      'AMD Radeon(TM) Graphics\t12\t45.5;AMD Radeon RX 6800M\t87\t71',
    );

    expect(gpus, hasLength(2));
    expect(gpus[0].name, 'AMD Radeon(TM) Graphics');
    expect(gpus[0].usagePercent, 12);
    expect(gpus[0].temperatureC, 45.5);
    expect(gpus[1].name, 'AMD Radeon RX 6800M');
    expect(gpus[1].usagePercent, 87);
    expect(gpus[1].temperatureC, 71);
  });

  test('kills powershell process when stats command times out', () async {
    final process = _FakeProcess();

    await expectLater(
      runPowerShellStatsScript(
        'Write-Output "slow"',
        timeout: const Duration(milliseconds: 1),
        processStarter:
            (
              executable,
              arguments, {
              workingDirectory,
              environment,
              includeParentEnvironment = true,
              runInShell = false,
              mode = ProcessStartMode.normal,
            }) async {
              expect(executable, 'powershell');
              expect(arguments, contains('-NonInteractive'));
              expect(arguments, contains('-WindowStyle'));
              expect(arguments, contains('Hidden'));
              return process;
            },
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(process.killed, isTrue);
  });

  test(
    'stats command timeout completes when process streams stay open',
    () async {
      final process = _StreamsStayOpenProcess();

      await expectLater(
        runPowerShellStatsScript(
          'Write-Output "slow"',
          timeout: const Duration(milliseconds: 1),
          processStarter:
              (
                executable,
                arguments, {
                workingDirectory,
                environment,
                includeParentEnvironment = true,
                runInShell = false,
                mode = ProcessStartMode.normal,
              }) async {
                return process;
              },
        ),
        throwsA(isA<TimeoutException>()),
      ).timeout(const Duration(seconds: 1));
      expect(process.killed, isTrue);
    },
  );

  test('uses lower frequency polling intervals', () {
    expect(systemStatsPollInterval, const Duration(seconds: 30));
    expect(systemHardwarePollInterval, const Duration(minutes: 5));
  });

  test('does not start stats process while monitoring is disabled', () async {
    var started = 0;
    final provider = SystemProvider(
      monitoringEnabled: false,
      processStarter:
          (
            executable,
            arguments, {
            workingDirectory,
            environment,
            includeParentEnvironment = true,
            runInShell = false,
            mode = ProcessStartMode.normal,
          }) async {
            started++;
            return _CompletedProcess('');
          },
    );

    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.monitoringEnabled, isFalse);
    expect(started, 0);
    provider.dispose();
  });

  test('starts stats process when monitoring is enabled', () async {
    if (!Platform.isWindows) return;
    var started = 0;
    final provider = SystemProvider(
      monitoringEnabled: false,
      processStarter:
          (
            executable,
            arguments, {
            workingDirectory,
            environment,
            includeParentEnvironment = true,
            runInShell = false,
            mode = ProcessStartMode.normal,
          }) async {
            started++;
            return _CompletedProcess(
              started == 1 ? '12|7.5,16|0 C:\t1024\t2048' : '61|GPU\t22\t70',
            );
          },
    );

    provider.setMonitoringEnabled(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(provider.monitoringEnabled, isTrue);
    expect(started, 2);
    expect(provider.stats.cpuUsage, 12);
    expect(provider.stats.gpus.single.temperatureC, 70);
    provider.dispose();
  });

  test(
    'uses Windows operating system caption from fast stats output',
    () async {
      if (!Platform.isWindows) return;
      var started = 0;
      final provider = SystemProvider(
        monitoringEnabled: false,
        processStarter:
            (
              executable,
              arguments, {
              workingDirectory,
              environment,
              includeParentEnvironment = true,
              runInShell = false,
              mode = ProcessStartMode.normal,
            }) async {
              started++;
              return _CompletedProcess(
                started == 1
                    ? '12|7.5,16|0 C:\t1024\t2048|Microsoft Windows 10 Pro'
                    : '61|GPU\t22\t70',
              );
            },
      );

      provider.setMonitoringEnabled(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(provider.stats.osName, 'Microsoft Windows 10 Pro');
      provider.dispose();
    },
  );
}

class _FakeProcess implements Process {
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exitCode = Completer<int>();
  bool killed = false;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    _stdout.close();
    _stderr.close();
    if (!_exitCode.isCompleted) {
      _exitCode.complete(-1);
    }
    return true;
  }

  @override
  int get pid => 1234;

  @override
  IOSink get stdin => throw UnimplementedError();
}

class _StreamsStayOpenProcess implements Process {
  final _stdout = StreamController<List<int>>();
  final _stderr = StreamController<List<int>>();
  final _exitCode = Completer<int>();
  bool killed = false;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }

  @override
  int get pid => 4321;

  @override
  IOSink get stdin => throw UnimplementedError();
}

class _CompletedProcess implements Process {
  final String output;

  _CompletedProcess(this.output);

  @override
  Stream<List<int>> get stdout => Stream.value(output.codeUnits);

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Future<int> get exitCode => Future.value(0);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  int get pid => 5678;

  @override
  IOSink get stdin => throw UnimplementedError();
}
