import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-level preferences that belong to the device rather than the account.
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.dark});

  final ThemeMode themeMode;

  AppSettings copyWith({ThemeMode? themeMode}) =>
      AppSettings(themeMode: themeMode ?? this.themeMode);
}

class SettingsController extends AsyncNotifier<AppSettings> {
  static const _themeKey = 'mates.theme_mode';

  @override
  Future<AppSettings> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_themeKey);
      return AppSettings(themeMode: _parse(raw));
    } on Exception {
      // Preferences unavailable (private browsing, blocked storage): the app
      // still works, it just won't remember the choice.
      return const AppSettings();
    }
  }

  static ThemeMode _parse(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.system => 'system',
        ThemeMode.dark => 'dark',
      };

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData((state.value ?? const AppSettings()).copyWith(themeMode: mode));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _encode(mode));
    } on Exception {
      // Non-fatal: the choice applies for this run.
    }
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(SettingsController.new);
