import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

typedef PrayerTimesHttpGet = Future<http.Response> Function(Uri uri);

class PrayerTimes {
  final Map<String, String> timings;

  const PrayerTimes(this.timings);

  String operator [](String prayer) => timings[prayer] ?? '--:--';
}

class PrayerTimesProvider extends ChangeNotifier {
  final PrayerTimesHttpGet _httpGet;
  PrayerTimes? _prayerTimes;
  bool _isLoading = false;
  String _error = '';

  PrayerTimesProvider({PrayerTimesHttpGet? httpGet})
    : _httpGet = httpGet ?? http.get;

  PrayerTimes? get prayerTimes => _prayerTimes;
  bool get isLoading => _isLoading;
  String get error => _error;

  Future<void> fetchPrayerTimes({String? city}) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      final uri = Uri.https('api.aladhan.com', '/v1/timingsByAddress', {
        'address': city?.trim().isNotEmpty == true ? city!.trim() : 'Cairo',
        'method': '5',
      });
      final response = await _httpGet(uri);
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final timings = json['data']?['timings'] as Map<String, dynamic>?;
      if (response.statusCode != 200 || timings == null) {
        throw const FormatException('Prayer times unavailable');
      }
      _prayerTimes = PrayerTimes({
        for (final prayer in ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'])
          prayer: _timeOnly(timings[prayer]?.toString() ?? ''),
      });
    } catch (_) {
      _error = 'Could not fetch prayer times';
    }

    _isLoading = false;
    notifyListeners();
  }

  String _timeOnly(String value) => value.split(' ').first;
}
