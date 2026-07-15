import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexus_dashboard/providers/prayer_times_provider.dart';

void main() {
  test('fetches the five daily prayer times for the selected city', () async {
    Uri? requestedUri;
    final provider = PrayerTimesProvider(
      httpGet: (uri) async {
        requestedUri = uri;
        return http.Response(
          '{"data":{"timings":{"Fajr":"04:20 (+03)","Dhuhr":"12:01 (+03)","Asr":"15:35 (+03)","Maghrib":"18:42 (+03)","Isha":"20:00 (+03)"}}}',
          200,
        );
      },
    );

    await provider.fetchPrayerTimes(city: 'Cairo');

    expect(requestedUri?.host, 'api.aladhan.com');
    expect(requestedUri?.queryParameters['address'], 'Cairo');
    expect(provider.prayerTimes?['Maghrib'], '18:42');
    expect(provider.error, isEmpty);
  });
}
