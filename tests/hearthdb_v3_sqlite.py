"""Execute the SQL emitted by the production Lua migrator against real SQLite.

The historical dataset is synthetic, shaped after the 119 root / four
ambiguous-immune facts described in the handoff; no user DB is modified.
"""
import sqlite3
from pathlib import Path


def make_db(version=2):
    db = sqlite3.connect(":memory:")
    db.execute("PRAGMA foreign_keys=ON")
    db.executescript("""
CREATE TABLE mobs (mob_id INTEGER PRIMARY KEY, last_name TEXT);
CREATE TABLE facts (
 mob_id INTEGER NOT NULL, dimension TEXT NOT NULL,
 verdict TEXT NOT NULL CHECK(verdict IN ('immune','vulnerable')),
 dynamic_suspected INTEGER NOT NULL DEFAULT 0 CHECK(dynamic_suspected IN (0,1)),
 proof_source TEXT, proof_spell_id INTEGER, proof_event TEXT,
 PRIMARY KEY(mob_id, dimension),
 FOREIGN KEY(mob_id) REFERENCES mobs(mob_id) ON DELETE CASCADE);
CREATE TABLE hypotheses (
 hypothesis_id INTEGER PRIMARY KEY AUTOINCREMENT, mob_id INTEGER NOT NULL,
 proof_source TEXT, proof_spell_id INTEGER, proof_event TEXT,
 FOREIGN KEY(mob_id) REFERENCES mobs(mob_id) ON DELETE CASCADE);
CREATE TABLE hypothesis_candidates (
 hypothesis_id INTEGER NOT NULL, dimension TEXT NOT NULL,
 PRIMARY KEY(hypothesis_id, dimension),
 FOREIGN KEY(hypothesis_id) REFERENCES hypotheses(hypothesis_id) ON DELETE CASCADE);
CREATE INDEX idx_hypotheses_mob_id ON hypotheses(mob_id);
CREATE TABLE dlsi_aura_repair_backup (
 mob_id INTEGER NOT NULL, dimension TEXT NOT NULL, verdict TEXT NOT NULL,
 dynamic_suspected INTEGER NOT NULL, proof_source TEXT,
 proof_spell_id INTEGER, proof_event TEXT, PRIMARY KEY(mob_id, dimension));
""")
    db.execute(f"PRAGMA user_version={version}")
    db.executemany("INSERT INTO mobs VALUES (?,?)",
                   [(i, f"Mob {i}") for i in range(1, 124)])
    immune = [
        (1, "frost", "immune", 0, "ambiguous_whole_spell", 122, "SPELL_MISS_OTHER:immune"),
        (2, "frost", "immune", 0, "ambiguous_whole_spell", 122, "SPELL_MISS_OTHER:immune"),
        (3, "fear", "immune", 0, "ambiguous_whole_spell", 8122, "SPELL_MISS_OTHER:immune"),
        (4, "fear", "immune", 0, "ambiguous_whole_spell", 8122, "SPELL_MISS_OTHER:immune"),
        (5, "dispel_magic", "immune", 0, "ambiguous_effect_mask_zero", 3, "IMMUNE2"),
        (6, "fire", "immune", 0, "authoritative_specific_effect", 10, "effect-proof"),
        (7, "frost", "vulnerable", 0, "authoritative_damage", 11, "damage"),
    ]
    db.executemany("INSERT INTO facts VALUES (?,?,?,?,?,?,?)", immune)
    db.executemany("INSERT INTO facts VALUES (?,?,?,?,?,?,?)", [
        (i, "root", "vulnerable", 0, "authoritative_aura",
         6795 if i <= 90 else 122, "aura") for i in range(8, 127)
         if i <= 123
    ])
    db.execute("INSERT INTO dlsi_aura_repair_backup VALUES (1,'charm','vulnerable',0,'authoritative_aura',1,'old')")
    db.executemany("INSERT INTO hypotheses VALUES (?,?,?,?,?)", [
        (10, 1, "ambiguous_whole_spell", 122, "IMMUNE"),
        (11, 3, "ambiguous_whole_spell", 8122, "IMMUNE")])
    db.executemany("INSERT INTO hypothesis_candidates VALUES (?,?)",
                   [(10, "frost"), (10, "root"), (11, "fear")])
    db.commit()
    return db


def snapshot(db):
    return {table: list(db.execute(f"SELECT * FROM {table} ORDER BY 1,2"))
            for table in ["facts", "hypotheses", "hypothesis_candidates",
                          "dlsi_aura_repair_backup"]}


def assert_ok(db):
    assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    assert db.execute("PRAGMA foreign_key_check").fetchall() == []


v3_sql = Path("tests/migration_generated.sql").read_text()
v1_sql = Path("tests/migration_generated_v1.sql").read_text()
assert "BEGIN IMMEDIATE;" in v3_sql and "PRAGMA user_version = 3;" in v3_sql
db = make_db()
original = snapshot(db)
db.executescript(v3_sql)
assert db.execute("PRAGMA user_version").fetchone()[0] == 3
assert_ok(db)
assert db.execute("SELECT COUNT(*) FROM dlsi_v3_fact_backup").fetchone()[0] == 5
assert db.execute("SELECT COUNT(*) FROM dlsi_v3_hypothesis_backup").fetchone()[0] == 2
assert db.execute("SELECT COUNT(*) FROM dlsi_v3_hypothesis_candidate_backup").fetchone()[0] == 3
assert db.execute("SELECT COUNT(*) FROM hypotheses").fetchone()[0] == 0
assert db.execute("SELECT COUNT(*) FROM hypothesis_candidates").fetchone()[0] == 0
assert db.execute("SELECT COUNT(*) FROM facts WHERE verdict='immune'").fetchone()[0] == 1
assert [x for x in original["facts"] if x[4] != "ambiguous_whole_spell"
        and x[4] != "ambiguous_effect_mask_zero"] == list(
    db.execute("SELECT * FROM facts ORDER BY 1,2"))
assert snapshot(db)["dlsi_aura_repair_backup"] == original["dlsi_aura_repair_backup"]
assert {x[0] for x in db.execute("SELECT mob_id FROM dlsi_v3_fact_backup")} == set(range(1,6))
assert {x[0] for x in db.execute("SELECT hypothesis_id FROM dlsi_v3_hypothesis_backup")} == {10,11}
# The pre-migration source rows remain independently and exactly recoverable.
assert list(db.execute("SELECT mob_id,dimension,verdict,dynamic_suspected,proof_source,proof_spell_id,proof_event FROM dlsi_v3_fact_backup ORDER BY 1,2")) == original["facts"][:5]
post = snapshot(db)
assert_ok(db)
assert snapshot(db) == post  # v3 startup is the checked Lua no-op, not a replay

# A failure mid-transaction leaves both schema and live facts unchanged.
db = make_db()
before = snapshot(db)
try:
    db.executescript(v3_sql.replace("DELETE FROM hypotheses;",
                                    "DELETE FROM table_that_does_not_exist;"))
except sqlite3.OperationalError:
    db.execute("ROLLBACK")
else:
    raise AssertionError("expected staged SQL failure")
assert db.execute("PRAGMA user_version").fetchone()[0] == 2
assert snapshot(db) == before
assert db.execute("SELECT name FROM sqlite_master WHERE name LIKE 'dlsi_v3_%'").fetchall() == []
assert_ok(db)

# v1 first performs the existing aura-provenance repair; then v3 retirement.
db = make_db(version=1)
db.executescript(v1_sql)
assert db.execute("PRAGMA user_version").fetchone()[0] == 2
assert db.execute("SELECT COUNT(*) FROM dlsi_aura_repair_backup").fetchone()[0] == 91
assert db.execute("SELECT COUNT(*) FROM facts WHERE dimension='root'").fetchone()[0] == 29
db.executescript(v3_sql)
assert db.execute("PRAGMA user_version").fetchone()[0] == 3
assert db.execute("SELECT COUNT(*) FROM dlsi_aura_repair_backup").fetchone()[0] == 91
assert db.execute("SELECT COUNT(*) FROM dlsi_v3_fact_backup").fetchone()[0] == 5
assert_ok(db)
print("PASS: real SQLite v2->v3, synthetic 2 Frost + 2 Fear + generic ambiguity,"
      " preserved facts/aura backups, rollback, FK/integrity, v1->v2->v3")
