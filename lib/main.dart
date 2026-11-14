import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:provider/provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/dashboard_provider.dart';
import 'providers/agenda_provider.dart';
import 'providers/window_activity_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/prayer_times_provider.dart';
import 'providers/system_provider.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for Windows desktop
  await windowManager.ensureInitialized();
  if (Platform.isWindows) {
    await Window.initialize();
    await SystemTheme.accentColor.load();
  }
  PaintingBinding.instance.imageCache.maximumSize = 8;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;

  final prefs = await SharedPreferences.getInstance();
  final startInWidgetMode = prefs.getBool('desktopWidgetMode') ?? false;
  final savedWidgetW = prefs.getDouble('widgetWinW');
  final savedWidgetH = prefs.getDouble('widgetWinH');
  final savedDashboardW = prefs.getDouble('dashboardWinW');
  final savedDashboardH = prefs.getDouble('dashboardWinH');
  final widgetHideTaskbar =
      prefs.getBool('desktopWidgetHideFromTaskbar') ?? true;

  final WindowOptions windowOptions = startInWidgetMode
      ? WindowOptions(
          size: Size(
            (savedWidgetW ?? 380).clamp(280.0, 1200.0),
            (savedWidgetH ?? 640).clamp(220.0, 1200.0),
          ),
          minimumSize: const Size(280, 220),
          center: prefs.getDouble('widgetWinX') == null,
          backgroundColor: Colors.transparent,
          skipTaskbar: widgetHideTaskbar,
          titleBarStyle: TitleBarStyle.hidden,
          windowButtonVisibility: false,
          title: 'Nexus Dashboard',
        )
      : WindowOptions(
          size: Size(
            (savedDashboardW ?? 1440).clamp(1024.0, 3840.0),
            (savedDashboardH ?? 900).clamp(700.0, 2160.0),
          ),
          minimumSize: const Size(1024, 700),
          center: prefs.getDouble('dashboardWinX') == null,
          backgroundColor: Colors.transparent,
          skipTaskbar: false,
          titleBarStyle: TitleBarStyle.normal,
          windowButtonVisibility: true,
          title: 'Nexus Dashboard',
        );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    final prefix = startInWidgetMode ? 'widgetWin' : 'dashboardWin';
    final x = prefs.getDouble('${prefix}X');
    final y = prefs.getDouble('${prefix}Y');
    if (x != null && y != null) {
      await windowManager.setPosition(Offset(x, y));
    }
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider(prefs)),
        ChangeNotifierProvider(create: (_) => AgendaProvider(prefs)),
        ChangeNotifierProvider(create: (_) => WindowActivityProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => PrayerTimesProvider()),
        ChangeNotifierProxyProvider2<
          DashboardProvider,
          WindowActivityProvider,
          SystemProvider
        >(
          create: (_) => SystemProvider(monitoringEnabled: false),
          update: (_, dashboard, activity, system) {
            final provider = system ?? SystemProvider(monitoringEnabled: false);
            provider.setLowResourceMode(dashboard.lowResourceMode);
            provider.setActivityLevel(activity.level);
            final systemWidgetVisible = dashboard.desktopWidgetMode
                ? dashboard.isDesktopWidgetEnabled('system')
                : dashboard.isWidgetEnabled('system');
            provider.setMonitoringEnabled(
              systemWidgetVisible && activity.level != ActivityLevel.hidden,
            );
            return provider;
          },
        ),
      ],
      child: const NexusDashboardApp(),
    ),
  );
}

class NexusDashboardApp extends StatefulWidget {
  const NexusDashboardApp({super.key});

  @override
  State<NexusDashboardApp> createState() => _NexusDashboardAppState();
}

class _NexusDashboardAppState extends State<NexusDashboardApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final appearance = context
        .select<DashboardProvider, (ThemeModePreference, double, Color)>(
          (dashboard) => (
            dashboard.themeModePreference,
            dashboard.glassIntensity,
            dashboard.accentColorValue,
          ),
        );
    return MaterialApp(
      title: 'Nexus Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightThemeWithAccent(appearance.$3, appearance.$2),
      darkTheme: AppTheme.darkThemeWithAccent(appearance.$3, appearance.$2),
      themeMode: switch (appearance.$1) {
        ThemeModePreference.system => ThemeMode.system,
        ThemeModePreference.light => ThemeMode.light,
        ThemeModePreference.dark => ThemeMode.dark,
      },
      home: const DashboardScreen(),
    );
  }
}
