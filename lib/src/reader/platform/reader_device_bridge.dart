import 'package:flutter/services.dart';

/// Native Android reader-only controls. Callers gate this behind Platform.isAndroid.
/// The same Dart source still runs on Windows without a MethodChannel host.
class ReaderDeviceBridge {
  ReaderDeviceBridge._();

  static const MethodChannel _methods = MethodChannel('read/device_control');
  static const EventChannel _volumeEvents = EventChannel('read/volume_keys');

  static Stream<String> get volumeKeys => _volumeEvents
      .receiveBroadcastStream()
      .where((Object? event) => event == 'up' || event == 'down')
      .cast<String>();

  static Future<void> setVolumePaging(bool enabled) =>
      _methods.invokeMethod<void>('setVolumePaging', <String, Object>{
        'enabled': enabled,
      });

  static Future<int?> batteryLevel() =>
      _methods.invokeMethod<int>('getBatteryLevel');

  /// null restores Android's automatic brightness; other values affect only
  /// the active app window and do not change system-wide brightness settings.
  static Future<void> setWindowBrightness(double? value) =>
      _methods.invokeMethod<void>('setWindowBrightness', <String, Object>{
        'value': value == null ? -1.0 : value.clamp(0.01, 1.0).toDouble(),
      });
}
