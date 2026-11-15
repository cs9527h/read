# Read Core Stability Fixes (independent of PR #17 UI)

## Scope
- Works on an independent branch based on PR #17; it does not mutate the other author's UI branch or main.
- Corrects analyze failure from an unused import in About page.
- Adds previous/next controls that cross chapter boundaries (the existing PageView only paged within a chapter). When moving backwards to a prior chapter, the saved text anchor requests its last page after repagination.
- Restricts import picker to supported ebook extensions, reports unreadable/missing local file paths rather than silently doing nothing, and validates source existence.
- Removes misleading 'cloud succeeded' icon: simply opening a book never proves WebDAV sync success.
- Preserves the black/white/grey bookshelf and avatar theme from PR #17.

## Open-source implementation boundary
- Legado (CCSSNE/legado) is GPL-3.0, while Read is MIT-licensed. We did NOT copy any Legado code into this change.
- Future Legado-derived implementation would need explicit license review, redistribution notices, source disclosure obligations, and possible relicensing rather than silent MIT reuse.
- Existing Flutter EPUB parser is currently text-only; full image/CSS/layout rendering is not implemented.

## Verification before merge
- GitHub Android + Windows CI must pass flutter analyze/test, then device test import -> chapter transitions -> restart -> offset restoration -> font-size change.
- Verify import from Android document providers that may not provide a local path; the current picker displays an actionable message and does not yet stream provider URIs.
- Verify very short/empty chapters and E-Ink next/previous controls.
- Do not merge this PR into main separately from its parent UI PR #17 without checking dependency.
## Additional verified-in-code changes
- EPUB2 and EPUB3 manifest cover recognition for embedded JPEG/PNG images only, capped at 3MB and checked by signature. Saves cover in app-owned book folder, persists optional path, and deletes it with the book. Missing/damaged/unsupported cover falls back to the grayscale placeholder. E-Ink displays a grayscale-filtered real cover. EPUB text extraction remains text-only, not a full layout engine.
- Shared ReadingAnchor utility converts custom chapter-relative UTF-16 offsets into absolute source offsets and back; WebDAV now loads each book's saved ChapterRule before upload and after download. Adds roundtrip and legacy metadata tests.
- Existing PR #17 now merged to main, this PR targets main and leaves its black-white UI unchanged.
- Added widget test for previous/next chapter navigation. Run CI and device smoke test before merging.
