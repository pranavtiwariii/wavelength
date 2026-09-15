import 'package:flutter/material.dart';

/// MATES' visual language.
///
/// The product is about the texture of what someone loves, so the surface stays
/// dark and low-chroma and lets artwork and type carry the colour. Three accent
/// hues are reserved for the three taste domains and never used for anything
/// else — a colour always means the same thing.
class MateColors {
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

class MateType {
  /// Display numerals (match scores) are tabular so they don't jitter.
  static const score = TextStyle(
    fontSize: 46,
    fontWeight: FontWeight.w700,
    letterSpacing: -2,
    height: 1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Light counterparts. The domain accents darken slightly so they stay legible
/// on a pale ground; everything else inverts.
class MateLight {
  static const ink = Color(0xFFFBF9F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFF1EEE7);
  static const stroke = Color(0xFFE3DED4);
  static const cream = Color(0xFF15141A);
  static const muted = Color(0xFF6B6779);
  static const faint = Color(0xFF9A96A6);

  static const music = Color(0xFF109C7E);
  static const movie = Color(0xFFC9721F);
  static const book = Color(0xFF7B4FD1);
}

ThemeData buildDarkTheme() {
  final base = ThemeData.dark(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: MateColors.ink,
    colorScheme: base.colorScheme.copyWith(
      primary: MateColors.music,
      surface: MateColors.surface,
      error: MateColors.danger,
      onPrimary: MateColors.ink,
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
        .apply(bodyColor: MateColors.cream, displayColor: MateColors.cream),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MateColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MateColors.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MateColors.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MateColors.music, width: 1.5),
      ),
      hintStyle: const TextStyle(color: MateColors.faint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MateColors.cream,
        foregroundColor: MateColors.ink,
        disabledBackgroundColor: MateColors.surfaceHigh,
        disabledForegroundColor: MateColors.faint,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MateColors.cream,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: MateColors.stroke),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: MateColors.surfaceHigh,
      contentTextStyle: TextStyle(color: MateColors.cream),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: MateColors.stroke, thickness: 1, space: 1),
  );
}


/// Light theme. Same geometry and type scale as dark — only the palette moves,
/// so a screen looks like the same screen in either mode.
ThemeData buildLightTheme() {
  final base = ThemeData.light(useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: MateLight.ink,
    colorScheme: base.colorScheme.copyWith(
      primary: MateLight.music,
      surface: MateLight.surface,
      error: MateColors.danger,
      onPrimary: Colors.white,
    ),
    textTheme: base.textTheme
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 36, height: 1.08, fontWeight: FontWeight.w700, letterSpacing: -1.1),
          headlineMedium: const TextStyle(
            fontSize: 27, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -0.7),
          titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
          titleMedium: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.2),
          titleSmall: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
          bodyMedium: const TextStyle(fontSize: 15, height: 1.45),
          bodySmall: const TextStyle(fontSize: 13.5, height: 1.4),
          labelSmall: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: MateLight.cream, displayColor: MateLight.cream),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MateLight.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MateLight.stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MateLight.stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: MateLight.music, width: 1.5),
      ),
      hintStyle: const TextStyle(color: MateLight.faint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MateLight.cream,
        foregroundColor: MateLight.ink,
        disabledBackgroundColor: MateLight.surfaceHigh,
        disabledForegroundColor: MateLight.faint,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MateLight.cream,
        minimumSize: const Size.fromHeight(50),
        side: const BorderSide(color: MateLight.stroke),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: MateLight.surfaceHigh,
      contentTextStyle: TextStyle(color: MateLight.cream),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(color: MateLight.stroke, thickness: 1, space: 1),
  );
}

/// Palette lookup that follows the active brightness, so widgets don't have to
/// branch on Theme.of(context).brightness at every call site.
class Palette {
  const Palette._(this.dark);
  final bool dark;

  factory Palette.of(BuildContext context) =>
      Palette._(Theme.of(context).brightness == Brightness.dark);

  Color get ink => dark ? MateColors.ink : MateLight.ink;
  Color get surface => dark ? MateColors.surface : MateLight.surface;
  Color get surfaceHigh => dark ? MateColors.surfaceHigh : MateLight.surfaceHigh;
  Color get stroke => dark ? MateColors.stroke : MateLight.stroke;
  Color get text => dark ? MateColors.cream : MateLight.cream;
  Color get muted => dark ? MateColors.muted : MateLight.muted;
  Color get faint => dark ? MateColors.faint : MateLight.faint;
  Color get music => dark ? MateColors.music : MateLight.music;
  Color get movie => dark ? MateColors.movie : MateLight.movie;
  Color get book => dark ? MateColors.book : MateLight.book;

  Color forScore(int score) {
    if (score >= 75) return music;
    if (score >= 50) return dark ? const Color(0xFFCFE36F) : const Color(0xFF7A8F14);
    if (score >= 30) return movie;
    return faint;
  }

  Color domain(String id) => switch (id) {
        'movie' => movie,
        'book' => book,
        _ => music,
      };
}
