-- Chat 4: production HearthDB v3 migrator exercised through a faithful
-- HearthDB call boundary; SQL is also emitted for real SQLite rehearsal.
local file = assert(io.open("SCRM-DLSI.lua", "r"))
local source = file:read("*a"); file:close()
local function extract(firstText, lastText, functionName)
    local first = assert(string.find(source, firstText, 1, true))
    local last = assert(string.find(source, lastText, first, true))
    local env = {}; setmetatable(env, { __index = _G }); env._G = env
    local loader = assert(loadstring(string.sub(source, first, last - 1) ..
        "\nreturn " .. functionName))
    setfenv(loader, env)
    return loader()
end
local migrate = extract("local function MigrateHearthDBV3(storage)",
    "-- Chunk C integration:", "MigrateHearthDBV3")
local repairV1 = extract("local function RepairLegacyAuraFallbackFacts(storage, DLSI)",
    "-- v2 did not retain", "RepairLegacyAuraFallbackFacts")
local n = 0
local function check(ok, message)
    n = n + 1
    if not ok then error(message, 2) end
end
local function has(hay, needle)
    return string.find(hay or "", needle, 1, true) ~= nil
end

local function makeStorage(config)
    config = config or {}
    local calls, version, staged = {}, config.version or 2, false
    local storage = { SCHEMA_VERSION = 3, schemaVersion = config.version or 2 }
    storage.Query = function(sql)
        if sql == "PRAGMA user_version" then
            return true, { { user_version = config.badVersion and 19 or version } }
        end
        if sql == "PRAGMA integrity_check" then
            return true, { { integrity_check = config.corrupt and "not ok" or "ok" } }
        end
        if sql == "PRAGMA foreign_key_check" then
            if config.badForeign or (staged and config.badForeignPost) then
                return true, { { table = "hypothesis_candidates" } }
            end
            return true, {}
        end
        if has(sql, "FROM sqlite_master") then
            return true, config.archiveCollision and { { name = "dlsi_v3_fact_backup" } } or {}
        end
        if has(sql, "AS legacy_facts") then
            if config.badCounts then return true, { { legacy_facts = "invalid" } } end
            return true, { { legacy_facts = config.facts or 5,
                legacy_hypotheses = config.hypotheses or 2,
                legacy_candidates = config.candidates or 3 } }
        end
        if has(sql, "AS archived_facts") then
            return true, { { archived_facts = config.badArchive and 0 or (config.facts or 5),
                archived_hypotheses = config.hypotheses or 2,
                archived_candidates = config.candidates or 3,
                remaining_facts = 0, remaining_hypotheses = 0, remaining_candidates = 0 } }
        end
        error("unexpected SQL query: " .. sql)
    end
    storage.Execute = function(sql)
        table.insert(calls, sql)
        if has(sql, "BEGIN IMMEDIATE;") then
            if config.failStage then return false, "synthetic failure" end
            staged = true
        elseif has(sql, "PRAGMA user_version = 3;") then
            if config.failCommit then return false, "synthetic commit failure" end
            version = 3; staged = false
        elseif has(sql, "ROLLBACK;") then
            staged = false
        else
            error("unexpected SQL execute: " .. sql)
        end
        return true
    end
    return storage, calls
end

local storage, calls = makeStorage()
local ok, result = migrate(storage)
check(ok and result.facts == 5 and result.hypotheses == 2 and
    result.candidates == 3, "migrator expected archive counts")
check(storage.schemaVersion == 3 and table.getn(calls) == 2,
    "version advances only after commit")
check(has(calls[1], "BEGIN IMMEDIATE;") and
    has(calls[1], "dlsi_v3_fact_backup") and
    has(calls[1], "dlsi_v3_hypothesis_backup") and
    has(calls[1], "dlsi_v3_hypothesis_candidate_backup"),
    "three archives staged transactionally")
check(has(calls[1], "substr(proof_source,1,10) = 'ambiguous_'"),
    "all ambiguous proof sources selected without spell/mob allowlist")
check(has(calls[1], "DELETE FROM hypotheses;") and
    has(calls[1], "DELETE FROM hypothesis_candidates;"),
    "v2 untyped hypotheses retired only after backup")
check(not has(calls[1], "DELETE FROM mobs") and
    not has(calls[1], "DROP TABLE facts"),
    "migration must not reset or wipe unrelated facts")
check(calls[2] == "PRAGMA user_version = 3;\nCOMMIT;",
    "schema marker committed last")
local output = assert(io.open("tests/migration_generated.sql", "w"))
output:write(calls[1], "\n", calls[2], "\n"); output:close()

local cases = {
    { tag = "invalid schema version", options = {version = 4}, rollback = false },
    { tag = "version mismatch", options = {badVersion = true}, rollback = false },
    { tag = "integrity failure", options = {corrupt = true}, rollback = false },
    { tag = "foreign key failure", options = {badForeign = true}, rollback = false },
    { tag = "old archive collision", options = {archiveCollision = true}, rollback = false },
    { tag = "missing valid counts", options = {badCounts = true}, rollback = false },
    { tag = "staging failure", options = {failStage = true}, rollback = true },
    { tag = "archive count mismatch", options = {badArchive = true}, rollback = true },
    { tag = "staged FK violation", options = {badForeignPost = true}, rollback = true },
    { tag = "commit failure", options = {failCommit = true}, rollback = true },
}
local i
for i = 1, table.getn(cases) do
    local case = cases[i]
    local fake, statements = makeStorage(case.options)
    local pass = migrate(fake)
    check(not pass and fake.schemaVersion ~= 3, case.tag .. " must fail closed")
    if case.rollback then
        check(has(statements[table.getn(statements)], "ROLLBACK;"),
            case.tag .. " must issue rollback")
    else
        check(table.getn(statements) == 0,
            case.tag .. " must not write anything")
    end
end
local noOp, noOpSQL = makeStorage({version = 3})
local skipped, counts = migrate(noOp)
check(skipped and counts.facts == 0 and table.getn(noOpSQL) == 0,
    "rerunning on v3 is a no-op")

-- Existing v1 aura repair remains the mandatory first stage of v1->v2->v3.
local v1Statements, v1Version = {}, 1
local v1Storage = {
    schemaVersion = 1, SCHEMA_VERSION = 3,
    SQLText = function(v) return "'" .. v .. "'" end,
}
v1Storage.Query = function(sql)
    if has(sql, "GROUP BY dimension") then
        return true, { { dimension = "root", proof_spell_id = 6795, fact_count = 90 } }
    end
    if sql == "PRAGMA user_version" then
        return true, { { user_version = v1Version } }
    end
    error("unexpected v1 SQL query: " .. sql)
end
v1Storage.Execute = function(sql)
    table.insert(v1Statements, sql)
    if has(sql, "PRAGMA user_version = 2;") then v1Version = 2 end
    return true
end
local repaired, removed = repairV1(v1Storage, {
    ImmunityObservations = { GetSpellProfile = function()
        return { name = "Synthetic Taunt", effects = { { auraName = 11 } } }
    end },
    ImmunityKnowledge = { GetSuccessDimensions = function() return {} end },
})
check(repaired and removed == 90 and v1Storage.schemaVersion == 2,
    "v1 aura repair must advance to v2 with copied evidence")
check(has(v1Statements[1], "dlsi_aura_repair_backup") and
    has(v1Statements[1], "PRAGMA user_version = 2;"),
    "v1 aura backup is retained before v3")
local v1SQL = assert(io.open("tests/migration_generated_v1.sql", "w"))
v1SQL:write(v1Statements[1], "\n"); v1SQL:close()
local migratedFromV1, v1stage = makeStorage()
local passed = migrate(migratedFromV1)
check(passed and migratedFromV1.schemaVersion == 3,
    "v1-v2-v3 path permits subsequent v3 migration")
print("PASS: " .. n .. " HearthDB v3 migration assertions (Lua 5.0.3)")
