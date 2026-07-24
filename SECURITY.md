# Security and privacy

Vitrine is pre-release software that works with user-selected book-cover files and a user-selected Markdown catalog. Its design prioritizes least privilege, explicit network activity, recoverability and user ownership of durable data.

## Security invariants

- Vitrine runs inside the macOS App Sandbox and restores user-approved locations through security-scoped bookmarks.
- The external cover tree is treated as read-only by the production architecture. Vitrine does not copy, rename, move, modify, recompress, delete or upload source covers.
- The Markdown catalog is the only durable library database. Writes pass through one save coordinator, use coordinated atomic replacement and retain rotating backups.
- Missing folders, incomplete enumeration, unstable files, identity mismatches and stale scan results suppress automatic catalog removal.
- External catalog changes are compared with a known disk baseline and reconciled through a three-way merge.
- Damaged catalog bytes are preserved before recovery or restoration is attempted.
- Network metadata lookup is explicit, selected-item only and reviewable before any value is committed.
- Exported diagnostics omit file paths, identifiers, book metadata, personal notes, cover contents, fingerprints and checksums.

## Important boundaries

- Source-cover immutability is an application invariant backed by architecture and tests; it is not enforced by a separate read-only filesystem entitlement. The sandbox also needs user-selected write access for the catalog file.
- A user-initiated Open Library query sends the entered ISBN or confirmed title/author query to Open Library. Browser fallback opens the selected search provider in the user's browser.
- iCloud Drive transport, account security and at-rest protection are provided by Apple rather than Vitrine.
- The current build is development signed. Developer ID signing, hardened-runtime distribution and notarization have not yet been completed.
- Independent backups remain appropriate for irreplaceable catalog and cover data while Vitrine is a release candidate.

## Reporting a vulnerability

Use GitHub private vulnerability reporting when it is enabled for this repository. Do not place sensitive file paths, real catalogs, personal notes or private cover images in a public issue.

Include:

- the affected commit or build;
- the macOS version;
- the smallest reproducible sequence;
- the expected and observed security boundary;
- sanitized logs or diagnostics, when relevant.

Ordinary defects that do not expose private data may be reported through the repository issue tracker.
