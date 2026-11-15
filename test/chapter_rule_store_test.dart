import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/chapter_rule_store.dart';
import 'package:read/src/services/chapter_splitter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('default automatic and per-book custom settings persist', () async {
    expect((await ChapterRuleStore.load('a')).mode, ChapterRuleMode.automatic);
    await ChapterRuleStore.save('a', const ChapterRule.custom(r'^卷[0-9]+'));
    final saved = await ChapterRuleStore.load('a');
    expect(saved.mode, ChapterRuleMode.custom);
    expect(saved.pattern, r'^卷[0-9]+');
    expect((await ChapterRuleStore.load('b')).mode, ChapterRuleMode.automatic);
    await ChapterRuleStore.save('a', const ChapterRule.none());
    expect((await ChapterRuleStore.load('a')).mode, ChapterRuleMode.none);
  });

  test('malformed stored pattern is not overwritten', () async {
    const bad = '{"mode":"custom","pattern":"(.*)+"}';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'read.chapter-rule.v1.a': bad,
    });
    expect((await ChapterRuleStore.load('a')).mode, ChapterRuleMode.automatic);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('read.chapter-rule.v1.a'), bad);
  });

  test('delete clears only the selected book rules', () async {
    await ChapterRuleStore.save('a', const ChapterRule.none());
    await ChapterRuleStore.save('b', const ChapterRule.none());
    await ChapterRuleStore.clearForDeletedBook('a');
    expect((await ChapterRuleStore.load('a')).mode, ChapterRuleMode.automatic);
    expect((await ChapterRuleStore.load('b')).mode, ChapterRuleMode.none);
  });
}
