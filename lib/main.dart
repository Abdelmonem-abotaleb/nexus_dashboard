import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/dashboard_provider.dart';
import 'providers/weather_provider.dart';
import 'providers/system_provider.dart';
import 'screens/dashboard_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for Windows desktop
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1440, 900),
    minimumSize: Size(1024, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    windowButtonVisibility: true,
    title: 'Nexus Dashboard',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardProvider(prefs)),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => SystemProvider()),
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
    final dashboard = context.watch<DashboardProvider>();
    final platformDarkMode =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    AppTheme.useDarkMode = dashboard.resolveUseDarkMode(
      platformDarkMode: platformDarkMode,
    );
    AppTheme.glassIntensity = dashboard.glassIntensity;

    return MaterialApp(
      title: 'Nexus Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: switch (dashboard.themeModePreference) {
        ThemeModePreference.system => ThemeMode.system,
        ThemeModePreference.light => ThemeMode.light,
        ThemeModePreference.dark => ThemeMode.dark,
      },
      home: const DashboardScreen(),
    );
  }
}
