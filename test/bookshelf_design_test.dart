import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/bookshelf/bookshelf_page.dart';
import 'package:read/src/model/book.dart';
import 'package:read/src/services/library_store.dart';
import 'package:read/src/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('The bookshelf shows real books and filters by title', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await LibraryStore.instance.init();
    final store = LibraryStore.instance;
    store.books
      ..clear()
      ..addAll(<Book>[
        Book(id: 'test-a', title: '春天的故事', author: '作者甲', content: '第一章'),
        Book(id: 'test-b', title: '冬天的日记', author: '作者乙', content: '第二章'),
      ]);

    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: const BookshelfPage(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('我的书架'), findsOneWidget);
    expect(find.text('春天的故事'), findsWidgets);
    expect(find.text('冬天的日记'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '春天');
    await tester.pumpAndSettle();
    expect(find.text('春天的故事'), findsWidgets);
    expect(find.text('冬天的日记'), findsNothing);

    await tester.enterText(find.byType(TextField), '没有这本书');
    await tester.pumpAndSettle();
    expect(find.text('没有找到这本书'), findsOneWidget);

    store.books.clear();
  });
}
