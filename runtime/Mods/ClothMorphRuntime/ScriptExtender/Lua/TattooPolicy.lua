-- ClothMorphRuntime / TattooPolicy.lua
-- Pure HUM_F tattoo-material policy. This module selects only a prebuilt
-- VisualResource/CCSV pair; it never reads or writes a character.

local M = {}

-- BG3SE requires Ext.Require during module startup. Retain the returned module
-- so console-time !cm_tattootest never needs a current-mod loading context.
local SelfTest
if Ext ~= nil and type(Ext.Require) == "function" then
    SelfTest = Ext.Require("TattooPolicySelfTest.lua")
else
    SelfTest = require("TattooPolicySelfTest")
end

local KAVT_UUID = "4cb0fd40-7212-4fe9-8733-9a8dbc6637ae"

local HUM_F_RACES = {
    ["0eb594cb-8820-4be6-a58d-8be7a1a98fba"] = true,
    ["6c038dcb-7eb5-431d-84f8-cecfaf1c0c5a"] = true,
    ["45f4ac10-3c89-4fb2-b37d-f973bb9110c0"] = true,
    ["4f5d1434-5175-4fa9-b7dc-ab24fba37929"] = true,
    ["c5f8ebdd-f4a5-4d2d-9eab-4a8d1b1dd724"] = true,
    ["4d30b4f9-7bb2-4fc2-a7bc-080f116e325a"] = true,
    ["e966f47f-998a-41df-ad86-d83b44299efb"] = true,
}

-- Every row is a matched pair. Availability checks validate both members so
-- Resolve and ResolveCcsv cannot choose different fallback variants.
local VARIANTS = {
    ["sbbf|none|match"] = { vr = "672a9c38-ba20-4872-a072-ba7f23f58f06", ccsv = "a22009cd-b9e9-55b1-8295-f89a0ede1bf6" },
    ["sbbf|none|hide"] = { vr = "07abdc8d-38a9-567e-ad49-06ef524410e4", ccsv = "d51dd1ab-2f74-5389-8c06-98c7e7f98854" },
    ["sbbf|kavt_vt|match"] = { vr = "d4f7c24b-2db1-5a7b-9efa-90e192116377", ccsv = "d711f7ca-30b6-5b9b-9e9f-537ab9af8cd7" },
    ["sbbf|kavt_vt|hide"] = { vr = "70ff0599-08f3-5f69-9a52-fdd6b6e949a1", ccsv = "e3643939-b718-50b4-be1f-849ca54c2f68" },
    ["sbbf|kavt_nvt|match"] = { vr = "a1bf2bef-d41b-5953-8a0a-6285a41b62e4", ccsv = "70971573-07de-5071-8a86-1f65b71a71e7" },
    ["sbbf|kavt_nvt|hide"] = { vr = "ecc64f43-99dc-5706-ba04-1158391257e0", ccsv = "9a07df63-f3a7-516f-b209-d2e26c35ef14" },
    ["sbbf|kavt_unknown|match"] = { vr = "f5ea4731-c402-5548-ac5b-2b79f11c6b17", ccsv = "63a631a5-6765-5ef9-befb-85e5a8e8e87d" },
    ["sbbf|kavt_unknown|hide"] = { vr = "f5ea4731-c402-5548-ac5b-2b79f11c6b17", ccsv = "63a631a5-6765-5ef9-befb-85e5a8e8e87d" },
    ["bcb|none|match"] = { vr = "74131131-2167-5e3c-a9d1-e6f18cab4ee5", ccsv = "fe01f8f7-814e-5c2e-9829-a0467fd5a6ce" },
    ["bcb|none|hide"] = { vr = "5d74e497-f089-51e6-9275-ee0d9232a144", ccsv = "866d7b74-ab5c-5690-8bc6-314c86bc3750" },
    ["bcb|kavt_vt|match"] = { vr = "e34429bf-b0d5-5a3b-af8e-3d4e38bf004c", ccsv = "8fad947b-075c-53df-b887-e786bb4b2f3f" },
    ["bcb|kavt_vt|hide"] = { vr = "051703e5-669c-57f3-859f-ab06101e415b", ccsv = "543d0b1a-72f9-5458-8b55-abe3161ebbf4" },
    ["bcb|kavt_nvt|match"] = { vr = "c708499a-3482-5299-8231-ee4eba09f5d9", ccsv = "5b351a42-516b-520a-8493-2e3be97f926f" },
    ["bcb|kavt_nvt|hide"] = { vr = "43cbec32-9f3a-5309-8616-b26c143da176", ccsv = "3b4fc8f9-8ce2-583f-8835-4117935e2b49" },
    ["bcb|kavt_unknown|match"] = { vr = "caea64ea-6079-5bf5-a84d-feb2f7535e94", ccsv = "61bcdb4f-b05c-52a3-ab21-64ef788331b5" },
    ["bcb|kavt_unknown|hide"] = { vr = "caea64ea-6079-5bf5-a84d-feb2f7535e94", ccsv = "61bcdb4f-b05c-52a3-ab21-64ef788331b5" },
}

local VALID_ENVIRONMENTS = {
    none = true,
    kavt_vt = true,
    kavt_nvt = true,
    kavt_unknown = true,
}

local function lower(value)
    return tostring(value or ""):lower()
end

local function key(bodyChoice, environment, policy)
    return bodyChoice .. "|" .. environment .. "|" .. policy
end

local function rowAvailable(row, resourceExists)
    if row == nil or type(resourceExists) ~= "function" then return false end
    local okVr, hasVr = pcall(resourceExists, row.vr, "vr")
    local okCcsv, hasCcsv = pcall(resourceExists, row.ccsv, "ccsv")
    return okVr and okCcsv and hasVr == true and hasCcsv == true
end

function M.Normalize(value)
    if value == "hide" then return "hide" end
    return "match"
end

function M.IsHumF(race, bodyType, bodyShape)
    if tostring(bodyType) ~= "1" then return false end
    if tostring(bodyShape) ~= "0" then return false end
    return HUM_F_RACES[lower(race)] == true
end

function M.DetectEnvironment(getLoadedMod)
    local loaded = nil
    if type(getLoadedMod) == "function" then
        local ok, value = pcall(getLoadedMod, KAVT_UUID)
        if ok then loaded = value end
    end
    if loaded == nil or loaded == false then return "none" end
    local name = ""
    pcall(function() name = tostring((loaded.Info and loaded.Info.Name) or loaded.Name or ""):upper() end)
    if name:find("NVP", 1, true) then return "kavt_nvt" end
    if name:find("KAVT", 1, true) or name:find("VIRTUAL TAV", 1, true) then return "kavt_vt" end
    return "kavt_unknown"
end

local function resolveKind(kind, bodyChoice, race, bodyType, bodyShape, policy, environment, resourceExists)
    local body = lower(bodyChoice)
    if body == "vanilla" then return nil, "vanilla-unmodified" end
    if (body ~= "sbbf" and body ~= "bcb") or not M.IsHumF(race, bodyType, bodyShape) then
        return nil, "out-of-scope"
    end

    local normalized = M.Normalize(policy)
    local env = lower(environment)
    if VALID_ENVIRONMENTS[env] ~= true then env = "none" end
    local primary = VARIANTS[key(body, env, normalized)]

    if env == "kavt_unknown" and normalized == "hide" and rowAvailable(primary, resourceExists) then
        return primary[kind], "fail-open:unknown-kavt-hide-to-match"
    end
    if rowAvailable(primary, resourceExists) then
        return primary[kind], "selected-primary:" .. env .. ":" .. normalized
    end

    local envMatch = VARIANTS[key(body, env, "match")]
    if normalized == "hide" and rowAvailable(envMatch, resourceExists) then
        return envMatch[kind], "fail-open:missing-hide-to-match"
    end

    local stockMatch = VARIANTS[key(body, "none", "match")]
    if env ~= "none" and rowAvailable(stockMatch, resourceExists) then
        return stockMatch[kind], "fail-open:missing-kavt-match-to-stock"
    end
    return nil, "unavailable:stock-match"
end

function M.Resolve(bodyChoice, race, bodyType, bodyShape, policy, environment, resourceExists)
    return resolveKind("vr", bodyChoice, race, bodyType, bodyShape, policy, environment, resourceExists)
end

function M.ResolveCcsv(bodyChoice, race, bodyType, bodyShape, policy, environment, resourceExists)
    return resolveKind("ccsv", bodyChoice, race, bodyType, bodyShape, policy, environment, resourceExists)
end

function M.DescribeVariants()
    local rows = {}
    for variantKey, row in pairs(VARIANTS) do
        local bodyChoice, environment, policy = variantKey:match("^([^|]+)|([^|]+)|([^|]+)$")
        rows[#rows + 1] = {
            key = variantKey,
            bodyChoice = bodyChoice,
            environment = environment,
            policy = policy,
            vr = row.vr,
            ccsv = row.ccsv,
        }
    end
    table.sort(rows, function(a, b) return a.key < b.key end)
    return rows
end

function M.RunSelfTest()
    return SelfTest.Run(M)
end

return M
