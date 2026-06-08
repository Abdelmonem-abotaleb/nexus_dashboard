import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_dashboard/providers/dashboard_provider.dart';
import 'package:nexus_dashboard/widgets/clock_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'apps': [
        jsonEncode({
          'id': 'test-app',
          'name': 'Test App',
          'executablePath': '',
          'iconPath': File('pubspec.yaml').absolute.path,
        }),
      ],
    });
  });

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

  testWidgets(
    'ignores unrelated dashboard updates but applies selected fields',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final dashboardProvider = DashboardProvider(prefs);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: dashboardProvider,
          child: const MaterialApp(home: Scaffold(body: ClockWidget())),
        ),
      );

      final initialNameWidget = tester.widget<Text>(find.text('Abdo'));

      await dashboardProvider.setGlassIntensity(0.7);
      await tester.pump();

      expect(tester.widget<Text>(find.text('Abdo')), same(initialNameWidget));

      await dashboardProvider.setUserName('Nexus');
      await tester.pump();

      expect(find.text('Nexus'), findsOneWidget);
    },
  );
}
