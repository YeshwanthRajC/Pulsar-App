import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A custom-rendered Pulsar Neutron Star Logo.
/// Represents a rotating, magnetized neutron star with relativistic radiation jets,
/// glowing stellar core, and orbiting magnetic fields.
class PulsarLogo extends StatefulWidget {
  final double size;
  final bool isAnimated;
  final Color? primaryColor;
  final Color? secondaryColor;

  const PulsarLogo({
    super.key,
    this.size = 32.0,
    this.isAnimated = true,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  State<PulsarLogo> createState() => _PulsarLogoState();
}

class _PulsarLogoState extends State<PulsarLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.isAnimated) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cyan = widget.primaryColor ?? AppColors.pulsarCyan;
    final violet = widget.secondaryColor ?? AppColors.nebulaViolet;

    if (!widget.isAnimated) {
      return CustomPaint(
        size: Size(widget.size, widget.size),
        painter: PulsarStarPainter(
          progress: 0.0,
          primaryColor: cyan,
          secondaryColor: violet,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: PulsarStarPainter(
            progress: _controller.value,
            primaryColor: cyan,
            secondaryColor: violet,
          ),
        );
      },
    );
  }
}

class PulsarStarPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;

  PulsarStarPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Outer Glow Aura
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.35),
          secondaryColor.withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, glowPaint);

    // 2. Pulsar Radiation Beams (8 rays like in the reference logo)
    final rayPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    const int rayCount = 8;
    final rotationAngle = progress * 2 * math.pi;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i * (2 * math.pi / rayCount)) + (rotationAngle * 0.2);
      final isMajor = i % 2 == 0;
      final rayLength = isMajor ? radius * 0.95 : radius * 0.62;
      final rayWidth = isMajor ? (size.width * 0.08) : (size.width * 0.05);

      final rayEnd = Offset(
        center.dx + rayLength * math.cos(angle),
        center.dy + rayLength * math.sin(angle),
      );

      final path = Path();
      // Draw diamond ray
      final perpAngle = angle + (math.pi / 2);
      final rayBase1 = Offset(
        center.dx + (rayWidth / 2) * math.cos(perpAngle),
        center.dy + (rayWidth / 2) * math.sin(perpAngle),
      );
      final rayBase2 = Offset(
        center.dx - (rayWidth / 2) * math.cos(perpAngle),
        center.dy - (rayWidth / 2) * math.sin(perpAngle),
      );

      path.moveTo(rayBase1.dx, rayBase1.dy);
      path.lineTo(rayEnd.dx, rayEnd.dy);
      path.lineTo(rayBase2.dx, rayBase2.dy);
      path.close();

      rayPaint.shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment(math.cos(angle), math.sin(angle)),
        colors: [
          Colors.white,
          isMajor ? primaryColor : secondaryColor,
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawPath(path, rayPaint);
    }

    // 3. Orbital Magnetic Rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..color = primaryColor.withValues(alpha: 0.5)
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius * 0.45, ringPaint);

    // 4. Central Neutron Star Core
    final coreGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          primaryColor,
          primaryColor.withValues(alpha: 0.2),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.3));
    canvas.drawCircle(center, radius * 0.25, coreGlow);
  }

  @override
  bool shouldRepaint(covariant PulsarStarPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
