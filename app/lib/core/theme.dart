import 'package:flutter/material.dart';

/// Wavelength's visual language. The product is about taste and texture, so the
/// palette stays low-chroma and calm - "a beautiful data-poem, not a dashboard"
/// (spec 8.1). Accent colours are reserved for the three taste domains so a
/// colour always means the same thing across the app.
class WaveColors {
  static const ink = Color(0xFF14131A);
  static const surface = Color(0xFF1C1B24);
  static const surfaceHigh = Color(0xFF26242F);
  static const cream = Color(0xFFF4F1EA);
  static const muted = Color(0xFF9B97A8);

  /// Domain accents - music / movies / books, used consistently everywhere.
  static const music = Color(0xFF7DD3C0);
  static const movie = Color(0xFFE8A87C);
  static const book = Color(0xFFB8A1E3);

  static const danger = Color(0xFFE06C75);
}

ThemeData buildWaveTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: WaveColors.ink,
    colorScheme: base.colorScheme.copyWith(
      primary: WaveColors.music,
      surface: WaveColors.surface,
      error: WaveColors.danger,
    ),
    // copyWith first, then apply - apply() stamps the colour onto every style,
    // so running it last is what keeps the overridden styles readable.
    textTheme: base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 34,
            height: 1.15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.6,
          ),
          titleLarge: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600, letterSpacing: -0.2),
          bodyMedium: const TextStyle(fontSize: 15, height: 1.45),
          labelLarge: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: WaveColors.cream, displayColor: WaveColors.cream),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WaveColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: WaveColors.music, width: 1.5),
      ),
      hintStyle: const TextStyle(color: WaveColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: WaveColors.cream,
        foregroundColor: WaveColors.ink,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
