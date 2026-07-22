# Vitrine V1 release-candidate checklist

Last updated: 2026-07-22

## Release status

**Candidate status: not yet releasable.** The V1.1 remediation audit supersedes the earlier release-candidate safety assessment. All mandatory V11-001 through V11-005 safety gates and the conflict/schema/localization gate are fixed and verified. Measured-scale, maintainability, and final release-verification phases remain open; hardware/iCloud/two-Mac and hands-on visual/VoiceOver portions of the manual matrix also require a scheduled acceptance session.

Verified V1.1 critical fixes: **2** (`V11-001`, `V11-002`). The broader V1.1 safety gate remains open.

The live remediation register is maintained in
[`docs/v1.1/REMEDIATION.md`](docs/v1.1/REMEDIATION.md). Existing V1 automated
results remain useful baseline evidence, but do not close a V1.1 gate.

## Shared-schema freeze

The V1 shared schemas are frozen during release verification. Changes to `BibliographicMetadata`, `CatalogItem`, `FilenameMetadataSuggestion`, `MetadataCandidate`, Markdown field names, or `CatalogMergeField` require all of the following in the same change:

1. Markdown writer and parser coverage.
2. Pre-change and post-change compatibility coverage.
3. Search inclusion where user-facing lookup is expected.
4. Three-way merge and conflict-resolution coverage.
5. Whole-item undo/restore coverage.
6. Inspector/editor or review presentation.
7. English, French, and Canadian French localization.
8. Accessibility text where the field is presented.

Reviewed parser fields are integrated through `FilenameMetadataSuggestionAdapter`; parsing rules do not live in `CatalogStore`.

## Automated verification

| Area | Result | Evidence |
| --- | --- | --- |
| Metadata schema integration | Pass | Every reviewed filename field is adapter-mapped; full metadata round-trips and merges. |
| Termination save durability | Pass | Pending debounced saves flush before termination; failure cancels quit; repeated quit and timeout paths are covered. |
| Transactional metadata edits | Pass | Catalog and undo state commit only after a successful save; failed and concurrent edits are covered. |
| External file-event ordering | Pass | One unbounded presenter stream preserves ordered events while catalog operations finish. |
| Ambiguous reconciliation clusters | Pass | Group-level full-hash resolution and 3×3, 3×2, 2×3, single-assignment, and deterministic-order regressions pass. |
| Explicit metadata-only retention | Pass | Kept records survive complete scans, uniquely returning covers reconnect, and explicit deletion remains available. |
| Reconciliation baseline | Pass | A changed `baseCatalogUpdatedAt` rejects the complete stale diff without altering the current catalog. |
| Cover-path containment | Pass | One resolver protects thumbnails, Open, Quick Look, and Finder reveal; traversal, absolute, malformed, root-equal, Unicode, and symlink cases are covered. |
| Cross-catalog replacement | Pass | Different catalog IDs back up under the old identity; malformed/unrelated bytes require authorization and are preserved verbatim; cancellation is non-mutating. |
| Cover-access bookmark intent | Pass | Catalog relocation preserves remembered cover access only when requested; explicit replacement and stable-volume remount semantics are documented and tested. |
| Conflict value presentation | Pass | Every merge field has a readable sample; contributors, roles, physical attributes, pagination, nil and empty values use localized display rules. |
| Dynamic localization safety | Pass | Runtime-built keys fail the audit; all catalog entries require `fr` and `fr-CA`; enum labels are exhaustive static mappings. |
| Bibliographic schema surface | Pass | Stored properties, Markdown keys and merge fields are registry-checked; fully populated and legacy schema-1 catalogs round-trip. |
| Markdown note compatibility | Pass | CRLF, CR and LF normalize identically while Finder block quotes and personal-note multiline output remain distinct. |
| Legacy catalog compatibility | Pass | A pre-parser schema-1 catalog rewrites without losing unknown fields. |
| Localization | Pass | Every catalogued string has `fr` and `fr-CA`; extracted SwiftUI keys are audited. |
| Unit, concurrency and integrity suite | Pass | `script/test.sh` completed successfully. |
| UI test compilation | Pass | The complete UI target, including the 5,000-item case, builds for testing. |
| UI test execution | Pass | `script/test_ui.sh --confirm-screen-control` completed the entire suite on 2026-07-21. |
| Source-cover integrity | Pass | SHA-256 manifests matched before and after all three scale scans. |
| Volume identity matching | Pass | UUID/resource identity is required; an unrelated same-name volume is rejected. |
| Thumbnail cache | Pass | One miss followed by one hit; 500-item and 256 MiB limits verified. |
| Clean signed build | Pass | Universal debug app signed by Apple Development; strict deep verification passed. |
| Sandbox entitlements | Pass | App Sandbox, app-scoped bookmarks, user-selected read/write and network client present. |
| Signed launch | Pass | `script/build_and_run.sh --verify` launched the clean artifact and found the process. |
| Distribution Gatekeeper | Not assessed | The current artifact is a development-signed build, not a notarized Developer ID distribution artifact. |

## Scale measurements

The test used 1,200 × 1,800 JPEG source covers. Peak memory is the conservative test-host high-water mark accumulated across the complete run. “Launch to grid” below measures catalog parsing/model availability; the 5,000-item UI navigation test also passed its 15-second interaction gate.

| Covers | Catalog size | Render | Parse/model ready | Refresh | Grid model | Peak resident |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1,000 | 534,637 bytes | 529 ms | 1,239 ms | 1,737 ms | 13 ms | 179 MB |
| 2,500 | 1,339,477 bytes | 1,025 ms | 3,063 ms | 4,170 ms | 31 ms | 375 MB |
| 5,000 | 2,680,877 bytes | 2,055 ms | 6,133 ms | 8,343 ms | 62 ms | 666 MB |

At 5,000 covers, cancellation completed in 35 ms. A cold thumbnail request took approximately 4 ms and the repeated request was served from cache below the timer’s 1 ms reporting resolution.

## Manual acceptance matrix

Status meanings: **Pass** was exercised in this release pass, **Automated** has direct deterministic coverage, **Partial** has passing coverage but still needs a hands-on portion, and **Pending manual** needs hardware, iCloud, networking, visual review, VoiceOver, or two Macs.

| # | Acceptance step | Status | Record |
| ---: | --- | --- | --- |
| 1 | Create a catalog from 20 JPEG covers | Pending manual | Welcome action is automated; native panel selection remains manual. |
| 2 | Save Markdown in iCloud Drive | Pending manual | Requires the user’s iCloud Drive. |
| 3 | Confirm no image is copied or modified | Pass | Before/after SHA-256 manifests match through 5,000 covers. |
| 4 | Grid appears without technical setup screens | Pass | Available and metadata-only UI fixtures launch directly into the library. |
| 5 | Confirm filenames and File Notes | Automated | Scanner and Finder Comment tests pass. |
| 6 | Quit/relaunch without new permission prompts | Pending manual | Bookmark persistence passes unit coverage; actual relaunch remains manual. |
| 7 | Add, rename and move covers | Automated | Reconciliation diff coverage. |
| 8 | Confirm UUID preservation | Automated | Fingerprint rename coverage. |
| 9 | Modify a Finder comment | Automated | Extended-attribute reader coverage. |
| 10 | Confirm it appears as File Notes | Pending manual | Model path covered; visual inspection remains. |
| 11 | Remove a cover | Automated | Complete-scan missing-record coverage. |
| 12 | Confirm missing-cover outcome | Automated | Locked V1 decision supersedes the old wording: confirmed unmatched records are removed after a safe complete refresh and backup. |
| 13 | Disconnect source volume | Pending manual | Requires removable hardware. |
| 14 | Confirm placeholders and Locate notice | Pass | Metadata-only UI fixture remains browsable and exposes Locate. |
| 15 | Remount volume in background | Pending manual | Requires removable hardware. |
| 16 | Confirm automatic reconnection | Pending manual | Identity matcher covered; mount notification needs hardware. |
| 17 | Mount unrelated same-name volume | Automated | Pure matcher rejects name-only matches. |
| 18 | Confirm mismatch warning | Pending manual | Physical-volume workflow required. |
| 19 | Copy a large cover during refresh | Pending manual | Instability guards covered; live copy scenario remains manual. |
| 20 | Confirm unstable cover is deferred | Automated | Unstable-known-path reconciliation test. |
| 21 | Edit notes during refresh | Automated | Stale-diff rejection preserves the edit and requests a fresh reconciliation. |
| 22 | Confirm one combined save | Automated | Debounced/overlapping save-collapse coverage. |
| 23 | Modify Markdown externally during refresh | Automated | External baseline and latest-catalog diff coverage. |
| 24 | Confirm both changes survive | Automated | Safe source/bibliographic merge coverage. |
| 25 | Create conflicting edits on two Macs | Pending manual | Merge engine covered; two-Mac transport requires hardware. |
| 26 | Confirm simple conflict alert | Pass | UI automation verifies Keep Mine, Use Other, and Review choices. |
| 27 | Broad choices affect only conflicting fields | Automated | Field-specific merge tests. |
| 28 | Review changes side by side | Pending manual | Review entry point is automated; side-by-side visual acceptance remains. |
| 29 | Enter an ISBN | Pending manual | ISBN validation and lookup decoding pass. |
| 30 | Accept selected Open Library fields | Pending manual | Candidate mapping is covered; live interaction remains. |
| 31 | Trigger Google and DuckDuckGo fallback | Pending manual | Requires user-initiated browser/network exercise. |
| 32 | Confirm no Google Books request | Automated | No Google Books dependency or endpoint exists. |
| 33 | Corrupt one Markdown record | Automated | Malformed-record recovery coverage. |
| 34 | Confirm friendly repair experience | Partial | Recovery presentation is automated; wording and complete choice flow remain manual. |
| 35 | Restore a backup | Automated | Selectable restore and coordinator tests. |
| 36 | Confirm damaged file remains preserved | Automated | Recovery preservation tests. |
| 37 | Browse at least 5,000 covers | Pass | UI automation reaches book 5,000 within the 15-second navigation gate. |
| 38 | Test hover and scrolling | Partial | 5,000-item scrolling passes; pointer-hover appearance remains manual. |
| 39 | Test light and dark appearances | Pending manual | Visual acceptance required. |
| 40 | Test Reduce Transparency | Pending manual | Visual acceptance required. |
| 41 | Test Increase Contrast | Automated | Accessibility fixture launches and verifies selection semantics; visual acceptance remains covered by row 39. |
| 42 | Test Reduce Motion | Automated | Accessibility fixture launches with Reduce Motion and verifies core semantics. |
| 43 | Navigate fully by keyboard | Pass | Arrow and End navigation are exercised through the focused grid. |
| 44 | Operate primary actions through VoiceOver | Pending manual | Labels/actions compile; VoiceOver operation requires manual acceptance. |
| 45 | Build, test and launch through run script | Pass | Clean signed build and process verification succeeded. |
| 46 | Attempt a second main window | Pass | UI automation verifies the main scene remains single-window across reopen and Command-N. |
| 47 | Newer schema opens read-only and cannot save | Pass | UI and save-coordinator tests enforce read-only behavior. |

## Remaining release actions

1. Exercise the iCloud, two-Mac, removable-volume, browser, appearance, and VoiceOver rows above.
2. Record hands-on visual first-frame, hover, and appearance results.
3. If distributing outside Xcode, produce and assess a hardened Developer ID/notarized artifact separately.

The V1 gate closes only when every **Partial** and **Pending manual** row has a dated pass record and no critical safety failure is found.
