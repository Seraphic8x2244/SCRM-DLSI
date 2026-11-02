-- Chat 5: real DLSI provider query function, synthetic HearthDB fact states.
-- No game API/runtime or persisted user database is exercised by this fixture.
local f = assert(io.open("SCRM-DLSI.lua", "r"))
local source = f:read("*a"); f:close()
local first = assert(string.find(source, 'local PROVIDER_ID = "scrm-dlsi"', 1, true))
local last = assert(string.find(source, "-- One-time version 1 -> 2 HearthDB", first, true))
local env = {}
setmetatable(env, { __index = _G })
env._G = env
local creatureID = 123
local isPlayer = false
local liveAura
local ready = true
local facts = {}
local profile
env.UnitExists = function(unit) return unit == "target" end
env.UnitIsPlayer = function() return isPlayer end
env.UnitCreatureID = function() return creatureID end
local loader = assert(loadstring(string.sub(source, first, last - 1) ..
    "\nreturn QueryDLSIImmunity"))
setfenv(loader, env)
local query = loader()
local knowledge = {
    IsActive = function() return true end,
    GetDimensionState = function(id, dimension)
        local row = facts[id]
        return row and row[dimension] or nil
    end,
}
local dlsi = {
    ImmunityStorage = { IsReady = function() return ready end },
    ImmunityKnowledge = knowledge,
    ImmunityObservations = { GetSpellProfile = function() return profile end },
    HasImmunityGuardAura = function() return nil, liveAura end,
    IsTemporarilyCCImmune = function() return false end,
}
local host = {}
local checks = 0
local function expect(expected, actual, detail)
    checks = checks + 1
    if expected ~= actual then
        error(detail .. ": expected " .. tostring(expected) ..
            " got " .. tostring(actual), 2)
    end
end
local function ask(value)
    return query(dlsi, host, "target", value)
end
local function reset()
    facts = {}
    profile = nil
    creatureID = 123
    isPlayer = false
    liveAura = nil
    ready = true
end
local function spellProfile()
    return {
        name = "Synthetic Root and Frost",
        school = "frost", spellMechanic = 0,
        spellMechanicDimension = nil, dispelType = 0,
        targetCreatureType = 0, mechanicDimensions = { "root" },
        effects = { { active = true, mechanic = 7, mechanicDimension = "root" } },
        effectClassificationComplete = true,
        targetApplicabilityComplete = true,
    }
end

reset()
expect(nil, ask("frost"), "no school evidence is unknown")
facts[123] = { frost = "vulnerable" }
expect(false, ask("frost"), "direct positive school success proves named vulnerability")
facts[123].frost = "immune"
expect(true, ask("frost"), "direct immune school fact")
reset()
facts[123] = { frost = "vulnerable", root = "vulnerable" }
profile = spellProfile()
expect(false, ask(999), "fully modelled spell with all required success facts")
profile.targetApplicabilityComplete = false
expect(nil, ask(999), "unknown effect targeting must not falsely prove spell vulnerable")
profile.targetApplicabilityComplete = nil
expect(nil, ask(999), "missing target completeness must fail closed")
profile.targetApplicabilityComplete = true
profile.effectClassificationComplete = false
expect(nil, ask(999), "unclassified effect must not falsely prove spell vulnerable")
profile.effectClassificationComplete = nil
expect(nil, ask(999), "missing classification completeness must fail closed")
profile.effectClassificationComplete = true
profile.targetCreatureType = 1
expect(nil, ask(999), "whole-spell creature restriction")
profile.targetCreatureType = 0
profile.spellMechanic = 99
expect(nil, ask(999), "unmodelled spell mechanic")
profile.spellMechanic = 0
profile.dispelType = 99
expect(nil, ask(999), "unmodelled dispel")
profile.dispelType = 0
facts[123].root = "immune"
profile.targetApplicabilityComplete = false
expect(true, ask(999), "positive root immunity still applies with incomplete profile")
reset()
facts[123] = { frost = "immune" }
isPlayer = true
expect(nil, ask("frost"), "player targets never read NPC template facts")
liveAura = "all"
expect(true, ask("frost"), "live guard aura still works on player targets")
reset()
creatureID = nil
expect(nil, ask("frost"), "unknown creature identity cannot use HearthDB")
reset()
ready = false
expect(nil, ask("frost"), "unready HearthDB is unknown")
reset()
facts[123] = {
    holy = "immune", fire = "immune", nature = "immune",
    frost = "immune", shadow = "immune", arcane = "immune",
}
expect(true, ask("spell"), "six independently confirmed schools derive spell immunity")
facts[123].arcane = nil
expect(nil, ask("spell"), "five magic schools must not imply broad spell immunity")

-- Static integration seams: one observation owner, two private consumers,
-- and migration preceding provider registration. These are source checks,
-- not a live assertion that the host DLL or addon event dispatcher works.
local function occursOnce(text)
    local _, count = string.gsub(source, text, "")
    return count == 1
end
expect(true, occursOnce("Pipeline.RegisterListener(onObservation)"),
    "one transient listener")
expect(true, occursOnce("Pipeline.RegisterListener(Knowledge.ProcessObservation)"),
    "one knowledge listener")
expect(true, occursOnce('CreateFrame("Frame", "SCRM_DLSI_ObservationFrame")'),
    "one observation frame")
expect(true, occursOnce("host.RegisterImmunityProvider,"),
    "one provider registration")
local migrate = assert(string.find(source, "pcall(MigrateHearthDBV3, storage)", 1, true))
local register = assert(string.find(source, "host.RegisterImmunityProvider,", migrate, true))
expect(true, migrate < register, "migration precedes provider registration")
print("Chat 5 provider/integration fixture PASS (" .. checks .. " assertions)")
