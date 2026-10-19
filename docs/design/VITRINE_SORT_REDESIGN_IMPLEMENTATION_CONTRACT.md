# Vitrine — Sort Redesign: Reviewed Implementation Contract

**Date:** 2026-10-19  
**Status:** Design reviewed; implementation NOT started.  
**Source:** User-provided `VITRINE_SORT_REDESIGN.md` (2026-10-19).  
**Baseline:** `main` at `2be7a4b183c6411509c6f62ee33c35546053d579`.

## 1. Integration prerequisite

- The accepted-but-not-merged Liquid Glass toolbar candidate is `07c6a9311a1248d1f31b55f1fad094aabfe05661`, on `stringmaster/vitrine-toolbar-density-glass-r2`.
- Its branch diverged from `main` (at this review: five commits ahead, fourteen behind; merge base `39eb0f675106f7e773f68a054da435ac16f9e594`). **Do not merge the entire candidate branch, or base the feature on that candidate, without reconciling newer mainline changes.**
- First port/land the approved toolbar-specific changes onto current `main` in a minimal isolated change, after the stipulated visual check. Preserve `.navigation` catalog identity, `.principal` Vitrine identity, primary-action filter/cover controls and trailing toolbar actions.
- Develop the sort change from the reconciled mainline, preferably as a separate functional PR. This design-only branch carries no application modification.

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

**Merge gate:** Actual Swift/macOS build and visual acceptance on the supported macOS/Xcode environment. A design-only PR does not constitute test evidence or feature completion.
