import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:window_manager/window_manager.dart';

import '../models/models.dart';
import '../services/app_icon_service.dart';
import '../theme/app_theme.dart';

class AddAppDialog extends StatefulWidget {
  final AppShortcut? existingApp;
  final Function(AppShortcut) onSave;
  final String Function() generateId;

  const AddAppDialog({
    super.key,
    this.existingApp,
    required this.onSave,
    required this.generateId,
  });

  @override
  State<AddAppDialog> createState() => _AddAppDialogState();
}

class _AddAppDialogState extends State<AddAppDialog> {
  late TextEditingController _nameController;
  late TextEditingController _pathController;
  String _iconPath = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingApp?.name ?? '',
    );
    _pathController = TextEditingController(
      text: widget.existingApp?.executablePath ?? '',
    );
    _iconPath = widget.existingApp?.iconPath ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  Future<FilePickerResult?> _pickExecutable() async {
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
        type: FileType.custom,
        allowedExtensions: ['exe', 'bat', 'cmd', 'lnk'],
      );
      return result;
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingApp != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonBlue.withValues(alpha: 0.1),
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
              isEditing ? 'EDIT APP' : 'ADD APP',
              style: TextStyle(
                color: AppTheme.neonGreen,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),

            const SizedBox(height: 24),

            // Name field
            _DialogTextField(
              label: 'App Name',
              controller: _nameController,
              hint: 'e.g. Chrome',
            ),

            const SizedBox(height: 16),

            // Path field
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Executable Path',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _pathController,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          hintText: r'C:\Program Files\...\app.exe',
                          hintStyle: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.72),
                            fontSize: 11,
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
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        final result = await _pickExecutable();
                        if (result != null &&
                            result.files.single.path != null) {
                          _pathController.text = result.files.single.path!;
                          if (_nameController.text.isEmpty) {
                            final fileName = result.files.single.name
                                .replaceAll(
                                  RegExp(r'\.(exe|bat|cmd|lnk)$'),
                                  '',
                                );
                            _nameController.text = fileName;
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.neonBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.neonBlue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.folder_open_rounded,
                          color: AppTheme.neonBlue,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        final selectedApp =
                            await showDialog<Map<String, String>>(
                              context: context,
                              barrierColor: Colors.black.withValues(alpha: 0.6),
                              builder: (_) =>
                                  const _InstalledAppsPickerDialog(),
                            );
                        if (selectedApp != null) {
                          _pathController.text = selectedApp['appId']!;
                          if (_nameController.text.isEmpty) {
                            _nameController.text = selectedApp['name']!;
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.neonGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.neonGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.apps_rounded,
                          color: AppTheme.neonGreen,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Icon preview
            Text(
              'Icon',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: _iconPath.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_iconPath),
                        fit: BoxFit.cover,
                        cacheWidth: 104,
                        cacheHeight: 104,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.apps_rounded, size: 28),
                      ),
                    )
                  : Icon(
                      Icons.apps_rounded,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 28,
                    ),
            ),

            const SizedBox(height: 24),

            // Actions
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
                  onPressed: _isSaving
                      ? null
                      : () async {
                          if (_nameController.text.isEmpty ||
                              _pathController.text.isEmpty) {
                            return;
                          }
                          setState(() => _isSaving = true);
                          final appId =
                              widget.existingApp?.id ?? widget.generateId();
                          final iconPath = await extractWindowsAppIcon(
                            executablePath: _pathController.text,
                            appId: appId,
                          );
                          if (!context.mounted) return;
                          widget.onSave(
                            AppShortcut(
                              id: appId,
                              name: _nameController.text,
                              executablePath: _pathController.text,
                              iconPath: iconPath.isNotEmpty
                                  ? iconPath
                                  : _iconPath,
                              color: widget.existingApp?.color ?? '#00D4FF',
                            ),
                          );
                          Navigator.of(context).pop();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonGreen.withValues(alpha: 0.15),
                    foregroundColor: AppTheme.neonGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: AppTheme.neonGreen.withValues(alpha: 0.4),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.neonGreen,
                            ),
                          ),
                        )
                      : Text(
                          isEditing ? 'SAVE CHANGES' : 'ADD APP',
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

class _DialogTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const _DialogTextField({
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

class _InstalledAppsPickerDialog extends StatefulWidget {
  const _InstalledAppsPickerDialog();

  @override
  State<_InstalledAppsPickerDialog> createState() =>
      _InstalledAppsPickerDialogState();
}

class _InstalledAppsPickerDialogState
    extends State<_InstalledAppsPickerDialog> {
  List<Map<String, String>> _allApps = [];
  List<Map<String, String>> _filteredApps = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    try {
      final result = await Process.run('powershell', [
        '-Command',
        '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; Get-StartApps | ConvertTo-Json',
      ]);
      if (result.exitCode == 0) {
        final decoded = jsonDecode(result.stdout);
        List<Map<String, String>> appsList = [];
        if (decoded is List) {
          appsList = decoded.map<Map<String, String>>((app) {
            return {
              'name': (app['Name'] ?? '').toString(),
              'appId': (app['AppID'] ?? '').toString(),
            };
          }).toList();
        } else if (decoded is Map) {
          appsList = [
            {
              'name': (decoded['Name'] ?? '').toString(),
              'appId': (decoded['AppID'] ?? '').toString(),
            },
          ];
        }

        // Filter empty apps
        appsList.removeWhere(
          (app) => app['name']!.isEmpty || app['appId']!.isEmpty,
        );
        // Sort alphabetically by name
        appsList.sort(
          (a, b) =>
              a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()),
        );

        if (mounted) {
          setState(() {
            _allApps = appsList;
            _filteredApps = appsList;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading installed apps: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = _allApps;
      } else {
        _filteredApps = _allApps
            .where(
              (app) =>
                  app['name']!.toLowerCase().contains(query) ||
                  app['appId']!.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 440,
        height: 520,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.neonGreen.withValues(alpha: 0.1),
              blurRadius: 40,
              spreadRadius: -10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.apps_rounded, color: AppTheme.neonGreen, size: 16),
                const SizedBox(width: 8),
                Text(
                  'SELECT WINDOWS APP',
                  style: TextStyle(
                    color: AppTheme.neonGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search Box
            TextField(
              controller: _searchController,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Search installed apps (e.g. Codex)...',
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                  fontSize: 12,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 18,
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
                    color: AppTheme.neonGreen.withValues(alpha: 0.5),
                  ),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            const SizedBox(height: 16),

            // Content List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.neonGreen,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Scanning applications...',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _filteredApps.isEmpty
                  ? Center(
                      child: Text(
                        'No applications found',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.72),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = _filteredApps[index];
                        final isUwp =
                            app['appId']!.contains('!') ||
                            !app['appId']!.contains('\\');
                        return _AppListTile(
                          name: app['name']!,
                          appId: app['appId']!,
                          isUwp: isUwp,
                          onTap: () => Navigator.of(context).pop(app),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'CLOSE',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                      fontSize: 11,
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

class _AppListTile extends StatefulWidget {
  final String name;
  final String appId;
  final bool isUwp;
  final VoidCallback onTap;

  const _AppListTile({
    required this.name,
    required this.appId,
    required this.isUwp,
    required this.onTap,
  });

  @override
  State<_AppListTile> createState() => _AppListTileState();
}

class _AppListTileState extends State<_AppListTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: _hovered
                ? AppTheme.neonGreen.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.02),
            border: Border.all(
              color: _hovered
                  ? AppTheme.neonGreen.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: widget.isUwp
                      ? AppTheme.neonBlue.withValues(alpha: 0.15)
                      : AppTheme.neonGreen.withValues(alpha: 0.15),
                ),
                child: Icon(
                  widget.isUwp
                      ? Icons.grid_view_rounded
                      : Icons.desktop_windows_rounded,
                  color: widget.isUwp ? AppTheme.neonBlue : AppTheme.neonGreen,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.appId,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.isUwp)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: AppTheme.neonBlue.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppTheme.neonBlue.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    'STORE',
                    style: TextStyle(
                      color: AppTheme.neonBlue,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
