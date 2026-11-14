import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_dashboard/models/models.dart';
import 'package:nexus_dashboard/providers/dashboard_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('adds todos with trimmed text and ignores empty todos', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    provider.addTodo('  Call pharmacy  ');
    provider.addTodo('   ');

    expect(provider.todos, hasLength(1));
    expect(provider.todos.single.text, 'Call pharmacy');
    expect(provider.pendingTodos, hasLength(1));
  });

  test('toggleTodo ignores unknown ids instead of throwing', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    expect(() => provider.toggleTodo('missing'), returnsNormally);
  });

  test('loads and persists dark mode preference', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    expect(provider.useDarkMode, isTrue);
    expect(provider.themeModePreference, ThemeModePreference.dark);

    await provider.setUseDarkMode(false);

    expect(provider.useDarkMode, isFalse);
    expect(provider.themeModePreference, ThemeModePreference.light);
    expect(prefs.getBool('useDarkMode'), isFalse);
  });

  test(
    'persists system theme preference and resolves effective mode',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = DashboardProvider(prefs);

      await provider.setThemeModePreference(ThemeModePreference.system);

      expect(provider.themeModePreference, ThemeModePreference.system);
      expect(prefs.getString('themeModePreference'), 'system');
      expect(provider.resolveUseDarkMode(platformDarkMode: true), isTrue);
      expect(provider.resolveUseDarkMode(platformDarkMode: false), isFalse);
    },
  );

  test('defaults to Abdo and standard window controls', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    expect(provider.userName, 'Abdo');
    expect(provider.borderlessEnabled, isFalse);
  });

  test('persists takeover and transparency settings', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    await provider.setTakeoverMode(true);
    await provider.setFullscreenEnabled(true);
    await provider.setAlwaysOnTop(true);
    await provider.setHideFromTaskbar(true);
    await provider.setWindowOpacity(0.64);
    await provider.setBackgroundDim(0.42);
    await provider.setBlurStrength(12);
    await provider.setGlassIntensity(0.7);

    expect(provider.takeoverMode, isTrue);
    expect(provider.fullscreenEnabled, isTrue);
    expect(provider.alwaysOnTop, isTrue);
    expect(provider.hideFromTaskbar, isTrue);
    expect(provider.windowOpacity, 0.64);
    expect(provider.backgroundDim, 0.42);
    expect(provider.blurStrength, 12);
    expect(provider.glassIntensity, 0.7);
  });

  test('migrates legacy background image into rotation list', () async {
    SharedPreferences.setMockInitialValues({
      'backgroundImage': r'C:\bg\one.jpg',
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    expect(provider.backgroundImagePaths, [r'C:\bg\one.jpg']);
    expect(provider.currentBackgroundImagePath, r'C:\bg\one.jpg');
  });

  test('adds unique background images and clears them', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    await provider.addBackgroundImages([
      r'C:\bg\one.jpg',
      r'C:\bg\two.jpg',
      r'C:\bg\one.jpg',
    ]);

    expect(provider.backgroundImagePaths, [r'C:\bg\one.jpg', r'C:\bg\two.jpg']);
    expect(prefs.getStringList('backgroundImages'), [
      r'C:\bg\one.jpg',
      r'C:\bg\two.jpg',
    ]);

    await provider.clearBackgroundImages();

    expect(provider.backgroundImagePaths, isEmpty);
    expect(provider.currentBackgroundImagePath, isEmpty);
    expect(prefs.getStringList('backgroundImages'), isEmpty);
  });

  test('tracks valid background images outside the build path', () async {
    final tempDir = await Directory.systemTemp.createTemp('nexus-bg-test');
    try {
      final existing = File('${tempDir.path}${Platform.pathSeparator}bg.jpg');
      await existing.writeAsString('fake image');

      final prefs = await SharedPreferences.getInstance();
      final provider = DashboardProvider(prefs);

      await provider.addBackgroundImages([existing.path, r'C:\missing.jpg']);

      expect(provider.backgroundImagePaths, [existing.path, r'C:\missing.jpg']);
      expect(provider.validBackgroundImagePaths, [existing.path]);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('persists and validates background rotation interval', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    await provider.setBackgroundRotationMinutes(10);

    expect(provider.backgroundRotationMinutes, 10);
    expect(prefs.getInt('backgroundRotationMinutes'), 10);

    await provider.setBackgroundRotationMinutes(7);

    expect(provider.backgroundRotationMinutes, 10);
    expect(prefs.getInt('backgroundRotationMinutes'), 10);
  });

  test('advances background image through shuffled rotation list', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    await provider.addBackgroundImages([
      r'C:\bg\one.jpg',
      r'C:\bg\two.jpg',
      r'C:\bg\three.jpg',
    ]);

    final firstPath = provider.currentBackgroundImagePath;
    provider.advanceBackgroundImage();

    expect(provider.currentBackgroundImagePath, isNot(firstPath));
    expect(
      provider.backgroundImagePaths,
      contains(provider.currentBackgroundImagePath),
    );
  });

  test('persists widget visibility and order', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    await provider.setWidgetEnabled('weather', false);
    provider.reorderDashboardWidget(0, 2);
    expect(provider.isWidgetEnabled('weather'), isFalse);
    expect(provider.widgetOrder[1], 'clock');
    expect(prefs.getStringList('disabledWidgets'), contains('weather'));
  });

  test('migrates legacy layout to breakpoint placements v3', () async {
    SharedPreferences.setMockInitialValues({
      'widgetOrder': ['websites', 'clock', 'shutdown'],
      'widgetSizes': ['clock:large'],
      'widgetLayouts': ['{"id":"clock","x":4,"y":2,"width":5,"height":2}'],
      'disabledWidgets': ['shutdown', 'restart', 'sleep', 'weather'],
      'userName': 'Existing User',
      'todos': [
        '{"id":"todo-1","text":"Keep me","completed":false,"createdAt":"2026-01-01T09:00:00.000"}',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    expect(provider.widgetOrder, DashboardProvider.defaultWidgetOrder);
    expect(provider.isWidgetEnabled('weather'), isFalse);
    expect(provider.isWidgetEnabled('power'), isFalse);
    expect(provider.isWidgetEnabled('agenda'), isTrue);
    expect(provider.userName, 'Existing User');
    expect(provider.todos.single.text, 'Keep me');
    expect(prefs.getInt('layoutSchemaVersion'), 3);
    expect(prefs.containsKey('widgetSizes'), isFalse);
    expect(prefs.containsKey('widgetLayouts'), isFalse);
    expect(prefs.getStringList('widgetPlacementsWide'), isNotEmpty);
    expect(prefs.getStringList('widgetPlacementsMedium'), isNotEmpty);
  });

  test('persists independent wide and medium placements', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);
    final wideClock = provider
        .placementsFor(LayoutBreakpoint.wide)
        .singleWhere((item) => item.id == 'clock');

    await provider.updateWidgetPlacement(
      LayoutBreakpoint.wide,
      wideClock.copyWith(x: 6, y: 6),
    );

    expect(
      provider
          .placementsFor(LayoutBreakpoint.wide)
          .singleWhere((item) => item.id == 'clock')
          .x,
      6,
    );
    expect(
      provider
          .placementsFor(LayoutBreakpoint.medium)
          .singleWhere((item) => item.id == 'clock')
          .x,
      0,
    );
    expect(prefs.getStringList('widgetPlacementsWide'), isNotEmpty);
  });

  test('removes one background and keeps a valid current selection', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);
    await provider.addBackgroundImages(['one.jpg', 'two.jpg', 'three.jpg']);
    final removed = provider.currentBackgroundImagePath;

    await provider.removeBackgroundImage(removed);

    expect(provider.backgroundImagePaths, isNot(contains(removed)));
    expect(
      provider.backgroundImagePaths,
      contains(provider.currentBackgroundImagePath),
    );
    expect(prefs.getStringList('backgroundImages'), hasLength(2));
  });

  test('includes agenda and consolidated power widget by default', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    expect(provider.visibleWidgetOrder, contains('agenda'));
    expect(provider.visibleWidgetOrder, contains('power'));
    expect(provider.visibleWidgetOrder, isNot(contains('shutdown')));
  });

  test('reorders websites', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);
    final first = provider.websites.first.id;

    provider.reorderWebsites(0, 2);

    expect(provider.websites[1].id, first);
  });

  test('persists weather preferences', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    await provider.setWeatherMetricUnits(false);
    await provider.setWeatherRefreshMinutes(20);

    expect(provider.weatherMetricUnits, isFalse);
    expect(provider.weatherRefreshMinutes, 20);
  });

  test('persists low resource mode preference', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    expect(provider.lowResourceMode, isFalse);

    await provider.setLowResourceMode(true);

    expect(provider.lowResourceMode, isTrue);
    expect(prefs.getBool('lowResourceMode'), isTrue);
  });

  test('model decoding tolerates missing optional fields', () {
    final app = AppShortcut.fromJson({'id': 'a1', 'name': 'Editor'});
    final site = WebShortcut.fromJson({'id': 'w1', 'name': 'Docs'});
    final todo = TodoItem.fromJson({'id': 't1', 'text': 'Review'});

    expect(app.executablePath, isEmpty);
    expect(site.url, isEmpty);
    expect(todo.completed, isFalse);
  });

  test(
    'manages desktop widget mode and independent widget selection/order',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final provider = DashboardProvider(prefs);

      expect(provider.desktopWidgetMode, isFalse);
      expect(
        provider.visibleDesktopWidgetOrder,
        ['clock', 'weather', 'prayerTimes'],
      );

      await provider.setDesktopWidgetMode(true);
      expect(provider.desktopWidgetMode, isTrue);
      expect(prefs.getBool('desktopWidgetMode'), isTrue);

      await provider.setDesktopWidgetEnabled('weather', false);
      await provider.setDesktopWidgetEnabled('todos', true);
      expect(provider.isDesktopWidgetEnabled('weather'), isFalse);
      expect(provider.isDesktopWidgetEnabled('todos'), isTrue);
      // Full dashboard visibility remains untouched.
      expect(provider.isWidgetEnabled('weather'), isTrue);

      provider.reorderDesktopWidget(0, 2);
      expect(provider.desktopWidgetOrder[1], 'clock');
      expect(provider.widgetOrder[0], 'clock');
    },
  );

  test('persists desktop widget window options and per-mode bounds', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    await provider.setDesktopWidgetAlwaysOnTop(true);
    await provider.setDesktopWidgetHideFromTaskbar(false);
    await provider.setDesktopWidgetLockPosition(true);
    await provider.setDesktopWidgetOpacity(0.75);
    await provider.saveDashboardWindowBounds(
      const Rect.fromLTWH(40, 60, 1440, 900),
    );
    await provider.saveDesktopWidgetWindowBounds(
      const Rect.fromLTWH(1050, 120, 380, 640),
    );

    final reloaded = DashboardProvider(prefs);
    expect(reloaded.desktopWidgetAlwaysOnTop, isTrue);
    expect(reloaded.desktopWidgetHideFromTaskbar, isFalse);
    expect(reloaded.desktopWidgetLockPosition, isTrue);
    expect(reloaded.desktopWidgetOpacity, 0.75);
    expect(
      reloaded.dashboardWindowBounds,
      const Rect.fromLTWH(40, 60, 1440, 900),
    );
    expect(
      reloaded.desktopWidgetWindowBounds,
      const Rect.fromLTWH(1050, 120, 380, 640),
    );
  });
}
