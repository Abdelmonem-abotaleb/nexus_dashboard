import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  final bool active;

  const ParticleBackground({super.key, this.active = true});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

bool shouldRenderParticles({required bool lowResourceMode}) => !lowResourceMode;

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  static const Duration _repaintInterval = Duration(milliseconds: 33);

  late AnimationController _controller;
  late _ThrottledParticleRepaint _repaint;
  late _ParticlePainter _painter;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    if (widget.active) {
      _controller.repeat();
    }
    _repaint = _ThrottledParticleRepaint(_controller, _repaintInterval);

    // Generate particles
    for (int i = 0; i < 32; i++) {
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
    _painter = _ParticlePainter(_particles, _controller, _repaint);
  }

  @override
  void didUpdateWidget(ParticleBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _repaint.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _painter, size: Size.infinite),
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

class _ThrottledParticleRepaint extends ChangeNotifier {
  final AnimationController animation;
  final Duration interval;
  Duration? _lastElapsed;

  _ThrottledParticleRepaint(this.animation, this.interval) {
    animation.addListener(_handleTick);
  }

  void _handleTick() {
    final elapsed = animation.lastElapsedDuration;
    if (elapsed == null) {
      notifyListeners();
      return;
    }
    final lastElapsed = _lastElapsed;
    if (lastElapsed != null) {
      final delta = elapsed - lastElapsed;
      if (delta >= Duration.zero && delta < interval) return;
    }
    _lastElapsed = elapsed;
    notifyListeners();
  }

  @override
  void dispose() {
    animation.removeListener(_handleTick);
    super.dispose();
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final Animation<double> animation;
  final Paint _paint = Paint()..style = PaintingStyle.fill;

  _ParticlePainter(
    this.particles,
    this.animation,
    Listenable repaint,
  ) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final animValue = animation.value;
    for (final p in particles) {
      // Move particles upward slowly
      final y = (p.y - p.speed * animValue * 1000) % 1.0;
      final x = (p.x + p.drift * animValue * 1000) % 1.0;

      _paint.color = const Color(0xFF00D4FF).withValues(alpha: p.opacity);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        p.size,
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.particles != particles || old.animation != animation;
}
