# Developing Vitrine

## Prerequisites

- macOS 26
- Xcode with the macOS 26 SDK and Swift 6
- an Apple Development identity for launching the sandboxed app
- command-line tools: `git`, `jq` and `rg`

Vitrine has no third-party package dependencies. Open
`Vitrine.xcodeproj` when working in Xcode, or use the scripts below from the
repository root.

## Daily workflow

1. Read [ARCHITECTURE.md](ARCHITECTURE.md) before changing persistence,
   reconciliation, recovery or shared metadata models.
2. Keep source-cover access read-only. Tests may create their own temporary
   fixture images; production code may not alter the selected cover tree.
3. Make the smallest change within the existing model/service/store/view
   boundaries.
4. Add focused tests for the changed behavior.
5. Run the non-interactive suite.
6. Run UI automation only in an agreed interruption window.
7. Use the release-candidate harness before declaring a release build.

Generated build data belongs under `.build/` or Xcode Derived Data and must not
be committed. User-specific Xcode state and `.DS_Store` are ignored.

## Build and run

The project-local entry point stops any existing Vitrine process, builds the
Debug app, verifies its signature and required entitlements, then launches it:

```sh
./script/build_and_run.sh
```

Useful modes:

```sh
./script/build_and_run.sh --verify    # launch and confirm the process exists
./script/build_and_run.sh --debug     # launch under LLDB
./script/build_and_run.sh --logs      # stream process logs
./script/build_and_run.sh --telemetry # stream Vitrine subsystem logs
```

Override the normal Derived Data location when isolation is useful:

```sh
VITRINE_DERIVED_DATA_PATH=/path/to/derived-data \
  ./script/build_and_run.sh --verify
```

The data-driven v2.1 filename parser is the production default. The reviewed
legacy engine remains a compatibility oracle for differential tests. In a Debug
scheme, add `--filename-parser-legacy` to force that comparison path, or
`--filename-parser-v2` to state the production selection explicitly. These
flags select the engine before parsing; they do not alter source filenames or
catalog metadata. New production behavior belongs in the versioned JSON rule
package and sanitized golden fixtures, not in new exact-title branches.

The script validates these sandbox entitlements:

- App Sandbox;
- user-selected read/write access;
- app-scoped security bookmarks;
- outbound network client access.

This is development-signing verification. Developer ID signing, hardened
runtime packaging and notarization are separate distribution steps.

## Test layers

### Non-interactive suite

```sh
./script/test.sh
```

This runs the localization audit and the complete `VitrineTests` target. The
test host is prevented from reopening or refreshing a remembered user library.
It is the default validation command for ordinary changes.

Coverage includes:

- Markdown parsing, writing, preservation and compatibility;
- scanner formats, metadata and instability handling;
- fingerprint reconciliation, rename/move identity and deletion gates;
- serialized saves, disk baselines, backup rotation and restore;
- external-change merging and conflict resolution;
- damaged-catalog recovery;
- filename suggestion integration and Open Library decoding;
- search, health reports, statistics, diagnostics and localization;
- thumbnail cache and cancellation behavior.

### UI automation

UI tests launch Vitrine and take keyboard focus. The wrapper refuses to run
without explicit confirmation:

```sh
./script/test_ui.sh --confirm-screen-control
```

The suite uses deterministic launch fixtures and does not open the real last
library. It covers welcome actions, metadata-only browsing, keyboard navigation,
inspector disclosure persistence, missing-folder status, recovery/conflict entry
points, accessibility semantics, single-window enforcement, unsupported-schema
read-only behavior and the 5,000-item grid.

Native file panels, removable media, iCloud transport, two-Mac conflicts,
browser fallback and hands-on VoiceOver remain manual acceptance activities.

### Release-candidate verification

Run headless release verification with:

```sh
./script/release_candidate.sh
```

This performs the non-interactive suite and synthetic 1,000-, 2,500- and
5,000-cover tests. The scale suite records catalog rendering, parse/model time,
refresh duration, grid-model construction, peak resident memory, cancellation,
thumbnail cache behavior and before/after SHA-256 source manifests.

Include the screen-controlling UI suite and clean signed launch only when the
interruption is acceptable:

```sh
./script/release_candidate.sh --confirm-screen-control
```

Each run writes logs and a summary to
`.build/ReleaseCandidate/<UTC timestamp>/`. The maintained acceptance record is
[V1-RELEASE-CHECKLIST.md](V1-RELEASE-CHECKLIST.md).

## Localization process

User-facing text lives in `Vitrine/Resources/Localizable.xcstrings` with English,
French and Canadian French coverage.

Run the extraction audit directly with:

```sh
./script/audit_localizations.sh
```

The script extracts SwiftUI keys from production sources, normalizes generated
placeholder forms, fails if a key is absent from the string catalog, and requires
both `fr` and `fr-CA` for every entry. It does not prove translation quality; new
or changed copy still requires human review in all three locales.

Production localization keys must be statically extractable. Enum-backed UI
labels use exhaustive `switch` mappings whose branches call `L10n.text` with
string literals; runtime construction through `String.LocalizationValue` is not
permitted. This makes a new enum case a compiler error until its label is mapped,
and the audit rejects code that could bypass extraction. `LocalizationTests`
independently checks locale coverage and all registered enum labels.

Do not assemble sentences from translated fragments when grammar or number can
change. Prefer complete localized strings and existing `L10n` helpers.

## Project Gutenberg reference

The About window comparison is historical, not a live network lookup. Its
count, capture month/year, and source URL are maintained together in
`LibraryStatistics.gutenbergReference`. When updating it:

1. verify the count at the recorded source URL;
2. update the count and capture month/year in the same commit;
3. update the localized About-window reference sentence;
4. update `LibraryStatisticsTests` and record the change in the release
   checklist.

## Architecture and ownership

Production code follows these boundaries:

- `App/`: scene lifecycle and command routing;
- `Models/`: immutable or value-semantic workflow and persistence data;
- `Services/`: file, metadata, network, reconciliation and platform operations;
- `Stores/`: main-actor state mutation and workflow orchestration;
- `Views/`: SwiftUI presentation with no direct catalog-file writes;
- `Support/`: formatting, localization, logging, escaping and normalization.

`CatalogStore` is the only main-actor catalog mutator.
`CatalogSaveCoordinator` is the only active-catalog writer. New code must not
write the live Markdown file or source-cover metadata around those boundaries.

### Shared metadata integration surfaces

Changes to any of these require cross-workstream review:

- `BibliographicMetadata`
- `CatalogItem`
- `FilenameMetadataSuggestion`
- `MetadataCandidate`
- Markdown field names
- `CatalogMergeField`
- searchable metadata assembly

Every newly accepted field must round-trip through Markdown, participate in
three-way merging and undo, remain searchable where appropriate, and include
editor/inspector, localization and accessibility coverage. Prefer adapters such
as `FilenameMetadataSuggestionAdapter` over moving parser rules into
`CatalogStore`.

## Persistence change checklist

Before changing catalog or access persistence, verify:

1. old schema-1 catalogs still parse;
2. new data survives write/read/relaunch;
3. unknown front matter, unmanaged prose and unrecognized record lines survive;
4. unsupported future schemas remain read-only;
5. three-way merge includes the field;
6. undo restores the complete logical edit;
7. save failures do not advance the disk baseline;
8. a backup exists before destructive catalog replacement or removal;
9. recovery preserves damaged bytes;
10. no source-cover operation was introduced.

## Scanner and reconciliation change checklist

Deletion behavior is the highest-risk scanner surface. A record may be removed
automatically only after folder validation, complete enumeration, stability
checks and identity/fingerprint matching. A missing folder, wrong folder,
enumeration error or unstable file must suppress removals.

When changing matching logic, cover at least:

- same-path refresh;
- rename and move with UUID preservation;
- duplicate partial fingerprints and full-hash disambiguation;
- unrelated same-name external volumes;
- incomplete and cancelled scans;
- stale reconciliation diffs after an intervening user edit.

## Git and review process

- Work on a topic branch rather than directly on `main`.
- Keep generated artifacts and personal library data out of commits.
- Review `git status` and `git diff --check` before staging.
- Run `./script/test.sh` before pushing.
- Run UI automation only after warning the person using the Mac.
- Summarize safety-sensitive behavior and test evidence in the pull request.
- Use a draft pull request while manual acceptance rows remain open.

The release gate closes only when the automated suites pass, the signed app
launches cleanly, source-cover hashes remain unchanged, and every remaining
manual row in the release checklist has a dated pass record.
