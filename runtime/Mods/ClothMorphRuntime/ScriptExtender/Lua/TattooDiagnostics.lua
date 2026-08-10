-- ClothMorphRuntime / TattooDiagnostics.lua
-- Focused registration adapter for the pure tattoo self-test and state probe.

local M = {}

function M.Register(deps)
    local function tattooTest()
        local ok, failures = deps.policy.RunSelfTest()
        local count = type(failures) == "table" and #failures or 0
        if ok then
            deps.log(("cm_tattootest: PASS (%d failure(s))"):format(count))
        else
            deps.warn(("cm_tattootest: FAIL (%d failure(s))"):format(count))
            for i, failure in ipairs(failures or {}) do
                deps.warn(("  %d: %s"):format(i, tostring(failure)))
            end
        end
    end

    local function tattooDump(_cmd, charArg)
        local char = deps.resolveCharacter(charArg)
        if char == nil then
            deps.warn("!cm_tattoodump [character-guid] -- no character target")
            return
        end
        local report = deps.probe.Capture(char, deps.makeProbeDeps())
        for _, line in ipairs(deps.probe.Format(report)) do deps.log(line) end
    end

    deps.register("cm_tattootest", tattooTest)
    deps.register("cm_tattoodump", tattooDump)
    return { cm_tattootest = tattooTest, cm_tattoodump = tattooDump }
end

return M
