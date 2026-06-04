import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/weather_provider.dart';
import '../providers/dashboard_provider.dart';
import '../theme/app_theme.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  Timer? _refreshTimer;
  int? _refreshMinutes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  void _refresh() {
    final dashboard = context.read<DashboardProvider>();
    context.read<WeatherProvider>().fetchWeather(
      apiKey: dashboard.weatherApiKey,
      city: dashboard.weatherCity.isNotEmpty ? dashboard.weatherCity : null,
      useMetricUnits: dashboard.weatherMetricUnits,
    );
  }

  void _ensureRefreshTimer(DashboardProvider dashboard) {
    if (_refreshMinutes == dashboard.weatherRefreshMinutes) return;
    _refreshMinutes = dashboard.weatherRefreshMinutes;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(minutes: dashboard.weatherRefreshMinutes),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final weather = context.watch<WeatherProvider>();
    final data = weather.weatherData;
    _ensureRefreshTimer(dashboard);
    final unit = dashboard.weatherMetricUnits ? '°C' : '°F';
    final windUnit = dashboard.weatherMetricUnits ? 'm/s' : 'mph';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(
        borderRadius: 20,
        borderColor: AppTheme.neonPurple.withValues(alpha: 0.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.wb_sunny_outlined,
                color: AppTheme.neonPurple,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                'WEATHER',
                style: TextStyle(
                  color: AppTheme.neonPurple,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _refresh,
                child: Icon(
                  Icons.refresh_rounded,
                  color: AppTheme.textMuted,
                  size: 16,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (weather.isLoading)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (data != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Emoji
                Text(
                  weather.iconToEmoji(data.icon),
                  style: TextStyle(fontSize: 40),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.temperature.toStringAsFixed(0),
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 42,
                            fontWeight: FontWeight.w200,
                            height: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            unit,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      data.city.toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              weather.isDemoData
                  ? '${_capitalize(data.condition)} · DEMO'
                  : _capitalize(data.condition),
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),

            const SizedBox(height: 12),

            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _WeatherStat(
                  icon: Icons.water_drop_outlined,
                  label: 'Humidity',
                  value: '${data.humidity}%',
                ),
                _WeatherStat(
                  icon: Icons.air_rounded,
                  label: 'Wind',
                  value: '${data.windSpeed.toStringAsFixed(1)} $windUnit',
                ),
                _WeatherStat(
                  icon: Icons.thermostat_outlined,
                  label: 'Feels like',
                  value: '${data.feelsLike.toStringAsFixed(0)}$unit',
                ),
              ],
            ),

            if (data.forecast.isNotEmpty) ...[
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: data.forecast
                      .asMap()
                      .entries
                      .map(
                        (entry) => Padding(
                          padding: EdgeInsets.only(
                            right: entry.key == data.forecast.length - 1
                                ? 0
                                : 8,
                          ),
                          child: _ForecastCard(
                            day: entry.value,
                            isToday: entry.key == 0,
                            iconToEmoji: weather.iconToEmoji,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ] else
            Text(
              'No weather data.\nAdd API key in Settings.',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _ForecastCard extends StatelessWidget {
  final ForecastDay day;
  final bool isToday;
  final String Function(String icon) iconToEmoji;

  const _ForecastCard({
    required this.day,
    required this.isToday,
    required this.iconToEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final label = isToday ? 'TODAY' : _shortDay(day.date);

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: isToday
            ? AppTheme.neonPurple.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.04),
        border: Border.all(
          color: isToday
              ? AppTheme.neonPurple.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isToday ? AppTheme.neonPurple : AppTheme.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(iconToEmoji(day.icon), style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            '${day.tempMax.toStringAsFixed(0)}°',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${day.tempMin.toStringAsFixed(0)}°',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _shortDay(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }
}

class _WeatherStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 14),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(label, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }
}
