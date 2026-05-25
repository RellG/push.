import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/app/theme/theme.dart';
import 'package:push_app/features/onboarding/onboarding_screen.dart';
import 'package:push_app/providers/app_providers.dart';

void main() {
  testWidgets('captures profile fields and completes onboarding', (
    tester,
  ) async {
    var completed = false;
    String? savedName;
    int? savedGoal;
    String? savedThemeMode;
    Future<void> completeOnboarding({
      required String name,
      required int currentGoal,
      required String themeMode,
    }) async {
      savedName = name;
      savedGoal = currentGoal;
      savedThemeMode = themeMode;
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          completeOnboardingProvider.overrideWithValue(completeOnboarding),
        ],
        child: MaterialApp(
          theme: PushTheme.dark(),
          home: OnboardingScreen(
            onCompleted: () => completed = true,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).first, 'Rell');
    await tester.enterText(find.byType(TextFormField).last, '125');
    await tester.tap(find.text('Light'));
    await tester.ensureVisible(find.text('Continue'));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(savedName, 'Rell');
    expect(savedGoal, 125);
    expect(savedThemeMode, 'light');
    expect(completed, isTrue);
  });
}
