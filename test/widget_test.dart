import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kingdom/main.dart';

void main() {
  testWidgets('Kingdom App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KingdomApp()));
    expect(find.byType(KingdomApp), findsOneWidget);
  });
}
