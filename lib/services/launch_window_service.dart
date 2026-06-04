import 'package:window_manager/window_manager.dart';

import '../providers/dashboard_provider.dart';

class LaunchWindowPolicy {
  final bool releaseAlwaysOnTop;
  final bool releaseFullScreen;
  final bool releaseTaskbar;

  const LaunchWindowPolicy({
    required this.releaseAlwaysOnTop,
    required this.releaseFullScreen,
    required this.releaseTaskbar,
  });

  factory LaunchWindowPolicy.fromDashboard(DashboardProvider dashboard) {
    final fullscreenTakeover =
        dashboard.takeoverMode && dashboard.fullscreenEnabled;
    return LaunchWindowPolicy(
      releaseAlwaysOnTop: dashboard.takeoverMode && dashboard.alwaysOnTop,
      releaseFullScreen: fullscreenTakeover,
      releaseTaskbar: fullscreenTakeover && dashboard.hideFromTaskbar,
    );
  }
}

Future<void> prepareWindowForExternalLaunch(LaunchWindowPolicy policy) async {
  if (policy.releaseAlwaysOnTop) {
    await windowManager.setAlwaysOnTop(false);
  }
  if (policy.releaseFullScreen && await windowManager.isFullScreen()) {
    await windowManager.setFullScreen(false);
  }
  if (policy.releaseTaskbar) {
    await windowManager.setSkipTaskbar(false);
  }
  await windowManager.show();
}

Future<void> finishSuccessfulExternalLaunch(LaunchWindowPolicy policy) async {
  await windowManager.show();
  if (policy.releaseFullScreen) {
    await windowManager.setFullScreen(true);
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  if (policy.releaseAlwaysOnTop) {
    await windowManager.setAlwaysOnTop(true);
  }
  if (policy.releaseTaskbar) {
    await windowManager.setSkipTaskbar(true);
  }
  await windowManager.blur();
}

Future<void> restoreWindowAfterFailedExternalLaunch(
  LaunchWindowPolicy policy,
) async {
  if (policy.releaseFullScreen && !await windowManager.isFullScreen()) {
    await windowManager.setFullScreen(true);
  }
  if (policy.releaseAlwaysOnTop) {
    await windowManager.setAlwaysOnTop(true);
  }
  if (policy.releaseTaskbar) {
    await windowManager.setSkipTaskbar(true);
  }
  await windowManager.show();
  await windowManager.focus();
}
