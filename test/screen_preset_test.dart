import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/reader/settings/reader_settings.dart';

void main() {
  test('屏幕预设齐全：手机/平板/长屏', () {
    expect(kScreenPresets.keys.toSet(), <String>{'手机', '平板', '长屏'});
  });

  test('每套屏幕预设都能通过校验并被 ReaderSettings 真实消费', () {
    for (final MapEntry<String, Map<String, Object?>> entry
        in kScreenPresets.entries) {
      // 校验器接受（说明键合法、类型正确）。
      final Map<String, Object?> validated =
          validatedReaderSettingsMap(Map<String, dynamic>.from(entry.value));
      final ReaderSettings settings = ReaderSettings(validated);

      // 引擎真实消费：分栏、边距、字号都来自预设，不是摆设。
      expect(settings.columns, entry.value['columns'], reason: entry.key);
      expect(settings.marginLeft, entry.value['marginLeft'], reason: entry.key);
      expect(settings.marginRight, entry.value['marginRight'], reason: entry.key);
      expect(settings.fontSize, entry.value['fontSize'], reason: entry.key);
    }
  });

  test('平板双栏、手机单栏，预设之间确实不同', () {
    final ReaderSettings phone = ReaderSettings(kScreenPresets['手机']!);
    final ReaderSettings tablet = ReaderSettings(kScreenPresets['平板']!);
    expect(phone.columns, 'one');
    expect(tablet.columns, 'two');
    expect(tablet.fontSize, greaterThan(phone.fontSize));
  });
}
