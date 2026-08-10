-- ClothMorphRuntime / TattooPolicySelfTest.lua
-- Executed in BG3SE by !cm_tattootest. Expected values are independent literal
-- vectors rather than values read from TattooPolicy's production table.

local M = {}

local RACE = "0eb594cb-8820-4be6-a58d-8be7a1a98fba"
local GITH = "bdf9b779-002c-4077-b377-8ea7c1faa795"
local HUM_F_RACES = {
    "0eb594cb-8820-4be6-a58d-8be7a1a98fba",
    "6c038dcb-7eb5-431d-84f8-cecfaf1c0c5a",
    "45f4ac10-3c89-4fb2-b37d-f973bb9110c0",
    "4f5d1434-5175-4fa9-b7dc-ab24fba37929",
    "c5f8ebdd-f4a5-4d2d-9eab-4a8d1b1dd724",
    "4d30b4f9-7bb2-4fc2-a7bc-080f116e325a",
    "e966f47f-998a-41df-ad86-d83b44299efb",
}

local EXPECTED = {
    { body = "sbbf", environment = "none", policy = "match", vr = "672a9c38-ba20-4872-a072-ba7f23f58f06", ccsv = "a22009cd-b9e9-55b1-8295-f89a0ede1bf6" },
    { body = "sbbf", environment = "none", policy = "hide", vr = "07abdc8d-38a9-567e-ad49-06ef524410e4", ccsv = "d51dd1ab-2f74-5389-8c06-98c7e7f98854" },
    { body = "sbbf", environment = "kavt_vt", policy = "match", vr = "d4f7c24b-2db1-5a7b-9efa-90e192116377", ccsv = "d711f7ca-30b6-5b9b-9e9f-537ab9af8cd7" },
    { body = "sbbf", environment = "kavt_vt", policy = "hide", vr = "70ff0599-08f3-5f69-9a52-fdd6b6e949a1", ccsv = "e3643939-b718-50b4-be1f-849ca54c2f68" },
    { body = "sbbf", environment = "kavt_nvt", policy = "match", vr = "a1bf2bef-d41b-5953-8a0a-6285a41b62e4", ccsv = "70971573-07de-5071-8a86-1f65b71a71e7" },
    { body = "sbbf", environment = "kavt_nvt", policy = "hide", vr = "ecc64f43-99dc-5706-ba04-1158391257e0", ccsv = "9a07df63-f3a7-516f-b209-d2e26c35ef14" },
    { body = "sbbf", environment = "kavt_unknown", policy = "match", vr = "f5ea4731-c402-5548-ac5b-2b79f11c6b17", ccsv = "63a631a5-6765-5ef9-befb-85e5a8e8e87d" },
    { body = "sbbf", environment = "kavt_unknown", policy = "hide", vr = "f5ea4731-c402-5548-ac5b-2b79f11c6b17", ccsv = "63a631a5-6765-5ef9-befb-85e5a8e8e87d" },
    { body = "bcb", environment = "none", policy = "match", vr = "74131131-2167-5e3c-a9d1-e6f18cab4ee5", ccsv = "fe01f8f7-814e-5c2e-9829-a0467fd5a6ce" },
    { body = "bcb", environment = "none", policy = "hide", vr = "5d74e497-f089-51e6-9275-ee0d9232a144", ccsv = "866d7b74-ab5c-5690-8bc6-314c86bc3750" },
    { body = "bcb", environment = "kavt_vt", policy = "match", vr = "e34429bf-b0d5-5a3b-af8e-3d4e38bf004c", ccsv = "8fad947b-075c-53df-b887-e786bb4b2f3f" },
    { body = "bcb", environment = "kavt_vt", policy = "hide", vr = "051703e5-669c-57f3-859f-ab06101e415b", ccsv = "543d0b1a-72f9-5458-8b55-abe3161ebbf4" },
    { body = "bcb", environment = "kavt_nvt", policy = "match", vr = "c708499a-3482-5299-8231-ee4eba09f5d9", ccsv = "5b351a42-516b-520a-8493-2e3be97f926f" },
    { body = "bcb", environment = "kavt_nvt", policy = "hide", vr = "43cbec32-9f3a-5309-8616-b26c143da176", ccsv = "3b4fc8f9-8ce2-583f-8835-4117935e2b49" },
    { body = "bcb", environment = "kavt_unknown", policy = "match", vr = "caea64ea-6079-5bf5-a84d-feb2f7535e94", ccsv = "61bcdb4f-b05c-52a3-ab21-64ef788331b5" },
    { body = "bcb", environment = "kavt_unknown", policy = "hide", vr = "caea64ea-6079-5bf5-a84d-feb2f7535e94", ccsv = "61bcdb4f-b05c-52a3-ab21-64ef788331b5" },
}

local function resourceStub(missing)
    local absent = missing or {}
    return function(guid, _kind) return absent[tostring(guid)] ~= true end
end

function M.Run(policy)
    local failures = {}
    local function check(name, actual, expected)
        if actual ~= expected then
            failures[#failures + 1] = name .. ": expected=" .. tostring(expected) .. " actual=" .. tostring(actual)
        end
    end
    local function edge(name, fn)
        local ok, err = pcall(fn)
        if not ok then failures[#failures + 1] = name .. ": " .. tostring(err) end
    end
    local exists = resourceStub()

    for i, vector in ipairs(EXPECTED) do
        local vr = policy.Resolve(vector.body, RACE, 1, 0, vector.policy, vector.environment, exists)
        local ccsv = policy.ResolveCcsv(vector.body, RACE, 1, 0, vector.policy, vector.environment, exists)
        check("table-vr-" .. tostring(i), vr, vector.vr)
        check("table-ccsv-" .. tostring(i), ccsv, vector.ccsv)
    end

    for _, race in ipairs(HUM_F_RACES) do
        check("hum-f-" .. race, policy.IsHumF(race, 1, 0), true)
        check("hum-f-wrong-type-" .. race, policy.IsHumF(race, 0, 0), false)
        check("hum-f-wrong-shape-" .. race, policy.IsHumF(race, 1, 1), false)
        for i, vector in ipairs(EXPECTED) do
            local vr = policy.Resolve(vector.body, race, 1, 0, vector.policy, vector.environment, exists)
            local ccsv = policy.ResolveCcsv(vector.body, race, 1, 0, vector.policy, vector.environment, exists)
            check("race-table-vr-" .. race .. "-" .. tostring(i), vr, vector.vr)
            check("race-table-ccsv-" .. race .. "-" .. tostring(i), ccsv, vector.ccsv)
        end
    end
    check("environment-none", policy.DetectEnvironment(function() return nil end), "none")
    check("environment-nvp-priority", policy.DetectEnvironment(function()
        return { Info = { Name = "KAVT NVP - Virtual Tav" } }
    end), "kavt_nvt")
    check("environment-vt-kavt", policy.DetectEnvironment(function()
        return { Info = { Name = "KAVT - Kazstra's Virtual Tav" } }
    end), "kavt_vt")
    check("environment-vt-long-name", policy.DetectEnvironment(function()
        return { Info = { Name = "Kazstra's Virtual Tav" } }
    end), "kavt_vt")
    check("environment-unknown", policy.DetectEnvironment(function()
        return { Info = { Name = "renamed package" } }
    end), "kavt_unknown")

    edge("invalid-policy-match", function()
        check("uppercase-policy", policy.Normalize("HIDE"), "match")
        check("invalid-policy", policy.Resolve("sbbf", RACE, 1, 0, "invalid", "none", exists), "672a9c38-ba20-4872-a072-ba7f23f58f06")
    end)
    edge("vanilla-unmodified", function()
        local value, reason = policy.Resolve("vanilla", RACE, 1, 0, "hide", "kavt_vt", exists)
        check("vanilla-value", value, nil); check("vanilla-reason", reason, "vanilla-unmodified")
    end)
    edge("gith-out-of-scope", function()
        local value, reason = policy.Resolve("sbbf", GITH, 1, 0, "match", "none", exists)
        check("gith-value", value, nil); check("gith-reason", reason, "out-of-scope")
    end)
    edge("wrong-body-tuple-out-of-scope", function()
        local value, reason = policy.Resolve("bcb", RACE, 1, 1, "match", "none", exists)
        check("tuple-value", value, nil); check("tuple-reason", reason, "out-of-scope")
    end)
    edge("unknown-kavt-hide-match", function()
        local value, reason = policy.Resolve("sbbf", RACE, 1, 0, "hide", "kavt_unknown", exists)
        check("unknown-value", value, "f5ea4731-c402-5548-ac5b-2b79f11c6b17")
        check("unknown-reason", reason, "fail-open:unknown-kavt-hide-to-match")
    end)
    edge("missing-hide-environment-match-vr", function()
        local value, reason = policy.Resolve("sbbf", RACE, 1, 0, "hide", "kavt_vt", resourceStub({ ["70ff0599-08f3-5f69-9a52-fdd6b6e949a1"] = true }))
        check("hide-vr-value", value, "d4f7c24b-2db1-5a7b-9efa-90e192116377")
        check("hide-vr-reason", reason, "fail-open:missing-hide-to-match")
    end)
    edge("missing-hide-environment-match-ccsv", function()
        local value, reason = policy.ResolveCcsv("bcb", RACE, 1, 0, "hide", "kavt_nvt", resourceStub({ ["3b4fc8f9-8ce2-583f-8835-4117935e2b49"] = true }))
        check("hide-ccsv-value", value, "5b351a42-516b-520a-8493-2e3be97f926f")
        check("hide-ccsv-reason", reason, "fail-open:missing-hide-to-match")
    end)
    edge("missing-kavt-match-stock-vr", function()
        local value, reason = policy.Resolve("bcb", RACE, 1, 0, "match", "kavt_vt", resourceStub({ ["e34429bf-b0d5-5a3b-af8e-3d4e38bf004c"] = true }))
        check("kavt-vr-value", value, "74131131-2167-5e3c-a9d1-e6f18cab4ee5")
        check("kavt-vr-reason", reason, "fail-open:missing-kavt-match-to-stock")
    end)
    edge("missing-kavt-match-stock-ccsv", function()
        local value, reason = policy.ResolveCcsv("sbbf", RACE, 1, 0, "match", "kavt_nvt", resourceStub({ ["70971573-07de-5071-8a86-1f65b71a71e7"] = true }))
        check("kavt-ccsv-value", value, "a22009cd-b9e9-55b1-8295-f89a0ede1bf6")
        check("kavt-ccsv-reason", reason, "fail-open:missing-kavt-match-to-stock")
    end)
    edge("missing-stock-nil-vr", function()
        local missing = resourceStub({ ["672a9c38-ba20-4872-a072-ba7f23f58f06"] = true })
        local vr, vrReason = policy.Resolve("sbbf", RACE, 1, 0, "match", "none", missing)
        local ccsv, ccsvReason = policy.ResolveCcsv("sbbf", RACE, 1, 0, "match", "none", missing)
        check("stock-vr-missing-vr", vr, nil); check("stock-vr-missing-ccsv", ccsv, nil)
        check("stock-vr-missing-vr-reason", vrReason, "unavailable:stock-match")
        check("stock-vr-missing-ccsv-reason", ccsvReason, "unavailable:stock-match")
    end)
    edge("missing-stock-nil-ccsv", function()
        local missing = resourceStub({ ["fe01f8f7-814e-5c2e-9829-a0467fd5a6ce"] = true })
        local vr, vrReason = policy.Resolve("bcb", RACE, 1, 0, "match", "none", missing)
        local ccsv, ccsvReason = policy.ResolveCcsv("bcb", RACE, 1, 0, "match", "none", missing)
        check("stock-ccsv-missing-vr", vr, nil); check("stock-ccsv-missing-ccsv", ccsv, nil)
        check("stock-ccsv-missing-vr-reason", vrReason, "unavailable:stock-match")
        check("stock-ccsv-missing-ccsv-reason", ccsvReason, "unavailable:stock-match")
    end)
    edge("missing-stock-pair-nil", function()
        local missing = resourceStub({
            ["672a9c38-ba20-4872-a072-ba7f23f58f06"] = true,
            ["a22009cd-b9e9-55b1-8295-f89a0ede1bf6"] = true,
        })
        local vr, vrReason = policy.Resolve("sbbf", RACE, 1, 0, "match", "none", missing)
        local ccsv, ccsvReason = policy.ResolveCcsv("sbbf", RACE, 1, 0, "match", "none", missing)
        check("stock-pair-vr", vr, nil); check("stock-pair-ccsv", ccsv, nil)
        check("stock-pair-vr-reason", vrReason, "unavailable:stock-match")
        check("stock-pair-ccsv-reason", ccsvReason, "unavailable:stock-match")
    end)
    edge("exhausted-hide-kavt-stock-nil", function()
        local missing = resourceStub({
            ["70ff0599-08f3-5f69-9a52-fdd6b6e949a1"] = true,
            ["e3643939-b718-50b4-be1f-849ca54c2f68"] = true,
            ["d4f7c24b-2db1-5a7b-9efa-90e192116377"] = true,
            ["d711f7ca-30b6-5b9b-9e9f-537ab9af8cd7"] = true,
            ["672a9c38-ba20-4872-a072-ba7f23f58f06"] = true,
            ["a22009cd-b9e9-55b1-8295-f89a0ede1bf6"] = true,
        })
        local vr, vrReason = policy.Resolve("sbbf", RACE, 1, 0, "hide", "kavt_vt", missing)
        local ccsv, ccsvReason = policy.ResolveCcsv("sbbf", RACE, 1, 0, "hide", "kavt_vt", missing)
        check("exhausted-vr", vr, nil); check("exhausted-ccsv", ccsv, nil)
        check("exhausted-vr-reason", vrReason, "unavailable:stock-match")
        check("exhausted-ccsv-reason", ccsvReason, "unavailable:stock-match")
    end)
    edge("no-empty-guid", function()
        local never = function() return false end
        local vr, vrReason = policy.Resolve("sbbf", RACE, 1, 0, "hide", "kavt_vt", never)
        local ccsv, ccsvReason = policy.ResolveCcsv("sbbf", RACE, 1, 0, "hide", "kavt_vt", never)
        check("no-empty-vr", vr == "", false); check("no-empty-ccsv", ccsv == "", false)
        check("no-resource-vr", vr, nil); check("no-resource-ccsv", ccsv, nil)
        check("no-resource-vr-reason", vrReason, "unavailable:stock-match")
        check("no-resource-ccsv-reason", ccsvReason, "unavailable:stock-match")
    end)

    return #failures == 0, failures
end

return M
