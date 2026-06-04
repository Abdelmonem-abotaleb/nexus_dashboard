import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:nexus_dashboard/providers/weather_provider.dart';

void main() {
  test('uses Open-Meteo weather when no API key is configured', () async {
    final requestedUris = <Uri>[];
    final provider = WeatherProvider(
      httpGet: (uri) async {
        requestedUris.add(uri);
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

    await provider.fetchWeather(apiKey: '', city: 'Cairo');

    expect(provider.weatherData?.city, 'Cairo');
    expect(provider.weatherData?.temperature, 24.5);
    expect(provider.weatherData?.forecast, hasLength(2));
    expect(provider.weatherData?.forecast.first.date, DateTime(2026, 6, 3));
    expect(provider.weatherData?.forecast.first.tempMax, 31);
    expect(provider.weatherData?.forecast.first.tempMin, 22);
    expect(provider.weatherData?.forecast.last.condition, 'Rain');
    expect(provider.isDemoData, isFalse);
    expect(provider.isLoading, isFalse);
    expect(provider.error, isEmpty);

    final forecastUri = requestedUris.last;
    expect(
      forecastUri.queryParameters['daily'],
      contains('temperature_2m_max'),
    );
    expect(
      forecastUri.queryParameters['daily'],
      contains('temperature_2m_min'),
    );
    expect(forecastUri.queryParameters['daily'], contains('weather_code'));
    expect(forecastUri.queryParameters['timezone'], 'auto');
    expect(forecastUri.queryParameters['forecast_days'], '8');
  });

  test('uses OpenWeather forecast when an API key is configured', () async {
    final requestedUris = <Uri>[];
    final provider = WeatherProvider(
      httpGet: (uri) async {
        requestedUris.add(uri);
        if (uri.path == '/data/2.5/weather') {
          return http.Response(
            '{"name":"Cairo","coord":{"lat":30.06263,"lon":31.24967},"main":{"temp":26.0,"humidity":48,"feels_like":27.0},"wind":{"speed":3.2},"weather":[{"description":"clear sky","icon":"01d"}]}',
            200,
          );
        }
        return http.Response(
          '{"list":['
          '{"dt":1780480800,"dt_txt":"2026-06-03 06:00:00","main":{"temp_min":22.0,"temp_max":29.0},"weather":[{"description":"clear sky","icon":"01d"}]},'
          '{"dt":1780502400,"dt_txt":"2026-06-03 12:00:00","main":{"temp_min":24.0,"temp_max":33.0},"weather":[{"description":"clear sky","icon":"01d"}]},'
          '{"dt":1780588800,"dt_txt":"2026-06-04 12:00:00","main":{"temp_min":23.0,"temp_max":31.0},"weather":[{"description":"light rain","icon":"10d"}]}'
          '],"city":{"timezone":7200}}',
          200,
        );
      },
    );

    await provider.fetchWeather(apiKey: 'key', city: 'Cairo');

    expect(provider.weatherData?.city, 'Cairo');
    expect(provider.weatherData?.forecast, hasLength(2));
    expect(provider.weatherData?.forecast.first.date, DateTime(2026, 6, 3));
    expect(provider.weatherData?.forecast.first.tempMax, 33);
    expect(provider.weatherData?.forecast.first.tempMin, 22);
    expect(provider.weatherData?.forecast.last.condition, 'light rain');
    expect(provider.isDemoData, isFalse);
    expect(provider.error, isEmpty);

    final forecastUri = requestedUris.last;
    expect(forecastUri.path, '/data/2.5/forecast');
    expect(forecastUri.queryParameters['lat'], '30.06263');
    expect(forecastUri.queryParameters['lon'], '31.24967');
    expect(forecastUri.queryParameters['appid'], 'key');
    expect(forecastUri.queryParameters['units'], 'metric');
  });

  test('uses default coordinates for OpenWeather when no location is set', () async {
    final requestedUris = <Uri>[];
    final provider = WeatherProvider(
      httpGet: (uri) async {
        requestedUris.add(uri);
        if (uri.path == '/data/2.5/weather') {
          return http.Response(
            '{"name":"Cairo","coord":{"lat":30.06263,"lon":31.24967},"main":{"temp":26.0,"humidity":48,"feels_like":27.0},"wind":{"speed":3.2},"weather":[{"description":"clear sky","icon":"01d"}]}',
            200,
          );
        }
        return http.Response(
          '{"list":['
          '{"dt":1780502400,"dt_txt":"2026-06-03 12:00:00","main":{"temp_min":24.0,"temp_max":33.0},"weather":[{"description":"clear sky","icon":"01d"}]},'
          '{"dt":1780588800,"dt_txt":"2026-06-04 12:00:00","main":{"temp_min":23.0,"temp_max":31.0},"weather":[{"description":"light rain","icon":"10d"}]}'
          '],"city":{"timezone":7200}}',
          200,
        );
      },
    );

    await provider.fetchWeather(apiKey: 'key');

    expect(provider.weatherData?.city, 'Cairo');
    expect(provider.weatherData?.temperature, 26);
    expect(provider.weatherData?.forecast, hasLength(2));
    expect(provider.isDemoData, isFalse);
    expect(provider.error, isEmpty);

    final currentUri = requestedUris.first;
    expect(currentUri.path, '/data/2.5/weather');
    expect(currentUri.queryParameters['lat'], '30.06263');
    expect(currentUri.queryParameters['lon'], '31.24967');
    expect(currentUri.queryParameters['appid'], 'key');
    expect(currentUri.queryParameters['units'], 'metric');
  });

  test('keeps OpenWeather current data when forecast fetch fails', () async {
    final provider = WeatherProvider(
      httpGet: (uri) async {
        if (uri.path == '/data/2.5/weather') {
          return http.Response(
            '{"name":"Cairo","coord":{"lat":30.06263,"lon":31.24967},"main":{"temp":26.0,"humidity":48,"feels_like":27.0},"wind":{"speed":3.2},"weather":[{"description":"clear sky","icon":"01d"}]}',
            200,
          );
        }
        return http.Response('forecast unavailable', 500);
      },
    );

    await provider.fetchWeather(apiKey: 'key', city: 'Cairo');

    expect(provider.weatherData?.city, 'Cairo');
    expect(provider.weatherData?.temperature, 26);
    expect(provider.weatherData?.forecast, isEmpty);
    expect(provider.isDemoData, isFalse);
    expect(provider.error, isEmpty);
  });

  test('iconToEmoji handles empty icon codes', () {
    final provider = WeatherProvider();

    expect(provider.iconToEmoji(''), '🌡️');
  });
}
