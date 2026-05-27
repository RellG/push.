import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/motion.dart';

class GoalCelebrationLayer extends StatefulWidget {
  const GoalCelebrationLayer({super.key});

  @override
  State<GoalCelebrationLayer> createState() => GoalCelebrationLayerState();
}

class GoalCelebrationLayerState extends State<GoalCelebrationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: PushMotion.celebration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void play() {
    unawaited(HapticFeedback.mediumImpact());
    unawaited(_controller.forward(from: 0));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final value = Curves.easeOutCubic.transform(_controller.value);
          final opacity = value < 0.7 ? 1.0 : (1 - value) / 0.3;

          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: CustomPaint(
              painter: _GoalCelebrationPainter(
                progress: value,
                colors: colors,
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _GoalCelebrationPainter extends CustomPainter {
  const _GoalCelebrationPainter({
    required this.progress,
    required this.colors,
  });

  final double progress;
  final PushColorTokens colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) {
      return;
    }

    final center = Offset(size.width / 2, size.height * 0.34);
    final radius = math.min(size.width, size.height) * 0.28;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          colors.accentStart,
          colors.accentMid,
          colors.accentEnd,
          colors.accentStart,
        ],
        transform: GradientRotation(progress * math.pi * 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      sweepPaint,
    );

    final particlePaint = Paint()..style = PaintingStyle.fill;
    for (var index = 0; index < 16; index += 1) {
      final angle = (math.pi * 2 / 16) * index;
      final distance = radius * (0.35 + progress * 0.75);
      final particleCenter =
          center +
          Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance,
          );
      final particleSize = 2 + (index % 3);
      particlePaint.color = [
        colors.accentStart,
        colors.accentMid,
        colors.accentEnd,
      ][index % 3].withValues(alpha: 1 - progress);

      canvas.drawCircle(particleCenter, particleSize.toDouble(), particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GoalCelebrationPainter oldDelegate) {
    return progress != oldDelegate.progress || colors != oldDelegate.colors;
  }
}
