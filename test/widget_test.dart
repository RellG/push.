import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders the Push. wordmark', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PushApp());
    await tester.pumpAndSettle();

    expect(find.text('Push.'), findsOneWidget);
  });
}
