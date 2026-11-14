import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_dashboard/models/models.dart';
import 'package:nexus_dashboard/providers/dashboard_provider.dart';
import 'package:nexus_dashboard/providers/agenda_provider.dart';
import 'package:nexus_dashboard/providers/window_activity_provider.dart';
import 'package:nexus_dashboard/providers/prayer_times_provider.dart';
import 'package:nexus_dashboard/providers/system_provider.dart';
import 'package:nexus_dashboard/providers/weather_provider.dart';
import 'package:nexus_dashboard/screens/dashboard_screen.dart';
import 'package:nexus_dashboard/services/startup_service.dart';
import 'package:nexus_dashboard/theme/app_theme.dart';
import 'package:nexus_dashboard/widgets/desktop_widget_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'weatherCity': 'Cairo',
      'lowResourceMode': true,
      'startupDelaySeconds': 0,
      'layoutSchemaVersion': 2,
      'apps': [
        jsonEncode({
          'id': 'test-app',
          'name': 'Test App',
          'executablePath': '',
          'iconPath': File('pubspec.yaml').absolute.path,
        }),
      ],
      'disabledWidgets': [
        'clock',
        'prayerTimes',
        'system',
        'todos',
        'apps',
        'websites',
        'shutdown',
        'restart',
        'sleep',
        'agenda',
        'power',
      ],
    });
    _mockDesktopPluginChannels();
  });

  tearDown(() {
    _clearDesktopPluginChannelMocks();
  });

  testWidgets('dashboard weather widget fetches once on startup', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    var forecastRequests = 0;
    final weatherProvider = WeatherProvider(
      httpGet: (uri) async {
        if (uri.host == 'geocoding-api.open-meteo.com') {
          return http.Response(
            '{"results":[{"name":"Cairo","latitude":30.06263,"longitude":31.24967}]}',
            200,
          );
        }
        if (uri.host == 'api.open-meteo.com') {
          forecastRequests++;
          return http.Response(
            '{"current":{"temperature_2m":24.5,"relative_humidity_2m":52,"apparent_temperature":25.0,"weather_code":0,"wind_speed_10m":1.7},"daily":{"time":["2026-06-03"],"temperature_2m_max":[31.0],"temperature_2m_min":[22.0],"weather_code":[0]}}',
            200,
          );
        }
        return http.Response('{}', 404);
      },
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DashboardProvider(prefs)),
          ChangeNotifierProvider(create: (_) => AgendaProvider(prefs)),
          ChangeNotifierProvider(create: (_) => WindowActivityProvider()),
          ChangeNotifierProvider.value(value: weatherProvider),
          ChangeNotifierProvider(create: (_) => PrayerTimesProvider()),
          ChangeNotifierProvider(
            create: (_) => SystemProvider(monitoringEnabled: false),
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(forecastRequests, 1);
  });

  testWidgets('responsive grid follows single, six, and twelve column rules', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'layoutSchemaVersion': 2,
      'lowResourceMode': true,
      'startupDelaySeconds': 30,
      'disabledWidgets': ['weather', 'prayerTimes', 'system'],
    });
    final prefs = await SharedPreferences.getInstance();

    Future<void> render(
      Size size, {
      double textScale = 1,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        _dashboardTestApp(prefs, textScale: textScale, themeMode: themeMode),
      );
      await tester.pump();
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await render(const Size(900, 700));
    final singleAgenda = tester.getSize(
      find.byKey(const ValueKey('dashboard-agenda')),
    );
    final singleTodo = tester.getSize(
      find.byKey(const ValueKey('dashboard-todos')),
    );
    expect(singleAgenda.width, closeTo(singleTodo.width, 1));

    await render(const Size(1024, 700), textScale: 1.5);
    final mediumAgenda = tester.getSize(
      find.byKey(const ValueKey('dashboard-agenda')),
    );
    final mediumApps = tester.getSize(
      find.byKey(const ValueKey('dashboard-apps')),
    );
    final mediumTodo = tester.getSize(
      find.byKey(const ValueKey('dashboard-todos')),
    );
    expect(mediumAgenda.width, closeTo(mediumApps.width, 1));
    expect(mediumTodo.width, lessThan(mediumApps.width));
    expect(tester.takeException(), isNull);

    await render(const Size(1920, 1080), themeMode: ThemeMode.dark);
    final wideAgenda = tester.getSize(
      find.byKey(const ValueKey('dashboard-agenda')),
    );
    final wideApps = tester.getSize(
      find.byKey(const ValueKey('dashboard-apps')),
    );
    expect(wideAgenda.width, lessThan(wideApps.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ctrl+, opens categorized settings and Escape closes it', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_dashboardTestApp(prefs));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('System'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('customize mode moves, resizes, and resets wide placements', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'layoutSchemaVersion': 3,
      'lowResourceMode': true,
      'startupDelaySeconds': 30,
      'disabledWidgets': [
        'weather',
        'agenda',
        'apps',
        'todos',
        'prayerTimes',
        'system',
        'power',
        'websites',
      ],
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1920, 1080);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_dashboardTestApp(prefs));
    await tester.pump();
    final context = tester.element(find.byType(DashboardScreen));
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);

    await tester.tap(find.text('CUSTOMIZE'));
    await tester.pump();
    expect(find.text('DONE'), findsOneWidget);
    expect(find.byTooltip('Move clock'), findsOneWidget);
    expect(find.byTooltip('Resize clock'), findsOneWidget);

    await tester.drag(find.byTooltip('Move clock'), const Offset(320, 136));
    await tester.pumpAndSettle();
    var clock = dashboard
        .placementsFor(LayoutBreakpoint.wide)
        .singleWhere((item) => item.id == 'clock');
    expect(clock.x, greaterThan(0));
    expect(clock.y, greaterThan(0));

    await tester.drag(find.byTooltip('Resize clock'), const Offset(160, 0));
    await tester.pumpAndSettle();
    clock = dashboard
        .placementsFor(LayoutBreakpoint.wide)
        .singleWhere((item) => item.id == 'clock');
    expect(clock.width, greaterThan(3));

    await tester.tap(find.text('RESET'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset layout'));
    await tester.pumpAndSettle();
    clock = dashboard
        .placementsFor(LayoutBreakpoint.wide)
        .singleWhere((item) => item.id == 'clock');
    expect((clock.x, clock.y, clock.width, clock.height), (0, 0, 3, 3));

    await tester.tap(find.byTooltip('Move clock'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    clock = dashboard
        .placementsFor(LayoutBreakpoint.wide)
        .singleWhere((item) => item.id == 'clock');
    expect(clock.x, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    clock = dashboard
        .placementsFor(LayoutBreakpoint.wide)
        .singleWhere((item) => item.id == 'clock');
    expect(clock.height, 4);
  });

  testWidgets('narrow mode refuses customization', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_dashboardTestApp(prefs));
    await tester.pump();

    await tester.tap(find.text('CUSTOMIZE'));
    await tester.pump();

    expect(find.textContaining('1024 px'), findsOneWidget);
    expect(find.text('DONE'), findsNothing);
  });

  testWidgets('appearance settings manage background thumbnails', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'layoutSchemaVersion': 3,
      'lowResourceMode': true,
      'startupDelaySeconds': 30,
      'backgroundImages': ['missing-one.jpg', 'missing-two.jpg'],
      'disabledWidgets': DashboardProvider.defaultWidgetOrder,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_dashboardTestApp(prefs));
    await tester.pump();
    final context = tester.element(find.byType(DashboardScreen));
    final dashboard = Provider.of<DashboardProvider>(context, listen: false);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.comma);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('Shuffle next'), findsOneWidget);
    expect(find.byTooltip('Remove background'), findsNWidgets(2));
    await tester.ensureVisible(find.byTooltip('Remove background').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove background').first);
    await tester.pump();
    expect(dashboard.backgroundImagePaths, hasLength(1));
    expect(find.byTooltip('Remove background'), findsOneWidget);
  });

  testWidgets(
    'switches to desktop widget mode, customizes cards, and returns to full dashboard',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'layoutSchemaVersion': 3,
        'lowResourceMode': true,
        'startupDelaySeconds': 30,
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(_dashboardTestApp(prefs));
      await tester.pump();

      await tester.tap(find.text('WIDGET'));
      await tester.pumpAndSettle();

      expect(find.byType(DesktopWidgetView), findsOneWidget);
      expect(
        find.byKey(const ValueKey('desktop-widget-card-clock')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('desktop-widget-card-weather')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('desktop-widget-card-prayerTimes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('desktop-widget-card-todos')),
        findsNothing,
      );

      // Simulate widget window size and hover over the widget view
      tester.view.physicalSize = const Size(380, 640);
      await tester.pump();
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byType(DesktopWidgetView)));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('desktop-widget-picker-button')),
      );
      await tester.pumpAndSettle();

      // Disable clock and enable todos inside the inline picker
      final clockRow = find.byKey(const ValueKey('desktop-picker-item-clock'));
      await tester.tap(
        find.descendant(of: clockRow, matching: find.byType(Checkbox)),
      );
      await tester.pump();

      final todosRow = find.byKey(const ValueKey('desktop-picker-item-todos'));
      await tester.ensureVisible(todosRow);
      await tester.tap(
        find.descendant(of: todosRow, matching: find.byType(Checkbox)),
      );
      await tester.pump();

      // Close picker
      await tester.tap(find.byTooltip('Done'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('desktop-widget-card-clock')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('desktop-widget-card-todos')),
        findsOneWidget,
      );

      // Expand back to Full Dashboard (simulated window resize back to 1440x900)
      await tester.tap(
        find.byKey(const Key('desktop-widget-expand-button')),
      );
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();
      expect(find.byType(DesktopWidgetView), findsNothing);
      expect(find.text('WIDGET'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop widget view renders all cards cleanly at 380x640', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'layoutSchemaVersion': 3,
      'lowResourceMode': true,
      'startupDelaySeconds': 30,
      'desktopWidgetMode': true,
      'desktopWidgetEnabledIds': DashboardProvider.defaultWidgetOrder,
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 640);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(_dashboardTestApp(prefs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DesktopWidgetView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _dashboardTestApp(
  SharedPreferences prefs, {
  double textScale = 1,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => DashboardProvider(prefs)),
      ChangeNotifierProvider(create: (_) => AgendaProvider(prefs)),
      ChangeNotifierProvider(create: (_) => WindowActivityProvider()),
      ChangeNotifierProvider(
        create: (_) =>
            WeatherProvider(httpGet: (_) async => http.Response('{}', 404)),
      ),
      ChangeNotifierProvider(create: (_) => PrayerTimesProvider()),
      ChangeNotifierProvider(
        create: (_) => SystemProvider(monitoringEnabled: false),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: DashboardScreen(
        startupService: StartupService(operatingSystem: 'linux'),
      ),
    ),
  );
}

void _mockDesktopPluginChannels() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('window_manager'), (
        call,
      ) async {
        return switch (call.method) {
          'isMinimized' ||
          'isFullScreen' ||
          'isMaximized' ||
          'isPreventClose' ||
          'isSkipTaskbar' => false,
          'getOpacity' => 1.0,
          'getTitle' => 'Nexus Dashboard',
          'getTitleBarHeight' => 0,
          'getBounds' => {
            'x': 100.0,
            'y': 100.0,
            'width': 1440.0,
            'height': 900.0,
          },
          _ => null,
        };
      });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter/system_tray/tray'),
        (call) async {
          return true;
        },
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter/system_tray/menu_manager'),
        (call) async => true,
      );
}

void _clearDesktopPluginChannelMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('window_manager'), null);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter/system_tray/tray'),
        null,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('flutter/system_tray/menu_manager'),
        null,
      );
}
