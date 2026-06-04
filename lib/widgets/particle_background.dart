import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Generate particles
    for (int i = 0; i < 50; i++) {
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ParticlePainter(_particles, _controller.value),
          size: Size.infinite,
        );
      },
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
  final double animValue;

  _ParticlePainter(this.particles, this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Move particles upward slowly
      final y = (p.y - p.speed * animValue * 1000) % 1.0;
      final x = (p.x + p.drift * animValue * 1000) % 1.0;

      final paint = Paint()
        ..color = const Color(0xFF00D4FF).withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x * size.width, y * size.height), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => true;
}
