import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  final bool active;

  const ParticleBackground({super.key, this.active = true});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

bool shouldRenderParticles({
  required bool lowResourceMode,
  bool hasBackgroundImage = false,
}) => !lowResourceMode && !hasBackgroundImage;

class _ParticleBackgroundState extends State<ParticleBackground> {
  static const Duration _repaintInterval = Duration(milliseconds: 66);

  final ValueNotifier<double> _phase = ValueNotifier(0);
  Timer? _timer;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Generate particles
    for (int i = 0; i < 16; i++) {
      _particles.add(
        _Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: _random.nextDouble() * 2 + 0.5,
          speed: _random.nextDouble() * 0.0002 + 0.00005,
          opacity: _random.nextDouble() * 0.4 + 0.05,
          drift: (_random.nextDouble() - 0.5) * 0.0001,
        ),
      );
    }
    if (widget.active) _startTimer();
  }

  @override
  void didUpdateWidget(ParticleBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_repaintInterval, (_) {
      _phase.value =
          (_phase.value + _repaintInterval.inMilliseconds / 30000) % 1;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ParticlePainter(
          _particles,
          _phase,
          Theme.of(context).colorScheme.primary,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _Particle {
  double x;
  double y;
  final double size;
  final double speed;
  final double opacity;
  final double drift;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.drift,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final ValueListenable<double> animation;
  final Color color;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  _ParticlePainter(this.particles, this.animation, this.color)
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final animValue = animation.value;
    for (final p in particles) {
      // Move particles upward slowly
      final y = (p.y - p.speed * animValue * 1000) % 1.0;
      final x = (p.x + p.drift * animValue * 1000) % 1.0;

      _paint.color = color.withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.particles != particles ||
      old.animation != animation ||
      old.color != color;
}
