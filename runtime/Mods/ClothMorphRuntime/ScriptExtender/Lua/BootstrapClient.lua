-- ===========================================================================
-- ClothMorphRuntime / BootstrapClient.lua
-- ---------------------------------------------------------------------------
-- CLIENT context. Osi.* does NOT exist here. The body-override logic lives on
-- the server, so the client copies of the console commands just FORWARD the
-- player's intent to the server over the net channel. We register the SAME
-- command names here so that typing "!cm_..." works no matter which context
-- the in-game console happens to be in (client vs server).
--
-- Gotchas obeyed:
--   * Console commands invoked with leading "!" (e.g. !cm_status).
--   * No os.* / io.*  -> use Ext.* if ever needed.
--   * Ext.RegisterNetListener is deprecated -> Ext.Net.CreateChannel().
-- All ASCII.
-- ===========================================================================

local Shared  = Ext.Require("Shared.lua")
local Targeting = Ext.Require("Targeting.lua")
local McmGlue = Ext.Require("MCMIntegration.lua")  -- optional BG3MCM bridge (v4.6, 2026-07-11)

local MOD = Mods.ClothMorphRuntime

local function Log(msg)
    Ext.Utils.Print("[ClothMorphRuntime:Client] " .. tostring(msg))
end

local function Warn(msg)
    Ext.Utils.PrintWarning("[ClothMorphRuntime:Client] " .. tostring(msg))
end

-- Net channel to the server (same name/owner as the server side).
local Channel = Ext.Net.CreateChannel(MOD.ModuleUUID or "ClothMorphRuntime", "ClothMorphRuntime_Cmd")

local function ClientTarget(explicitTarget)
    local target = Targeting.NormGuid(explicitTarget)
    if target == nil then target = Targeting.GetClientControlTarget() end
    return target
end

-- Fire-and-forget request to the server. SendToServer is non-deprecated.
local function Forward(cmd, arg, target)
    local ok = pcall(function()
        Channel:SendToServer({ cmd = cmd, arg = arg, target = target })
    end)
    if not ok then
        Warn(("Forward('%s'): failed to reach server channel."):format(tostring(cmd)))
    else
        Log(("Forwarded '%s'%s%s to server (results print in the SERVER log)."):format(
            tostring(cmd),
            arg and (" arg='" .. tostring(arg) .. "'") or "",
            target and (" target=" .. tostring(target)) or ""))
    end
end

local function ForwardForTarget(cmd, arg, explicitTarget)
    local target = ClientTarget(explicitTarget)
    if target == nil then
        Warn(("!cm_%s: could not resolve your controlled character; pass a character GUID."):format(tostring(cmd)))
        return
    end
    Forward(cmd, arg, target)
end

-- !cm_setbody <vanilla|sbbf|bcb>
Ext.RegisterConsoleCommand("cm_setbody", function(_cmd, choice, charArg)
    choice = choice and tostring(choice):lower() or nil
    if not Shared.IsValidBodyChoice(choice) then
        Warn("!cm_setbody usage: !cm_setbody <vanilla|sbbf|bcb> [charGuid]")
        return
    end
    ForwardForTarget("setbody", choice, charArg)
end)

-- !cm_applyccsv <ccsvGuid>  -- apply ANY CCSV by GUID (testing)
Ext.RegisterConsoleCommand("cm_applyccsv", function(_cmd, ccsv, charArg)
    ForwardForTarget("applyccsv", ccsv, charArg)
end)

-- !cm_optout [off]  -- exclude the equipped torso item from vanilla-VR remap
-- (hybrid modded outfits keep their authored look); "off" re-enables remap.
Ext.RegisterConsoleCommand("cm_optout", function(_cmd, arg, charArg)
    ForwardForTarget("optout", arg, charArg)
end)

-- !cm_revert  -- strip our override, back to original body
Ext.RegisterConsoleCommand("cm_revert", function(_cmd, charArg)
    ForwardForTarget("revert", nil, charArg)
end)

-- !cm_status
Ext.RegisterConsoleCommand("cm_status", function(_cmd, charArg)
    ForwardForTarget("status", nil, charArg)
end)

-- !cm_checkbody [ccsvGuid]   -- diagnostic; results print in the SERVER log
Ext.RegisterConsoleCommand("cm_checkbody", function(_cmd, ccsvArg, charArg)
    ForwardForTarget("checkbody", ccsvArg, charArg)
end)

-- !cm_slotcheck  -- diagnostic: dump equipment slots (results in SERVER log)
Ext.RegisterConsoleCommand("cm_slotcheck", function(_cmd, charArg)
    ForwardForTarget("slotcheck", nil, charArg)
end)

-- !cm_reconcile  -- re-run the clothed/nude toggle (results in SERVER log)
Ext.RegisterConsoleCommand("cm_reconcile", function(_cmd, charArg)
    ForwardForTarget("reconcile", nil, charArg)
end)

-- ---------------------------------------------------------------------------
-- EquipmentRace clothed-half commands (v4) -- forwarded to the server.
-- ---------------------------------------------------------------------------
-- !cm_setclothed <vanilla|sbbf>  -- flip ONLY the clothed half (testing)
Ext.RegisterConsoleCommand("cm_setclothed", function(_cmd, choice, charArg)
    choice = choice and tostring(choice):lower() or nil
    if choice ~= "vanilla" and choice ~= "sbbf" then
        Warn("!cm_setclothed usage: !cm_setclothed <vanilla|sbbf> [charGuid]")
        return
    end
    ForwardForTarget("setclothed", choice, charArg)
end)

-- !cm_erpass [force]  -- run the blanket shared-mesh injection pass
Ext.RegisterConsoleCommand("cm_erpass", function(_cmd, forceArg)
    Forward("erpass", forceArg)
end)

-- !cm_erstatus  -- clothed-half diagnostics (results in SERVER log)
Ext.RegisterConsoleCommand("cm_erstatus", function(_cmd, charArg)
    ForwardForTarget("erstatus", nil, charArg)
end)

-- !cm_refresh  -- unequip/re-equip visual slots to force re-render
Ext.RegisterConsoleCommand("cm_refresh", function(_cmd, charArg)
    ForwardForTarget("refresh", nil, charArg)
end)

-- !cm_seterace <equipmentRaceGuid>  -- manual EquipmentRace recovery (server)
Ext.RegisterConsoleCommand("cm_seterace", function(_cmd, guid, charArg)
    if not guid or guid == "" then
        Warn("!cm_seterace <equipmentRaceGuid> [charGuid]")
        return
    end
    ForwardForTarget("seterace", guid, charArg)
end)

-- !cm_findoverride <charGuid> <searchGuid>
--   LOCAL (not forwarded): scans the CLIENT-side components of the entity for
--   searchGuid, so we can find where a visual override is stored on the client.
--   charGuid is REQUIRED here (no Osi in client context to resolve the host).
--   Run the SERVER copy too (!cm_findoverride with no charGuid uses the host).
Ext.RegisterConsoleCommand("cm_findoverride", function(_cmd, charArg, guidArg)
    if not charArg or charArg == "" then
        Warn("!cm_findoverride <charGuid> <searchGuid> -- charGuid REQUIRED in client context")
        return
    end
    local e = Ext.Entity.Get(charArg)
    Log(("---- cm_findoverride (client) char=%s search=%s ----"):format(tostring(charArg), tostring(guidArg)))
    local _, names = Shared.FindOverride(e, guidArg, function(m) Log(m) end)
    if names then
        Log(("All components (%d):"):format(#names))
        for _, n in ipairs(names) do Log("  comp: " .. tostring(n)) end
    end
    Log("--------------------------------------------------------")
end)

-- ---------------------------------------------------------------------------
-- !cm_visdump [charGuid]
--   LOCAL (not forwarded): walks the CLIENT-side rendered visual tree of the
--   character -- root Visual, every Attachment, every ObjectDesc -- printing
--   each VisualResource id, source GR2 (when resolvable) and material. Purpose:
--   name the exact mesh that draws unexplained geometry (AoP nipple hunt).
--   charGuid optional: without it we try the ClientControl entity.
--   Everything is pcall-guarded; unknown fields print as "?" instead of erroring.
-- ---------------------------------------------------------------------------
local function VD_get(o, k)
    if o == nil then return nil end
    local ok, v = pcall(function() return o[k] end)
    if ok then return v end
    return nil
end

local function VD_gid(x)
    if x == nil then return "nil" end
    local g = VD_get(x, "Guid")
    if g ~= nil then return tostring(g) end
    return tostring(x)
end

-- Resolve a VisualResource id -> its Name + SourceFile via the resource bank.
local function VD_resinfo(vrId)
    local name, src = "?", "?"
    pcall(function()
        local r = Ext.Resource.Get(vrId, "Visual")
        if r then
            name = tostring(VD_get(r, "Name") or "?")
            src  = tostring(VD_get(r, "SourceFile") or "?")
        end
    end)
    return name, src
end

local function VD_objdescs(vis, indent)
    local ods = VD_get(vis, "ObjectDescs")
    if ods == nil then return end
    local n = 0
    pcall(function() n = #ods end)
    for j = 1, n do
        local od = ods[j]
        local rend = VD_get(od, "Renderable")
        local am   = VD_get(rend, "ActiveMaterial")
        local mat  = VD_get(am, "MaterialName")
        if mat == nil then
            local m = VD_get(am, "Material")
            mat = VD_get(m, "Name")
        end
        Log(("%s  obj[%d] renderable=%s material=%s"):format(
            indent, j, tostring(rend ~= nil), tostring(mat)))
    end
end

local function VD_dumpVisual(vis, label, indent, depth)
    if vis == nil then Log(indent .. label .. " = nil"); return end
    local vrId = VD_gid(VD_get(vis, "VisualResource"))
    local name, src = VD_resinfo(vrId)
    Log(("%s%s VR=%s name=%s"):format(indent, label, vrId, name))
    if src ~= "?" then Log(indent .. "  src=" .. src) end
    VD_objdescs(vis, indent)
    if depth <= 0 then return end
    local atts = VD_get(vis, "Attachments")
    if atts == nil then return end
    local n = 0
    pcall(function() n = #atts end)
    for i = 1, n do
        local att = atts[i]
        local bone = tostring(VD_get(att, "Bone") or VD_get(att, "BoneName") or "?")
        VD_dumpVisual(VD_get(att, "Visual"),
            ("att[%d] bone=%s"):format(i, bone), indent .. "  ", depth - 1)
    end
end

Ext.RegisterConsoleCommand("cm_visdump", function(_cmd, charArg)
    local e
    if charArg and charArg ~= "" then
        e = Ext.Entity.Get(charArg)
    else
        -- fallback: the entity the client controls
        pcall(function()
            local list = Ext.Entity.GetAllEntitiesWithComponent("ClientControl")
            for _, cand in ipairs(list or {}) do
                if VD_get(cand, "CharacterCreationAppearance") ~= nil then e = cand; break end
            end
            if e == nil and list and list[1] then e = list[1] end
        end)
    end
    if e == nil then
        Warn("!cm_visdump [charGuid] -- could not resolve entity (pass your char guid)")
        return
    end
    Log("==== cm_visdump ====")
    local visComp = VD_get(e, "Visual")
    VD_dumpVisual(VD_get(visComp, "Visual"), "root", "", 3)
    Log("==== end cm_visdump ====")
end)

-- Optional MCM bridge: MCM's UI runs client-side; forward body_choice changes
-- to the server over the existing command channel (server dedupes vs its own
-- event subscription, so double delivery is harmless).
McmGlue.InstallClient({ Log = Log, Warn = Warn,
                        IsValid = Shared.IsValidBodyChoice, Forward = ForwardForTarget })

Log("BootstrapClient v4.7 loaded. Commands (forward to server): "
    .. "!cm_setbody !cm_setclothed !cm_seterace !cm_erpass !cm_erstatus !cm_refresh "
    .. "!cm_applyccsv !cm_revert !cm_status !cm_checkbody ; "
    .. "!cm_findoverride !cm_visdump (local client scans)")
