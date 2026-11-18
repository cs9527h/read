import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/profile/changelog_page.dart';
import 'package:read/src/version.dart';

void main() {
  test('published changelog entries are unique, short and current', () {
    expect(readReleaseNotes, isNotEmpty);
    expect(readReleaseNotes.first.version, appVersion);
    final versions = readReleaseNotes.map((e) => e.version).toList();
    expect(versions.toSet().length, versions.length);
    for (final note in readReleaseNotes) {
      expect(note.date.length, 10);
      expect(note.date[4], '-');
      expect(note.date[7], '-');
      expect(note.changes, isNotEmpty);
      expect(note.changes.length, lessThanOrEqualTo(4));
      for (final line in note.changes) {
        expect(line.trim(), isNotEmpty);
        expect(line.length, lessThanOrEqualTo(80));
      }
    }
  });
}
