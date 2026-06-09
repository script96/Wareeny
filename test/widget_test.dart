import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/app/wareny_app.dart';
import 'package:wareeny/core/config/app_config.dart';
import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/di/service_registry.dart';

void main() {
  testWidgets('shows the Luma intro screen', (WidgetTester tester) async {
    final services = ServiceRegistry.create(AppConfig.dev());

    await tester.pumpWidget(
      AppScope(services: services, child: const WareenyApp()),
    );

    expect(find.text('Luma'), findsOneWidget);
    expect(find.text('Your voice of sight'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('opens the main shell after starting', (
    WidgetTester tester,
  ) async {
    final services = ServiceRegistry.create(AppConfig.dev());

    await tester.pumpWidget(
      AppScope(services: services, child: const WareenyApp()),
    );

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.text('Hold to Speak'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Modes'), findsOneWidget);
    expect(find.text('Saved Items'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
