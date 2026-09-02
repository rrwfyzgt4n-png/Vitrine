---
schema: stringmaster/v1
work_order_id: WO-2026-09-02-020
work_order_kind: single
execution_mode: source
base_head: c1843f98390034b16dae530280de50bdf46de392
branch_name: stringmaster/vitrine-toolbar-density-glass-r2
write_roots:
  - Vitrine/Views/ContentView.swift
project_id: vitrine
state_revision: 21
executor: codex
recommended_model: gpt-5.6-luna
reasoning_effort: low
spending_class: S1
status: READY
maximum_full_test_runs: 1
final_test_argv:
  - ./script/test.sh
maximum_evidence_runs: 0
progress_narration: prohibited
architecture_changes: prohibited
created_at: "2026-09-02T03:18:00-04:00"
---

# Objective

Implement the already-approved Vitrine macOS toolbar polish: rely on native system Liquid Glass for ordinary toolbar controls and replace the cover-size typography metaphor with a clear grid-density metaphor, without changing cover-size stepping, repeat behavior, or unrelated product behavior.

This is a replacement execution for the consumed original implementation work order. Product intent and implementation scope are unchanged. The replacement uses a fresh candidate branch and the exact Codex CLI model id `gpt-5.6-luna`.

# Repository gate

- Source repository must be `rrwfyzgt4n-png/Vitrine`.
- Begin from exact accepted source `c1843f98390034b16dae530280de50bdf46de392`.
- The accepted source branch is `stringmaster-remediation/vitrine-language-sort-consistency-r1`.
- Work only in the isolated source lane prepared for this work order.
- Require assigned branch `stringmaster/vitrine-toolbar-density-glass-r2` at the exact base and clean at executor start.
- The remote r2 branch must be absent before StringMaster transport.
- Do not inspect, delete, repair, reset, checkout, or otherwise modify retained runtime evidence or the stale local r1 candidate branch from `TURN-2026-09-02-001`.
- Stop if the exact base cannot be established or if unrelated pre-existing changes are present in the prepared lane.

# Success criteria

1. Ordinary macOS toolbar controls in `ContentView` inherit the system toolbar's Liquid Glass treatment rather than forcing `.buttonStyle(.glass)`.
2. The intentionally prominent `Review Next Filename` action remains visually prominent; do not flatten it merely for stylistic uniformity.
3. The custom principal Vitrine identity may retain its deliberate custom glass surface and its corresponding shared-background opt-out.
4. The catalog identity toolbar item uses the native toolbar background/grouping instead of opting out without replacement glass, unless direct SDK behavior proves that would regress its intended presentation; if so, stop and report the evidence rather than invent another custom surface.
5. The cover-size control uses a native SF Symbols grid-density pair: denser grid means smaller covers, sparser grid means larger covers. Prefer `square.grid.3x3` and `square.grid.2x2` if both are valid for the current target SDK; otherwise use the closest native pair with the same literal density meaning and report the exact symbols chosen.
6. Do not use typography-size, magnification/zoom, or custom image assets for this control.
7. Preserve the existing discrete `coverSizeSteps` behavior and `.buttonRepeatBehavior(.enabled)` press-and-hold traversal.
8. Disable the decrease control at the minimum step and the increase control at the maximum step. Derive endpoint state from `coverSizeSteps`; do not duplicate endpoint constants.
9. Preserve the existing help and accessibility labels that state the actual actions, and preserve the cover-size accessibility value.
10. Remove cover-size visual-emphasis code that becomes dead or meaningless after the metaphor change.
11. `./script/test.sh` passes in the one authorized complete-suite run.
12. No file outside the single authorized write root changes.

# In scope

- `Vitrine/Views/ContentView.swift`
- Ordinary toolbar Liquid Glass cleanup inside this file.
- Catalog toolbar grouping/background participation.
- Cover-size icon metaphor, endpoint disabled state, and directly obsolete local presentation code.

# Out of scope

- Any other source or test file.
- Inspector, floating status, settings, welcome, about, library-card, or other glass redesign.
- New assets, localization edits, dependencies, package/project configuration, persisted state, data model, sorting/filtering semantics, catalog behavior, release gates, signing, notarization, or accessibility-system configuration.
- Broad visual redesign or changes to toolbar action ordering.
- Any cleanup or mutation of retained `TURN-2026-09-02-001` runtime state or branch history.

# Required reconnaissance

Before editing:

- inspect the complete current `ContentView.swift` at the exact accepted base;
- confirm the macOS deployment target/current SDK context needed for the chosen SF Symbols;
- inspect existing tests and `./script/test.sh` sufficiently to understand the final gate;
- use relevant Git history only if needed to resolve intent that the current source does not answer.

Classify material assumptions as `RESOLVED_BY_EVIDENCE`, `SAFE_REVERSIBLE_ASSUMPTION`, or `MATERIAL_UNRESOLVED`. Stop only for a material unresolved ambiguity.

# Observation contract

After editing, inspect the complete diff against the accepted base and verify every behavioral change maps directly to a success criterion. No UI automation or manual app launch is required by this work order; product visual acceptance remains with control/product review after candidate materialization.

# Protected behavior and invariants

- Accepted catalog/data safety behavior remains untouched.
- Sort, filter, refresh, inspector, and review-next actions retain their existing semantics.
- Cover-size steps and press-and-hold repeat semantics remain unchanged except for endpoint disabling.
- Toolbar item ordering remains unchanged.
- No new architecture, abstraction, dependency, or reusable framework is introduced for this localized UI polish.

# Capability envelope

Authorized: `READ`, `REPO_WRITE`, `PROCESS`.

Not authorized: `NETWORK_READ` by the executor, `REMOTE_WRITE` by the executor, `HOST_MUTATION`, `DESTRUCTIVE`.

StringMaster may perform its ordinary conductor-owned candidate materialization and bounded remote transport after executor completion.

# Complexity budget

Zero complexity events are authorized. Do not add abstraction layers, dependencies, public APIs, schemas, persisted state, background processes, generalized extension points, or cross-component coupling. If a success criterion appears to require one, stop and report.

# Stop conditions

Stop without broadening scope if:

- exact accepted base cannot be established;
- assigned r2 branch is not the exact C1-prepared local branch at the accepted base;
- implementation requires a second source/test/project/resource file;
- the required grid-density metaphor cannot be expressed with suitable native SF Symbols on the target SDK;
- native toolbar treatment produces an ambiguity that requires a new custom glass surface;
- the single complete test run fails and the failure cannot be attributed to the authorized diff with direct evidence;
- any material unresolved product ambiguity remains after repository/SDK evidence.

# Commit and materialization contract

The executor does not stage, commit, switch branches, rebase, merge, tag, alter remotes, or touch the retained r1 branch/runtime state. StringMaster owns deterministic reconciliation and, if the final diff is valid and confined to the write root, materializes at most one candidate commit on:

`stringmaster/vitrine-toolbar-density-glass-r2`

Do not merge the candidate into an accepted or default branch.

# Push and transport contract

StringMaster may perform one ordinary non-force push of the valid r2 candidate branch. No force push, protected-ref mutation, release publication, retained-r1 mutation, or unrelated remote write is authorized.

# Final report

Report only:

- repository/base gate result;
- exact changed file;
- exact SF Symbol names used;
- toolbar glass changes made;
- confirmation that stepping/repeat semantics were preserved and endpoint disabling was added;
- complete-suite result;
- `git diff --check` result if run by the ordinary conductor;
- assumption ledger;
- complexity events (`none` expected);
- candidate branch/SHA if materialized;
- any blocker.

Do not claim acceptance.

# Spending controls

Use exact model `gpt-5.6-luna` at low reasoning, S1. Progress narration is prohibited. Maximum complete-suite runs: 1. Maximum evidence runs: 0.
