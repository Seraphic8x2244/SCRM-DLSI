# HearthDB v3 — backup, migration and recovery

This is a data-safety/recovery reference, not a live development handoff. Current development state belongs exclusively in `DEV_PROGRESS.md`.

## Before updating

1. Exit World of Warcraft completely and ensure HearthDB has closed its database.
2. Locate `SuperCleveRoidMacros_Immunity.db`. Copy the **entire closed database file** to a dated, separate safe location. Where SQLite write-ahead-log or journal sidecars exist, ensure the copy is a consistent closed-state snapshot including any required files. Do not copy an open database.
3. Preserve the original copy until the migrated build has been tested in-game and across a relog. Do not use the addon UI's manual reset function as a migration recovery tool.

DLSI does **not** make an automatic physical copy of the database: the runtime has HearthDB's SQLite API, not a safe arbitrary file-copy API. The migration's in-database archives preserve retired rows, **not** the entire database.

## What happens on startup

- Fresh empty database: create v3 directly.
- Existing v1: run the existing v1→v2 aura-fallback correction, keeping `dlsi_aura_repair_backup`; after its successful commit, attempt v2→v3.
- Existing v2: validate, then migrate v2→v3 in a separate transaction.
- Existing v3: validate the live schema and archive table columns; **no migration**.
- Unsupported versions, existing unversioned tables, invalid integrity/FK, archive name collisions or SQL errors: **fail closed**; the provider does not register. Never silently reset.

The v3 migration first copies every active fact with `verdict='immune'` and `proof_source` beginning `ambiguous_` into `dlsi_v3_fact_backup` with `retirement_reason='unattributed_legacy_immune'`. It then removes only those active facts. This uses evidence provenance, **not spell IDs, creature IDs, or a predefined list**.

All persisted v2 hypotheses and their candidates are archived into `dlsi_v3_hypothesis_backup` and `dlsi_v3_hypothesis_candidate_backup`, then retired. Old v2 candidate rows do not establish the typed completeness needed by the new confidence gate. Unrelated active facts and the earlier aura backup remain intact.

Backup verification, remaining-live-row checks and foreign-key checks happen **before** the v3 transaction commits. A failure rolls it back. In the v1→v2→v3 sequence, the earlier v1→v2 commit is a separate completed transaction; if the v3 stage fails, the database can safely remain at v2 and retry after correcting the error.

## Read-only audit (outside the game)

Open a **copy** in a trusted SQLite tool, not the active file. Example read-only SQL:

```sql
PRAGMA user_version;
PRAGMA integrity_check;
PRAGMA foreign_key_check;
SELECT COUNT(*) FROM dlsi_v3_fact_backup;
SELECT COUNT(*) FROM dlsi_v3_hypothesis_backup;
SELECT COUNT(*) FROM dlsi_v3_hypothesis_candidate_backup;
SELECT mob_id, dimension, proof_source, proof_spell_id, proof_event, retirement_reason
FROM dlsi_v3_fact_backup ORDER BY mob_id, dimension;
```

Schema 3 and empty integrity/FK errors are expected; archive counts depend on the actual historical file. No particular number of Frost, Fear, or other facts is required.

## Recovery

- If startup reports a migration failure, **stop** and retain both the current database and the cold backup. Capture the exact message/version; do not retry by deleting tables or changing `PRAGMA user_version`.
- For a full rollback to the prior state, close WoW/HearthDB, preserve the failed/migrated database for diagnosis, then restore the **entire pre-update cold backup**. Run a compatible previous addon build only if appropriate; the newer build will otherwise attempt migration again.
- The in-database archive tables are for auditing and case-by-case recovery. **Do not automatically insert retired ambiguous immune facts back into live `facts`**: doing so restores precisely the unsupported conclusions this migration retracts.
- Schema v3 cannot safely be consumed by an old schema-v2 build. Never masquerade v3 as v2 by only changing the version pragma.

## Validation status

Automated Lua 5.0.3 regression and real SQLite rehearsals passed on a **synthetic** dataset modeled after the reported historical Frost/Fear and legacy aura examples. The user's original file bytes were not available for a copy-based rehearsal. Live HearthDB behavior, actual user-file migration, and physical cold-file restoration remain untested pending Chat 5 and user runtime checks.
