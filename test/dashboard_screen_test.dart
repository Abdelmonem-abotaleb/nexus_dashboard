import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_dashboard/providers/dashboard_provider.dart';
import 'package:nexus_dashboard/providers/system_provider.dart';
import 'package:nexus_dashboard/providers/weather_provider.dart';
import 'package:nexus_dashboard/screens/dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'weatherCity': 'Cairo',
      'lowResourceMode': true,
      'startupDelaySeconds': 0,
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
        'system',
        'todos',
        'apps',
        'websites',
        'shutdown',
        'restart',
        'sleep',
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
          ChangeNotifierProvider.value(value: weatherProvider),
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
