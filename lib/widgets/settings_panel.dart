import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/dashboard_provider.dart';
import '../providers/weather_provider.dart';
import '../services/startup_service.dart';

enum _SettingsCategory { appearance, dashboard, data, system }

class SettingsPanel extends StatefulWidget {
  final VoidCallback onClose;
  final StartupService? startupService;
  const SettingsPanel({super.key, required this.onClose, this.startupService});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final StartupService _startupService =
      widget.startupService ?? StartupService();
  late final TextEditingController _nameController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _cityController;
  _SettingsCategory _category = _SettingsCategory.appearance;
  bool _startupEnabled = false;
  bool _startupLoading = true;

  @override
  void initState() {
    super.initState();
    final dashboard = context.read<DashboardProvider>();
    _nameController = TextEditingController(text: dashboard.userName);
    _apiKeyController = TextEditingController(text: dashboard.weatherApiKey);
    _cityController = TextEditingController(text: dashboard.weatherCity);
    _loadStartupSetting();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apiKeyController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final media = MediaQuery.of(context);
    final compact = media.size.width < 900;
    final width = compact
        ? (media.size.width * .92).clamp(260.0, 980.0)
        : (media.size.width * .82).clamp(700.0, 980.0);
    final height = compact
        ? (media.size.height * .92).clamp(220.0, 720.0)
        : (media.size.height * .86).clamp(560.0, 720.0);

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .98),
      elevation: 24,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            _header(context),
            const Divider(height: 1),
            Expanded(
              child: compact
                  ? Column(
                      children: [
                        _compactCategories(),
                        const Divider(height: 1),
                        Expanded(child: _categoryContent(dashboard)),
                      ],
                    )
                  : Row(
                      children: [
                        _categoryRail(),
                        const VerticalDivider(width: 1),
                        Expanded(child: _categoryContent(dashboard)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => SizedBox(
    height: 64,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Icon(
            Icons.tune_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text('Settings', style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          Text('1.2.0 (5)', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Close settings',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    ),
  );

  Widget _categoryRail() => NavigationRail(
    selectedIndex: _category.index,
    onDestinationSelected: (index) =>
        setState(() => _category = _SettingsCategory.values[index]),
    extended: true,
    minExtendedWidth: 210,
    groupAlignment: -1,
    destinations: const [
      NavigationRailDestination(
        icon: Icon(Icons.palette_outlined),
        selectedIcon: Icon(Icons.palette_rounded),
        label: Text('Appearance'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.cloud_outlined),
        selectedIcon: Icon(Icons.cloud_rounded),
        label: Text('Data & Weather'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.computer_outlined),
        selectedIcon: Icon(Icons.computer_rounded),
        label: Text('System'),
      ),
    ],
  );

  Widget _compactCategories() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: SegmentedButton<_SettingsCategory>(
      segments: const [
        ButtonSegment(
          value: _SettingsCategory.appearance,
          label: Text('Appearance'),
        ),
        ButtonSegment(
          value: _SettingsCategory.dashboard,
          label: Text('Dashboard'),
        ),
        ButtonSegment(value: _SettingsCategory.data, label: Text('Data')),
        ButtonSegment(value: _SettingsCategory.system, label: Text('System')),
      ],
      selected: {_category},
      onSelectionChanged: (value) => setState(() => _category = value.first),
    ),
  );

  Widget _categoryContent(DashboardProvider dashboard) => FocusTraversalGroup(
    child: ListView(
      padding: const EdgeInsets.all(28),
      children: switch (_category) {
        _SettingsCategory.appearance => _appearanceSettings(dashboard),
        _SettingsCategory.dashboard => _dashboardSettings(dashboard),
        _SettingsCategory.data => _dataSettings(dashboard),
        _SettingsCategory.system => _systemSettings(dashboard),
      },
    ),
  );

  List<Widget> _appearanceSettings(DashboardProvider dashboard) => [
    const _PageHeading(
      'Appearance',
      'Personalize the dashboard without sacrificing readability.',
    ),
    _DebouncedTextField(
      label: 'Display name',
      controller: _nameController,
      onCommit: dashboard.setUserName,
    ),
    const SizedBox(height: 20),
    _SettingBlock(
      title: 'Theme mode',
      child: SegmentedButton<ThemeModePreference>(
        segments: const [
          ButtonSegment(
            value: ThemeModePreference.system,
            label: Text('System'),
          ),
          ButtonSegment(value: ThemeModePreference.light, label: Text('Light')),
          ButtonSegment(value: ThemeModePreference.dark, label: Text('Dark')),
        ],
        selected: {dashboard.themeModePreference},
        onSelectionChanged: (value) =>
            dashboard.setThemeModePreference(value.first),
      ),
    ),
    const SizedBox(height: 20),
    _SettingBlock(
      title: 'Accent color',
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChoiceChip(
            label: const Text('Windows Accent'),
            selected: dashboard.followSystemAccent,
            onSelected: (val) {
              if (val) dashboard.setFollowSystemAccent(true);
            },
          ),
          ...const ['#2D7FF9', '#00A884', '#7C5CFC', '#D97706'].map(
            (hex) => _AccentChoice(
              hex: hex,
              selected:
                  !dashboard.followSystemAccent && dashboard.accentColor == hex,
              onSelected: () => dashboard.setAccentColor(hex),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    _SettingBlock(
      title: 'Background images',
      subtitle: '${dashboard.backgroundImagePaths.length} selected',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickBackgroundImages(dashboard),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add images'),
              ),
              OutlinedButton.icon(
                onPressed: dashboard.backgroundImagePaths.length > 1
                    ? dashboard.advanceBackgroundImage
                    : null,
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Shuffle next'),
              ),
              if (dashboard.backgroundImagePaths.isNotEmpty)
                TextButton.icon(
                  onPressed: dashboard.clearBackgroundImages,
                  icon: const Icon(Icons.clear_rounded),
                  label: const Text('Clear all'),
                ),
              DropdownButton<int>(
                value: dashboard.backgroundRotationMinutes,
                items: DashboardProvider.backgroundRotationMinuteOptions
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('Rotate every $value min'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    dashboard.setBackgroundRotationMinutes(value);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dashboard.backgroundImagePaths.isEmpty)
            Text(
              'Choose two or more pictures to rotate them in shuffled order.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            _BackgroundGallery(
              paths: dashboard.backgroundImagePaths,
              currentPath: dashboard.currentBackgroundImagePath,
              onRemove: dashboard.removeBackgroundImage,
            ),
        ],
      ),
    ),
    const SizedBox(height: 18),
    _CommitSlider(
      label: 'Window opacity',
      value: dashboard.windowOpacity,
      min: .25,
      max: 1,
      divisions: 15,
      onCommit: dashboard.setWindowOpacity,
    ),
    _CommitSlider(
      label: 'Background dim',
      value: dashboard.backgroundDim,
      min: 0,
      max: .95,
      divisions: 19,
      onCommit: dashboard.setBackgroundDim,
    ),
    _CommitSlider(
      label: 'Blur strength',
      value: dashboard.blurStrength,
      min: 0,
      max: 30,
      divisions: 30,
      onCommit: dashboard.setBlurStrength,
    ),
    _CommitSlider(
      label: 'Surface intensity',
      value: dashboard.glassIntensity,
      min: .2,
      max: 1.4,
      divisions: 12,
      onCommit: dashboard.setGlassIntensity,
    ),
    const SizedBox(height: 20),
    _SettingBlock(
      title: 'Backdrop Material',
      subtitle: 'Native Windows blur styling',
      child: Wrap(
        spacing: 8,
        children: ['mica', 'acrylic', 'solid'].map((mode) {
          final isSelected = dashboard.backdropEffect == mode;
          final label = switch (mode) {
            'mica' => 'Mica (Windows 11)',
            'acrylic' => 'Acrylic Blur',
            _ => 'Solid Canvas',
          };
          return ChoiceChip(
            label: Text(label),
            selected: isSelected,
            onSelected: (_) => dashboard.setBackdropEffect(mode),
          );
        }).toList(),
      ),
    ),
  ];

  List<Widget> _dashboardSettings(DashboardProvider dashboard) => [
    const _PageHeading(
      'Dashboard',
      'Choose which cards appear and set their reading order.',
    ),
    _SwitchSetting(
      title: '24-hour clock',
      value: dashboard.use24Hour,
      onChanged: dashboard.setUse24Hour,
    ),
    _SwitchSetting(
      title: 'Show seconds',
      value: dashboard.showSeconds,
      onChanged: dashboard.setShowSeconds,
    ),
    const SizedBox(height: 18),
    Text('WIDGETS', style: Theme.of(context).textTheme.labelSmall),
    const SizedBox(height: 8),
    ...dashboard.widgetOrder.asMap().entries.map((entry) {
      final index = entry.key;
      final id = entry.value;
      return _WidgetOrderTile(
        label: _widgetLabel(id),
        enabled: dashboard.isWidgetEnabled(id),
        canMoveUp: index > 0,
        canMoveDown: index < dashboard.widgetOrder.length - 1,
        onToggle: (value) => dashboard.setWidgetEnabled(id, value),
        onMoveUp: () => dashboard.reorderDashboardWidget(index, index - 1),
        onMoveDown: () => dashboard.reorderDashboardWidget(index, index + 2),
      );
    }),
    const SizedBox(height: 24),
    const Divider(),
    const SizedBox(height: 18),
    Text('DESKTOP WIDGET MODE', style: Theme.of(context).textTheme.labelSmall),
    const SizedBox(height: 8),
    _SwitchSetting(
      title: 'Desktop widget mode',
      value: dashboard.desktopWidgetMode,
      onChanged: dashboard.setDesktopWidgetMode,
    ),
    _SwitchSetting(
      title: 'Pin desktop widget (Always on top)',
      value: dashboard.desktopWidgetAlwaysOnTop,
      onChanged: dashboard.setDesktopWidgetAlwaysOnTop,
    ),
    _SwitchSetting(
      title: 'Hide desktop widget from taskbar',
      value: dashboard.desktopWidgetHideFromTaskbar,
      onChanged: dashboard.setDesktopWidgetHideFromTaskbar,
    ),
    _SwitchSetting(
      title: 'Lock desktop widget position & size',
      value: dashboard.desktopWidgetLockPosition,
      onChanged: dashboard.setDesktopWidgetLockPosition,
    ),
    const SizedBox(height: 8),
    _CommitSlider(
      label: 'Desktop widget opacity',
      value: dashboard.desktopWidgetOpacity,
      min: .25,
      max: 1,
      divisions: 15,
      onCommit: dashboard.setDesktopWidgetOpacity,
    ),
    const SizedBox(height: 16),
    Text(
      'DESKTOP WIDGET CARDS',
      style: Theme.of(context).textTheme.labelSmall,
    ),
    const SizedBox(height: 8),
    ...dashboard.desktopWidgetOrder.asMap().entries.map((entry) {
      final index = entry.key;
      final id = entry.value;
      return _WidgetOrderTile(
        label: _widgetLabel(id),
        enabled: dashboard.isDesktopWidgetEnabled(id),
        canMoveUp: index > 0,
        canMoveDown: index < dashboard.desktopWidgetOrder.length - 1,
        onToggle: (value) => dashboard.setDesktopWidgetEnabled(id, value),
        onMoveUp: () => dashboard.reorderDesktopWidget(index, index - 1),
        onMoveDown: () => dashboard.reorderDesktopWidget(index, index + 2),
      );
    }),
  ];

  List<Widget> _dataSettings(DashboardProvider dashboard) => [
    const _PageHeading(
      'Data & Weather',
      'Weather uses Open-Meteo unless an OpenWeather key is supplied.',
    ),
    _DebouncedTextField(
      label: 'City name (weather and prayer times)',
      controller: _cityController,
      onCommit: dashboard.setWeatherCity,
    ),
    const SizedBox(height: 16),
    _DebouncedTextField(
      label: 'OpenWeather API key (optional)',
      controller: _apiKeyController,
      obscureText: true,
      onCommit: dashboard.setWeatherApiKey,
    ),
    const SizedBox(height: 12),
    _SwitchSetting(
      title: 'Metric units',
      value: dashboard.weatherMetricUnits,
      onChanged: dashboard.setWeatherMetricUnits,
    ),
    _CommitSlider(
      label: 'Weather refresh minutes',
      value: dashboard.weatherRefreshMinutes.toDouble(),
      min: 1,
      max: 120,
      divisions: 119,
      display: (value) => '${value.round()} min',
      onCommit: (value) => dashboard.setWeatherRefreshMinutes(value.round()),
    ),
    const SizedBox(height: 12),
    Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        onPressed: () {
          context.read<WeatherProvider>().fetchWeather(
            apiKey: _apiKeyController.text.trim(),
            city: _cityController.text.trim().isEmpty
                ? null
                : _cityController.text.trim(),
            useMetricUnits: dashboard.weatherMetricUnits,
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Refreshing weather…')));
        },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Refresh weather'),
      ),
    ),
  ];

  List<Widget> _systemSettings(DashboardProvider dashboard) => [
    const _PageHeading(
      'System',
      'Control startup, focus behavior, and Windows takeover mode.',
    ),
    _SwitchSetting(
      title: _startupLoading ? 'Checking startup setting…' : 'Start on login',
      value: _startupEnabled,
      onChanged: _startupLoading ? null : _setStartupEnabled,
    ),
    _SwitchSetting(
      title: 'Takeover mode',
      value: dashboard.takeoverMode,
      onChanged: dashboard.setTakeoverMode,
    ),
    _SwitchSetting(
      title: 'Fullscreen',
      value: dashboard.fullscreenEnabled,
      onChanged: dashboard.setFullscreenEnabled,
    ),
    _SwitchSetting(
      title: 'Borderless window',
      value: dashboard.borderlessEnabled,
      onChanged: dashboard.setBorderlessEnabled,
    ),
    _SwitchSetting(
      title: 'Always on top',
      value: dashboard.alwaysOnTop,
      onChanged: dashboard.setAlwaysOnTop,
    ),
    _SwitchSetting(
      title: 'Hide from taskbar',
      value: dashboard.hideFromTaskbar,
      onChanged: dashboard.setHideFromTaskbar,
    ),
    _SwitchSetting(
      title: 'Protect window controls',
      value: dashboard.protectWindowControls,
      onChanged: dashboard.setProtectWindowControls,
    ),
    _SwitchSetting(
      title: 'Wake focus fallback',
      value: dashboard.wakeFocusFallback,
      onChanged: dashboard.setWakeFocusFallback,
    ),
    _SwitchSetting(
      title: 'Low-resource mode',
      value: dashboard.lowResourceMode,
      onChanged: dashboard.setLowResourceMode,
    ),
    _CommitSlider(
      label: 'Startup focus delay',
      value: dashboard.startupDelaySeconds.toDouble(),
      min: 0,
      max: 30,
      divisions: 30,
      display: (value) => '${value.round()} sec',
      onCommit: (value) => dashboard.setStartupDelaySeconds(value.round()),
    ),
  ];

  String _widgetLabel(String id) => switch (id) {
    'clock' => 'Clock',
    'weather' => 'Weather',
    'agenda' => 'Agenda',
    'apps' => 'App launcher',
    'todos' => 'To-do',
    'prayerTimes' => 'Prayer times',
    'system' => 'System stats',
    'power' => 'Power actions',
    'websites' => 'Websites',
    _ => id,
  };

  Future<void> _pickBackgroundImages(DashboardProvider dashboard) async {
    final wasAlwaysOnTop = await windowManager.isAlwaysOnTop();
    final wasFullScreen = await windowManager.isFullScreen();
    try {
      if (wasAlwaysOnTop) await windowManager.setAlwaysOnTop(false);
      if (wasFullScreen) await windowManager.setFullScreen(false);
      await windowManager.blur();
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      final paths =
          result?.files.map((file) => file.path).whereType<String>().toList() ??
          const [];
      if (paths.isNotEmpty) await dashboard.addBackgroundImages(paths);
    } finally {
      if (wasFullScreen) await windowManager.setFullScreen(true);
      if (wasAlwaysOnTop) await windowManager.setAlwaysOnTop(true);
      await windowManager.focus();
    }
  }

  Future<void> _loadStartupSetting() async {
    final enabled = await _startupService.isEnabled();
    if (!mounted) return;
    setState(() {
      _startupEnabled = enabled;
      _startupLoading = false;
    });
  }

  Future<void> _setStartupEnabled(bool value) async {
    setState(() => _startupLoading = true);
    try {
      await _startupService.setEnabled(value);
      if (!mounted) return;
      setState(() {
        _startupEnabled = value;
        _startupLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _startupLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update startup setting: $error')),
      );
    }
  }
}

class _BackgroundGallery extends StatelessWidget {
  final List<String> paths;
  final String currentPath;
  final ValueChanged<String> onRemove;

  const _BackgroundGallery({
    required this.paths,
    required this.currentPath,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 520 ? 140.0 : 180.0;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: paths
              .map(
                (path) => _BackgroundThumbnail(
                  key: ValueKey('background-thumbnail-$path'),
                  path: path,
                  width: width,
                  selected: path == currentPath,
                  onRemove: () => onRemove(path),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _BackgroundThumbnail extends StatelessWidget {
  final String path;
  final double width;
  final bool selected;
  final VoidCallback onRemove;

  const _BackgroundThumbnail({
    super.key,
    required this.path,
    required this.width,
    required this.selected,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: selected ? 'Current background' : 'Background image',
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: 360,
                    cacheHeight: 204,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Text(
                        'CURRENT',
                        style: TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 4,
                top: 4,
                child: IconButton.filled(
                  onPressed: onRemove,
                  tooltip: 'Remove background',
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  const _PageHeading(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _SettingBlock extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _SettingBlock({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      if (subtitle != null)
        Text(
          subtitle!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      const SizedBox(height: 10),
      child,
    ],
  );
}

class _DebouncedTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final Future<void> Function(String) onCommit;
  const _DebouncedTextField({
    required this.label,
    required this.controller,
    required this.onCommit,
    this.obscureText = false,
  });

  @override
  State<_DebouncedTextField> createState() => _DebouncedTextFieldState();
}

class _DebouncedTextFieldState extends State<_DebouncedTextField> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule(String value) {
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 500),
      () => widget.onCommit(value.trim()),
    );
  }

  void _commit(String value) {
    _timer?.cancel();
    widget.onCommit(value.trim());
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    obscureText: widget.obscureText,
    onChanged: _schedule,
    onSubmitted: _commit,
    onTapOutside: (_) {
      _commit(widget.controller.text);
      FocusManager.instance.primaryFocus?.unfocus();
    },
    decoration: InputDecoration(labelText: widget.label),
  );
}

class _SwitchSetting extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _SwitchSetting({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    value: value,
    onChanged: onChanged,
  );
}

class _CommitSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double)? display;
  final ValueChanged<double> onCommit;
  const _CommitSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.display,
    required this.onCommit,
  });

  @override
  State<_CommitSlider> createState() => _CommitSliderState();
}

class _CommitSliderState extends State<_CommitSlider> {
  late double _value = widget.value;
  bool _dragging = false;

  @override
  void didUpdateWidget(_CommitSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging && oldWidget.value != widget.value) _value = widget.value;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(widget.label)),
          Text(
            widget.display?.call(_value) ?? '${(_value * 100).round()}%',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
      Slider(
        value: _value.clamp(widget.min, widget.max),
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        onChangeStart: (_) => _dragging = true,
        onChanged: (value) => setState(() => _value = value),
        onChangeEnd: (value) {
          _dragging = false;
          widget.onCommit(value);
        },
      ),
    ],
  );
}

class _WidgetOrderTile extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onToggle;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  const _WidgetOrderTile({
    required this.label,
    required this.enabled,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggle,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Switch(value: enabled, onChanged: onToggle),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Move $label up',
            onPressed: canMoveUp ? onMoveUp : null,
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
          IconButton(
            tooltip: 'Move $label down',
            onPressed: canMoveDown ? onMoveDown : null,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
        ],
      ),
    ),
  );
}

class _AccentChoice extends StatelessWidget {
  final String hex;
  final bool selected;
  final VoidCallback onSelected;
  const _AccentChoice({
    required this.hex,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
    return Semantics(
      label: 'Accent color $hex',
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onSelected,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 3,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
