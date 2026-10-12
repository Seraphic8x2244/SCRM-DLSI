-- SCRM-DLSI single-source extraction workspace.
-- Original advanced modules preserved verbatim inside private loader functions.
-- DO NOT ACTIVATE until host helpers, HearthDB preservation and provider wiring
-- have been audited. This source-stage commit is intentionally not a runnable DLSI.
local ADDON_NAME = "SCRM-DLSI"
local ADDON_VERSION = GetAddOnMetadata(ADDON_NAME, "Version")

-- BEGIN Chunk B: isolated helper and read-only host-adapter factory (DORMANT).
-- The factory is intentionally not invoked until Chunk C establishes safe owners.
-- Never mutate host CleveRoids methods or the legacy immunity SavedVariables here.
local function CreateDLSIHostAdapters(host)
    local adapters = {}
    local CleveRoids = host -- compatibility for original helper bodies; read-only
    adapters.NormalizeGUID = function(guid)
        if not guid then return nil end
        return tostring(guid)
    end
    adapters.GetGUID = function(unit)
        if not unit or type(GetUnitGUID) ~= "function" then return nil end
        return adapters.NormalizeGUID(GetUnitGUID(unit))
    end
    adapters.GetCreatureEntry = function(unit)
        if not unit or type(UnitCreatureID) ~= "function" then return nil end
        return UnitCreatureID(unit)
    end
    -- Host's ClassicAPI wrappers remain authoritative for spell data.
    -- The frozen generic host does not ship the prototype's extended
    -- ClassicAPI helpers. Implement only those read-only adapters here.
    adapters.ClassicAPI = {}
    adapters.ClassicAPI.ResolveLiveCreatureID = function(guid)
        if guid == nil then return nil, nil, "missing_guid" end
        if type(UnitTokenFromGUID) ~= "function" or
            type(UnitGUID) ~= "function" or
            type(UnitCreatureID) ~= "function" then
            return nil, nil, "resolver_unavailable"
        end
        local guidText = tostring(guid)
        local unit = UnitTokenFromGUID(guidText)
        if not unit then return nil, nil, "not_live" end
        local liveGUID = UnitGUID(unit)
        if not liveGUID or string.lower(tostring(liveGUID)) ~=
            string.lower(guidText) then
            return nil, nil, "stale_token"
        end
        local mobID = UnitCreatureID(unit)
        if not mobID then return nil, unit, "not_creature" end
        return tonumber(mobID), unit, "live"
    end
    adapters.ClassicAPI.GetSpellSchoolByID = function(spellID)
        if not spellID or type(GetSpellSchool) ~= "function" then
            return nil, nil
        end
        local id, name = GetSpellSchool(spellID)
        if not id then return nil, nil end
        return id - 1, name
    end
    adapters.ClassicAPI.GetSpellMechanicByID = function(spellID)
        local api = host.ClassicAPI
        if not api or type(api.GetSpellMechanicByID) ~= "function" then return nil end
        return api.GetSpellMechanicByID(spellID)
    end
    adapters.ClassicAPI.GetSpellEffectMechanics = function(spellID)
        local api = host.ClassicAPI
        if not api or type(api.GetSpellEffectMechanics) ~= "function" then return nil end
        return api.GetSpellEffectMechanics(spellID)
    end
    adapters.ClassicAPI.GetSpellEffectInfo = function(spellID)
        if not spellID or not C_Spell or
            type(C_Spell.GetSpellEffectInfo) ~= "function" then return nil end
        return C_Spell.GetSpellEffectInfo(spellID)
    end
    adapters.ClassicAPI.GetSpellDispelType = function(spellID)
        if not spellID or not C_Spell or
            type(C_Spell.GetSpellDispelType) ~= "function" then return nil end
        return C_Spell.GetSpellDispelType(spellID)
    end
    adapters.Print = function(message)
        if type(host.Print) == "function" then return host.Print(message) end
    end
    adapters.NotifyImmunityDataChanged = function()
        -- Local consumers are installed in Chunk C. Never call the host's legacy notifier.
        if adapters.OnKnowledgeChanged then adapters.OnKnowledgeChanged() end
    end
    adapters.GetImmunityDebugSnapshot = function()
        -- Host diagnostics are optional and strictly read-only. Never alias its journal.
        if type(host.GetImmunityDebugSnapshot) == "function" then
            return host.GetImmunityDebugSnapshot()
        end
        return nil
    end
    -- Host classification/cast evidence is read-only; no guessed NPC DR bucket.
    local GetSpellCCType = function(id)
        if type(host.GetSpellCCType) == "function" then return host.GetSpellCCType(id) end
        return nil
    end

local IMMUNITY_AURAS = {
    all = {
        [498] = true,    -- Divine Protection (Rank 1)
        [5573] = true,   -- Divine Protection (Rank 2)
        [642] = true,    -- Divine Shield (Rank 1)
        [1020] = true,   -- Divine Shield (Rank 2)
        [13874] = true,  -- Divine Shield
        [11958] = true,  -- Ice Block
        [27619] = true,  -- Ice Block (alternate)
    },

    spell = {
        -- These NPC auras make magic spells return IMMUNE rather than merely
        -- absorbing or reducing their damage.
        [7121] = true,   -- Anti-Magic Shield
        [19645] = true,  -- Anti-Magic Shield (variant)
        [24021] = true,  -- Anti-Magic Shield (variant)
    },

    physical = {
        [1022] = true,   -- Blessing of Protection (Rank 1)
        [5599] = true,   -- Blessing of Protection (Rank 2)
        [10278] = true,  -- Blessing of Protection (Rank 3)
    },

    root = {
        [1044] = true,   -- Blessing of Freedom
    },

    snare = {
        [1044] = true,   -- Blessing of Freedom
    },

    reflect = {
        -- Spell Reflection
        [9941] = true,
        [9943] = true,
        [10074] = true,
        [11818] = true,
        [21118] = true,

        -- School-specific Reflectors (Engineering items)
        [23097] = true,  -- Fire Reflector
        [23131] = true,  -- Frost Reflector
        [23132] = true,  -- Shadow Reflector
        [23178] = true,  -- Nature Reflector
        [23216] = true,  -- Arcane Reflector

        -- Multi-school Reflect (NPC abilities)
        [13022] = true,  -- Fire and Arcane Reflect
        [19595] = true,  -- Shadow and Frost Reflect

        -- Generic Reflection buffs
        [3651] = true,   -- Shield of Reflection
        [9906] = true,   -- Reflection
        [10831] = true,  -- Reflection Field
        [17106] = true,  -- Reflection
        [17107] = true,  -- Reflection
        [17108] = true,  -- Reflection
        [20223] = true,  -- Magic Reflection
        [20619] = true,  -- Magic Reflection
        [22067] = true,  -- Reflection
        [23920] = true,  -- Shield Reflection
        [23921] = true,  -- Shield Reflection
        [27564] = true,  -- Reflection
    },
}

local IMMUNITY_AURA_GUARD_ORDER = { "all", "spell", "physical", "reflect" }

-- Return the active aura spell ID for one semantic bucket, or nil.
-- Matching is numeric and locale-independent; direct by-ID lookup also sees
-- auras outside the visible slots.
local function GetActiveImmunityAura(unit, auraType)
    if not UnitExists(unit) then return nil end
    if not C_UnitAuras or not C_UnitAuras.GetUnitAuraBySpellID then return nil end

    local auraIDs = IMMUNITY_AURAS[auraType]
    if not auraIDs then return nil end

    for spellID in pairs(auraIDs) do
        if C_UnitAuras.GetUnitAuraBySpellID(unit, spellID, "HELPFUL") then
            return spellID
        end
    end

    return nil
end

-- Compatibility learning guard: any listed temporary protection or reflection
-- still makes a failed/IMMUNE observation inconclusive. Reflection is returned
-- as its own bucket and is never promoted to an immunity type.
local function HasImmunityGuardAura(unit)
    for _, auraType in ipairs(IMMUNITY_AURA_GUARD_ORDER) do
        local spellID = GetActiveImmunityAura(unit, auraType)
        if spellID then
            local spellName = C_Spell.GetSpellName(spellID) or ("SpellID:" .. spellID)
            return spellName, auraType, spellID
        end
    end

    return nil
end

-- Curated encounter auras that temporarily grant immunity to specific CC mechanics.
-- Keyed by creature entry -> aura spell ID -> canonical immunity type.
-- Keep this list deliberately small and evidence-backed; this is not DBC inference.
local TEMP_CC_IMMUNITIES = {
    [15516] = { -- Battleguard Sartura
        [26083] = { stun = true }, -- Whirlwind: temporary stun immunity
    },
}

-- Resolve the creature-template entry through ClassicAPI. This keeps GUID
-- layout/client-token details out of the TempCCImmune subsystem.
local function GetCreatureEntry(unit)
    if not unit then return nil end
    return adapters.GetCreatureEntry(unit)
end

-- Return true when a curated aura currently explains this creature's immunity
-- to exactly the requested CC mechanic. Optional second return is the aura ID.
local function IsTemporarilyCCImmune(unit, ccType)
    if not unit or not ccType or not UnitExists(unit) then
        return false
    end

    -- Typed temporary CC auras apply to players and NPCs alike. These are live
    -- state only and must never be promoted to permanent learned immunity.
    local typedAuraID = GetActiveImmunityAura(unit, ccType)
    if typedAuraID then
        return true, typedAuraID
    end

    local creatureEntry = GetCreatureEntry(unit)
    local auraRules = creatureEntry and TEMP_CC_IMMUNITIES[creatureEntry]
    if not auraRules then
        return false
    end

    if not C_UnitAuras or not C_UnitAuras.GetUnitAuraBySpellID then
        return false
    end

    for auraID, mechanics in pairs(auraRules) do
        if mechanics[ccType] and C_UnitAuras.GetUnitAuraBySpellID(unit, auraID) then
            return true, auraID
        end
    end

    return false
end

adapters.IsTemporarilyCCImmune = IsTemporarilyCCImmune

-- Slice 3 normalized-transient bridge. Keep the curated numeric definitions
-- authoritative here so the generalized backend does not duplicate them.
function adapters.GetTransientImmunityAuraEffects(spellID, mobID)
    spellID = tonumber(spellID)
    mobID = tonumber(mobID)
    if not spellID then return {} end

    local effects = {}
    local seen = {}

    local function addEffect(source, dimension, auraType)
        local key = tostring(source) .. ":" .. tostring(dimension or auraType or "")
        if seen[key] then return end
        seen[key] = true
        table.insert(effects, {
            source = source,
            dimension = dimension,
            auraType = auraType,
            auraID = spellID,
        })
    end

    for auraType, auraIDs in pairs(IMMUNITY_AURAS) do
        if auraIDs[spellID] then
            if auraType == "reflect" then
                addEffect("reflection", nil, auraType)
            elseif auraType == "root" or auraType == "snare" then
                addEffect("temporary_cc", auraType, auraType)
            else
                addEffect("temporary_aura", auraType, auraType)
            end
        end
    end

    local mobRules = mobID and TEMP_CC_IMMUNITIES[mobID]
    local mechanics = mobRules and mobRules[spellID]
    if mechanics then
        for ccType in pairs(mechanics) do
            addEffect("temporary_cc", ccType, "temp_cc")
        end
    end

    return effects
end

adapters.HasImmunityGuardAura = HasImmunityGuardAura


local STUN_CONTROL_DR_OVERRIDES = {
    [7922] = true,   -- Charge Stun
    [20253] = true,  -- Intercept Stun Rank 1
    [20614] = true,  -- Intercept Stun Rank 2
    [20615] = true,  -- Intercept Stun Rank 3
}
local KIDNEY_SHOT_IDS = {
    [408] = true,
    [8643] = true,
}

local function IsKidneyShotSpell(spellID)
    if KIDNEY_SHOT_IDS[spellID] then return true end

    -- Vanilla Rogue family bit 21 (0x00200000) is Kidney Shot. Prefer the
    -- family mask so custom ranks that preserve DBC family data also classify correctly.
    if GetSpellRecField then
        local familyName = GetSpellRecField(spellID, "spellFamilyName")
        local familyFlags = GetSpellRecField(spellID, "spellFamilyFlags")
        if familyName == 8 and familyFlags then -- SPELLFAMILY_ROGUE
            local kidneyBit = 2097152 -- 0x00200000
            if math.mod(math.floor(familyFlags / kidneyBit), 2) == 1 then
                return true
            end
        end
    end

    return false
end

local function WasClientInitiatedSpell(spellID)
    -- Nampower SPELL_CAST_EVENT fires only for spells initiated by the client.
    -- Proc/trigger spell IDs reach server SPELL_GO/MISS without their own entry.
    local cast = host.pendingCasts and host.pendingCasts[spellID]
    if not cast or not cast.timestamp then return false end
    local age = GetTime() - cast.timestamp
    return age >= 0 and age <= 5
end

local function GetSpellImmunityDRType(spellID)
    if GetSpellCCType(spellID) ~= "stun" then return nil end

    if IsKidneyShotSpell(spellID) then
        return "stun_kidneyshot"
    end

    -- These stun subspells are internally triggered but explicitly belong to
    -- controlled-stun DR in Vanilla.
    if STUN_CONTROL_DR_OVERRIDES[spellID] then
        return "stun_control"
    end

    if WasClientInitiatedSpell(spellID) then
        return "stun_control"
    end

    return "stun_trigger"
end

adapters.GetSpellImmunityDRType = GetSpellImmunityDRType

-- Generalized-backend DR classification must not reuse the legacy fallback that
-- guesses every non-client-initiated stun is triggered. For the player's own
-- casts the existing runtime cast evidence is usable. For another caster it is
-- only safe to classify spell IDs whose Vanilla bucket is explicit.
function adapters.ClassifyNPCStunDR(spellID, casterGUID)
    spellID = tonumber(spellID)
    if not spellID or GetSpellCCType(spellID) ~= "stun" then
        return nil, false, "not_stun"
    end

    if IsKidneyShotSpell(spellID) then
        return "stun_kidneyshot", true, "kidney_shot"
    end

    if STUN_CONTROL_DR_OVERRIDES[spellID] then
        return "stun_control", true, "explicit_control"
    end

    local playerGUID = adapters.GetGUID and adapters.GetGUID("player") or nil
    if playerGUID and casterGUID then
        if adapters.NormalizeGUID then
            playerGUID = adapters.NormalizeGUID(playerGUID)
            casterGUID = adapters.NormalizeGUID(casterGUID)
        end
        if playerGUID == casterGUID then
            if WasClientInitiatedSpell(spellID) then
                return "stun_control", true, "player_client_cast"
            end
            return "stun_trigger", true, "player_triggered"
        end
    end

    return nil, false, "controlled_vs_triggered_unknown"
end


    return adapters
end
-- END Chunk B factory; no calls or registrations.

-- BEGIN preserved source: ImmunityObservations.lua (design/temp-cc-immunity)
local function LoadOriginalImmunityObservations(namespace)
local _G = _G or getfenv(0)
local CleveRoids = namespace -- DLSI private namespace; never alias the host
-- No host-global assignment: module exports remain private.

-- Normalized immunity evidence input seam.
--
-- This module observes and normalizes combat evidence, caches static spell
-- classification and exposes diagnostics/listener hooks. It deliberately does
-- not write HearthDB, mutate legacy immunity storage, infer permanent facts, or
-- drive UI/SCT; those responsibilities remain downstream of this input seam.
local Pipeline = CleveRoids.ImmunityObservations or {}
CleveRoids.ImmunityObservations = Pipeline

Pipeline.SCHEMA_VERSION = 1

Pipeline.EVIDENCE = {
    AUTHORITATIVE_SUCCESS = "authoritative_success",
    AMBIGUOUS_IMMUNE = "ambiguous_immune",
    NEUTRAL = "neutral",
    LIFECYCLE = "lifecycle",
}

local MISS_INFO = {
    NONE = 0,
    MISS = 1,
    RESIST = 2,
    DODGE = 3,
    PARRY = 4,
    BLOCK = 5,
    EVADE = 6,
    IMMUNE = 7,
    IMMUNE2 = 8,
    DEFLECT = 9,
    ABSORB = 10,
    REFLECT = 11,
}

local MISS_NAMES = {
    [0] = "none",
    [1] = "miss",
    [2] = "resist",
    [3] = "dodge",
    [4] = "parry",
    [5] = "block",
    [6] = "evade",
    [7] = "immune",
    [8] = "immune2",
    [9] = "deflect",
    [10] = "absorb",
    [11] = "reflect",
}

local SCHOOL_NAMES = {
    [0] = "physical",
    [1] = "holy",
    [2] = "fire",
    [3] = "nature",
    [4] = "frost",
    [5] = "shadow",
    [6] = "arcane",
}

-- Mechanic names are the existing SCRM permanent-immunity vocabulary. Static
-- classification may expose several dimensions; selecting/eliminating candidates
-- belongs to later slices.
local MECHANIC_TO_DIMENSION = {
    [1] = "charm",
    [2] = "disorient",
    [5] = "fear",
    [7] = "root",
    [9] = "silence",
    [10] = "sleep",
    [11] = "snare",
    [12] = "stun",
    [13] = "freeze",
    [14] = "knockout",
    [15] = "bleed",
    [17] = "polymorph",
    [18] = "banish",
    [20] = "shackle",
    [24] = "horror",
    [27] = "daze",
}

-- Aura-name fallback is only used when no recognized explicit spell/effect
-- mechanic exists. This prevents a generic MOD_STUN aura from misclassifying a
-- spell whose explicit mechanic says Sleep/Knockout/Banish.
local AURA_NAME_TO_DIMENSION = {
    [1] = "charm",
    [2] = "charm",
    [5] = "polymorph",
    [7] = "fear",
    [11] = "root",
    [12] = "stun",
    [27] = "silence",
    [31] = "charm",
    [33] = "snare",
}

-- Dispel-family immunity is independent from spell school. "dispel_magic" is
-- an internal learning dimension; it is intentionally not the broad "spell"
-- immunity dimension used by production queries.
local DISPEL_TO_DIMENSION = {
    [1] = "dispel_magic",
    [2] = "curse",
    [3] = "disease",
    [4] = "poison",
}

local spellCache = {}
local listeners = {}
local sequence = 0

local diagnostics = {
    eventsSeen = 0,
    observationsEmitted = 0,
    listenerErrors = 0,
    spellCacheHits = 0,
    spellCacheMisses = 0,
    liveMobResolved = 0,
    unresolvedTargetIdentity = 0,
    nonCreatureTargets = 0,
    byEvent = {},
    byKind = {},
    byEvidence = {},
    last = nil,
}

local function normalizeGUID(guid)
    if guid == nil then return nil end
    if CleveRoids.NormalizeGUID then
        return CleveRoids.NormalizeGUID(guid)
    end
    return tostring(guid)
end

local function increment(map, key)
    if not key then return end
    map[key] = (map[key] or 0) + 1
end

local function copyCounts(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end

local function countKeys(source)
    local count = 0
    for _ in pairs(source) do
        count = count + 1
    end
    return count
end

local function addUnique(list, seen, value)
    if value and not seen[value] then
        seen[value] = true
        table.insert(list, value)
    end
end

local function copyEffect(raw, mechanic)
    if not raw and mechanic == nil then return nil end
    raw = raw or {}
    return {
        effect = raw.effect or 0,
        auraName = raw.auraName or 0,
        mechanic = mechanic or 0,
        basePoints = raw.basePoints,
        baseDice = raw.baseDice,
        dieSides = raw.dieSides,
        pointsPerLevel = raw.pointsPerLevel,
        dicePerLevel = raw.dicePerLevel,
        miscValue = raw.miscValue,
    }
end

function Pipeline.ClearSpellCache()
    spellCache = {}
end

-- Cached, read-only-by-convention static decomposition for arbitrary spell IDs.
-- Runtime success/failure is never inferred from this table; it only describes
-- dimensions a later reducer may need to reason about.
function Pipeline.GetSpellProfile(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then return nil end

    local cached = spellCache[spellID]
    if cached then
        diagnostics.spellCacheHits = diagnostics.spellCacheHits + 1
        return cached
    end

    diagnostics.spellCacheMisses = diagnostics.spellCacheMisses + 1

    local API = CleveRoids.ClassicAPI
    if not API then return nil end

    local schoolID, schoolName = API.GetSpellSchoolByID(spellID)
    local spellMechanic, spellMechanicName = API.GetSpellMechanicByID(spellID)
    local effectMechanics = API.GetSpellEffectMechanics(spellID)
    local rawEffects = API.GetSpellEffectInfo(spellID)
    local dispelType = API.GetSpellDispelType(spellID)
    local targetCreatureType = nil
    if type(_G.GetSpellRecField) == "function" then
        targetCreatureType = tonumber(_G.GetSpellRecField(spellID, "targetCreatureType"))
    end

    if schoolName then
        schoolName = string.lower(tostring(schoolName))
    elseif schoolID ~= nil then
        schoolName = SCHOOL_NAMES[schoolID]
    end

    local profile = {
        spellID = spellID,
        name = C_Spell.GetSpellName(spellID),
        schoolID = schoolID,
        school = schoolName,
        spellMechanic = spellMechanic or 0,
        spellMechanicName = spellMechanicName,
        spellMechanicDimension = nil,
        dispelType = dispelType or 0,
        dispelDimension = DISPEL_TO_DIMENSION[dispelType],
        targetCreatureType = targetCreatureType or 0,
        effects = {},
        auraTypes = {},
        mechanicDimensions = {},
        hasAura = false,
    }

    local auraSeen = {}
    local dimensionSeen = {}
    local explicitMechanicDimension = false

    local spellDimension = spellMechanic and MECHANIC_TO_DIMENSION[spellMechanic] or nil
    profile.spellMechanicDimension = spellDimension
    if spellDimension then
        addUnique(profile.mechanicDimensions, dimensionSeen, spellDimension)
        explicitMechanicDimension = true
    end

    for i = 1, 3 do
        local raw = rawEffects and rawEffects[i] or nil
        local effectMechanic = effectMechanics and effectMechanics[i] or 0
        local effect = copyEffect(raw, effectMechanic)
        if effect then
            profile.effects[i] = effect
            if effect.auraName and effect.auraName > 0 then
                profile.hasAura = true
                addUnique(profile.auraTypes, auraSeen, effect.auraName)
            end
        end

        local dimension = effectMechanic and MECHANIC_TO_DIMENSION[effectMechanic] or nil
        if effect then
            effect.mechanicDimension = dimension
        end
        if dimension then
            addUnique(profile.mechanicDimensions, dimensionSeen, dimension)
            explicitMechanicDimension = true
        end
    end

    -- Preserve the existing combined-profile fallback rule while also exposing
    -- a per-effect dimension for the Slice 4 failure-path reducer.
    for i = 1, 3 do
        local effect = profile.effects[i]
        if effect and not effect.mechanicDimension then
            effect.mechanicDimension = AURA_NAME_TO_DIMENSION[effect.auraName]
        end
        if not explicitMechanicDimension and effect and effect.mechanicDimension then
            addUnique(profile.mechanicDimensions, dimensionSeen, effect.mechanicDimension)
        end
    end

    spellCache[spellID] = profile
    return profile
end

local CORE_ADAPTERS = {}

-- Portable is deliberately the default. It preserves raw Nampower meaning
-- without claiming server-side semantics that have not been verified for the
-- active core.
CORE_ADAPTERS.portable = {
    interpretImmune = function(variant)
        if variant == "immune2" then
            return "raw_immune2", nil
        end
        return "raw_immune", nil
    end,
}

-- Core-specific miss semantics belong here, not in the common evidence reducer.
-- Slice 4 consumes only the normalized failurePath and never branches on core name.
CORE_ADAPTERS.vmangos = {
    interpretImmune = function(variant)
        if variant == "immune2" then
            return "effect_mask_zero", "effect_mask_zero"
        end
        return "generic_whole_spell_immune", "whole_spell"
    end,
}

-- Turtle-family server source uses the same relevant Vanilla 1.12 split:
-- whole-spell immunity is reported as IMMUNE, while a target whose final
-- effect mask is empty is reported as IMMUNE2. Keep a distinct adapter name so
-- any future core divergence remains isolated at this boundary.
CORE_ADAPTERS.octowow = {
    interpretImmune = function(variant)
        if variant == "immune2" then
            return "effect_mask_zero", "effect_mask_zero"
        end
        return "generic_whole_spell_immune", "whole_spell"
    end,
}

-- Slice 8 removes the development-only portable default. Normal production
-- startup now selects the target-family adapter from the environment already
-- detected in Init.lua. Preserve a preselected adapter for focused diagnostics
-- or test harnesses; portable remains available as an explicit conservative
-- override but is no longer the normal production path.
local defaultCoreAdapter = CleveRoids.hasTurtle and "octowow" or "vmangos"
Pipeline.coreAdapterName = Pipeline.coreAdapterName or defaultCoreAdapter

function Pipeline.SetCoreAdapter(name)
    if not CORE_ADAPTERS[name] then
        return false
    end
    Pipeline.coreAdapterName = name
    return true
end

function Pipeline.GetCoreAdapter()
    return Pipeline.coreAdapterName
end

local function interpretMiss(missInfo)
    local result = {
        outcome = MISS_NAMES[missInfo] or "unknown",
        evidence = Pipeline.EVIDENCE.NEUTRAL,
        authoritative = false,
        immuneVariant = nil,
        coreMeaning = nil,
        failurePath = nil,
    }

    if missInfo == MISS_INFO.IMMUNE or missInfo == MISS_INFO.IMMUNE2 then
        local variant = missInfo == MISS_INFO.IMMUNE2 and "immune2" or "immune"
        local adapter = CORE_ADAPTERS[Pipeline.coreAdapterName] or CORE_ADAPTERS.portable
        result.outcome = "immune"
        result.evidence = Pipeline.EVIDENCE.AMBIGUOUS_IMMUNE
        result.immuneVariant = variant
        result.coreMeaning, result.failurePath = adapter.interpretImmune(variant)
    end

    return result
end

local function resolveTarget(observation, guid)
    guid = normalizeGUID(guid)
    observation.targetGUID = guid
    if not guid then
        observation.targetIdentity = "missing_guid"
        diagnostics.unresolvedTargetIdentity = diagnostics.unresolvedTargetIdentity + 1
        return
    end

    local API = CleveRoids.ClassicAPI
    local mobID, unit, status = API.ResolveLiveCreatureID(guid)
    observation.targetMobID = mobID
    observation.targetUnit = unit
    observation.targetIdentity = status

    if unit then
        observation.targetName = UnitName(unit)
    end

    if mobID then
        diagnostics.liveMobResolved = diagnostics.liveMobResolved + 1
    elseif status == "not_creature" then
        diagnostics.nonCreatureTargets = diagnostics.nonCreatureTargets + 1
    else
        diagnostics.unresolvedTargetIdentity = diagnostics.unresolvedTargetIdentity + 1
    end
end

local function newObservation(eventName, scope, kind)
    sequence = sequence + 1
    return {
        schemaVersion = Pipeline.SCHEMA_VERSION,
        sequence = sequence,
        timestamp = GetTime(),
        source = "nampower",
        event = eventName,
        scope = scope,
        kind = kind,
        coreAdapter = Pipeline.coreAdapterName,
    }
end

local function rememberDiagnosticSummary(observation)
    diagnostics.last = {
        sequence = observation.sequence,
        event = observation.event,
        kind = observation.kind,
        evidence = observation.evidence,
        outcome = observation.outcome,
        targetGUID = observation.targetGUID,
        targetMobID = observation.targetMobID,
        targetIdentity = observation.targetIdentity,
        spellID = observation.spellID,
        coreAdapter = observation.coreAdapter,
    }
end

local function emit(observation)
    diagnostics.observationsEmitted = diagnostics.observationsEmitted + 1
    increment(diagnostics.byKind, observation.kind)
    increment(diagnostics.byEvidence, observation.evidence)
    rememberDiagnosticSummary(observation)

    for i = 1, table.getn(listeners) do
        local callback = listeners[i]
        local ok = pcall(callback, observation)
        if not ok then
            diagnostics.listenerErrors = diagnostics.listenerErrors + 1
        end
    end

    return observation
end

function Pipeline.RegisterListener(callback)
    if type(callback) ~= "function" then return false end
    for i = 1, table.getn(listeners) do
        if listeners[i] == callback then return true end
    end
    table.insert(listeners, callback)
    return true
end

function Pipeline.UnregisterListener(callback)
    for i = table.getn(listeners), 1, -1 do
        if listeners[i] == callback then
            table.remove(listeners, i)
            return true
        end
    end
    return false
end

local function scopeForEvent(eventName)
    if string.find(eventName, "_SELF$") then return "self" end
    if string.find(eventName, "_OTHER$") then return "other" end
    return "unit"
end

local function normalizeMiss(eventName, casterGUID, targetGUID, spellID, missInfo)
    spellID = tonumber(spellID)
    missInfo = tonumber(missInfo)
    if not targetGUID or not spellID or missInfo == nil then return nil end

    local interpretation = interpretMiss(missInfo)
    local observation = newObservation(eventName, scopeForEvent(eventName), "miss")
    observation.casterGUID = normalizeGUID(casterGUID)
    observation.spellID = spellID
    observation.spell = Pipeline.GetSpellProfile(spellID)
    observation.missInfo = missInfo
    observation.missReason = MISS_NAMES[missInfo] or "unknown"
    observation.outcome = interpretation.outcome
    observation.evidence = interpretation.evidence
    observation.authoritative = interpretation.authoritative
    observation.immuneVariant = interpretation.immuneVariant
    observation.coreMeaning = interpretation.coreMeaning
    observation.failurePath = interpretation.failurePath
    resolveTarget(observation, targetGUID)
    return emit(observation)
end

local function normalizeDamage(eventName, targetGUID, casterGUID, spellID, amount,
                               mitigation, hitInfo, runtimeSchoolID, effectAura)
    spellID = tonumber(spellID)
    runtimeSchoolID = tonumber(runtimeSchoolID)
    if not targetGUID or not spellID then return nil end

    local observation = newObservation(eventName, scopeForEvent(eventName), "damage")
    observation.casterGUID = normalizeGUID(casterGUID)
    observation.spellID = spellID
    observation.spell = Pipeline.GetSpellProfile(spellID)
    observation.outcome = "damage_landed"
    observation.evidence = Pipeline.EVIDENCE.AUTHORITATIVE_SUCCESS
    observation.authoritative = true
    observation.successKind = "damage"
    observation.runtimeSchoolID = runtimeSchoolID
    observation.runtimeSchool = runtimeSchoolID ~= nil and SCHOOL_NAMES[runtimeSchoolID] or nil
    observation.amount = tonumber(amount)
    observation.mitigation = mitigation
    observation.hitInfo = tonumber(hitInfo)
    observation.effectAura = effectAura
    resolveTarget(observation, targetGUID)
    return emit(observation)
end

local function auraOperation(eventName, state)
    state = tonumber(state)
    if state == 0 then return "added" end
    if state == 1 then return "removed" end
    if state == 2 then return "modified" end
    if string.find(eventName, "_ADDED_") then return "added" end
    return "removed"
end

local function normalizeAura(eventName, targetGUID, slot, spellID, stackCount,
                            auraLevel, auraSlot, state)
    spellID = tonumber(spellID)
    if not targetGUID or not spellID then return nil end

    local kind = string.find(eventName, "^BUFF_") and "buff" or "debuff"
    local operation = auraOperation(eventName, state)
    local stacks = tonumber(stackCount)
    local present = operation == "added" or
        (operation == "modified" and (stacks == nil or stacks > 0))

    local observation = newObservation(eventName, scopeForEvent(eventName), "aura")
    observation.spellID = spellID
    observation.spell = Pipeline.GetSpellProfile(spellID)
    observation.auraKind = kind
    observation.auraOperation = operation
    observation.stackCount = stacks
    observation.auraLevel = tonumber(auraLevel)
    observation.luaSlot = tonumber(slot)
    observation.auraSlot = tonumber(auraSlot)
    observation.state = tonumber(state)
    observation.outcome = present and "aura_present" or "aura_removed"
    observation.evidence = present and Pipeline.EVIDENCE.AUTHORITATIVE_SUCCESS
        or Pipeline.EVIDENCE.NEUTRAL
    observation.authoritative = present and true or false
    observation.successKind = present and "aura" or nil

    resolveTarget(observation, targetGUID)

    -- Nampower add/modify is already authoritative presence evidence. When the
    -- live unit is available, ClassicAPI actual aura state can add source
    -- attribution and a second diagnostic confirmation. AURA_CAST_ON_* is
    -- intentionally not registered or consumed.
    if present and observation.targetUnit then
        local filter = kind == "buff" and "HELPFUL" or "HARMFUL"
        local auraData = CleveRoids.ClassicAPI.GetUnitAuraBySpellID(
            observation.targetUnit, spellID, filter
        )
        observation.classicAuraVerified = auraData and true or false
        if auraData and auraData.sourceGUID then
            observation.casterGUID = normalizeGUID(auraData.sourceGUID)
            observation.casterSource = "classicapi_aura"
        end
    end

    return emit(observation)
end

local function normalizeDeath(eventName, targetGUID)
    if not targetGUID then return nil end
    local observation = newObservation(eventName, "unit", "death")
    observation.outcome = "died"
    observation.evidence = Pipeline.EVIDENCE.LIFECYCLE
    observation.authoritative = true
    resolveTarget(observation, targetGUID)
    return emit(observation)
end

-- Explicit lifecycle seam for transient-only state. Current live producers use
-- UNIT_DIED and PLAYER_ENTERING_WORLD; adapters may also normalize a proven
-- despawn without bypassing the observation pipeline.
function Pipeline.EmitLifecycle(outcome, targetGUID, eventName, detail)
    if not outcome then return nil end
    local observation = newObservation(eventName or "IMMUNITY_LIFECYCLE", "unit", "lifecycle")
    observation.outcome = tostring(outcome)
    observation.evidence = Pipeline.EVIDENCE.LIFECYCLE
    observation.authoritative = true
    observation.lifecycleDetail = detail
    if targetGUID then
        resolveTarget(observation, targetGUID)
    end
    return emit(observation)
end

-- Public adapter seam. Live registration below is the only current producer.
-- No persistence or inference happens here.
function Pipeline.HandleNampowerEvent(eventName, a1, a2, a3, a4, a5, a6, a7, a8)
    if not eventName then return nil end

    diagnostics.eventsSeen = diagnostics.eventsSeen + 1
    increment(diagnostics.byEvent, eventName)

    if eventName == "SPELL_MISS_SELF" or eventName == "SPELL_MISS_OTHER" then
        -- casterGuid, targetGuid, spellId, missInfo
        return normalizeMiss(eventName, a1, a2, a3, a4)
    end

    if eventName == "SPELL_DAMAGE_EVENT_SELF" or eventName == "SPELL_DAMAGE_EVENT_OTHER" then
        -- targetGuid, casterGuid, spellId, amount, mitigationStr, hitInfo,
        -- runtimeSchool, effectAuraStr
        return normalizeDamage(eventName, a1, a2, a3, a4, a5, a6, a7, a8)
    end

    if string.find(eventName, "^BUFF_ADDED_") or
       string.find(eventName, "^BUFF_REMOVED_") or
       string.find(eventName, "^DEBUFF_ADDED_") or
       string.find(eventName, "^DEBUFF_REMOVED_") then
        -- guid, luaSlot, spellId, stackCount, auraLevel, rawAuraSlot, state
        return normalizeAura(eventName, a1, a2, a3, a4, a5, a6, a7)
    end

    if eventName == "UNIT_DIED" then
        return normalizeDeath(eventName, a1)
    end

    if eventName == "PLAYER_ENTERING_WORLD" then
        return Pipeline.EmitLifecycle("world_reset", nil, eventName)
    end

    return nil
end

function Pipeline.GetDiagnostics()
    return {
        schemaVersion = Pipeline.SCHEMA_VERSION,
        coreAdapter = Pipeline.coreAdapterName,
        listenerCount = table.getn(listeners),
        spellCacheEntries = countKeys(spellCache),
        eventsSeen = diagnostics.eventsSeen,
        observationsEmitted = diagnostics.observationsEmitted,
        listenerErrors = diagnostics.listenerErrors,
        spellCacheHits = diagnostics.spellCacheHits,
        spellCacheMisses = diagnostics.spellCacheMisses,
        liveMobResolved = diagnostics.liveMobResolved,
        unresolvedTargetIdentity = diagnostics.unresolvedTargetIdentity,
        nonCreatureTargets = diagnostics.nonCreatureTargets,
        byEvent = copyCounts(diagnostics.byEvent),
        byKind = copyCounts(diagnostics.byKind),
        byEvidence = copyCounts(diagnostics.byEvidence),
        last = diagnostics.last,
    }
end

function Pipeline.ResetDiagnostics()
    diagnostics.eventsSeen = 0
    diagnostics.observationsEmitted = 0
    diagnostics.listenerErrors = 0
    diagnostics.spellCacheHits = 0
    diagnostics.spellCacheMisses = 0
    diagnostics.liveMobResolved = 0
    diagnostics.unresolvedTargetIdentity = 0
    diagnostics.nonCreatureTargets = 0
    diagnostics.byEvent = {}
    diagnostics.byKind = {}
    diagnostics.byEvidence = {}
    diagnostics.last = nil
end

local EVENT_NAMES = {
    "SPELL_MISS_SELF",
    "SPELL_MISS_OTHER",
    "SPELL_DAMAGE_EVENT_SELF",
    "SPELL_DAMAGE_EVENT_OTHER",
    "BUFF_ADDED_SELF",
    "BUFF_REMOVED_SELF",
    "BUFF_ADDED_OTHER",
    "BUFF_REMOVED_OTHER",
    "DEBUFF_ADDED_SELF",
    "DEBUFF_REMOVED_SELF",
    "DEBUFF_ADDED_OTHER",
    "DEBUFF_REMOVED_OTHER",
    "UNIT_DIED",
    "PLAYER_ENTERING_WORLD",
}

local frame = CreateFrame("Frame", "SCRM_DLSI_ObservationFrame")
Pipeline.frame = frame

if CleveRoids.hasNampower then
    for i = 1, table.getn(EVENT_NAMES) do
        frame:RegisterEvent(EVENT_NAMES[i])
    end
end

frame:SetScript("OnEvent", function()
    if not CleveRoids.DLSIEventsEnabled or
        not CleveRoids.IsSelectedProvider or
        not CleveRoids.IsSelectedProvider() then return end
    Pipeline.HandleNampowerEvent(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
end)

end
-- END preserved source: ImmunityObservations.lua

-- BEGIN preserved source: ImmunityStorage.lua (design/temp-cc-immunity)
local function LoadOriginalImmunityStorage(namespace)
local _G = _G or getfenv(0)
local CleveRoids = namespace -- DLSI private namespace; never alias the host
-- No host-global assignment: module exports remain private.

local Storage = CleveRoids.ImmunityStorage or {}
CleveRoids.ImmunityStorage = Storage

Storage.DB_FILENAME = "SuperCleveRoidMacros_Immunity.db"
Storage.SCHEMA_VERSION = 1
Storage.handle = nil
Storage.ready = false
Storage.schemaVersion = nil
Storage.hearthDBVersion = nil
Storage.lastErrorCode = nil
Storage.lastError = nil
Storage.lastResetReason = nil

local REQUIRED_FUNCTIONS = {
    "HDB_GetVersion",
    "HDB_Open",
    "HDB_Close",
    "HDB_Execute",
    "HDB_Query",
}

local SCHEMA_SQL = [[
BEGIN;
CREATE TABLE IF NOT EXISTS mobs (
    mob_id INTEGER PRIMARY KEY,
    last_name TEXT
);
CREATE TABLE IF NOT EXISTS facts (
    mob_id INTEGER NOT NULL,
    dimension TEXT NOT NULL,
    verdict TEXT NOT NULL CHECK (verdict IN ('immune', 'vulnerable')),
    dynamic_suspected INTEGER NOT NULL DEFAULT 0 CHECK (dynamic_suspected IN (0, 1)),
    proof_source TEXT,
    proof_spell_id INTEGER,
    proof_event TEXT,
    PRIMARY KEY (mob_id, dimension),
    FOREIGN KEY (mob_id) REFERENCES mobs(mob_id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS hypotheses (
    hypothesis_id INTEGER PRIMARY KEY AUTOINCREMENT,
    mob_id INTEGER NOT NULL,
    proof_source TEXT,
    proof_spell_id INTEGER,
    proof_event TEXT,
    FOREIGN KEY (mob_id) REFERENCES mobs(mob_id) ON DELETE CASCADE
);
CREATE TABLE IF NOT EXISTS hypothesis_candidates (
    hypothesis_id INTEGER NOT NULL,
    dimension TEXT NOT NULL,
    PRIMARY KEY (hypothesis_id, dimension),
    FOREIGN KEY (hypothesis_id) REFERENCES hypotheses(hypothesis_id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_hypotheses_mob_id ON hypotheses(mob_id);
PRAGMA user_version = 1;
COMMIT;
]]

local RESET_SCHEMA_SQL = [[
BEGIN;
DROP TABLE IF EXISTS hypothesis_candidates;
DROP TABLE IF EXISTS hypotheses;
DROP TABLE IF EXISTS facts;
DROP TABLE IF EXISTS mobs;
CREATE TABLE mobs (
    mob_id INTEGER PRIMARY KEY,
    last_name TEXT
);
CREATE TABLE facts (
    mob_id INTEGER NOT NULL,
    dimension TEXT NOT NULL,
    verdict TEXT NOT NULL CHECK (verdict IN ('immune', 'vulnerable')),
    dynamic_suspected INTEGER NOT NULL DEFAULT 0 CHECK (dynamic_suspected IN (0, 1)),
    proof_source TEXT,
    proof_spell_id INTEGER,
    proof_event TEXT,
    PRIMARY KEY (mob_id, dimension),
    FOREIGN KEY (mob_id) REFERENCES mobs(mob_id) ON DELETE CASCADE
);
CREATE TABLE hypotheses (
    hypothesis_id INTEGER PRIMARY KEY AUTOINCREMENT,
    mob_id INTEGER NOT NULL,
    proof_source TEXT,
    proof_spell_id INTEGER,
    proof_event TEXT,
    FOREIGN KEY (mob_id) REFERENCES mobs(mob_id) ON DELETE CASCADE
);
CREATE TABLE hypothesis_candidates (
    hypothesis_id INTEGER NOT NULL,
    dimension TEXT NOT NULL,
    PRIMARY KEY (hypothesis_id, dimension),
    FOREIGN KEY (hypothesis_id) REFERENCES hypotheses(hypothesis_id) ON DELETE CASCADE
);
CREATE INDEX idx_hypotheses_mob_id ON hypotheses(mob_id);
PRAGMA user_version = 1;
COMMIT;
]]

local SCHEMA_PROBES = {
    "SELECT mob_id, last_name FROM mobs LIMIT 0",
    "SELECT mob_id, dimension, verdict, dynamic_suspected, proof_source, proof_spell_id, proof_event FROM facts LIMIT 0",
    "SELECT hypothesis_id, mob_id, proof_source, proof_spell_id, proof_event FROM hypotheses LIMIT 0",
    "SELECT hypothesis_id, dimension FROM hypothesis_candidates LIMIT 0",
}

local function setError(code, message)
    Storage.ready = false
    Storage.lastErrorCode = code
    Storage.lastError = tostring(message or "unknown error")
    return false, Storage.lastError
end

local function clearError()
    Storage.lastErrorCode = nil
    Storage.lastError = nil
end

local function executeInternal(sql)
    if not Storage.handle then
        return false, "database is not open"
    end
    if type(sql) ~= "string" or sql == "" then
        return false, "SQL must be a non-empty string"
    end

    local ok, result = pcall(_G.HDB_Execute, Storage.handle, sql)
    if not ok then
        return false, tostring(result)
    end
    return true, result
end

local function queryInternal(sql)
    if not Storage.handle then
        return false, "database is not open"
    end
    if type(sql) ~= "string" or sql == "" then
        return false, "SQL must be a non-empty string"
    end

    local ok, rows = pcall(_G.HDB_Query, Storage.handle, sql)
    if not ok then
        return false, tostring(rows)
    end
    if type(rows) ~= "table" then
        return false, "HDB_Query returned a non-table result"
    end
    return true, rows
end

local function rollbackQuietly()
    if Storage.handle and type(_G.HDB_Execute) == "function" then
        pcall(_G.HDB_Execute, Storage.handle, "ROLLBACK;")
    end
end

local function createSchema()
    local ok, err = executeInternal(SCHEMA_SQL)
    if not ok then
        rollbackQuietly()
        return false, err
    end
    Storage.schemaVersion = Storage.SCHEMA_VERSION
    return true
end

local function readSchemaVersion()
    local ok, rows = queryInternal("PRAGMA user_version")
    if not ok then return false, rows end
    if table.getn(rows) < 1 or type(rows[1]) ~= "table" then
        return false, "PRAGMA user_version returned no row"
    end

    local version = tonumber(rows[1].user_version)
    if not version or version < 0 or version ~= math.floor(version) then
        return false, "PRAGMA user_version returned an invalid value"
    end
    return true, version
end

local function validateSchema()
    local i
    for i = 1, table.getn(SCHEMA_PROBES) do
        local ok, err = queryInternal(SCHEMA_PROBES[i])
        if not ok then
            return false, err
        end
    end
    return true
end

function Storage.IsHearthDBAvailable()
    local i
    for i = 1, table.getn(REQUIRED_FUNCTIONS) do
        local name = REQUIRED_FUNCTIONS[i]
        if type(_G[name]) ~= "function" then
            return false, name
        end
    end
    return true
end

function Storage.GetHearthDBVersion()
    if type(_G.HDB_GetVersion) ~= "function" then
        return nil, nil, nil
    end

    local ok, major, minor, patch = pcall(_G.HDB_GetVersion)
    if not ok then
        return nil, nil, nil
    end
    return tonumber(major), tonumber(minor), tonumber(patch)
end

function Storage.SQLText(value, allowNil)
    if value == nil and allowNil then return "NULL" end
    if type(value) ~= "string" then
        return nil, "expected string SQL value"
    end
    return "'" .. string.gsub(value, "'", "''") .. "'"
end

function Storage.SQLInteger(value, minValue, allowNil)
    if value == nil and allowNil then return "NULL" end
    local number = tonumber(value)
    if not number or number ~= math.floor(number) then
        return nil, "expected integer SQL value"
    end
    if minValue ~= nil and number < minValue then
        return nil, "integer SQL value is below minimum"
    end
    return string.format("%.0f", number)
end

function Storage.SQLBoolean(value, allowNil)
    if value == nil and allowNil then return "NULL" end
    if value == true or value == 1 then return "1" end
    if value == false or value == 0 then return "0" end
    return nil, "expected boolean SQL value"
end

function Storage.SQLEnum(value, allowed, allowNil)
    if value == nil and allowNil then return "NULL" end
    if type(value) ~= "string" or type(allowed) ~= "table" or not allowed[value] then
        return nil, "invalid enumerated SQL value"
    end
    return Storage.SQLText(value)
end

function Storage.Execute(sql)
    if not Storage.ready then
        return false, Storage.lastError or "immunity database is not ready"
    end
    return executeInternal(sql)
end

function Storage.Query(sql)
    if not Storage.ready then
        return false, Storage.lastError or "immunity database is not ready"
    end
    return queryInternal(sql)
end

function Storage.IsReady()
    return Storage.ready and true or false
end

function Storage.GetDiagnostics()
    return {
        ready = Storage.ready and true or false,
        database = Storage.DB_FILENAME,
        schemaVersion = Storage.schemaVersion,
        expectedSchemaVersion = Storage.SCHEMA_VERSION,
        hearthDBVersion = Storage.hearthDBVersion,
        lastErrorCode = Storage.lastErrorCode,
        lastError = Storage.lastError,
        lastResetReason = Storage.lastResetReason,
    }
end

function Storage.Close()
    local handle = Storage.handle
    Storage.handle = nil
    Storage.ready = false
    Storage.schemaVersion = nil

    if handle and type(_G.HDB_Close) == "function" then
        local ok, err = pcall(_G.HDB_Close, handle)
        if not ok then
            Storage.lastErrorCode = "close"
            Storage.lastError = tostring(err)
            return false, Storage.lastError
        end
    end
    return true
end

function Storage.ResetSchema(reason)
    if not Storage.handle then
        return setError("schema", "cannot reset schema before the database is open")
    end

    local ok, err = executeInternal(RESET_SCHEMA_SQL)
    if not ok then
        rollbackQuietly()
        return setError("schema", "schema reset failed: " .. tostring(err))
    end

    Storage.schemaVersion = Storage.SCHEMA_VERSION
    Storage.lastResetReason = reason or "manual reset"

    local valid, validationError = validateSchema()
    if not valid then
        return setError("schema", "schema validation failed after reset: " .. tostring(validationError))
    end

    clearError()
    Storage.ready = true
    return true
end

function Storage.Initialize()
    if Storage.handle then
        local closed, closeError = Storage.Close()
        if not closed then
            return setError("close", "could not close the previous HearthDB handle: " .. tostring(closeError))
        end
    end

    Storage.ready = false
    Storage.schemaVersion = nil
    Storage.hearthDBVersion = nil
    Storage.lastResetReason = nil
    clearError()

    local available, missing = Storage.IsHearthDBAvailable()
    if not available then
        return setError("missing", "HearthDB function is unavailable: " .. tostring(missing))
    end

    local major, minor, patch = Storage.GetHearthDBVersion()
    if major == nil or minor == nil or patch == nil then
        return setError("missing", "HDB_GetVersion failed")
    end
    Storage.hearthDBVersion = string.format("%d.%d.%d", major, minor, patch)

    local ok, handle = pcall(_G.HDB_Open, Storage.DB_FILENAME)
    if not ok then
        return setError("open", handle)
    end
    if type(handle) ~= "number" then
        return setError("open", "HDB_Open returned an invalid handle")
    end
    Storage.handle = handle

    local versionOK, version = readSchemaVersion()
    if not versionOK then
        local err = version
        Storage.Close()
        return setError("schema", "could not read schema version: " .. tostring(err))
    end
    Storage.schemaVersion = version

    if version == 0 then
        -- user_version=0 alone does not prove this file is a new empty DB.
        -- An existing unversioned/partial schema must never be modified.
        local inspected, existingTables = queryInternal(
            "SELECT name FROM sqlite_master WHERE type = 'table' LIMIT 1")
        if not inspected or table.getn(existingTables) > 0 then
            Storage.Close()
            if not inspected then
                return setError("schema", "could not inspect unversioned schema: " ..
                    tostring(existingTables) .. "; data preserved")
            end
            return setError("schema", "unversioned database already contains tables; data preserved")
        end
        local created, createError = createSchema()
        if not created then
            Storage.Close()
            return setError("schema", "schema creation failed: " .. tostring(createError))
        end
    elseif version ~= Storage.SCHEMA_VERSION then
        -- DLSI startup must never reset existing HearthDB records implicitly.
        -- A mismatched schema is unavailable until an explicit recovery decision.
        Storage.Close()
        return setError("schema", "unsupported existing schema version " .. tostring(version) ..
            " (expected " .. tostring(Storage.SCHEMA_VERSION) .. "); data preserved")
    end

    local valid, validationError = validateSchema()
    if not valid then
        -- Corrupt/incompatible schema is not permission to destroy learner data.
        Storage.Close()
        return setError("schema", "existing schema validation failed: " ..
            tostring(validationError) .. "; data preserved")
    end

    clearError()
    Storage.ready = true
    Storage.schemaVersion = Storage.SCHEMA_VERSION
    return true
end

end
-- END preserved source: ImmunityStorage.lua

-- BEGIN preserved source: ImmunityTransient.lua (design/temp-cc-immunity)
local function LoadOriginalImmunityTransient(namespace)
local _G = _G or getfenv(0)
local CleveRoids = namespace -- DLSI private namespace; never alias the host
-- No host-global assignment: module exports remain private.

-- Slice 3 transient-only immunity safety reducer.
--
-- This module consumes only normalized ImmunityObservations. It maintains
-- target-centric NPC stun DR state plus temporary explanations that later
-- inference slices may query. Nothing here writes HearthDB, SavedVariables,
-- permanent immunity facts, or the production learner.
local Pipeline = CleveRoids.ImmunityObservations
local Context = CleveRoids.ImmunityTransient or {}
CleveRoids.ImmunityTransient = Context

Context.DR_RESET_WINDOW = 20
Context.DEATH_GUARD_WINDOW = 3
Context.STUN_EVENT_DEDUPE_WINDOW = 0.10

local VALID_DR_BUCKETS = {
    stun_control = true,
    stun_trigger = true,
    stun_kidneyshot = true,
}

local targets = Context.targets or {}
Context.targets = targets

local diagnostics = {
    observationsSeen = 0,
    auraTransitions = 0,
    stunLanded = 0,
    stunDeduped = 0,
    drCertain = 0,
    drUncertain = 0,
    deaths = 0,
    despawns = 0,
    worldResets = 0,
    last = nil,
}

local function normalizeGUID(guid)
    if guid == nil then return nil end
    if CleveRoids.NormalizeGUID then
        return CleveRoids.NormalizeGUID(guid)
    end
    return tostring(guid)
end

local function containsDimension(profile, dimension)
    if not profile or not profile.mechanicDimensions then return false end
    for i = 1, table.getn(profile.mechanicDimensions) do
        if profile.mechanicDimensions[i] == dimension then
            return true
        end
    end
    return false
end

local function getTargetState(guid, mobID, create)
    guid = normalizeGUID(guid)
    if not guid then return nil end

    local state = targets[guid]
    if state and mobID and state.mobID and state.mobID ~= mobID then
        -- A reused/re-resolved GUID must never inherit transient state from a
        -- different creature-template entry.
        targets[guid] = nil
        state = nil
    end

    if not state and create then
        state = {
            guid = guid,
            mobID = mobID,
            dr = {},
            auras = {},
            lastStunAt = {},
        }
        targets[guid] = state
    elseif state and mobID and not state.mobID then
        state.mobID = mobID
    end

    return state
end

local function resetTargetState(state, mobID)
    state.mobID = mobID
    state.dr = {}
    state.drCategoryUncertainUntil = nil
    state.drCategoryUncertain = nil
    state.auras = {}
    state.lastStunAt = {}
    state.deadUntil = nil
    state.lifecycle = nil
    state.lifecycleAt = nil
end

local function pruneState(state, now)
    if not state then return end

    for bucket, entry in pairs(state.dr) do
        if not entry.lastHitTime or (now - entry.lastHitTime) >= Context.DR_RESET_WINDOW then
            state.dr[bucket] = nil
        end
    end

    if state.drCategoryUncertainUntil and now >= state.drCategoryUncertainUntil then
        state.drCategoryUncertainUntil = nil
        state.drCategoryUncertain = nil
    end

    if state.deadUntil and now >= state.deadUntil then
        state.deadUntil = nil
        if state.lifecycle == "died" then
            state.lifecycle = nil
            state.lifecycleAt = nil
        end
    end
end

local function copyEffects(effects)
    local result = {}
    for i = 1, table.getn(effects or {}) do
        local effect = effects[i]
        table.insert(result, {
            source = effect.source,
            dimension = effect.dimension,
            auraType = effect.auraType,
            auraID = effect.auraID,
        })
    end
    return result
end

local function classifyAuraEffects(observation)
    if not CleveRoids.GetTransientImmunityAuraEffects then
        return {}
    end

    local mobID = observation.targetMobID
    if not mobID and observation.targetGUID then
        local state = getTargetState(observation.targetGUID, nil, false)
        mobID = state and state.mobID or nil
    end

    return CleveRoids.GetTransientImmunityAuraEffects(
        observation.spellID,
        mobID
    )
end

local function rememberAura(observation, now)
    local state = getTargetState(
        observation.targetGUID,
        observation.targetMobID,
        false
    )

    if observation.auraOperation == "removed" then
        if state and state.auras[observation.spellID] then
            state.auras[observation.spellID] = nil
            diagnostics.auraTransitions = diagnostics.auraTransitions + 1
        end
        return
    end

    if observation.outcome ~= "aura_present" then return end

    local effects = classifyAuraEffects(observation)
    if table.getn(effects) == 0 then return end

    if not state then
        state = getTargetState(
            observation.targetGUID,
            observation.targetMobID,
            true
        )
    end
    if not state then return end

    state.auras[observation.spellID] = {
        spellID = observation.spellID,
        since = now,
        effects = copyEffects(effects),
    }
    diagnostics.auraTransitions = diagnostics.auraTransitions + 1
end

local function stunDedupeKey(observation)
    return tostring(observation.spellID or 0)
        .. ":" .. tostring(observation.casterGUID or "?")
        .. ":" .. tostring(observation.auraSlot or observation.luaSlot or "?")
end

local function recordLandedStun(observation, now)
    if observation.kind ~= "aura"
        or observation.auraKind ~= "debuff"
        or observation.outcome ~= "aura_present"
        or not containsDimension(observation.spell, "stun") then
        return
    end

    local existing = getTargetState(
        observation.targetGUID,
        observation.targetMobID,
        false
    )
    local mobID = observation.targetMobID or (existing and existing.mobID)
    if not mobID then
        -- We only advance NPC DR after the GUID has been proven to be a creature.
        return
    end

    local state = getTargetState(observation.targetGUID, mobID, true)
    if not state then return end
    pruneState(state, now)

    local key = stunDedupeKey(observation)
    local last = state.lastStunAt[key]
    if last and (now - last) < Context.STUN_EVENT_DEDUPE_WINDOW then
        diagnostics.stunDeduped = diagnostics.stunDeduped + 1
        return
    end
    state.lastStunAt[key] = now
    diagnostics.stunLanded = diagnostics.stunLanded + 1

    local bucket, certain, reason = nil, false, "classifier_unavailable"
    if CleveRoids.ClassifyNPCStunDR then
        bucket, certain, reason = CleveRoids.ClassifyNPCStunDR(
            observation.spellID,
            observation.casterGUID
        )
    end

    if certain and VALID_DR_BUCKETS[bucket] then
        local entry = state.dr[bucket]
        local count = 1
        if entry and entry.lastHitTime
            and (now - entry.lastHitTime) < Context.DR_RESET_WINDOW then
            count = (entry.count or 0) + 1
        end
        state.dr[bucket] = {
            count = count,
            lastHitTime = now,
            spellID = observation.spellID,
            casterGUID = observation.casterGUID,
            reason = reason,
        }
        diagnostics.drCertain = diagnostics.drCertain + 1
    else
        -- Nampower OTHER/aura evidence does not expose vMaNGOS's runtime
        -- triggered flag. Never guess controlled vs triggered: retain a
        -- temporary blocker until any plausible DR category has reset.
        state.drCategoryUncertainUntil = now + Context.DR_RESET_WINDOW
        state.drCategoryUncertain = {
            time = now,
            spellID = observation.spellID,
            casterGUID = observation.casterGUID,
            reason = reason or "controlled_vs_triggered_unknown",
        }
        diagnostics.drUncertain = diagnostics.drUncertain + 1
    end
end

local function clearTargetForLifecycle(observation, now)
    local guid = normalizeGUID(observation.targetGUID)
    if not guid then return end

    if observation.outcome == "died" then
        local state = getTargetState(guid, observation.targetMobID, true)
        if not state then return end
        local mobID = state.mobID
        resetTargetState(state, mobID)
        state.deadUntil = now + Context.DEATH_GUARD_WINDOW
        state.lifecycle = "died"
        state.lifecycleAt = now
        diagnostics.deaths = diagnostics.deaths + 1
    elseif observation.outcome == "despawned" then
        targets[guid] = nil
        diagnostics.despawns = diagnostics.despawns + 1
    end
end

local function onObservation(observation)
    if type(observation) ~= "table" then return end
    diagnostics.observationsSeen = diagnostics.observationsSeen + 1

    local now = tonumber(observation.timestamp) or GetTime()

    if observation.kind == "lifecycle" and observation.outcome == "world_reset" then
        for guid in pairs(targets) do
            targets[guid] = nil
        end
        diagnostics.worldResets = diagnostics.worldResets + 1
        diagnostics.last = {
            sequence = observation.sequence,
            outcome = observation.outcome,
        }
        return
    end

    if observation.kind == "death"
        or (observation.kind == "lifecycle"
            and (observation.outcome == "died" or observation.outcome == "despawned")) then
        clearTargetForLifecycle(observation, now)
    elseif observation.kind == "aura" then
        rememberAura(observation, now)
        recordLandedStun(observation, now)
    end

    diagnostics.last = {
        sequence = observation.sequence,
        kind = observation.kind,
        outcome = observation.outcome,
        targetGUID = observation.targetGUID,
        targetMobID = observation.targetMobID,
        spellID = observation.spellID,
    }
end

local function addExplanation(result, seen, source, dimension, detail, auraID)
    local key = tostring(source) .. ":" .. tostring(dimension or "")
        .. ":" .. tostring(auraID or detail or "")
    if seen[key] then return end
    seen[key] = true
    table.insert(result, {
        source = source,
        dimension = dimension,
        detail = detail,
        auraID = auraID,
    })
end

local function addLiveAuraFallbacks(result, seen, observation)
    local unit = observation.targetUnit
    if not unit then return end

    if CleveRoids.HasImmunityGuardAura then
        local _, auraType, auraID = CleveRoids.HasImmunityGuardAura(unit)
        if auraID then
            if auraType == "reflect" then
                addExplanation(result, seen, "reflection", nil, "active_aura", auraID)
            else
                addExplanation(result, seen, "temporary_aura", auraType, "active_aura", auraID)
            end
        end
    end

    if CleveRoids.IsTemporarilyCCImmune
        and observation.spell
        and observation.spell.mechanicDimensions then
        for i = 1, table.getn(observation.spell.mechanicDimensions) do
            local dimension = observation.spell.mechanicDimensions[i]
            local immune, auraID = CleveRoids.IsTemporarilyCCImmune(unit, dimension)
            if immune and auraID then
                addExplanation(
                    result,
                    seen,
                    "temporary_cc",
                    dimension,
                    "active_aura",
                    auraID
                )
            end
        end
    end
end

local function activeDRImmunityPossible(state, now)
    local buckets = { "stun_control", "stun_trigger" }
    for i = 1, table.getn(buckets) do
        local bucket = buckets[i]
        local entry = state.dr[bucket]
        if entry and entry.count and entry.count >= 3
            and entry.lastHitTime
            and (now - entry.lastHitTime) < Context.DR_RESET_WINDOW then
            return true, bucket, entry
        end
    end
    return false
end

function Context.GetDRGuard(targetGUID, spellID, casterGUID)
    local state = getTargetState(targetGUID, nil, false)
    if not state then return false end

    local now = GetTime()
    pruneState(state, now)

    if state.drCategoryUncertainUntil and now < state.drCategoryUncertainUntil then
        return true, "dr_category_uncertain", nil, nil, state.drCategoryUncertain
    end

    local bucket, certain, reason = nil, false, "classifier_unavailable"
    if CleveRoids.ClassifyNPCStunDR then
        bucket, certain, reason = CleveRoids.ClassifyNPCStunDR(spellID, casterGUID)
    end

    if not certain or not VALID_DR_BUCKETS[bucket] then
        -- The current OTHER-caster stun may itself be control or trigger. If
        -- either plausible bucket has already reached immune-stage DR, permanent
        -- inference must remain blocked rather than choosing one.
        local possible, possibleBucket, entry = activeDRImmunityPossible(state, now)
        if possible then
            return true, "dr_category_uncertain", nil, entry.count, {
                reason = reason or "controlled_vs_triggered_unknown",
                possibleBucket = possibleBucket,
                entry = entry,
            }
        end
        return false, nil, bucket
    end

    local entry = state.dr[bucket]
    if entry and entry.count and entry.count >= 3
        and entry.lastHitTime
        and (now - entry.lastHitTime) < Context.DR_RESET_WINDOW then
        return true, "dr", bucket, entry.count, entry
    end

    return false, nil, bucket, entry and entry.count or 0, entry
end

local function identityIsUnresolved(status)
    return status == "missing_guid"
        or status == "not_live"
        or status == "stale_token"
end

function Context.GetExplanations(observation)
    local result = {}
    local seen = {}
    if type(observation) ~= "table" then return result end

    if observation.missReason == "reflect" then
        addExplanation(result, seen, "reflection", nil, "direct_miss")
    end

    local state = getTargetState(
        observation.targetGUID,
        observation.targetMobID,
        false
    )
    local now = GetTime()
    if state then
        pruneState(state, now)

        if state.deadUntil and now < state.deadUntil then
            addExplanation(result, seen, "death", nil, "recent_death")
        end

        for _, aura in pairs(state.auras) do
            for i = 1, table.getn(aura.effects or {}) do
                local effect = aura.effects[i]
                addExplanation(
                    result,
                    seen,
                    effect.source,
                    effect.dimension,
                    "normalized_aura",
                    effect.auraID
                )
            end
        end

        if containsDimension(observation.spell, "stun") then
            local guarded, source, bucket, count, detail = Context.GetDRGuard(
                observation.targetGUID,
                observation.spellID,
                observation.casterGUID
            )
            if guarded then
                addExplanation(
                    result,
                    seen,
                    source,
                    bucket,
                    count or detail
                )
            end
        end
    end

    if identityIsUnresolved(observation.targetIdentity) then
        addExplanation(
            result,
            seen,
            "target_identity_unresolved",
            nil,
            observation.targetIdentity
        )
    end

    addLiveAuraFallbacks(result, seen, observation)
    return result
end

function Context.GetTargetState(targetGUID)
    local state = getTargetState(targetGUID, nil, false)
    if not state then return nil end
    pruneState(state, GetTime())

    local snapshot = {
        guid = state.guid,
        mobID = state.mobID,
        deadUntil = state.deadUntil,
        lifecycle = state.lifecycle,
        drCategoryUncertainUntil = state.drCategoryUncertainUntil,
        drCategoryUncertain = state.drCategoryUncertain,
        dr = {},
        auras = {},
    }

    for bucket, entry in pairs(state.dr) do
        snapshot.dr[bucket] = {
            count = entry.count,
            lastHitTime = entry.lastHitTime,
            spellID = entry.spellID,
            casterGUID = entry.casterGUID,
            reason = entry.reason,
        }
    end
    for spellID, aura in pairs(state.auras) do
        snapshot.auras[spellID] = {
            spellID = aura.spellID,
            since = aura.since,
            effects = copyEffects(aura.effects),
        }
    end

    return snapshot
end

function Context.GetDiagnostics()
    local targetCount = 0
    for _ in pairs(targets) do
        targetCount = targetCount + 1
    end
    return {
        observationsSeen = diagnostics.observationsSeen,
        auraTransitions = diagnostics.auraTransitions,
        stunLanded = diagnostics.stunLanded,
        stunDeduped = diagnostics.stunDeduped,
        drCertain = diagnostics.drCertain,
        drUncertain = diagnostics.drUncertain,
        deaths = diagnostics.deaths,
        despawns = diagnostics.despawns,
        worldResets = diagnostics.worldResets,
        targetCount = targetCount,
        last = diagnostics.last,
    }
end

function Context.Reset()
    for guid in pairs(targets) do
        targets[guid] = nil
    end
end

if Pipeline and Pipeline.RegisterListener then
    Pipeline.RegisterListener(onObservation)
end

end
-- END preserved source: ImmunityTransient.lua

-- BEGIN preserved source: ImmunityKnowledge.lua (design/temp-cc-immunity)
local function LoadOriginalImmunityKnowledge(namespace)
local _G = _G or getfenv(0)
local CleveRoids = namespace -- DLSI private namespace; never alias the host
-- No host-global assignment: module exports remain private.

-- Slice 7 production knowledge backend with centralized learning diagnostics.
--
-- This module consumes normalized observations and persists:
--   * authoritative per-dimension vulnerability facts;
--   * unresolved ambiguous immunity hypotheses with linked candidates;
--   * confirmed permanent immunity when exactly one valid permanent cause remains;
--   * revocation of a confirmed permanent fact on authoritative success; and
--   * an independent dynamic/conditional-immunity suspicion flag after revocation.
--
-- Production queries now consume these facts. Broad-immunity promotion and
-- Slice 7 UI/SCT diagnostics remain deferred.
local Pipeline = CleveRoids.ImmunityObservations
local Storage = CleveRoids.ImmunityStorage
local Transient = CleveRoids.ImmunityTransient

local Knowledge = CleveRoids.ImmunityKnowledge or {}
CleveRoids.ImmunityKnowledge = Knowledge

-- Presence of this module is the production cutover gate. It deliberately does
-- not depend on storage readiness: HearthDB is required, and an unavailable
-- database must not silently reactivate the legacy SavedVariables learner.
Knowledge.ACTIVE = true

function Knowledge.IsActive()
    return Knowledge.ACTIVE == true
end

local CANDIDATE_DIMENSIONS = {
    physical = true,
    holy = true,
    fire = true,
    nature = true,
    frost = true,
    shadow = true,
    arcane = true,

    stun = true,
    freeze = true,
    knockout = true,
    fear = true,
    root = true,
    silence = true,
    sleep = true,
    charm = true,
    polymorph = true,
    banish = true,
    shackle = true,
    horror = true,
    disorient = true,
    daze = true,
    snare = true,

    bleed = true,
    dispel_magic = true,
    curse = true,
    disease = true,
    poison = true,
}

-- Broad facts are reserved/queryable by the production model, but the bounded
-- Slice 6 learner still never manufactures broad-immunity candidates or promotes them.
local FACT_DIMENSIONS = {}
for dimension in pairs(CANDIDATE_DIMENSIONS) do
    FACT_DIMENSIONS[dimension] = true
end
FACT_DIMENSIONS.spell = true
FACT_DIMENSIONS.cc = true
FACT_DIMENSIONS.all = true

local NONPHYSICAL_SCHOOLS = {
    holy = true,
    fire = true,
    nature = true,
    frost = true,
    shadow = true,
    arcane = true,
}

local diagnostics = {
    observationsSeen = 0,
    successesSeen = 0,
    vulnerabilitiesRecorded = 0,
    vulnerableCandidatesEliminated = 0,
    hypothesesCreated = 0,
    hypothesesDeduped = 0,
    hypothesesDiscardedKnownVulnerable = 0,
    hypothesesBlockedTransient = 0,
    ambiguousUnsupported = 0,
    missingIdentity = 0,
    storageUnavailable = 0,
    storageErrors = 0,
    permanentConfirmations = 0,
    permanentRevocations = 0,
    dynamicSuspicionsSet = 0,
    hypothesesBlockedDynamic = 0,
    hypothesesResolvedKnownImmune = 0,
    hypothesesDiscardedDynamic = 0,
    knownVulnerableFastPaths = 0,
    last = nil,
}

local transitionListeners = {}

local function notifyKnowledgeChanged()
    if CleveRoids.NotifyImmunityDataChanged then
        CleveRoids.NotifyImmunityDataChanged()
    end
end

local function incrementLast(kind, observation, detail)
    diagnostics.last = {
        kind = kind,
        sequence = observation and observation.sequence or nil,
        event = observation and observation.event or nil,
        mobID = observation and observation.targetMobID or nil,
        spellID = observation and observation.spellID or nil,
        detail = detail,
    }
end

local function validMobID(value)
    local number = tonumber(value)
    if not number or number <= 0 or number ~= math.floor(number) then
        return nil
    end
    return number
end

local function validSpellID(value)
    local number = tonumber(value)
    if not number or number <= 0 or number ~= math.floor(number) then
        return nil
    end
    return number
end

local function addDimension(list, seen, dimension)
    if not dimension or not CANDIDATE_DIMENSIONS[dimension] or seen[dimension] then
        return
    end
    seen[dimension] = true
    table.insert(list, dimension)
end

local function sortedCopy(list)
    local result = {}
    local i
    for i = 1, table.getn(list or {}) do
        result[i] = list[i]
    end
    table.sort(result)
    return result
end

local function candidateSignature(list)
    return table.concat(sortedCopy(list), "|")
end

function Knowledge.RegisterTransitionListener(listener)
    if type(listener) ~= "function" then return false end
    local i
    for i = 1, table.getn(transitionListeners) do
        if transitionListeners[i] == listener then
            return true
        end
    end
    table.insert(transitionListeners, listener)
    return true
end

function Knowledge.UnregisterTransitionListener(listener)
    local i
    for i = table.getn(transitionListeners), 1, -1 do
        if transitionListeners[i] == listener then
            table.remove(transitionListeners, i)
        end
    end
end

local function emitTransition(state, observation, dimensions, detail)
    if table.getn(transitionListeners) == 0 then return end

    local transition = {
        state = state,
        sequence = observation and observation.sequence or nil,
        event = observation and observation.event or nil,
        mobID = validMobID(observation and observation.targetMobID or nil),
        targetName = observation and observation.targetName or nil,
        spellID = validSpellID(observation and observation.spellID or nil),
        dimensions = sortedCopy(dimensions or {}),
        reason = detail and detail.reason or nil,
        hypothesisID = detail and detail.hypothesisID or nil,
        proofSource = detail and detail.proofSource or nil,
        proofSpellID = detail and validSpellID(detail.proofSpellID) or nil,
        proofEvent = detail and detail.proofEvent or nil,
    }

    local i
    for i = 1, table.getn(transitionListeners) do
        pcall(transitionListeners[i], transition)
    end
end

local function quoteText(value, allowNil)
    local result, err = Storage.SQLText(value, allowNil)
    if not result then
        return nil, err
    end
    return result
end

local function quoteInteger(value, minimum, allowNil)
    local result, err = Storage.SQLInteger(value, minimum, allowNil)
    if not result then
        return nil, err
    end
    return result
end

local function storageReady()
    return Storage and Storage.IsReady and Storage.IsReady()
end

local function executeTransaction(statements)
    if table.getn(statements) == 0 then
        return true
    end

    local sql = "BEGIN;\n" .. table.concat(statements, "\n") .. "\nCOMMIT;"
    local ok, err = Storage.Execute(sql)
    if not ok then
        pcall(Storage.Execute, "ROLLBACK;")
        return false, err
    end
    return true
end

local function mobStatements(mobID, name)
    local mobSQL = quoteInteger(mobID, 1, false)
    if not mobSQL then return nil end

    local statements = {}
    if type(name) == "string" and name ~= "" then
        local nameSQL = quoteText(name, false)
        if not nameSQL then return nil end
        table.insert(statements,
            "INSERT OR IGNORE INTO mobs (mob_id, last_name) VALUES (" ..
            mobSQL .. ", " .. nameSQL .. ");")
        table.insert(statements,
            "UPDATE mobs SET last_name = " .. nameSQL ..
            " WHERE mob_id = " .. mobSQL .. ";")
    else
        table.insert(statements,
            "INSERT OR IGNORE INTO mobs (mob_id, last_name) VALUES (" ..
            mobSQL .. ", NULL);")
    end
    return statements
end

local function appendStatements(target, source)
    local i
    for i = 1, table.getn(source or {}) do
        table.insert(target, source[i])
    end
end

local function loadFactMap(mobID)
    local mobSQL = quoteInteger(mobID, 1, false)
    if not mobSQL then return false, "invalid mob ID" end

    local ok, rows = Storage.Query(
        "SELECT dimension, verdict, dynamic_suspected, proof_source, " ..
        "proof_spell_id, proof_event FROM facts WHERE mob_id = " .. mobSQL
    )
    if not ok then return false, rows end

    local result = {}
    local i
    for i = 1, table.getn(rows) do
        local row = rows[i]
        if row and row.dimension then
            result[tostring(row.dimension)] = row
        end
    end
    return true, result
end

local function queryCandidateCount(mobID, dimensions)
    if table.getn(dimensions or {}) == 0 then return 0 end

    local mobSQL = quoteInteger(mobID, 1, false)
    if not mobSQL then return 0 end

    local quoted = {}
    local i
    for i = 1, table.getn(dimensions) do
        local value = quoteText(dimensions[i], false)
        if value then table.insert(quoted, value) end
    end
    if table.getn(quoted) == 0 then return 0 end

    local ok, rows = Storage.Query(
        "SELECT COUNT(*) AS candidate_count " ..
        "FROM hypothesis_candidates c " ..
        "JOIN hypotheses h ON h.hypothesis_id = c.hypothesis_id " ..
        "WHERE h.mob_id = " .. mobSQL ..
        " AND c.dimension IN (" .. table.concat(quoted, ",") .. ")"
    )
    if not ok or table.getn(rows) == 0 then return 0 end
    return tonumber(rows[1].candidate_count) or 0
end

local function successDimensions(observation)
    local result = {}
    local seen = {}
    local profile = observation and observation.spell or nil

    if not observation or not profile then return result end

    if observation.kind == "damage" and observation.outcome == "damage_landed" then
        local school = observation.runtimeSchool or profile.school
        addDimension(result, seen, school)
        return result
    end

    if observation.kind ~= "aura"
        or observation.outcome ~= "aura_present"
        or observation.auraKind ~= "debuff" then
        return result
    end

    -- A real hostile aura proves the spell/action school did not block the
    -- application, independently from any exact mechanic/effect-family proof.
    addDimension(result, seen, profile.school)
    addDimension(result, seen, profile.dispelDimension)

    if profile.spellMechanicDimension then
        addDimension(result, seen, profile.spellMechanicDimension)
        return result
    end

    -- Nampower aura presence has no effect index. If exactly one recognized
    -- aura-effect dimension exists, that dimension is authoritative; if several
    -- differ, do not guess which effect the observed aura slot represents.
    local auraDimensions = {}
    local auraSeen = {}
    local i
    for i = 1, 3 do
        local effect = profile.effects and profile.effects[i] or nil
        if effect and effect.auraName and effect.auraName > 0
            and effect.mechanicDimension then
            addDimension(auraDimensions, auraSeen, effect.mechanicDimension)
        end
    end
    if table.getn(auraDimensions) == 1 then
        addDimension(result, seen, auraDimensions[1])
    end

    return result
end

local function hypothesisCandidates(observation)
    local result = {}
    local seen = {}
    local profile = observation and observation.spell or nil

    if not observation or not profile then return result end

    if observation.failurePath == "whole_spell" then
        -- A static target-creature restriction is an alternate non-permanent
        -- vMaNGOS IMMUNE path. Because it is not a durable immunity dimension,
        -- do not create a hypothesis that Slice 5 could later over-confirm.
        if profile.targetCreatureType and profile.targetCreatureType > 0 then
            return result
        end

        -- An unrecognized spell-level mechanic or Dispel family is still a real
        -- whole-spell alternative even though Slice 4 has no durable dimension
        -- for it. Abstain instead of silently dropping that cause.
        if profile.spellMechanic and profile.spellMechanic > 0
            and not profile.spellMechanicDimension then
            return result
        end
        if profile.dispelType and profile.dispelType > 0
            and not profile.dispelDimension then
            return result
        end
        if not profile.school or not CANDIDATE_DIMENSIONS[profile.school] then
            return result
        end

        -- vMaNGOS generic IMMUNE: only whole-spell causes belong here. Per-effect
        -- mechanics are intentionally excluded because those failures are silent.
        addDimension(result, seen, profile.school)
        addDimension(result, seen, profile.spellMechanicDimension)
        addDimension(result, seen, profile.dispelDimension)
        return result
    end

    if observation.failurePath == "effect_mask_zero" then
        -- vMaNGOS IMMUNE2 can represent per-effect mechanic, aura-state,
        -- effect-type, or other effect-mask elimination. Slice 4 does not model
        -- every one of those as a durable dimension, so storing only the known
        -- subset would make a later single-candidate confirmation unsafe.
        return result
    end

    -- Portable/Octo raw IMMUNE semantics remain deliberately unverified. The
    -- adapter must normalize a proven failure path before durable hypotheses are
    -- allowed; the common reducer never branches on a core name.
    return result
end

local function hasApplicableTransientExplanation(observation, candidates)
    if not Transient or not Transient.GetExplanations then
        return false
    end

    local explanations = Transient.GetExplanations(observation)
    local candidateSet = {}
    local i
    for i = 1, table.getn(candidates or {}) do
        candidateSet[candidates[i]] = true
    end

    for i = 1, table.getn(explanations or {}) do
        local explanation = explanations[i]
        local source = explanation and explanation.source or nil
        local dimension = explanation and explanation.dimension or nil

        if source == "reflection"
            or source == "death"
            or source == "dr"
            or source == "dr_category_uncertain"
            or source == "target_identity_unresolved" then
            return true, explanation
        end

        if dimension == "all" then
            return true, explanation
        end

        if dimension == "spell" then
            local school = observation.spell and observation.spell.school or nil
            if NONPHYSICAL_SCHOOLS[school] then
                return true, explanation
            end
        elseif dimension and candidateSet[dimension] then
            return true, explanation
        end
    end

    return false
end

function Knowledge.GetFact(mobID, dimension)
    mobID = validMobID(mobID)
    if not mobID or not FACT_DIMENSIONS[dimension] or not storageReady() then
        return nil
    end

    local mobSQL = quoteInteger(mobID, 1, false)
    local dimensionSQL = quoteText(dimension, false)
    if not mobSQL or not dimensionSQL then return nil end

    local ok, rows = Storage.Query(
        "SELECT verdict, dynamic_suspected, proof_source, proof_spell_id, proof_event " ..
        "FROM facts WHERE mob_id = " .. mobSQL ..
        " AND dimension = " .. dimensionSQL .. " LIMIT 1"
    )
    if not ok or table.getn(rows) == 0 then return nil end

    local row = rows[1]
    return {
        mobID = mobID,
        dimension = dimension,
        verdict = row.verdict and tostring(row.verdict) or nil,
        dynamicSuspected = tonumber(row.dynamic_suspected) == 1,
        proofSource = row.proof_source,
        proofSpellID = tonumber(row.proof_spell_id),
        proofEvent = row.proof_event,
    }
end

-- Diagnostic read seam for the immunity screen. This exposes compact durable
-- conclusions only; raw observations remain deliberately unpersisted.
function Knowledge.GetFacts(mobID)
    mobID = validMobID(mobID)
    if not mobID or not storageReady() then return {} end

    local mobSQL = quoteInteger(mobID, 1, false)
    if not mobSQL then return {} end

    local ok, rows = Storage.Query(
        "SELECT dimension, verdict, dynamic_suspected, proof_source, " ..
        "proof_spell_id, proof_event FROM facts WHERE mob_id = " .. mobSQL ..
        " ORDER BY dimension"
    )
    if not ok then return {} end

    local result = {}
    local i
    for i = 1, table.getn(rows) do
        local row = rows[i]
        table.insert(result, {
            mobID = mobID,
            dimension = row.dimension and tostring(row.dimension) or nil,
            verdict = row.verdict and tostring(row.verdict) or nil,
            dynamicSuspected = tonumber(row.dynamic_suspected) == 1,
            proofSource = row.proof_source,
            proofSpellID = tonumber(row.proof_spell_id),
            proofEvent = row.proof_event,
        })
    end
    return result
end

-- Production/UI read seam for confirmed permanent facts. Optional dimension
-- narrows the result without changing the inference model.
function Knowledge.GetConfirmedImmunities(dimension)
    if not storageReady() then return {} end
    if dimension ~= nil and not FACT_DIMENSIONS[dimension] then return {} end

    local where = " WHERE f.verdict = 'immune'"
    if dimension ~= nil then
        local dimensionSQL = quoteText(dimension, false)
        if not dimensionSQL then return {} end
        where = where .. " AND f.dimension = " .. dimensionSQL
    end

    local ok, rows = Storage.Query(
        "SELECT f.mob_id, m.last_name AS name, f.dimension, f.dynamic_suspected, " ..
        "f.proof_source, f.proof_spell_id, f.proof_event " ..
        "FROM facts f LEFT JOIN mobs m ON m.mob_id = f.mob_id" ..
        where ..
        " ORDER BY f.dimension, m.last_name, f.mob_id"
    )
    if not ok then return {} end

    local result = {}
    local i
    for i = 1, table.getn(rows) do
        local row = rows[i]
        table.insert(result, {
            mobID = tonumber(row.mob_id),
            name = row.name and tostring(row.name) or nil,
            dimension = row.dimension and tostring(row.dimension) or nil,
            verdict = "immune",
            dynamicSuspected = tonumber(row.dynamic_suspected) == 1,
            proofSource = row.proof_source,
            proofSpellID = tonumber(row.proof_spell_id),
            proofEvent = row.proof_event,
        })
    end
    return result
end

function Knowledge.GetHypotheses(mobID)
    mobID = validMobID(mobID)
    if not mobID or not storageReady() then return {} end

    local mobSQL = quoteInteger(mobID, 1, false)
    if not mobSQL then return {} end

    local ok, rows = Storage.Query(
        "SELECT h.hypothesis_id, h.proof_source, h.proof_spell_id, h.proof_event, " ..
        "c.dimension FROM hypotheses h " ..
        "JOIN hypothesis_candidates c ON c.hypothesis_id = h.hypothesis_id " ..
        "WHERE h.mob_id = " .. mobSQL ..
        " ORDER BY h.hypothesis_id, c.dimension"
    )
    if not ok then return {} end

    local ordered = {}
    local byID = {}
    local i
    for i = 1, table.getn(rows) do
        local row = rows[i]
        local id = tonumber(row.hypothesis_id)
        if id then
            local item = byID[id]
            if not item then
                item = {
                    hypothesisID = id,
                    mobID = mobID,
                    proofSource = row.proof_source,
                    proofSpellID = tonumber(row.proof_spell_id),
                    proofEvent = row.proof_event,
                    candidates = {},
                }
                byID[id] = item
                table.insert(ordered, item)
            end
            if row.dimension then
                table.insert(item.candidates, tostring(row.dimension))
            end
        end
    end

    for i = 1, table.getn(ordered) do
        ordered[i].readyForConfirmation = table.getn(ordered[i].candidates) == 1
    end
    return ordered
end

function Knowledge.GetDimensionState(mobID, dimension)
    if not FACT_DIMENSIONS[dimension] then return "unknown" end

    local fact = Knowledge.GetFact(mobID, dimension)
    if fact and fact.verdict then
        return fact.verdict, fact
    end

    mobID = validMobID(mobID)
    if not mobID or not storageReady() then return "unknown" end

    local mobSQL = quoteInteger(mobID, 1, false)
    local dimensionSQL = quoteText(dimension, false)
    if not mobSQL or not dimensionSQL then return "unknown" end

    local ok, rows = Storage.Query(
        "SELECT h.hypothesis_id FROM hypotheses h " ..
        "JOIN hypothesis_candidates c ON c.hypothesis_id = h.hypothesis_id " ..
        "WHERE h.mob_id = " .. mobSQL ..
        " AND c.dimension = " .. dimensionSQL .. " LIMIT 1"
    )
    if ok and table.getn(rows) > 0 then
        return "suspected", { hypothesisID = tonumber(rows[1].hypothesis_id) }
    end
    return "unknown"
end


local function factVerdict(fact)
    if not fact or fact.verdict == nil then return nil end
    return tostring(fact.verdict)
end

local function factDynamicSuspected(fact)
    return fact and tonumber(fact.dynamic_suspected) == 1
end

local function listSet(list)
    local result = {}
    local i
    for i = 1, table.getn(list or {}) do
        result[list[i]] = true
    end
    return result
end

local function sortedIntegerList(set)
    local result = {}
    for value, present in pairs(set or {}) do
        local number = tonumber(value)
        if present and number and number > 0 and number == math.floor(number) then
            table.insert(result, number)
        end
    end
    table.sort(result)
    return result
end

local function sqlIntegerList(values)
    local result = {}
    local i
    for i = 1, table.getn(values or {}) do
        local value = quoteInteger(values[i], 1, false)
        if value then table.insert(result, value) end
    end
    if table.getn(result) == 0 then return nil end
    return table.concat(result, ",")
end

local function firstDynamicCandidate(facts, candidates)
    local i
    for i = 1, table.getn(candidates or {}) do
        local dimension = candidates[i]
        if factDynamicSuspected(facts[dimension]) then
            return dimension
        end
    end
    return nil
end

local function firstImmuneCandidate(facts, candidates)
    local i
    for i = 1, table.getn(candidates or {}) do
        local dimension = candidates[i]
        if factVerdict(facts[dimension]) == "immune" then
            return dimension
        end
    end
    return nil
end

local function hypothesisIDsContaining(hypotheses, dimension)
    local ids = {}
    local i, j
    for i = 1, table.getn(hypotheses or {}) do
        local hypothesis = hypotheses[i]
        for j = 1, table.getn(hypothesis.candidates or {}) do
            if hypothesis.candidates[j] == dimension then
                ids[hypothesis.hypothesisID] = true
                break
            end
        end
    end
    return sortedIntegerList(ids)
end

local function appendHypothesisDeletes(statements, ids)
    local idSQL = sqlIntegerList(ids)
    if not idSQL then return end
    table.insert(statements,
        "DELETE FROM hypothesis_candidates WHERE hypothesis_id IN (" ..
        idSQL .. ");")
    table.insert(statements,
        "DELETE FROM hypotheses WHERE hypothesis_id IN (" .. idSQL .. ");")
end

local function hypothesisProofSQL(hypothesis)
    local sourceSQL = quoteText(hypothesis and hypothesis.proofSource or nil, true)
    local spellSQL = quoteInteger(
        validSpellID(hypothesis and hypothesis.proofSpellID or nil),
        1,
        true
    )
    local eventSQL = quoteText(hypothesis and hypothesis.proofEvent or nil, true)
    return sourceSQL, spellSQL, eventSQL
end

local function appendImmuneFact(statements, mobSQL, dimension, hypothesis)
    local dimensionSQL = quoteText(dimension, false)
    local sourceSQL, spellSQL, eventSQL = hypothesisProofSQL(hypothesis)
    if not dimensionSQL or not sourceSQL or not spellSQL or not eventSQL then
        return false
    end

    table.insert(statements,
        "INSERT OR IGNORE INTO facts " ..
        "(mob_id, dimension, verdict, dynamic_suspected, proof_source, proof_spell_id, proof_event) " ..
        "VALUES (" .. mobSQL .. ", " .. dimensionSQL ..
        ", 'immune', 0, " .. sourceSQL .. ", " .. spellSQL .. ", " ..
        eventSQL .. ");")
    return true
end

local function planAfterAuthoritativeSuccess(hypotheses, facts, successSet, revokedSet)
    local survivors = {}
    local deleteIDs = {}
    local confirmations = {}
    local confirmationByDimension = {}
    local dynamicDiscardCount = 0
    local i, j

    for i = 1, table.getn(hypotheses or {}) do
        local hypothesis = hypotheses[i]
        local remaining = {}
        local blockedDynamic = false
        local explainedKnownImmune = false

        for j = 1, table.getn(hypothesis.candidates or {}) do
            local dimension = hypothesis.candidates[j]
            local fact = facts[dimension]

            if revokedSet[dimension] or factDynamicSuspected(fact) then
                blockedDynamic = true
            elseif factVerdict(fact) == "immune" and not successSet[dimension] then
                explainedKnownImmune = true
            elseif not successSet[dimension] and factVerdict(fact) ~= "vulnerable" then
                table.insert(remaining, dimension)
            end
        end

        if blockedDynamic then
            if not deleteIDs[hypothesis.hypothesisID] then
                dynamicDiscardCount = dynamicDiscardCount + 1
            end
            deleteIDs[hypothesis.hypothesisID] = true
        elseif explainedKnownImmune or table.getn(remaining) == 0 then
            deleteIDs[hypothesis.hypothesisID] = true
        else
            survivors[hypothesis.hypothesisID] = {
                hypothesis = hypothesis,
                remaining = remaining,
            }
        end
    end

    for i = 1, table.getn(hypotheses or {}) do
        local hypothesis = hypotheses[i]
        local survivor = survivors[hypothesis.hypothesisID]
        if survivor and table.getn(survivor.remaining) == 1 then
            local dimension = survivor.remaining[1]
            if not confirmationByDimension[dimension] then
                confirmationByDimension[dimension] = hypothesis
                table.insert(confirmations, {
                    dimension = dimension,
                    hypothesis = hypothesis,
                })
            end
        end
    end

    for id, survivor in pairs(survivors) do
        for j = 1, table.getn(survivor.remaining) do
            if confirmationByDimension[survivor.remaining[j]] then
                deleteIDs[id] = true
                break
            end
        end
    end

    table.sort(confirmations, function(a, b)
        return a.dimension < b.dimension
    end)

    return confirmations, sortedIntegerList(deleteIDs), dynamicDiscardCount
end

local function confirmSingleCandidate(observation, mobID, dimension, existing)
    local statements = mobStatements(mobID, observation.targetName)
    if not statements then
        return false, "invalid_mob_metadata"
    end

    local mobSQL = quoteInteger(mobID, 1, false)
    local sourceSQL = quoteText(
        "ambiguous_" .. tostring(observation.failurePath or "unknown"),
        false
    )
    local spellSQL = quoteInteger(validSpellID(observation.spellID), 1, true)
    local proofEvent = tostring(observation.event or "immune")
    if observation.immuneVariant then
        proofEvent = proofEvent .. ":" .. tostring(observation.immuneVariant)
    end
    local eventSQL = quoteText(proofEvent, false)
    local dimensionSQL = quoteText(dimension, false)
    if not mobSQL or not sourceSQL or not spellSQL or not eventSQL or not dimensionSQL then
        return false, "invalid_confirmation_provenance"
    end

    table.insert(statements,
        "INSERT OR IGNORE INTO facts " ..
        "(mob_id, dimension, verdict, dynamic_suspected, proof_source, proof_spell_id, proof_event) " ..
        "VALUES (" .. mobSQL .. ", " .. dimensionSQL ..
        ", 'immune', 0, " .. sourceSQL .. ", " .. spellSQL .. ", " ..
        eventSQL .. ");")

    appendHypothesisDeletes(statements, hypothesisIDsContaining(existing, dimension))
    table.insert(statements,
        "DELETE FROM hypotheses WHERE mob_id = " .. mobSQL ..
        " AND NOT EXISTS (SELECT 1 FROM hypothesis_candidates c " ..
        "WHERE c.hypothesis_id = hypotheses.hypothesis_id);")

    local ok, err = executeTransaction(statements)
    if ok then
        notifyKnowledgeChanged()
    end
    return ok, err
end

function Knowledge.GetSuspectedDimensions(mobID)
    mobID = validMobID(mobID)
    if not mobID or not storageReady() then return {} end

    local mobSQL = quoteInteger(mobID, 1, false)
    if not mobSQL then return {} end

    local ok, rows = Storage.Query(
        "SELECT DISTINCT c.dimension FROM hypothesis_candidates c " ..
        "JOIN hypotheses h ON h.hypothesis_id = c.hypothesis_id " ..
        "LEFT JOIN facts f ON f.mob_id = h.mob_id AND f.dimension = c.dimension " ..
        "WHERE h.mob_id = " .. mobSQL .. " AND f.mob_id IS NULL " ..
        "ORDER BY c.dimension"
    )
    if not ok then return {} end

    local result = {}
    local i
    for i = 1, table.getn(rows) do
        if rows[i].dimension then
            table.insert(result, tostring(rows[i].dimension))
        end
    end
    return result
end

local function recordVulnerability(observation)
    local mobID = validMobID(observation.targetMobID)
    if not mobID then
        diagnostics.missingIdentity = diagnostics.missingIdentity + 1
        incrementLast("success_skipped", observation, "missing_mob_id")
        return
    end

    local dimensions = successDimensions(observation)
    if table.getn(dimensions) == 0 then
        incrementLast("success_skipped", observation, "no_authoritative_dimension")
        return
    end

    diagnostics.successesSeen = diagnostics.successesSeen + 1

    local factsOK, facts = loadFactMap(mobID)
    if not factsOK then
        diagnostics.storageErrors = diagnostics.storageErrors + 1
        incrementLast("storage_error", observation, facts)
        return
    end

    -- A repeated authoritative success for dimensions already known
    -- vulnerable cannot change any durable conclusion. The first success that
    -- established vulnerability already removed those candidates from every
    -- hypothesis, so skip the hypothesis query and write transaction entirely.
    local allKnownVulnerable = true
    local fastIndex
    for fastIndex = 1, table.getn(dimensions) do
        if factVerdict(facts[dimensions[fastIndex]]) ~= "vulnerable" then
            allKnownVulnerable = false
            break
        end
    end
    if allKnownVulnerable then
        diagnostics.knownVulnerableFastPaths =
            diagnostics.knownVulnerableFastPaths + 1
        incrementLast(
            "success_known_vulnerable",
            observation,
            table.concat(sortedCopy(dimensions), ",")
        )
        return
    end

    local hypotheses = Knowledge.GetHypotheses(mobID)
    local successSet = listSet(dimensions)
    local revokedSet = {}
    local revocationCount = 0
    local dynamicSetCount = 0
    local i

    for i = 1, table.getn(dimensions) do
        local dimension = dimensions[i]
        local fact = facts[dimension]
        if factVerdict(fact) == "immune" then
            revokedSet[dimension] = true
            revocationCount = revocationCount + 1
            if not factDynamicSuspected(fact) then
                dynamicSetCount = dynamicSetCount + 1
            end
        end
    end

    local eliminatedDimensions = {}
    local eliminatedSet = {}
    local revokedDimensions = {}
    local hypothesisIndex, candidateIndex
    for hypothesisIndex = 1, table.getn(hypotheses) do
        local hypothesis = hypotheses[hypothesisIndex]
        for candidateIndex = 1, table.getn(hypothesis.candidates or {}) do
            local candidate = hypothesis.candidates[candidateIndex]
            if successSet[candidate] and not revokedSet[candidate] then
                eliminatedSet[candidate] = true
            end
        end
    end
    for candidate in pairs(eliminatedSet) do
        table.insert(eliminatedDimensions, candidate)
    end
    for dimension in pairs(revokedSet) do
        table.insert(revokedDimensions, dimension)
    end
    table.sort(eliminatedDimensions)
    table.sort(revokedDimensions)

    local confirmations, deleteIDs, dynamicDiscardCount =
        planAfterAuthoritativeSuccess(hypotheses, facts, successSet, revokedSet)

    local eliminated = queryCandidateCount(mobID, dimensions)
    local statements = mobStatements(mobID, observation.targetName)
    if not statements then
        diagnostics.storageErrors = diagnostics.storageErrors + 1
        incrementLast("storage_error", observation, "invalid_mob_metadata")
        return
    end

    local mobSQL = quoteInteger(mobID, 1, false)
    local spellSQL = quoteInteger(validSpellID(observation.spellID), 1, true)
    local sourceSQL = quoteText(
        "authoritative_" .. tostring(observation.successKind or "success"),
        false
    )
    local eventSQL = quoteText(
        tostring(observation.event or observation.outcome or "success"),
        false
    )
    if not mobSQL or not spellSQL or not sourceSQL or not eventSQL then
        diagnostics.storageErrors = diagnostics.storageErrors + 1
        incrementLast("storage_error", observation, "invalid_success_provenance")
        return
    end

    for i = 1, table.getn(dimensions) do
        local dimensionSQL = quoteText(dimensions[i], false)
        if not dimensionSQL then
            diagnostics.storageErrors = diagnostics.storageErrors + 1
            incrementLast("storage_error", observation, "invalid_success_dimension")
            return
        end

        table.insert(statements,
            "INSERT OR IGNORE INTO facts " ..
            "(mob_id, dimension, verdict, dynamic_suspected, proof_source, proof_spell_id, proof_event) " ..
            "VALUES (" .. mobSQL .. ", " .. dimensionSQL ..
            ", 'vulnerable', 0, " .. sourceSQL .. ", " .. spellSQL .. ", " ..
            eventSQL .. ");")
        table.insert(statements,
            "UPDATE facts SET " ..
            "dynamic_suspected = CASE WHEN verdict = 'immune' THEN 1 " ..
            "ELSE dynamic_suspected END, " ..
            "verdict = 'vulnerable', proof_source = " .. sourceSQL ..
            ", proof_spell_id = " .. spellSQL ..
            ", proof_event = " .. eventSQL ..
            " WHERE mob_id = " .. mobSQL ..
            " AND dimension = " .. dimensionSQL .. ";")
        table.insert(statements,
            "DELETE FROM hypothesis_candidates WHERE dimension = " .. dimensionSQL ..
            " AND hypothesis_id IN (SELECT hypothesis_id FROM hypotheses WHERE mob_id = " ..
            mobSQL .. ");")
    end

    -- Clean up any pre-existing ordinary vulnerable candidates before applying
    -- the same deterministic confirmation plan. Dynamic vulnerability is not a
    -- permanent candidate, but it remains a credible conditional explanation;
    -- hypotheses containing it are discarded whole below rather than narrowed.
    table.insert(statements,
        "DELETE FROM hypothesis_candidates WHERE hypothesis_id IN " ..
        "(SELECT hypothesis_id FROM hypotheses WHERE mob_id = " .. mobSQL .. ") " ..
        "AND dimension IN (SELECT dimension FROM facts WHERE mob_id = " .. mobSQL ..
        " AND verdict = 'vulnerable' AND dynamic_suspected = 0);")

    for i = 1, table.getn(confirmations) do
        if not appendImmuneFact(
            statements,
            mobSQL,
            confirmations[i].dimension,
            confirmations[i].hypothesis
        ) then
            diagnostics.storageErrors = diagnostics.storageErrors + 1
            incrementLast("storage_error", observation, "invalid_confirmation_provenance")
            return
        end
    end

    appendHypothesisDeletes(statements, deleteIDs)
    table.insert(statements,
        "DELETE FROM hypotheses WHERE mob_id = " .. mobSQL ..
        " AND NOT EXISTS (SELECT 1 FROM hypothesis_candidates c " ..
        "WHERE c.hypothesis_id = hypotheses.hypothesis_id);")

    local ok, err = executeTransaction(statements)
    if not ok then
        diagnostics.storageErrors = diagnostics.storageErrors + 1
        incrementLast("storage_error", observation, err)
        return
    end

    notifyKnowledgeChanged()

    diagnostics.vulnerabilitiesRecorded =
        diagnostics.vulnerabilitiesRecorded + table.getn(dimensions)
    diagnostics.vulnerableCandidatesEliminated =
        diagnostics.vulnerableCandidatesEliminated + eliminated
    diagnostics.permanentRevocations =
        diagnostics.permanentRevocations + revocationCount
    diagnostics.dynamicSuspicionsSet =
        diagnostics.dynamicSuspicionsSet + dynamicSetCount
    diagnostics.permanentConfirmations =
        diagnostics.permanentConfirmations + table.getn(confirmations)
    diagnostics.hypothesesDiscardedDynamic =
        diagnostics.hypothesesDiscardedDynamic + dynamicDiscardCount

    -- Learning SCT consumes only meaningful state transitions. A routine
    -- vulnerability fact with no active candidate is intentionally silent.
    if table.getn(eliminatedDimensions) > 0 then
        emitTransition("disproved", observation, eliminatedDimensions, {
            reason = "candidate_eliminated",
        })
    end
    for i = 1, table.getn(confirmations) do
        local confirmation = confirmations[i]
        local proof = confirmation.hypothesis
        emitTransition("confirmed", observation, { confirmation.dimension }, {
            reason = "permanent_confirmed",
            hypothesisID = proof and proof.hypothesisID or nil,
            proofSource = proof and proof.proofSource or nil,
            proofSpellID = proof and proof.proofSpellID or nil,
            proofEvent = proof and proof.proofEvent or nil,
        })
    end
    if table.getn(revokedDimensions) > 0 then
        emitTransition("conditional", observation, revokedDimensions, {
            reason = "confirmed_immunity_revoked",
        })
    end

    local detail = "vulnerable=" .. table.concat(sortedCopy(dimensions), ",")
    if revocationCount > 0 then
        detail = detail .. ";revoked=" .. tostring(revocationCount)
    end
    if table.getn(confirmations) > 0 then
        local confirmed = {}
        for i = 1, table.getn(confirmations) do
            table.insert(confirmed, confirmations[i].dimension)
        end
        detail = detail .. ";confirmed=" .. table.concat(sortedCopy(confirmed), ",")
    end
    incrementLast("vulnerable", observation, detail)
end

local function createHypothesis(observation)
    local mobID = validMobID(observation.targetMobID)
    if not mobID then
        diagnostics.missingIdentity = diagnostics.missingIdentity + 1
        incrementLast("hypothesis_skipped", observation, "missing_mob_id")
        return
    end

    local candidates = hypothesisCandidates(observation)
    if table.getn(candidates) == 0 then
        diagnostics.ambiguousUnsupported = diagnostics.ambiguousUnsupported + 1
        incrementLast("hypothesis_skipped", observation, "unverified_or_unclassified_failure_path")
        return
    end

    local blocked, explanation = hasApplicableTransientExplanation(observation, candidates)
    if blocked then
        diagnostics.hypothesesBlockedTransient =
            diagnostics.hypothesesBlockedTransient + 1
        incrementLast(
            "hypothesis_blocked",
            observation,
            explanation and explanation.source or "transient"
        )
        return
    end

    local factsOK, facts = loadFactMap(mobID)
    if not factsOK then
        diagnostics.storageErrors = diagnostics.storageErrors + 1
        incrementLast("storage_error", observation, facts)
        return
    end

    -- A previously confirmed immunity that was later disproved is no longer a
    -- valid permanent candidate, but its dynamic flag is positive evidence that
    -- this dimension can still explain an IMMUNE conditionally. Do not use that
    -- event to over-confirm a different permanent dimension.
    local dynamicDimension = firstDynamicCandidate(facts, candidates)
    if dynamicDimension then
        diagnostics.hypothesesBlockedDynamic =
            diagnostics.hypothesesBlockedDynamic + 1
        incrementLast("hypothesis_blocked", observation, "dynamic:" .. dynamicDimension)
        return
    end

    -- If a permanent candidate is already confirmed immune, the observation is
    -- already explained. It contributes no new ambiguity about the other
    -- dimensions.
    local immuneDimension = firstImmuneCandidate(facts, candidates)
    if immuneDimension then
        diagnostics.hypothesesResolvedKnownImmune =
            diagnostics.hypothesesResolvedKnownImmune + 1
        incrementLast("hypothesis_resolved", observation, "known_immune:" .. immuneDimension)
        return
    end

    local remaining = {}
    local i
    for i = 1, table.getn(candidates) do
        local dimension = candidates[i]
        if factVerdict(facts[dimension]) ~= "vulnerable" then
            table.insert(remaining, dimension)
        end
    end

    if table.getn(remaining) == 0 then
        diagnostics.hypothesesDiscardedKnownVulnerable =
            diagnostics.hypothesesDiscardedKnownVulnerable + 1
        incrementLast("hypothesis_discarded", observation, "all_candidates_vulnerable")
        return
    end

    local existing = Knowledge.GetHypotheses(mobID)

    if table.getn(remaining) == 1 then
        local ok, err = confirmSingleCandidate(
            observation,
            mobID,
            remaining[1],
            existing
        )
        if not ok then
            diagnostics.storageErrors = diagnostics.storageErrors + 1
            incrementLast("storage_error", observation, err)
            return
        end

        diagnostics.permanentConfirmations =
            diagnostics.permanentConfirmations + 1
        incrementLast("immune_confirmed", observation, remaining[1])
        emitTransition("confirmed", observation, { remaining[1] }, {
            reason = "permanent_confirmed",
            proofSource = "ambiguous_" .. tostring(observation.failurePath or "unknown"),
            proofSpellID = observation.spellID,
            proofEvent = observation.event,
        })
        return
    end

    local signature = candidateSignature(remaining)
    for i = 1, table.getn(existing) do
        if candidateSignature(existing[i].candidates) == signature then
            diagnostics.hypothesesDeduped = diagnostics.hypothesesDeduped + 1
            incrementLast("hypothesis_deduped", observation, signature)
            return
        end
    end

    local statements = mobStatements(mobID, observation.targetName)
    if not statements then
        diagnostics.storageErrors = diagnostics.storageErrors + 1
        incrementLast("storage_error", observation, "invalid_mob_metadata")
        return
    end

    local mobSQL = quoteInteger(mobID, 1, false)
    local spellSQL = quoteInteger(validSpellID(observation.spellID), 1, true)
    local sourceSQL = quoteText(
        "ambiguous_" .. tostring(observation.failurePath or "unknown"),
        false
    )
    local proofEvent = tostring(observation.event or "immune")
    if observation.immuneVariant then
        proofEvent = proofEvent .. ":" .. tostring(observation.immuneVariant)
    end
    local eventSQL = quoteText(proofEvent, false)

    table.insert(statements,
        "INSERT INTO hypotheses (mob_id, proof_source, proof_spell_id, proof_event) " ..
        "VALUES (" .. mobSQL .. ", " .. sourceSQL .. ", " .. spellSQL .. ", " ..
        eventSQL .. ");")

    for i = 1, table.getn(remaining) do
        local dimensionSQL = quoteText(remaining[i], false)
        table.insert(statements,
            "INSERT INTO hypothesis_candidates (hypothesis_id, dimension) " ..
            "SELECT MAX(hypothesis_id), " .. dimensionSQL .. " FROM hypotheses;")
    end

    local ok, err = executeTransaction(statements)
    if not ok then
        diagnostics.storageErrors = diagnostics.storageErrors + 1
        incrementLast("storage_error", observation, err)
        return
    end

    notifyKnowledgeChanged()
    diagnostics.hypothesesCreated = diagnostics.hypothesesCreated + 1
    incrementLast("hypothesis_created", observation, signature)
    emitTransition("candidate", observation, remaining, {
        reason = "hypothesis_created",
        proofSource = "ambiguous_" .. tostring(observation.failurePath or "unknown"),
        proofSpellID = observation.spellID,
        proofEvent = observation.event,
    })
end

function Knowledge.ProcessObservation(observation)
    if type(observation) ~= "table" then return end
    diagnostics.observationsSeen = diagnostics.observationsSeen + 1

    if not storageReady() then
        diagnostics.storageUnavailable = diagnostics.storageUnavailable + 1
        incrementLast("storage_unavailable", observation, "not_ready")
        return
    end

    if observation.evidence == Pipeline.EVIDENCE.AUTHORITATIVE_SUCCESS
        and observation.authoritative then
        recordVulnerability(observation)
        return
    end

    if observation.evidence == Pipeline.EVIDENCE.AMBIGUOUS_IMMUNE then
        createHypothesis(observation)
    end
end

function Knowledge.GetDiagnostics()
    return {
        observationsSeen = diagnostics.observationsSeen,
        successesSeen = diagnostics.successesSeen,
        vulnerabilitiesRecorded = diagnostics.vulnerabilitiesRecorded,
        vulnerableCandidatesEliminated = diagnostics.vulnerableCandidatesEliminated,
        hypothesesCreated = diagnostics.hypothesesCreated,
        hypothesesDeduped = diagnostics.hypothesesDeduped,
        hypothesesDiscardedKnownVulnerable = diagnostics.hypothesesDiscardedKnownVulnerable,
        hypothesesBlockedTransient = diagnostics.hypothesesBlockedTransient,
        ambiguousUnsupported = diagnostics.ambiguousUnsupported,
        missingIdentity = diagnostics.missingIdentity,
        storageUnavailable = diagnostics.storageUnavailable,
        storageErrors = diagnostics.storageErrors,
        permanentConfirmations = diagnostics.permanentConfirmations,
        permanentRevocations = diagnostics.permanentRevocations,
        dynamicSuspicionsSet = diagnostics.dynamicSuspicionsSet,
        hypothesesBlockedDynamic = diagnostics.hypothesesBlockedDynamic,
        hypothesesResolvedKnownImmune = diagnostics.hypothesesResolvedKnownImmune,
        hypothesesDiscardedDynamic = diagnostics.hypothesesDiscardedDynamic,
        knownVulnerableFastPaths = diagnostics.knownVulnerableFastPaths,
        last = diagnostics.last,
    }
end

function Knowledge.GetCandidatesForObservation(observation)
    return sortedCopy(hypothesisCandidates(observation))
end

function Knowledge.GetSuccessDimensions(observation)
    return sortedCopy(successDimensions(observation))
end

if Pipeline and Pipeline.RegisterListener then
    Pipeline.RegisterListener(Knowledge.ProcessObservation)
end

end
-- END preserved source: ImmunityKnowledge.lua

-- BEGIN preserved source: ImmunityUI.lua (design/temp-cc-immunity)
local function LoadOriginalImmunityUI(namespace)
--[[
    Immunity testing/management UI
    Production immunity inspection/management surface. No inference lives here.
    Learned permanent facts are read from ImmunityKnowledge/HearthDB; the
    SavedVariables table is retained only for explicit manual/static overrides.
]]
local _G = _G or getfenv(0)
local CleveRoids = namespace -- DLSI private namespace; never alias the host

local DATA_VERSION = 1
local MAIN_WIDTH = 710
local MAIN_HEIGHT = 690
local TARGET_WIDTH = 300
local COLUMN_WIDTH = 138
local COLUMN_GAP = 6
local SECTION_WIDTH = 670
local HEADER_ICON_SIZE = 18
local MODAL_FRAME_LEVEL_OFFSET = 50
local TARGET_MODEL_WIDTH = 118
local TARGET_MODEL_HEIGHT = 126
local TARGET_MODEL_REVOLUTION_SECONDS = 12

local widgetCounter = 0
local mainFrame
local targetFrame
local clearDialog
local historyDialog
local ccSection
local spellSection
local legacyTitle
local legacyList
local targetNameText
local targetInfoText
local targetModel
local targetModelRotation = 0
local targetModelRotating = false
local targetCCList
local targetSpellList
local targetLiveList
local learningSCTToggle
local learningSCTDriver
local learningSCTEntries = {}

local CC_COLUMNS = {
    { key = "cc", type = "cc", label = "CC", broad = true, iconSpellID = 853 }, -- Hammer of Justice
    { key = "cc_charm", type = "charm", mechanicID = 1, label = "Charm", iconSpellID = 6358 }, -- Seduction
    { key = "cc_disorient", type = "disorient", mechanicID = 2, label = "Disorient", iconSpellID = 1776 }, -- Gouge
    { key = "cc_fear", type = "fear", mechanicID = 5, label = "Fear", iconSpellID = 5782 }, -- Fear
    { key = "cc_root", type = "root", mechanicID = 7, label = "Root", iconSpellID = 339 }, -- Entangling Roots
    { key = "cc_silence", type = "silence", mechanicID = 9, label = "Silence", iconSpellID = 15487 }, -- Silence
    { key = "cc_sleep", type = "sleep", mechanicID = 10, label = "Sleep", iconSpellID = 2637 }, -- Hibernate
    { key = "cc_snare", type = "snare", mechanicID = 11, label = "Snare", iconSpellID = 1715 }, -- Hamstring
    { key = "cc_stun", type = "stun", mechanicID = 12, label = "Stun", iconSpellID = 853 }, -- Hammer of Justice
    { key = "cc_freeze", type = "freeze", mechanicID = 13, label = "Freeze", iconSpellID = 122 }, -- Frost Nova
    { key = "cc_knockout", type = "knockout", mechanicID = 14, label = "Knockout (Sap)", iconSpellID = 6770 }, -- Sap
    { key = "cc_polymorph", type = "polymorph", mechanicID = 17, label = "Polymorph", iconSpellID = 118 }, -- Polymorph
    { key = "cc_banish", type = "banish", mechanicID = 18, label = "Banish", iconSpellID = 710 }, -- Banish
    { key = "cc_shackle", type = "shackle", mechanicID = 20, label = "Shackle", iconSpellID = 9484 }, -- Shackle Undead
    { key = "cc_horror", type = "horror", mechanicID = 24, label = "Horror", iconSpellID = 6789 }, -- Death Coil
    { key = "cc_daze", type = "daze", mechanicID = 27, label = "Daze", iconSpellID = 5116 }, -- Concussive Shot
}

local SPELL_COLUMNS = {
    { key = "all", type = "all", label = "All", iconSpellID = 642 }, -- Divine Shield
    { key = "spell", type = "spell", label = "Spell", iconSpellID = 7121 }, -- Anti-Magic Shield
    { key = "physical", type = "physical", label = "Physical", iconSpellID = 1022 }, -- Blessing of Protection
    { key = "holy", type = "holy", label = "Holy", iconSpellID = 879 }, -- Exorcism
    { key = "fire", type = "fire", label = "Fire", iconSpellID = 133 }, -- Fireball
    { key = "nature", type = "nature", label = "Nature", iconSpellID = 403 }, -- Lightning Bolt
    { key = "frost", type = "frost", label = "Frost", iconSpellID = 116 }, -- Frostbolt
    { key = "shadow", type = "shadow", label = "Shadow", iconSpellID = 686 }, -- Shadow Bolt
    { key = "arcane", type = "arcane", label = "Arcane", iconSpellID = 5143 }, -- Arcane Missiles
    { key = "bleed", type = "bleed", label = "Bleed", iconSpellID = 772 }, -- Rend
}

local DIMENSION_ICON_SPELL_IDS = {
    cc = 853,
    charm = 6358,
    disorient = 1776,
    fear = 5782,
    root = 339,
    silence = 15487,
    sleep = 2637,
    snare = 1715,
    stun = 853,
    freeze = 122,
    knockout = 6770,
    polymorph = 118,
    banish = 710,
    shackle = 9484,
    horror = 6789,
    daze = 5116,
    all = 642,
    spell = 7121,
    physical = 1022,
    holy = 879,
    fire = 133,
    nature = 403,
    frost = 116,
    shadow = 686,
    arcane = 5143,
    bleed = 772,
    dispel_magic = 527,
    curse = 475,
    disease = 528,
    poison = 8946,
}

local TYPE_LABELS = {
    cc = "CC",
    charm = "Charm",
    disorient = "Disorient",
    fear = "Fear",
    root = "Root",
    silence = "Silence",
    sleep = "Sleep",
    snare = "Snare",
    stun = "Stun",
    freeze = "Freeze",
    knockout = "Knockout (Sap)",
    polymorph = "Polymorph",
    banish = "Banish",
    shackle = "Shackle",
    horror = "Horror",
    daze = "Daze",
    all = "All",
    spell = "Spell",
    physical = "Physical",
    holy = "Holy",
    fire = "Fire",
    nature = "Nature",
    frost = "Frost",
    shadow = "Shadow",
    arcane = "Arcane",
    bleed = "Bleed",
    dispel_magic = "Dispel Magic",
    curse = "Curse",
    disease = "Disease",
    poison = "Poison",
    unknown = "Unknown",
}

local SPELL_GENERAL_KEYS = {
    all = true,
    spell = true,
    physical = true,
    holy = true,
    fire = true,
    nature = true,
    frost = true,
    shadow = true,
    arcane = true,
    bleed = true,
    unknown = true,
}

local CLASSIFICATION_LABELS = {
    normal = "Normal",
    trivial = "Trivial",
    elite = "Elite",
    rare = "Rare",
    rareelite = "Rare Elite",
    worldboss = "Boss",
}

local function StopTargetModelRotation()
    if targetModel then
        targetModel:SetScript("OnUpdate", nil)
    end
    targetModelRotating = false
end

local function StartTargetModelRotation()
    if not targetModel or targetModelRotating then return end

    targetModelRotating = true
    targetModel:SetScript("OnUpdate", function()
        local elapsed = arg1 or 0
        local speed = (2 * math.pi) / TARGET_MODEL_REVOLUTION_SECONDS
        targetModelRotation = targetModelRotation + (elapsed * speed)
        if targetModelRotation >= (2 * math.pi) then
            targetModelRotation = targetModelRotation - (2 * math.pi)
        end
        targetModel:SetRotation(targetModelRotation)
    end)
end

local function HideTargetModel()
    StopTargetModelRotation()
    if targetModel then
        targetModel:Hide()
    end
end

local function RefreshTargetModel()
    if not targetModel or not mainFrame or not mainFrame:IsShown() or not UnitExists("target") then
        HideTargetModel()
        return
    end

    targetModelRotation = 0
    local ok = pcall(function()
        targetModel:SetUnit("target")
        targetModel:SetRotation(targetModelRotation)
    end)

    if not ok then
        HideTargetModel()
        return
    end

    targetModel:Show()
    StartTargetModelRotation()
end


local function NewWidgetName(prefix)
    widgetCounter = widgetCounter + 1
    return "CleveRoidsImmunity" .. prefix .. tostring(widgetCounter)
end

local function ApplyBackdrop(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.96)
end

local function CreateButton(parent, text, width, height)
    local button = CreateFrame("Button", NewWidgetName("Button"), parent, "UIPanelButtonTemplate")
    button:SetWidth(width or 90)
    button:SetHeight(height or 22)
    button:SetText(text or "")
    return button
end

local function CreateMessageList(parent)
    local list = CreateFrame("ScrollingMessageFrame", NewWidgetName("List"), parent)
    list:SetFont("Fonts\\FRIZQT__.TTF", 10)
    list:SetJustifyH("LEFT")
    list:SetMaxLines(1000)
    list:SetFading(false)
    if list.SetTimeVisible then
        list:SetTimeVisible(999999)
    end
    if list.EnableMouseWheel then
        list:EnableMouseWheel(true)
        list:SetScript("OnMouseWheel", function()
            local delta = arg1 or 0
            if delta > 0 then
                list:ScrollUp()
            elseif delta < 0 then
                list:ScrollDown()
            end
        end)
    end
    return list
end

-- Learning alerts are presentation-only consumers of committed learner transitions.
local LEARNING_SCT_STATE = {
    candidate = { label = "Immunity Detected!", color = { 1.0, 0.82, 0.0 } },
    disproved = { label = "Immunity Resolved!", color = { 0.2, 1.0, 0.3 } },
    confirmed = { label = "Immunity Resolved!", color = { 1.0, 0.2, 0.2 } },
    conditional = { label = "Immunity Resolved!", color = { 1.0, 0.55, 0.0 } },
}
local learningAlertTemplate
local learningAlertDurationSlider
local learningAlertDurationValue
local learningAlertLockButton
local LEARNING_ALERT_ICON = 34
local LEARNING_ALERT_PAIR_GAP = 9

local function GetLearningAlertDuration()
    local value = CleveRoidMacros and tonumber(CleveRoidMacros.learningImmunityAlertDuration)
    if value == nil then
        -- Migrate the old boolean without silently enabling previously disabled alerts.
        value = CleveRoidMacros and CleveRoidMacros.learningImmunitySCT == 1 and 4 or 0
    end
    return math.max(0, math.min(10, math.floor(value + 0.5)))
end

local function IsLearningSCTEnabled()
    return GetLearningAlertDuration() > 0
end

local function GetLearningAlertPosition()
    local settings = CleveRoidMacros or {}
    return tonumber(settings.learningImmunityAlertX) or 0, tonumber(settings.learningImmunityAlertY) or 92
end

local function ClearLearningSCT()
    for i = table.getn(learningSCTEntries), 1, -1 do
        local entry = learningSCTEntries[i]
        if entry.frame then entry.frame:Hide() end
        table.remove(learningSCTEntries, i)
    end
    if learningSCTDriver then learningSCTDriver:Hide() end
end

local function LayoutLearningSCT()
    local x, y = GetLearningAlertPosition()
    for i = 1, table.getn(learningSCTEntries) do
        local row = learningSCTEntries[i].frame
        row:ClearAllPoints()
        row:SetPoint("CENTER", UIParent, "CENTER", x, y + ((i - 1) * (row:GetHeight() + 5)))
    end
end

local function EnsureLearningSCTDriver()
    if learningSCTDriver then return end
    learningSCTDriver = CreateFrame("Frame", "SCRM_DLSI_LearningAlertDriver", UIParent)
    learningSCTDriver:SetScript("OnUpdate", function()
        local elapsed = arg1 or 0
        local duration = GetLearningAlertDuration()
        local removed = false
        for i = table.getn(learningSCTEntries), 1, -1 do
            local entry = learningSCTEntries[i]
            entry.elapsed = entry.elapsed + elapsed
            if duration == 0 or entry.elapsed >= duration then
                entry.frame:Hide()
                table.remove(learningSCTEntries, i)
                removed = true
            else
                local fadeStart = duration * (2.7 / 3.5)
                local alpha = 1
                if entry.elapsed > fadeStart then
                    alpha = (duration - entry.elapsed) / (duration - fadeStart)
                end
                entry.frame:SetAlpha(alpha)
            end
        end
        if removed then LayoutLearningSCT() end
        if table.getn(learningSCTEntries) == 0 then learningSCTDriver:Hide() end
    end)
    learningSCTDriver:Hide()
end

local function CreateLearningSCTIcon(parent, spellID, dimension, state)
    local holder = CreateFrame("Frame", NewWidgetName("AlertIcon"), parent)
    holder:SetWidth(LEARNING_ALERT_ICON)
    holder:SetHeight(LEARNING_ALERT_ICON)
    holder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
    local c = state.color
    holder:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 2)
    local textureID = dimension and DIMENSION_ICON_SPELL_IDS[dimension] or spellID
    local texture = textureID and C_Spell.GetSpellTexture(textureID)
    icon:SetTexture(texture or CleveRoids.unknownTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    return holder
end

local function CreateAlertSurface()
    local row = CreateFrame("Frame", NewWidgetName("AlertRow"), UIParent)
    row:SetHeight(46)
    row:SetFrameStrata("DIALOG")
    row:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 8, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    row:SetBackdropColor(0, 0, 0, 0.72)
    return row
end

local function ShowLearningTransition(transition)
    if not IsLearningSCTEnabled() or type(transition) ~= "table" then return end
    local state = LEARNING_SCT_STATE[transition.state]
    local dimensions = transition.dimensions or {}
    if not state or table.getn(dimensions) == 0 then return end
    EnsureLearningSCTDriver()

    local row = CreateAlertSurface()
    row:SetBackdropBorderColor(state.color[1], state.color[2], state.color[3], 1)
    local title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -7)
    title:SetText(state.label)
    title:SetTextColor(state.color[1], state.color[2], state.color[3])
    local mob = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mob:SetPoint("TOPLEFT", row, "TOPLEFT", 7, -26)
    mob:SetText(transition.targetName and transition.targetName ~= "" and transition.targetName or "Unknown target")

    local textWidth = math.max(title:GetStringWidth(), mob:GetStringWidth()) + 16
    local x = textWidth + 3
    local maxWidth = math.min(750, UIParent:GetWidth() - 60)
    local y = -6
    local pairWidth = LEARNING_ALERT_ICON * 2 + 2
    -- Each evidence unit is placed atomically: never split spell and dimension.
    for i = 1, table.getn(dimensions) do
        if x + pairWidth + 7 > maxWidth and x > textWidth + 3 then
            x = textWidth + 3
            y = y - (LEARNING_ALERT_ICON + 5)
        end
        local dimension = dimensions[i]
        -- A confirmation may originate in an earlier ambiguous observation.
        -- Use its persisted provenance spell where provided, never invent history.
        local spellID = transition.state == "confirmed"
            and (transition.proofSpellID or transition.spellID) or transition.spellID
        if transition.state == "candidate" then
            -- The trigger icon is shown once, followed by candidate dimensions.
            if i == 1 then
                local spell = CreateLearningSCTIcon(row, spellID, nil, state)
                spell:SetPoint("TOPLEFT", row, "TOPLEFT", x, y)
                x = x + LEARNING_ALERT_ICON + LEARNING_ALERT_PAIR_GAP
            end
            local dim = CreateLearningSCTIcon(row, nil, dimension, state)
            dim:SetPoint("TOPLEFT", row, "TOPLEFT", x, y)
            x = x + LEARNING_ALERT_ICON + 3
        else
            local spell = CreateLearningSCTIcon(row, spellID, nil, state)
            spell:SetPoint("TOPLEFT", row, "TOPLEFT", x, y)
            local dim = CreateLearningSCTIcon(row, nil, dimension, state)
            dim:SetPoint("LEFT", spell, "RIGHT", 2, 0)
            x = x + pairWidth + LEARNING_ALERT_PAIR_GAP
        end
    end
    row:SetWidth(math.max(textWidth + 8, x + 4))
    row:SetHeight(math.max(46, -y + LEARNING_ALERT_ICON + 6))
    table.insert(learningSCTEntries, { frame = row, elapsed = 0 })
    LayoutLearningSCT()
    row:Show()
    learningSCTDriver:Show()
end

local function EnsureLearningAlertTemplate()
    if learningAlertTemplate then return end
    local frame = CreateAlertSurface()
    frame:SetWidth(270)
    frame:SetHeight(46)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local x, y = frame:GetCenter()
        local px, py = UIParent:GetCenter()
        CleveRoidMacros = CleveRoidMacros or {}
        CleveRoidMacros.learningImmunityAlertX = x - px
        CleveRoidMacros.learningImmunityAlertY = y - py
        LayoutLearningSCT()
    end)
    local heading = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    heading:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -7)
    heading:SetText("Immunity Detected!")
    local name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -26)
    name:SetText("Mob Name (drag to position)")
    learningAlertTemplate = frame
    frame:Hide()
end

local function SetLearningAlertUnlocked(unlocked)
    CleveRoidMacros = CleveRoidMacros or {}
    EnsureLearningAlertTemplate()
    if unlocked then
        local x, y = GetLearningAlertPosition()
        learningAlertTemplate:ClearAllPoints()
        learningAlertTemplate:SetPoint("CENTER", UIParent, "CENTER", x, y)
        learningAlertTemplate:Show()
    else
        if learningAlertTemplate:IsShown() then
            local x, y = learningAlertTemplate:GetCenter()
            local px, py = UIParent:GetCenter()
            CleveRoidMacros.learningImmunityAlertX = x - px
            CleveRoidMacros.learningImmunityAlertY = y - py
            LayoutLearningSCT()
        end
        learningAlertTemplate:Hide()
    end
    if learningAlertLockButton then
        learningAlertLockButton:SetText(unlocked and "Lock" or "Unlock")
    end
end

local function SetLearningAlertDuration(value)
    value = math.max(0, math.min(10, math.floor((tonumber(value) or 0) + 0.5)))
    CleveRoidMacros = CleveRoidMacros or {}
    CleveRoidMacros.learningImmunityAlertDuration = value
    if value == 0 then ClearLearningSCT() end
    if learningAlertDurationValue then
        learningAlertDurationValue:SetText(tostring(value) .. "s")
    end
end

local function ClearMessageList(list)
    if list and list.Clear then
        list:Clear()
    end
end

local function TableCount(t)
    local count = 0
    if type(t) ~= "table" then return 0 end
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

local function CountAllRecords(data)
    local count = 0
    if type(data) ~= "table" then return 0 end
    for _, bucket in pairs(data) do
        if type(bucket) == "table" then
            count = count + TableCount(bucket)
        end
    end
    return count
end

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[DeepCopy(key)] = DeepCopy(child)
    end
    return copy
end

local function FormatStoredLine(npcName, data)
    if data == true then
        return npcName
    end
    if type(data) == "table" then
        local suffix = ""
        if data.spell then
            suffix = suffix .. " [" .. tostring(data.spell) .. "]"
        end
        if data.buff then
            suffix = suffix .. " [buff: " .. tostring(data.buff) .. "]"
        end
        if suffix == "" then
            suffix = " [legacy]"
        end
        return npcName .. suffix
    end
    return npcName .. " [" .. tostring(data) .. "]"
end

local function SortedBucketLines(bucket)
    local names = {}
    local lines = {}
    if type(bucket) ~= "table" then
        return lines
    end
    for npcName in pairs(bucket) do
        table.insert(names, npcName)
    end
    table.sort(names)
    for _, npcName in ipairs(names) do
        table.insert(lines, FormatStoredLine(npcName, bucket[npcName]))
    end
    return lines
end

local function AddLines(list, lines)
    ClearMessageList(list)
    if table.getn(lines) == 0 then
        list:AddMessage("|cff777777(none)|r")
        return
    end
    for _, line in ipairs(lines) do
        list:AddMessage(line)
    end
end

local function StorageKeyForDimension(dimension)
    for _, column in ipairs(CC_COLUMNS) do
        if column.type == dimension then
            return column.key
        end
    end
    for _, column in ipairs(SPELL_COLUMNS) do
        if column.type == dimension then
            return column.key
        end
    end
    return nil
end

-- Build the existing UI columns from the same production inputs used by macro
-- queries: confirmed HearthDB facts plus explicit manual/static overrides.
local function BuildProductionDisplayData()
    local data = {}

    local function addLine(key, line)
        if not key or not line then return end
        data[key] = data[key] or {}
        table.insert(data[key], line)
    end

    local knowledge = CleveRoids.ImmunityKnowledge
    if knowledge and knowledge.GetConfirmedImmunities then
        local facts = knowledge.GetConfirmedImmunities()
        for _, fact in ipairs(facts) do
            local key = StorageKeyForDimension(fact.dimension)
            if key then
                local label = fact.name
                if not label or label == "" then
                    label = "Mob " .. tostring(fact.mobID or "?")
                end
                if fact.mobID then
                    label = label .. " [Mob ID " .. tostring(fact.mobID) .. "]"
                end
                addLine(key, label)
            end
        end
    end

    -- Data-version 7 guarantees these name-keyed entries are user-created
    -- manual/static overrides, not learned facts.
    local staticData = CleveRoids_ImmunityData or {}
    local function addStaticColumns(columns)
        for _, column in ipairs(columns) do
            local lines = SortedBucketLines(staticData[column.key])
            for _, line in ipairs(lines) do
                addLine(column.key, line .. " [manual]")
            end
        end
    end
    addStaticColumns(CC_COLUMNS)
    addStaticColumns(SPELL_COLUMNS)

    for _, lines in pairs(data) do
        table.sort(lines)
    end
    return data
end

local function ColumnHeader(column, count)
    if column.mechanicID then
        return tostring(column.mechanicID) .. " " .. column.label .. " (" .. tostring(count) .. ")"
    end
    return column.label .. " (" .. tostring(count) .. ")"
end

local function CreateHorizontalSlider(parent)
    local slider = CreateFrame("Slider", NewWidgetName("HSlider"), parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(12)
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:SetMinMaxValues(0, 1)
    slider:SetValue(0)
    if slider.SetValueStep then
        slider:SetValueStep(12)
    end

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOPLEFT", slider, "TOPLEFT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", slider, "BOTTOMRIGHT", 0, 0)
    track:SetTexture("Interface\\Buttons\\WHITE8x8")
    track:SetVertexColor(0.18, 0.18, 0.18, 0.9)

    return slider
end

local function SetHorizontalSectionOffset(section, offset)
    offset = offset or 0
    if offset < 0 then offset = 0 end
    if offset > (section.maxScroll or 0) then
        offset = section.maxScroll or 0
    end

    section.offset = offset
    section.viewport:SetHorizontalScroll(0)
    section.child:ClearAllPoints()
    section.child:SetPoint("TOPLEFT", section.viewport, "TOPLEFT", -offset, 0)
end

local function CreateDataColumn(parent, column, height)
    local frame = CreateFrame("Frame", NewWidgetName("Column"), parent)
    frame:SetWidth(COLUMN_WIDTH)
    frame:SetHeight(height)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(HEADER_ICON_SIZE)
    icon:SetHeight(HEADER_ICON_SIZE)
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -3)
    icon:SetTexture(
        (column.iconSpellID and C_Spell.GetSpellTexture(column.iconSpellID)) or
        CleveRoids.unknownTexture or
        "Interface\\Icons\\INV_Misc_QuestionMark"
    )
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", icon, "TOPRIGHT", 4, 1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    header:SetHeight(30)
    header:SetJustifyH("LEFT")
    header:SetJustifyV("TOP")
    header:SetText(column.label)

    local list = CreateMessageList(frame)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -34)
    list:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 22)

    local up = CreateButton(frame, "^", 22, 18)
    up:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -27, 1)
    up:SetScript("OnClick", function()
        list:ScrollUp()
    end)

    local down = CreateButton(frame, "v", 22, 18)
    down:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -3, 1)
    down:SetScript("OnClick", function()
        list:ScrollDown()
    end)

    column.frame = frame
    column.header = header
    column.list = list
end

local function CreateHorizontalSection(parent, topOffset, height, columns, namePrefix)
    local section = {}

    section.viewport = CreateFrame("ScrollFrame", NewWidgetName(namePrefix .. "Scroll"), parent)
    section.viewport:SetPoint("TOPLEFT", parent, "TOPLEFT", 20, topOffset)
    section.viewport:SetWidth(SECTION_WIDTH)
    section.viewport:SetHeight(height)

    section.child = CreateFrame("Frame", NewWidgetName(namePrefix .. "Child"), section.viewport)
    section.child:SetHeight(height)
    section.child:SetWidth(SECTION_WIDTH)
    section.child:SetPoint("TOPLEFT", section.viewport, "TOPLEFT", 0, 0)
    section.viewport:SetScrollChild(section.child)

    for _, column in ipairs(columns) do
        CreateDataColumn(section.child, column, height - 18)
    end

    section.slider = CreateHorizontalSlider(parent)
    section.slider:SetPoint("TOPLEFT", section.viewport, "BOTTOMLEFT", 0, -2)
    section.slider:SetWidth(SECTION_WIDTH)
    section.columns = columns
    section.maxScroll = 0
    section.offset = 0
    section.slider:SetScript("OnValueChanged", function()
        SetHorizontalSectionOffset(section, arg1 or 0)
    end)
    return section
end

local function RefreshHorizontalSection(section, data)
    local x = 0
    local visibleCount = 0
    data = data or {}

    for _, column in ipairs(section.columns) do
        local lines = data[column.key] or {}
        local count = table.getn(lines)
        local visible = true
        if column.broad and count == 0 then
            visible = false
        end

        if visible then
            column.frame:ClearAllPoints()
            column.frame:SetPoint("TOPLEFT", section.child, "TOPLEFT", x, 0)
            column.frame:Show()
            column.header:SetText(ColumnHeader(column, count))
            AddLines(column.list, lines)
            x = x + COLUMN_WIDTH + COLUMN_GAP
            visibleCount = visibleCount + 1
        else
            column.frame:Hide()
        end
    end

    local previousOffset = section.offset or 0

    local contentWidth = x
    if contentWidth < SECTION_WIDTH then
        contentWidth = SECTION_WIDTH
    end
    section.child:SetWidth(contentWidth)

    local maxScroll = contentWidth - SECTION_WIDTH
    if maxScroll < 0 then maxScroll = 0 end
    section.maxScroll = maxScroll

    if maxScroll == 0 then
        section.slider:Hide()
        section.slider:SetValue(0)
        SetHorizontalSectionOffset(section, 0)
    else
        section.slider:Show()
        section.slider:SetMinMaxValues(0, maxScroll)

        if previousOffset > maxScroll then
            previousOffset = maxScroll
        end

        -- Leftmost columns are the initial state. Moving the thumb right increases
        -- the offset and physically moves the column strip left, revealing the
        -- additional columns on the right.
        section.slider:SetValue(previousOffset)
        SetHorizontalSectionOffset(section, previousOffset)
    end
end

local function RefreshLegacyUnknown()
    local bucket = CleveRoids_ImmunityData and CleveRoids_ImmunityData.unknown
    local count = TableCount(bucket)
    legacyTitle:SetText("Manual/static unknown (" .. tostring(count) .. ")")
    AddLines(legacyList, SortedBucketLines(bucket))
end

local function ImmunityLabel(entry)
    local label = TYPE_LABELS[entry.immunityType] or tostring(entry.immunityType or "Unknown")
    if entry.mechanicID then
        return tostring(entry.mechanicID) .. " " .. label
    end
    return label
end

local function FormatRecordedTargetEntry(entry)
    local text = ImmunityLabel(entry)
    if entry.buff then
        text = text .. " [buff: " .. tostring(entry.buff) .. "]"
        if entry.active == false then
            text = text .. " (inactive)"
        end
    end
    if entry.spell then
        text = text .. " [" .. tostring(entry.spell) .. "]"
    end
    return text
end

local function FormatLiveDetail(detail)
    if detail == nil then return nil end
    if type(detail) == "number" then
        local spellName = C_Spell.GetSpellName(detail)
        if spellName then
            return spellName .. " " .. tostring(detail)
        end
        return "SpellID:" .. tostring(detail)
    end
    return tostring(detail)
end

local function AddLiveTargetEntries(list, heading, entries)
    if table.getn(entries) == 0 then return end
    list:AddMessage("|cffffcc00" .. heading .. "|r")
    for _, entry in ipairs(entries) do
        local text = ImmunityLabel(entry)
        local detail = FormatLiveDetail(entry.detail)
        if detail then
            text = text .. " - " .. detail
        end
        if entry.source then
            text = text .. " [" .. tostring(entry.source) .. "]"
        end
        list:AddMessage(text)
    end
end

local function FormatLearnerProvenance(source, spellID, proofEvent)
    local parts = {}
    if source and source ~= "" then
        table.insert(parts, "source=" .. tostring(source))
    end
    if spellID then
        local spellName = C_Spell.GetSpellName(spellID)
        if spellName then
            table.insert(parts, "spell=" .. spellName .. " (" .. tostring(spellID) .. ")")
        else
            table.insert(parts, "spellID=" .. tostring(spellID))
        end
    end
    if proofEvent and proofEvent ~= "" then
        table.insert(parts, "event=" .. tostring(proofEvent))
    end
    if table.getn(parts) == 0 then return "provenance unavailable" end
    return table.concat(parts, "; ")
end

local function AddLearnerDiagnostics(list, mobID)
    local knowledge = CleveRoids.ImmunityKnowledge
    if not mobID or not knowledge then return false end

    local facts = knowledge.GetFacts and knowledge.GetFacts(mobID) or {}
    local hypotheses = knowledge.GetHypotheses and knowledge.GetHypotheses(mobID) or {}
    if table.getn(facts) == 0 and table.getn(hypotheses) == 0 then
        return false
    end

    list:AddMessage("|cff66ccffLEARNER STATE [Mob ID " .. tostring(mobID) .. "]|r")

    local i
    for i = 1, table.getn(facts) do
        local fact = facts[i]
        local label = TYPE_LABELS[fact.dimension] or tostring(fact.dimension or "Unknown")
        local color
        local stateText
        if fact.dynamicSuspected then
            color = "ffff8c00"
            stateText = "vulnerable; temporary/conditional immunity suspected"
        elseif fact.verdict == "immune" then
            color = "ffff3333"
            stateText = "confirmed permanent immunity"
        else
            color = "ff33ff55"
            stateText = tostring(fact.verdict or "unknown")
        end
        list:AddMessage("|c" .. color .. label .. ": " .. stateText .. "|r")
        list:AddMessage(
            "|cff999999  " ..
            FormatLearnerProvenance(fact.proofSource, fact.proofSpellID, fact.proofEvent) ..
            "|r"
        )
    end

    if table.getn(hypotheses) > 0 then
        list:AddMessage("|cffffcc00UNRESOLVED HYPOTHESES|r")
        for i = 1, table.getn(hypotheses) do
            local hypothesis = hypotheses[i]
            local candidates = {}
            local j
            for j = 1, table.getn(hypothesis.candidates or {}) do
                local dimension = hypothesis.candidates[j]
                table.insert(candidates, TYPE_LABELS[dimension] or tostring(dimension))
            end
            list:AddMessage(
                "|cffffcc00#" .. tostring(hypothesis.hypothesisID or "?") ..
                " candidates: " .. table.concat(candidates, ", ") .. "|r"
            )
            list:AddMessage(
                "|cff999999  " ..
                FormatLearnerProvenance(
                    hypothesis.proofSource,
                    hypothesis.proofSpellID,
                    hypothesis.proofEvent
                ) ..
                "|r"
            )
        end
    end

    return true
end

local function RefreshTargetPanel()
    if not targetNameText then return end

    ClearMessageList(targetCCList)
    ClearMessageList(targetSpellList)
    ClearMessageList(targetLiveList)

    if not CleveRoids.GetImmunityDebugSnapshot then
        targetNameText:SetText("Framework debug state unavailable")
        if targetInfoText then targetInfoText:SetText("") end
        HideTargetModel()
        return
    end

    local snapshot = CleveRoids.GetImmunityDebugSnapshot("target")
    if not snapshot or not snapshot.exists then
        targetNameText:SetText("No current target")
        if targetInfoText then targetInfoText:SetText("") end
        HideTargetModel()
        targetCCList:AddMessage("|cff777777(none)|r")
        targetSpellList:AddMessage("|cff777777(none)|r")
        targetLiveList:AddMessage("|cff777777No live immunity state|r")
        return
    end

    targetNameText:SetText(snapshot.name or "Unknown")

    local creatureID = snapshot.creatureEntry and tostring(snapshot.creatureEntry) or "-"
    local level = UnitLevel("target")
    local levelText = level and level > 0 and tostring(level) or "??"
    local creatureType = UnitCreatureType("target") or "Unknown"
    local classification = UnitClassification("target")
    local classificationText = CLASSIFICATION_LABELS[classification] or tostring(classification or "Unknown")

    if targetInfoText then
        targetInfoText:SetText(
            "Mob ID: " .. creatureID ..
            "\nLevel: " .. levelText ..
            "\nType: " .. creatureType ..
            "\nClass: " .. classificationText
        )
    end

    RefreshTargetModel()

    if table.getn(snapshot.recordedCC) == 0 then
        targetCCList:AddMessage("|cff777777(none)|r")
    else
        for _, entry in ipairs(snapshot.recordedCC) do
            targetCCList:AddMessage(FormatRecordedTargetEntry(entry))
        end
    end

    if table.getn(snapshot.recordedSpell) == 0 then
        targetSpellList:AddMessage("|cff777777(none)|r")
    else
        for _, entry in ipairs(snapshot.recordedSpell) do
            targetSpellList:AddMessage(FormatRecordedTargetEntry(entry))
        end
    end

    AddLearnerDiagnostics(targetLiveList, snapshot.creatureEntry)
    AddLiveTargetEntries(targetLiveList, "LIVE CC", snapshot.liveCC)
    AddLiveTargetEntries(targetLiveList, "LIVE SPELL", snapshot.liveSpell)

    if table.getn(snapshot.explanations) > 0 then
        targetLiveList:AddMessage("|cff66ccffEXPLANATION (not immunity)|r")
        for _, entry in ipairs(snapshot.explanations) do
            local detail = FormatLiveDetail(entry.detail)
            local text = "Reflection"
            if detail then
                text = text .. " - " .. detail
            end
            text = text .. " [reflection]"
            targetLiveList:AddMessage(text)
        end
    end

    if table.getn(snapshot.legacy) > 0 then
        targetLiveList:AddMessage("|cffaaaaaaLEGACY UNKNOWN|r")
        for _, entry in ipairs(snapshot.legacy) do
            targetLiveList:AddMessage(FormatRecordedTargetEntry(entry))
        end
    end

    if table.getn(snapshot.liveCC) == 0 and
       table.getn(snapshot.liveSpell) == 0 and
       table.getn(snapshot.explanations) == 0 and
       table.getn(snapshot.legacy) == 0 then
        targetLiveList:AddMessage("|cff777777No live immunity/explanation state|r")
    end
end

local function RefreshAll()
    if not mainFrame then return end
    local productionData = BuildProductionDisplayData()
    RefreshHorizontalSection(ccSection, productionData)
    RefreshHorizontalSection(spellSection, productionData)
    RefreshLegacyUnknown()
    RefreshTargetPanel()
end

-- Host-owned manual/static immunity records and backups are strictly read-only.
-- DLSI does not administer SCRM's legacy SavedVariables.
local function EnsureBackupTable()
    if CleveRoidMacros and type(CleveRoidMacros.immunityBackups) == "table" then
        return CleveRoidMacros.immunityBackups
    end
    return {}
end

local function LegacyManagementUnavailable()
    CleveRoids.Print("Manual immunity storage and backups remain owned by SCRM; DLSI does not modify them.")
end

local function BackupCurrent(reason)
    LegacyManagementUnavailable()
end

local function NotifyDataChanged()
    if CleveRoids.RefreshImmunityUI then CleveRoids.RefreshImmunityUI() end
end

local function ClearCCStorage(key)
    LegacyManagementUnavailable()
end

local function ClearSpellStorage(key)
    LegacyManagementUnavailable()
end

local function ClearAllStorage()
    LegacyManagementUnavailable()
end

local function BuildClearOptions(mode)
    local options = {}

    if mode == "cc" then
        table.insert(options, { key = "*", label = "All manual CC overrides" })
        if TableCount(CleveRoids_ImmunityData and CleveRoids_ImmunityData.cc) > 0 then
            table.insert(options, { key = "cc", label = "Broad CC" })
        end
        for _, column in ipairs(CC_COLUMNS) do
            if not column.broad then
                table.insert(options, {
                    key = column.key,
                    label = (column.mechanicID and (tostring(column.mechanicID) .. " ") or "") .. column.label,
                })
            end
        end
    elseif mode == "spell" then
        table.insert(options, { key = "*", label = "All manual spell/school overrides" })
        for _, column in ipairs(SPELL_COLUMNS) do
            table.insert(options, { key = column.key, label = column.label })
        end
        if TableCount(CleveRoids_ImmunityData and CleveRoids_ImmunityData.unknown) > 0 then
            table.insert(options, { key = "unknown", label = "Manual/static unknown" })
        end
    else
        table.insert(options, { key = "*", label = "ALL manual/static overrides" })
    end

    return options
end

local function CreateClearDialog(parent)
    local frame = CreateFrame("Frame", "SCRM_DLSI_ClearDialog", parent)
    frame:SetWidth(430)
    frame:SetHeight(180)
    frame:SetPoint("CENTER", parent, "CENTER", 0, 20)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(parent:GetFrameLevel() + MODAL_FRAME_LEVEL_OFFSET)
    ApplyBackdrop(frame)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetText("Clear Immunity Data")
    frame.title = title

    local selected = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    selected:SetPoint("TOP", title, "BOTTOM", 0, -28)
    selected:SetWidth(280)
    selected:SetHeight(32)
    selected:SetJustifyH("CENTER")
    frame.selected = selected

    local prev = CreateButton(frame, "<", 35, 22)
    prev:SetPoint("RIGHT", selected, "LEFT", -8, 0)
    prev:SetScript("OnClick", function()
        if not frame.options then return end
        frame.index = frame.index - 1
        if frame.index < 1 then frame.index = table.getn(frame.options) end
        frame.Refresh()
    end)

    local nextButton = CreateButton(frame, ">", 35, 22)
    nextButton:SetPoint("LEFT", selected, "RIGHT", 8, 0)
    nextButton:SetScript("OnClick", function()
        if not frame.options then return end
        frame.index = frame.index + 1
        if frame.index > table.getn(frame.options) then frame.index = 1 end
        frame.Refresh()
    end)

    local backup = CreateButton(frame, "Backup", 90, 24)
    backup:SetPoint("BOTTOM", frame, "BOTTOM", -105, 20)
    backup:SetScript("OnClick", function()
        BackupCurrent("Manual backup from clear dialog")
    end)

    local clear = CreateButton(frame, "Clear", 90, 24)
    clear:SetPoint("LEFT", backup, "RIGHT", 8, 0)
    clear:SetScript("OnClick", function()
        local option = frame.options and frame.options[frame.index]
        if not option then return end

        if frame.mode == "cc" then
            ClearCCStorage(option.key)
        elseif frame.mode == "spell" then
            ClearSpellStorage(option.key)
        else
            ClearAllStorage()
        end
        frame:Hide()
    end)

    local cancel = CreateButton(frame, "Cancel", 90, 24)
    cancel:SetPoint("LEFT", clear, "RIGHT", 8, 0)
    cancel:SetScript("OnClick", function()
        frame:Hide()
    end)

    function frame.Refresh()
        local option = frame.options and frame.options[frame.index]
        if option then
            frame.selected:SetText(option.label)
        else
            frame.selected:SetText("(none)")
        end
    end

    return frame
end

local function ShowClearDialog(mode)
    clearDialog.mode = mode
    clearDialog.options = BuildClearOptions(mode)
    clearDialog.index = 1
    if mode == "cc" then
        clearDialog.title:SetText("Clear CC Immunity Data")
    elseif mode == "spell" then
        clearDialog.title:SetText("Clear Spell Immunity Data")
    else
        clearDialog.title:SetText("Clear ALL Learned Immunity Data")
    end
    clearDialog.Refresh()
    clearDialog:Show()
end

local function CreateHistoryDialog(parent)
    local frame = CreateFrame("Frame", "SCRM_DLSI_BackupHistory", parent)
    frame:SetWidth(500)
    frame:SetHeight(250)
    frame:SetPoint("CENTER", parent, "CENTER", 0, 15)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(parent:GetFrameLevel() + MODAL_FRAME_LEVEL_OFFSET)
    ApplyBackdrop(frame)
    frame:Hide()
    frame.index = 1

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -18)
    title:SetText("Immunity Backup History")

    local countText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("TOP", title, "BOTTOM", 0, -12)
    frame.countText = countText

    local selected = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    selected:SetPoint("TOP", countText, "BOTTOM", 0, -16)
    selected:SetWidth(360)
    selected:SetHeight(52)
    selected:SetJustifyH("CENTER")
    selected:SetJustifyV("TOP")
    frame.selected = selected

    local prev = CreateButton(frame, "< Prev", 70, 22)
    prev:SetPoint("TOPRIGHT", selected, "TOPLEFT", -6, 0)
    prev:SetScript("OnClick", function()
        local backups = EnsureBackupTable()
        if table.getn(backups) == 0 then return end
        frame.index = frame.index - 1
        if frame.index < 1 then frame.index = table.getn(backups) end
        frame.Refresh()
    end)

    local nextButton = CreateButton(frame, "Next >", 70, 22)
    nextButton:SetPoint("TOPLEFT", selected, "TOPRIGHT", 6, 0)
    nextButton:SetScript("OnClick", function()
        local backups = EnsureBackupTable()
        if table.getn(backups) == 0 then return end
        frame.index = frame.index + 1
        if frame.index > table.getn(backups) then frame.index = 1 end
        frame.Refresh()
    end)

    local backup = CreateButton(frame, "Backup Current", 110, 24)
    backup:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 24)
    backup:SetScript("OnClick", function()
        BackupCurrent("Manual backup from history")
    end)

    local restore = CreateButton(frame, "Restore", 90, 24)
    restore:SetPoint("LEFT", backup, "RIGHT", 8, 0)
    restore:SetScript("OnClick", function()
        local backups = EnsureBackupTable()
        local selectedBackup = backups[frame.index]
        if not selectedBackup then return end
        LegacyManagementUnavailable()
    end)

    local deleteButton = CreateButton(frame, "Delete", 90, 24)
    deleteButton:SetPoint("LEFT", restore, "RIGHT", 8, 0)
    deleteButton:SetScript("OnClick", function()
        local backups = EnsureBackupTable()
        local selectedBackup = backups[frame.index]
        if not selectedBackup then return end
        local label = selectedBackup.label or tostring(frame.index)
        LegacyManagementUnavailable()
    end)

    local close = CreateButton(frame, "Close", 90, 24)
    close:SetPoint("LEFT", deleteButton, "RIGHT", 8, 0)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    function frame.Refresh()
        local backups = EnsureBackupTable()
        local count = table.getn(backups)
        frame.countText:SetText(tostring(count) .. " saved backup" .. (count == 1 and "" or "s"))

        if count == 0 then
            frame.selected:SetText("No manual backups yet.")
            return
        end

        if frame.index > count then frame.index = count end
        if frame.index < 1 then frame.index = 1 end

        local selectedBackup = backups[frame.index]
        local label = selectedBackup.label or ("Backup " .. tostring(frame.index))
        local reason = selectedBackup.reason and ("\n" .. tostring(selectedBackup.reason)) or ""
        local recordCount = CountAllRecords(selectedBackup.data)
        frame.selected:SetText(
            tostring(frame.index) .. "/" .. tostring(count) .. "  " .. label ..
            "\nData v" .. tostring(selectedBackup.immunityDataVersion or "?") ..
            " - " .. tostring(recordCount) .. " records" .. reason
        )
    end

    frame:SetScript("OnShow", function()
        local backups = EnsureBackupTable()
        local count = table.getn(backups)
        frame.index = count > 0 and count or 1
        frame.Refresh()
    end)

    return frame
end

local function CreateTargetPanel(parent)
    local frame = CreateFrame("Frame", "SCRM_DLSI_TargetPanel", parent)
    frame:SetWidth(TARGET_WIDTH)
    frame:SetHeight(MAIN_HEIGHT)
    frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 4, 0)
    ApplyBackdrop(frame)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("Current Target")

    targetModel = CreateFrame("PlayerModel", "SCRM_DLSI_ImmunityTargetModel", frame)
    targetModel:SetWidth(TARGET_MODEL_WIDTH)
    targetModel:SetHeight(TARGET_MODEL_HEIGHT)
    targetModel:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -46)
    targetModel:SetFrameLevel(frame:GetFrameLevel() + 1)
    ApplyBackdrop(targetModel)
    targetModel:Hide()

    targetNameText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    targetNameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 148, -48)
    targetNameText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -48)
    targetNameText:SetHeight(34)
    targetNameText:SetJustifyH("LEFT")
    targetNameText:SetJustifyV("TOP")
    targetNameText:SetText("No current target")

    targetInfoText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    targetInfoText:SetPoint("TOPLEFT", frame, "TOPLEFT", 148, -84)
    targetInfoText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -18, -84)
    targetInfoText:SetHeight(82)
    targetInfoText:SetJustifyH("LEFT")
    targetInfoText:SetJustifyV("TOP")
    targetInfoText:SetText("")

    local ccHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ccHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -190)
    ccHeader:SetText("Recorded CC")

    local spellHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 155, -190)
    spellHeader:SetText("Recorded Spell")

    targetCCList = CreateMessageList(frame)
    targetCCList:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -210)
    targetCCList:SetWidth(126)
    targetCCList:SetHeight(148)

    targetSpellList = CreateMessageList(frame)
    targetSpellList:SetPoint("TOPLEFT", frame, "TOPLEFT", 155, -210)
    targetSpellList:SetWidth(126)
    targetSpellList:SetHeight(148)

    local liveHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    liveHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -378)
    liveHeader:SetText("Live / current-state / explanations")

    targetLiveList = CreateMessageList(frame)
    targetLiveList:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -401)
    targetLiveList:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 28)

    targetFrame = frame
    return frame
end

local function CreateMainFrame()
    local frame = CreateFrame("Frame", "SCRM_DLSI_ManagementFrame", UIParent)
    frame:SetWidth(MAIN_WIDTH)
    frame:SetHeight(MAIN_HEIGHT)
    -- Center the combined main + attached target footprint. At 1024-wide UI scale
    -- this leaves a small margin on both sides instead of clipping the target border.
    frame:SetPoint("CENTER", UIParent, "CENTER", -152, 0)
    frame:SetFrameStrata("DIALOG")
    ApplyBackdrop(frame)
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(true)
    end

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -14)
    title:SetText("SCRM Immunities")

    local close = CreateFrame("Button", NewWidgetName("Close"), frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)

    -- Keep controls below the centered title, clear of the window chrome.
    local alertLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    alertLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -39)
    alertLabel:SetText("Immunity Learning Alerts")
    local durationLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    durationLabel:SetPoint("LEFT", alertLabel, "RIGHT", 12, 0)
    durationLabel:SetText("Duration")

    local offLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    offLabel:SetPoint("LEFT", durationLabel, "RIGHT", 10, 0)
    offLabel:SetText("Off")
    learningAlertDurationSlider = CreateFrame("Slider", NewWidgetName("AlertDuration"), frame, "OptionsSliderTemplate")
    learningAlertDurationSlider:SetWidth(108)
    learningAlertDurationSlider:SetHeight(16)
    learningAlertDurationSlider:SetPoint("LEFT", offLabel, "RIGHT", 8, 0)
    learningAlertDurationSlider:SetMinMaxValues(0, 10)
    learningAlertDurationSlider:SetValueStep(1)
    -- The template places Low/High below the bar; use inline end labels instead.
    local sliderName = learningAlertDurationSlider:GetName()
    local low = _G[sliderName .. "Low"]
    local high = _G[sliderName .. "High"]
    local caption = _G[sliderName .. "Text"]
    if low then low:SetText("") end
    if high then high:SetText("") end
    if caption then caption:SetText("") end
    local maxLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    maxLabel:SetPoint("LEFT", learningAlertDurationSlider, "RIGHT", 8, 0)
    maxLabel:SetText("10 sec")
    learningAlertDurationSlider:SetValue(GetLearningAlertDuration())
    learningAlertDurationSlider:SetScript("OnValueChanged", function()
        SetLearningAlertDuration(learningAlertDurationSlider:GetValue())
    end)
    learningAlertLockButton = CreateFrame("Button", NewWidgetName("AlertLock"), frame, "UIPanelButtonTemplate")
    learningAlertLockButton:SetWidth(64)
    learningAlertLockButton:SetHeight(22)
    learningAlertLockButton:SetPoint("LEFT", maxLabel, "RIGHT", 12, 0)
    learningAlertLockButton:SetText("Unlock")
    learningAlertLockButton:SetScript("OnClick", function()
        SetLearningAlertUnlocked(not (learningAlertTemplate and learningAlertTemplate:IsShown()))
    end)

    local ccTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ccTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -70)
    ccTitle:SetText("CC Immunities")

    ccSection = CreateHorizontalSection(frame, -92, 214, CC_COLUMNS, "CC")

    local spellTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -344)
    spellTitle:SetText("Spell Immunities")

    spellSection = CreateHorizontalSection(frame, -366, 190, SPELL_COLUMNS, "Spell")

    legacyTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legacyTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -596)
    legacyTitle:SetText("Manual/static unknown (0)")

    legacyList = CreateMessageList(frame)
    legacyList:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -615)
    legacyList:SetWidth(670)
    legacyList:SetHeight(38)

    local backupCC = CreateButton(frame, "Backup", 70, 22)
    backupCC:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 22)
    backupCC:SetScript("OnClick", function()
        BackupCurrent("Manual backup before/around CC management")
    end)

    local clearCC = CreateButton(frame, "Clear CC...", 90, 22)
    clearCC:SetPoint("LEFT", backupCC, "RIGHT", 4, 0)
    clearCC:SetScript("OnClick", function()
        ShowClearDialog("cc")
    end)

    local backupSpell = CreateButton(frame, "Backup", 70, 22)
    backupSpell:SetPoint("LEFT", clearCC, "RIGHT", 16, 0)
    backupSpell:SetScript("OnClick", function()
        BackupCurrent("Manual backup before/around spell management")
    end)

    local clearSpell = CreateButton(frame, "Clear Spell...", 100, 22)
    clearSpell:SetPoint("LEFT", backupSpell, "RIGHT", 4, 0)
    clearSpell:SetScript("OnClick", function()
        ShowClearDialog("spell")
    end)

    local backupAll = CreateButton(frame, "Backup", 70, 22)
    backupAll:SetPoint("LEFT", clearSpell, "RIGHT", 16, 0)
    backupAll:SetScript("OnClick", function()
        BackupCurrent("Manual backup before/around full immunity reset")
    end)

    local clearAll = CreateButton(frame, "Clear All...", 90, 22)
    clearAll:SetPoint("LEFT", backupAll, "RIGHT", 4, 0)
    clearAll:SetScript("OnClick", function()
        ShowClearDialog("all")
    end)

    local backups = CreateButton(frame, "Backups...", 90, 22)
    backups:SetPoint("LEFT", clearAll, "RIGHT", 16, 0)
    backups:SetScript("OnClick", function()
        historyDialog:Show()
    end)

    CreateTargetPanel(frame)
    clearDialog = CreateClearDialog(frame)
    historyDialog = CreateHistoryDialog(frame)

    local eventFrame = CreateFrame("Frame", "SCRM_DLSI_UIEventFrame", frame)
    eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
    eventFrame:RegisterEvent("UNIT_AURA")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:SetScript("OnEvent", function()
        if not frame:IsShown() then return end
        if event == "UNIT_AURA" and arg1 and arg1 ~= "target" then
            return
        end
        RefreshTargetPanel()
    end)

    frame:SetScript("OnShow", function()
        if learningAlertDurationSlider then learningAlertDurationSlider:SetValue(GetLearningAlertDuration()) end
        RefreshAll()
    end)
    frame:SetScript("OnHide", function()
        StopTargetModelRotation()
    end)

    frame:Hide()
    mainFrame = frame
end

function CleveRoids.RefreshImmunityUI()
    if mainFrame and mainFrame:IsShown() then
        RefreshAll()
    end
end

function CleveRoids.ToggleImmunityUI()
    if not mainFrame then
        CreateMainFrame()
    end

    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        RefreshAll()
    end
end

local function HandleKnowledgeTransition(transition)
    ShowLearningTransition(transition)
end

if CleveRoids.ImmunityKnowledge and CleveRoids.ImmunityKnowledge.RegisterTransitionListener then
    CleveRoids.ImmunityKnowledge.RegisterTransitionListener(HandleKnowledgeTransition)
end

CreateMainFrame()

end
-- END preserved source: ImmunityUI.lua

-- Chunk D: the host supplies selection and exclusive automatic-learning
-- ownership; this private bridge supplies only DLSI's three-state truth.
-- No legacy SavedVariables data is consulted or written here.
local PROVIDER_ID = "scrm-dlsi"
local QUERY_DIMENSIONS = {
    all=true, cc=true, spell=true, physical=true, holy=true, fire=true,
    nature=true, frost=true, shadow=true, arcane=true, bleed=true,
    charm=true, disorient=true, fear=true, root=true, silence=true,
    sleep=true, snare=true, stun=true, freeze=true, knockout=true,
    polymorph=true, banish=true, shackle=true, horror=true, daze=true,
    dispel_magic=true, curse=true, disease=true, poison=true,
}
local MAGIC_SCHOOLS = {
    holy=true, fire=true, nature=true, frost=true, shadow=true, arcane=true,
}
local CC_DIMENSIONS = {
    charm=true, disorient=true, fear=true, root=true, silence=true,
    sleep=true, snare=true, stun=true, freeze=true, knockout=true,
    polymorph=true, banish=true, shackle=true, horror=true, daze=true,
}

local function AddQueryDimension(list, seen, dimension)
    if QUERY_DIMENSIONS[dimension] and not seen[dimension] then
        seen[dimension] = true
        table.insert(list, dimension)
    end
end

local function GetQuerySpellID(host, text)
    if type(text) == "number" then
        if text > 0 then return text end
        return nil
    end
    if type(text) ~= "string" then return nil end
    local base = text
    if type(host.StripRank) == "function" then
        base = host.StripRank(text) or text
    else
        base = string.gsub(text, "%s*%([Rr]ank%s+%d+%)%s*$", "")
    end
    base = string.gsub(base, "_", " ")
    if type(host.GetSpellIdForName) == "function" then
        return host.GetSpellIdForName(base)
    end
    if type(GetSpellIdForName) == "function" then
        return GetSpellIdForName(base)
    end
    return nil
end

local function BuildQueryDimensions(profile)
    local dimensions, seen = {}, {}
    if type(profile) ~= "table" then return dimensions, false end
    local school = profile.school
    -- An unknown school means the complete action cannot be proved vulnerable.
    local complete = QUERY_DIMENSIONS[school] and true or false
    AddQueryDimension(dimensions, seen, school)
    if MAGIC_SCHOOLS[school] then
        AddQueryDimension(dimensions, seen, "spell")
    end
    -- Retain the original typed mechanic/dispel classifiers from Observations.
    AddQueryDimension(dimensions, seen, profile.dispelDimension)
    local mechanics = profile.mechanicDimensions or {}
    for i = 1, table.getn(mechanics) do
        local dimension = mechanics[i]
        AddQueryDimension(dimensions, seen, dimension)
        if CC_DIMENSIONS[dimension] then
            AddQueryDimension(dimensions, seen, "cc")
        end
    end
    AddQueryDimension(dimensions, seen, "all")
    return dimensions, complete
end

local function QueryDLSIImmunity(DLSI, host, unitId, spellOrSchool)
    local storage = DLSI.ImmunityStorage
    local knowledge = DLSI.ImmunityKnowledge
    if not storage or not storage.IsReady or not storage.IsReady() or
        not knowledge or not knowledge.IsActive or not knowledge.IsActive() then
        return nil
    end
    if type(UnitExists) ~= "function" or not unitId or
        not UnitExists(unitId) or UnitIsPlayer(unitId) then return nil end
    if type(UnitCreatureID) ~= "function" then return nil end
    local mobID = tonumber(UnitCreatureID(unitId))
    if not mobID or mobID <= 0 or mobID ~= math.floor(mobID) then
        return nil
    end

    local dimensions, complete
    if type(spellOrSchool) == "string" and
        QUERY_DIMENSIONS[string.lower(spellOrSchool)] then
        dimensions = { string.lower(spellOrSchool) }
        complete = true
    else
        local spellID = GetQuerySpellID(host, spellOrSchool)
        if not spellID or not DLSI.ImmunityObservations then return nil end
        local profile = DLSI.ImmunityObservations.GetSpellProfile(spellID)
        if not profile or not profile.name then return nil end
        dimensions, complete = BuildQueryDimensions(profile)
    end

    local anyUnknown = not complete
    for i = 1, table.getn(dimensions) do
        local dimension = dimensions[i]
        -- Confirmed live guards count only for their documented type.
        -- Reflection is a learning exclusion, not proof of immunity.
        if DLSI.HasImmunityGuardAura then
            local _, auraType = DLSI.HasImmunityGuardAura(unitId)
            if auraType == "all" or auraType == dimension or
                (auraType == "spell" and MAGIC_SCHOOLS[dimension]) then
                return true
            end
        end
        if CC_DIMENSIONS[dimension] and DLSI.IsTemporarilyCCImmune and
            DLSI.IsTemporarilyCCImmune(unitId, dimension) then
            return true
        end

        local state = knowledge.GetDimensionState(mobID, dimension)
        if state == "immune" then return true end
        if state ~= "vulnerable" then anyUnknown = true end
    end
    -- Only complete, independently proven vulnerability yields false.
    -- Missing facts, hypotheses, errors and absent identity remain nil.
    if not anyUnknown then return false end
    return nil
end

-- Chunk C integration: private facade, HearthDB lifecycle and event gating.
-- Registration follows successful storage + complete learner/UI activation.
-- The observation frame checks the live host selection on every event.
local DLSI = { DLSIEventsEnabled = false }
local ready = false
local closed = false

DLSI.IsSelectedProvider = function()
    local host = _G.CleveRoids
    return ready and not closed and DLSI.DLSIEventsEnabled and
        host and type(host.GetSelectedImmunityProvider) == "function" and
        host.GetSelectedImmunityProvider() == PROVIDER_ID
end

local function BindPrivateModuleEnvironment(loader)
    -- Lua 5.0 environments isolate accidental global assignments. WoW API
    -- lookup still uses the game's global table; private writes stay private.
    local environment = {}
    setmetatable(environment, { __index = _G })
    setfenv(loader, environment)
end

local function PrepareDLSI()
    if ready or closed then return ready end
    local host = _G.CleveRoids
    if type(host) ~= "table" or type(host.ClassicAPI) ~= "table" then
        return false
    end
    local api = host.ClassicAPI
    -- Only the common host API is required. The additional prototype
    -- readers are private read-only adapters defined above.
    local required = {
        "GetSpellMechanicByID", "GetSpellEffectMechanics"
    }
    for i = 1, table.getn(required) do
        if type(api[required[i]]) ~= "function" then return false end
    end
    if type(_G.C_Spell) ~= "table" or
        type(C_Spell.GetSpellName) ~= "function" or
        type(C_Spell.GetSpellTexture) ~= "function" or
        type(C_Spell.GetSpellEffectInfo) ~= "function" or
        type(C_Spell.GetSpellDispelType) ~= "function" or
        type(_G.GetSpellSchool) ~= "function" or
        type(_G.UnitTokenFromGUID) ~= "function" or
        type(_G.UnitGUID) ~= "function" or
        type(_G.UnitCreatureID) ~= "function" or
        type(host.RegisterImmunityProvider) ~= "function" or
        type(host.GetSelectedImmunityProvider) ~= "function" then
        return false
    end
    local adapters = CreateDLSIHostAdapters(host)
    DLSI.NormalizeGUID = adapters.NormalizeGUID
    DLSI.ClassicAPI = adapters.ClassicAPI
    DLSI.Print = adapters.Print
    DLSI.NotifyImmunityDataChanged = adapters.NotifyImmunityDataChanged
    DLSI.GetImmunityDebugSnapshot = adapters.GetImmunityDebugSnapshot
    DLSI.HasImmunityGuardAura = adapters.HasImmunityGuardAura
    DLSI.IsTemporarilyCCImmune = adapters.IsTemporarilyCCImmune
    DLSI.GetTransientImmunityAuraEffects = adapters.GetTransientImmunityAuraEffects
    DLSI.GetSpellImmunityDRType = adapters.GetSpellImmunityDRType
    DLSI.ClassifyNPCStunDR = adapters.ClassifyNPCStunDR
    DLSI.hasNampower = host.hasNampower and true or false
    DLSI.hasTurtle = host.hasTurtle and true or false
    DLSI.unknownTexture = host.unknownTexture
    adapters.OnKnowledgeChanged = function()
        if DLSI.RefreshImmunityUI then DLSI.RefreshImmunityUI() end
    end

    -- Opening storage precedes all knowledge listeners and inference activation.
    -- Storage.Initialize fails closed on missing HearthDB or unknown schema.
    BindPrivateModuleEnvironment(LoadOriginalImmunityStorage)
    local loaded, err = pcall(LoadOriginalImmunityStorage, DLSI)
    if not loaded then
        closed = true -- partially loaded modules must never be retried/duplicated
        if host.Print then host.Print("DLSI storage failed: " .. tostring(err)) end
        return false
    end
    local storage = DLSI.ImmunityStorage
    if not storage then closed = true; return false end
    local initialized, ok = pcall(storage.Initialize)
    if not initialized or not ok then
        if not initialized then
            closed = true
            if host.Print then host.Print("DLSI HearthDB failed: " .. tostring(ok)) end
        end
        storage.Close()
        return false
    end

    -- One existing Observations frame owns the normalized learner event seam.
    -- Register the provider only after every original module has loaded.
    BindPrivateModuleEnvironment(LoadOriginalImmunityObservations)
    BindPrivateModuleEnvironment(LoadOriginalImmunityTransient)
    BindPrivateModuleEnvironment(LoadOriginalImmunityKnowledge)
    BindPrivateModuleEnvironment(LoadOriginalImmunityUI)
    local modulesLoaded, moduleError = pcall(function()
        LoadOriginalImmunityObservations(DLSI)
        LoadOriginalImmunityTransient(DLSI)
        LoadOriginalImmunityKnowledge(DLSI)
        LoadOriginalImmunityUI(DLSI)
    end)
    if not modulesLoaded then
        closed = true
        storage.Close()
        if host.Print then host.Print("DLSI module startup failed: " ..
            tostring(moduleError)) end
        return false
    end

    local registered = host.RegisterImmunityProvider(
        PROVIDER_ID, "SCRM Deep Learning Immunities",
        function(unit, spell)
            if not DLSI.IsSelectedProvider() then return nil end
            return QueryDLSIImmunity(DLSI, host, unit, spell)
        end)
    if not registered then
        closed = true
        storage.Close()
        if host.Print then host.Print("DLSI provider registration failed") end
        return false
    end
    ready = true
    DLSI.DLSIEventsEnabled = true
    return true
end

local lifecycle = CreateFrame("Frame", "SCRM_DLSI_LifecycleFrame")
lifecycle:RegisterEvent("ADDON_LOADED")
lifecycle:RegisterEvent("PLAYER_ENTERING_WORLD")
lifecycle:RegisterEvent("PLAYER_LOGOUT")
lifecycle:SetScript("OnEvent", function()
    if event == "PLAYER_LOGOUT" then
        closed = true
        DLSI.DLSIEventsEnabled = false
        if DLSI.ImmunityStorage then DLSI.ImmunityStorage.Close() end
        return
    end
    if event == "ADDON_LOADED" and arg1 ~= ADDON_NAME then return end
    PrepareDLSI()
end)

-- DLSI-owned UI entry point; no host slash command or macro UI is replaced.
SLASH_SCRMDLSI1 = "/dlsi"
SlashCmdList["SCRMDLSI"] = function()
    if ready and DLSI.ToggleImmunityUI then
        DLSI.ToggleImmunityUI()
    elseif _G.CleveRoids and _G.CleveRoids.Print then
        _G.CleveRoids.Print("DLSI is unavailable; check HearthDB and ClassicAPI")
    end
end
