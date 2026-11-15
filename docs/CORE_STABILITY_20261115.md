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