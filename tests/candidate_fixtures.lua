-- Chat 2 typed candidate / uncertainty fixtures, on the official Lua 5.0.3 VM.
-- Load the genuine profile classifier and candidate builder, not reimplementations.
local file = assert(io.open("SCRM-DLSI.lua", "r"))
local source = file:read("*a")
file:close()
local profileFirst = assert(string.find(source, "local SCHOOL_NAMES = {", 1, true))
local profileLast = assert(string.find(source, "local CORE_ADAPTERS = {}", profileFirst, true))
local profileSource = string.sub(source, profileFirst, profileLast - 1)
local dimFirst = assert(string.find(source, "local CANDIDATE_DIMENSIONS = {", 1, true))
local dimLast = assert(string.find(source, "-- Broad facts", dimFirst, true))
local dimSource = string.sub(source, dimFirst, dimLast - 1)
local candidateFirst = assert(string.find(source, "local function buildCandidateModel(observation)", 1, true))
local candidateLast = assert(string.find(source, "local function hasApplicableTransientExplanation(", candidateFirst, true))
local candidateSource = string.sub(source, candidateFirst, candidateLast - 1)

local spells = {}
local api = {}
function api.GetSpellSchoolByID(id)
    return spells[id].schoolID, spells[id].school
end
function api.GetSpellMechanicByID(id) return spells[id].spellMechanic or 0 end
function api.GetSpellEffectMechanics(id) return spells[id].mechanics end
function api.GetSpellEffectInfo(id) return spells[id].effects end
function api.GetSpellDispelType(id) return spells[id].dispel or 0 end

local env = {}
setmetatable(env, { __index = _G })
env._G = env
env.__host = { ClassicAPI = api }
env.C_Spell = { GetSpellName = function(id) return "Synthetic " .. id end }
env.GetSpellRecField = function(id, field)
    if field == "targetCreatureType" then
        return spells[id].targetCreatureType
    end
end

local profileLoad = assert(loadstring("local CleveRoids = _G.__host\n" ..
    "local Pipeline = {}\n" .. profileSource .. "\nreturn Pipeline"))
setfenv(profileLoad, env)
local pipeline = profileLoad()
local builderLoad = assert(loadstring(dimSource .. "\n" .. candidateSource ..
    "\nreturn buildCandidateModel, hypothesisCandidates"))
setfenv(builderLoad, env)
local build, durable = builderLoad()

local checks = 0
local function eq(got, want, why)
    checks = checks + 1
    if got ~= want then
        error(why .. ": expected " .. tostring(want) ..
            ", got " .. tostring(got), 2)
    end
end
local function raw(effectID, auraType)
    return { effect = effectID, auraName = auraType }
end
local function make(id, data, failurePath, immuneVariant)
    spells[id] = data
    local profile = pipeline.GetSpellProfile(id)
    return {
        spell = profile, spellID = id, failurePath = failurePath or "whole_spell",
        immuneVariant = immuneVariant or "immune",
    }
end
local function dimensions(model)
    return table.concat(model.dimensions, ",")
end
local function findCandidate(model, dimension)
    local i
    for i = 1, table.getn(model.candidates) do
        if model.candidates[i].dimension == dimension then
            return model.candidates[i]
        end
    end
    return nil
end
local function reasonPresent(model, expected)
    local i
    for i = 1, table.getn(model.uncertainty) do
        if model.uncertainty[i] == expected then return true end
    end
    return false
end
local function applicable(observation)
    local i
    for i = 1, 3 do
        if observation.spell.effects[i].active then
            observation.spell.effects[i].targetApplicability = "applicable"
        end
    end
end

-- Frost Nova: school, spell mechanic, effect root, dispel, and duplicate
-- dimension provenance. Data are synthetic, not a live DBC assertion.
local frost = make(9201, {
    schoolID = 4, school = "Frost", spellMechanic = 7, dispel = 1,
    effects = { raw(6, 26), raw(0, 0), raw(0, 0) },
    mechanics = { 7, 0, 0 },
})
local f = build(frost)
eq(dimensions(f), "dispel_magic,frost,root", "Frost Nova alternatives")
eq(f.immuneVariant, "immune", "raw variant preserved")
eq(f.unmodelledAlternative, true, "unknown target is alternative")
eq(f.complete, false, "unknown target cannot be exhaustive")
eq(f.persistenceEligible, false, "no unsafe persistence")
eq(table.getn(durable(frost)), 0, "flat learner receives no partial set")
eq(reasonPresent(f, "unknown_effect_target:1"), true, "target uncertainty")
local root = assert(findCandidate(f, "root"))
eq(table.getn(root.provenance), 2, "root spell/effect dedup retains origins")
eq(root.provenance[1].origin, "spell_mechanic", "root spell origin")
eq(root.provenance[2].origin, "effect", "root effect origin")
eq(root.provenance[2].effectIndex, 1, "root effect slot")
eq(root.provenance[2].mechanicID, 7, "root DBC mechanic")
eq(root.provenance[2].targetApplicability, "unknown", "root target provenance")
eq(findCandidate(f, "dispel_magic").provenance[1].origin, "dispel_family", "dispel origin")
eq(findCandidate(f, "frost").provenance[1].origin, "school", "school origin")
applicable(frost)
f = build(frost)
eq(f.complete, true, "synthetic fully known target")
eq(f.persistenceEligible, true, "fully modelled whole spell eligible")
eq(table.concat(durable(frost), ","), "dispel_magic,frost,root", "flat adapter for eligible set")

-- Even a complete profile must not cross the IMMUNE/IMMUNE2 source boundary.
frost.immuneVariant = "immune2"
local inconsistent = build(frost)
eq(reasonPresent(inconsistent, "raw_variant_path_mismatch"), true,
    "raw IMMUNE2 with whole-spell interpretation is inconsistent")
eq(inconsistent.persistenceEligible, false, "variant mismatch cannot learn")
frost.immuneVariant = "immune"

-- Psychic Scream: different sources of Fear dedupe to one typed dimension.
local scream = make(9202, {
    schoolID = 5, school = "Shadow", spellMechanic = 5,
    effects = { raw(6, 7), raw(6, 7), raw(0, 0) },
    mechanics = { 5, 0, 0 },
})
applicable(scream)
local s = build(scream)
eq(dimensions(s), "fear,shadow", "Psychic Scream alternatives")
eq(table.getn(findCandidate(s, "fear").provenance), 3, "fear sources preserved")
eq(findCandidate(s, "fear").provenance[2].mechanicSource,
    "effect_mechanic", "explicit source")
eq(findCandidate(s, "fear").provenance[3].mechanicSource,
    "aura_fallback", "fallback source")
eq(s.complete, true, "fully modelled fear synthetic")

-- Rake: primary damage + independent second-slot bleed.
local rake = make(9203, {
    schoolID = 0, school = "Physical",
    effects = { raw(2, 0), raw(6, 0), raw(0, 0) },
    mechanics = { 0, 15, 0 },
})
local rk = build(rake)
eq(dimensions(rk), "bleed,physical", "Rake physical and bleed")
eq(findCandidate(rk, "bleed").provenance[1].effectIndex, 2, "bleed slot 2")
eq(rk.complete, false, "damage effect type and target still unresolved")
eq(reasonPresent(rk, "unmodelled_effect_type:1"), true, "primary effect unknown")
eq(table.getn(durable(rake)), 0, "Rake incomplete not promoted")

-- Rip: single bleed effect is potential even when event is IMMUNE2.
local rip = make(9204, {
    schoolID = 0, school = "Physical",
    effects = { raw(6, 0), raw(0, 0), raw(0, 0) },
    mechanics = { 15, 0, 0 },
}, "effect_mask_zero", "immune2")
applicable(rip)
local rp = build(rip)
eq(dimensions(rp), "bleed,physical", "Rip effects retained for diagnostics")
eq(rp.immuneVariant, "immune2", "IMMUNE2 distinct")
eq(rp.failurePath, "effect_mask_zero", "raw failure path distinct")
eq(reasonPresent(rp, "effect_mask_zero_not_exhaustive"), true, "mask path unknown")
eq(rp.complete, false, "mask not exhaustive")
eq(table.getn(durable(rip)), 0, "IMMUNE2 cannot write hypotheses")

-- Explicitly not-applicable slots must be excluded without inventing target data.
local skipped = make(9205, {
    schoolID = 4, school = "Frost",
    effects = { raw(6, 26), raw(0, 0), raw(0, 0) },
    mechanics = { 0, 0, 0 },
})
skipped.spell.effects[1].targetApplicability = "not_applicable"
local sk = build(skipped)
eq(dimensions(sk), "frost", "inapplicable effect omitted")
eq(sk.complete, true, "known inapplicable not an unknown alternative")
eq(findCandidate(sk, "root"), nil, "inapplicable root cannot leak")
eq(sk.persistenceEligible, false, "no relevant effects cannot prove school")
eq(reasonPresent(sk, "no_potential_target_effect"), true,
    "non-target spell cannot be exhaustive")

-- Unknown nonzero mechanic cannot become an aura fallback.
local unknownMechanic = make(9206, {
    schoolID = 4, school = "Frost",
    effects = { raw(6, 26), raw(0, 0), raw(0, 0) },
    mechanics = { 999, 0, 0 },
})
applicable(unknownMechanic)
local um = build(unknownMechanic)
eq(dimensions(um), "frost", "unrecognised mechanic does not invent root")
eq(um.unmodelledAlternative, true, "unrecognised mechanic flagged")
eq(reasonPresent(um, "unclassified_effect:1:unknown_nonzero_mechanic"),
    true, "explicit unsupported effect preserved")
eq(table.getn(durable(unknownMechanic)), 0, "cannot promote incomplete school")

-- Creature type restrictions, unknown dispels, absent slots and portable paths.
local restricted = make(9207, {
    schoolID = 4, school = "Frost", targetCreatureType = 4, dispel = 99,
    effects = { raw(6, 26), raw(0, 0), raw(0, 0) },
    mechanics = { 0, 0, 0 },
})
applicable(restricted)
local rs = build(restricted)
eq(reasonPresent(rs, "whole_spell_creature_type_restriction"), true, "creature restriction")
eq(reasonPresent(rs, "unmodelled_dispel_family"), true, "unknown dispel")
eq(rs.persistenceEligible, false, "restricted spell cannot overconfirm")
eq(dimensions(rs), "frost,root", "restricted diagnostics still useful")

local missing = make(9208, {
    schoolID = 4, school = "Frost", mechanics = { 7, 0, 0 },
})
local ms = build(missing)
eq(reasonPresent(ms, "unknown_effect_slot:1"), true, "missing metadata")
eq(ms.complete, false, "no effect metadata incomplete")
eq(table.getn(durable(missing)), 0, "no partial candidates persisted")

local unsupported = build({ failurePath = "whole_spell", immuneVariant = "immune" })
eq(reasonPresent(unsupported, "missing_spell_profile"), true, "missing profile")
eq(table.getn(unsupported.dimensions), 0, "no invented cause")

local portable = make(9209, {
    schoolID = 4, school = "Frost",
    effects = { raw(6, 26), raw(0, 0), raw(0, 0) },
    mechanics = { 0, 0, 0 },
}, nil, "immune2")
applicable(portable)
portable.failurePath = nil
local pt = build(portable)
eq(reasonPresent(pt, "unverified_failure_path"), true, "portable unverified")
eq(table.getn(durable(portable)), 0, "portable failure excluded")
eq(pt.immuneVariant, "immune2", "portable raw variant remains visible")

print("PASS: " .. checks .. " typed candidate fixture checks (Lua 5.0.3)")
