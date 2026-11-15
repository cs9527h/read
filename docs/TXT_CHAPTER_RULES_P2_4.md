# Read TXT Chapter Rules (Draft)

This implements a Reeden-inspired, per-book chapter recognition control for the existing text reader.

- Modes: automatic/default; entire text as one chapter; restricted custom line-anchored regular expression (e.g. `^卷[0-9]+`).
- Custom patterns are checked before use. At most 120 pattern characters, line candidates no longer than 100 UTF-16 code units, at most 20,000 detected headings. Parenthesized groups, alternations, backreferences and excessive quantifiers are deliberately not supported in this first iteration.
- Every chapter range points into the **original, unmodified text**. No replacements or destructive content processing are implemented.
- Per-book settings are stored using SharedPreferences. Deleting a book clears its chapter settings; malformed saved data remains untouched rather than silently overwritten.
- When the user changes chapter rules, the reader reconstructs chapter-local progress from the original absolute character anchor. On app restart, reopening under a saved custom rule restores the old chapter-relative anchor with that same rule.
- Search and bookmark anchors still reference the source text, independently of chapter count.
- Narrow-screen reader actions are consolidated into a single toolbar menu while retaining a dedicated bookmark toggle.

## Limitations and validation

This is not a complete Reeden regex-engine clone. Advanced groups, multi-line expressions, custom global replacements and manual chapter merge/split have not been implemented. Long books are still loaded into memory (current 40 MB safety cap). Flutter analyze/tests, normal Android and E-Ink CI, and real-device restart/reflow validation are required before merge/release.

Depends on UI/bookmark PR #13 and search PR #12. Source repo public; Mate unaffected.
