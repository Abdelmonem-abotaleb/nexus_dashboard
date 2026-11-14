import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_dashboard/providers/window_activity_provider.dart';

void main() {
  test('is active only while visible and focused', () {
    final activity = WindowActivityProvider();
    var notifications = 0;
    activity.addListener(() => notifications++);

    expect(activity.isActive, isTrue);
    activity.setFocused(false);
    expect(activity.isActive, isFalse);
    activity.setVisible(false);
    activity.setFocused(true);
    expect(activity.isActive, isFalse);
    activity.setVisible(true);
    expect(activity.isActive, isTrue);
    expect(notifications, 4);
  });

  test('reports appropriate ActivityLevel', () {
    final activity = WindowActivityProvider();
    expect(activity.level, ActivityLevel.focused);

    activity.setFocused(false);
    expect(activity.level, ActivityLevel.visibleUnfocused);

    activity.setVisible(false);
    expect(activity.level, ActivityLevel.hidden);

    activity.setFocused(true);
    expect(activity.level, ActivityLevel.hidden);

    activity.setVisible(true);
    expect(activity.level, ActivityLevel.focused);
  });
}
