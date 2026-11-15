# Read: WebDAV reading-progress sync v1

Status: draft implementation. Do not release before CI and real-device verification.

## How to use
1. First import the SAME original ebook file on each device. Book files are not uploaded in this milestone.
2. In the bookshelf tap the cloud icon. Enter the exact HTTPS WebDAV *file* URL, username, provider-specific WebDAV application password and a separate encryption passphrase of at least 12 characters.
3. Example URL for JianGuoYun: https://dav.jianguoyun.com/dav/read-progress-v1.enc . The parent folder must already exist.
4. Run sync on the first device, then the other with identical URL and encryption passphrase.
5. If both devices independently advanced in the same book, choose the local or cloud position. Canceling must stop the transaction.

## Implementation and safety
- Identical original book files are matched by streaming SHA-256, not local ID, local path, or title.
- Plain-text ebooks transmit absolute UTF-16 text offsets. PDF uses a zero-based page index.
- Legacy text progress with no reliable character anchor is deliberately skipped.
- AES-256-GCM encryption, random nonce and salt, password-derived key; never send book metadata in plaintext.
- HTTPS WebDAV; conditional PUT using If-Match / If-None-Match rejects concurrent writes. Providers without ETags cannot safely commit updates using this transport.
- The remote store retains entries absent from the current device, never treating missing books as deletions.
- A conflict must be resolved explicitly, not using an unreliable device clock.
- Remote data is applied locally only after the remote state is validated and any necessary conditional upload succeeds.
- A repeat sync with no changes avoids unnecessary uploads.
- The shared sync baseline is stored per cloud URL, not credentials. WebDAV passwords and encryption passphrase stay in memory.
- No automatic network calls or background access.

## Not yet full Reeden parity
Still missing: automatic on-open/on-close sync, debounce, reliable offline retry queue, encrypted syncing of original book files, bookmarks, annotations, reading settings, backup/restore, Wi-Fi policy, detailed sync history, credential secure vault, migration to production SQLite, and Windows/Android multi-device acceptance tests.

## Important integration limitation
The current Windows/sync development branch uses the default chapter splitter to convert chapter-local text progress to absolute offsets. Before combining with the separate custom-chapter-rules PR #14, the adapter MUST use each book's saved chapter-rule setting to avoid incorrect positions. Do not claim compatible custom-rule synchronization until fixed.

## Required validation
Flutter analyze/tests, Android/E-Ink APK and Windows build, repeated no-op sync, wrong passphrase, corrupt remote payload, same-book SHA identity, two devices editing simultaneously, HTTP 412/409 ETag race, bad credentials, offline retry, PDF page restore, reflow/restart, and unchanged local data after failure.

Dependency chain: #4 -> #5 -> #10 -> #11 -> this PR. Independent text/UI chain #12 -> #13 -> #14; integration requires reconciliation, never blind rebase.