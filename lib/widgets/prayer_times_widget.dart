import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dashboard_provider.dart';
import '../providers/prayer_times_provider.dart';
import '../theme/app_theme.dart';

class PrayerTimesWidget extends StatefulWidget {
  const PrayerTimesWidget({super.key});

  @override
  State<PrayerTimesWidget> createState() => _PrayerTimesWidgetState();
}

class _PrayerTimesWidgetState extends State<PrayerTimesWidget> {
  Timer? _timer;
  DateTime _day = DateTime.now();
  String _city = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      final now = DateTime.now();
      if (now.day != _day.day) {
        _day = now;
        _refresh();
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  void _refresh() {
    final city = context.read<DashboardProvider>().weatherCity;
    _city = city;
    context.read<PrayerTimesProvider>().fetchPrayerTimes(city: city);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final city = context.watch<DashboardProvider>().weatherCity;
    if (city != _city) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && city != _city) _refresh();
      });
    }
    final prayers = context.watch<PrayerTimesProvider>();
    final data = prayers.prayerTimes;
    final next = data == null ? null : _nextPrayer(data);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(
        context,
        borderRadius: 20,
        borderColor: AppTheme.accent(context).withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mosque_outlined,
                color: AppTheme.accent(context),
                size: 15,
              ),
              const SizedBox(width: 8),
              Text(
                'PRAYER TIMES',
                style: TextStyle(
                  color: AppTheme.accent(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh prayer times',
                onPressed: _refresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (prayers.isLoading && data == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (data == null)
            Text(
              'Prayer times unavailable.',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                fontSize: 12,
              ),
            )
          else ...[
            if (next != null)
              Text(
                'NEXT: ${next.$1.toUpperCase()} • ${next.$2}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                for (final prayer in const {
                  'Fajr': 'Fajr',
                  'Dhuhr': 'Dhuhr',
                  'Asr': 'Asr',
                  'Maghrib': 'Maghrib',
                  'Isha': 'Isha',
                }.entries)
                  _PrayerTime(
                    label: prayer.value,
                    time: data[prayer.key],
                    highlighted: next?.$1 == prayer.key,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  (String, String)? _nextPrayer(PrayerTimes data) {
    final now = TimeOfDay.now();
    for (final prayer in const ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha']) {
      final parts = data[prayer].split(':');
      final time = parts.length == 2
          ? TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 0,
              minute: int.tryParse(parts[1]) ?? 0,
            )
          : null;
      if (time != null &&
          (time.hour > now.hour ||
              time.hour == now.hour && time.minute > now.minute)) {
        return (prayer, data[prayer]);
      }
    }
    return ('Fajr', data['Fajr']);
  }
}

class _PrayerTime extends StatelessWidget {
  final String label;
  final String time;
  final bool highlighted;

  const _PrayerTime({
    required this.label,
    required this.time,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: highlighted
              ? AppTheme.neonGreen
              : Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
          fontSize: 10,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        time,
        style: TextStyle(
          color: highlighted
              ? AppTheme.neonGreen
              : Theme.of(context).colorScheme.onSurface,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
