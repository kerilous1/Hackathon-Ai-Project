import 'package:flutter_test/flutter_test.dart';
import 'package:ui/main.dart';

void main() {
  testWidgets('App launches and shows PediaCare branding', (WidgetTester tester) async {
    await tester.pumpWidget(const PediaCareApp());
    await tester.pump();

    // Verify the app title or logo is present
    expect(find.textContaining('PediaCare.AI'), findsOneWidget);
  });
}
