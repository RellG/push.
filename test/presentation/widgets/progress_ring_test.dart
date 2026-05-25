import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/app/theme/theme.dart';
import 'package:push_app/presentation/widgets/progress_ring.dart';

void main() {
  testWidgets('shows current and goal values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: PushTheme.dark(),
        home: const Scaffold(
          body: ProgressRing(current: 40, goal: 100),
        ),
      ),
    );

    expect(find.text('40'), findsOneWidget);
    expect(find.text('/ 100'), findsOneWidget);
  });
}
