import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_dashboard/providers/dashboard_provider.dart';
import 'package:nexus_dashboard/services/launch_window_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('release policy follows fullscreen takeover settings', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    await provider.setTakeoverMode(true);
    await provider.setFullscreenEnabled(true);
    await provider.setAlwaysOnTop(true);
    await provider.setHideFromTaskbar(true);

    final policy = LaunchWindowPolicy.fromDashboard(provider);

    expect(policy.releaseAlwaysOnTop, isTrue);
    expect(policy.releaseFullScreen, isTrue);
    expect(policy.releaseTaskbar, isTrue);
  });

  test('release policy stays disabled outside takeover mode', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    await provider.setFullscreenEnabled(true);
    await provider.setAlwaysOnTop(true);
    await provider.setHideFromTaskbar(true);

    final policy = LaunchWindowPolicy.fromDashboard(provider);

    expect(policy.releaseAlwaysOnTop, isFalse);
    expect(policy.releaseFullScreen, isFalse);
    expect(policy.releaseTaskbar, isFalse);
  });
}
