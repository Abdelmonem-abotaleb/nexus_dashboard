import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/dashboard_provider.dart';
import '../services/app_launch_service.dart';
import '../services/fuzzy_matcher.dart';
import '../services/power_service.dart';
import '../theme/app_theme.dart';

enum CommandItemType { app, website, todo, action }

class CommandPaletteItem {
  final String id;
  final String title;
  final String subtitle;
  final CommandItemType type;
  final IconData icon;
  final String? iconPath;
  final Color? color;
  final VoidCallback onExecute;

  const CommandPaletteItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.icon,
    this.iconPath,
    this.color,
    required this.onExecute,
  });
}

class CommandPalette extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback? onOpenSettings;

  const CommandPalette({
    super.key,
    required this.onClose,
    this.onOpenSettings,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() {
      setState(() => _selectedIndex = 0);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<CommandPaletteItem> _buildItems(DashboardProvider dashboard) {
    final items = <CommandPaletteItem>[];

    // Apps
    for (final app in dashboard.apps) {
      items.add(
        CommandPaletteItem(
          id: 'app_${app.id}',
          title: app.name,
          subtitle: 'Launch application',
          type: CommandItemType.app,
          icon: Icons.apps_rounded,
          iconPath: app.iconPath,
          color: AppTheme.neonGreen,
          onExecute: () {
            widget.onClose();
            AppLaunchService.instance.launchAppWithPolicy(
              app: app,
              dashboard: dashboard,
            );
          },
        ),
      );
    }

    // Websites
    for (final site in dashboard.websites) {
      items.add(
        CommandPaletteItem(
          id: 'web_${site.id}',
          title: site.name,
          subtitle: site.url,
          type: CommandItemType.website,
          icon: Icons.language_rounded,
          color: AppTheme.neonBlue,
          onExecute: () {
            widget.onClose();
            final uri = Uri.tryParse(site.url);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      );
    }

    // Todos
    for (final todo in dashboard.todos) {
      items.add(
        CommandPaletteItem(
          id: 'todo_${todo.id}',
          title: todo.text,
          subtitle: todo.completed ? 'Completed to-do' : 'Pending to-do (Enter to toggle)',
          type: CommandItemType.todo,
          icon: todo.completed ? Icons.check_circle_outline : Icons.circle_outlined,
          color: todo.completed ? Colors.white38 : AppTheme.neonOrange,
          onExecute: () {
            dashboard.toggleTodo(todo.id);
            widget.onClose();
          },
        ),
      );
    }

    // Quick Actions
    items.add(
      CommandPaletteItem(
        id: 'action_widget_mode',
        title: dashboard.desktopWidgetMode
            ? 'Switch to Full Dashboard'
            : 'Switch to Desktop Widget Mode',
        subtitle: 'Transform between compact desktop widget and full dashboard',
        type: CommandItemType.action,
        icon: Icons.picture_in_picture_alt_rounded,
        color: AppTheme.neonBlue,
        onExecute: () {
          dashboard.toggleDesktopWidgetMode();
          widget.onClose();
        },
      ),
    );

    items.add(
      CommandPaletteItem(
        id: 'action_edit_mode',
        title: dashboard.isEditMode ? 'Exit Edit Mode' : 'Customize Dashboard (Edit Mode)',
        subtitle: 'Toggle layout editing and widget moving',
        type: CommandItemType.action,
        icon: Icons.dashboard_customize_outlined,
        color: AppTheme.neonPurple,
        onExecute: () {
          dashboard.toggleEditMode();
          widget.onClose();
        },
      ),
    );

    if (widget.onOpenSettings != null) {
      items.add(
        CommandPaletteItem(
          id: 'action_settings',
          title: 'Open Settings',
          subtitle: 'Configure backdrop, accent, widgets, and preferences',
          type: CommandItemType.action,
          icon: Icons.settings_outlined,
          color: AppTheme.neonPurple,
          onExecute: () {
            widget.onClose();
            widget.onOpenSettings!();
          },
        ),
      );
    }

    items.add(
      CommandPaletteItem(
        id: 'action_sleep',
        title: 'Sleep PC',
        subtitle: 'Put the system to sleep',
        type: CommandItemType.action,
        icon: Icons.bedtime_outlined,
        color: AppTheme.neonBlue,
        onExecute: () {
          widget.onClose();
          runPowerAction(PowerAction.sleep);
        },
      ),
    );

    return items;
  }

  List<CommandPaletteItem> _filterItems(List<CommandPaletteItem> allItems, String query) {
    if (query.trim().isEmpty) return allItems;

    final scored = <({CommandPaletteItem item, int score})>[];
    for (final item in allItems) {
      final match = FuzzyMatcher.match(query, item.title);
      if (match.matches) {
        scored.add((item: item, score: match.score));
      } else {
        // Fallback search subtitle
        final subMatch = FuzzyMatcher.match(query, item.subtitle);
        if (subMatch.matches) {
          scored.add((item: item, score: subMatch.score - 50));
        }
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.item).toList();
  }

  void _handleKey(KeyEvent event, List<CommandPaletteItem> items) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (items.isEmpty) return;
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % items.length;
      });
      _scrollToIndex(_selectedIndex);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (items.isEmpty) return;
      setState(() {
        _selectedIndex = (_selectedIndex - 1 + items.length) % items.length;
      });
      _scrollToIndex(_selectedIndex);
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (items.isNotEmpty && _selectedIndex < items.length) {
        items[_selectedIndex].onExecute();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onClose();
    }
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    const itemHeight = 56.0;
    final targetOffset = index * itemHeight;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final allItems = _buildItems(dashboard);
    final filteredItems = _filterItems(allItems, _queryController.text);
    final accent = AppTheme.accent(context);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) => _handleKey(event, filteredItems),
      child: Center(
        child: Container(
          width: 620,
          constraints: const BoxConstraints(maxHeight: 480),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 32,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: accent, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _queryController,
                            focusNode: _inputFocusNode,
                            autofocus: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type an app, bookmark, to-do, or command...',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 15,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_queryController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: Colors.white60,
                            splashRadius: 16,
                            onPressed: () => _queryController.clear(),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ESC',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),

                  // Results list
                  Flexible(
                    child: filteredItems.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off_rounded,
                                  size: 40,
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No matching results found',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            shrinkWrap: true,
                            itemCount: filteredItems.length,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemBuilder: (context, index) {
                              final item = filteredItems[index];
                              final isSelected = index == _selectedIndex;

                              return InkWell(
                                onTap: item.onExecute,
                                onHover: (hovering) {
                                  if (hovering) {
                                    setState(() => _selectedIndex = index);
                                  }
                                },
                                child: Container(
                                  height: 54,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? accent.withValues(alpha: 0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(
                                            color: accent.withValues(alpha: 0.4),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // Item Icon / App Icon
                                      _buildItemIcon(item),
                                      const SizedBox(width: 12),
                                      // Title & subtitle
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: isSelected ? 0.8 : 0.45,
                                                ),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Type Badge
                                      _buildTypeBadge(item.type),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),

                  // Footer shortcut tips
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildKeyHint('↑↓', 'Navigate'),
                        const SizedBox(width: 12),
                        _buildKeyHint('↵', 'Execute'),
                        const Spacer(),
                        Text(
                          'Nexus Launcher',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemIcon(CommandPaletteItem item) {
    if (item.iconPath != null && item.iconPath!.isNotEmpty) {
      final file = File(item.iconPath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            file,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallbackIcon(item),
          ),
        );
      }
    }
    return _buildFallbackIcon(item);
  }

  Widget _buildFallbackIcon(CommandPaletteItem item) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: (item.color ?? Colors.white).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        item.icon,
        size: 16,
        color: item.color ?? Colors.white,
      ),
    );
  }

  Widget _buildTypeBadge(CommandItemType type) {
    final (label, color) = switch (type) {
      CommandItemType.app => ('APP', AppTheme.neonGreen),
      CommandItemType.website => ('WEB', AppTheme.neonBlue),
      CommandItemType.todo => ('TODO', AppTheme.neonOrange),
      CommandItemType.action => ('ACTION', AppTheme.neonPurple),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildKeyHint(String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            key,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
