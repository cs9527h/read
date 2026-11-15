# Reeden-level synchronization parity checklist for Read

Reference: Reeden official docs https://docs.reeden.app/sync , https://docs.reeden.app/auto_sync and https://docs.reeden.app/sync_content (verified 2026-11-15). This is a feature benchmark, not a claim of source-code equivalence.

## Priority A — correctly resume reading everywhere
- [x] Stable SHA-256 original-file identity rather than local filesystem path (PR #15 staged).
- [x] Text absolute UTF-16 source anchors, with extracted-text digest checks; PDF page indices (PR #15 staged).
- [x] Explicit user choice if both devices change the position (PR #15 staged).
- [x] HTTPS WebDAV + conditional ETags + encrypted progress-only metadata, preserving absent-cloud/local entries (PR #15 staged).
- [ ] Two-device real-world acceptance tests: restart, font change, PDF, source-character offsets, offline recovery, races.
- [ ] Adapt absolute-offset conversion to each book's saved custom chapter rules from PR #14, then test.
- [ ] A short independent per-book progress channel with opt-in fast push after inactivity (Reeden describes roughly 8 seconds) and an opt-in cloud-position restore on open.
- [ ] In settings, control prompt-on-conflict, keep-local, keep-cloud *with confirmation*, never silent accidental overwrites.

## Priority B — unattended synchronization without losing data
- [ ] Store endpoint and username per device, secrets only in a platform-backed encrypted credential vault, with explicit opt-in and revoke/delete actions.
- [ ] Automatic sync enabled explicitly; triggers: app start, book open/close, network return, data modified; flexible debounce and periodic interval.
- [ ] Wi-Fi-only automatic requests, manual sync allowed by user action regardless of network type.
- [ ] Retry queue with exponential backoff and idempotent transactions; never overwrite on stale ETag.
- [ ] A persistent progress revision journal and per-device identity. Restart/reinstall recovery must not fabricate newer revisions.
- [ ] Sync history UI with status, category, action, time, error and retry, without exposing passwords or book content.
- [ ] Keep a recoverable pre-merge snapshot; restore must be transactional.

## Priority C — complete metadata
- [ ] Two-way sync for actual bookshelf entries, book status, read/unread flags, bookmarks, highlights, notes, tags, book groups and statistics.
- [ ] Tombstones and explicit trash/recovery; deleting locally is NOT silently equivalent to deleting everywhere.
- [ ] Configurable per-category settings; UI/layout options default per-device for phone vs E-Ink vs desktop.
- [ ] Sync full-text chapter-recognition options, replacements, reader state and compatible reading themes.
- [ ] Automatic migration from old SharedPreferences without destructive overwrite into the production database.

## Priority D — files, storage, disaster recovery
- [ ] Optional book-file sync using content-addressed blobs; allow metadata-only mode and avoid re-upload of unchanged files.
- [ ] Separately switch original book files, covers, fonts, dictionaries and background resources.
- [ ] Metadata and files can use different cloud folders/providers, preserving deterministic object names.
- [ ] Local and cloud backup versions, export/import, cloud/local comparisons and safe recovery flows.
- [ ] Defensive authentication, TLS, timeout, size quotas, metadata authentication and no plaintext cloud secrets.
- [ ] Test multiple devices, partial file availability, concurrent edits, wrong passwords, revoked access and cloud outages.

## Cross-platform quality gates
- [ ] Android and E-Ink release APKs with distinct package IDs, signing/upgrade tests.
- [ ] Windows portable and installer validation on a real Windows host; no assumptions from CI alone.
- [ ] E-Ink sync status legible in grayscale, minimal animations, no aggressive background activity.
- [ ] One coherent sync status dashboard for all supported platforms.

Current PR #15 is a first manual-progress-sync milestone, not parity completion. Prioritize safety and full-source matching before automatic uploads. The Read project is public; Mate is separate and should never be modified by this roadmap.