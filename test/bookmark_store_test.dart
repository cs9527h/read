import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/services/bookmark_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('absolute anchors persist, remain sorted and toggle off', () async {
    expect(await BookmarkStore.load('a'), isEmpty);
    expect(await BookmarkStore.toggle('a', 200), [200]);
    expect(await BookmarkStore.toggle('a', 30), [30, 200]);
    expect(await BookmarkStore.load('a'), [30, 200]);
    expect(await BookmarkStore.toggle('a', 200), [30]);
  });

  test('book IDs are isolated and deletion clears only its own marks', () async {
    await BookmarkStore.toggle('a', 1);
    await BookmarkStore.toggle('b', 3);
    await BookmarkStore.clearForDeletedBook('a');
    expect(await BookmarkStore.load('a'), isEmpty);
    expect(await BookmarkStore.load('b'), [3]);
  });

  test('corrupted data is not overwritten on load', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'read.bookmarks.v1.corrupt': 'not-json',
    });
    expect(await BookmarkStore.load('corrupt'), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('read.bookmarks.v1.corrupt'), 'not-json');
  });
}
