import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wareeny/presentation/settings/settings_controller.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('normalizes a raw server IP to the default HTTP port', () async {
    final settings = await SettingsController.load();

    await settings.setServerAddress('192.168.1.38');

    expect(settings.serverAddress, '192.168.1.38');
    expect(settings.resolvedServerAddress, 'http://192.168.1.38:8000');
    expect(
      settings.resolveCloudApiBaseUrl('http://localhost:8000'),
      'http://192.168.1.38:8000',
    );
  });

  test('normalizes public tunnel hostnames to HTTPS', () async {
    final settings = await SettingsController.load();

    await settings.setServerAddress('demo.trycloudflare.com');

    expect(settings.resolvedServerAddress, 'https://demo.trycloudflare.com');
  });

  test('clearing the server address falls back to the app default', () async {
    final settings = await SettingsController.load();

    await settings.setServerAddress('http://10.0.0.8:9000');
    await settings.setServerAddress('   ');

    final prefs = await SharedPreferences.getInstance();
    expect(settings.serverAddress, isNull);
    expect(settings.resolvedServerAddress, isNull);
    expect(
      settings.resolveCloudApiBaseUrl('http://localhost:8000'),
      'http://localhost:8000',
    );
    expect(prefs.containsKey('settings.serverAddress'), isFalse);
  });
}
