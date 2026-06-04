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

  test('persists widget visibility and order', () async {
    final prefs = await SharedPreferences.getInstance();
    final provider = DashboardProvider(prefs);

    await provider.setWidgetEnabled('weather', false);
    provider.reorderDashboardWidget(0, 2);
    await provider.setWidgetSize('weather', 'large');

    expect(provider.isWidgetEnabled('weather'), isFalse);
    expect(provider.widgetSize('weather'), 'large');
    expect(provider.widgetOrder[1], 'clock');
    expect(prefs.getStringList('disabledWidgets'), contains('weather'));
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

  test('model decoding tolerates missing optional fields', () {
    final app = AppShortcut.fromJson({'id': 'a1', 'name': 'Editor'});
    final site = WebShortcut.fromJson({'id': 'w1', 'name': 'Docs'});
    final todo = TodoItem.fromJson({'id': 't1', 'text': 'Review'});

    expect(app.executablePath, isEmpty);
    expect(site.url, isEmpty);
    expect(todo.completed, isFalse);
  });
}
