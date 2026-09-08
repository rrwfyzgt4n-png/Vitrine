# Vitrine Current Policy — SHADOW / NON-AUTHORITATIVE

This is a staged current-policy surface only. Until product authority explicitly accepts a Vitrine POLICY cutover, canonical `sm-vitrine/DECISIONS.md` remains the operative project-policy source. This file intentionally excludes transient revisions, active candidates, accepted-head chronology, and one-off review evidence.

## Canonical control

Vitrine's mutable canonical StringMaster control lives under `sm-vitrine/` in this repository. The former central StringMaster Vitrine tree is frozen historical material and must not receive new control mutations.

**Provenance:** DECISIONS “Canonical StringMaster control lives with Vitrine” (2026-08-31); current StringMaster FRAMEWORK.

## External cover storage

Vitrine consumes user-selected external cover storage without taking ownership of it. The application must not copy, rename, move, edit, recompress, delete, or upload source cover files.

**Provenance:** DECISIONS “External cover storage remains read-only” (2026-08-06).

## Durable catalog format

Bibliographic metadata, provenance, workflow state, and personal notes remain in a user-selected, human-readable Markdown catalog rather than an opaque application database.

**Provenance:** DECISIONS “Portable Markdown is the durable catalog” (2026-08-06).

## Network enrichment

Metadata lookup remains explicit, user initiated, selected-item only, and reviewable before returned fields become durable catalog data.

**Provenance:** DECISIONS “Network enrichment remains explicit” (2026-08-06).

## Persistence and recovery

The active catalog has one coordinated writer. Saves remain serialized and atomic, backups remain rotating and recoverable, unsupported newer schemas remain read-only, and external edits remain conflict-aware.

**Provenance:** DECISIONS “Persistence and recovery remain safety boundaries” (2026-08-06).

## Release evidence

Automated unit, integration, concurrency, localization, scale, integrity, and UI evidence may support release acceptance but do not replace required manual iCloud, two-Mac, removable-volume, browser, visual, VoiceOver, signing, Gatekeeper, or notarization gates when those gates are active.

Pre-ship hardening precedes remaining design polish. Ship-relevant safety, data-loss, security, and hardening findings must be addressed before design polish and final release gates; future product work should not displace those release obligations without an explicit product decision.

**Provenance:** DECISIONS “Automated evidence does not close manual release gates” (2026-08-06) and “Pre-ship hardening precedes design polish” (2026-08-14).

## Toolbar Liquid Glass

Ordinary macOS toolbar controls should rely on the system-provided Liquid Glass treatment and grouping instead of redundant explicit glass button styling. Custom glass is reserved for intentional custom surfaces or deliberate replacement of a shared system grouping.

**Provenance:** DECISIONS “Toolbar glass follows the native macOS toolbar treatment” (2026-08-31).

## Cover-size control

Cover sizing communicates library density rather than typography: a denser grid means smaller covers and a sparser grid means larger covers. Preserve discrete stepping and press-and-hold repeat behavior. At the minimum or maximum size, the corresponding direction is unavailable. Help and accessibility labels continue to state the actual cover-size action.

**Provenance:** DECISIONS “Cover sizing uses a grid-density metaphor” (2026-08-31).

## Acceptance boundary

Automated evidence, technical acceptance, candidate publication, and canonical REPORT/RECEIPT evidence do not replace a product visual/manual gate when the active Vitrine state requires one. Product authority retains final acceptance.

**Provenance:** durable release-evidence decisions; current StringMaster FRAMEWORK.

## Migration boundary

This shadow POLICY does not accept or reject the toolbar candidate currently under review and does not change Vitrine's source pointer or review state. It exists only to prepare a later hot/cold policy cutover after completeness review.
