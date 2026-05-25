import 'package:flutter/material.dart';
import 'package:push_app/app/theme/colors.dart';
import 'package:push_app/app/theme/motion.dart';
import 'package:push_app/app/theme/typography.dart';

abstract final class PushTheme {
  static ThemeData dark() {
    return _theme(Brightness.dark, PushColorTokens.dark());
  }

  static ThemeData light() {
    return _theme(Brightness.light, PushColorTokens.light());
  }

  static ThemeData _theme(Brightness brightness, PushColorTokens colors) {
    final textTheme = PushTypography.textTheme(
      colors.textPrimary,
      colors.textMuted,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: PushFonts.sans,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.textPrimary,
        onPrimary: colors.background,
        secondary: colors.textMuted,
        onSecondary: colors.background,
        error: const Color(0xFFFF453A),
        onError: colors.background,
        surface: colors.surface,
        onSurface: colors.textPrimary,
      ),
      extensions: [colors],
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.background,
        selectedItemColor: colors.textPrimary,
        unselectedItemColor: colors.textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: colors.textPrimary,
              foregroundColor: colors.background,
              disabledBackgroundColor: colors.surfaceAlt,
              disabledForegroundColor: colors.textMuted,
              elevation: 0,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ).copyWith(
              animationDuration: PushMotion.fast,
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: colors.textPrimary,
              minimumSize: const Size(48, 48),
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ).copyWith(
              animationDuration: PushMotion.fast,
            ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
