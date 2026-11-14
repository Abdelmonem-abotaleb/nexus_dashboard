import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/dashboard_provider.dart';
import '../services/app_icon_service.dart';
import '../services/app_launch_service.dart';
import '../theme/app_theme.dart';
import 'add_app_dialog.dart';

class AppLauncherWidget extends StatelessWidget {
  const AppLauncherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context
        .select<DashboardProvider, (List<AppShortcut>, bool)>(
          (dashboard) => (dashboard.apps, dashboard.isEditMode),
        );
    final dashboard = context.read<DashboardProvider>();
    final apps = selected.$1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(
        context,
        borderRadius: 20,
        borderColor: AppTheme.accent(context).withValues(alpha: 0.15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.apps_rounded,
                color: AppTheme.accent(context),
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'APP LAUNCHER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.accent(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showAddAppDialog(context, dashboard),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('ADD APP'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // App grid
          apps.isEmpty
              ? _emptyState(context, dashboard)
              : Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: apps.asMap().entries.map((entry) {
                    final index = entry.key;
                    final app = entry.value;
                    final iconWidget = _AppIcon(
                      app: app,
                      isEditMode: selected.$2,
                      onLaunch: () => _launchApp(context, app),
                      onDelete: () =>
                          _confirmDeleteApp(context, dashboard, app),
                      onEdit: () =>
                          _showEditAppDialog(context, dashboard, app),
                      onMoveUp: index > 0
                          ? () => dashboard.reorderApps(index, index - 1)
                          : null,
                      onMoveDown: index < apps.length - 1
                          ? () => dashboard.reorderApps(index, index + 2)
                          : null,
                    );

                    if (!selected.$2) {
                      return iconWidget;
                    }

                    return DragTarget<int>(
                      onWillAcceptWithDetails: (details) => details.data != index,
                      onAcceptWithDetails: (details) {
                        final fromIndex = details.data;
                        dashboard.reorderApps(
                          fromIndex,
                          index > fromIndex ? index + 1 : index,
                        );
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovered = candidateData.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: isHovered
                                ? Border.all(
                                    color: AppTheme.accent(context),
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Draggable<int>(
                            data: index,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Opacity(
                                opacity: 0.9,
                                child: Transform.scale(
                                  scale: 1.08,
                                  child: iconWidget,
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: iconWidget,
                            ),
                            child: iconWidget,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, DashboardProvider dashboard) {
    return InkWell(
      onTap: () => _showAddAppDialog(context, dashboard),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first app',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchApp(BuildContext context, AppShortcut app) async {
    final dashboard = context.read<DashboardProvider>();
    try {
      await AppLaunchService.instance.launchAppWithPolicy(
        app: app,
        dashboard: dashboard,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not launch ${app.name}: ${e.toString()}',
            ),
            backgroundColor: AppTheme.neonPink,
          ),
        );
      }
    }
  }

  void _showAddAppDialog(BuildContext context, DashboardProvider dashboard) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => AddAppDialog(
        onSave: (app) => dashboard.addApp(app),
        generateId: dashboard.generateId,
      ),
    );
  }

  void _showEditAppDialog(
    BuildContext context,
    DashboardProvider dashboard,
    AppShortcut app,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => AddAppDialog(
        existingApp: app,
        onSave: (updated) => dashboard.updateApp(updated),
        generateId: dashboard.generateId,
      ),
    );
  }

  Future<void> _confirmDeleteApp(
    BuildContext context,
    DashboardProvider dashboard,
    AppShortcut app,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => _DeleteConfirmDialog(
        title: 'REMOVE APP',
        message: 'Remove ${app.name} from the launcher?',
        accentColor: AppTheme.neonGreen,
      ),
    );
    if (confirmed == true) {
      dashboard.removeApp(app.id);
    }
  }
}

class AppShortcutPathStatus {
  final bool iconExists;
  final bool pathExists;

  const AppShortcutPathStatus({
    required this.iconExists,
    required this.pathExists,
  });
}

Future<AppShortcutPathStatus> checkAppShortcutPaths(AppShortcut app) async {
  final path = app.executablePath.replaceAll(
    '%USERNAME%',
    Platform.environment['USERNAME'] ?? '',
  );
  final iconExistsFuture = app.iconPath.isEmpty
      ? Future.value(false)
      : File(app.iconPath).exists();
  final pathExistsFuture = _isUwpOrProtocol(path)
      ? Future.value(true)
      : File(path).exists();

  final results = await Future.wait([iconExistsFuture, pathExistsFuture]);
  return AppShortcutPathStatus(iconExists: results[0], pathExists: results[1]);
}

// â”€â”€â”€ App Icon â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _AppIcon extends StatefulWidget {
  final AppShortcut app;
  final bool isEditMode;
  final VoidCallback onLaunch;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _AppIcon({
    required this.app,
    required this.isEditMode,
    required this.onLaunch,
    required this.onDelete,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _iconExists = false;
  bool _pathExists = false;
  bool _pathsChecked = false;
  int _pathCheckGeneration = 0;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
    _checkPaths();
  }

  @override
  void didUpdateWidget(_AppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.app.executablePath != widget.app.executablePath ||
        oldWidget.app.iconPath != widget.app.iconPath) {
      _checkPaths();
    }
  }

  @override
  void dispose() {
    _pathCheckGeneration++;
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _checkPaths() async {
    final generation = ++_pathCheckGeneration;
    if (_pathsChecked || _iconExists || _pathExists) {
      setState(() {
        _iconExists = false;
        _pathExists = false;
        _pathsChecked = false;
      });
    }
    final status = await checkAppShortcutPaths(widget.app);
    if (!mounted || generation != _pathCheckGeneration) return;
    setState(() {
      _iconExists = status.iconExists;
      _pathExists = status.pathExists;
      _pathsChecked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        _scaleController.forward();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        _scaleController.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnim,
        child: InkWell(
          onTap: widget.isEditMode ? widget.onEdit : widget.onLaunch,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: _hovered
                      ? AppTheme.accent(context).withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: _hovered
                        ? AppTheme.accent(context).withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                      child: _iconExists
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(widget.app.iconPath),
                                fit: BoxFit.cover,
                                cacheWidth: 88,
                                cacheHeight: 88,
                                filterQuality: FilterQuality.medium,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.apps_rounded,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.app.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Edit controls
              if (widget.isEditMode || _hovered)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Row(
                    children: [
                      if (widget.isEditMode && widget.onMoveUp != null)
                        _EditBubble(
                          icon: Icons.arrow_upward_rounded,
                          onTap: widget.onMoveUp!,
                        ),
                      if (widget.isEditMode && widget.onMoveDown != null)
                        _EditBubble(
                          icon: Icons.arrow_downward_rounded,
                          onTap: widget.onMoveDown!,
                        ),
                      IconButton.filled(
                        onPressed: widget.onDelete,
                        tooltip: 'Remove ${widget.app.name}',
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        iconSize: 16,
                        style: IconButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
              if (_pathsChecked && !_pathExists)
                Positioned(
                  bottom: -6,
                  left: 4,
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.neonPink,
                    size: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditBubble extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _EditBubble({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onTap,
      tooltip: 'Reorder shortcut',
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      iconSize: 16,
      icon: Icon(icon),
    );
  }
}

class _DeleteConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final Color accentColor;

  const _DeleteConfirmDialog({
    required this.title,
    required this.message,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: accentColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'CANCEL',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('REMOVE', style: TextStyle(color: AppTheme.neonPink)),
        ),
      ],
    );
  }
}

bool _isUwpOrProtocol(String path) {
  return isUwpOrProtocol(path);
}
