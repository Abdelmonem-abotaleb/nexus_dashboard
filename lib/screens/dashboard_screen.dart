import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../models/models.dart';
import '../providers/dashboard_provider.dart';
import '../providers/window_activity_provider.dart';
import '../services/dashboard_grid_service.dart';
import '../services/tray_service.dart';
import '../services/startup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clock_widget.dart';
import '../widgets/weather_widget.dart';
import '../widgets/prayer_times_widget.dart';
import '../widgets/app_launcher_widget.dart';
import '../widgets/website_widget.dart';
import '../widgets/todo_widget.dart';
import '../widgets/system_stats_widget.dart';
import '../widgets/settings_panel.dart';
import '../widgets/particle_background.dart';
import '../widgets/power_action_widget.dart';
import '../widgets/agenda_widget.dart';
import '../widgets/command_palette.dart';
import '../widgets/desktop_widget_view.dart';
import '../services/hotkey_service.dart';

class DashboardScreen extends StatefulWidget {
  final StartupService? startupService;
  const DashboardScreen({super.key, this.startupService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WindowListener {
  static const double _gridGap = 16;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final FocusNode _focusNode = FocusNode();
  Timer? _startupFocusTimer;
  Timer? _backgroundRotationTimer;
  Timer? _boundsSaveTimer;
  DashboardProvider? _dashboardProvider;
  String _lastWindowSignature = '';
  String _lastBackgroundRotationSignature = '';
  String _lastDashboardSettingsSignature = '';
  bool? _lastAppliedWidgetMode;
  bool _isApplyingWindowMode = false;
  bool _pendingWindowUpdate = false;
  bool _settingsOpen = false;
  bool _commandPaletteOpen = false;
  bool _fullscreenTopBarVisible = false;
  bool _visualEffectsActive = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    TrayService.instance.visibleNotifier.addListener(_handleTrayVisibility);
    TrayService.instance.onToggleWidgetMode = _toggleWidgetModeFromTray;
    HotkeyService.instance.initialize(
      onAction: () {
        if (mounted) {
          setState(() => _commandPaletteOpen = true);
        }
      },
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    // Initialize desktop services after build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrayService.instance.initialize();
      final dashProvider = context.read<DashboardProvider>();
      _startupFocusTimer = Timer(
        Duration(seconds: dashProvider.startupDelaySeconds),
        _bringToFront,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dashboardProvider = context.read<DashboardProvider>();
    if (_dashboardProvider == dashboardProvider) return;

    _dashboardProvider?.removeListener(_handleDashboardProviderChange);
    _dashboardProvider = dashboardProvider;
    _dashboardProvider!.addListener(_handleDashboardProviderChange);
    _handleDashboardProviderChange();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    TrayService.instance.visibleNotifier.removeListener(_handleTrayVisibility);
    if (TrayService.instance.onToggleWidgetMode == _toggleWidgetModeFromTray) {
      TrayService.instance.onToggleWidgetMode = null;
    }
    _dashboardProvider?.removeListener(_handleDashboardProviderChange);
    _fadeController.dispose();
    _startupFocusTimer?.cancel();
    _backgroundRotationTimer?.cancel();
    _boundsSaveTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.select<DashboardProvider, int>(
      (dashboard) => dashboard.layoutRevision,
    );
    final dashboard = context.read<DashboardProvider>();
    final size = MediaQuery.of(context).size;
    final fullscreenTakeover =
        dashboard.takeoverMode && dashboard.fullscreenEnabled;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKeyEvent(event, dashboard),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Ã¢â€â‚¬Ã¢â€â‚¬ Background Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            if (!dashboard.desktopWidgetMode) _buildBackground(dashboard),

            // Ã¢â€â‚¬Ã¢â€â‚¬ Particle effect Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            if (!dashboard.desktopWidgetMode &&
                shouldRenderParticles(
                  lowResourceMode: dashboard.lowResourceMode,
                  hasBackgroundImage: _activeBackgroundImagePath(
                    dashboard,
                  ).isNotEmpty,
                ))
              ParticleBackground(active: _visualEffectsActive),

            // Ã¢â€â‚¬Ã¢â€â‚¬ Main content Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            FadeTransition(
              opacity: _fadeAnimation,
              child: SafeArea(
                child: dashboard.desktopWidgetMode
                    ? DesktopWidgetView(
                        buildWidget: _buildDashboardWidget,
                        onOpenSettings: () =>
                            setState(() => _settingsOpen = true),
                      )
                    : fullscreenTakeover
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

            // Ã¢â€â‚¬Ã¢â€â‚¬ Settings panel overlay Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            if (_settingsOpen)
              Semantics(
                button: true,
                label: 'Close settings',
                child: InkWell(
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
              ),
            if (_settingsOpen)
              Positioned.fill(
                child: Center(
                  child: SettingsPanel(
                    startupService: widget.startupService,
                    onClose: () => setState(() => _settingsOpen = false),
                  ),
                ),
              ),

            // ── Command Palette overlay ───────────────────────────────────────
            if (_commandPaletteOpen)
              Semantics(
                button: true,
                label: 'Close command palette',
                child: InkWell(
                  onTap: () => setState(() => _commandPaletteOpen = false),
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
              ),
            if (_commandPaletteOpen)
              Positioned.fill(
                child: CommandPalette(
                  onClose: () => setState(() => _commandPaletteOpen = false),
                  onOpenSettings: () => setState(() => _settingsOpen = true),
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
    if (event.logicalKey == LogicalKeyboardKey.escape && _commandPaletteOpen) {
      setState(() => _commandPaletteOpen = false);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && _settingsOpen) {
      setState(() => _settingsOpen = false);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && dashboard.isEditMode) {
      dashboard.toggleEditMode();
      return;
    }
    if ((event.logicalKey == LogicalKeyboardKey.keyK && keyboard.isControlPressed) ||
        (event.logicalKey == LogicalKeyboardKey.space && (keyboard.isControlPressed || keyboard.isAltPressed))) {
      setState(() => _commandPaletteOpen = !_commandPaletteOpen);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.comma &&
        keyboard.isControlPressed) {
      setState(() => _settingsOpen = true);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyW &&
        keyboard.isControlPressed &&
        keyboard.isAltPressed) {
      dashboard.toggleDesktopWidgetMode();
      return;
    }
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

  void _toggleWidgetModeFromTray() {
    if (!mounted) return;
    context.read<DashboardProvider>().toggleDesktopWidgetMode();
  }

  Future<void> _applyWindowSettings(DashboardProvider dashboard) async {
    final signature = [
      dashboard.desktopWidgetMode,
      dashboard.desktopWidgetAlwaysOnTop,
      dashboard.desktopWidgetHideFromTaskbar,
      dashboard.desktopWidgetLockPosition,
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

    final previousMode = _lastAppliedWidgetMode;
    final enteringWidgetMode =
        previousMode != null && !previousMode && dashboard.desktopWidgetMode;
    final exitingWidgetMode =
        previousMode != null && previousMode && !dashboard.desktopWidgetMode;
    _lastAppliedWidgetMode = dashboard.desktopWidgetMode;

    if (enteringWidgetMode) {
      _isApplyingWindowMode = true;
      try {
        final isFull = await windowManager.isFullScreen();
        final isMax = await windowManager.isMaximized();
        if (!isFull && !isMax) {
          final bounds = await windowManager.getBounds();
          await dashboard.saveDashboardWindowBounds(bounds);
        }
        if (isFull) await windowManager.setFullScreen(false);
        if (isMax) await windowManager.unmaximize();
        await windowManager.setMinimumSize(const Size(280, 220));
        final widgetBounds = dashboard.desktopWidgetWindowBounds;
        if (widgetBounds != null) {
          await windowManager.setBounds(widgetBounds);
        } else {
          await windowManager.setSize(const Size(380, 640));
          await windowManager.center();
        }
      } finally {
        _isApplyingWindowMode = false;
      }
    } else if (exitingWidgetMode) {
      _isApplyingWindowMode = true;
      try {
        final bounds = await windowManager.getBounds();
        await dashboard.saveDesktopWidgetWindowBounds(bounds);
        await windowManager.setResizable(true);
        await windowManager.setMinimumSize(const Size(1024, 700));
        final dashBounds = dashboard.dashboardWindowBounds;
        if (dashBounds != null) {
          await windowManager.setBounds(dashBounds);
        } else {
          await windowManager.setSize(const Size(1440, 900));
          await windowManager.center();
        }
      } finally {
        _isApplyingWindowMode = false;
      }
    }

    if (dashboard.desktopWidgetMode) {
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setOpacity(1.0);
      await windowManager.setAlwaysOnTop(dashboard.desktopWidgetAlwaysOnTop);
      await windowManager.setSkipTaskbar(dashboard.desktopWidgetHideFromTaskbar);
      await windowManager.setFullScreen(false);
      await windowManager.setPreventClose(true);
      await windowManager.setClosable(true);
      await windowManager.setMinimizable(true);
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      await windowManager.setResizable(!dashboard.desktopWidgetLockPosition);
      unawaited(dashboard.applyBackdropEffect());
      await windowManager.show();
      return;
    }

    final takeover = dashboard.takeoverMode;
    final fullscreenTakeover = takeover && dashboard.fullscreenEnabled;
    final protected = takeover && dashboard.protectWindowControls;
    await windowManager.setResizable(true);
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
    unawaited(dashboard.applyBackdropEffect());
    if (!fullscreenTakeover) {
      await windowManager.show();
    }
  }

  Future<void> _bringToFront() async {
    await TrayService.instance.showWindow();
  }

  void _handleDashboardProviderChange() {
    final dashboard = _dashboardProvider;
    if (dashboard == null) return;

    final signature = _dashboardSettingsSignature(dashboard);
    if (_lastDashboardSettingsSignature == signature) return;
    _lastDashboardSettingsSignature = signature;
    _scheduleWindowUpdate();
  }

  String _dashboardSettingsSignature(DashboardProvider dashboard) {
    return [
      dashboard.desktopWidgetMode,
      dashboard.desktopWidgetAlwaysOnTop,
      dashboard.desktopWidgetHideFromTaskbar,
      dashboard.desktopWidgetLockPosition,
      dashboard.takeoverMode,
      dashboard.fullscreenEnabled,
      dashboard.alwaysOnTop,
      dashboard.hideFromTaskbar,
      dashboard.borderlessEnabled,
      dashboard.protectWindowControls,
      dashboard.windowOpacity,
      dashboard.backgroundRotationMinutes,
      ...dashboard.validBackgroundImagePaths,
    ].join('|');
  }

  void _scheduleWindowUpdate() {
    if (_pendingWindowUpdate) return;
    _pendingWindowUpdate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingWindowUpdate = false;
      if (!mounted) return;
      final dashboard = context.read<DashboardProvider>();
      _applyWindowSettings(dashboard);
      _configureBackgroundRotation(dashboard);
    });
  }

  void _configureBackgroundRotation(DashboardProvider dashboard) {
    final validPaths = dashboard.validBackgroundImagePaths;
    final active = context.read<WindowActivityProvider>().isActive;
    final signature = [
      active,
      dashboard.backgroundRotationMinutes,
      ...validPaths,
    ].join('|');
    if (_lastBackgroundRotationSignature == signature) return;
    _lastBackgroundRotationSignature = signature;
    _backgroundRotationTimer?.cancel();
    _backgroundRotationTimer = null;
    if (!active || validPaths.length < 2) return;

    _backgroundRotationTimer = Timer.periodic(
      Duration(minutes: dashboard.backgroundRotationMinutes),
      (_) {
        if (!mounted) return;
        context.read<DashboardProvider>().advanceBackgroundImage();
      },
    );
  }

  void _handleTrayVisibility() {
    final visible = TrayService.instance.isVisible;
    _setActivity(visible: visible, focused: visible ? null : false);
  }

  void _setActivity({bool? visible, bool? focused}) {
    if (!mounted) return;
    final activity = context.read<WindowActivityProvider>();
    if (visible != null) activity.setVisible(visible);
    if (focused != null) activity.setFocused(focused);
    final active = activity.isActive;
    setState(() => _visualEffectsActive = active);
    _lastBackgroundRotationSignature = '';
    _configureBackgroundRotation(context.read<DashboardProvider>());
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
    _setActivity(visible: false, focused: false);
    await TrayService.instance.hideWindow();
  }

  @override
  void onWindowMinimize() async {
    _setActivity(visible: false, focused: false);
    final dashboard = context.read<DashboardProvider>();
    if (dashboard.takeoverMode && dashboard.protectWindowControls) {
      await windowManager.restore();
      await _bringToFront();
    }
  }

  @override
  void onWindowRestore() async {
    _setActivity(visible: true, focused: true);
    _lastWindowSignature = '';
    await _applyWindowSettings(context.read<DashboardProvider>());
  }

  @override
  void onWindowFocus() {
    _setActivity(visible: true, focused: true);
  }

  @override
  void onWindowBlur() {
    _setActivity(focused: false);
  }

  @override
  void onWindowMoved() {
    _scheduleBoundsSave();
  }

  @override
  void onWindowResized() {
    _scheduleBoundsSave();
  }

  void _scheduleBoundsSave() {
    if (_isApplyingWindowMode || !mounted) return;
    _boundsSaveTimer?.cancel();
    _boundsSaveTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || _isApplyingWindowMode) return;
      final isFull = await windowManager.isFullScreen();
      final isMax = await windowManager.isMaximized();
      final isMin = await windowManager.isMinimized();
      if (isFull || isMax || isMin || !mounted) return;
      final bounds = await windowManager.getBounds();
      if (!mounted) return;
      final dashboard = context.read<DashboardProvider>();
      if (dashboard.desktopWidgetMode) {
        await dashboard.saveDesktopWidgetWindowBounds(bounds);
      } else {
        await dashboard.saveDashboardWindowBounds(bounds);
      }
    });
  }

  Widget _buildBackground(DashboardProvider dashboard) {
    final imagePath = _activeBackgroundImagePath(dashboard);
    return SizedBox.expand(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            fit: StackFit.expand,
            children: [...previousChildren, ?currentChild],
          );
        },
        child: imagePath.isEmpty
            ? _buildDefaultBackground()
            : _buildImageBackground(imagePath, dashboard.backgroundDim),
      ),
    );
  }

  String _activeBackgroundImagePath(DashboardProvider dashboard) {
    final currentPath = dashboard.currentBackgroundImagePath;
    if (currentPath.isNotEmpty &&
        dashboard.validBackgroundImagePaths.contains(currentPath)) {
      return currentPath;
    }
    if (dashboard.validBackgroundImagePaths.isNotEmpty) {
      return dashboard.validBackgroundImagePaths.first;
    }
    return '';
  }

  Widget _buildImageBackground(String path, double backgroundDim) {
    final media = MediaQuery.of(context);
    final cacheWidth = (media.size.width * media.devicePixelRatio)
        .round()
        .clamp(1024, 4096);
    final cacheHeight = (media.size.height * media.devicePixelRatio)
        .round()
        .clamp(700, 2304);
    return Stack(
      key: ValueKey('background-image-$path'),
      fit: StackFit.expand,
      children: [
        Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
        Container(
          color: Theme.of(
            context,
          ).colorScheme.surface.withValues(alpha: backgroundDim),
        ),
      ],
    );
  }

  Widget _buildDefaultBackground() {
    // Default gradient background
    return DecoratedBox(
      key: const ValueKey('default-background'),
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
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
                      cacheWidth: 64,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.open_with_rounded,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DRAG',
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
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

          // Desktop widget mode
          _TopBarButton(
            icon: Icons.picture_in_picture_alt_rounded,
            label: 'WIDGET',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onTap: () => dashboard.setDesktopWidgetMode(true),
          ),

          const SizedBox(width: 8),

          // Dashboard customization
          _TopBarButton(
            icon: dashboard.isEditMode
                ? Icons.check_rounded
                : Icons.dashboard_customize_outlined,
            label: dashboard.isEditMode ? 'DONE' : 'CUSTOMIZE',
            color: dashboard.isEditMode
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            onTap: () => _toggleCustomizeMode(dashboard),
          ),

          if (dashboard.isEditMode) ...[
            const SizedBox(width: 8),
            _TopBarButton(
              icon: Icons.restart_alt_rounded,
              label: 'RESET',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              onTap: () => _confirmResetLayout(dashboard),
            ),
          ],

          const SizedBox(width: 8),

          // Settings
          _TopBarButton(
            icon: Icons.settings_outlined,
            label: 'SETTINGS',
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            onTap: () => setState(() => _settingsOpen = true),
          ),

          const SizedBox(width: 8),

          // Window controls
          _WindowControls(),
        ],
      ),
    );
  }

  void _toggleCustomizeMode(DashboardProvider dashboard) {
    if (dashboard.isEditMode) {
      dashboard.toggleEditMode();
      return;
    }
    final contentWidth = MediaQuery.sizeOf(context).width - 48;
    if (_gridColumnCount(contentWidth) == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Customize widgets at a window width of 1024 px or more.',
          ),
        ),
      );
      return;
    }
    dashboard.toggleEditMode();
  }

  Future<void> _confirmResetLayout(DashboardProvider dashboard) async {
    final breakpoint = _breakpointForWidth(
      MediaQuery.sizeOf(context).width - 48,
    );
    if (breakpoint == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset this layout?'),
        content: Text(
          'Restore the default ${breakpoint == LayoutBreakpoint.wide ? 'wide' : 'medium'} widget arrangement?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset layout'),
          ),
        ],
      ),
    );
    if (confirmed == true) await dashboard.resetWidgetPlacements(breakpoint);
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
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.72),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _gridColumnCount(constraints.maxWidth);
        if (columns == 1) {
          final unit = constraints.maxWidth;
          final cards = dashboard.visibleWidgetOrder
              .map((id) => (id: id, child: _buildDashboardWidget(id)))
              .where((entry) => entry.child != null)
              .toList();
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dashboard.isEditMode)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: MaterialBanner(
                      content: Text(
                        'Widget customization is available at 1024 px and wider.',
                      ),
                      actions: [SizedBox.shrink()],
                    ),
                  ),
                Wrap(
                  runSpacing: _gridGap,
                  children: cards.map((entry) {
                    final spec = _structuredSpec(entry.id, columns);
                    return SizedBox(
                      key: ValueKey('dashboard-${entry.id}'),
                      width: unit,
                      height: spec.height,
                      child: entry.child!,
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }

        const rowHeight = 120.0;
        final breakpoint = columns == 12
            ? LayoutBreakpoint.wide
            : LayoutBreakpoint.medium;
        final unit = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - (_gridGap * (columns - 1))) / columns;
        final placements = dashboard
            .placementsFor(breakpoint)
            .where((item) => dashboard.isWidgetEnabled(item.id))
            .toList();
        final gridHeight = placements.isEmpty
            ? constraints.maxHeight
            : placements
                  .map(
                    (item) =>
                        item.y * (rowHeight + _gridGap) +
                        item.height * rowHeight +
                        (item.height - 1) * _gridGap,
                  )
                  .reduce((a, b) => a > b ? a : b)
                  .clamp(constraints.maxHeight, double.infinity);

        return SingleChildScrollView(
          child: SizedBox(
            height: gridHeight,
            child: Stack(
              children: [
                if (dashboard.isEditMode)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _DashboardGridPainter(
                          columns: columns,
                          cellWidth: unit,
                          rowHeight: rowHeight,
                          gap: _gridGap,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ...placements.map((placement) {
                  final child = _buildDashboardWidget(placement.id);
                  if (child == null) return const SizedBox.shrink();
                  final width =
                      placement.width * unit + (placement.width - 1) * _gridGap;
                  final height =
                      placement.height * rowHeight +
                      (placement.height - 1) * _gridGap;
                  return Positioned(
                    key: ValueKey('dashboard-${placement.id}'),
                    left: placement.x * (unit + _gridGap),
                    top: placement.y * (rowHeight + _gridGap),
                    width: width,
                    height: height,
                    child: _EditableGridItem(
                      placement: placement,
                      breakpoint: breakpoint,
                      cellWidth: unit,
                      rowHeight: rowHeight,
                      gap: _gridGap,
                      editMode: dashboard.isEditMode,
                      onCommit: (updated) =>
                          dashboard.updateWidgetPlacement(breakpoint, updated),
                      child: child,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  int _gridColumnCount(double width) {
    // The dashboard itself has 48 px of horizontal shell padding.
    if (width < 960) return 1;
    if (width < 1232) return 6;
    return 12;
  }

  LayoutBreakpoint? _breakpointForWidth(double width) {
    final columns = _gridColumnCount(width);
    return switch (columns) {
      12 => LayoutBreakpoint.wide,
      6 => LayoutBreakpoint.medium,
      _ => null,
    };
  }

  ({int columns, double height}) _structuredSpec(String id, int columns) {
    if (columns == 1) {
      return (
        columns: 1,
        height: switch (id) {
          'weather' => 380,
          'apps' || 'todos' => 340,
          'websites' => 220,
          _ => 280,
        },
      );
    }
    final wide = columns == 12;
    return switch (id) {
      'clock' => (columns: 3, height: 380),
      'weather' => (columns: 3, height: 380),
      'agenda' => (columns: wide ? 6 : 6, height: 380),
      'apps' => (columns: wide ? 8 : 6, height: 340),
      'todos' => (columns: wide ? 4 : 3, height: 340),
      'prayerTimes' => (columns: wide ? 4 : 3, height: 250),
      'system' => (columns: wide ? 4 : 3, height: 250),
      'power' => (columns: wide ? 4 : 3, height: 250),
      'websites' => (columns: columns, height: 220),
      _ => (columns: columns, height: 260),
    };
  }

  Widget? _buildDashboardWidget(String id) {
    switch (id) {
      case 'clock':
        return const ClockWidget();
      case 'weather':
        return const WeatherWidget();
      case 'agenda':
        return const AgendaWidget();
      case 'prayerTimes':
        return const PrayerTimesWidget();
      case 'system':
        return const SystemStatsWidget();
      case 'apps':
        return const AppLauncherWidget();
      case 'websites':
        return const WebsiteWidget();
      case 'todos':
        return const TodoWidget();
      case 'power':
        return const PowerActionsWidget();
      default:
        return null;
    }
  }
}

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

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Window Controls Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _EditableGridItem extends StatefulWidget {
  final DashboardWidgetPlacement placement;
  final LayoutBreakpoint breakpoint;
  final double cellWidth;
  final double rowHeight;
  final double gap;
  final bool editMode;
  final ValueChanged<DashboardWidgetPlacement> onCommit;
  final Widget child;

  const _EditableGridItem({
    required this.placement,
    required this.breakpoint,
    required this.cellWidth,
    required this.rowHeight,
    required this.gap,
    required this.editMode,
    required this.onCommit,
    required this.child,
  });

  @override
  State<_EditableGridItem> createState() => _EditableGridItemState();
}

class _EditableGridItemState extends State<_EditableGridItem> {
  Offset _dragOffset = Offset.zero;
  Offset _resizeOffset = Offset.zero;

  DashboardWidgetPlacement get _preview {
    final horizontalStep = widget.cellWidth + widget.gap;
    final verticalStep = widget.rowHeight + widget.gap;
    return DashboardGridService.clamp(
      widget.placement.copyWith(
        x: widget.placement.x + (_dragOffset.dx / horizontalStep).round(),
        y: widget.placement.y + (_dragOffset.dy / verticalStep).round(),
        width:
            widget.placement.width +
            (_resizeOffset.dx / horizontalStep).round(),
        height:
            widget.placement.height + (_resizeOffset.dy / verticalStep).round(),
      ),
      widget.breakpoint,
    );
  }

  @override
  void didUpdateWidget(_EditableGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.placement != widget.placement || !widget.editMode) {
      _dragOffset = Offset.zero;
      _resizeOffset = Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final width =
        preview.width * widget.cellWidth + (preview.width - 1) * widget.gap;
    final height =
        preview.height * widget.rowHeight + (preview.height - 1) * widget.gap;
    final translation = Offset(
      (preview.x - widget.placement.x) * (widget.cellWidth + widget.gap),
      (preview.y - widget.placement.y) * (widget.rowHeight + widget.gap),
    );

    return Focus(
      onKeyEvent: (_, event) => _handleKeyEvent(event),
      child: Transform.translate(
        offset: translation,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: widget.editMode,
                    child: widget.child,
                  ),
                ),
                if (widget.editMode) ...[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.025),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: _GridHandle(
                      icon: Icons.open_with_rounded,
                      tooltip: 'Move ${widget.placement.id}',
                      cursor: SystemMouseCursors.move,
                      onPanUpdate: (details) =>
                          setState(() => _dragOffset += details.delta),
                      onPanEnd: (_) => _commitPreview(),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _GridHandle(
                      icon: Icons.aspect_ratio_rounded,
                      tooltip: 'Resize ${widget.placement.id}',
                      cursor: SystemMouseCursors.resizeDownRight,
                      onPanUpdate: (details) =>
                          setState(() => _resizeOffset += details.delta),
                      onPanEnd: (_) => _commitPreview(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !widget.editMode) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        (_dragOffset != Offset.zero || _resizeOffset != Offset.zero)) {
      setState(() {
        _dragOffset = Offset.zero;
        _resizeOffset = Offset.zero;
      });
      return KeyEventResult.handled;
    }
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => (-1, 0),
      LogicalKeyboardKey.arrowRight => (1, 0),
      LogicalKeyboardKey.arrowUp => (0, -1),
      LogicalKeyboardKey.arrowDown => (0, 1),
      _ => null,
    };
    if (delta == null) return KeyEventResult.ignored;
    final resize = HardwareKeyboard.instance.isShiftPressed;
    final updated = resize
        ? widget.placement.copyWith(
            width: widget.placement.width + delta.$1,
            height: widget.placement.height + delta.$2,
          )
        : widget.placement.copyWith(
            x: widget.placement.x + delta.$1,
            y: widget.placement.y + delta.$2,
          );
    widget.onCommit(DashboardGridService.clamp(updated, widget.breakpoint));
    return KeyEventResult.handled;
  }

  void _commitPreview() {
    final preview = _preview;
    setState(() {
      _dragOffset = Offset.zero;
      _resizeOffset = Offset.zero;
    });
    if (preview.x == widget.placement.x &&
        preview.y == widget.placement.y &&
        preview.width == widget.placement.width &&
        preview.height == widget.placement.height) {
      return;
    }
    widget.onCommit(preview);
  }
}

class _GridHandle extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final MouseCursor cursor;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const _GridHandle({
    required this.icon,
    required this.tooltip,
    required this.cursor,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  State<_GridHandle> createState() => _GridHandleState();
}

class _GridHandleState extends State<_GridHandle> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      child: Semantics(
        button: true,
        label: widget.tooltip,
        child: Tooltip(
          message: widget.tooltip,
          child: MouseRegion(
            cursor: widget.cursor,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _focusNode.requestFocus,
              onPanStart: (_) => _focusNode.requestFocus(),
              onPanUpdate: widget.onPanUpdate,
              onPanEnd: widget.onPanEnd,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _focused
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: _focused ? 2 : 1,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardGridPainter extends CustomPainter {
  final int columns;
  final double cellWidth;
  final double rowHeight;
  final double gap;
  final Color color;

  const _DashboardGridPainter({
    required this.columns,
    required this.cellWidth,
    required this.rowHeight,
    required this.gap,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rows = (size.height / (rowHeight + gap)).ceil();
    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              column * (cellWidth + gap),
              row * (rowHeight + gap),
              cellWidth,
              rowHeight,
            ),
            const Radius.circular(10),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashboardGridPainter oldDelegate) =>
      oldDelegate.columns != columns ||
      oldDelegate.cellWidth != cellWidth ||
      oldDelegate.rowHeight != rowHeight ||
      oldDelegate.gap != gap ||
      oldDelegate.color != color;
}

class _WindowControls extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    if (dashboard.protectWindowControls && dashboard.takeoverMode) {
      return _TopBarButton(
        icon: Icons.lock_outline,
        label: 'LOCKED',
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
        onTap: () {},
      );
    }

    return Row(
      children: [
        _WinButton(
          tooltip: 'Minimize',
          color: const Color(0xFFFFBD2E),
          icon: Icons.minimize_rounded,
          onTap: () => _minimizeWindow(dashboard),
        ),
        const SizedBox(width: 8),
        _WinButton(
          tooltip: 'Maximize or restore',
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
          tooltip: 'Close',
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
  final String tooltip;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _WinButton({
    required this.tooltip,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: widget.onTap,
      style: IconButton.styleFrom(
        minimumSize: const Size(36, 36),
        backgroundColor: widget.color,
        foregroundColor: Colors.black.withValues(alpha: .7),
      ),
      icon: Icon(widget.icon, size: 14),
    );
  }
}
