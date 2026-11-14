import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';

class DesktopWidgetView extends StatefulWidget {
  final Widget? Function(String id) buildWidget;
  final VoidCallback onOpenSettings;

  const DesktopWidgetView({
    super.key,
    required this.buildWidget,
    required this.onOpenSettings,
  });

  @override
  State<DesktopWidgetView> createState() => _DesktopWidgetViewState();
}

class _DesktopWidgetViewState extends State<DesktopWidgetView> {
  bool _hovered = false;
  bool _pickerOpen = false;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final visibleIds = dashboard.visibleDesktopWidgetOrder;
    final controlsVisible = _hovered || _pickerOpen || visibleIds.isEmpty;
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: visibleIds.isEmpty
                  ? _EmptyWidgetState(
                      onChooseWidgets: () => setState(() => _pickerOpen = true),
                      onSwitchToDashboard: () =>
                          dashboard.setDesktopWidgetMode(false),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 52, 12, 14),
                      physics: const BouncingScrollPhysics(),
                      itemCount: visibleIds.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final id = visibleIds[index];
                        final child = widget.buildWidget(id);
                        if (child == null) return const SizedBox.shrink();
                        return KeyedSubtree(
                          key: ValueKey('desktop-widget-card-$id'),
                          child: _wrapCardForCompactStack(id, child),
                        );
                      },
                    ),
            ),

            // Hover-only mini control bar
            Positioned(
              top: 8,
              left: 10,
              right: 10,
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: AnimatedOpacity(
                  opacity: controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  child: _MiniControlBar(
                    dashboard: dashboard,
                    pickerOpen: _pickerOpen,
                    onTogglePicker: () =>
                        setState(() => _pickerOpen = !_pickerOpen),
                    onOpenSettings: widget.onOpenSettings,
                  ),
                ),
              ),
            ),

            // Inline widget picker & reorder drawer
            if (_pickerOpen)
              Positioned(
                top: 52,
                left: 12,
                right: 12,
                bottom: 12,
                child: _WidgetPickerPanel(
                  dashboard: dashboard,
                  onClose: () => setState(() => _pickerOpen = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _wrapCardForCompactStack(String id, Widget child) {
    return switch (id) {
      'agenda' => SizedBox(height: 240, child: child),
      'power' => SizedBox(height: 165, child: child),
      'todos' => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: child,
      ),
      _ => child,
    };
  }
}

class _MiniControlBar extends StatelessWidget {
  final DashboardProvider dashboard;
  final bool pickerOpen;
  final VoidCallback onTogglePicker;
  final VoidCallback onOpenSettings;

  const _MiniControlBar({
    required this.dashboard,
    required this.pickerOpen,
    required this.onTogglePicker,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.accent(context);
    final locked = dashboard.desktopWidgetLockPosition;

    final dragStrip = Row(
      children: [
        Icon(
          locked ? Icons.lock_outline_rounded : Icons.drag_indicator_rounded,
          size: 14,
          color: locked ? accent : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            locked ? 'LOCKED' : 'NEXUS WIDGET',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: locked
                    ? dragStrip
                    : DragToMoveArea(child: SizedBox(height: 36, child: dragStrip)),
              ),
              _MiniIconButton(
                key: const Key('desktop-widget-picker-button'),
                icon: pickerOpen
                    ? Icons.widgets_rounded
                    : Icons.widgets_outlined,
                tooltip: 'Choose widget cards',
                active: pickerOpen,
                onTap: onTogglePicker,
              ),
              _MiniIconButton(
                key: const Key('desktop-widget-pin-button'),
                icon: dashboard.desktopWidgetAlwaysOnTop
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                tooltip: dashboard.desktopWidgetAlwaysOnTop
                    ? 'Unpin from top'
                    : 'Always on top',
                active: dashboard.desktopWidgetAlwaysOnTop,
                onTap: () => dashboard.setDesktopWidgetAlwaysOnTop(
                  !dashboard.desktopWidgetAlwaysOnTop,
                ),
              ),
              _MiniIconButton(
                key: const Key('desktop-widget-lock-button'),
                icon: locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                tooltip: locked ? 'Unlock position' : 'Lock position',
                active: locked,
                onTap: () => dashboard.setDesktopWidgetLockPosition(!locked),
              ),
              _MiniIconButton(
                key: const Key('desktop-widget-settings-button'),
                icon: Icons.settings_outlined,
                tooltip: 'Open settings',
                onTap: onOpenSettings,
              ),
              _MiniIconButton(
                key: const Key('desktop-widget-expand-button'),
                icon: Icons.open_in_full_rounded,
                tooltip: 'Switch to Full Dashboard',
                onTap: () => dashboard.setDesktopWidgetMode(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _MiniIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.accent(context);
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      iconSize: 16,
      style: active
          ? IconButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.16),
              foregroundColor: accent,
            )
          : IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
      icon: Icon(icon),
    );
  }
}

class _WidgetPickerPanel extends StatelessWidget {
  final DashboardProvider dashboard;
  final VoidCallback onClose;

  const _WidgetPickerPanel({required this.dashboard, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppTheme.accent(context);
    final order = dashboard.desktopWidgetOrder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 16, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'DESKTOP WIDGET CARDS',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Done',
                      onPressed: onClose,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.check_rounded, size: 18),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  itemCount: order.length,
                  itemBuilder: (context, index) {
                    final id = order[index];
                    final enabled = dashboard.isDesktopWidgetEnabled(id);
                    return Container(
                      key: ValueKey('desktop-picker-item-$id'),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: enabled
                            ? accent.withValues(alpha: 0.08)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: enabled,
                            onChanged: (value) {
                              if (value != null) {
                                dashboard.setDesktopWidgetEnabled(id, value);
                              }
                            },
                          ),
                          Icon(
                            _widgetIcon(id),
                            size: 16,
                            color: enabled
                                ? accent
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => dashboard.setDesktopWidgetEnabled(
                                id,
                                !enabled,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text(
                                  desktopWidgetLabel(id),
                                  style: TextStyle(
                                    color: enabled
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: enabled
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Move ${desktopWidgetLabel(id)} up',
                            onPressed: index > 0
                                ? () => dashboard.reorderDesktopWidget(
                                    index,
                                    index - 1,
                                  )
                                : null,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            iconSize: 16,
                            icon: const Icon(Icons.keyboard_arrow_up_rounded),
                          ),
                          IconButton(
                            tooltip: 'Move ${desktopWidgetLabel(id)} down',
                            onPressed: index < order.length - 1
                                ? () => dashboard.reorderDesktopWidget(
                                    index,
                                    index + 2,
                                  )
                                : null,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            iconSize: 16,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _widgetIcon(String id) => switch (id) {
    'clock' => Icons.schedule_rounded,
    'weather' => Icons.wb_sunny_outlined,
    'agenda' => Icons.calendar_month_outlined,
    'apps' => Icons.apps_rounded,
    'todos' => Icons.checklist_rounded,
    'prayerTimes' => Icons.mosque_outlined,
    'system' => Icons.memory_rounded,
    'power' => Icons.power_settings_new_rounded,
    'websites' => Icons.language_rounded,
    _ => Icons.widgets_outlined,
  };
}

class _EmptyWidgetState extends StatelessWidget {
  final VoidCallback onChooseWidgets;
  final VoidCallback onSwitchToDashboard;

  const _EmptyWidgetState({
    required this.onChooseWidgets,
    required this.onSwitchToDashboard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.glassDecoration(context, borderRadius: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.widgets_outlined,
                size: 32,
                color: AppTheme.accent(context),
              ),
              const SizedBox(height: 10),
              Text(
                'No widgets selected',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Pick weather, prayer times, clock, or any cards to display on your desktop.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onChooseWidgets,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Choose widgets'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onSwitchToDashboard,
                child: const Text('Back to Full Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String desktopWidgetLabel(String id) => switch (id) {
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
