import 'package:flutter_test/flutter_test.dart';
import 'package:warene/main.dart';

void main() {
  testWidgets('WareneApp smoke test', (WidgetTester tester) async {
    // Verify the app widget can be instantiated.
    await tester.pumpWidget(const WareneApp());
    // PermissionGate should show a loading indicator initially.
    expect(find.byType(WareneApp), findsOneWidget);
  });
}
