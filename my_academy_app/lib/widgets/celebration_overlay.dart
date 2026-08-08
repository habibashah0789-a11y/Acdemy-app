import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// An overlay widget that displays a beautiful, custom confetti celebration effect.
/// It uses a Flutter Ticker and a custom particle simulation for high performance
/// and offline-friendly operation.
class CelebrationOverlay extends StatefulWidget {
  final Widget child;
  const CelebrationOverlay({super.key, required this.child});

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();
  Duration _lastElapsed = Duration.zero;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    
    // Initialize particles when the widget size is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeParticles();
      _ticker.start();
    });
  }

  void _initializeParticles() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    
    // Vibrant celebration color palette
    final colors = [
      const Color(0xFFFF5252), // Red
      const Color(0xFFFFEB3B), // Yellow
      const Color(0xFF4CAF50), // Green
      const Color(0xFF2196F3), // Blue
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFFF9800), // Orange
      const Color(0xFFE91E63), // Pink
      const Color(0xFF00BCD4), // Cyan
    ];

    // Create 120 particles shooting outwards/downwards
    for (int i = 0; i < 120; i++) {
      // Choose starting point: center of screen shooting upwards, or top of screen raining down
      final isPopper = _random.nextDouble() < 0.7;
      double startX;
      double startY;
      double speedX;
      double speedY;

      if (isPopper) {
        // Shoot upwards from the bottom left and bottom right corners
        final fromLeft = _random.nextBool();
        startX = fromLeft ? 0 : size.width;
        startY = size.height * 0.85;
        // Shoot diagonally with variations
        speedX = fromLeft ? (_random.nextDouble() * 350 + 200) : -(_random.nextDouble() * 350 + 200);
        speedY = -(_random.nextDouble() * 500 + 400);
      } else {
        // Rain down from top
        startX = _random.nextDouble() * size.width;
        startY = -20 - _random.nextDouble() * 150;
        speedX = _random.nextDouble() * 120 - 60;
        speedY = _random.nextDouble() * 200 + 120;
      }

      _particles.add(
        ConfettiParticle(
          x: startX,
          y: startY,
          color: colors[_random.nextInt(colors.length)],
          size: _random.nextDouble() * 9 + 6,
          speedX: speedX,
          speedY: speedY,
          rotation: _random.nextDouble() * 2 * pi,
          rotationSpeed: _random.nextDouble() * 5 * pi - 2.5 * pi,
          shape: _random.nextBool() ? ParticleShape.rect : ParticleShape.circle,
        ),
      );
    }
    setState(() {
      _initialized = true;
    });
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }
    final dt = (elapsed.inMicroseconds - _lastElapsed.inMicroseconds) / 1000000.0;
    _lastElapsed = elapsed;

    if (dt <= 0) return;

    final size = MediaQuery.of(context).size;
    for (final p in _particles) {
      p.update(dt, size);
    }
    
    // Stop the ticker if all particles have fallen off screen
    final active = _particles.any((p) => p.y < size.height + 50);
    if (!active) {
      _ticker.stop();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_initialized)
          IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: ConfettiPainter(particles: _particles),
            ),
          ),
      ],
    );
  }
}

enum ParticleShape { rect, circle }

class ConfettiParticle {
  double x;
  double y;
  final Color color;
  final double size;
  double speedX;
  double speedY;
  double rotation;
  final double rotationSpeed;
  final ParticleShape shape;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.color,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.rotation,
    required this.rotationSpeed,
    required this.shape,
  });

  void update(double dt, Size bounds) {
    // Apply gravity
    speedY += 280 * dt; // gravity acceleration
    // Apply air resistance
    speedX *= (1 - 0.45 * dt);
    
    x += speedX * dt;
    y += speedY * dt;
    
    // Add sway
    x += sin(y / 24) * 2.0 * dt * 60; // sway proportional to frame updates
    
    rotation += rotationSpeed * dt;
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Don't paint if out of vertical bounds
      if (p.y > size.height + 50 || p.y < -100) continue;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      paint.color = p.color;

      if (p.shape == ParticleShape.rect) {
        canvas.drawRect(
          Rect.fromLTWH(-p.size / 2, -p.size / 2, p.size, p.size * 1.6),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) => true;
}
