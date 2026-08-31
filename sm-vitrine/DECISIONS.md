# Vitrine Decisions

This file is append-only. Record only durable product or architectural decisions that would be costly to rediscover.

## 2026-08-06 — External cover storage remains read-only

Vitrine consumes a user-selected external cover tree without taking ownership of it. The application must not copy, rename, move, edit, recompress, delete, or upload source cover files.

## 2026-08-06 — Portable Markdown is the durable catalog

Bibliographic metadata, provenance, workflow state, and personal notes remain in a user-selected, human-readable Markdown catalog rather than an opaque application database.

## 2026-08-06 — Network enrichment remains explicit

Metadata lookup is user initiated, selected-item only, and reviewable before any returned field becomes durable catalog data.

## 2026-08-06 — Persistence and recovery remain safety boundaries

The active catalog has one coordinated writer. Saves remain serialized and atomic, backups remain rotating and recoverable, unsupported newer schemas remain read-only, and external edits remain conflict-aware.

## 2026-08-06 — Automated evidence does not close manual release gates

Unit, integration, concurrency, localization, scale, integrity, and UI automation may support release acceptance but do not substitute for required iCloud, two-Mac, removable-volume, browser, visual, VoiceOver, signing, Gatekeeper, or notarization evidence.

## 2026-08-06 — Initial onboarding is read-only

The first StringMaster transition inventories the exact local checkout against verified `origin/main`. It authorizes no source edits, builds, tests, launches, commits, pushes, signing, packaging, or release-state changes.

## 2026-08-14 — Pre-ship hardening precedes design polish

Before applying the remaining product/design opinions, run one full portable adversarial hardening sweep against the accepted engineering baseline with production frozen. Review and remediate ship-relevant findings before design changes. After the design changes, complete the remaining release gates and ship Vitrine v1.0. Defer v1.1 product work until real-world user testing provides evidence for the next revision.

The hardening sweep must not stop merely because it finds the first deterministic defect. It completes its bounded attack budget unless a safety/data-loss/security defect makes continued testing of that candidate meaningless. Automated hardening still does not replace the manual release gates recorded above.

## 2026-08-31 — Canonical StringMaster control lives with Vitrine

Under the current StringMaster framework, Vitrine's mutable canonical control state lives in the repository-top `sm-vitrine/` root. The former `rrwfyzgt4n-png/StringMaster/projects/vitrine/` tree is frozen historical material and must not receive new control mutations.

## 2026-08-31 — Toolbar glass follows the native macOS toolbar treatment

Vitrine should rely on the system-provided Liquid Glass treatment for ordinary macOS toolbar controls instead of redundantly forcing explicit glass button styles. Custom glass remains reserved for intentional custom surfaces or deliberate replacement of a shared system grouping.

## 2026-08-31 — Cover sizing uses a grid-density metaphor

The cover-size control should communicate library density rather than typography: a denser grid means smaller covers and a sparser grid means larger covers. Preserve discrete size stepping and press-and-hold repeat behavior. At the minimum or maximum size, the corresponding direction should be unavailable. Help and accessibility labels should continue to state the actual cover-size action.
