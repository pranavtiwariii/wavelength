import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mates_app/core/theme.dart';
import 'package:mates_app/features/auth/sign_in_screen.dart';

void main() {
  testWidgets('sign-in screen shows the value proposition and a single input', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildDarkTheme(), home: const SignInScreen()),
      ),
    );

    expect(find.text('Find people who\nget your taste.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Send me a code'), findsOneWidget);
  });

  testWidgets('sign-in does not navigate on an empty identifier', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: buildDarkTheme(), home: const SignInScreen()),
      ),
    );

    await tester.tap(find.text('Send me a code'));
    await tester.pump();

    // Still on the sign-in screen, no error, no request fired.
    expect(find.byType(SignInScreen), findsOneWidget);
  });
}
