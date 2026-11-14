import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/system_provider.dart';
import '../theme/app_theme.dart';

class SystemStatsWidget extends StatelessWidget {
  const SystemStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final system = context.watch<SystemProvider>();
    final stats = system.stats;

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
                Icons.memory_rounded,
                color: AppTheme.accent(context),
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                'SYSTEM',
                style: TextStyle(
                  color: AppTheme.accent(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stats.hostname,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                    fontSize: 10,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // CPU
          _StatBar(
            label: 'CPU',
            value: stats.cpuUsage / 100,
            valueText: _usageAndTempText(stats.cpuUsage, stats.cpuTemperatureC),
            color: _getColor(stats.cpuUsage / 100),
          ),

          const SizedBox(height: 12),

          // GPU
          if (stats.gpus.isEmpty)
            _StatBar(
              label: 'GPU',
              value: 0,
              valueText: _usageAndTempText(0, null),
              tooltipMessage:
                  'GPU temperature requires NVIDIA SMI, AMD ADL, or Libre/OpenHardwareMonitor.',
              color: AppTheme.neonGreen,
            )
          else
            ...stats.gpus.expand(
              (gpu) => [
                _GpuActivityBar(gpu: gpu),
                if (gpu != stats.gpus.last) const SizedBox(height: 12),
              ],
            ),

          const SizedBox(height: 12),

          // RAM
          _StatBar(
            label: 'RAM',
            value: stats.ramPercent,
            valueText:
                '${stats.ramUsage.toStringAsFixed(1)} / ${stats.ramTotal.toStringAsFixed(0)} GB',
            color: _getColor(stats.ramPercent),
          ),

          const SizedBox(height: 12),

          // Disk
          if (stats.disks.isEmpty)
            _StatBar(
              label: 'DISK',
              value: 0,
              valueText: 'R 0.0 / W 0.0 MB/s',
              color: AppTheme.neonGreen,
            )
          else
            ...stats.disks.expand(
              (disk) => [
                _DiskActivityBar(disk: disk),
                if (disk != stats.disks.last) const SizedBox(height: 12),
              ],
            ),

          const SizedBox(height: 12),

          // OS info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.computer_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                  size: 12,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stats.osName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                      fontSize: 11,
                      letterSpacing: 0.5,
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

  Color _getColor(double fraction) {
    if (fraction < 0.6) return AppTheme.neonGreen;
    if (fraction < 0.8) return const Color(0xFFFFBD2E);
    return AppTheme.neonPink;
  }

  String _usageAndTempText(double usage, double? temperatureC) {
    final usageText = '${usage.toStringAsFixed(0)}%';
    final tempText = temperatureC == null
        ? 'N/A'
        : '${temperatureC.toStringAsFixed(0)}C';
    return '$usageText / $tempText';
  }
}

class _DiskActivityBar extends StatelessWidget {
  final DiskActivity disk;

  const _DiskActivityBar({required this.disk});

  @override
  Widget build(BuildContext context) {
    final throughput = disk.readBytesPerSecond + disk.writeBytesPerSecond;
    final fraction = throughput / (100 * 1024 * 1024);
    final valueText =
        'R ${disk.readMegabytesPerSecond.toStringAsFixed(1)} / '
        'W ${disk.writeMegabytesPerSecond.toStringAsFixed(1)} MB/s';

    return _StatBar(
      label: 'DISK ${disk.label}',
      value: fraction,
      valueText: valueText,
      color: AppTheme.neonGreen,
    );
  }
}

class _GpuActivityBar extends StatelessWidget {
  final GpuActivity gpu;

  const _GpuActivityBar({required this.gpu});

  @override
  Widget build(BuildContext context) {
    final value = gpu.usagePercent / 100;
    return _StatBar(
      label: _gpuLabel(gpu.name),
      value: value,
      valueText: _usageAndTempText(gpu.usagePercent, gpu.temperatureC),
      tooltipMessage: gpu.temperatureC == null
          ? 'GPU temperature requires NVIDIA SMI, AMD ADL, or Libre/OpenHardwareMonitor.'
          : null,
      color: _getColor(value),
    );
  }

  Color _getColor(double fraction) {
    if (fraction < 0.6) return AppTheme.neonGreen;
    if (fraction < 0.8) return const Color(0xFFFFBD2E);
    return AppTheme.neonPink;
  }

  String _usageAndTempText(double usage, double? temperatureC) {
    final usageText = '${usage.toStringAsFixed(0)}%';
    final tempText = temperatureC == null
        ? 'N/A'
        : '${temperatureC.toStringAsFixed(0)}C';
    return '$usageText / $tempText';
  }

  String _gpuLabel(String name) {
    return name
        .replaceAll('AMD ', '')
        .replaceAll('(TM)', '')
        .replaceAll('Radeon RX ', 'RX ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double value;
  final String valueText;
  final String? tooltipMessage;
  final Color color;

  const _StatBar({
    required this.label,
    required this.value,
    required this.valueText,
    this.tooltipMessage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            Tooltip(
              message: tooltipMessage ?? valueText,
              waitDuration: const Duration(milliseconds: 400),
              child: Text(
                valueText,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 4,
            color: Colors.white.withValues(alpha: 0.06),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.6), color],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
