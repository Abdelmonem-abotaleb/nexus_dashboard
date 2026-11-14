import 'package:flutter/material.dart';

import '../services/power_service.dart';
import '../theme/app_theme.dart';

class PowerActionsWidget extends StatelessWidget {
  const PowerActionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(context, borderRadius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'POWER',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          Row(
            children: PowerAction.values
                .map(
                  (action) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: action == PowerAction.values.last ? 0 : 8,
                      ),
                      child: _PowerButton(action: action),
                    ),
                  ),
                )
                .toList(),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Kept for callers that need one action; the redesigned dashboard uses the
/// consolidated [PowerActionsWidget].
class PowerActionWidget extends StatelessWidget {
  final PowerAction action;
  const PowerActionWidget({super.key, required this.action});

  @override
  Widget build(BuildContext context) => _PowerButton(action: action);
}

class _PowerButton extends StatelessWidget {
  final PowerAction action;
  const _PowerButton({required this.action});

  String get _title => switch (action) {
    PowerAction.shutdown => 'Shut down',
    PowerAction.restart => 'Restart',
    PowerAction.sleep => 'Sleep',
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

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _title,
      child: OutlinedButton(
        onPressed: () => _confirmAndRun(context),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 64),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 22),
            const SizedBox(height: 6),
            Text(_title, maxLines: 1, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndRun(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_title),
        content: Text(_confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_title),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await runPowerAction(action);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not run $_title: $error')));
    }
  }
}
