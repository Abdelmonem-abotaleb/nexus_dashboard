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
    final dashboard = context.watch<DashboardProvider>();
    final websites = dashboard.websites;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(
        borderRadius: 20,
        borderColor: AppTheme.neonPink.withValues(alpha: 0.15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.language_rounded, color: AppTheme.neonPink, size: 14),
              const SizedBox(width: 8),
              Text(
                'WEBSITES',
                style: TextStyle(
                  color: AppTheme.neonPink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showAddDialog(context, dashboard),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.neonPink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppTheme.neonPink.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: AppTheme.neonPink,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ADD SITE',
                        style: TextStyle(
                          color: AppTheme.neonPink,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
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
                  children: websites
                      .asMap()
                      .entries
                      .map(
                        (site) => _WebsiteChip(
                          site: site.value,
                          isEditMode: dashboard.isEditMode,
                          onTap: () => _launch(context, site.value.url),
                          onDelete: () => _confirmDeleteSite(
                            context,
                            dashboard,
                            site.value,
                          ),
                          onEdit: () =>
                              _showEditDialog(context, dashboard, site.value),
                          onMoveUp: site.key > 0
                              ? () => dashboard.reorderWebsites(
                                  site.key,
                                  site.key - 1,
                                )
                              : null,
                          onMoveDown: site.key < websites.length - 1
                              ? () => dashboard.reorderWebsites(
                                  site.key,
                                  site.key + 2,
                                )
                              : null,
                        ),
                      )
                      .toList(),
                ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, DashboardProvider dashboard) {
    return GestureDetector(
      onTap: () => _showAddDialog(context, dashboard),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.glassBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.add_link_rounded, color: AppTheme.textMuted, size: 28),
            SizedBox(height: 8),
            Text(
              'Add your first website',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
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

// ─── Website Chip ─────────────────────────────────────────────────────────────
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
          GestureDetector(
            onTap: widget.isEditMode ? widget.onEdit : widget.onTap,
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
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: _color.withValues(alpha: 0.25),
                          blurRadius: 16,
                          spreadRadius: -4,
                        ),
                      ]
                    : null,
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
                      color: _hovered ? _color : AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.open_in_new_rounded,
                    color: _hovered
                        ? _color.withValues(alpha: 0.7)
                        : AppTheme.textMuted,
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
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.neonPink,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.only(right: 3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.darkCard,
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Icon(icon, color: AppTheme.textSecondary, size: 11),
      ),
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
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.glassBorder),
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
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('REMOVE', style: TextStyle(color: AppTheme.neonPink)),
        ),
      ],
    );
  }
}
