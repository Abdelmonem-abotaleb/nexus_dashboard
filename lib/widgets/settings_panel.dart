import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/dashboard_provider.dart';
import '../providers/weather_provider.dart';
import '../services/startup_service.dart';
import '../theme/app_theme.dart';

class SettingsPanel extends StatefulWidget {
  final VoidCallback onClose;

  const SettingsPanel({super.key, required this.onClose});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  late TextEditingController _nameController;
  late TextEditingController _apiKeyController;
  late TextEditingController _cityController;
  final StartupService _startupService = StartupService();
  bool _startupEnabled = false;
  bool _startupLoading = true;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _slideController.forward();

    final dashboard = context.read<DashboardProvider>();
    _nameController = TextEditingController(text: dashboard.userName);
    _apiKeyController = TextEditingController(text: dashboard.weatherApiKey);
    _cityController = TextEditingController(text: dashboard.weatherCity);
    _loadStartupSetting();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _nameController.dispose();
    _apiKeyController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        width: 360,
        height: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.darkCard.withValues(alpha: 0.95),
          border: Border(
            left: BorderSide(color: AppTheme.glassBorder, width: 1),
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppTheme.glassBorder),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'SETTINGS',
                      style: TextStyle(
                        color: AppTheme.neonBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // ── Profile ──────────────────────────────────────────
                    _SectionHeader(title: 'PROFILE'),
                    const SizedBox(height: 12),
                    _SettingsTextField(
                      label: 'Display Name',
                      controller: _nameController,
                      onChanged: (v) => dashboard.setUserName(v),
                    ),

                    const SizedBox(height: 24),

                    // ── Appearance ───────────────────────────────────────
                    _SectionHeader(title: 'APPEARANCE'),
                    const SizedBox(height: 12),

                    // Background image picker
                    _SettingsRow(
                      label: 'Background Images',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _SettingsActionButton(
                                icon: Icons.add_photo_alternate_outlined,
                                label: 'Add Images',
                                onTap: () => _pickBackgroundImages(dashboard),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${dashboard.backgroundImagePaths.length} selected',
                                style: TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (dashboard.backgroundImagePaths.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: dashboard.clearBackgroundImages,
                              child: Text(
                                'Clear background images',
                                style: TextStyle(
                                  color: AppTheme.neonPink.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 11,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppTheme.neonPink.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    _SettingsRow(
                      label: 'Background Rotation',
                      child: _RotationIntervalPicker(
                        value: dashboard.backgroundRotationMinutes,
                        onChanged: dashboard.setBackgroundRotationMinutes,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Accent color presets
                    _SettingsRow(
                      label: 'Accent Color',
                      child: Wrap(
                        spacing: 8,
                        children:
                            [
                              '#00D4FF',
                              '#7B2FFF',
                              '#00FF94',
                              '#FF006E',
                              '#FF9F0A',
                              '#FFFFFF',
                            ].map((hex) {
                              final selected = dashboard.accentColor == hex;
                              final color = Color(
                                int.parse(hex.replaceFirst('#', '0xFF')),
                              );
                              return GestureDetector(
                                onTap: () => dashboard.setAccentColor(hex),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: color,
                                    border: selected
                                        ? Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          )
                                        : null,
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: color.withValues(
                                                alpha: 0.6,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    _SettingsRow(
                      label: 'Theme Mode',
                      child: _ThemeModePicker(
                        value: dashboard.themeModePreference,
                        onChanged: dashboard.setThemeModePreference,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _SettingsSlider(
                      label: 'Window Opacity',
                      value: dashboard.windowOpacity,
                      min: 0.25,
                      max: 1,
                      displayValue:
                          '${(dashboard.windowOpacity * 100).round()}%',
                      onChanged: (v) => dashboard.setWindowOpacity(v),
                    ),
                    _SettingsSlider(
                      label: 'Background Dim',
                      value: dashboard.backgroundDim,
                      min: 0,
                      max: 0.95,
                      displayValue:
                          '${(dashboard.backgroundDim * 100).round()}%',
                      onChanged: (v) => dashboard.setBackgroundDim(v),
                    ),
                    _SettingsSlider(
                      label: 'Blur Strength',
                      value: dashboard.blurStrength,
                      min: 0,
                      max: 30,
                      displayValue: dashboard.blurStrength.toStringAsFixed(0),
                      onChanged: (v) => dashboard.setBlurStrength(v),
                    ),
                    _SettingsSlider(
                      label: 'Glass Intensity',
                      value: dashboard.glassIntensity,
                      min: 0.2,
                      max: 1.4,
                      displayValue: dashboard.glassIntensity.toStringAsFixed(1),
                      onChanged: (v) => dashboard.setGlassIntensity(v),
                    ),

                    const SizedBox(height: 24),

                    // ── Clock ────────────────────────────────────────────
                    _SectionHeader(title: 'CLOCK'),
                    const SizedBox(height: 12),

                    _SettingsToggle(
                      label: '24-Hour Format',
                      value: dashboard.use24Hour,
                      onChanged: (v) => dashboard.setUse24Hour(v),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggle(
                      label: 'Show Seconds',
                      value: dashboard.showSeconds,
                      onChanged: (v) => dashboard.setShowSeconds(v),
                    ),

                    const SizedBox(height: 24),

                    // ── System ───────────────────────────────────────────
                    _SectionHeader(title: 'SYSTEM'),
                    const SizedBox(height: 12),

                    _SettingsToggle(
                      label: _startupLoading
                          ? 'Checking Startup...'
                          : 'Start on Login',
                      value: _startupEnabled,
                      onChanged: _startupLoading || !_startupService.isSupported
                          ? null
                          : (v) => _setStartupEnabled(v),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggle(
                      label: 'Takeover Mode',
                      value: dashboard.takeoverMode,
                      onChanged: (v) => dashboard.setTakeoverMode(v),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggle(
                      label: 'Fullscreen',
                      value: dashboard.fullscreenEnabled,
                      onChanged: (v) => dashboard.setFullscreenEnabled(v),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggle(
                      label: 'Borderless Window',
                      value: dashboard.borderlessEnabled,
                      onChanged: (v) => dashboard.setBorderlessEnabled(v),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggle(
                      label: 'Always On Top',
                      value: dashboard.alwaysOnTop,
                      onChanged: (v) => dashboard.setAlwaysOnTop(v),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggle(
                      label: 'Hide From Taskbar',
                      value: dashboard.hideFromTaskbar,
                      onChanged: (v) => dashboard.setHideFromTaskbar(v),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggle(
                      label: 'Protect Window Controls',
                      value: dashboard.protectWindowControls,
                      onChanged: (v) => dashboard.setProtectWindowControls(v),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggle(
                      label: 'Wake Focus Fallback',
                      value: dashboard.wakeFocusFallback,
                      onChanged: (v) => dashboard.setWakeFocusFallback(v),
                    ),
                    const SizedBox(height: 8),
                    _SettingsToggle(
                      label: 'Low Resource Mode',
                      value: dashboard.lowResourceMode,
                      onChanged: (v) => dashboard.setLowResourceMode(v),
                    ),
                    _SettingsSlider(
                      label: 'Startup Focus Delay',
                      value: dashboard.startupDelaySeconds.toDouble(),
                      min: 0,
                      max: 30,
                      divisions: 30,
                      displayValue: '${dashboard.startupDelaySeconds}s',
                      onChanged: (v) =>
                          dashboard.setStartupDelaySeconds(v.round()),
                    ),

                    const SizedBox(height: 24),

                    // ── Widgets ──────────────────────────────────────────
                    _SectionHeader(title: 'WIDGETS'),
                    const SizedBox(height: 12),
                    ...dashboard.widgetOrder.map(
                      (id) => _WidgetControlRow(
                        label: _widgetLabel(id),
                        enabled: dashboard.isWidgetEnabled(id),
                        canMoveUp: dashboard.widgetOrder.indexOf(id) > 0,
                        canMoveDown:
                            dashboard.widgetOrder.indexOf(id) <
                            dashboard.widgetOrder.length - 1,
                        onToggle: (v) => dashboard.setWidgetEnabled(id, v),
                        onMoveUp: () {
                          final index = dashboard.widgetOrder.indexOf(id);
                          dashboard.reorderDashboardWidget(index, index - 1);
                        },
                        onMoveDown: () {
                          final index = dashboard.widgetOrder.indexOf(id);
                          dashboard.reorderDashboardWidget(index, index + 2);
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Weather ──────────────────────────────────────────
                    _SectionHeader(title: 'WEATHER'),
                    const SizedBox(height: 8),
                    Text(
                      'Leave API key empty to use free Open-Meteo weather.',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 12),

                    _SettingsTextField(
                      label: 'OpenWeather API Key',
                      controller: _apiKeyController,
                      obscureText: true,
                      onChanged: (v) => dashboard.setWeatherApiKey(v),
                    ),

                    const SizedBox(height: 12),

                    _SettingsTextField(
                      label: 'City Name (e.g. Cairo)',
                      controller: _cityController,
                      onChanged: (v) => dashboard.setWeatherCity(v),
                    ),

                    const SizedBox(height: 12),

                    _SettingsToggle(
                      label: 'Metric Units',
                      value: dashboard.weatherMetricUnits,
                      onChanged: (v) => dashboard.setWeatherMetricUnits(v),
                    ),
                    _SettingsSlider(
                      label: 'Refresh Interval',
                      value: dashboard.weatherRefreshMinutes.toDouble(),
                      min: 1,
                      max: 120,
                      divisions: 119,
                      displayValue: '${dashboard.weatherRefreshMinutes}m',
                      onChanged: (v) =>
                          dashboard.setWeatherRefreshMinutes(v.round()),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          context.read<WeatherProvider>().fetchWeather(
                            apiKey: _apiKeyController.text,
                            city: _cityController.text.isNotEmpty
                                ? _cityController.text
                                : null,
                            useMetricUnits: dashboard.weatherMetricUnits,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Refreshing weather...'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.neonPurple.withValues(
                            alpha: 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: AppTheme.neonPurple.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: Text(
                          'REFRESH WEATHER',
                          style: TextStyle(
                            color: AppTheme.neonPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Version
                    Center(
                      child: Text(
                        'NEXUS DASHBOARD  v1.0.0',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _widgetLabel(String id) {
    switch (id) {
      case 'clock':
        return 'Clock';
      case 'weather':
        return 'Weather';
      case 'system':
        return 'System Stats';
      case 'apps':
        return 'App Launcher';
      case 'websites':
        return 'Websites';
      case 'todos':
        return 'To-Do';
      case 'shutdown':
        return 'Shut Down';
      case 'restart':
        return 'Restart';
      case 'sleep':
        return 'Sleep';
      default:
        return id;
    }
  }

  Future<void> _pickBackgroundImages(DashboardProvider dashboard) async {
    final wasAlwaysOnTop = await windowManager.isAlwaysOnTop();
    final wasFullScreen = await windowManager.isFullScreen();

    try {
      if (wasAlwaysOnTop) {
        await windowManager.setAlwaysOnTop(false);
      }
      if (wasFullScreen) {
        await windowManager.setFullScreen(false);
      }
      await windowManager.blur();

      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null) return;
      final paths = result.files
          .map((file) => file.path)
          .whereType<String>()
          .toList();
      if (paths.isEmpty) return;
      await dashboard.addBackgroundImages(paths);
    } finally {
      if (wasFullScreen) {
        await windowManager.setFullScreen(true);
      }
      if (wasAlwaysOnTop) {
        await windowManager.setAlwaysOnTop(true);
      }
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

  Future<void> _setStartupEnabled(bool enabled) async {
    setState(() => _startupLoading = true);

    try {
      await _startupService.setEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _startupEnabled = enabled;
        _startupLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Nexus will start when you sign in.'
                : 'Nexus startup on login disabled.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _startupLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update startup setting: $e'),
          backgroundColor: AppTheme.neonPink,
        ),
      );
    }
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: AppTheme.textMuted,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 3,
      ),
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  const _SettingsTextField({
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: AppTheme.neonBlue.withValues(alpha: 0.5),
              ),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingsToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.neonBlue,
          activeTrackColor: AppTheme.neonBlue.withValues(alpha: 0.3),
          inactiveThumbColor: AppTheme.textMuted,
          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
        ),
      ],
    );
  }
}

class _ThemeModePicker extends StatelessWidget {
  final ThemeModePreference value;
  final ValueChanged<ThemeModePreference> onChanged;

  const _ThemeModePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ThemeModePreference.values
          .map(
            (mode) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: mode == ThemeModePreference.values.last ? 0 : 8,
                ),
                child: _ThemeModeButton(
                  label: _label(mode),
                  selected: mode == value,
                  onTap: () => onChanged(mode),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  String _label(ThemeModePreference mode) {
    return switch (mode) {
      ThemeModePreference.system => 'SYSTEM',
      ThemeModePreference.light => 'LIGHT',
      ThemeModePreference.dark => 'DARK',
    };
  }
}

class _ThemeModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.neonBlue.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppTheme.neonBlue.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppTheme.neonBlue : AppTheme.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.neonBlue, size: 14),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RotationIntervalPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _RotationIntervalPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value:
              DashboardProvider.backgroundRotationMinuteOptions.contains(value)
              ? value
              : 2,
          dropdownColor: AppTheme.darkCard,
          iconEnabledColor: AppTheme.neonBlue,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          items: DashboardProvider.backgroundRotationMinuteOptions
              .map(
                (minutes) => DropdownMenuItem<int>(
                  value: minutes,
                  child: Text('$minutes min'),
                ),
              )
              .toList(),
          onChanged: (minutes) {
            if (minutes == null) return;
            onChanged(minutes);
          },
        ),
      ),
    );
  }
}

class _SettingsSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SettingsSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
            Text(
              displayValue,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppTheme.neonBlue,
          inactiveColor: AppTheme.textMuted.withValues(alpha: 0.25),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _WidgetControlRow extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool canMoveUp;
  final bool canMoveDown;
  final ValueChanged<bool> onToggle;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _WidgetControlRow({
    required this.label,
    required this.enabled,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggle,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: canMoveUp ? onMoveUp : null,
            icon: Icon(Icons.keyboard_arrow_up, color: AppTheme.textSecondary),
          ),
          IconButton(
            onPressed: canMoveDown ? onMoveDown : null,
            icon: Icon(
              Icons.keyboard_arrow_down,
              color: AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          Switch(
            value: enabled,
            onChanged: onToggle,
            activeThumbColor: AppTheme.neonBlue,
            activeTrackColor: AppTheme.neonBlue.withValues(alpha: 0.3),
            inactiveThumbColor: AppTheme.textMuted,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingsRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
