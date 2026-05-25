import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/motion.dart';
import 'package:push_app/app/theme/typography.dart';

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.current,
    required this.goal,
    super.key,
    this.size = 248,
  });

  final int current;
  final int goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final progress = goal <= 0 ? 0.0 : (current / goal).clamp(0.0, 1.0);

    return Semantics(
      label: 'Daily pushup progress',
      value: '$current of $goal',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: progress),
        duration: PushMotion.progress,
        curve: PushMotion.defaultCurve,
        builder: (context, animatedProgress, child) {
          return SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter: _ProgressRingPainter(
                progress: animatedProgress,
                trackColor: colors.surfaceAlt,
                progressColor: colors.textPrimary,
                borderColor: colors.border,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: current.toDouble()),
                      duration: PushMotion.counter,
                      curve: PushMotion.defaultCurve,
                      builder: (context, value, child) {
                        return Text(
                          value.round().toString(),
                          style: PushTypography.monoNumber(
                            color: colors.textPrimary,
                            fontSize: 48,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '/ $goal',
                      style: PushTypography.monoNumber(
                        color: colors.textMuted,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.borderColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = math.max<double>(10, size.width * 0.048);
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas
      ..drawOval(rect, trackPaint)
      ..drawOval(rect.deflate(strokeWidth / 2), borderPaint)
      ..drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        progressPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        trackColor != oldDelegate.trackColor ||
        progressColor != oldDelegate.progressColor ||
        borderColor != oldDelegate.borderColor;
  }
}
