-- Synthetic Spell.dbc profile regressions, executed with official Lua 5.0.3.
-- Load the actual production classifier only; no WoW, SCRM or HearthDB mocks.
local file = assert(io.open("SCRM-DLSI.lua", "r"))
local source = file:read("*a")
file:close()
local first = assert(string.find(source, "local SCHOOL_NAMES = {", 1, true))
local last = assert(string.find(source, "local CORE_ADAPTERS = {}", first, true))
local classifierSource = string.sub(source, first, last - 1)

local spells = {}
local api = {}
function api.GetSpellSchoolByID(id) return 4, "Frost" end
function api.GetSpellMechanicByID(id)
    return spells[id].spellMechanic or 0
end
function api.GetSpellEffectMechanics(id) return spells[id].mechanics end
function api.GetSpellEffectInfo(id) return spells[id].effects end
function api.GetSpellDispelType(id) return spells[id].dispel or 0 end

local host = { ClassicAPI = api }
local environment = {}
setmetatable(environment, { __index = _G })
environment._G = environment
environment.__fixtureHost = host
environment.C_Spell = {
    GetSpellName = function(id) return "Synthetic " .. id end,
}
environment.GetSpellRecField = function(id, field)
    if field == "targetCreatureType" then return spells[id].targetCreatureType end
end

local run = assert(loadstring(
    "local CleveRoids = _G.__fixtureHost\n" ..
    "local Pipeline = {}\n" .. classifierSource .. "\nreturn Pipeline"))
setfenv(run, environment)
local profiles = run()

local checks = 0
local function eq(got, want, message)
    checks = checks + 1
    if got ~= want then
        error(message .. ": expected " .. tostring(want) ..
            ", got " .. tostring(got), 2)
    end
end
local function fixture(id, data)
    spells[id] = data
    return assert(profiles.GetSpellProfile(id))
end
local function raw(effectID, auraType)
    return { effect = effectID, auraName = auraType }
end
local function dims(profile)
    return table.concat(profile.mechanicDimensions, ",")
end

-- Spell-level stun must not hide an unrelated explicit root or aura fallback.
local mixed = fixture(9101, {
    spellMechanic = 12,
    effects = { raw(6, 26), raw(6, 12), raw(0, 0) },
    mechanics = { 7, 0, 0 },
})
eq(mixed.spellMechanicDimension, "stun", "spell mechanic")
eq(dims(mixed), "stun,root", "mixed explicit and fallback dimensions")
eq(mixed.effects[1].effectIndex, 1, "effect slot identity")
eq(mixed.effects[1].mechanicID, 7, "raw mechanic retained")
eq(mixed.effects[1].mechanicDimension, "root", "explicit root")
eq(mixed.effects[1].mechanicSource, "effect_mechanic", "explicit source")
eq(mixed.effects[2].mechanicDimension, "stun", "fallback across explicit slots")
eq(mixed.effects[2].mechanicSource, "aura_fallback", "fallback source")
eq(mixed.effects[3].classification, "inactive", "zero slot inactive")
eq(mixed.effectClassificationComplete, true, "known effect classifications")
eq(mixed.targetApplicabilityComplete, false, "target metadata not exposed")

-- A nonzero unrecognised mechanic must NEVER fall back to MOD_ROOT.
local unknownMechanic = fixture(9102, {
    effects = { raw(6, 26), raw(0, 0), raw(0, 0) },
    mechanics = { 999, 0, 0 },
})
eq(unknownMechanic.effects[1].mechanicDimension, nil, "unknown mechanic blocks fallback")
eq(unknownMechanic.effects[1].mechanicID, 999, "unknown mechanic ID retained")
eq(unknownMechanic.effects[1].classification, "unknown_nonzero_mechanic", "explicit unknown")
eq(unknownMechanic.effects[1].mechanicSource, "unmodelled_mechanic", "unknown source")
eq(unknownMechanic.effectClassificationComplete, false, "unknown fails closed")
eq(dims(unknownMechanic), "", "unknown does not fabricate root")

local root = fixture(9103, {
    effects = { raw(6, 26), raw(0, 0), raw(0, 0) },
    mechanics = { 0, 0, 0 },
})
eq(root.effects[1].mechanicDimension, "root", "AuraType 26 MOD_ROOT")
eq(root.effects[1].mechanicSource, "aura_fallback", "root fallback provenance")
eq(dims(root), "root", "root aggregate")

local taunt = fixture(9104, {
    effects = { raw(6, 11), raw(0, 0), raw(0, 0) },
    mechanics = { 0, 0, 0 },
})
eq(taunt.effects[1].auraType, 11, "AuraType 11 retained")
eq(taunt.effects[1].mechanicDimension, nil, "taunt is not root")
eq(dims(taunt), "", "taunt does not add CC")
eq(taunt.effects[1].classification, "unmodelled_aura", "taunt unmodelled")

-- TargetCreatureType is a whole-spell restriction, not per-slot targeting.
-- The real APIs return no per-effect implicit target metadata.
local restricted = fixture(9105, {
    targetCreatureType = 4,
    effects = { raw(6, 26), raw(0, 0), raw(0, 0) },
    mechanics = { 0, 0, 0 },
})
eq(restricted.targetCreatureType, 4, "restriction preserved")
eq(restricted.effects[1].targetApplicability, "unknown", "unknown effect target")
eq(restricted.effects[1].targetSource, "unavailable", "not invented target")
eq(restricted.effects[2].targetApplicability, "inactive", "inactive target")
eq(restricted.targetApplicabilityComplete, false, "unknown targeting marked")

-- Mechanics without raw effect IDs do not prove an effect is active.
local absentRaw = fixture(9106, { mechanics = { 7, 0, 0 } })
eq(absentRaw.effects[1].effectID, nil, "missing raw ID")
eq(absentRaw.effects[1].active, nil, "missing effect activity")
eq(absentRaw.effects[1].mechanicDimension, nil, "no dimension without activity")
eq(absentRaw.effectClassificationComplete, false, "incomplete raw metadata")
eq(dims(absentRaw), "", "missing raw cannot fabricate root")

-- Missing effect mechanic table is not equivalent to a DBC zero.
local absentMechanic = fixture(9107, {
    effects = { raw(6, 26), raw(0, 0), raw(0, 0) },
})
eq(absentMechanic.effects[1].mechanicID, nil, "missing mechanic differs from zero")
eq(absentMechanic.effects[1].mechanicDimension, nil, "no fallback on missing mechanic")
eq(absentMechanic.effects[1].classification, "unknown_mechanic", "unknown metadata")
eq(absentMechanic.effectClassificationComplete, false, "missing mechanics incomplete")

-- Malformed zero slot's aura must not produce an active dimension.
local unused = fixture(9108, {
    effects = { raw(0, 26), raw(0, 0), raw(0, 0) },
    mechanics = { 0, 0, 0 },
})
eq(unused.effects[1].classification, "inactive", "inactive wins over aura")
eq(dims(unused), "", "inactive aura cannot be a candidate")
eq(unused.hasAura, false, "inactive aura ignored")

eq(profiles.GetSpellProfile(9103), root, "profile cache identity")
profiles.ClearSpellCache()
local afterClear = profiles.GetSpellProfile(9103)
eq(afterClear ~= root, true, "cache clear")
eq(dims(afterClear), "root", "cache rebuild")

print("PASS: " .. checks .. " DBC profile fixture checks (Lua 5.0.3)")
