import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/sync/s3_store.dart';

void main() {
  test('ListObjectsV2 parses namespace-prefixed records and continuation', () {
    const xml = '''
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <IsTruncated>true</IsTruncated>
  <NextContinuationToken>second%2Fpage==</NextContinuationToken>
  <Contents>
    <Key>Read/books/第一章.txt</Key>
    <Size>123</Size>
    <LastModified>2026-11-15T10:20:30.000Z</LastModified>
    <ETag>&quot;abcd&quot;</ETag>
  </Contents>
  <Contents>
    <Key>Elsewhere/ignore.txt</Key>
    <Size>500</Size>
  </Contents>
</ListBucketResult>''';
    final page = S3Store.parseListObjectsV2(xml, rootPrefix: 'Read/');
    expect(page.truncated, isTrue);
    expect(page.nextToken, 'second%2Fpage==');
    expect(page.entries.length, 1);
    expect(page.entries.single.key, 'books/第一章.txt');
    expect(page.entries.single.size, 123);
    expect(page.entries.single.etag, 'abcd');
    expect(page.entries.single.modifiedAt?.toUtc().year, 2026);
  });

  test('last listing page has no continuation and ignores empty keys', () {
    const xml = '''
<ListBucketResult>
  <IsTruncated>false</IsTruncated>
  <Contents><Key></Key><Size>0</Size></Contents>
  <Contents><Key>Read/a.epub</Key><Size>1024</Size></Contents>
</ListBucketResult>''';
    final page = S3Store.parseListObjectsV2(xml, rootPrefix: 'Read/');
    expect(page.truncated, isFalse);
    expect(page.nextToken, isNull);
    expect(page.entries.map((e) => e.key), <String>['a.epub']);
  });

  test('invalid S3 list result fails closed instead of returning empty data', () {
    expect(
      () => S3Store.parseListObjectsV2('<Error><Code>AccessDenied</Code></Error>'),
      throwsFormatException,
    );
  });
}
