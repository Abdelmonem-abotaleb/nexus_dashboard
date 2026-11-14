import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../providers/dashboard_provider.dart';
import '../services/launch_window_service.dart';
import '../theme/app_theme.dart';
import 'add_website_dialog.dart';

class WebsiteWidget extends StatelessWidget {
  const WebsiteWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final selected = context
        .select<DashboardProvider, (List<WebShortcut>, bool)>(
          (dashboard) => (dashboard.websites, dashboard.isEditMode),
        );
    final dashboard = context.read<DashboardProvider>();
    final websites = selected.$1;

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
                Icons.language_rounded,
                color: AppTheme.accent(context),
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'WEBSITES',
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
                onPressed: () => _showAddDialog(context, dashboard),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('ADD SITE'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Website list
          websites.isEmpty
              ? _emptyState(context, dashboard)
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: websites.asMap().entries.map((entry) {
                    final index = entry.key;
                    final site = entry.value;
                    final chipWidget = _WebsiteChip(
                      site: site,
                      isEditMode: selected.$2,
                      onTap: () => _launch(context, site.url),
                      onDelete: () =>
                          _confirmDeleteSite(context, dashboard, site),
                      onEdit: () =>
                          _showEditDialog(context, dashboard, site),
                      onMoveUp: index > 0
                          ? () => dashboard.reorderWebsites(index, index - 1)
                          : null,
                      onMoveDown: index < websites.length - 1
                          ? () => dashboard.reorderWebsites(index, index + 2)
                          : null,
                    );

                    if (!selected.$2) {
                      return chipWidget;
                    }

                    return DragTarget<int>(
                      onWillAcceptWithDetails: (details) => details.data != index,
                      onAcceptWithDetails: (details) {
                        final fromIndex = details.data;
                        dashboard.reorderWebsites(
                          fromIndex,
                          index > fromIndex ? index + 1 : index,
                        );
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovered = candidateData.isNotEmpty;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
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
                                  scale: 1.05,
                                  child: chipWidget,
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: chipWidget,
                            ),
                            child: chipWidget,
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
      onTap: () => _showAddDialog(context, dashboard),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.add_link_rounded,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
              size: 28,
            ),
            SizedBox(height: 8),
            Text(
              'Add your first website',
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

  Future<void> _launch(BuildContext context, String url) async {
    final dashboard = context.read<DashboardProvider>();
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    final launchPolicy = LaunchWindowPolicy.fromDashboard(dashboard);

    try {
      await prepareWindowForExternalLaunch(launchPolicy);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw Exception('No application is registered to open this URL.');
      }
      await finishSuccessfulExternalLaunch(launchPolicy);
    } catch (e) {
      await restoreWindowAfterFailedExternalLaunch(launchPolicy);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open $url: ${e.toString()}'),
          backgroundColor: AppTheme.neonPink,
        ),
      );
    }
  }

  void _showAddDialog(BuildContext context, DashboardProvider dashboard) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => AddWebsiteDialog(
        onSave: (site) => dashboard.addWebsite(site),
        generateId: dashboard.generateId,
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    DashboardProvider dashboard,
    WebShortcut site,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => AddWebsiteDialog(
        existingSite: site,
        onSave: (updated) => dashboard.updateWebsite(updated),
        generateId: dashboard.generateId,
      ),
    );
  }

  Future<void> _confirmDeleteSite(
    BuildContext context,
    DashboardProvider dashboard,
    WebShortcut site,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => _DeleteConfirmDialog(
        title: 'REMOVE WEBSITE',
        message: 'Remove ${site.name} from shortcuts?',
      ),
    );
    if (confirmed == true) {
      dashboard.removeWebsite(site.id);
    }
  }
}

// â”€â”€â”€ Website Chip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _WebsiteChip extends StatefulWidget {
  final WebShortcut site;
  final bool isEditMode;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const _WebsiteChip({
    required this.site,
    required this.isEditMode,
    required this.onTap,
    required this.onDelete,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  State<_WebsiteChip> createState() => _WebsiteChipState();
}

class _WebsiteChipState extends State<_WebsiteChip> {
  bool _hovered = false;

  Color get _color {
    try {
      return Color(int.parse(widget.site.color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.neonPink;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            onTap: widget.isEditMode ? widget.onEdit : widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _hovered
                    ? _color.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: _hovered
                      ? _color.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Favicon or colored dot
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color.withValues(alpha: 0.3),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        widget.site.faviconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            widget.site.name[0].toUpperCase(),
                            style: TextStyle(
                              color: _color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.site.name,
                    style: TextStyle(
                      color: _hovered
                          ? _color
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.open_in_new_rounded,
                    color: _hovered
                        ? _color.withValues(alpha: 0.7)
                        : Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.72),
                    size: 12,
                  ),
                ],
              ),
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
                    _WebsiteEditBubble(
                      icon: Icons.arrow_upward_rounded,
                      onTap: widget.onMoveUp!,
                    ),
                  if (widget.isEditMode && widget.onMoveDown != null)
                    _WebsiteEditBubble(
                      icon: Icons.arrow_downward_rounded,
                      onTap: widget.onMoveDown!,
                    ),
                  IconButton.filled(
                    onPressed: widget.onDelete,
                    tooltip: 'Remove ${widget.site.name}',
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
        ],
      ),
    );
  }
}

class _WebsiteEditBubble extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _WebsiteEditBubble({required this.icon, required this.onTap});

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

  const _DeleteConfirmDialog({required this.title, required this.message});

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
          color: AppTheme.neonPink,
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
