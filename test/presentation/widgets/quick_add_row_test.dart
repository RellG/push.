import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/app/theme/theme.dart';
import 'package:push_app/presentation/widgets/quick_add_row.dart';

void main() {
  testWidgets('logs quick and custom set values', (tester) async {
    final logged = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: PushTheme.dark(),
        home: Scaffold(
          body: QuickAddRow(
            onAdd: (reps) async => logged.add(reps),
          ),
        ),
      ),
    );

    await tester.tap(find.text('+10'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.byType(TextField), '13');
    await tester.tap(find.text('Add'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(logged, [10, 13]);
  });
}
