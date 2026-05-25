import 'package:flutter_test/flutter_test.dart';
import 'package:push_app/main.dart';

void main() {
  testWidgets('renders the Push. wordmark', (tester) async {
    await tester.pumpWidget(const PushApp());

    expect(find.text('Push.'), findsOneWidget);
  });
}
