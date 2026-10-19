# Vitrine — Sort Redesign: Reviewed Implementation Contract

**Date:** 2026-10-19  
**Status:** Design reviewed; implementation NOT started.  
**Source:** User-provided `VITRINE_SORT_REDESIGN.md` (2026-10-19).  
**Baseline:** `main` at `2be7a4b183c6411509c6f62ee33c35546053d579`.

## 1. Implementation entry point — NO prerequisite merge

- **Start implementation now from current `main`**, not from the historical toolbar branch. Create a separate `feat/vitrine-sort-sections` implementation branch; re-read `main` first to avoid stale SHAs. The source redesign says the toolbar candidate should land first, but that is a *design assumption*, not a technical prerequisite.
- Liquid Glass toolbar reference: `07c6a9311a1248d1f31b55f1fad094aabfe05661` on `stringmaster/vitrine-toolbar-density-glass-r2`. The candidate is five commits ahead and fourteen behind `main` at this review, with unrelated differences. **Do not merge/cherry-pick the entire branch** into this feature. Inspect and manually adopt only the still-desired toolbar-specific decisions within the new sort control.
- Keep all current-mainline behavior outside sorting: `.navigation` catalog identity, `.principal` Vitrine identity, filtering, conditional filename-review action, cover-size buttons, Refresh, Inspector, toolbar spacer and file/catalog flows. Do not remove unrelated newer mainline code to mimic the older candidate.
- The historical toolbar's *visual acceptance* is NOT a blocker to coding this feature. Compile and test first; evaluate the new combined toolbar visually before merging the implementation PR. This reviewed-contract PR is separate from implementation and should remain design-only.
- Decide the actual liquid-glass container treatment based on the platform rendering: avoid stacking a custom glass background on native glass controls; keep the switch visible and usable at small window sizes.

## 2. User-facing contract

- Replace the icon-only thirteen-case Sort menu with **Title | Year | Collection**, current mode readable without opening a menu.
- Tapping the active segment reverses its direction. An explicit adjacent direction control must offer a discoverable alternative; its label/value must state the direction. Selecting an inactive mode resets direction to ascending. Default: Title ascending.
- Ascending semantics: title A–Z, year oldest to newest, collection A–Z. Descending reverses **the primary key**, while title tie-breaks remain A–Z for Year and Collection.
- Keep filtering, search, cover sizing, Refresh, Inspector and conditional Review Next Filename behavior intact.
- Validate narrow-window toolbar layout, Dynamic Type, label truncation/overflow, focus order, VoiceOver and keyboard activation. If necessary make the switch compact without hiding current sort state.

## 3. Persisted sort state and migration

- Replace `CatalogSortOption`'s thirteen cases with Title/Year/Collection plus a separate `SortDirection` (ascending/descending). Keep serialization backward compatible through a single explicit migration reader; writing back canonical values is idempotent.
- Legacy `titleAscending` -> Title/ascending; `titleDescending` -> Title/descending; `publicationYear` -> Year/ascending; `collection` -> Collection/ascending. All other removed values and invalid/unknown persisted values -> Title/ascending. Respect a separately saved direction only for the new canonical model, not for discarded legacy sorts.
- Preserve the existing `sortOption` UserDefaults key if practical; add an independently persisted direction key. Migration must not modify catalog files or book metadata.
- Replace tests that require removed sort cases instead of silently dropping coverage.

## 4. Ordering invariants: one comparison contract

- Sort and section under the **same canonical normalized primary key**. Do not derive display grouping from raw fields while sorting using different fallback keys.
- Title: normalized displayed title, with the leading normalized letter as group identity (uppercase for display). Nonletter-leading titles belong to `#`; define `#` placement deterministically (first in ascending, last in descending) so the group is contiguous.
- Year: extract the first valid four-digit publication year using the existing `CatalogDerivedIndex.publicationYear` precedence. Never change the publication-date parser in this feature. **Undated must stay at the end in both directions.**
- Collection: trim whitespace; a missing/blank collection has its own sentinel and a final **Uncategorized** group in both directions. **Do not use title as a substitute collection key** (current index does this). Normalize present collection names consistently; keep the original human-readable collection spelling for section headings.
- Secondary/tertiary keys: Year -> normalized Title A–Z -> UUID; Collection -> normalized Title A–Z -> UUID; Title -> UUID. UUID is only a deterministic last-resort tie breaker. Compare nil/sentinel cases explicitly, never by inverting a comparator that would pull missing values to the top.
- Total ordering must not depend on the incoming order of catalog items, search/filter state, sort implementation stability, or hash iteration order.

## 5. Section generation

- Keep `visibleItems` as the already-filtered, already-sorted *flat* source used by keyboard navigation, selection, scrolling, accessibility position and card counts. Group that exact array for presentation; do not execute a second competing sort.
- Prefer a pure, testable section builder accepting the computed visible array and sort state. Each section has a stable canonical identity, localized display label, item count and references to items plus their original one-based flat index.
- Title: letter rails, skip empty groups, `#` for nonletters. Year: adaptive era headers with visible gaps between occupied buckets. Collection: group names and book counts; missing collection trails.
- Bucket initial width based on range of **known visible years**: span <=15: 5; <=60: 10; <=150: 25; otherwise: 50. Align to global width boundaries using integer division.
- The initial formula alone does NOT guarantee 4–8 groups or a <=10 cap. Recount **occupied** buckets, including `Undated`, then iteratively widen through 5,10,25,50,100,200,500,1000,2000,... as needed to enforce at most ten rendered sections. The 4–8 target is aspirational, not an invariant for sparse/pathological distributions.
- Render a width-10 interval as `1960s`; other widths use explicit year ranges, shortened only when unambiguous (for example `1990–94`). Use localized `Undated` for missing or unparsable years. Recalculate buckets when the *visible result set* changes, not on every unrelated card redraw.
- Suppress the visual section header when there is only one section, including an entirely undated/uncategorized result. With zero results, render no section.

## 6. SwiftUI and interaction constraints

- Use `LazyVGrid(..., pinnedViews: [.sectionHeaders])` and `Section` headers spanning the grid. Do not replace the existing virtualized grid with eager stacks. Use a light material under pinned headers; label + localized count + trailing hairline rule, accessible as a heading.
- Preserve stable `.id(item.id)` for `ScrollViewReader.scrollTo`, multi-action context menus, double-click, selection, Quick Look and `BookCardView.gridPosition/gridCount` based on the **flat** list. Existing up/down navigation uses an approximate column heuristic; verify it with section boundaries rather than asserting it is correct by construction.
- Animate mode changes only when Reduce Motion is off and the scale test remains responsive. `.animation` on section identity by itself does not guarantee cards glide between different `Section` containers. Do not promise that animation without verifying it on macOS.
- Keep `CatalogDerivedIndex` lazy-search behavior; remove dead sort-key branches without changing `searchableText` fields used for search. Avoid repeated N log N sorting through separate toolbar, store and grid reads where possible; measure before adding caching.

## 7. Localization and accessibility

- Update `Localizable.xcstrings` with all new strings and complete `fr` and `fr-CA` entries: `Year`, `Undated`, `Uncategorized`, accessible mode/direction instructions and any button labels/help text. Reuse `L10n.bookCount` for localized plurals.
- Use `L10n.text` for static labels; never hard-code English section/control strings. The numeric year/range formatting must be locale-appropriate without altering its semantic boundaries.
- Expose section headings as VoiceOver headings with count, sort mode and direction as readable control state, and direction reversal as keyboard-accessible action.

## 8. File-level scope

| File | Expected work |
|---|---|
| `Vitrine/Models/CatalogSortOption.swift` | New 3-mode + direction model and canonical persistence migration helper |
| `Vitrine/Services/CatalogDerivedIndex.swift` | Eliminate unused sort keys; preserve search text; add canonical primary/secondary keys |
| `Vitrine/Stores/CatalogStore.swift` | Persisted mode/direction, strict total comparator, pure section-building interface or integration |
| `Vitrine/Views/LibraryGridView.swift` | Sectioned virtualized grid, pinned headers, accessibility, positional identity |
| `Vitrine/Views/ContentView.swift` | Three-way visible switch, reversal button and preserved toolbar actions |
| `Vitrine/Resources/Localizable.xcstrings` | EN lookup + fr/fr-CA localized values |
| `VitrineTests/*` | Adapt existing sort assertions; add migration, order, bucket and grouping tests |

## 9. Required acceptance evidence

1. Title A–Z/Z–A; Year ascending/descending with undated last; Collection ascending/descending with uncategorized last. Equal primary keys have deterministic, documented tie-breaks.
2. Boundary years: 5/10/25/50 bins, half-decade crossing, century boundary, very wide year spans, gaps, invalid dates, exactly one section and no results; cap of <=10 occupied sections.
3. All removed raw preference values, both legacy title directions, year/collection legacy preferences, invalid raw string and application relaunch.
4. Search/filter while sort changes, collection spelling/case/diacritics, symbols/digits/accented title initials, duplicate titles, deterministic UUID tie break.
5. Grid action regressions: focus, keyboard arrows/Home/End/Return/Space, scroll-to-selection, context actions, card accessibility positions, sticky header behavior and custom cover width.
6. VoiceOver, Reduce Motion, light/dark, window minimum width, macOS visual review against accepted Liquid Glass candidate.
7. Unit, UI, performance and scale coverage including `CatalogStoreFilterTests`, `Phase5PerformanceTests`, `ReleaseCandidateScaleTests`, `LocalizationTests` and 1,000/2,500/5,000-item libraries. Measure sort+section elapsed time and scrolling responsiveness. Verify the source-cover read-only and Markdown-only persistence guarantees remain untouched.

## 10. Executable coding work order — implement end to end

**Goal:** Deliver a *working* three-mode sorted and sectioned library on a new branch from current `main`; publish a draft implementation PR; never auto-merge. Do not stop at another design review.

1. **Branch and read-only preflight.** Fetch current `main`, create `feat/vitrine-sort-sections`, review the five production files, localization file and test references in section 8. Inspect the old toolbar candidate as a reference only. Do not modify the old candidate branch or PR #4.
2. **State and migration.** Implement `CatalogSort` and `SortDirection`, migrate legacy raw strings exactly as section 3, persist the canonical pair, and add focused preference tests. Keep `UserDefaults` test isolation. Preserve previous saved descending Title behavior.
3. **Deterministic sort core.** Remove unused sort keys **without deleting searchable metadata**. Implement canonical keys and a strict total comparator, explicit missing-value-last semantics and stable tie-breaks in section 4. Test every direction, collection nil/blank, year nil/invalid, equal keys and reverse order.
4. **Section model.** Implement a pure grouping function in a separately testable module or helper (not in a view's `body`). Accept one already-sorted visible-item snapshot; output stable group ids, display labels, counts and flat indices. Implement bucket widening, sparse distributions and no/single-section behavior. Reuse the exact sort keys.
5. **Grid.** Render `Section` within `LazyVGrid(pinnedViews: [.sectionHeaders])`. Keep card id, actions and global index for accessibility. Verify existing up/down keyboard selection and `ScrollViewReader` across section boundaries. If positional navigation is incorrect, fix the actual geometry/navigation logic instead of preserving a known-bad heuristic.
6. **Toolbar and localization.** Replace the thirteen-case menu with visible Title/Year/Collection and a direction button. Selecting a *different* mode uses its documented default ascending; selecting the *current* mode toggles. Supply localized control state and headings in `fr` and `fr-CA`, including plural book counts. Preserve other toolbar actions and integrate only relevant visual choices from the Liquid Glass candidate.
7. **Quality verification.** Build with the available macOS/Xcode environment. Run unit tests and targeted UI tests; cover 1k/2.5k/5k items; check light/dark, Reduce Motion, VoiceOver and a narrow window. Animation is an optional enhancement if stable and performant; do **not** make it a blocking prerequisite for correct ordering and headers. If no macOS runner is available, report **untested** rather than claim tests passed.
8. **Deliver.** Commit coherent increments on the feature branch, push, create a draft PR with changed files, actual test commands/results, screenshots *only if actually captured*, known limitations and precise head/base SHAs. Keep `main` untouched and do not merge without review.

**Implementation acceptance order:** determinism and migration -> grouping and keyboard integrity -> visible switch and sticky headers -> localization/accessibility -> macOS build/tests/visual review. Earlier stages can be coded together without waiting for intermediate approvals. No blocker should be invented from the unmerged historical toolbar branch.

**Merge gate:** A working Swift/macOS build, meaningful regression results and review of the combined toolbar on a supported machine. This design-only PR does not constitute implementation/test evidence.
