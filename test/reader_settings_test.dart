import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/reader/settings/reader_settings.dart';

void main() {
  test('默认值完整且可被 patch 覆盖', () {
    final ReaderSettings s = ReaderSettings();
    expect(s.fontSize, 18.0);
    expect(s.lineHeight, 1.75);
    expect(s.pageTurnMode, 'cover');
    expect(s.headerShow, isFalse);
    final ReaderSettings next = s.patch(<String, Object?>{'fontSize': 22.0});
    expect(next.fontSize, 22.0);
    expect(s.fontSize, 18.0, reason: '原对象应保持不可变');
  });

  test('diffFrom 只返回改过的键', () {
    final ReaderSettings base = ReaderSettings();
    final ReaderSettings next = base.patch(<String, Object?>{
      'fontSize': 24.0,
      'textColor': 0xFF112233,
    });
    final Map<String, Object?> diff = next.diffFrom(base);
    expect(diff.keys.toSet(), <String>{'fontSize', 'textColor'});
    expect(ReaderSettings(base.toJson()).diffFrom(base), isEmpty);
  });

  test('JSON 往返保持所有设置', () {
    final ReaderSettings source = ReaderSettings().patch(<String, Object?>{
      'themeId': 'sepia',
      'fontFamily': 'user-1',
      'headerShow': true,
      'tapCenter': 'none',
      'indentMode': 'em',
      'boldPattern': r'^【.+】$',
    });
    final ReaderSettings restored =
        ReaderSettings.fromJsonString(source.toJsonString());
    expect(restored, source);
    expect(restored.themeId, 'sepia');
    expect(restored.headerShow, isTrue);
    expect(restored.indentMode, 'em');
  });

  test('损坏的 JSON 抛出可读错误', () {
    expect(
      () => ReaderSettings.fromJsonString('[]'),
      throwsA(isA<FormatException>()),
    );
  });
}
