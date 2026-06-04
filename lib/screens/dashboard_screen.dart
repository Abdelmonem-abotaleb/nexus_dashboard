import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/dashboard_provider.dart';
import '../providers/weather_provider.dart';
import '../services/tray_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clock_widget.dart';
import '../widgets/weather_widget.dart';
import '../widgets/app_launcher_widget.dart';
import '../widgets/website_widget.dart';
import '../widgets/todo_widget.dart';
import '../widgets/system_stats_widget.dart';
import '../widgets/settings_panel.dart';
import '../widgets/particle_background.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WindowListener {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final FocusNode _focusNode = FocusNode();
  Timer? _startupFocusTimer;
  String _lastWindowSignature = '';
  bool _settingsOpen = false;
  bool _fullscreenTopBarVisible = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Fetch weather after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrayService.instance.initialize();
      final dashProvider = context.read<DashboardProvider>();
      context.read<WeatherProvider>().fetchWeather(
        apiKey: dashProvider.weatherApiKey,
        city: dashProvider.weatherCity.isNotEmpty
            ? dashProvider.weatherCity
            : null,
        useMetricUnits: dashProvider.weatherMetricUnits,
      );
      _startupFocusTimer = Timer(
        Duration(seconds: dashProvider.startupDelaySeconds),
        _bringToFront,
      );
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _fadeController.dispose();
    _startupFocusTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final size = MediaQuery.of(context).size;
    final platformDarkMode =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final fullscreenTakeover =
        dashboard.takeoverMode && dashboard.fullscreenEnabled;
    AppTheme.useDarkMode = dashboard.resolveUseDarkMode(
      platformDarkMode: platformDarkMode,
    );
    AppTheme.glassIntensity = dashboard.glassIntensity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyWindowSettings(dashboard);
    });

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, dashboard),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // ── Background ──────────────────────────────────────────────────
            _buildBackground(dashboard),

            // ── Particle effect ──────────────────────────────────────────────
            const ParticleBackground(),

            // ── Main content ─────────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
                child: fullscreenTakeover
                    ? _buildFullscreenContent(context, dashboard, size)
                    : Column(
                        children: [
                          _buildTopBar(context, dashboard),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                              child: _buildDashboardLayout(
                                context,
                                dashboard,
                                size,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            // ── Settings panel overlay ───────────────────────────────────────
            if (_settingsOpen)
              GestureDetector(
                onTap: () => setState(() => _settingsOpen = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: dashboard.blurStrength,
                      sigmaY: dashboard.blurStrength,
                    ),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            if (_settingsOpen)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: SettingsPanel(
                  onClose: () => setState(() => _settingsOpen = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event, DashboardProvider dashboard) {
    if (event is! KeyDownEvent) return;
    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyN &&
        keyboard.isControlPressed &&
        keyboard.isAltPressed) {
      dashboard.setTakeoverMode(false);
      dashboard.setFullscreenEnabled(false);
      dashboard.setAlwaysOnTop(false);
      dashboard.setHideFromTaskbar(false);
      _bringToFront();
    }
  }

  Future<void> _applyWindowSettings(DashboardProvider dashboard) async {
    final signature = [
      dashboard.takeoverMode,
      dashboard.fullscreenEnabled,
      dashboard.alwaysOnTop,
      dashboard.hideFromTaskbar,
      dashboard.borderlessEnabled,
      dashboard.protectWindowControls,
      dashboard.windowOpacity,
    ].join('|');
    if (_lastWindowSignature == signature) return;
    _lastWindowSignature = signature;

    final takeover = dashboard.takeoverMode;
    final fullscreenTakeover = takeover && dashboard.fullscreenEnabled;
    final protected = takeover && dashboard.protectWindowControls;
    await windowManager.setOpacity(dashboard.windowOpacity);
    await windowManager.setAlwaysOnTop(
      fullscreenTakeover && dashboard.alwaysOnTop,
    );
    await windowManager.setSkipTaskbar(
      fullscreenTakeover && dashboard.hideFromTaskbar,
    );
    await windowManager.setFullScreen(fullscreenTakeover);
    await windowManager.setPreventClose(true);
    await windowManager.setClosable(!protected);
    await windowManager.setMinimizable(!protected);
    await windowManager.setTitleBarStyle(
      dashboard.borderlessEnabled ? TitleBarStyle.hidden : TitleBarStyle.normal,
    );
    if (!fullscreenTakeover) {
      await windowManager.show();
    }
  }

  Future<void> _bringToFront() async {
    await TrayService.instance.showWindow();
  }

  @override
  void onWindowClose() async {
    if (TrayService.instance.isExiting) {
      await windowManager.destroy();
      return;
    }

    final dashboard = context.read<DashboardProvider>();
    if (dashboard.takeoverMode && dashboard.protectWindowControls) {
      await _bringToFront();
      return;
    }
    await TrayService.instance.hideWindow();
  }

  @override
  void onWindowMinimize() async {
    final dashboard = context.read<DashboardProvider>();
    if (dashboard.takeoverMode && dashboard.protectWindowControls) {
      await windowManager.restore();
      await _bringToFront();
    }
  }

  @override
  void onWindowRestore() async {
    _lastWindowSignature = '';
    await _applyWindowSettings(context.read<DashboardProvider>());
  }

  Widget _buildBackground(DashboardProvider dashboard) {
    if (dashboard.backgroundImagePath.isNotEmpty) {
      final file = File(dashboard.backgroundImagePath);
      if (file.existsSync()) {
        return SizedBox.expand(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(file, fit: BoxFit.cover),
              Container(
                color: AppTheme.darkBase.withValues(
                  alpha: dashboard.backgroundDim,
                ),
              ),
            ],
          ),
        );
      }
    }

    // Default gradient background
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            // Subtle radial glows
            Positioned(
              top: -200,
              left: -100,
              child: Container(
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.neonBlue.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -150,
              right: -100,
              child: Container(
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.neonPurple.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, DashboardProvider dashboard) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: DragToMoveArea(
              child: SizedBox(
                height: 52,
                child: Row(
                  children: [
                    Image.asset(
                      'assets/icons/logo.png',
                      height: 32,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.open_with_rounded,
                      color: AppTheme.textMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DRAG',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Edit mode toggle
          _TopBarButton(
            icon: dashboard.isEditMode
                ? Icons.check_rounded
                : Icons.tune_rounded,
            label: dashboard.isEditMode ? 'DONE' : 'EDIT',
            color: dashboard.isEditMode
                ? AppTheme.neonGreen
                : AppTheme.textSecondary,
            onTap: () => dashboard.toggleEditMode(),
          ),

          const SizedBox(width: 8),

          // Settings
          _TopBarButton(
            icon: Icons.settings_outlined,
            label: 'SETTINGS',
            color: AppTheme.textSecondary,
            onTap: () => setState(() => _settingsOpen = true),
          ),

          const SizedBox(width: 8),

          // Window controls
          _WindowControls(),
        ],
      ),
    );
  }

  Widget _buildFullscreenContent(
    BuildContext context,
    DashboardProvider dashboard,
    Size size,
  ) {
    final topBarVisible = _fullscreenTopBarVisible || _settingsOpen;

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: _buildDashboardLayout(context, dashboard, size),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 12,
          child: MouseRegion(
            onEnter: (_) => setState(() => _fullscreenTopBarVisible = true),
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          top: topBarVisible ? 0 : -56,
          left: 0,
          right: 0,
          child: MouseRegion(
            onEnter: (_) => setState(() => _fullscreenTopBarVisible = true),
            onExit: (_) => setState(() => _fullscreenTopBarVisible = false),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: dashboard.blurStrength,
                  sigmaY: dashboard.blurStrength,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard.withValues(alpha: 0.72),
                    border: Border(
                      bottom: BorderSide(color: AppTheme.glassBorder),
                    ),
                  ),
                  child: _buildTopBar(context, dashboard),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardLayout(
    BuildContext context,
    DashboardProvider dashboard,
    Size size,
  ) {
    final availableWidth = size.width - 48;
    final compact = availableWidth < 1180;

    return SingleChildScrollView(
      child: Wrap(
        spacing: 20,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.start,
        children: dashboard.visibleWidgetOrder
            .map(
              (id) => _buildDashboardWidget(
                id,
                compact,
                availableWidth,
                dashboard.widgetSize(id),
              ),
            )
            .whereType<Widget>()
            .toList(),
      ),
    );
  }

  Widget? _buildDashboardWidget(
    String id,
    bool compact,
    double width,
    String size,
  ) {
    final scale = switch (size) {
      'compact' => 0.82,
      'large' => 1.25,
      _ => 1.0,
    };
    final sideWidth = compact ? width : (300.0 * scale).clamp(240.0, 380.0);
    final centerBase = compact ? width : (width - 640).clamp(420.0, 760.0);
    final centerWidth = compact
        ? width
        : (centerBase * scale).clamp(360.0, width);
    final todoWidth = compact ? width : (280.0 * scale).clamp(240.0, 360.0);
    final todoHeight = switch (size) {
      'compact' => 400.0,
      'large' => 650.0,
      _ => 520.0,
    };

    switch (id) {
      case 'clock':
        return SizedBox(width: sideWidth, child: const ClockWidget());
      case 'weather':
        return SizedBox(width: sideWidth, child: const WeatherWidget());
      case 'system':
        return SizedBox(width: sideWidth, child: const SystemStatsWidget());
      case 'apps':
        return SizedBox(width: centerWidth, child: const AppLauncherWidget());
      case 'websites':
        return SizedBox(width: centerWidth, child: const WebsiteWidget());
      case 'todos':
        return SizedBox(
          width: todoWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: todoHeight),
            child: const TodoWidget(),
          ),
        );
      default:
        return null;
    }
  }
}

// ─── Top Bar Button ───────────────────────────────────────────────────────────
class _TopBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _TopBarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Window Controls ──────────────────────────────────────────────────────────
class _WindowControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    if (dashboard.protectWindowControls && dashboard.takeoverMode) {
      return _TopBarButton(
        icon: Icons.lock_outline,
        label: 'LOCKED',
        color: AppTheme.textMuted,
        onTap: () {},
      );
    }

    return Row(
      children: [
        _WinButton(
          color: const Color(0xFFFFBD2E),
          icon: Icons.minimize_rounded,
          onTap: () => _minimizeWindow(dashboard),
        ),
        const SizedBox(width: 8),
        _WinButton(
          color: const Color(0xFF28C840),
          icon: Icons.crop_square_rounded,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        const SizedBox(width: 8),
        _WinButton(
          color: const Color(0xFFFF5F56),
          icon: Icons.close_rounded,
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }

  Future<void> _minimizeWindow(DashboardProvider dashboard) async {
    if (dashboard.takeoverMode && dashboard.fullscreenEnabled) {
      await windowManager.setFullScreen(false);
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSkipTaskbar(false);
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
    await windowManager.minimize();
  }
}

class _WinButton extends StatefulWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _WinButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: widget.color,
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: Colors.black.withValues(alpha: _hovered ? 0.75 : 0.5),
          ),
        ),
      ),
    );
  }
}
