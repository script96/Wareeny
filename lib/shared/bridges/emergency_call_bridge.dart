import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wareeny/shared/bridges/native_bridge_channels.dart';

class EmergencyCallBridge {
  const EmergencyCallBridge();

  static const _channel = MethodChannel(NativeBridgeChannels.emergency);
  static const _callMethod = 'call.start';

  Future<bool> call(String e164PhoneNumber) async {
    try {
      final started = await _channel.invokeMethod<bool>(_callMethod, {
        'phoneNumber': e164PhoneNumber,
      });
      if (started == true) return true;
    } on MissingPluginException {
      // iOS and unsupported platforms use the system tel handler below.
    } on PlatformException {
      // Permission denial or an unavailable call handler falls back to dialer.
    }
    return launchUrl(
      Uri(scheme: 'tel', path: e164PhoneNumber),
      mode: LaunchMode.externalApplication,
    );
  }
}
