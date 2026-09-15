import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

void main() {
  runApp(const ProviderScope(child: WavelengthApp()));
}

class WavelengthApp extends ConsumerWidget {
  const WavelengthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Wavelength',
      debugShowCheckedModeBanner: false,
      theme: buildWaveTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
