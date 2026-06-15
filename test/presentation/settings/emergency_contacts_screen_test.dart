import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wareeny/presentation/settings/emergency_contacts_screen.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('contact dialog closes without using disposed controllers', (
    WidgetTester tester,
  ) async {
    final settings = await SettingsController.load();

    await tester.pumpWidget(
      MaterialApp(home: EmergencyContactsScreen(settings: settings)),
    );

    await tester.tap(find.text('Add Contact'));
    await tester.pumpAndSettle();
    expect(find.text('Emergency Contact'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Emergency Contact'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location sharing switch persists the user choice', (
    WidgetTester tester,
  ) async {
    final settings = await SettingsController.load();

    await tester.pumpWidget(
      MaterialApp(home: EmergencyContactsScreen(settings: settings)),
    );

    expect(settings.shareLocationWithEmergencyContacts, isTrue);
    expect(find.text('Share my location'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(settings.shareLocationWithEmergencyContacts, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('settings.shareEmergencyLocation'), isFalse);
  });
}
