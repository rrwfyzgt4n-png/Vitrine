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
| 3 — Filesystem and overwrite recovery | V11-005, V11-006, V11-026 | Planned | All cover access is contained and overwritten catalogs remain recoverable |
| 4 — Conflict, schema, localization | V11-007, V11-008, V11-018, V11-020, V11-024 | Planned | Every metadata surface round-trips and is localized |
| 5 — Measured scale | V11-009, V11-014, V11-023, V11-025 | Planned | Exact behavior with measured improvement at 5,000 records |
| 6 — Product truth and maintainability | V11-010, V11-012, V11-013, V11-016, V11-019 | Planned | Stable behavior without a high-risk speculative rewrite |
| 7 — Release verification | V11-021, V11-022 and all 24 remediation vectors | Planned | Complete automated and manual acceptance evidence |

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
