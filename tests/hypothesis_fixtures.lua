-- Chat 3: execute the actual production learner against synthetic v2 rows.
-- No in-game results or migration are inferred from these fixtures.
local f = assert(io.open("SCRM-DLSI.lua", "r"))
local source = f:read("*a")
f:close()
local first = assert(string.find(source, "local function LoadOriginalImmunityKnowledge(namespace)", 1, true))
local last = assert(string.find(source, "-- END preserved source: ImmunityKnowledge.lua", first, true))
local env = {}
setmetatable(env, { __index = _G })
env._G = env
local loader = assert(loadstring(string.sub(source, first, last - 1) ..
    "\nreturn LoadOriginalImmunityKnowledge"))
setfenv(loader, env)
local loadKnowledge = loader()
local count = 0
local function check(value, why)
    count = count + 1
    if not value then error(why, 2) end
end
local function contains(s, term)
    return string.find(s or "", term, 1, true) ~= nil
end
local facts, hypotheses, transactions = {}, {}, {}
local storage = {
    IsReady = function() return true end,
    SQLText = function(v, allow)
        if v == nil then if allow then return "NULL" end; return nil end
        return "'" .. string.gsub(tostring(v), "'", "''") .. "'"
    end,
    SQLInteger = function(v, min, allow)
        if v == nil and allow then return "NULL" end
        v = tonumber(v)
        if not v or v < min or v ~= math.floor(v) then return nil end
        return tostring(v)
    end,
    Execute = function(sql)
        table.insert(transactions, sql)
        return true
    end,
}
storage.Query = function(sql)
    if contains(sql, "COUNT(*) AS candidate_count") then
        return true, { { candidate_count = 0 } }
    end
    if contains(sql, "FROM facts WHERE mob_id") then
        local rows = {}
        for dim, fact in pairs(facts) do
            table.insert(rows, {
                dimension = dim, verdict = fact.verdict,
                dynamic_suspected = fact.dynamic_suspected or 0,
            })
        end
        return true, rows
    end
    if contains(sql, "FROM hypotheses h") then
        local rows = {}
        local i, j
        for i = 1, table.getn(hypotheses) do
            local hyp = hypotheses[i]
            for j = 1, table.getn(hyp.candidates) do
                table.insert(rows, {
                    hypothesis_id = hyp.id, dimension = hyp.candidates[j],
                    proof_source = hyp.source, proof_spell_id = hyp.spell,
                    proof_event = hyp.event,
                })
            end
        end
        return true, rows
    end
    return false, "unexpected query " .. sql
end
local evidence = {
    AMBIGUOUS_IMMUNE = "ambiguous_immune",
    AUTHORITATIVE_SUCCESS = "authoritative_success",
}
local p = { EVIDENCE = evidence, RegisterListener = function() end }
local ns = {
    ImmunityObservations = p, ImmunityStorage = storage,
    ImmunityTransient = { GetExplanations = function() return {} end },
}
loadKnowledge(ns)
local learner = ns.ImmunityKnowledge
local function reset(f, h)
    facts = f or {}
    hypotheses = h or {}
    transactions = {}
end
local function sql()
    return transactions[table.getn(transactions)] or ""
end
local function success(id, profile, kind, runtimeSchool)
    return {
        targetMobID = 100, targetName = "Synthetic", spellID = id,
        spell = profile, kind = kind or "aura",
        outcome = kind == "damage" and "damage_landed" or "aura_present",
        auraKind = "debuff", runtimeSchool = runtimeSchool,
        event = "SPELL_SUCCESS",
        evidence = evidence.AUTHORITATIVE_SUCCESS, authoritative = true,
    }
end
local profile = {
    school = "frost", schoolID = 4, spellMechanic = 7,
    spellMechanicDimension = "root", dispelType = 1,
    dispelDimension = "dispel_magic",
    effects = {
        { active = true, effectIndex = 1, effectID = 6,
          mechanicID = 7, mechanicDimension = "root",
          mechanicSource = "explicit", targetApplicability = "applicable" },
        { active = false }, { active = false },
    },
}
local frost = {
    targetMobID = 100, targetName = "Synthetic", spellID = 122,
    spell = profile, kind = "miss", event = "SPELL_MISS_OTHER",
    failurePath = "whole_spell", immuneVariant = "immune",
    evidence = evidence.AMBIGUOUS_IMMUNE,
}
local model = learner.GetCandidateModelForObservation(frost)
check(model.complete and model.persistenceEligible, "Frost Nova complete synthetic model")
check(table.concat(model.dimensions, ",") == "dispel_magic,frost,root",
    "Frost Nova retains three alternatives")

-- Growl's AuraType 11 is Taunt, never Root; HoJ success can prove
-- Stun/Holy/Magic vulnerability, never an immune dimension.
reset()
learner.ProcessObservation(success(6795, { school = "physical",
    effects = { { auraName = 11 }, {}, {} } }))
check(contains(sql(), "'physical'"), "Growl success recorded")
check(not contains(sql(), "'root'"), "Growl cannot prove root")
reset()
learner.ProcessObservation(success(853, {
    school = "holy", dispelDimension = "dispel_magic",
    spellMechanicDimension = "stun" }))
check(contains(sql(), "'holy'") and contains(sql(), "'stun'")
    and contains(sql(), "'dispel_magic'"), "HoJ true success dimensions")
check(not contains(sql(), "'immune', 0"), "HoJ cannot prove immune")

-- Immediate singleton after already known root+magic successes:
-- stage in v2 hypothesis tables and do not create an immune fact.
reset({ root = { verdict = "vulnerable" },
    dispel_magic = { verdict = "vulnerable" } })
learner.ProcessObservation(frost)
check(table.getn(transactions) == 1, "singleton persisted")
check(contains(sql(), "INSERT INTO hypotheses"), "singleton staged")
check(contains(sql(), "SELECT MAX(hypothesis_id), 'frost'"),
    "Frost remains suspected")
check(not contains(sql(), "'immune', 0"), "immediate permanent blocked")

-- Repeated generic IMMUNE cannot upgrade a persisted singleton.
reset(facts, { { id = 7, source = "ambiguous_whole_spell", spell = 122,
    candidates = { "frost" } } })
learner.ProcessObservation(frost)
check(table.getn(transactions) == 0, "repeat ambiguous observation deduped")

-- Full multi-dimensional candidate retains its Root and Magic alternatives;
-- uncertain targeting and raw IMMUNE2 never persist.
reset()
learner.ProcessObservation(frost)
check(contains(sql(), "SELECT MAX(hypothesis_id), 'root'"),
    "root alternative staged")
check(contains(sql(), "SELECT MAX(hypothesis_id), 'dispel_magic'"),
    "dispel alternative staged")
local immune2 = {}
for k, v in pairs(frost) do immune2[k] = v end
immune2.immuneVariant = "immune2"
reset()
learner.ProcessObservation(immune2)
check(table.getn(transactions) == 0, "variant mismatch cannot persist")
local uncertain = {}
for k, v in pairs(frost) do uncertain[k] = v end
local unknownProfile = {}
for k, v in pairs(profile) do unknownProfile[k] = v end
unknownProfile.effects = {
    { active = true, targetApplicability = "unknown",
      mechanicDimension = "root" }, { active = false }, { active = false },
}
uncertain.spell = unknownProfile
reset()
learner.ProcessObservation(uncertain)
check(table.getn(transactions) == 0, "incomplete cannot persist")

-- Delayed reduction of a legacy v2 hypothesis: authoritative Root success
-- deletes Root candidate but does not confirm its Frost survivor.
reset({ dispel_magic = { verdict = "vulnerable" } }, {
    { id = 42, source = "ambiguous_whole_spell", spell = 122,
      candidates = { "root", "frost" } },
})
learner.ProcessObservation(success(9401, {
    school = "nature", spellMechanicDimension = "root" }))
check(contains(sql(), "DELETE FROM hypothesis_candidates WHERE dimension = 'root'"),
    "true Root success eliminates Root candidate")
check(not contains(sql(), "'immune', 0"), "delayed permanent blocked")
check(not contains(sql(), "hypothesis_id IN (42)"), "singleton v2 row retained")
check(learner.GetDiagnostics().permanentConfirmations == 0,
    "no permanent confirmations from ambiguous alternatives")

-- An immunity-then-vulnerability contradiction indicates dynamic
-- suspicion: discard hypothesis instead of narrowing to another cause.
reset({ root = { verdict = "vulnerable", dynamic_suspected = 1 } }, {
    { id = 43, source = "ambiguous_whole_spell", spell = 122,
      candidates = { "root", "frost" } },
})
learner.ProcessObservation(success(9402, {
    school = "nature", spellMechanicDimension = "root" }))
check(contains(sql(), "hypothesis_id IN (43)"), "dynamic row discarded")
check(not contains(sql(), "'immune', 0"), "dynamic not promoted")

-- Valid target-correlated runtime school damage can prove vulnerability
-- even when optional static Spell.dbc profile lookup fails.
reset()
learner.ProcessObservation(success(9403, nil, "damage", "frost"))
check(contains(sql(), "VALUES (100, 'frost', 'vulnerable'"),
    "profile-less runtime damage school retained")

-- Test the exact shared source gate, including a future *verified* proof
-- class; normalizer currently defines no authoritative immune event.
local gateFirst = assert(string.find(source,
    "local function canConfirmFromEvidence(proof, dimension)", 1, true))
local gateLast = assert(string.find(source,
    "local function planAfterAuthoritativeSuccess(", gateFirst, true))
local gate = assert(loadstring("local CANDIDATE_DIMENSIONS = { frost = true }\n" ..
    "local Pipeline = { EVIDENCE = { AUTHORITATIVE_IMMUNE = 'authoritative_immune' } }\n" ..
    string.sub(source, gateFirst, gateLast - 1) ..
    "\nreturn canConfirmFromEvidence"))()
check(not gate(frost, "frost"), "ambiguous never crosses proof gate")
check(not gate({ proofSource = "ambiguous_whole_spell" }, "frost"),
    "v2 legacy source never crosses proof gate")
local proof = { evidence = "authoritative_immune", authoritative = true,
    attribution = "verified_effect", failurePath = "attributed_dimension",
    attributedDimension = "frost" }
check(gate(proof, "frost"), "verified dimension attribution allowed")
check(not gate(proof, "root"), "wrong dimension rejected")
proof.immuneVariant = "immune"
check(not gate(proof, "frost"), "generic raw variant rejected")
print("hypothesis lifecycle fixture assertions: " .. count)
