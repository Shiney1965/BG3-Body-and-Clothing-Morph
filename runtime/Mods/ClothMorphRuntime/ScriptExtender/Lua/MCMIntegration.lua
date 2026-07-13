-- MCMIntegration.lua -- optional BG3MCM (Mod Configuration Menu, Nexus 9162)
-- bridge for ClothMorphRuntime. v4.6, 2026-07-11.
--
-- MCM is a HARD dependency as of v4.7 (Alan's decision 2026-07-11: SE-console
-- users always have MCM): declared in meta.lsx Dependencies; the blueprint no
-- longer sets "Optional". The McmPresent() guards below are kept as defensive
-- coding so a missing/failed MCM still degrades to a logged no-op instead of
-- a bootstrap error.
--
-- Wiring (see BootstrapServer.lua / BootstrapClient.lua):
--   * CLIENT: InstallClient{} subscribes to Ext.ModEvents.BG3MCM
--     ["MCM_Setting_Saved"] and FORWARDS body_choice over the existing
--     ClothMorphRuntime_Cmd net channel with the controlled character target.
--   * SERVER: InstallServer{} also subscribes defensively, but it does not
--     apply contextless MCM events unless a target can be resolved. The net
--     path remains authoritative because DispatchNetCmd validates the sending
--     user against the requested character.
--   * ApplyOnLoad{} no longer falls back to the host character. It only applies
--     if a caller supplies an explicit safe target resolver.
--
-- MCM API facts used here (wiki.bg3.community "Mod Configuration Menu"):
--   MCM.Get("settingId") reads a value; Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]
--   fires with payload { modUUID, settingId, value }; filter on ModuleUUID.

local M = {}

local SETTING_BODY  = "body_choice"
local SETTING_APPLY = "apply_on_load"
local DEDUPE_MS     = 1500

local last = { value = nil, t = 0 }

local function Now()
    local ok, t = pcall(Ext.Utils.MonotonicTime)
    return ok and t or 0
end

-- MCM stores the radio label ("Vanilla"/"SBBF"/"BCB"); runtime wants lowercase.
local function ToChoice(v)
    if v == nil then return nil end
    return tostring(v):lower()
end

local function McmPresent()
    local ok, present = pcall(function()
        return Ext.ModEvents ~= nil and Ext.ModEvents.BG3MCM ~= nil
    end)
    return ok and present == true
end

-- deps: { Log, Warn, IsValid(choice)->bool, Apply(choice) }
local function Subscribe(deps, tag)
    local ok, err = pcall(function()
        Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
            if not payload or payload.modUUID ~= ModuleUUID then return end
            if payload.settingId ~= SETTING_BODY then return end
            local choice = ToChoice(payload.value)
            if not deps.IsValid(choice) then
                deps.Warn(("MCM[%s]: ignoring invalid body_choice '%s'"):format(tag, tostring(payload.value)))
                return
            end
            deps.Apply(choice, payload)
        end)
    end)
    if ok then
        deps.Log(("MCM[%s]: integration active (listening for %s)."):format(tag, SETTING_BODY))
    else
        deps.Warn(("MCM[%s]: subscribe failed: %s"):format(tag, tostring(err)))
    end
end

-- SERVER ---------------------------------------------------------------
-- deps: { Log, Warn, IsValid, ResolveMcmTarget?, SetDesiredBody }
function M.InstallServer(deps)
    if not McmPresent() then
        deps.Log("MCM not detected; MCM integration idle (mod fully usable via !cm_setbody).")
        return
    end
    Subscribe({
        Log = deps.Log, Warn = deps.Warn, IsValid = deps.IsValid,
        Apply = function(choice)
            local char = nil
            if deps.ResolveMcmTarget ~= nil then
                char = deps.ResolveMcmTarget(payload)
            end
            if not char then
                deps.Warn("MCM(server): setting event has no validated character target; waiting for client-forwarded event.")
                return
            end
            local t = Now()
            if last.value == choice and (t - last.t) < DEDUPE_MS then return end
            deps.Log(("MCM(server): body_choice -> '%s' (%s)"):format(choice, tostring(char)))
            deps.SetDesiredBody(char, choice)
            last.value, last.t = choice, t
        end,
    }, "S")
end

-- Server-side net-path apply with the SAME dedupe. This is the multiplayer-safe
-- MCM path: DispatchNetCmd validates data.target against the sending user before
-- this function mutates the character.
-- Returns true if applied, false if deduped/invalid.
function M.NetApply(deps, choice, target)
    choice = ToChoice(choice)
    if not deps.IsValid(choice) then return false end
    local char = target
    if char == nil and deps.ResolveMcmTarget ~= nil then
        char = deps.ResolveMcmTarget()
    end
    if not char then deps.Warn("MCM(net): no validated character target."); return false end
    local t = Now()
    if last.value == choice and (t - last.t) < DEDUPE_MS then return false end
    deps.Log(("MCM(net): body_choice -> '%s' (%s)"):format(choice, tostring(char)))
    deps.SetDesiredBody(char, choice)
    last.value, last.t = choice, t
    return true
end

-- CLIENT ---------------------------------------------------------------
-- deps: { Log, Warn, IsValid, Forward(cmd, arg) }
function M.InstallClient(deps)
    if not McmPresent() then
        deps.Log("MCM not detected; MCM integration idle.")
        return
    end
    Subscribe({
        Log = deps.Log, Warn = deps.Warn, IsValid = deps.IsValid,
        Apply = function(choice) deps.Forward("mcm_setbody", choice) end,
    }, "C")
end

-- APPLY-ON-LOAD (server) -------------------------------------------------
-- deps: { Log, Warn, IsValid, ResolveMcmTarget?, SetDesiredBody }
function M.ApplyOnLoad(deps)
    pcall(function()
        if not McmPresent() then return end
        if type(MCM) ~= "table" or type(MCM.Get) ~= "function" then return end
        if MCM.Get(SETTING_APPLY) ~= true then return end
        local choice = ToChoice(MCM.Get(SETTING_BODY))
        if not deps.IsValid(choice) then return end
        local char = nil
        if deps.ResolveMcmTarget ~= nil then char = deps.ResolveMcmTarget() end
        if not char then return end
        deps.Log(("MCM: apply_on_load -> re-applying '%s' to %s"):format(choice, tostring(char)))
        deps.SetDesiredBody(char, choice)
    end)
end

return M
