import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../models/models.dart';
import '../providers/dashboard_provider.dart';
import '../services/dashboard_grid_service.dart';
import '../services/power_service.dart';
import '../services/tray_service.dart';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin, WindowListener {
  static const double _gridGap = 16;
  static const double _gridCellHeight = 112;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final FocusNode _focusNode = FocusNode();
  Timer? _startupFocusTimer;
  Timer? _backgroundRotationTimer;
  DashboardProvider? _dashboardProvider;
  String _lastWindowSignature = '';
  String _lastBackgroundRotationSignature = '';
  String _lastDashboardSettingsSignature = '';
  bool _pendingWindowUpdate = false;
  bool _settingsOpen = false;
  bool _fullscreenTopBarVisible = false;
  bool _visualEffectsActive = true;

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
    _dashboardProvider?.removeListener(_handleDashboardProviderChange);
    _fadeController.dispose();
    _startupFocusTimer?.cancel();
    _backgroundRotationTimer?.cancel();
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
            if (shouldRenderParticles(
              lowResourceMode: dashboard.lowResourceMode,
            ))
              ParticleBackground(active: _visualEffectsActive),

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
    final signature = [
      dashboard.backgroundRotationMinutes,
      ...validPaths,
    ].join('|');
    if (_lastBackgroundRotationSignature == signature) return;
    _lastBackgroundRotationSignature = signature;
    _backgroundRotationTimer?.cancel();
    _backgroundRotationTimer = null;
    if (validPaths.length < 2) return;

    _backgroundRotationTimer = Timer.periodic(
      Duration(minutes: dashboard.backgroundRotationMinutes),
      (_) {
        if (!mounted) return;
        context.read<DashboardProvider>().advanceBackgroundImage();
      },
    );
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
    if (mounted) {
      setState(() => _visualEffectsActive = false);
    }
    await TrayService.instance.hideWindow();
  }

  @override
  void onWindowMinimize() async {
    if (mounted) {
      setState(() => _visualEffectsActive = false);
    }
    final dashboard = context.read<DashboardProvider>();
    if (dashboard.takeoverMode && dashboard.protectWindowControls) {
      await windowManager.restore();
      await _bringToFront();
    }
  }

  @override
  void onWindowRestore() async {
    if (mounted) {
      setState(() => _visualEffectsActive = true);
    }
    _lastWindowSignature = '';
    await _applyWindowSettings(context.read<DashboardProvider>());
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
    return Stack(
      key: ValueKey('background-image-$path'),
      fit: StackFit.expand,
      children: [
        Image.file(File(path), fit: BoxFit.cover),
        Container(color: AppTheme.darkBase.withValues(alpha: backgroundDim)),
      ],
    );
  }

  Widget _buildDefaultBackground() {
    // Default gradient background
    return DecoratedBox(
      key: const ValueKey('default-background'),
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: Stack(
        children: [
          // Subtle radial glows
          Positioned(
            top: -200,
            left: -100,
            child: RepaintBoundary(
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
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: RepaintBoundary(
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
          ),
        ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _gridColumnCount(constraints.maxWidth);
        final cellWidth =
            (constraints.maxWidth - (_gridGap * (columns - 1))) / columns;
        final widgets = dashboard.visibleWidgetOrder
            .map(
              (id) => (
                id: id,
                layout: _layoutForGrid(dashboard.widgetLayout(id), columns),
                child: _buildDashboardWidget(id),
              ),
            )
            .where((entry) => entry.child != null)
            .toList();
        final gridHeight = widgets.fold<double>(constraints.maxHeight, (
          height,
          entry,
        ) {
          final bottom =
              entry.layout.y * (_gridCellHeight + _gridGap) +
              entry.layout.height * _gridCellHeight +
              (entry.layout.height - 1) * _gridGap;
          return bottom > height ? bottom : height;
        });

        return SingleChildScrollView(
          child: SizedBox(
            height: gridHeight,
            child: Stack(
              children: widgets.map((entry) {
                final layout = entry.layout;
                final left = layout.x * (cellWidth + _gridGap);
                final top = layout.y * (_gridCellHeight + _gridGap);
                final width =
                    layout.width * cellWidth + (layout.width - 1) * _gridGap;
                final height =
                    layout.height * _gridCellHeight +
                    (layout.height - 1) * _gridGap;

                return Positioned(
                  left: left,
                  top: top,
                  width: width,
                  height: height,
                  child: _EditableDashboardWidget(
                    id: entry.id,
                    layout: layout,
                    columns: columns,
                    cellWidth: cellWidth,
                    cellHeight: _gridCellHeight,
                    gap: _gridGap,
                    editMode: dashboard.isEditMode,
                    onLayoutChanged: (updated) =>
                        dashboard.setWidgetLayout(entry.id, updated),
                    child: entry.child!,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  int _gridColumnCount(double width) {
    if (width < 520) return 2;
    if (width < 860) return 4;
    if (width < 1180) return 6;
    return 12;
  }

  DashboardWidgetLayout _layoutForGrid(
    DashboardWidgetLayout layout,
    int columns,
  ) {
    final width = layout.width.clamp(1, columns);
    return layout.copyWith(
      x: layout.x.clamp(0, columns - width),
      width: width,
      y: layout.y.clamp(0, 60),
      height: layout.height.clamp(1, 12),
    );
  }

  Widget? _buildDashboardWidget(String id) {
    switch (id) {
      case 'clock':
        return const ClockWidget();
      case 'weather':
        return const WeatherWidget();
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
      case 'shutdown':
        return const PowerActionWidget(action: PowerAction.shutdown);
      case 'restart':
        return const PowerActionWidget(action: PowerAction.restart);
      case 'sleep':
        return const PowerActionWidget(action: PowerAction.sleep);
      default:
        return null;
    }
  }
}

class _EditableDashboardWidget extends StatefulWidget {
  final String id;
  final DashboardWidgetLayout layout;
  final int columns;
  final double cellWidth;
  final double cellHeight;
  final double gap;
  final bool editMode;
  final ValueChanged<DashboardWidgetLayout> onLayoutChanged;
  final Widget child;

  const _EditableDashboardWidget({
    required this.id,
    required this.layout,
    required this.columns,
    required this.cellWidth,
    required this.cellHeight,
    required this.gap,
    required this.editMode,
    required this.onLayoutChanged,
    required this.child,
  });

  @override
  State<_EditableDashboardWidget> createState() =>
      _EditableDashboardWidgetState();
}

class _EditableDashboardWidgetState extends State<_EditableDashboardWidget> {
  Offset _dragOffset = Offset.zero;
  Offset _resizeOffset = Offset.zero;

  @override
  void didUpdateWidget(_EditableDashboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layout != widget.layout) {
      _dragOffset = Offset.zero;
      _resizeOffset = Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _dragOffset,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final previewWidth = clampPreviewDelta(
            constraints.maxWidth + _resizeOffset.dx,
            widget.cellWidth,
            constraints.maxWidth +
                (widget.columns * (widget.cellWidth + widget.gap)),
          );
          final previewHeight = clampPreviewDelta(
            constraints.maxHeight + _resizeOffset.dy,
            widget.cellHeight,
            constraints.maxHeight + (12 * (widget.cellHeight + widget.gap)),
          );

          return OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: 0,
            minHeight: 0,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: SizedBox(
              width: previewWidth,
              height: previewHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: widget.child),
                  if (widget.editMode) ...[
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.neonBlue.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _EditHandle(
                        icon: Icons.open_with_rounded,
                        tooltip: 'Move',
                        cursor: SystemMouseCursors.move,
                        onPanUpdate: (details) =>
                            setState(() => _dragOffset += details.delta),
                        onPanEnd: (_) => _commitDrag(),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _EditHandle(
                        icon: Icons.aspect_ratio_rounded,
                        tooltip: 'Resize',
                        cursor: SystemMouseCursors.resizeDownRight,
                        onPanUpdate: (details) =>
                            setState(() => _resizeOffset += details.delta),
                        onPanEnd: (_) => _commitResize(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _commitDrag() {
    final deltaX = snapDragDeltaToGrid(
      _dragOffset.dx,
      widget.cellWidth + widget.gap,
    );
    final deltaY = snapDragDeltaToGrid(
      _dragOffset.dy,
      widget.cellHeight + widget.gap,
    );
    setState(() => _dragOffset = Offset.zero);
    if (deltaX == 0 && deltaY == 0) return;
    widget.onLayoutChanged(
      _clampLayout(
        widget.layout.copyWith(
          x: widget.layout.x + deltaX,
          y: widget.layout.y + deltaY,
        ),
      ),
    );
  }

  void _commitResize() {
    final deltaWidth = snapDragDeltaToGrid(
      _resizeOffset.dx,
      widget.cellWidth + widget.gap,
    );
    final deltaHeight = snapDragDeltaToGrid(
      _resizeOffset.dy,
      widget.cellHeight + widget.gap,
    );
    setState(() => _resizeOffset = Offset.zero);
    if (deltaWidth == 0 && deltaHeight == 0) return;
    widget.onLayoutChanged(
      _clampLayout(
        widget.layout.copyWith(
          width: widget.layout.width + deltaWidth,
          height: widget.layout.height + deltaHeight,
        ),
      ),
    );
  }

  DashboardWidgetLayout _clampLayout(DashboardWidgetLayout layout) {
    final isPowerAction =
        widget.id == 'shutdown' ||
        widget.id == 'restart' ||
        widget.id == 'sleep';
    final minHeight = isPowerAction ? 1 : 2;
    final minWidth = isPowerAction ? 1 : 2;
    final width = layout.width.clamp(minWidth, widget.columns);
    return layout.copyWith(
      x: layout.x.clamp(0, widget.columns - width),
      y: layout.y.clamp(0, 60),
      width: width,
      height: layout.height.clamp(minHeight, 12),
    );
  }
}

class _EditHandle extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final MouseCursor cursor;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const _EditHandle({
    required this.icon,
    required this.tooltip,
    required this.cursor,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: MouseRegion(
        cursor: cursor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
          child: Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.darkCard.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Icon(icon, color: AppTheme.neonBlue, size: 18),
          ),
        ),
      ),
    );
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
