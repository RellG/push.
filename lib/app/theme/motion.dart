import 'package:flutter/animation.dart';

abstract final class PushMotion {
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration pageTransition = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration counter = Duration(milliseconds: 400);
  static const Duration progress = Duration(milliseconds: 600);

  static const double pressedScale = 0.97;
}
