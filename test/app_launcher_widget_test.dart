import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_dashboard/models/models.dart';
import 'package:nexus_dashboard/providers/dashboard_provider.dart';
import 'package:nexus_dashboard/widgets/app_launcher_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('path cache reports existing icon and executable files', () async {
    final tempDir = await Directory.systemTemp.createTemp(
      'nexus_app_launcher_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final executable = File('${tempDir.path}${Platform.pathSeparator}app.exe')
      ..writeAsStringSync('');
    final icon = File('${tempDir.path}${Platform.pathSeparator}icon.png')
      ..writeAsStringSync('');

    final status = await checkAppShortcutPaths(
      AppShortcut(
        id: 'valid',
        name: 'Valid App',
        executablePath: executable.path,
        iconPath: icon.path,
      ),
    );

    expect(status.iconExists, isTrue);
    expect(status.pathExists, isTrue);
  });

  testWidgets('shows missing-path warning after async path cache completes', (
    tester,
  ) async {
    await _pumpLauncher(
      tester,
      AppShortcut(
        id: 'missing',
        name: 'Missing App',
        executablePath:
            '${Directory.systemTemp.path}${Platform.pathSeparator}nexus_missing_app.exe',
      ),
    );

    await _pumpPathChecks(tester);

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('does not warn for UWP or protocol launch targets', (
    tester,
  ) async {
    await _pumpLauncher(
      tester,
      AppShortcut(
        id: 'uwp',
        name: 'Store App',
        executablePath: 'shell:AppsFolder\\Microsoft.WindowsCalculator',
      ),
    );

    await _pumpPathChecks(tester);

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });
}

Future<void> _pumpLauncher(WidgetTester tester, AppShortcut app) async {
  SharedPreferences.setMockInitialValues({
    'apps': [jsonEncode(app.toJson())],
  });
  final prefs = await SharedPreferences.getInstance();
  final dashboard = DashboardProvider(prefs);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: dashboard,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 520, height: 220, child: AppLauncherWidget()),
        ),
      ),
    ),
  );
}

Future<void> _pumpPathChecks(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pump();
}
