import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

class AddWebsiteDialog extends StatefulWidget {
  final WebShortcut? existingSite;
  final Function(WebShortcut) onSave;
  final String Function() generateId;

  const AddWebsiteDialog({
    super.key,
    this.existingSite,
    required this.onSave,
    required this.generateId,
  });

  @override
  State<AddWebsiteDialog> createState() => _AddWebsiteDialogState();
}

class _AddWebsiteDialogState extends State<AddWebsiteDialog> {
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  String _selectedColor = '#7B2FFF';

  final _colors = [
    '#00D4FF',
    '#7B2FFF',
    '#00FF94',
    '#FF006E',
    '#FF9F0A',
    '#4285F4',
    '#1DB954',
    '#5865F2',
    '#EA4335',
    '#FBBC04',
    '#FF4500',
    '#FFFFFF',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingSite?.name ?? '',
    );
    _urlController = TextEditingController(
      text: widget.existingSite?.url ?? '',
    );
    _selectedColor = widget.existingSite?.color ?? '#7B2FFF';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSite != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonPink.withValues(alpha: 0.1),
              blurRadius: 40,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              isEditing ? 'EDIT WEBSITE' : 'ADD WEBSITE',
              style: TextStyle(
                color: AppTheme.neonPink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),

            const SizedBox(height: 24),

            _Field(
              label: 'Site Name',
              controller: _nameController,
              hint: 'e.g. YouTube',
            ),

            const SizedBox(height: 16),

            _Field(
              label: 'URL',
              controller: _urlController,
              hint: 'https://youtube.com',
            ),

            const SizedBox(height: 16),

            // Color picker
            Text(
              'Color',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((hex) {
                final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                final selected = _selectedColor == hex;
                return InkWell(
                  onTap: () => setState(() => _selectedColor = hex),
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: selected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: selected
                        ? Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 12,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'CANCEL',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    if (_nameController.text.isEmpty ||
                        _urlController.text.isEmpty) {
                      return;
                    }
                    var url = _urlController.text.trim();
                    if (!url.startsWith('http')) {
                      url = 'https://$url';
                    }
                    widget.onSave(
                      WebShortcut(
                        id: widget.existingSite?.id ?? widget.generateId(),
                        name: _nameController.text.trim(),
                        url: url,
                        color: _selectedColor,
                      ),
                    );
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonPink.withValues(alpha: 0.15),
                    foregroundColor: AppTheme.neonPink,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: AppTheme.neonPink.withValues(alpha: 0.4),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    isEditing ? 'SAVE CHANGES' : 'ADD SITE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
              fontSize: 13,
            ),
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
                color: AppTheme.neonPink.withValues(alpha: 0.5),
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
