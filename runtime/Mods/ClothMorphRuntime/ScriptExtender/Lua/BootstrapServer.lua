-- ===========================================================================
-- ClothMorphRuntime / BootstrapServer.lua
-- ---------------------------------------------------------------------------
-- SERVER context. Osi.* exists here (and ONLY here). Applies / clears / switches
-- the per-character nude-body override and persists the choice in PersistentVars.
--
-- VERIFIED MECHANISM (in-game, 2026-06-24):
--   * APPLY a body  : Osi.AddCustomVisualOverride(char, ccsv)
--       -> APPENDS the CCSV GUID to entity.CharacterCreationAppearance.Visuals
--          and renders it. (ccsv = a CharacterCreationSharedVisual GUID.)
--   * There is NO Osiris remove. RemoveCustomVisualOverride does not exist.
--   * Overrides STACK (each Add appends) and PERSIST in the savegame.
--   * CLEAR / SWITCH / REVERT (the only way): read
--       entity.CharacterCreationAppearance.Visuals, rebuild the array WITHOUT the
--       CCSV(s) we appended, assign it back, then
--       entity:Replicate("CharacterCreationAppearance")  -- syncs + re-renders.
--     Confirmed: assigning a Lua array to .Visuals + Replicate works and the body
--     visibly reverts.
--
-- Because overrides persist in the save, we do NOT re-apply on load (that would
-- stack). We DO strip-before-apply on every change so we never accumulate.
--
-- Gotchas obeyed: console cmds need "!"; no os.*/io.* (use Ext.*); Net via
-- Ext.Net.CreateChannel; all risky calls pcall'd; ASCII only.
-- ===========================================================================

local Shared    = Ext.Require("Shared.lua")
local EquipRace = Ext.Require("EquipRace.lua")  -- clothed half (EquipmentRace runtime, 2026-07-01)
local Targeting = Ext.Require("Targeting.lua")
local SharedTemplateProbe = Ext.Require("SharedTemplateProbe.lua")
local McmGlue   = Ext.Require("MCMIntegration.lua")  -- BG3MCM bridge (hard dependency as of v4.7, 2026-07-11)

local MOD = Mods.ClothMorphRuntime

PersistentVars = PersistentVars or {}
local SCHEMA_VERSION = 4  -- v4: added ClothedChoice/OrigEquipRace (EquipmentRace clothed half)

local function Log(msg)  Ext.Utils.Print("[ClothMorphRuntime:Server] " .. tostring(msg)) end
local function Warn(msg) Ext.Utils.PrintWarning("[ClothMorphRuntime:Server] " .. tostring(msg)) end

-- Normalize any Osiris object reference to a bare lowercase GUID. Osiris
-- events (Equipped/Unequipped) pass characters as "Name_guid" strings while
-- our PV.Bodies records are keyed by the bare GUID form - a raw table lookup
-- silently misses and the auto-toggle no-ops (bug found in-game 2026-07-04:
-- equipping vanilla armor over the SBBF nude body clipped instead of
-- reconciling). Bare GUIDs are accepted by both Osi.* and Ext.Entity.Get.
-- NOTE: must be defined BEFORE EnsurePV (which uses it for re-keying).
local function NormGuid(s)
    s = tostring(s or "")
    local g = s:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)%s*$")
    return (g or s):lower()
end

-- ---------------------------------------------------------------------------
-- PersistentVars schema (saved into the BG3 savegame by SE):
--   PersistentVars = {
--     Version = <int>,
--     Bodies  = { [characterGuid] = { Choice="vanilla|sbbf|bcb", AppliedCcsv=<guid|nil>,
--                                     DesiredCcsv=<guid|nil>,             -- v3 (nude half)
--                                     ClothedChoice="vanilla|sbbf"|nil,   -- v4 (clothed half; nil = vanilla)
--                                     OrigEquipRace=<guid|nil> } },       -- v4 (recorded at first flip)
--   }
-- The override itself ALSO lives in the savegame (CharacterCreationAppearance);
-- PersistentVars just records WHICH CCSV is ours so we know what to strip.
-- ---------------------------------------------------------------------------
local function EnsurePV()
    PersistentVars = PersistentVars or {}
    PersistentVars.Bodies  = PersistentVars.Bodies or {}
    PersistentVars.OptoutTemplates = PersistentVars.OptoutTemplates or {}
    -- v3 migration: existing records gain DesiredCcsv (= AppliedCcsv if present).
    if (PersistentVars.Version or 0) < 3 then
        for _, rec in pairs(PersistentVars.Bodies) do
            if rec.DesiredCcsv == nil and rec.AppliedCcsv ~= nil then
                rec.DesiredCcsv = rec.AppliedCcsv
            end
        end
    end
    -- v4: ClothedChoice/OrigEquipRace default to nil (= vanilla); no rewrite needed.
    if (PersistentVars.Version or 0) < SCHEMA_VERSION then
        PersistentVars.Version = SCHEMA_VERSION
    end
    -- Re-key all records to bare lowercase GUIDs (idempotent; guards against
    -- records created from prefixed "Name_guid" strings).
    local rekeyed = {}
    local changed = false
    for k, rec in pairs(PersistentVars.Bodies) do
        local nk = NormGuid(k)
        if rekeyed[nk] == nil then rekeyed[nk] = rec end
        if nk ~= k then changed = true end
    end
    if changed then PersistentVars.Bodies = rekeyed end
    return PersistentVars
end

local function GetHostChar()
    local ok, char = pcall(function() return Osi.GetHostCharacter() end)
    if ok and char ~= nil and char ~= "" then return NormGuid(char) end
    return nil
end

local function ResolveCommandChar(charArg)
    local char = Targeting.NormGuid(charArg)
    if char == nil then char = GetHostChar() end
    return char
end

local function ResolveNetTarget(data, user)
    local requested = Targeting.NormGuid(data and (data.target or data.char or data.character))
    local host = Targeting.NormGuid(GetHostChar())
    -- v4.8 SP/loopback tolerance (2026-07-13): in single-player, SE's channel
    -- handler can deliver a nil or non-Osiris-format sender id for the LOCAL
    -- client. v4.7's strict validation therefore silently dropped EVERY
    -- client-forwarded command -- including the MCM toggle (regression Alan hit).
    -- Requests that target (or default to) the HOST character are accepted
    -- without sender checks; that is inherently safe in single-player.
    if host ~= nil and (requested == nil or requested == host) then
        return host
    end
    -- Party-member tolerance (single-player companions). TODO-MULTIPLAYER:
    -- replace with real per-user ownership validation once the userId<->
    -- Osi.GetReservedUserID format mapping is calibrated from live MP logs.
    if requested ~= nil and Osi ~= nil then
        local okPM, isPM = pcall(function() return Osi.IsPartyMember(requested, 1) end)
        if okPM and (isPM == 1 or isPM == true) then
            return requested
        end
    end
    if user == nil then
        Warn(("Net channel: denied cmd='%s' target='%s' reason=missing-sender-user"):format(
            tostring(data and data.cmd),
            tostring(data and data.target)))
        return nil
    end
    local char, err, why = Targeting.ResolveTarget(data, user, {
        getHostChar = GetHostChar,
    })
    if char == nil then
        -- Extra diagnostics so a future MP session can calibrate the id formats.
        local reserved = nil
        pcall(function() reserved = Osi.GetReservedUserID(requested) end)
        Warn(("Net channel: denied cmd='%s' target='%s' reason=%s%s [senderType=%s sender=%s reservedForTarget=%s]"):format(
            tostring(data and data.cmd),
            tostring(data and data.target),
            tostring(err),
            why and ("/" .. tostring(why)) or "",
            type(user), tostring(user), tostring(reserved)))
    end
    return char
end

local function GetEntity(char)
    local ok, ent = pcall(function() return Ext.Entity.Get(char) end)
    if ok then return ent end
    return nil
end

-- ---------------------------------------------------------------------------
-- Visuals helpers. CharacterCreationAppearance.Visuals is a userdata array of
-- GUID strings; assigning a Lua array of strings + Replicate is the proven
-- write path.
-- ---------------------------------------------------------------------------
local function GetCCA(entity)
    if entity == nil then return nil end
    local cca
    pcall(function() cca = entity.CharacterCreationAppearance end)
    return cca
end

local function ReadVisuals(cca)
    local out = {}
    if cca == nil or cca.Visuals == nil then return out end
    pcall(function()
        for _, g in ipairs(cca.Visuals) do out[#out + 1] = tostring(g) end
    end)
    return out
end

-- Remove the given GUIDs (set, lowercased keys) from the character's Visuals and
-- push the change to the client. Returns the new list, and how many were removed.
local function StripVisuals(char, dropSet)
    local entity = GetEntity(char)
    local cca = GetCCA(entity)
    if cca == nil then
        Warn("StripVisuals: no CharacterCreationAppearance on " .. tostring(char))
        return nil, 0
    end
    local cur = ReadVisuals(cca)
    local keep, removed = {}, 0
    for _, g in ipairs(cur) do
        if dropSet[tostring(g):lower()] then
            removed = removed + 1
        else
            keep[#keep + 1] = g
        end
    end
    if removed > 0 then
        local okW = pcall(function()
            cca.Visuals = keep
            entity:Replicate("CharacterCreationAppearance")
        end)
        if not okW then
            Warn("StripVisuals: write/Replicate failed for " .. tostring(char))
            return nil, 0
        end
    end
    return keep, removed
end

-- Strip whatever CCSV we previously recorded for this character (if any).
local function StripOurOverride(char)
    local pv = EnsurePV()
    local rec = pv.Bodies[char]
    if rec and rec.AppliedCcsv then
        local dropSet = { [tostring(rec.AppliedCcsv):lower()] = true }
        local _, removed = StripVisuals(char, dropSet)
        Log(("StripOurOverride: removed %d entr(y/ies) of %s from %s")
            :format(removed, tostring(rec.AppliedCcsv), tostring(char)))
    end
end

-- ---------------------------------------------------------------------------
-- ApplyCcsv(char, ccsv): strip our previous override, then apply ccsv and record
-- it. This is the low-level switch primitive (raw CCSV GUID).
-- ---------------------------------------------------------------------------
local function ApplyCcsv(char, ccsv, choiceLabel)
    if char == nil or ccsv == nil or ccsv == "" then
        Warn("ApplyCcsv: missing char/ccsv"); return false
    end
    local pv = EnsurePV()
    StripOurOverride(char)  -- clean switch: never stack
    local okApply = pcall(function() Osi.AddCustomVisualOverride(char, ccsv) end)
    if not okApply then
        Warn("ApplyCcsv: AddCustomVisualOverride failed " .. tostring(ccsv))
        return false
    end
    -- Update fields IN PLACE (v4: the record also carries ClothedChoice /
    -- OrigEquipRace for the EquipmentRace half - do not wipe them).
    local rec = pv.Bodies[char] or {}
    rec.Choice, rec.AppliedCcsv, rec.DesiredCcsv = choiceLabel or "custom", ccsv, ccsv
    pv.Bodies[char] = rec
    Log(("ApplyCcsv: %s -> %s (choice=%s)")
        :format(tostring(char), tostring(ccsv), tostring(choiceLabel or "custom")))
    return true
end

-- RevertChar(char): strip our override, record vanilla. No Osiris remove needed.
-- v4.3: also reverts the CLOTHED half (EquipmentRace) so !cm_revert restores the
-- WHOLE character (nude + armor). Was nude-only before; Alan expected a full
-- revert. The clothed revert is a no-op-safe pcall (does nothing if the char was
-- never flipped / has no recoverable original).
local function RevertChar(char)
    if char == nil then return false end
    local pv = EnsurePV()
    StripOurOverride(char)
    local rec = pv.Bodies[char] or {}
    rec.Choice, rec.AppliedCcsv, rec.DesiredCcsv = "vanilla", nil, nil
    pv.Bodies[char] = rec
    pcall(function() EquipRace.SetClothed(char, "vanilla", rec) end)  -- clothed half too
    Log("RevertChar: " .. tostring(char) .. " reverted to vanilla body + clothing")
    return true
end

-- ---------------------------------------------------------------------------
-- Clothed/nude auto-toggle.
--   Desired body (when nude) = rec.DesiredCcsv (nil => vanilla). When a torso
--   item is worn we STRIP the nude override (the equipped SBBF-refit outfit
--   carries the SBBF shape + occludes the body); when the torso is bare we
--   (re-)apply the desired CCSV. Proven 2026-06-26: nude override punches
--   through clothing, so the two states must be mutually exclusive.
-- ---------------------------------------------------------------------------
local TORSO_SLOTS = { "Breast", "VanityBody" }

local function SlotOccupied(char, slot)
    local occ = false
    pcall(function()
        local it = Osi.GetEquippedItem(char, slot)
        if it ~= nil and it ~= "" then occ = true end
    end)
    return occ
end

-- Which armour set the engine currently RENDERS: "Normal" (Breast slot) or
-- "Vanity" (camp clothes / VanityBody). Ground truth = entity.ArmorSetState
-- .State (eoc::armor_set::StateComponent; same enum as Osi Get/SetArmourSet,
-- values Normal=0 / Vanity=1). nil component = Normal (component can be absent).
local function CurrentArmourSet(char)
    local set = "Normal"
    pcall(function()
        local e = GetEntity(char)
        local s = e ~= nil and e.ArmorSetState or nil
        if s ~= nil then
            local v = s.State
            if v == "Vanity" or v == 1 then set = "Vanity" end
        end
    end)
    return set
end

-- v4.4 camp-clothes fix (2026-07-07, confirmed via slotcheck): camp clothes
-- equipped-but-HIDDEN (armour set Normal, Breast empty, VanityBody occupied)
-- previously counted as covered, so Reconcile stripped the nude override while
-- the character rendered nude. Only the slot belonging to the ACTIVE armour
-- set can visually cover the torso: Vanity -> VanityBody, Normal -> Breast.
-- (Edge assumed, flagged for in-game check: Vanity set + empty VanityBody is
-- treated as bare.)
local function IsTorsoCovered(char)
    if CurrentArmourSet(char) == "Vanity" then
        return SlotOccupied(char, "VanityBody")
    else
        return SlotOccupied(char, "Breast")
    end
end

-- Idempotent: brings the override in line with desire + torso coverage.
local function Reconcile(char, reason)
    local pv = EnsurePV()
    local rec = pv.Bodies[char]
    if rec == nil then return end
    local desired = rec.DesiredCcsv
    if desired == nil then
        if rec.AppliedCcsv then
            StripOurOverride(char); rec.AppliedCcsv = nil
            Log(("Reconcile(%s): desired vanilla -> stripped"):format(tostring(reason)))
        end
        return
    end
    if IsTorsoCovered(char) then
        if rec.AppliedCcsv then
            StripOurOverride(char); rec.AppliedCcsv = nil
            Log(("Reconcile(%s): torso covered -> stripped nude body"):format(tostring(reason)))
        end
    else
        if rec.AppliedCcsv ~= desired then
            ApplyCcsv(char, desired, rec.Choice or "custom")
            Log(("Reconcile(%s): torso bare -> applied %s"):format(tostring(reason), tostring(desired)))
        end
    end
end

-- SetDesiredBody(char, choice): record the player's pick (what to show when
-- nude) then Reconcile so it only renders if the torso is bare. This is the
-- clothing-aware path used by !cm_setbody.
-- v4: ALSO drives the clothed half (EquipmentRace flip) so one command sets
-- the whole character. The two halves stay mutually exclusive via Reconcile
-- (nude CCSV only when torso bare; ER only affects worn gear).
local function SetDesiredBody(char, choice)
    local pv = EnsurePV()
    pv.Bodies[char] = pv.Bodies[char] or { Choice = "vanilla" }
    if choice == "vanilla" then
        pv.Bodies[char].Choice = "vanilla"
        pv.Bodies[char].DesiredCcsv = nil
        Reconcile(char, "setbody-vanilla")
        pcall(function() EquipRace.SetClothed(char, "vanilla", pv.Bodies[char]) end)
        return true
    end
    -- The two halves are INDEPENDENT: a missing nude CCSV mapping must not
    -- block the clothed flip (bug found in-game 2026-07-04: Shadowheart's
    -- unmapped race key aborted before SetClothed ever ran).
    local rec = pv.Bodies[char]
    local okNude, okClothed = false, false
    local entity = GetEntity(char)
    local race, bt, bs
    pcall(function() race, bt, bs = Shared.ReadCharStats(entity) end)
    local ccsv, mapKey = Shared.ResolveCcsv(choice, race, bt, bs)
    if ccsv == nil then
        Warn(("SetDesiredBody: no CCSV mapped for key '%s' (race=%s bt=%s bs=%s) - "
            .. "nude half SKIPPED; attempting clothed half."):format(
            tostring(mapKey), tostring(race), tostring(bt), tostring(bs)))
    else
        rec.Choice = choice
        rec.DesiredCcsv = ccsv
        Reconcile(char, "setbody")
        okNude = true
    end
    -- Clothed half: flip EquipmentRace if this choice has minted clothed assets
    -- (sbbf only in v1).
    if EquipRace.MINTED[choice] ~= nil then
        local okC
        pcall(function() okC = EquipRace.SetClothed(char, choice, rec) end)
        okClothed = (okC == true)
    else
        Log(("SetDesiredBody: '%s' has no clothed (EquipmentRace) assets yet; nude half only."):format(tostring(choice)))
    end
    if okClothed and not okNude then rec.Choice = choice end  -- record intent
    return okNude or okClothed
end

-- ---------------------------------------------------------------------------
-- ApplyBody(char, choice): map choice (sbbf|bcb|vanilla) -> CCSV via Shared and
-- apply it. "vanilla"/unmapped -> revert. Needs CCSV_MAP populated (and, for our
-- own bodies, the ClothMorphContent VisualBank pak loaded so the CCSV resolves).
-- ---------------------------------------------------------------------------
local function ApplyBody(char, choice)
    if char == nil then Warn("ApplyBody: no character"); return false end
    if choice == "vanilla" then return RevertChar(char) end

    local entity = GetEntity(char)
    local race, bt, bs
    pcall(function() race, bt, bs = Shared.ReadCharStats(entity) end)
    local ccsv, mapKey = Shared.ResolveCcsv(choice, race, bt, bs)
    if ccsv == nil then
        Warn(("ApplyBody: no CCSV mapped for key '%s' (race=%s bt=%s bs=%s). "
            .. "Populate CCSV_MAP / load ClothMorphContent."):format(
            tostring(mapKey), tostring(race), tostring(bt), tostring(bs)))
        return false
    end
    return ApplyCcsv(char, ccsv, choice)
end

-- ===========================================================================
-- STATUS / DIAGNOSTICS
-- ===========================================================================
local function DumpStatus(char)
    local pv = EnsurePV()
    if char == nil then Log("Status: no host character."); return end
    local entity = GetEntity(char)
    local race, bt, bs
    pcall(function() race, bt, bs = Shared.ReadCharStats(entity) end)
    local rec = pv.Bodies[char] or {}
    local cca = GetCCA(entity)
    local vis = ReadVisuals(cca)
    Log("---- cm_status ----")
    Log("  Character : " .. tostring(char))
    Log("  Race      : " .. tostring(race))
    Log("  BodyType  : " .. tostring(bt) .. "  BodyShape: " .. tostring(bs))
    Log("  Choice    : " .. tostring(rec.Choice or "vanilla"))
    Log("  OurCcsv   : " .. tostring(rec.AppliedCcsv or "(none)"))
    Log("  Desired   : " .. tostring(rec.DesiredCcsv or "(vanilla)"))
    Log("  Clothed   : " .. tostring(rec.ClothedChoice or "vanilla"))
    Log("  Visuals (" .. tostring(#vis) .. "):")
    for i, g in ipairs(vis) do Log("    " .. i .. "  " .. tostring(g)) end
    Log("-------------------")
end

-- CCSV chain check (StaticData CCSV -> Ext.Resource Visual mesh).
local function CheckBody(char, ccsvArg)
    if char == nil then Log("cm_checkbody: no host character."); return end
    local pv = EnsurePV()
    local rec = pv.Bodies[char] or {}
    local ccsv = ccsvArg or rec.AppliedCcsv or "c0ffeeb0-d100-4b0d-9e57-5bbf00000001"
    Log("---- cm_checkbody ----  CCSV: " .. tostring(ccsv))
    local obj
    pcall(function() obj = Ext.StaticData.Get(ccsv, "CharacterCreationSharedVisual") end)
    if obj == nil then
        Warn("  CCSV did NOT resolve (StaticData). Engine has no such shared-visual.")
    else
        local vr
        pcall(function() vr = obj.VisualResource end)
        Log("  CCSV ok; wrapped VisualResource: " .. tostring(vr))
        if vr and tostring(vr) ~= "" then
            local mesh
            pcall(function() mesh = Ext.Resource.Get(tostring(vr), "Visual") end)
            if mesh == nil then
                Warn("  Visual mesh NOT registered -> body will not render. "
                    .. "(Need the VisualBank that defines this resource.)")
            else
                local sf
                pcall(function() sf = mesh.SourceFile end)
                Log("  Visual mesh ok; SourceFile: " .. tostring(sf))
            end
        end
    end
    Log("----------------------")
end

-- Find which component holds a GUID (discovery; see Shared.FindOverride).
local function FindOverride(char, search)
    local e = GetEntity(char)
    Log(("---- cm_findoverride char=%s search=%s ----"):format(tostring(char), tostring(search)))
    Shared.FindOverride(e, search, function(m) Log(m) end)
    Log("----------------------------------------")
end

-- ===========================================================================
-- CONSOLE COMMANDS (invoke with leading "!", e.g. !cm_status). Mirrored in
-- BootstrapClient.lua so they work from either console context.
-- ===========================================================================
local function Cmd_SetBody(_cmd, choice, charArg)
    choice = choice and tostring(choice):lower() or nil
    if not Shared.IsValidBodyChoice(choice) then
        Warn("!cm_setbody usage: !cm_setbody <vanilla|sbbf|bcb> [charGuid]"); return
    end
    local char = ResolveCommandChar(charArg); if not char then Warn("no character target"); return end
    SetDesiredBody(char, choice); DumpStatus(char)
end

-- !cm_applyccsv <ccsvGuid>  -- apply ANY CCSV by GUID (testing w/ vanilla CCSVs)
local function Cmd_ApplyCcsv(_cmd, ccsv, charArg)
    if not ccsv or ccsv == "" then Warn("!cm_applyccsv <ccsvGuid>"); return end
    local char = ResolveCommandChar(charArg); if not char then Warn("no character target"); return end
    ApplyCcsv(char, tostring(ccsv), "custom"); DumpStatus(char)
end

-- !cm_revert  -- strip our override, back to original body
local function Cmd_Revert(_cmd, charArg)
    local char = ResolveCommandChar(charArg); if not char then Warn("no character target"); return end
    RevertChar(char); DumpStatus(char)
end

local function Cmd_Status(_cmd, charArg)    DumpStatus(ResolveCommandChar(charArg)) end
local function Cmd_CheckBody(_cmd, a, charArg) CheckBody(ResolveCommandChar(charArg), a) end
local function Cmd_FindOverride(_cmd, a, b)
    local char, search
    if b ~= nil and b ~= "" then char, search = a, b else char, search = GetHostChar(), a end
    if not char or char == "" then Warn("!cm_findoverride [charGuid] <searchGuid>"); return end
    FindOverride(char, search)
end

-- !cm_slotcheck  -- diagnostic: print which item occupies each equipment slot,
-- so we can confirm the torso slot string the toggle keys on ("Breast").
local function Cmd_SlotCheck(_cmd, charArg)
    local char = ResolveCommandChar(charArg); if not char then Warn("no character target"); return end
    Log("---- cm_slotcheck ----  char: " .. tostring(char))
    for _, slot in ipairs({ "Breast", "VanityBody", "Cloak", "Helmet",
                            "Gloves", "Boots", "Underwear", "Amulet" }) do
        local it
        pcall(function() it = Osi.GetEquippedItem(char, slot) end)
        Log(("  %-12s = %s"):format(slot, tostring(it)))
    end
    Log(("  ArmourSet      = %s"):format(CurrentArmourSet(char)))
    Log(("  IsTorsoCovered = %s"):format(tostring(IsTorsoCovered(char))))
    Log("----------------------")
end

-- !cm_reconcile  -- manually re-run the clothed/nude toggle for the host.
local function Cmd_Reconcile(_cmd, charArg)
    local char = ResolveCommandChar(charArg); if not char then Warn("no character target"); return end
    Reconcile(char, "manual"); DumpStatus(char)
end

-- ---------------------------------------------------------------------------
-- EquipmentRace clothed-half commands (v4). !cm_setclothed flips ONLY the
-- clothed half (testing granularity); production path is !cm_setbody.
-- ---------------------------------------------------------------------------
local function Cmd_SetClothed(_cmd, choice, charArg)
    choice = choice and tostring(choice):lower() or nil
    if choice ~= "vanilla" and EquipRace.MINTED[choice] == nil then
        Warn("!cm_setclothed usage: !cm_setclothed <vanilla|sbbf> [charGuid]"); return
    end
    local char = ResolveCommandChar(charArg); if not char then Warn("no character target"); return end
    local pv = EnsurePV()
    pv.Bodies[char] = pv.Bodies[char] or { Choice = "vanilla" }
    EquipRace.SetClothed(char, choice, pv.Bodies[char])
    EquipRace.DumpStatus(char, pv.Bodies[char])
end

-- !cm_erpass [force]  -- run the blanket shared-mesh injection pass manually.
local function Cmd_ErPass(_cmd, forceArg)
    EquipRace.RunBlanketPass("sbbf", forceArg == "force")
end

-- !cm_erstatus  -- clothed-half diagnostics for the host.
local function Cmd_ErStatus(_cmd, charArg)
    local char = ResolveCommandChar(charArg); if not char then Warn("no character target"); return end
    local pv = EnsurePV()
    EquipRace.DumpStatus(char, pv.Bodies[char])
end

-- !cm_refresh  -- unequip/re-equip the host's visual slots (force re-render).
local function Cmd_Refresh(_cmd, charArg)
    local char = ResolveCommandChar(charArg); if not char then Warn("no character target"); return end
    EquipRace.RefreshEquipment(char)
end

-- !cm_seterace <equipmentRaceGuid>  -- MANUAL RECOVERY. Write an EquipmentRace
-- onto the selected character, record it as the original, mark clothed=vanilla,
-- and refresh. Use to un-stick a character whose original ER was lost, or to
-- verify a candidate original before trusting it. (Tav: ad21d837-...; SH: 76217761-...)
local function Cmd_SetERace(_cmd, guid, charArg)
    if not guid or guid == "" then Warn("!cm_seterace <equipmentRaceGuid> [charGuid]"); return end
    local char = ResolveCommandChar(charArg); if not char then Warn("no character target"); return end
    local pv = EnsurePV()
    pv.Bodies[char] = pv.Bodies[char] or { Choice = "vanilla" }
    EquipRace.ForceSetEquipRace(char, tostring(guid), pv.Bodies[char])
    EquipRace.DumpStatus(char, pv.Bodies[char])
end

-- !cm_optout [off]  -- exclude the host's equipped torso item from vanilla-VR
-- remapping (hybrid modded outfits keep their authored look on flipped bodies).
-- "!cm_optout" turns it ON for the equipped torso item; "!cm_optout off" undoes.
local function Cmd_Optout(_cmd, arg, charArg)
    local on = (arg ~= "off")
    local char = ResolveCommandChar(charArg); if not char then Warn("no character target"); return end
    local item
    for _, slot in ipairs(TORSO_SLOTS) do
        pcall(function()
            local it = Osi.GetEquippedItem(char, slot)
            if item == nil and it ~= nil and it ~= "" then item = it end
        end)
    end
    if item == nil then
        Warn("!cm_optout: nothing equipped in a torso slot - equip the item first, then run !cm_optout")
        return
    end
    local id = EquipRace.SetOptout(item, on)
    if id ~= nil then
        local pv = EnsurePV()
        pv.OptoutTemplates[id:lower()] = (on and true) or nil
        Log(("cm_optout: item %s template %s optout=%s (persisted)"):format(tostring(item), id, tostring(on)))
        EquipRace.RefreshEquipment(char)
    end
end

local function ExpectedEquipRace(char, choice)
    choice = choice and tostring(choice):lower() or nil
    if choice == nil or choice == "" then return nil end
    if EquipRace.MINTED[choice] ~= nil then return EquipRace.MINTED[choice] end
    if choice == "vanilla" then
        local rec = EnsurePV().Bodies[char] or {}
        return rec.OrigEquipRace
    end
    return Targeting.NormGuid(choice) or choice
end

local function RunSharedProbe(charA, expectedA, charB, expectedB)
    charA, charB = Targeting.NormGuid(charA), Targeting.NormGuid(charB)
    if charA == nil or charB == nil then
        Warn("!cm_sharedprobe <charA> <expectedA> <charB> <expectedB>")
        return
    end
    local snapA = SharedTemplateProbe.ReadSnapshot(charA, { getEntity = GetEntity })
    local snapB = SharedTemplateProbe.ReadSnapshot(charB, { getEntity = GetEntity })
    local report = SharedTemplateProbe.CompareSnapshots({
        a = snapA,
        b = snapB,
        expectedA = ExpectedEquipRace(charA, expectedA),
        expectedB = ExpectedEquipRace(charB, expectedB),
    })
    Log("---- cm_sharedprobe ----")
    Log("  expectedA : " .. tostring(report.expectedA or expectedA))
    Log("  expectedB : " .. tostring(report.expectedB or expectedB))
    Log("  " .. SharedTemplateProbe.FormatReport(report))
    if report.sameTemplate and report.equipmentRaceLeak then
        Warn("cm_sharedprobe: FAIL - shared-template characters collapsed to the same EquipmentRace state.")
    elseif report.sameTemplate then
        Log("cm_sharedprobe: PASS - shared-template characters kept distinct EquipmentRace states.")
    else
        Warn("cm_sharedprobe: characters do not report the same template; this is not the shared-template isolation case.")
    end
    Log("------------------------")
end

-- !cm_sharedprobe <charA> <expectedA> <charB> <expectedB>
-- expected values can be vanilla, sbbf, bcb, or an EquipmentRace GUID.
local function Cmd_SharedProbe(_cmd, charA, expectedA, charB, expectedB)
    if not charA or not expectedA or not charB or not expectedB then
        Warn("!cm_sharedprobe <charA> <expectedA> <charB> <expectedB>")
        return
    end
    RunSharedProbe(charA, expectedA, charB, expectedB)
end

-- !cm_sharedapply <charA> <choiceA> <charB> <choiceB>
-- Applies two choices, then runs the shared-template isolation report.
local function Cmd_SharedApply(_cmd, charA, choiceA, charB, choiceB)
    charA, charB = Targeting.NormGuid(charA), Targeting.NormGuid(charB)
    choiceA = choiceA and tostring(choiceA):lower() or nil
    choiceB = choiceB and tostring(choiceB):lower() or nil
    if charA == nil or charB == nil or not Shared.IsValidBodyChoice(choiceA) or not Shared.IsValidBodyChoice(choiceB) then
        Warn("!cm_sharedapply <charA> <vanilla|sbbf|bcb> <charB> <vanilla|sbbf|bcb>")
        return
    end
    SetDesiredBody(charA, choiceA)
    SetDesiredBody(charB, choiceB)
    RunSharedProbe(charA, choiceA, charB, choiceB)
end

Ext.RegisterConsoleCommand("cm_optout",       Cmd_Optout)
Ext.RegisterConsoleCommand("cm_setbody",      Cmd_SetBody)
Ext.RegisterConsoleCommand("cm_applyccsv",    Cmd_ApplyCcsv)
Ext.RegisterConsoleCommand("cm_revert",       Cmd_Revert)
Ext.RegisterConsoleCommand("cm_status",       Cmd_Status)
Ext.RegisterConsoleCommand("cm_checkbody",    Cmd_CheckBody)
Ext.RegisterConsoleCommand("cm_findoverride", Cmd_FindOverride)
Ext.RegisterConsoleCommand("cm_slotcheck",    Cmd_SlotCheck)
Ext.RegisterConsoleCommand("cm_reconcile",    Cmd_Reconcile)
Ext.RegisterConsoleCommand("cm_setclothed",   Cmd_SetClothed)
Ext.RegisterConsoleCommand("cm_erpass",       Cmd_ErPass)
Ext.RegisterConsoleCommand("cm_erstatus",     Cmd_ErStatus)
Ext.RegisterConsoleCommand("cm_refresh",      Cmd_Refresh)
Ext.RegisterConsoleCommand("cm_seterace",     Cmd_SetERace)
Ext.RegisterConsoleCommand("cm_sharedprobe",  Cmd_SharedProbe)
Ext.RegisterConsoleCommand("cm_sharedapply",  Cmd_SharedApply)

-- ===========================================================================
-- NET CHANNEL -- client-context console commands forward intent to the server.
-- ===========================================================================
-- The client sends one-way messages via Channel:SendToServer, so the server must
-- register a MESSAGE handler with :SetHandler (NOT :SetRequestHandler, which only
-- catches RequestToServer). Using SetRequestHandler was the "no message handler
-- was registered" bug that made client-console (C >>) commands silently no-op.
local Channel = Ext.Net.CreateChannel(MOD.ModuleUUID or "ClothMorphRuntime", "ClothMorphRuntime_Cmd")
local function NetMessageArgs(a, b, c)
    if type(a) == "table" and a.cmd ~= nil then return a, b end
    if type(b) == "table" and b.cmd ~= nil then return b, c end
    return a, b
end

local function DispatchNetCmd(a, b, c)
    local data, user = NetMessageArgs(a, b, c)
    data = data or {}
    local cmd = data.cmd
    local char = nil
    if cmd ~= "erpass" then
        char = ResolveNetTarget(data, user)
        if char == nil then return end
    end
    if     cmd == "setbody"   then Cmd_SetBody("cm_setbody", data.arg, char)
    elseif cmd == "mcm_setbody" then  -- MCM change forwarded from the client leg (deduped vs the server-side event)
        McmGlue.NetApply({ Log = Log, Warn = Warn, IsValid = Shared.IsValidBodyChoice,
                           SetDesiredBody = SetDesiredBody }, data.arg, char)
    elseif cmd == "applyccsv" then Cmd_ApplyCcsv("cm_applyccsv", data.arg, char)
    elseif cmd == "revert"    then Cmd_Revert("cm_revert", char)
    elseif cmd == "status"    then Cmd_Status("cm_status", char)
    elseif cmd == "checkbody" then Cmd_CheckBody("cm_checkbody", data.arg, char)
    elseif cmd == "slotcheck" then Cmd_SlotCheck("cm_slotcheck", char)
    elseif cmd == "reconcile" then Cmd_Reconcile("cm_reconcile", char)
    elseif cmd == "setclothed" then Cmd_SetClothed("cm_setclothed", data.arg, char)
    elseif cmd == "erpass"    then Cmd_ErPass("cm_erpass", data.arg)
    elseif cmd == "erstatus"  then Cmd_ErStatus("cm_erstatus", char)
    elseif cmd == "refresh"   then Cmd_Refresh("cm_refresh", char)
    elseif cmd == "seterace"  then Cmd_SetERace("cm_seterace", data.arg, char)
    elseif cmd == "optout"    then Cmd_Optout("cm_optout", data.arg, char)
    else Warn("Net channel: unknown cmd '" .. tostring(cmd) .. "'") end
end
Channel:SetHandler(DispatchNetCmd)
-- Also accept request-style calls, in case a future client uses RequestToServer.
pcall(function()
    Channel:SetRequestHandler(function(a, b, c) DispatchNetCmd(a, b, c); return { ok = true } end)
end)

-- Expose for debugging.
MOD.ApplyBody = ApplyBody
MOD.ApplyCcsv = ApplyCcsv
MOD.RevertChar = RevertChar
MOD.DumpStatus = DumpStatus
MOD.StripOurOverride = StripOurOverride
MOD.Reconcile = Reconcile
MOD.SetDesiredBody = SetDesiredBody

-- ===========================================================================
-- EQUIP / UNEQUIP AUTO-TOGGLE
--   Only chars we track (have a record in PV.Bodies) are managed. On any
--   torso equip change we Reconcile: covered -> strip nude override, bare ->
--   re-apply the desired CCSV. The Equip/Unequip event itself re-renders the
--   character, which avoids the strip-while-clothed stale-render problem seen
--   with a bare !cm_revert. Arg order is handled defensively (either may be the
--   character). Osi only exists server-side, so this lives here.
-- ===========================================================================
local function OnEquipChange(a, b, ev)
    local pv = EnsurePV()
    -- Normalize BOTH args before lookup: Osiris passes "Name_guid" forms here,
    -- while PV.Bodies is keyed by bare lowercase GUIDs (see NormGuid).
    local na, nb = NormGuid(a), NormGuid(b)
    local char, item = nil, nil
    if pv.Bodies[na] then char, item = na, b elseif pv.Bodies[nb] then char, item = nb, a end
    if char == nil then return end
    pcall(function() Reconcile(char, ev) end)
    -- Clothed half: a flipped char equipping an item whose template lacks our
    -- minted key (modded item / child template) would render INVISIBLE (P3).
    -- Late-inject + re-equip that item.
    if ev == "Equipped" and item ~= nil then
        pcall(function() EquipRace.OnEquipped(item, char, pv.Bodies[char]) end)
    end
end

pcall(function()
    Ext.Osiris.RegisterListener("Equipped", 2, "after",
        function(item, char) OnEquipChange(item, char, "Equipped") end)
    Ext.Osiris.RegisterListener("Unequipped", 2, "after",
        function(item, char) OnEquipChange(item, char, "Unequipped") end)
    Log("Equip/Unequip auto-toggle listeners registered.")
end)

-- v4.4: re-reconcile when the armour set flips (camp arrival/departure). All
-- vanilla set changes route through the story PROC_SetArmourSet(_Char, _Set);
-- user-defined PROCs ARE capturable by BG3SE (built-in SetArmourSet is NOT,
-- per API.md). Defensive pcall: if the PROC name ever changes, the Equipped/
-- Unequipped listeners still cover most transitions.
pcall(function()
    Ext.Osiris.RegisterListener("PROC_SetArmourSet", 2, "after",
        function(char, _set)
            local pv = EnsurePV()
            local n = NormGuid(char)
            if pv.Bodies[n] ~= nil then
                pcall(function() Reconcile(n, "armourset") end)
            end
        end)
    Log("PROC_SetArmourSet reconcile listener registered.")
end)

-- ===========================================================================
-- LIFECYCLE
--   Overrides PERSIST in the save, so we do NOT re-apply on load (that would
--   stack). We only normalize PersistentVars here.
-- ===========================================================================
Ext.Events.SessionLoaded:Subscribe(function()
    EnsurePV()
    -- Seed the remap opt-out set from the save (persisted by !cm_optout).
    local nOpt = 0
    for tid, v in pairs(PersistentVars.OptoutTemplates or {}) do
        if v then EquipRace.OPTOUT[tostring(tid):lower()] = true; nOpt = nOpt + 1 end
    end
    if nOpt > 0 then Log(("SessionLoaded: seeded %d remap opt-out template(s)."):format(nOpt)) end
    local n, nClothed = 0, 0
    local choices = {}
    for _, rec in pairs(PersistentVars.Bodies or {}) do
        n = n + 1
        if rec.ClothedChoice ~= nil and rec.ClothedChoice ~= "vanilla" then
            nClothed = nClothed + 1
            choices[rec.ClothedChoice] = true
        end
        -- C2 companion (2026-07-06): a character flagged NeedsRecovery (or with a
        -- recorded orig) may still carry a persisted minted ER even though its
        -- ClothedChoice reads vanilla - keep the pass alive so gear stays visible.
        if rec.NeedsRecovery and rec.ClothedChoice ~= nil and rec.ClothedChoice ~= "vanilla" then
            choices[rec.ClothedChoice] = true
        elseif rec.NeedsRecovery then
            choices["sbbf"] = true  -- unknown choice: sbbf pass is the safe default
        end
    end
    Log(("SessionLoaded: schema v%d, %d recorded choice(s) (%d clothed). Nude overrides "
        .. "persist in the save; not re-applying those."):format(PersistentVars.Version or 0, n, nClothed))
    -- Clothed half: template writes are NOT save-persistent -> run the blanket
    -- injection pass now for EVERY distinct persisted choice (C1 fix 2026-07-06:
    -- was hardcoded "sbbf", which left bcb-flipped characters invisible on reload).
    for choice in pairs(choices) do
        pcall(function() EquipRace.RunBlanketPass(choice, false) end)
    end
end)

-- Re-apply clothed flips once characters exist / after a save is loaded.
-- (EquipRace.ReapplyAll is idempotent: it skips chars already on the minted GUID.)
local MCM_DEPS = { Log = Log, Warn = Warn, IsValid = Shared.IsValidBodyChoice,
                   ResolveMcmTarget = function() return nil end,
                   SetDesiredBody = SetDesiredBody }
pcall(function()
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(_level, _isEditor)
        local pv = EnsurePV()
        pcall(function() EquipRace.ReapplyAll(pv.Bodies, "LevelGameplayStarted") end)
        -- no-op unless MCM present and apply_on_load enabled:
        McmGlue.ApplyOnLoad(MCM_DEPS)
    end)
    Ext.Osiris.RegisterListener("SavegameLoaded", 0, "after", function()
        local pv = EnsurePV()
        pcall(function() EquipRace.ReapplyAll(pv.Bodies, "SavegameLoaded") end)
        McmGlue.ApplyOnLoad(MCM_DEPS)
    end)
    Log("Clothed-half re-apply listeners registered (LevelGameplayStarted/SavegameLoaded).")
end)

-- MCM bridge: live body_choice changes from the MCM UI (hard dependency as of
-- v4.7; guards still degrade to a logged no-op if MCM is missing/failed).
McmGlue.InstallServer(MCM_DEPS)

Log("BootstrapServer v4.8 loaded. Commands: !cm_setbody <vanilla|sbbf|bcb> | "
    .. "!cm_setclothed <vanilla|sbbf> | !cm_seterace <guid> | !cm_erpass [force] | !cm_erstatus | !cm_refresh | "
    .. "!cm_applyccsv <ccsvGuid> | !cm_revert | !cm_status | !cm_checkbody | !cm_findoverride")
