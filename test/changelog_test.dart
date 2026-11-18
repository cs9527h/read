import 'package:flutter_test/flutter_test.dart';
import 'package:read/src/profile/changelog_page.dart';

void main() {
  test('published changelog versions have distinct readable entries', () {
    expect(readReleaseNotes, isNotEmpty);
    final versions = readReleaseNotes.map((e) => e.version).toList();
    expect(versions.toSet().length, versions.length);
    for (final note in readReleaseNotes) {
      expect(note.date, matches(RegExp(r'^\d{4}-\d{2}-\d{2})));
      expect(note.changes, isNotEmpty);
      expect(note.changes.length, lessThanOrEqualTo(4));
      for (final line in note.changes) {
        expect(line.trim(), isNotEmpty);
        expect(line.length, lessThanOrEqualTo(80));
      }
    }
  });
}
)));
      expect(note.changes, isNotEmpty);
      expect(note.changes.length, lessThanOrEqualTo(4));
      for (final line in note.changes) {
        expect(line.trim(), isNotEmpty);
        expect(line.length, lessThanOrEqualTo(80));
      }
    }
  });
}
