# Development Progress

## Current
- Branch: `dev`
- Version: `0.1.0-dev` (scaffold only)
- Development checkpoint before this documentation update: `9722816f9c0feee47406fe7f274a587ccd5253df`. Verify the live `dev` HEAD before resuming.
- Stable baseline: None; `main` is the README-only repository baseline.
- Goal: Extract the advanced SCRM immunity system into an independently maintained companion addon.
- Current scope boundary: DLSI remains a scaffold, with no learner extraction or DLSI runtime implementation. The independent host hook is implemented on SCRM's `immunities-hook` branch, with its no-hybrid query/learning correction committed; Lua 5.0.3 compilation and provider-present runtime validation are still outstanding.

## Current Design / Development Contract

### Architecture / Ownership
- Addon: `SCRM-DLSI` / `SCRM_DLSI` (Deep Learning Super Immunities), a companion plugin requiring brues-code/SuperCleveRoidMacros.
- Unmodified upstream SCRM is the host macro engine and must operate independently when no plugin is installed.
- DLSI owns advanced immunity observations, transient guards, HearthDB-backed knowledge, learning, diagnostics, alerts and its own UI.
- Integrate through a **generic, open immunity-provider extension API**, not a DLSI-specific interface.
- Upstream integration has been implemented (not submitted as a PR) on `Seraphic8x2244/SuperCleveRoidMacros:immunities-hook`, latest implementation HEAD `bc0a488b051775f128b3d05db03876b15e747061`, based on upstream-mirroring `main` `37ca7cef4012cc0d76b7e559ac9517c785dbae79`. Do not use upstream `main` for the hook until approved/merged.
- The Blizzard macro window always exposes an `Immunity Provider:` row and standard Blizzard dropdown above the Delete / New / Exit footer, without modifying macro tabs. With no external provider, SCRM Built-in is its sole option. Initial left-of-tab UI was observed overlapping/skinning poorly in-game, so host `immunities-hook` was revised at `1e9efbfd` (docs `bcf9f787`); user runtime screenshot showed the footer dropdown overlapped Delete/New/Exit and Lua error at `ImmunityProviders.lua:87` (`UIDropDownMenu_CreateInfo` unavailable on Vanilla 1.12). Host fix `f4c0992d` replaced that helper with a plain table; user then confirmed **no Lua errors, dropdown appears, and SCRM Built-in displays/opens**, but the row sat too high above the character counter. Host layout-only fix `6a8205b4` now anchors the row to `MacroDeleteButton` `TOPLEFT` with a 2-unit gap and reduces its anchor frame height to 22; **this latest position awaits in-game verification**.

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
- The prior host hook violated failure semantics; this was corrected in `bc0a488b`. Registration now accepts boolean/nil results and no longer activates built-in queries/learning on external failure. The new contract remains source-checked, not provider-runtime validated; do not modify the DLSI learner to fit the host.

### Protocol / Data Model
- SCRM hook implementation exposes `CleveRoids.RegisterImmunityProvider(id, displayName, check)`; `check(unitId, spellOrSchool)` returns `true` known immune, `false` known vulnerable, or `nil` unknown/insufficient evidence. Operational callback failures are warned once and produce unknown without fallback. It also exposes `GetSelectedImmunityProvider`, `GetActiveImmunityProvider`, `IsExternalImmunityActive`, `QueryExternalImmunity`, and `SelectImmunityProvider`. This is an implemented *host draft*, not yet a runtime-proven contract.
- Multiple providers can register. User selection is explicit and **account-wide** in `CleveRoidMacros.immunityProvider` (rather than per-character). SCRM built-in is default. The original fallback defect was corrected on the host at `bc0a488b`: selected external authority now remains active during missing/failed-provider conditions, and nil is an accepted unknown result rather than false or an error. Agreed contract: SCRM built-in runs only when explicitly selected or as the initial default. Any selected external provider is solely authoritative, even when missing, broken or unable to query; unknown/error must make both `[immune]` and `[noimmune]` fail conservatively, and no automatic built-in learning/removal resumes. Never blend external and legacy data. Preserve the selected provider and existing storage without migration or deletion.
- The relevant upstream query entry point is `CleveRoids.CheckImmunity(unit, spellOrSchool)`; upstream has several independent automatic writes, including direct SavedVariables writes, so a query wrapper alone is insufficient.
- Existing branch-specific implementation and detailed learner semantics: `Seraphic8x2244/SuperCleveRoidMacros`, `design/temp-cc-immunity`, `docs/CC-DR-IMMUNITY-REWORK.md`; historical reference commit `3b37d154` for the agreed upstream hook scope. Re-read the active prototype branch HEAD before extraction.

### Active Decisions
- Host no-hybrid correction is committed. Complete canonical Lua 5.0.3 compilation when checker is executable, targeted provider-present runtime tests, and deferred Delete-button-anchored dropdown placement check before calling the hook validated or PR-ready. No fork-specific DLSI references in host SCRM.
- Decide which presentation/management functions remain accessible through host SCRM and which are DLSI-owned.

## Recent Relevant Commits
- Host immunity prototype branch reference: `de4b82e2`.
- Host generic-hook starting point: `37ca7cef`; foundation `e69cbd50`; UI anchor `6a8205b4`; exclusive provider query/automatic write isolation `bc0a488b` (6 files, +205/-7 lines versus SCRM main; no PR).

## Completed / User-Verified
- Design direction agreed: open-provider upstream PR and separate SCRM-DLSI plugin.
- Source inspection confirmed shared upstream conditional hook `CleveRoids.CheckImmunity` and multiple legacy writes.
- User tested SCRM `immunities-hook` with no provider: macro window and ordinary macro conditionals work. Legacy immunity learning and provider-present behaviour were **not** tested; these are host baseline observations, not DLSI runtime tests.

## Implemented / Awaiting Runtime Test
- **DLSI:** None; template scaffold is not a functioning immunity plugin.
- **SCRM host (separate repository):** Generic provider registration, persistent authority choice, nil/boolean query contract, single delegation, conservative unknown conditional handling, identified automatic write suppression and startup legacy-reset guard committed at `bc0a488b`. Source-reviewed but not tested with an external provider in-game. Built-in conditional semantics remain unchanged in source.

## Static / Automated Checks
- DLSI template source and remote HEAD inspected; no DLSI Lua compiler or runtime test.
- SCRM final hook diff reviewed against upstream mirror `main`: 6 files, +205/-7. Targeted static invariants PASS: selected authority independent of provider health; handled nil/true/false; CC wrapper avoids double delegation; `[noimmune]` fails on external unknown; four automatic record/remove functions guarded; direct delayed-bleed/shared-debuff and combat-log school writes guarded; startup version reset excluded during external selection; manual command mutations retained; no DLSI-specific host logic. This was source-level inspection, **not a Lua 5.0.3 compiler pass**. A compiler executable and checker sources were not available together in the active environment; the canonical VanillaTemplate checker was not run. SCRM's initial no-provider macro-window/conditional test passed in-game, and the dropdown subsequently opened with SCRM Built-in without Lua errors.

## Current Issues
- Host no-hybrid source correction is committed; remaining blockers for claiming complete validation are Lua 5.0.3 compiler check, external-provider in-game test (known true/false/unknown, missing/throwing provider, no legacy learner writes), and deferred UI placement check. Do not open upstream PR before review/approval.
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
- Validate the corrected generic SCRM host hook at `bc0a488b` using the canonical Lua 5.0.3 compiler and a temporary test provider (not shipped). Test selection, nil/true/false, missing/error, reload and automatic-write isolation; defer macro-row anchor check until next user runtime session. Do not open a PR without authorisation.
- Begin first DLSI functional development build on `dev` only after confirming the final registration/query/failure contract. Extract existing immunity modules and fork-local helpers with explicit ownership, without changing inference semantics. Bump DLSI's TOC version for runtime changes.

## Bounded Host Provider Integration Test Matrix (prepared; not run)
Use only a disposable test addon registering a deterministic provider with `CleveRoids.RegisterImmunityProvider`. Do not implement DLSI or mutate its inference engine.
1. SCRM alone: Built-in sole selector entry; legacy `[immune]`/`[noimmune]` and automatic learning remain baseline-compatible.
2. Register an external provider returning `true`; explicitly select it; verify `[immune]` succeeds and `[noimmune]` fails for the same unit/query.
3. Return `false`; verify `[immune]` fails and `[noimmune]` succeeds.
4. Return `nil`; verify **both** conditions fail (unknown, not vulnerable); test bare action syntax as well.
5. Throw an error and separately return an invalid value; verify one warning, unknown conservative results, no built-in fallback.
6. Reload with the selected external provider absent; verify selection persistence, visible unavailable entry, both conditions conservatively false, and **no** built-in automatic learning/removal.
7. For true/false/nil/error/missing cases, snapshot legacy SavedVariables and exercise relevant combat-log and delayed paths; verify zero automatic legacy mutations, including startup reset. Do not use manual mutation commands in this check.
8. Re-register/restore a provider and select it, then explicitly select Built-in; verify normal queries and automatic learner resume without deleting or merging stored records.
9. Check selector account-wide persistence across characters/reloads and registration/selection order.
10. Defer Delete-button-anchored macro-window placement verification to the next user UI session.

## 2026-10-10 Repository Verification / Bounded Audit
- GitHub remote refs verified at start: SCRM `immunities-hook` = `bc0a488b051775f128b3d05db03876b15e747061`; DLSI `dev` = `b60dc73956af435b2d28f7752856a6aace5fca8e`.
- Compared host against upstream-mirroring `37ca7cef`: 9 commits ahead, 0 behind, six changed files. Reviewed `ImmunityProviders.lua` and relevant `Init.lua` implementation: selected provider ID remains authoritative even if absent/error; valid answers are true/false/nil; invalid/throwing answers are marked failed and yield unknown; explicit Built-in selection required to restore fallback; startup legacy reset guarded while external selected. This is a **bounded source audit**, not a full codebase re-audit or runtime pass.
- Canonical Lua 5.0.3 compilation: **NOT RUN**. GitHub file retrieval was available, and shell has `gcc`/`git`, but no checkout/checker was mounted and shell GitHub DNS resolution failed. The canonical VanillaTemplate source and host checkout were therefore not available together for execution. Do not claim a syntax/compiler pass.
- Outstanding: canonical Lua 5.0.3 check across hook Lua files; broader legacy-write path audit; deterministic provider-present runtime matrix above. UI positioning explicitly deferred.
- This update is documentation only; no DLSI runtime code or SCRM hook changes, no version bump, no branch promotion and no PR.

## Deferred / Out of Scope
- Slice 8 runtime matrix, broad immunity promotion and unrequested learner changes.
- No fork-to-main merge or legacy-data deletion.

## Release / Promotion Notes
- Preserve README-only stable `main` until a tested stable release is authorized.
- Dependencies: brues-code SCRM; existing upstream client requirements; HearthDB for DLSI learning.
- Lua 5.0.3 checker is maintained in VanillaTemplate at `tools/lua50/` and may be run there against this checkout when needed.

## Exact Next Step
Run canonical Lua 5.0.3 compilation on the unchanged SCRM `immunities-hook` tree with VanillaTemplate checker in a shell that can access both trees. Complete outstanding legacy-write review and execute the prepared bounded test-provider matrix; keep dropdown positioning deferred. Do not extract DLSI, begin Slice 8 or open a PR without authorization.
