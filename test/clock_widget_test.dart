import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_dashboard/widgets/clock_widget.dart';

void main() {
  test('returns greeting for each part of the day', () {
    expect(greetingForHour(3), 'GOOD NIGHT');
    expect(greetingForHour(5), 'GOOD MORNING');
    expect(greetingForHour(8), 'GOOD MORNING');
    expect(greetingForHour(12), 'GOOD AFTERNOON');
    expect(greetingForHour(18), 'GOOD EVENING');
    expect(greetingForHour(22), 'GOOD NIGHT');
  });

  test('chooses clock refresh delay based on seconds visibility', () {
    final now = DateTime(2026, 6, 5, 12, 34, 45, 250);

    expect(
      clockRefreshDelay(now, showSeconds: true),
      const Duration(seconds: 1),
    );
    expect(
      clockRefreshDelay(now, showSeconds: false),
      const Duration(seconds: 14, milliseconds: 750),
    );
  });
}
