import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_dashboard/services/power_service.dart';

void main() {
  test('builds Windows shutdown command', () {
    final command = PowerCommand.forAction(PowerAction.shutdown);

    expect(command.executable, 'shutdown');
    expect(command.arguments, ['/s', '/t', '0']);
  });

  test('builds Windows restart command', () {
    final command = PowerCommand.forAction(PowerAction.restart);

    expect(command.executable, 'shutdown');
    expect(command.arguments, ['/r', '/t', '0']);
  });
}
