-- ===========================================================================
-- ClothMorphRuntime / Shared.lua
-- ---------------------------------------------------------------------------
-- Shared data + helpers used by BootstrapServer.lua and BootstrapClient.lua.
-- Loaded in BOTH the server and client Lua states via Ext.Require, so it must
-- NOT call Osi.* at load time (Osi only exists server-side). All ASCII.
-- No os.* / io.* (sandbox disables them; use Ext.* instead).
-- ===========================================================================

local M = {}

-- ---------------------------------------------------------------------------
-- Body choices the player can pick. "vanilla" means "remove any override and
-- use the game's default body" so it has NO CCSV entry.
-- ---------------------------------------------------------------------------
M.BODY_CHOICES = {
    vanilla = "vanilla", -- remove override -> stock body
    sbbf    = "sbbf",    -- Soft Body / Better Bodies Female (FredKarrera)
    bcb     = "bcb",     -- BCB add-on body (Sindae)
}

-- True if the given string is a valid body-choice keyword.
function M.IsValidBodyChoice(choice)
    return choice ~= nil and M.BODY_CHOICES[choice] ~= nil
end

-- ---------------------------------------------------------------------------
-- Body coverage registry.
--
-- The CCSV lookup is generated from tools/body_registry_manifest.json into
-- BodyRegistry.lua. That keeps runtime coverage data out of this shared helper
-- and gives the content generator one canonical place to add future race/body
-- combinations.
--
-- KEY FORMAT: "<bodychoice>__<race>_<bodytype><shape>"
-- VALUE: CharacterCreationSharedVisual GUID, never a raw VisualResource GUID.
-- ---------------------------------------------------------------------------
local BodyRegistry
if Ext ~= nil and Ext.Require ~= nil then
    BodyRegistry = Ext.Require("BodyRegistry.lua")
else
    BodyRegistry = require("BodyRegistry")
end

M.CCSV_MAP = BodyRegistry.MAP
M.CCSV_COVERAGE = BodyRegistry.COVERAGE

-- ---------------------------------------------------------------------------
-- M.BodyKey(race, bodyType, bodyShape) -> canonical "<race>_<bt><shape>" suffix
-- Both the generator and runtime must call this so keys never drift.
-- ---------------------------------------------------------------------------
function M.BodyKey(race, bodyType, bodyShape)
    return BodyRegistry.BodyKey(race, bodyType, bodyShape)
end

-- Full map key: "<bodychoice>__<bodykey>"
function M.MapKey(bodyChoice, race, bodyType, bodyShape)
    return BodyRegistry.MapKey(bodyChoice, race, bodyType, bodyShape)
end

-- ---------------------------------------------------------------------------
-- M.ResolveCcsv(bodyChoice, race, bodyType, bodyShape)
--   -> ccsvGuid, mapKey   (ccsvGuid is nil for "vanilla" or unmapped combos)
-- Pure: does not touch Osi or the entity; safe in either context.
-- ---------------------------------------------------------------------------
function M.ResolveCcsv(bodyChoice, race, bodyType, bodyShape)
    return BodyRegistry.ResolveCcsv(bodyChoice, race, bodyType, bodyShape)
end

-- ---------------------------------------------------------------------------
-- M.ReadCharStats(entity) -> race, bodyType, bodyShape  (strings, or nils)
-- Reads the entity's CharacterCreationStats component defensively. SAFE in
-- either context (it only reads ECS components, not Osi). Callers still wrap
-- this in pcall as a second belt.
-- ---------------------------------------------------------------------------
function M.ReadCharStats(entity)
    if entity == nil then return nil, nil, nil end
    local ccs = entity.CharacterCreationStats
    if ccs == nil then return nil, nil, nil end
    -- Field names per BG3SE's CharacterCreationStats component.
    local race      = ccs.Race
    local bodyType  = ccs.BodyType
    local bodyShape = ccs.BodyShape
    return race, bodyType, bodyShape
end

-- ---------------------------------------------------------------------------
-- M.FindOverride(entity, searchGuid, sayFn) -> hits, allNames
--   DISCOVERY tool. Lists every component on `entity` and flags any whose
--   serialized contents contain `searchGuid`. We need this because BG3 Osiris
--   has NO RemoveCustomVisualOverride (verified: AddCustomVisualOverride is the
--   only CustomVisual call). To switch/clear a body override we must edit the
--   component that stores it -- and the SE docs do not name that component, so
--   we locate it empirically: apply an override, then run this with the applied
--   CCSV GUID to see which component now contains it.
--   Read-only and pcall-guarded; safe in either context. Visual override data
--   is often client-side, so run this in BOTH `server` and `client` consoles.
-- ---------------------------------------------------------------------------
function M.FindOverride(entity, searchGuid, sayFn)
    local say = sayFn or print
    local hits = {}
    if entity == nil then say("FindOverride: nil entity"); return hits, nil end
    local names
    local okN = pcall(function() names = entity:GetAllComponentNames() end)
    if not okN or names == nil then
        say("FindOverride: GetAllComponentNames failed")
        return hits, nil
    end
    local needle = tostring(searchGuid or ""):lower()
    for _, n in ipairs(names) do
        local comp
        pcall(function() comp = entity[n] end)
        if comp ~= nil and needle ~= "" then
            local s
            local okS = pcall(function() s = Ext.Json.Stringify(comp, { Beautify = false }) end)
            if okS and s ~= nil and tostring(s):lower():find(needle, 1, true) then
                hits[#hits + 1] = n
                say("  MATCH component: " .. tostring(n))
            end
        end
    end
    say(("FindOverride: scanned %d components, %d match(es) for %s")
        :format(#names, #hits, needle))
    return hits, names
end

return M
