import 'package:flutter/services.dart';

import 'package:wareny/shared/bridges/native_bridge_channels.dart';

class DevicePowerSignals {
  const DevicePowerSignals({
    required this.batteryPercent,
    required this.isCharging,
    required this.thermalState,
  });

  final int batteryPercent;
  final bool isCharging;
  final String thermalState;

  factory DevicePowerSignals.fromMap(Map<Object?, Object?> map) {
    return DevicePowerSignals(
      batteryPercent: (map['batteryPercent'] as num?)?.round() ?? 0,
      isCharging: map['isCharging'] as bool? ?? false,
      thermalState: map['thermalState'] as String? ?? 'unknown',
    );
  }
}

class BatteryThermalBridge {
  const BatteryThermalBridge()
    : _channel = const MethodChannel(NativeBridgeChannels.batteryThermal);

  final MethodChannel _channel;

  static const getSignalsMethod = 'power.getSignals';

  Future<DevicePowerSignals> getSignals() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      getSignalsMethod,
    );

    return DevicePowerSignals.fromMap(result ?? const {});
  }
}
