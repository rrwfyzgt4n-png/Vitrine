# Vitrine

Vitrine is a native macOS application for browsing and enriching a physical book
collection from cover images already stored on the Mac. The cover folder remains
externally managed and read-only; Vitrine keeps bibliographic information and
personal notes in one portable, human-readable Markdown catalog.

The project targets macOS 26, uses Swift 6 and SwiftUI, and has no third-party
runtime dependencies.

## Current status

Vitrine is a V1 release candidate. The unit, integration, localization and macOS
UI-automation suites pass, including deterministic 1,000-, 2,500- and
5,000-cover checks. Hardware, iCloud, multi-Mac, visual-appearance and manual
VoiceOver acceptance remain recorded in
[V1-RELEASE-CHECKLIST.md](V1-RELEASE-CHECKLIST.md).

This repository currently produces a development-signed application. Developer
ID distribution signing and notarization are separate release activities.

## Product principles

- The cover grid is the primary interface.
- Source covers are never copied, renamed, moved, edited, recompressed, deleted
  or uploaded by Vitrine.
- The Markdown catalog is the only durable library database.
- Finder Comments and file metadata remain source-file authority; bibliographic
  fields and personal notes remain catalog authority.
- Background safety mechanisms stay quiet until a decision genuinely requires
  the user.
- Network metadata lookup is explicit and reviewable. Vitrine does not perform
  automatic or bulk enrichment.

## Implemented capabilities

- Persistent security-scoped access to the last catalog and cover folder.
- Stable volume identity matching and safe external-volume remount handling.
- JPG/JPEG, PNG, HEIC/HEIF, TIFF/TIF and WebP cover discovery.
- Dimensions, dates, file size, Finder Comments and bounded image metadata.
- Stable item identity across file renames and moves using resource identifiers,
  partial fingerprints and full hashes for ambiguity resolution.
- Conditional deletion only after a validated, complete and stable scan.
- Serialized atomic saves, disk baselines, ten rotating local backups and
  three-way external-change merging.
- Damaged-catalog recovery with selectable backups and preservation of the
  damaged source.
- Filename-derived metadata suggestions with field-by-field review.
- Manual bibliographic editing, provenance, autosave and undo.
- Explicit Open Library lookup by ISBN or confirmed title/author, with browser
  fallback.
- Catalog health, privacy-safe diagnostics and cover-information rebuilding.
- English, French and Canadian French localization.
- Keyboard navigation, Quick Look, Finder actions and macOS accessibility
  semantics.

## Build and run

Requirements:

- macOS 26
- Xcode with the macOS 26 SDK
- Apple development signing configured for local execution
- `jq` and `rg` for localization and release scripts

Build, verify the development signature and entitlements, then launch:

```sh
./script/build_and_run.sh --verify
```

Run without post-launch verification:

```sh
./script/build_and_run.sh
```

## Tests

The normal suite is non-interactive and does not open the remembered library:

```sh
./script/test.sh
```

UI automation launches Vitrine and takes keyboard focus. It requires explicit
confirmation so it is never disruptive by surprise:

```sh
./script/test_ui.sh --confirm-screen-control
```

The release-candidate harness adds scale, source-hash and clean-build evidence:

```sh
./script/release_candidate.sh
```

Add `--confirm-screen-control` to include the UI suite and signed launch.
Evidence is written beneath `.build/ReleaseCandidate/<UTC timestamp>/`.

## Repository map

```text
Vitrine/
  App/                 App entry point, commands and lifecycle hooks
  Models/              Sendable catalog, metadata and workflow values
  Services/
    Markdown/          Schema-1 parser, writer and compatibility support
    Metadata/          Filename parsing, Open Library and browser fallback
  Stores/              Main-actor application state and orchestration
  Views/               SwiftUI grid, inspector, maintenance and recovery UI
  Resources/           Asset catalog and string catalog
VitrineTests/          Unit, concurrency, integrity and scale tests
VitrineUITests/        Opt-in macOS UI automation
script/                Build, test, localization and release entry points
```

## Documentation

- [Architecture](ARCHITECTURE.md) — boundaries, data flow, persistence and
  safety invariants.
- [Development](DEVELOPMENT.md) — local workflow, testing, localization and
  release process.
- [V1 release checklist](V1-RELEASE-CHECKLIST.md) — automated evidence and
  remaining manual acceptance work.

The authoritative product specification is maintained separately from the
repository. When implementation and documentation disagree, verify behavior in
tests and reconcile both with that specification before changing a safety rule.
