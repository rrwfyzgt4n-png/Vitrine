# Vitrine 1.1 remediation register

This register adopts the supplied Vitrine 1.1 remediation package as the
engineering contract for V1.1. The package named commit
`4169d9d64c615da5836a8a58e438d99eb13b7788`, which is not present in this
repository. Findings were therefore rechecked against the live branch.

## Live baseline

- Branch: `codex/v1-completion`
- V1 completion baseline: `03a49f1dd21aa28d75b19e8b2b1eece2c07d9d14`
- UI and metadata-lookup refinement baseline:
  `7cdff1e` (`Refine library and metadata lookup interfaces`)
- Headless baseline verification: `script/test.sh` passed on 2026-07-22.
- Existing 1,000/2,500/5,000-cover measurements are retained as the provisional
  pre-remediation benchmark and must be rerun before closing Phase 5.
- Machine-local corpus tests are optional evidence only and are not portable CI
  coverage.

## Release policy

V11-001 through V11-005 are mandatory release gates. V11-006 through V11-009
must be fixed and verified or explicitly deferred with a written no-data-loss
rationale. V11-023 and V11-025 require measurements before optimization.

The release checklist must not claim zero critical safety failures while any
mandatory safety gate is open or lacks focused regression coverage.

## Phase register

| Phase | Items | Status | Gate |
| --- | --- | --- | --- |
| 0 — Baseline and evidence | Package adoption, truthful checklist, portable test boundary | Complete | A clean, reproducible baseline tied to a real commit |
| 1 — Transactional saves | V11-001, V11-002, V11-017 | Verified 2026-07-22 | No silent loss on quit or save failure; one ordered file-event buffer |
| 2 — Reconciliation safety | V11-003, V11-004, V11-011, V11-015 | Verified 2026-07-22 | No ambiguous or explicitly retained record is automatically deleted |
| 3 — Filesystem and overwrite recovery | V11-005, V11-006, V11-026 | Verified 2026-07-22 | All cover access is contained and overwritten catalogs remain recoverable |
| 4 — Conflict, schema, localization | V11-007, V11-008, V11-018, V11-020, V11-024 | Verified 2026-07-22 | Every metadata surface round-trips and is localized |
| 5 — Measured scale | V11-009, V11-014, V11-023, V11-025 | Verified 2026-07-25 | Exact behavior with measured improvement at 5,000 records |
| 6 — Product truth and maintainability | V11-010, V11-012, V11-013, V11-016, V11-019 | Verified 2026-07-26 | Stable behavior without a high-risk speculative rewrite |
| 7 — Release verification | V11-021, V11-022 and all 24 remediation vectors | Automated verified 2026-07-26; manual pending | Complete automated and manual acceptance evidence |

## Phase 1 invariants

1. The newest queued snapshot for a catalog URL is the snapshot written.
2. A termination flush bypasses metadata debounce and waits for disk completion.
3. A flush failure cancels termination and leaves Vitrine open.
4. In-memory catalog state and undo are committed only after save success.
5. Concurrent logical edits build on pending edits and receive the exact snapshot
   committed by the coalesced save.
6. File-presenter events have one ordered buffer; active catalog operations delay
   consumption instead of dropping events.

## Phase 1 verification

Focused coverage verifies flush-before-quit behavior, newest-snapshot
coalescing, explicit-save wakeup, in-flight successors, flush failure,
transactional catalog/undo behavior, concurrent book edits, repeated quit
requests, termination timeout, and ordered file-presenter bursts.

`script/test.sh` passed after the implementation on 2026-07-22. This closes
V11-001, V11-002, and V11-017; it does not close the remaining mandatory V1.1
safety gates.

## Phase 2 verification

Fingerprint reconciliation now operates on complete clusters. Unique full
hashes resolve first; every unresolved member receives a stable, relevant
candidate set; sources are consumed once at cluster level; and unresolved
members never fall through to automatic removal. Operation and candidate order
is deterministic.

An explicit `.metadataOnly` decision survives complete warning-free scans while
the cover remains absent. An exact or uniquely identified returning source
restores `.available`; explicit catalog deletion remains available. The
inspector and grid accessibility descriptions distinguish this state from
temporary unavailability.

`baseCatalogUpdatedAt` is an enforced whole-diff baseline. A catalog change
during scanning leaves the current catalog untouched and asks for another
refresh rather than applying an obsolete diff.

Focused cluster, retention, stale-diff, deletion, and localization coverage and
the complete `script/test.sh` suite passed on 2026-07-22. This closes V11-003,
V11-004, V11-011, and V11-015.

## Phase 3 verification

`CoverPathResolver` is now the single boundary used when a catalog cover path
becomes a filesystem URL. It standardizes the source root and each resolved path
component, resolves intermediate symlinks, requires a strict descendant, and
rejects absolute paths, traversal, malformed separators, root-equal paths, and
symlink escapes. Thumbnail, Open, Quick Look, and Finder reveal all use this
resolver; interactive actions report a localized error instead of opening an
unsafe URL.

The save coordinator now identifies existing destination bytes before replacing
them. Matching catalogs retain normal backup behavior; a different catalog is
replaced only through an explicitly authorized Create/Export flow and its bytes
are backed up under the old catalog UUID. Malformed or unrelated bytes require
the same authorization and are preserved verbatim under
`Vitrine/Orphaned Catalog Replacements/`. A rejected or cancelled replacement
does not change the destination. Show Local Backups reveals the complete recovery
archive rather than only the active catalog's newest backup, keeping replaced
identities and unrecognized replacements discoverable.

The architecture now records the exact `preserveExistingCoverAccess` invariant,
including catalog relocation, explicit source replacement, stale bookmark
refresh, and stable-volume remount rules. Focused containment, symlink,
same/different identity, malformed destination, raw preservation, cancellation,
and bookmark tests pass. The complete non-interactive `script/test.sh` suite
passed on 2026-07-22. This closes V11-005, V11-006, and V11-026.

## Phase 4 verification

Merge-conflict values now pass through `CatalogMergeValueFormatter`. Optional
nil, empty values, contributors and localized roles, physical attributes,
pagination, provenance, availability, booleans, dates, source records, and book
records have explicit display rules; supported fields no longer fall through to
Swift debug descriptions. The formatter shares contributor and physical-detail
conventions with the inspector. `CatalogMergeField.label` is an exhaustive static
mapping, so adding a case requires a localized label before the project compiles.

Runtime-computed localization keys are prohibited. The localization audit now
rejects those constructions and requires both French and Canadian French for
every catalog entry. The convention and its compiler/audit boundary are recorded
in `DEVELOPMENT.md`.

`BibliographicMetadataField` inventories every stored bibliographic property and
maps it exhaustively to one Markdown key and one merge field. The parser consumes
that key registry. Tests compare it with the reflected model, the complete merge
surface, a fully populated Markdown round trip, search integration, and legacy
schema-1 compatibility. Duplicate record IDs cannot replace the first accepted
record, and deletion conflict choices preserve independent edits and unrelated
additions.

The `metadata-confirmed` title branch is retained deliberately: provenance-free
schema-1 title records make it reachable. Both that compatibility path and the
provenance-only path now have invariant tests. Finder and personal-note line
endings use one normalization helper while retaining distinct block-quote and
multiline rendering and byte-equivalent schema output. Focused tests and the
complete non-interactive suite passed on 2026-07-22. This closes V11-007,
V11-008, V11-018, V11-020, and V11-024.

## Phase 5 verification

Search and sort normalization now lives in a transient, main-actor-owned index
that is invalidated on every catalog snapshot change. It computes only the
active sort key and adds normalized search text lazily, preserving the exact
search fields and sort behavior without penalizing the initial grid. Markdown
rendering computes each normalized title once per item.

The filename parser reuses immutable regular expressions through a bounded,
locked repository. Concurrent parser stress preserves complete suggestion
values, evidence, confidence, and source spans. Partial fingerprints check task
cancellation before and between filesystem reads. Reconciliation applies its
ordered operation stream through indexed IDs and tombstoned records, preserving
conditional revisions, duplicate-path behavior, additions, removals, and
ambiguity while avoiding repeated full-array searches.

On the same x86_64 macOS 26.5.2 test destination, the measured 5,000-record
results were:

| Workload | Before | After | Change |
| --- | ---: | ---: | ---: |
| Initial title-sorted grid model | 63.674 ms | 58.894 ms | 7.5% faster |
| Filename parser corpus | 11,555.7 ms | 6,750.1 ms | 41.6% faster |
| Mixed reconciliation apply | 4,185.1 ms | 44.9 ms | 98.9% faster |
| Markdown render | 2,170.9 ms | 2,162.7 ms | Within run-to-run noise |

The release-scale run retained identical catalog bytes and source-cover hashes.
Focused tests also verify derived-index invalidation, concurrent parser
determinism, cancelled partial fingerprints, and exact optimized-versus-legacy
reconciliation output.

Reviewed filename suggestions and manual Save actions now bypass autosave
debouncing. Maintenance refresh/rebuild work cannot supersede a pending metadata
edit, and an edit waits for an active whole-catalog operation. A regression test
accepts suggestions for two books and reopens the Markdown catalog to verify
that both records and every accepted field persist.

The non-interactive release-scale test passed on 2026-07-25. This closes
V11-009, V11-014, V11-023, and V11-025.

## Phase 6 verification

The scanner now publishes bounded progress after enumeration and during cover
inspection. `CatalogStore` maps that progress to `ScanState` and the existing
cancelable status capsule, with at most 102 progress events for a scan of any
size. Background refreshes update state without accidentally presenting a
foreground status capsule. Focused scanner coverage verifies the initial and
terminal counts and the progress bounds.

The rule-driven v2 filename parser is now the production default. The
corpus-specific legacy parser remains available only as an explicit debug and
differential-test engine; portable golden fixtures continue to compare both
engines. This isolates historical corpus branches without deleting the
compatibility oracle or weakening mandatory field-level review.

The main SwiftUI `Window` already declares
`.defaultLaunchBehavior(.presented)`. App launch now relies on that deterministic
scene lifecycle instead of immediate, asynchronous, and delayed attempts to
force the same window forward. Reopen handling still presents an existing
hidden window. Contract coverage rejects delayed launch retries.

The Project Gutenberg comparison uses one explicit historical reference value
containing the count, capture month/year, and source URL. The About window
continues to identify it as a July 2026 eBook-count reference rather than a live
page count, and the maintenance procedure is documented and tested.

The first recommended `CatalogStore` extraction is complete:
`CatalogUITestFixtureBuilder` owns deterministic test-fixture construction and
has direct unit coverage for scale, unsupported-schema, conflict, and recovery
fixtures. Further splitting of undo, mutations, and presentation state is
deliberately deferred: no second implementation or reproduced correctness
defect currently justifies moving the sole main-actor mutation boundary during
release stabilization.

Focused Phase 6 coverage and the complete non-interactive suite passed on
2026-07-26. This closes V11-010, V11-012, V11-013, and V11-016. V11-019's
high-confidence first extraction is complete; speculative decomposition is
deferred with the no-data-loss rationale above.

The repeat 1,000/2,500/5,000-cover matrix measured refresh times of
1.70/4.12/8.24 seconds. At 5,000 covers, catalog parsing took 6.14 seconds,
grid-model construction took 58 ms, cancellation took 44 ms, and peak resident
memory was 647 MB. Source SHA-256 manifests remained identical before and after
every run.

## Phase 7 automated verification

The supplied 24 structured remediation vectors now have an explicit portable
test map in `docs/v1.1/TEST-VECTORS.md`. Machine-local removable-volume corpus
tests remain optional diagnostics and are not counted as CI or release
coverage, closing V11-021.

The vector review exposed one missing integration boundary: after an external
disk change rejected a reviewed filename-suggestion save, conflict handling
merged the displayed catalog rather than the unsaved reviewed candidate.
`CatalogStore` now passes that candidate directly into the three-way merge
without publishing optimistic state. A conflict-free merge durably saves both
the reviewed suggestion and unrelated external fields; a real field conflict
remains pending for explicit review. The regression passed ten consecutive
iterations and two sequential reviewed suggestions survived reopen.

The release checklist now contains explicit evidence for every V11-022 safety
assertion and no longer counts historical or machine-local evidence as a
current portable pass. Mandatory V11-001 through V11-005 gates and all 24
portable vectors pass.

The 2026-07-26 headless release-candidate run passed localization, unit,
concurrency, integrity, and 1,000/2,500/5,000-cover suites. At 5,000 covers the
current run measured 9.95 seconds for refresh, 6.51 seconds for catalog parsing,
60 ms for grid-model construction, 44 ms cancellation, and 698 MB peak resident
memory. Every source-cover SHA-256 manifest was unchanged.

A separate clean product-only universal Debug bundle passed strict deep
signature verification. It uses hardened runtime and the intended App Sandbox,
app-scoped bookmark, user-selected read/write, and network-client entitlements.
It is signed with Apple Development for local verification, not Developer ID,
so Gatekeeper rejection as a distribution artifact is expected. Current UI
automation and signed-launch verification remain pending until an explicitly
announced screen-control window. Hardware/iCloud/two-device, browser,
appearance, and VoiceOver rows also remain manual release gates.
