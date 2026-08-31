---
schema: stringmaster/v1
project_id: vitrine
revision: 16
source_repository: rrwfyzgt4n-png/Vitrine
active_branch: stringmaster-remediation/vitrine-language-sort-consistency-r1
verified_remote_head: c1843f98390034b16dae530280de50bdf46de392
reported_local_head: null
verification_status: verified
stage: ACCEPTED
active_transition: null
active_work_order: null
executor: null
model_class: null
spending_class: null
blocked_by: null
updated_at: "2026-08-31T03:59:12-04:00"
---

# Current objective

Complete Vitrine's remaining v1.0 product/design polish from the accepted engineering baseline, beginning with the toolbar Liquid Glass cleanup and a clearer cover-size control, before returning to the remaining manual release gates.

# Accepted state

Accepted Vitrine source:

```text
branch: stringmaster-remediation/vitrine-language-sort-consistency-r1
commit: c1843f98390034b16dae530280de50bdf46de392
```

The accepted source branch was independently re-verified on 2026-08-31 and still points exactly to that commit. No new source candidate is active.

# Canonical-root establishment

This revision establishes `sm-vitrine/` in the Vitrine repository as the canonical StringMaster control root required by the current framework.

The former `rrwfyzgt4n-png/StringMaster/projects/vitrine/` control tree remains frozen historical material. Its revision-15 accepted record was used only as migration input and does not remain an authoritative mutable control location.

No historical run, turn, receipt, report, or archived work order is rewritten or copied as new evidence by this migration.

# Product decisions ready for implementation

The next design transition should preserve the existing cover-size stepping and press-and-hold repeat behavior while replacing the font-size metaphor with a grid-density metaphor: denser grid for smaller covers, sparser grid for larger covers. Endpoint controls should become unavailable when the corresponding minimum or maximum is reached, while existing clear help and accessibility labels remain.

For toolbar Liquid Glass, prefer the native macOS toolbar treatment and remove redundant explicit glass styling where the system already supplies the appropriate toolbar glass. Custom glass remains appropriate only where it is intentionally replacing or supplementing the system grouping.

# Remaining release state

The prior release ordering remains:

1. pre-ship hardening — complete;
2. ship-relevant remediation — complete;
3. remaining product/design opinions — active next objective;
4. remaining manual release gates and Vitrine v1.0 shipment;
5. v1.1 work after real-world user evidence.

The earlier Xcode Helper Accessibility prerequisite and other manual release gates remain separate and unresolved until product/design work closes.

# Next action

Create a bounded product/design work order against exact accepted source `c1843f98390034b16dae530280de50bdf46de392` for the toolbar Liquid Glass cleanup and cover-size control metaphor. Do not begin release-gate work yet.
