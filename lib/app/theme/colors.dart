import 'package:flutter/material.dart';

@immutable
class PushColorTokens extends ThemeExtension<PushColorTokens> {
  const PushColorTokens({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
    required this.accentStart,
    required this.accentMid,
    required this.accentEnd,
  });

  factory PushColorTokens.dark() {
    return const PushColorTokens(
      background: Color(0xFF000000),
      surface: Color(0xFF0A0A0A),
      surfaceAlt: Color(0xFF171717),
      border: Color(0xFF262626),
      textPrimary: Color(0xFFFAFAFA),
      textMuted: Color(0xFFA1A1AA),
      accentStart: Color(0xFF0070F3),
      accentMid: Color(0xFF7928CA),
      accentEnd: Color(0xFFFF0080),
    );
  }

  factory PushColorTokens.light() {
    return const PushColorTokens(
      background: Color(0xFFFFFFFF),
      surface: Color(0xFFFAFAFA),
      surfaceAlt: Color(0xFFF4F4F5),
      border: Color(0xFFE4E4E7),
      textPrimary: Color(0xFF0A0A0A),
      textMuted: Color(0xFF71717A),
      accentStart: Color(0xFF0070F3),
      accentMid: Color(0xFF7928CA),
      accentEnd: Color(0xFFFF0080),
    );
  }

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textMuted;
  final Color accentStart;
  final Color accentMid;
  final Color accentEnd;

  LinearGradient get accentGradient => LinearGradient(
    colors: [accentStart, accentMid, accentEnd],
  );

  @override
  PushColorTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textMuted,
    Color? accentStart,
    Color? accentMid,
    Color? accentEnd,
  }) {
    return PushColorTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textMuted: textMuted ?? this.textMuted,
      accentStart: accentStart ?? this.accentStart,
      accentMid: accentMid ?? this.accentMid,
      accentEnd: accentEnd ?? this.accentEnd,
    );
  }

  @override
  PushColorTokens lerp(ThemeExtension<PushColorTokens>? other, double t) {
    if (other is! PushColorTokens) {
      return this;
    }

    return PushColorTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentStart: Color.lerp(accentStart, other.accentStart, t)!,
      accentMid: Color.lerp(accentMid, other.accentMid, t)!,
      accentEnd: Color.lerp(accentEnd, other.accentEnd, t)!,
    );
  }
}

extension PushColorLookup on BuildContext {
  PushColorTokens get colors => Theme.of(this).extension<PushColorTokens>()!;
}
