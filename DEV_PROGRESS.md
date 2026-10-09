# Development Progress

## Current
- Branch: `dev`
- Version: `0.1.0-dev` (scaffold only)
- Development head: Initial scaffold commit (verify actual remote HEAD at resume).
- Stable baseline: None; `main` is the README-only repository baseline.
- Goal: Extract the advanced SCRM immunity system into an independently maintained companion addon.
- Current scope boundary: Workflow/bootstrap documentation and minimal addon skeleton; no learner extraction or upstream-hook implementation yet.

## Current Design / Development Contract

### Architecture / Ownership
- Addon: `SCRM-DLSI` / `SCRM_DLSI` (Deep Learning Super Immunities), a companion plugin requiring brues-code/SuperCleveRoidMacros.
- Unmodified upstream SCRM is the host macro engine and must operate independently when no plugin is installed.
- DLSI owns advanced immunity observations, transient guards, HearthDB-backed knowledge, learning, diagnostics, alerts and its own UI.
- Integrate through a **generic, open immunity-provider extension API**, not a DLSI-specific interface.
- Upstream integration is planned on `Seraphic8x2244/SuperCleveRoidMacros:immunities-hook`, created from upstream-mirroring `main`; a PR to brues is not yet implemented/submitted.
- The Blizzard macro window should expose an `Immunity Provider` button immediately left of the character-specific macros tab when >=1 external provider has registered; show a selector with SCRM built-in as default. Final API/UI contract still needs source-verified design.

### Invariants
- Preserve existing `[immune]` and `[noimmune]` macro syntax, including the bare action form.
- Preserve the proven conservative learner behavior and exclusions (player targets, temporary immunity, TempCC, reflection, DR, death, ambiguous IMMUNE/IMMUNE2) during extraction.
- Preserve the HearthDB database filename `SuperCleveRoidMacros_Immunity.db` and schema/learner data, without destructive migration.
- SCRM legacy `CleveRoids_ImmunityData` records remain untouched, and built-in behavior is unchanged when selected.
- External provider selection must avoid competing automatic learners and contradictory sources. Proposed behavior: one selected authoritative provider, built-in default; storage failures require explicit status and agreed fallback rather than silent data mixing.
- No unsupported assumptions of cross-core runtime compatibility; vMaNGOS and Turtle/Octo need live validation.
- SCRM `main` must stay an upstream mirror; do not move fork-only learner code there.

### Protocol / Data Model
- Generic provider registration, query delegation, selection/persistence, activation/availability and built-in learning suppression are **proposed**, not implemented.
- Multiple providers may register. User chooses provider rather than relying on load order; initial discussion favored per-character selection, subject to final confirmation.
- The relevant upstream query entry point is `CleveRoids.CheckImmunity(unit, spellOrSchool)`; upstream has several independent automatic writes, including direct SavedVariables writes, so a query wrapper alone is insufficient.
- Existing branch-specific implementation and detailed learner semantics: `Seraphic8x2244/SuperCleveRoidMacros`, `design/temp-cc-immunity`, `docs/CC-DR-IMMUNITY-REWORK.md`; current reference commit `de4b82e2`.

### Active Decisions
- Agree precise registration API, query-result contract, provider names, availability/failure policy, UI and legacy automatic learner bypass before implementation.
- Decide which presentation/management functions remain accessible through host SCRM and which are DLSI-owned.

## Recent Relevant Commits
- Host immunity prototype branch reference: `de4b82e2`.
- Host generic-hook branch initially created from upstream mirror: `37ca7cef`.

## Completed / User-Verified
- Design direction agreed: open-provider upstream PR and separate SCRM-DLSI plugin.
- Source inspection confirmed shared upstream conditional hook `CleveRoids.CheckImmunity` and multiple legacy writes.

## Implemented / Awaiting Runtime Test
- None. Template scaffold is not a functioning immunity plugin.

## Static / Automated Checks
- Template source read and repository states inspected; Lua compiler and WoW runtime checks not run.

## Current Issues
- No safe upstream hook or legacy-write bypass has been implemented.
- The five dedicated advanced immunity modules also depend on fork-specific `Utility.lua` logic and startup wiring.
- Full historical evidence trail for resolved alert display remains incomplete in the prototype.

## Testing
### Last Runtime Test
- DLSI version/commit: None.
- Passed: None.
- Failed: None.
- Not tested: All DLSI runtime behavior.

### Next Runtime Test
- Only after hook and extraction implementation, validate SCRM alone, selected DLSI provider, switching, missing DB, legacy preservation, query semantics, live learning and persistence.

## Planned / Next Work
- Review the open generic provider-hook design and testable legacy learning gate, then implement the bounded upstream PR in `immunities-hook`.
- Extract the existing five immunity modules and fork-local helpers into DLSI with explicit ownership, without changing inference semantics.

## Deferred / Out of Scope
- Slice 8 runtime matrix, broad immunity promotion and unrequested learner changes.
- No fork-to-main merge or legacy-data deletion.

## Release / Promotion Notes
- Preserve README-only stable `main` until a tested stable release is authorized.
- Dependencies: brues-code SCRM; existing upstream client requirements; HearthDB for DLSI learning.
- Lua 5.0.3 checker is maintained in VanillaTemplate at `tools/lua50/` and may be run there against this checkout when needed.

## Exact Next Step
Agree the minimal generic upstream-provider API and safe suppression of every automatic legacy learner mutation, including direct SavedVariables writes, before extracting or implementing DLSI.
