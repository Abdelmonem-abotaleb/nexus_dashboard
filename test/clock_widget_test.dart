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
}
