# Development Progress

## Current
- Branch: `dev`
- Version: `0.1.0-dev` (scaffold only)
- Development head before this documentation update: `c73458d854540d39575b73c2129ae8fe33dfb204` (verify current remote HEAD at resume).
- Stable baseline: None; `main` is the README-only repository baseline.
- Goal: Extract the advanced SCRM immunity system into an independently maintained companion addon.
- Current scope boundary: DLSI remains a scaffold, with no learner extraction or DLSI runtime implementation. The independent host hook is implemented on SCRM's `immunities-hook` branch, pending refinement/validation.

## Current Design / Development Contract

### Architecture / Ownership
- Addon: `SCRM-DLSI` / `SCRM_DLSI` (Deep Learning Super Immunities), a companion plugin requiring brues-code/SuperCleveRoidMacros.
- Unmodified upstream SCRM is the host macro engine and must operate independently when no plugin is installed.
- DLSI owns advanced immunity observations, transient guards, HearthDB-backed knowledge, learning, diagnostics, alerts and its own UI.
- Integrate through a **generic, open immunity-provider extension API**, not a DLSI-specific interface.
- Upstream integration has been implemented (not submitted as a PR) on `Seraphic8x2244/SuperCleveRoidMacros:immunities-hook`, latest reviewed HEAD `b5fab176cf67018b4be594ad067346579630110d`, based on upstream-mirroring `main` `37ca7cef4012cc0d76b7e559ac9517c785dbae79`. Do not use upstream `main` for the hook until approved/merged.
- The Blizzard macro window always exposes an `Immunity Provider:` row and standard Blizzard dropdown above the Delete / New / Exit footer, without modifying macro tabs. With no external provider, SCRM Built-in is its sole option. Initial left-of-tab UI was observed overlapping/skinning poorly in-game, so host `immunities-hook` was revised at `1e9efbfd` (docs `bcf9f787`); the new footer layout and dropdown still require in-game validation.

### Invariants
- Preserve existing `[immune]` and `[noimmune]` macro syntax, including the bare action form.
- Preserve the proven conservative learner behavior and exclusions (player targets, temporary immunity, TempCC, reflection, DR, death, ambiguous IMMUNE/IMMUNE2) during extraction.
- Preserve the HearthDB database filename `SuperCleveRoidMacros_Immunity.db` and schema/learner data, without destructive migration.
- SCRM legacy `CleveRoids_ImmunityData` records remain untouched, and built-in behavior is unchanged when selected.
- External provider selection must prevent competing automatic learners and contradictory sources. **Agreed: no hybridisation or silent failover.** SCRM Built-in is the default and behaves unchanged for ordinary users; when an external provider is selected, all automatic built-in learning/removal is dormant regardless of provider availability/health. Broken/unavailable external results are unknown, not `false`; both positive and negative immunity conditionals fail conservatively. Users explicitly select built-in to restore it.
- No unsupported assumptions of cross-core runtime compatibility; vMaNGOS and Turtle/Octo need live validation.
- SCRM `main` must stay an upstream mirror; do not move fork-only learner code there.


### Final provider ownership decision (2026-10-10)
- Normal SCRM must behave exactly as upstream when built-in is selected or no provider is configured.
- A selected external provider is the sole authoritative immunity source. No hybrid answers, built-in fallback, learning supplementation, inferred answers, or hole-patching by SCRM.
- SCRM's automatic legacy learning and removal stays dormant for the full duration of external selection, including provider errors, missing providers, and unknown results. Existing data is never merged, migrated, reset, or deleted by the integration.
- The provider owns the distinction between established immune, established vulnerable, and unknown (insufficient learning). Operational provider failure is separate. Unknown does not justify guessing; neither positive nor negative conditionals should turn unavailable information into certainty.
- DLSI's established learner, evidence handling, uncertainty, safeguards, storage and alerts are not to be modified. Integration adapts at the interface only.
- Current host hook is a draft and violates the agreed failure semantics: selected-provider errors currently activate built-in fallback. Its boolean-only contract also needs a way to retain unknown without conflating it with vulnerability. Correct this before DLSI integration or an upstream PR.

### Protocol / Data Model
- SCRM hook implementation currently exposes `CleveRoids.RegisterImmunityProvider(id, displayName, check)`; `check(unitId, spellOrSchool)` must return a boolean. It also exposes `GetSelectedImmunityProvider`, `GetActiveImmunityProvider`, `IsExternalImmunityActive`, `QueryExternalImmunity`, and `SelectImmunityProvider`. This is an implemented *host draft*, not yet a runtime-proven contract.
- Multiple providers can register. User selection is explicit and **account-wide** in `CleveRoidMacros.immunityProvider` (rather than per-character). SCRM built-in is default. The existing host draft currently falls back to built-in after a missing/failed selected provider; **this is a confirmed defect and must be corrected before DLSI integration**. Agreed contract: SCRM built-in runs only when explicitly selected or as the initial default. Any selected external provider is solely authoritative, even when missing, broken or unable to query; unknown/error must make both `[immune]` and `[noimmune]` fail conservatively, and no automatic built-in learning/removal resumes. Never blend external and legacy data. Preserve the selected provider and existing storage without migration or deletion.
- The relevant upstream query entry point is `CleveRoids.CheckImmunity(unit, spellOrSchool)`; upstream has several independent automatic writes, including direct SavedVariables writes, so a query wrapper alone is insufficient.
- Existing branch-specific implementation and detailed learner semantics: `Seraphic8x2244/SuperCleveRoidMacros`, `design/temp-cc-immunity`, `docs/CC-DR-IMMUNITY-REWORK.md`; historical reference commit `3b37d154` for the agreed upstream hook scope. Re-read the active prototype branch HEAD before extraction.

### Active Decisions
- Before treating the host hook as an upstream PR candidate, review double-delegation through `CheckImmunity`/`CheckCCImmunity`, correct the prohibited built-in fallback on external-provider failure, tri-state conditional handling, UI placement, every automatic mutation path and Lua 5.0.3 compile compatibility. Keep the API generic, with no DLSI-specific references in SCRM.
- Decide which presentation/management functions remain accessible through host SCRM and which are DLSI-owned.

## Recent Relevant Commits
- Host immunity prototype branch reference: `de4b82e2`.
- Host generic-hook starting point: `37ca7cef`; implementation `e69cbd50`; API documentation/head `b5fab176` (4 changed files; +180/-3 lines versus SCRM main; no PR).

## Completed / User-Verified
- Design direction agreed: open-provider upstream PR and separate SCRM-DLSI plugin.
- Source inspection confirmed shared upstream conditional hook `CleveRoids.CheckImmunity` and multiple legacy writes.
- User tested SCRM `immunities-hook` with no provider: macro window and ordinary macro conditionals work. Legacy immunity learning and provider-present behaviour were **not** tested; these are host baseline observations, not DLSI runtime tests.

## Implemented / Awaiting Runtime Test
- **DLSI:** None; template scaffold is not a functioning immunity plugin.
- **SCRM host (separate repository):** Provider API, selection UI, query routing and identified automatic-write guards are committed, but not provider-present runtime validated.

## Static / Automated Checks
- DLSI template source and remote HEAD inspected; no DLSI Lua compiler or runtime test.
- SCRM hook diff reviewed: 4 files, 180 additions, 3 deletions. Targeted source presence checks passed; no canonical Lua 5.0.3 compiler pass or comprehensive test suite was run. The host no-provider macro-window/conditional behaviour was reported working in-game.

## Current Issues
- Host hook draft exists but is not yet fully validated or PR-ready. Check nested immunity-query routing, enforce the agreed no-hybrid/no-failover contract, macro UI placement and complete learner mutation coverage before dependent DLSI implementation.
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
- Refine and validate the generic SCRM host hook on `immunities-hook`; do not open a PR without user authorisation.
- Begin first DLSI functional development build on `dev` only after confirming the final registration/query/failure contract. Extract existing immunity modules and fork-local helpers with explicit ownership, without changing inference semantics. Bump DLSI's TOC version for runtime changes.

## Deferred / Out of Scope
- Slice 8 runtime matrix, broad immunity promotion and unrequested learner changes.
- No fork-to-main merge or legacy-data deletion.

## Release / Promotion Notes
- Preserve README-only stable `main` until a tested stable release is authorized.
- Dependencies: brues-code SCRM; existing upstream client requirements; HearthDB for DLSI learning.
- Lua 5.0.3 checker is maintained in VanillaTemplate at `tools/lua50/` and may be run there against this checkout when needed.

## Exact Next Step
Review and harden SCRM `immunities-hook` (particularly duplicate delegation, provider failure/fallback and automatic mutation coverage), complete available static checks, then implement the first SCRM-DLSI provider integration build on `dev`. Do not start Slice 8 or open an upstream PR yet.
