---
schema: stringmaster/v1
project_id: vitrine
revision: 17
source_repository: rrwfyzgt4n-png/Vitrine
active_branch: stringmaster-remediation/vitrine-language-sort-consistency-r1
verified_remote_head: c1843f98390034b16dae530280de50bdf46de392
reported_local_head: null
verification_status: verified
stage: READY
active_transition: vitrine-toolbar-density-glass-r1
active_work_order: WO-2026-08-31-017
executor: codex
model_class: GPT-5.6 Luna Low
spending_class: S1
blocked_by: null
updated_at: "2026-08-31T08:49:00-04:00"
---

# Current objective

Implement the bounded v1.0 macOS toolbar polish approved by product authority: rely on native system Liquid Glass for ordinary toolbar controls and replace the cover-size typography metaphor with a grid-density metaphor while preserving the existing stepped repeat behavior.

# Accepted base

```text
branch: stringmaster-remediation/vitrine-language-sort-consistency-r1
commit: c1843f98390034b16dae530280de50bdf46de392
```

The accepted branch was freshly re-verified before this transition and still points exactly to the accepted commit.

# Active transition

`WO-2026-08-31-017` is the sole active work order.

It is a single S1 Codex source lane restricted to:

```text
Vitrine/Views/ContentView.swift
```

The intended candidate branch is:

```text
stringmaster/vitrine-toolbar-density-glass-r1
```

No candidate exists or is accepted yet.

# Product constraints

- ordinary toolbar controls should use native macOS toolbar glass;
- the deliberate principal Vitrine glass identity and intentionally prominent review action are preserved;
- cover sizing uses denser-grid = smaller covers and sparser-grid = larger covers;
- discrete stepping and press-and-hold repeat behavior are preserved;
- the corresponding endpoint control becomes unavailable at minimum/maximum size;
- no broader UI redesign, architecture change, asset work, localization work, or release-gate work is authorized.

# Next action

Execute `WO-2026-08-31-017` exactly once through the accepted StringMaster turn path, then review the resulting REPORT/RECEIPT and candidate independently before any acceptance transition.
