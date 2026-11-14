import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_dashboard/models/models.dart';
import 'package:nexus_dashboard/providers/dashboard_provider.dart';
import 'package:nexus_dashboard/providers/weather_provider.dart';
import 'package:nexus_dashboard/providers/window_activity_provider.dart';
import 'package:nexus_dashboard/widgets/weather_widget.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'weatherCity': 'Cairo'});
  });

  testWidgets('renders today and upcoming forecast days', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final weatherProvider = WeatherProvider(
      httpGet: (uri) async {
        if (uri.host == 'geocoding-api.open-meteo.com') {
          return http.Response(
            '{"results":[{"name":"Cairo","latitude":30.06263,"longitude":31.24967}]}',
            200,
          );
        }
        return http.Response(
          '{"current":{"temperature_2m":24.5,"relative_humidity_2m":52,"apparent_temperature":25.0,"weather_code":0,"wind_speed_10m":1.7},"daily":{"time":["2026-06-03","2026-06-04"],"temperature_2m_max":[31.0,32.5],"temperature_2m_min":[22.0,23.5],"weather_code":[0,61]}}',
          200,
        );
      },
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DashboardProvider(prefs)),
          ChangeNotifierProvider.value(value: weatherProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 360, child: WeatherWidget())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('THU'), findsOneWidget);
    expect(find.text('31°'), findsOneWidget);
    expect(find.text('22°'), findsOneWidget);
  });

  testWidgets('refresh timer follows dashboard refresh minute changes', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final dashboardProvider = DashboardProvider(prefs);
    var forecastRequests = 0;
    final weatherProvider = WeatherProvider(
      httpGet: (uri) async {
        if (uri.host == 'geocoding-api.open-meteo.com') {
          return http.Response(
            '{"results":[{"name":"Cairo","latitude":30.06263,"longitude":31.24967}]}',
            200,
          );
        }
        forecastRequests++;
        return http.Response(
          '{"current":{"temperature_2m":24.5,"relative_humidity_2m":52,"apparent_temperature":25.0,"weather_code":0,"wind_speed_10m":1.7},"daily":{"time":["2026-06-03"],"temperature_2m_max":[31.0],"temperature_2m_min":[22.0],"weather_code":[0]}}',
          200,
        );
      },
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: dashboardProvider),
          ChangeNotifierProvider.value(value: weatherProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 360, child: WeatherWidget())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(forecastRequests, 1);

    await dashboardProvider.setWeatherRefreshMinutes(1);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    await tester.pump(const Duration(milliseconds: 100));

    expect(forecastRequests, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores unrelated dashboard changes', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final dashboardProvider = DashboardProvider(prefs);
    final weatherProvider = _CountingWeatherProvider(
      httpGet: (uri) async => uri.host == 'geocoding-api.open-meteo.com'
          ? http.Response(
              '{"results":[{"name":"Cairo","latitude":30.06263,"longitude":31.24967}]}',
              200,
            )
          : http.Response(
              '{"current":{"temperature_2m":24.5,"relative_humidity_2m":52,"apparent_temperature":25.0,"weather_code":0,"wind_speed_10m":1.7},"daily":{"time":[],"temperature_2m_max":[],"temperature_2m_min":[],"weather_code":[]}}',
              200,
            ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: dashboardProvider),
          ChangeNotifierProvider<WeatherProvider>.value(value: weatherProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SizedBox(width: 360, child: WeatherWidget())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final readsBefore = weatherProvider.weatherDataReads;

    await dashboardProvider.setBlurStrength(12);
    await tester.pump();

    expect(weatherProvider.weatherDataReads, readsBefore);

    await dashboardProvider.setWeatherMetricUnits(false);
    await tester.pump();

    expect(weatherProvider.weatherDataReads, greaterThan(readsBefore));
    expect(find.text('°F'), findsOneWidget);
  });

  testWidgets('pauses while inactive and refreshes once on resume', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final dashboardProvider = DashboardProvider(prefs);
    final activityProvider = WindowActivityProvider();
    var requests = 0;
    final weatherProvider = WeatherProvider(
      httpGet: (uri) async {
        if (uri.host == 'geocoding-api.open-meteo.com') {
          return http.Response(
            '{"results":[{"name":"Cairo","latitude":30.0,"longitude":31.0}]}',
            200,
          );
        }
        requests++;
        return http.Response(
          '{"current":{"temperature_2m":24,"relative_humidity_2m":50,"apparent_temperature":24,"weather_code":0,"wind_speed_10m":1},"daily":{"time":[],"temperature_2m_max":[],"temperature_2m_min":[],"weather_code":[]}}',
          200,
        );
      },
    );

    await dashboardProvider.setWeatherRefreshMinutes(1);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: dashboardProvider),
          ChangeNotifierProvider.value(value: activityProvider),
          ChangeNotifierProvider.value(value: weatherProvider),
        ],
        child: const MaterialApp(home: WeatherWidget()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(requests, 1);

    activityProvider.setFocused(false);
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    expect(requests, 1);

    activityProvider.setFocused(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(requests, 2);
  });
}

class _CountingWeatherProvider extends WeatherProvider {
  _CountingWeatherProvider({required super.httpGet});

  int weatherDataReads = 0;

  @override
  WeatherData? get weatherData {
    weatherDataReads++;
    return super.weatherData;
  }
}
