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
}
