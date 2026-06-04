import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexus_dashboard/theme/app_theme.dart';

void main() {
  test('provides distinct dark and light themes', () {
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(
      AppTheme.darkTheme.scaffoldBackgroundColor,
      isNot(AppTheme.lightTheme.scaffoldBackgroundColor),
    );
  });
}
