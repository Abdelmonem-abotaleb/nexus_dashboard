import 'package:flutter/material.dart';

import '../services/power_service.dart';
import '../theme/app_theme.dart';

class PowerActionWidget extends StatelessWidget {
  final PowerAction action;

  const PowerActionWidget({super.key, required this.action});

  String get _title => switch (action) {
    PowerAction.shutdown => 'SHUT DOWN',
    PowerAction.restart => 'RESTART',
    PowerAction.sleep => 'SLEEP',
  };

  String get _confirmMessage => switch (action) {
    PowerAction.shutdown => 'Shut down Windows now?',
    PowerAction.restart => 'Restart Windows now?',
    PowerAction.sleep => 'Put Windows to sleep now?',
  };

  IconData get _icon => switch (action) {
    PowerAction.shutdown => Icons.power_settings_new_rounded,
    PowerAction.restart => Icons.restart_alt_rounded,
    PowerAction.sleep => Icons.nights_stay_rounded,
  };

  Color get _color => switch (action) {
    PowerAction.shutdown => AppTheme.neonPink,
    PowerAction.restart => const Color(0xFFFFBD2E),
    PowerAction.sleep => AppTheme.neonBlue,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmAndRun(context),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: AppTheme.glassDecoration(
          borderRadius: 20,
          borderColor: _color.withValues(alpha: 0.2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, color: _color, size: 30),
              const SizedBox(height: 10),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndRun(BuildContext context) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppTheme.useDarkMode
          ? Colors.black.withValues(alpha: 0.6)
          : Colors.white.withValues(alpha: 0.35),
      builder: (_) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.glassBorder),
        ),
        title: Text(
          _title,
          style: TextStyle(
            color: _color,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        content: Text(
          _confirmMessage,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('CANCEL', style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_title, style: TextStyle(color: _color)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await runPowerAction(action);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not run $_title: ${e.toString()}'),
          backgroundColor: AppTheme.neonPink,
        ),
      );
    }
  }
}
