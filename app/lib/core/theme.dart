import 'package:flutter/material.dart';

/// Wavelength's visual language.
///
/// The product is about the texture of what someone loves, so the surface stays
/// dark and low-chroma and lets artwork and type carry the colour. Three accent
/// hues are reserved for the three taste domains and never used for anything
/// else — a colour always means the same thing.
class WaveColors {
  // Warm near-black, not blue-black: artwork sits on it without turning cold.
  static const ink = Color(0xFF0E0D12);
  static const surface = Color(0xFF17161D);
  static const surfaceHigh = Color(0xFF232129);
  static const stroke = Color(0xFF2E2B36);

  static const cream = Color(0xFFF6F3EC);
  static const muted = Color(0xFF8E8A9C);
  static const faint = Color(0xFF5E5A6B);

  /// Domain accents — music / movies / books.
  static const music = Color(0xFF6FE3C4);
  static const movie = Color(0xFFF2A65A);
  static const book = Color(0xFFB08CF0);

  static const danger = Color(0xFFE5687A);
  static const like = Color(0xFF6FE3C4);
  static const pass = Color(0xFF5E5A6B);

  /// Score gradient — cool for a weak match, warm for a strong one.
  static Color forScore(int score) {
    if (score >= 75) return music;
    if (score >= 50) return const Color(0xFFCFE36F);
    if (score >= 30) return movie;
    return faint;
  }
}

class WaveType {
  /// Display numerals (match scores) are tabular so they don't jitter.
  static const score = TextStyle(
    fontSize: 46,
    fontWeight: FontWeight.w700,
    letterSpacing: -2,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildWaveTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: WaveColors.ink,
    colorScheme: base.colorScheme.copyWith(
      primary: WaveColors.music,
      surface: WaveColors.surface,
      error: WaveColors.danger,
      onPrimary: WaveColors.ink,
    ),
    // copyWith first, then apply — apply() stamps the colour onto every style,
    // so running it last is what keeps the overridden styles readable.
    textTheme: base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 36,
            height: 1.08,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.1,
          ),
          headlineMedium: const TextStyle(
            fontSize: 27,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
          titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          titleMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
          titleSmall: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
          bodyMedium: const TextStyle(fontSize: 15, height: 1.45),
          bodySmall: const TextStyle(fontSize: 13.5, height: 1.4),
          labelSmall: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: WaveColors.cream, displayColor: WaveColors.cream),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: WaveColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: WaveColors.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: WaveColors.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: WaveColors.music, width: 1.5),
      ),
      hintStyle: const TextStyle(color: WaveColors.faint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: WaveColors.cream,
        foregroundColor: WaveColors.ink,
        disabledBackgroundColor: WaveColors.surfaceHigh,
        disabledForegroundColor: WaveColors.faint,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: WaveColors.cream,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: WaveColors.stroke),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: WaveColors.surfaceHigh,
      contentTextStyle: TextStyle(color: WaveColors.cream),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: WaveColors.stroke, thickness: 1, space: 1),
  );
}
