import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/app/wareny_app.dart';
import 'package:wareeny/core/config/app_config.dart';
import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/di/service_registry.dart';

void main() {
  testWidgets('shows the camera mode shell', (WidgetTester tester) async {
    final services = ServiceRegistry.create(AppConfig.dev());

    await tester.pumpWidget(
      AppScope(services: services, child: const WareenyApp()),
    );

    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('INDOOR'), findsOneWidget);
  });

  testWidgets('switches modes with a two finger swipe', (
    WidgetTester tester,
  ) async {
    final services = ServiceRegistry.create(AppConfig.dev());

    await tester.pumpWidget(
      AppScope(services: services, child: const WareenyApp()),
    );

    final firstFinger = await tester.createGesture(pointer: 1);
    final secondFinger = await tester.createGesture(pointer: 2);

    await firstFinger.down(const Offset(300, 300));
    await secondFinger.down(const Offset(300, 360));
    await firstFinger.moveBy(const Offset(-90, 0));
    await secondFinger.moveBy(const Offset(-90, 0));
    await tester.pump();

    expect(find.text('OUTDOOR'), findsOneWidget);
    expect(find.text('SETTINGS'), findsNothing);
  });
}
