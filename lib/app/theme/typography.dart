import 'package:flutter/material.dart';

abstract final class PushFonts {
  static const sans = 'Geist';
  static const mono = 'GeistMono';
}

abstract final class PushTypography {
  static TextTheme textTheme(Color textPrimary, Color textMuted) {
    return TextTheme(
      displaySmall: _sans(
        color: textPrimary,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineMedium: _sans(
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: _sans(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: _sans(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      labelMedium: _sans(
        color: textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static TextStyle monoNumber({
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return TextStyle(
      color: color,
      fontFamily: PushFonts.mono,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0,
    );
  }

  static TextStyle monoCode({
    required Color color,
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return TextStyle(
      color: color,
      fontFamily: PushFonts.mono,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: 0,
      height: 1.4,
    );
  }

  static TextStyle _sans({
    required Color color,
    required double fontSize,
    required FontWeight fontWeight,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      color: color,
      fontFamily: PushFonts.sans,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
  }
}
