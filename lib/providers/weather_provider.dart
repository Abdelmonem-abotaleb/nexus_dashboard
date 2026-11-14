import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

typedef WeatherHttpGet = Future<http.Response> Function(Uri uri);

class WeatherProvider extends ChangeNotifier {
  final WeatherHttpGet _httpGet;
  SharedPreferences? _prefs;
  WeatherData? _weatherData;
  bool _isLoading = false;
  bool _isDemoData = false;
  bool _isStale = false;
  DateTime? _lastUpdated;
  String _error = '';

  WeatherProvider({
    WeatherHttpGet? httpGet,
    SharedPreferences? prefs,
  }) : _httpGet = httpGet ?? http.get,
       _prefs = prefs {
    _loadCache();
  }

  WeatherData? get weatherData => _weatherData;
  bool get isLoading => _isLoading;
  bool get isDemoData => _isDemoData;
  bool get isStale => _isStale;
  DateTime? get lastUpdated => _lastUpdated;
  String get error => _error;

  Future<void> _loadCache() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final cachedJson = _prefs?.getString('weatherCache');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final map = jsonDecode(cachedJson) as Map<String, dynamic>;
        _weatherData = WeatherData.fromJson(
          map['data'] as Map<String, dynamic>,
        );
        _lastUpdated = map['updatedAt'] != null
            ? DateTime.tryParse(map['updatedAt'])
            : null;
        _isStale = true;
        _isDemoData = false;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveCache() async {
    try {
      if (_weatherData == null) return;
      _prefs ??= await SharedPreferences.getInstance();
      final cache = {
        'data': _weatherData!.toJson(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await _prefs?.setString('weatherCache', jsonEncode(cache));
      _lastUpdated = DateTime.now();
      _isStale = false;
    } catch (_) {}
  }

  Future<void> fetchWeather({
    required String apiKey,
    String? city,
    double? lat,
    double? lon,
    bool useMetricUnits = true,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    if (apiKey.isEmpty) {
      await _fetchOpenMeteoWeather(
        city: city,
        lat: lat,
        lon: lon,
        useMetricUnits: useMetricUnits,
      );
      return;
    }

    try {
      final units = useMetricUnits ? 'metric' : 'imperial';
      final resolvedCity = city?.trim();
      Uri uri;
      if (resolvedCity != null && resolvedCity.isNotEmpty) {
        uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
          'q': resolvedCity,
          'appid': apiKey,
          'units': units,
        });
      } else if (lat != null && lon != null) {
        uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'appid': apiKey,
          'units': units,
        });
      } else {
        uri = Uri.https('api.openweathermap.org', '/data/2.5/weather', {
          'lat': '30.06263',
          'lon': '31.24967',
          'appid': apiKey,
          'units': units,
        });
      }

      final response = await _httpGet(uri);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final forecast = await _fetchOpenWeatherForecast(
          currentWeatherJson: json,
          apiKey: apiKey,
          units: units,
        );
        _weatherData = WeatherData.fromOpenWeather(
          json,
          useMetricUnits: useMetricUnits,
          forecast: forecast,
        );
        _isDemoData = false;
        _isStale = false;
        await _saveCache();
      } else {
        if (_weatherData != null) {
          _isStale = true;
          _error = 'Offline (cached data)';
        } else {
          _error = 'Could not fetch weather';
          _weatherData = WeatherData.mock();
          _isDemoData = true;
        }
      }
    } catch (e) {
      if (_weatherData != null) {
        _isStale = true;
        _error = 'Offline (cached data)';
      } else {
        _error = 'Network error';
        _weatherData = WeatherData.mock();
        _isDemoData = true;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchOpenMeteoWeather({
    String? city,
    double? lat,
    double? lon,
    required bool useMetricUnits,
  }) async {
    try {
      var resolvedCity = city?.trim();
      var resolvedLat = lat;
      var resolvedLon = lon;

      if ((resolvedLat == null || resolvedLon == null) &&
          resolvedCity != null &&
          resolvedCity.isNotEmpty) {
        final query = Uri.encodeComponent(resolvedCity);
        final geocode = await _httpGet(
          Uri.parse(
            'https://geocoding-api.open-meteo.com/v1/search?name=$query&count=1&language=en&format=json',
          ),
        );
        if (geocode.statusCode == 200) {
          final json = jsonDecode(geocode.body) as Map<String, dynamic>;
          final results = json['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            final first = results.first as Map<String, dynamic>;
            resolvedCity = first['name']?.toString() ?? resolvedCity;
            resolvedLat = (first['latitude'] as num).toDouble();
            resolvedLon = (first['longitude'] as num).toDouble();
          }
        }
      }

      resolvedLat ??= 30.06263;
      resolvedLon ??= 31.24967;
      resolvedCity = resolvedCity == null || resolvedCity.isEmpty
          ? 'Cairo'
          : resolvedCity;

      final temperatureUnit = useMetricUnits ? 'celsius' : 'fahrenheit';
      final windSpeedUnit = useMetricUnits ? 'ms' : 'mph';
      final url =
          'https://api.open-meteo.com/v1/forecast?latitude=$resolvedLat&longitude=$resolvedLon'
          '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m'
          '&daily=temperature_2m_max,temperature_2m_min,weather_code'
          '&timezone=auto'
          '&forecast_days=8'
          '&temperature_unit=$temperatureUnit&wind_speed_unit=$windSpeedUnit';
      final response = await _httpGet(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _weatherData = WeatherData.fromOpenMeteo(
          json: json,
          city: resolvedCity,
        );
        _isDemoData = false;
        _isStale = false;
        await _saveCache();
      } else {
        if (_weatherData != null) {
          _isStale = true;
          _error = 'Offline (cached data)';
        } else {
          _error = 'Could not fetch weather';
          _weatherData = WeatherData.mock();
          _isDemoData = true;
        }
      }
    } catch (e) {
      if (_weatherData != null) {
        _isStale = true;
        _error = 'Offline (cached data)';
      } else {
        _error = 'Network error';
        _weatherData = WeatherData.mock();
        _isDemoData = true;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<List<ForecastDay>> _fetchOpenWeatherForecast({
    required Map<String, dynamic> currentWeatherJson,
    required String apiKey,
    required String units,
  }) async {
    try {
      final coord = currentWeatherJson['coord'] as Map<String, dynamic>?;
      final lat = (coord?['lat'] as num?)?.toDouble();
      final lon = (coord?['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) return [];

      final uri = Uri.https('api.openweathermap.org', '/data/2.5/forecast', {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'appid': apiKey,
        'units': units,
      });
      final response = await _httpGet(uri);
      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return parseOpenWeatherForecast(json);
    } catch (_) {
      return [];
    }
  }

  List<ForecastDay> parseOpenWeatherForecast(Map<String, dynamic> json) {
    final list = json['list'] as List<dynamic>? ?? [];
    final timezoneOffset = (json['city'] as Map<String, dynamic>?)?['timezone'];
    final offset = Duration(seconds: (timezoneOffset as num?)?.toInt() ?? 0);
    final days = <DateTime, _OpenWeatherDayAccumulator>{};

    for (final item in list.whereType<Map<String, dynamic>>()) {
      final utcDate = _openWeatherUtcDate(item);
      if (utcDate == null) continue;
      final localDateTime = utcDate.add(offset);
      final date = DateTime(
        localDateTime.year,
        localDateTime.month,
        localDateTime.day,
      );
      final main = item['main'] as Map<String, dynamic>? ?? {};
      final tempMin = (main['temp_min'] as num?)?.toDouble();
      final tempMax = (main['temp_max'] as num?)?.toDouble();
      if (tempMin == null || tempMax == null) continue;

      final weather = (item['weather'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .firstOrNull;
      final icon = weather?['icon']?.toString() ?? '01d';
      final condition = weather?['description']?.toString() ?? 'Weather';

      days
          .putIfAbsent(date, () => _OpenWeatherDayAccumulator(date))
          .add(
            tempMin: tempMin,
            tempMax: tempMax,
            icon: icon,
            condition: condition,
          );
    }

    return days.values.map((day) => day.toForecastDay()).take(8).toList();
  }

  DateTime? _openWeatherUtcDate(Map<String, dynamic> item) {
    final timestamp = (item['dt'] as num?)?.toInt();
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
    }

    final text = item['dt_txt']?.toString();
    if (text == null || text.isEmpty) return null;
    final parsed = DateTime.tryParse('${text.replaceFirst(' ', 'T')}Z');
    return parsed?.toUtc();
  }

  // Map OWM icon code to emoji
  String iconToEmoji(String icon) {
    if (icon.length < 2) return '🌡️';
    switch (icon.substring(0, 2)) {
      case '01':
        return '☀️';
      case '02':
        return '🌤️';
      case '03':
      case '04':
        return '☁️';
      case '09':
      case '10':
        return '🌧️';
      case '11':
        return '⛈️';
      case '13':
        return '❄️';
      case '50':
        return '🌫️';
      default:
        return '🌡️';
    }
  }
}

class _OpenWeatherDayAccumulator {
  final DateTime date;
  double? _tempMin;
  double? _tempMax;
  String _icon = '01d';
  String _condition = 'Weather';

  _OpenWeatherDayAccumulator(this.date);

  void add({
    required double tempMin,
    required double tempMax,
    required String icon,
    required String condition,
  }) {
    _tempMin = _tempMin == null
        ? tempMin
        : (_tempMin! < tempMin ? _tempMin : tempMin);
    _tempMax = _tempMax == null
        ? tempMax
        : (_tempMax! > tempMax ? _tempMax : tempMax);
    _icon = icon;
    _condition = condition;
  }

  ForecastDay toForecastDay() {
    return ForecastDay(
      date: date,
      tempMax: _tempMax ?? 0,
      tempMin: _tempMin ?? 0,
      icon: _icon,
      condition: _condition,
    );
  }
}
