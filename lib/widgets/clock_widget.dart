import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../providers/dashboard_provider.dart';
import '../providers/window_activity_provider.dart';
import '../theme/app_theme.dart';

String greetingForHour(int hour) {
  if (hour < 5) return 'GOOD NIGHT';
  if (hour < 12) return 'GOOD MORNING';
  if (hour < 17) return 'GOOD AFTERNOON';
  if (hour < 21) return 'GOOD EVENING';
  return 'GOOD NIGHT';
}

Duration clockRefreshDelay(DateTime now, {required bool showSeconds}) {
  if (showSeconds) return const Duration(seconds: 1);
  final delay = Duration(
    minutes: 1,
    seconds: -now.second,
    milliseconds: -now.millisecond,
    microseconds: -now.microsecond,
  );
  return delay == Duration.zero ? const Duration(minutes: 1) : delay;
}

class ClockWidget extends StatelessWidget {
  const ClockWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final use24Hour = context.select<DashboardProvider, bool>(
      (dashboard) => dashboard.use24Hour,
    );
    final showSeconds = context.select<DashboardProvider, bool>(
      (dashboard) => dashboard.showSeconds,
    );
    final userName = context.select<DashboardProvider, String>(
      (dashboard) => dashboard.userName,
    );
    final isVisible = context.select<WindowActivityProvider?, bool>(
      (activity) => activity?.isVisible ?? true,
    );

    return _ClockContent(
      use24Hour: use24Hour,
      showSeconds: showSeconds,
      userName: userName,
      isVisible: isVisible,
    );
  }
}

class _ClockContent extends StatefulWidget {
  final bool use24Hour;
  final bool showSeconds;
  final String userName;
  final bool isVisible;

  const _ClockContent({
    required this.use24Hour,
    required this.showSeconds,
    required this.userName,
    this.isVisible = true,
  });

  @override
  State<_ClockContent> createState() => _ClockContentState();
}

class _ClockContentState extends State<_ClockContent> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    if (widget.isVisible) {
      _scheduleNextTick(widget.showSeconds);
    }
  }

  @override
  void didUpdateWidget(_ClockContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      if (widget.isVisible) {
        _now = DateTime.now();
        _scheduleNextTick(widget.showSeconds);
      } else {
        _timer?.cancel();
        _timer = null;
      }
      return;
    }
    if (!widget.isVisible) return;
    if (oldWidget.showSeconds == widget.showSeconds) return;
    _timer?.cancel();
    _scheduleNextTick(widget.showSeconds);
  }

  void _scheduleNextTick(bool showSeconds) {
    _timer?.cancel();
    if (!widget.isVisible) return;
    _timer = Timer(
      clockRefreshDelay(DateTime.now(), showSeconds: showSeconds),
      () {
        if (!mounted || !widget.isVisible) return;
        setState(() => _now = DateTime.now());
        _scheduleNextTick(showSeconds);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = widget.use24Hour
        ? (widget.showSeconds ? 'HH:mm:ss' : 'HH:mm')
        : (widget.showSeconds ? 'hh:mm:ss a' : 'hh:mm a');

    final timeStr = DateFormat(timeFormat).format(_now);
    final dateStr = DateFormat('EEEE, MMMM d').format(_now);
    final yearStr = DateFormat('yyyy').format(_now);
    final greeting = _getGreeting();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassDecoration(
        context,
        borderRadius: 20,
        borderColor: AppTheme.accent(context).withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            greeting,
            style: TextStyle(
              color: AppTheme.accent(context),
              fontSize: 12,
              letterSpacing: 3,
              fontWeight: FontWeight.w600,
            ),
          ),

          // User name
          Text(
            widget.userName,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 16),

          // Time display
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              timeStr,
              maxLines: 1,
              style: TextStyle(
                color: AppTheme.accent(context),
                fontSize: 52,
                fontWeight: FontWeight.w200,
                letterSpacing: -2,
                height: 1,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Date
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                dateStr,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppTheme.accent(context).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  yearStr,
                  style: TextStyle(
                    color: AppTheme.accent(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Decorative divider
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.accent(context).withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    return greetingForHour(_now.hour);
  }
}
