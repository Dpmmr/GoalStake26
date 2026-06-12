import 'package:flutter_test/flutter_test.dart';
import 'package:goalstake26/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GoalStakeApp());
    expect(find.text('GOALSTAKE 26'), findsOneWidget);
  });
}
