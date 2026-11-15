import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/reader/platform/reader_device_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('read/device_control');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getBatteryLevel') return 73;
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('hardware paging is explicitly enabled and disabled', () async {
    await ReaderDeviceBridge.setVolumePaging(true);
    await ReaderDeviceBridge.setVolumePaging(false);
    expect(calls.map((call) => call.method),
        <String>['setVolumePaging', 'setVolumePaging']);
    expect((calls[0].arguments as Map)['enabled'], true);
    expect((calls[1].arguments as Map)['enabled'], false);
  });

  test('battery level is read from Android channel', () async {
    expect(await ReaderDeviceBridge.batteryLevel(), 73);
    expect(calls.single.method, 'getBatteryLevel');
  });

  test('window brightness never changes global device settings', () async {
    await ReaderDeviceBridge.setWindowBrightness(0.37);
    await ReaderDeviceBridge.setWindowBrightness(null);
    expect(calls.map((call) => call.method),
        <String>['setWindowBrightness', 'setWindowBrightness']);
    expect((calls[0].arguments as Map)['value'], 0.37);
    expect((calls[1].arguments as Map)['value'], -1.0);
  });
}
