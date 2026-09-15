import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/settings_controller.dart';
import 'core/theme.dart';

void main() {
  runApp(const ProviderScope(child: MatesApp()));
}

class MatesApp extends ConsumerWidget {
  const MatesApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).value;

    return MaterialApp.router(
      title: 'MATES',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: settings?.themeMode ?? ThemeMode.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
