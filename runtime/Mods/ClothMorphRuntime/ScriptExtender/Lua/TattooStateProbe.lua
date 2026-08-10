-- ClothMorphRuntime / TattooStateProbe.lua
-- Pure, dependency-injected tattoo-state capture and deterministic formatting.
-- This module normalizes engine-facing values immediately and never mutates them.

local M = {
    VERSION = 2,
    MAX_DEPTH = 6,
    MAX_ITEMS = 256,
    MAX_STATIC_ITEMS = 4096,
    MAX_APPLIED_VISUALS = 32,
}

local KAVT_UUID = "4cb0fd40-7212-4fe9-8733-9a8dbc6637ae"
local RELEVANT = { "tattoo", "atlas", "draw" }
local VALID_STATES = {
    present = true,
    absent = true,
    empty = true,
    unavailable = true,
    ["read-error"] = true,
    unresolved = true,
}
local VALID_REPORT_STATUS = { complete = true, partial = true, unresolved = true }

local function safeToString(value)
    local ok, result = pcall(tostring, value)
    if not ok then return nil, "tostring-failed" end
    return result, nil
end

local function normalizeScalar(value)
    local kind = type(value)
    if kind == "nil" or kind == "boolean" or kind == "number" or kind == "string" then
        return value, nil
    end
    local text, detail = safeToString(value)
    if text == nil then return nil, detail end
    return text, nil
end

local function stateForScalar(value)
    if value == nil then return "absent" end
    if type(value) == "string" and value == "" then return "empty" end
    return "present"
end

local function field(state, value, detail)
    return { state = state, value = value, detail = detail }
end

local function safeRead(container, key, missingState)
    if container == nil then return field(missingState or "unavailable", nil) end
    local ok, value = pcall(function() return container[key] end)
    if not ok then
        local detail = safeToString(value)
        return field("read-error", nil, detail)
    end
    local normalized, detail = normalizeScalar(value)
    if detail ~= nil then return field("read-error", nil, detail) end
    local state = stateForScalar(normalized)
    if state == "absent" and missingState ~= nil then state = missingState end
    return field(state, normalized)
end

local function readObject(container, key, missingState)
    if container == nil then return nil, missingState or "unavailable", nil end
    local ok, value = pcall(function() return container[key] end)
    if not ok then
        local detail = safeToString(value)
        return nil, "read-error", detail
    end
    if value == nil then return nil, missingState or "absent", nil end
    return value, "present", nil
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then return nil, "unavailable", "callback-unavailable" end
    local ok, value = pcall(callback, ...)
    if not ok then
        local detail = safeToString(value)
        return nil, "read-error", detail
    end
    if value == nil or value == false then return nil, "absent", nil end
    return value, "present", nil
end

local function callField(callback, ...)
    if type(callback) ~= "function" then return field("unavailable", nil, "callback-unavailable") end
    local ok, value = pcall(callback, ...)
    if not ok then
        local detail = safeToString(value)
        return field("read-error", nil, detail)
    end
    local normalized, detail = normalizeScalar(value)
    if detail ~= nil then return field("read-error", nil, detail) end
    return field(stateForScalar(normalized), normalized)
end

local function addDiagnostic(diagnostics, path, state, detail)
    local normalizedPath = safeToString(path) or "diagnostic"
    local normalizedDetail = safeToString(detail) or ""
    diagnostics[#diagnostics + 1] = normalizedPath .. ":" .. state .. ":" .. normalizedDetail
end

local function isRelevantPath(path)
    local text = (safeToString(path) or ""):lower()
    for _, needle in ipairs(RELEVANT) do
        if text:find(needle, 1, true) then return true end
    end
    return false
end

local function newBudget()
    return { items = 0, truncated = false }
end

local function consume(budget, amount)
    if budget.items + amount > M.MAX_ITEMS then
        budget.truncated = true
        return false
    end
    budget.items = budget.items + amount
    return true
end

local function safeEntries(container, budget)
    if container == nil then return nil, "unavailable", nil end
    local entries = {}
    local stopped = false
    local ok, problem = pcall(function()
        for key, value in pairs(container) do
            if not consume(budget, 2) then
                stopped = true
                break
            end
            local keyText, keyDetail = safeToString(key)
            if keyText == nil then
                keyText = "<unprintable-key>"
                keyDetail = keyDetail or "tostring-failed"
            end
            entries[#entries + 1] = {
                key = keyText,
                keyType = type(key),
                value = value,
                detail = keyDetail,
            }
        end
    end)
    if not ok then
        local detail = safeToString(problem)
        return nil, "read-error", detail
    end
    table.sort(entries, function(a, b)
        if a.key == b.key then return a.keyType < b.keyType end
        return a.key < b.key
    end)
    if stopped then budget.truncated = true end
    return entries, "present", nil
end

local function safeArrayEntries(container, budget)
    if container == nil then return nil, "unavailable", nil end
    local entries = {}
    local stopped = false
    local ok, problem = pcall(function()
        for index, value in ipairs(container) do
            if #entries >= M.MAX_APPLIED_VISUALS then
                stopped = true
                break
            end
            if not consume(budget, 2) then
                stopped = true
                break
            end
            entries[#entries + 1] = { index = index, value = value }
        end
    end)
    if not ok then
        local detail = safeToString(problem)
        return nil, "read-error", detail
    end
    if stopped then budget.truncated = true end
    return entries, "present", nil
end

local function safeStaticGuids(container)
    if container == nil then return nil, "unavailable", nil, false end
    local values = {}
    local truncated = false
    local ok, problem = pcall(function()
        for _, value in pairs(container) do
            if #values >= M.MAX_STATIC_ITEMS then
                truncated = true
                break
            end
            local normalized, detail = normalizeScalar(value)
            values[#values + 1] = {
                value = normalized,
                detail = detail,
            }
        end
    end)
    if not ok then
        local detail = safeToString(problem)
        return nil, "read-error", detail, truncated
    end
    table.sort(values, function(a, b)
        return (safeToString(a.value) or "") < (safeToString(b.value) or "")
    end)
    return values, "present", nil, truncated
end

local function collectRelevant(value, rootPath, budget, diagnostics)
    local leaves = {}
    local seen = {}

    local function addLeaf(path, state, scalar, detail)
        leaves[#leaves + 1] = {
            path = path,
            state = state,
            value = scalar,
            detail = detail,
        }
    end

    local function visit(current, path, depth, relevant)
        if depth > M.MAX_DEPTH then
            budget.truncated = true
            if relevant then addLeaf(path, "unresolved", nil, "depth-limit") end
            return
        end

        local kind = type(current)
        if kind ~= "table" then
            if relevant or isRelevantPath(current) then
                local normalized, detail = normalizeScalar(current)
                if detail ~= nil then
                    addLeaf(path, "read-error", nil, detail)
                else
                    addLeaf(path, stateForScalar(normalized), normalized)
                end
            end
            return
        end

        if seen[current] then
            if relevant then addLeaf(path, "unresolved", nil, "cycle") end
            return
        end
        seen[current] = true

        local entries, state, detail = safeEntries(current, budget)
        if entries == nil then
            if relevant then addLeaf(path, state, nil, detail) end
            addDiagnostic(diagnostics, path, state, detail)
            seen[current] = nil
            return
        end
        for _, entry in ipairs(entries) do
            local childPath = path .. "." .. entry.key
            local childRelevant = relevant or isRelevantPath(entry.key)
            if entry.detail ~= nil and childRelevant then
                addLeaf(childPath, "read-error", nil, entry.detail)
            else
                visit(entry.value, childPath, depth + 1, childRelevant)
            end
        end
        seen[current] = nil
    end

    visit(value, rootPath, 0, false)
    table.sort(leaves, function(a, b)
        if a.path == b.path then return a.state < b.state end
        return a.path < b.path
    end)
    return leaves
end

local function containsRelevantText(value)
    local text = (safeToString(value) or ""):lower()
    for _, needle in ipairs(RELEVANT) do
        if text:find(needle, 1, true) then return true end
    end
    return false
end

local function isBodyTattooAppearance(name, materialType)
    local normalizedName = (safeToString(name) or ""):lower():gsub("[^%a%d]", "")
    local normalizedType = (safeToString(materialType) or ""):lower():gsub("[^%a%d]", "")
    return normalizedName:find("bodytattoo", 1, true) ~= nil
        or normalizedType:find("bodytattoo", 1, true) ~= nil
        or normalizedType:find("bodyart", 1, true) ~= nil
end

local PRESET_PARAMETER_COLLECTIONS = {
    "ScalarParameters",
    "Texture2DParameters",
    "Vector2Parameters",
    "Vector3Parameters",
    "VectorParameters",
    "VirtualTextureParameters",
}

local MATERIAL_PARAMETER_COLLECTIONS = {
    "ScalarParameters",
    "Texture2DParameters",
    "Vector2Parameters",
    "Vector3Parameters",
    "VectorParameters",
    "VirtualTextureParameters",
}

local PRESET_PARAMETER_VALUE_FIELDS = {
    "Enabled",
    "Value",
}

local MATERIAL_PARAMETER_VALUE_FIELDS = {
    ScalarParameters = { "BaseValue", "Enabled", "ExportAsPreset", "Value" },
    Texture2DParameters = { "Enabled", "ExportAsPreset", "ID" },
    Vector2Parameters = { "BaseValue", "Enabled", "ExportAsPreset", "Value" },
    Vector3Parameters = { "BaseValue", "Enabled", "ExportAsPreset", "Value" },
    VectorParameters = { "BaseValue", "Enabled", "ExportAsPreset", "Value" },
    VirtualTextureParameters = { "Enabled", "ExportAsPreset", "ID" },
}

local function appendNormalizedLeaves(destination, path, value, budget, diagnostics, depth)
    depth = depth or 0
    if depth > M.MAX_DEPTH then
        budget.truncated = true
        destination[#destination + 1] = {
            path = path,
            state = "unresolved",
            value = nil,
            detail = "depth-limit",
        }
        return
    end

    local kind = type(value)
    if kind ~= "table" and kind ~= "userdata" then
        local normalized, detail = normalizeScalar(value)
        destination[#destination + 1] = {
            path = path,
            state = detail == nil and stateForScalar(normalized) or "read-error",
            value = detail == nil and normalized or nil,
            detail = detail,
        }
        return
    end

    local entries, state, detail = safeEntries(value, budget)
    if entries == nil then
        destination[#destination + 1] = {
            path = path,
            state = state,
            value = nil,
            detail = detail,
        }
        addDiagnostic(diagnostics, path, state, detail)
        return
    end
    if #entries == 0 then
        local normalized, scalarDetail = normalizeScalar(value)
        destination[#destination + 1] = {
            path = path,
            state = scalarDetail == nil and "present" or "read-error",
            value = scalarDetail == nil and normalized or nil,
            detail = scalarDetail,
        }
        return
    end
    for _, entry in ipairs(entries) do
        appendNormalizedLeaves(
            destination,
            path .. "." .. entry.key,
            entry.value,
            budget,
            diagnostics,
            depth + 1
        )
    end
end

local function parameterName(record, schema)
    if schema == "preset" then return safeRead(record, "Parameter", "absent") end
    return safeRead(record, "ParameterName", "absent")
end

local function captureRelevantParameters(container, rootPath, budget, diagnostics, schema)
    local leaves = {}
    if container == nil then return leaves end
    schema = schema == "preset" and "preset" or "material"
    local collections = schema == "preset"
        and PRESET_PARAMETER_COLLECTIONS
        or MATERIAL_PARAMETER_COLLECTIONS

    for _, collectionName in ipairs(collections) do
        local valueFields = schema == "preset"
            and PRESET_PARAMETER_VALUE_FIELDS
            or MATERIAL_PARAMETER_VALUE_FIELDS[collectionName]
        local collection, collectionState, collectionDetail = readObject(
            container,
            collectionName,
            "absent"
        )
        if collection ~= nil then
            local entries, entriesState, entriesDetail = safeEntries(collection, budget)
            if entries == nil then
                addDiagnostic(
                    diagnostics,
                    rootPath .. "." .. collectionName,
                    entriesState,
                    entriesDetail
                )
            else
                for _, entry in ipairs(entries) do
                    local record = entry.value
                    local name = parameterName(record, schema)
                    if name.state == "read-error" then
                        addDiagnostic(
                            diagnostics,
                            rootPath .. "." .. collectionName .. "." .. entry.key .. ".Parameter",
                            name.state,
                            name.detail
                        )
                    elseif name.state == "present" and containsRelevantText(name.value) then
                        local parameterPath = rootPath .. "." .. collectionName .. "." .. entry.key
                        leaves[#leaves + 1] = {
                            path = parameterPath .. ".Parameter",
                            state = "present",
                            value = name.value,
                        }
                        for _, valueField in ipairs(valueFields) do
                            local raw, rawState, rawDetail = readObject(record, valueField, "absent")
                            if rawState == "present" then
                                appendNormalizedLeaves(
                                    leaves,
                                    parameterPath .. "." .. valueField,
                                    raw,
                                    budget,
                                    diagnostics
                                )
                            elseif rawState == "read-error" then
                                leaves[#leaves + 1] = {
                                    path = parameterPath .. "." .. valueField,
                                    state = rawState,
                                    value = nil,
                                    detail = rawDetail,
                                }
                                addDiagnostic(
                                    diagnostics,
                                    parameterPath .. "." .. valueField,
                                    rawState,
                                    rawDetail
                                )
                            end
                        end
                    end
                end
            end
        elseif collectionState == "read-error" then
            addDiagnostic(
                diagnostics,
                rootPath .. "." .. collectionName,
                collectionState,
                collectionDetail
            )
        end
    end
    table.sort(leaves, function(a, b)
        if a.path == b.path then return a.state < b.state end
        return a.path < b.path
    end)
    return leaves
end

local function captureEnvironment(deps, diagnostics)
    local environment = {
        classification = field("unavailable", nil),
        kavtUuid = field("present", KAVT_UUID),
        kavtName = field("absent", nil),
        state = "unavailable",
    }

    local loaded, loadedState, loadedDetail = safeCall(deps.getLoadedMod, KAVT_UUID)
    if loadedState == "read-error" then
        environment.kavtName = field("read-error", nil, loadedDetail)
        addDiagnostic(diagnostics, "environment.kavt", loadedState, loadedDetail)
    elseif loadedState == "unavailable" then
        environment.kavtName = field("unavailable", nil, loadedDetail)
    elseif loaded ~= nil then
        local info, infoState, infoDetail = readObject(loaded, "Info", "absent")
        local nameField
        if infoState == "present" then
            nameField = safeRead(info, "Name", "absent")
        elseif infoState == "read-error" then
            nameField = field("read-error", nil, infoDetail)
        else
            nameField = safeRead(loaded, "Name", "absent")
        end
        environment.kavtName = nameField
        if nameField.state == "read-error" then
            addDiagnostic(diagnostics, "environment.kavtName", nameField.state, nameField.detail)
        end
    end

    environment.classification = callField(deps.detectEnvironment)
    local classification = environment.classification.value
    if environment.classification.state == "present" then
        local valid = classification == "none"
            or classification == "kavt_vt"
            or classification == "kavt_nvt"
            or classification == "kavt_unknown"
        if not valid then
            environment.classification = field("unresolved", classification, "unexpected-classification")
            addDiagnostic(diagnostics, "environment.classification", "unresolved", classification)
        end
    elseif environment.classification.state == "read-error" then
        addDiagnostic(
            diagnostics,
            "environment.classification",
            environment.classification.state,
            environment.classification.detail
        )
    end
    environment.state = environment.classification.state
    return environment
end

local function captureAppliedVisuals(appearance, deps, budget, diagnostics, rootPath)
    local result = { state = "unavailable", entries = {}, truncated = false }
    local visuals, visualsState, visualsDetail = readObject(appearance, "Visuals", "absent")
    if visuals == nil then
        result.state = visualsState
        if visualsState == "read-error" then
            addDiagnostic(diagnostics, rootPath .. ".visuals", visualsState, visualsDetail)
        end
        return result
    end

    local entries, entriesState, entriesDetail = safeArrayEntries(visuals, budget)
    if entries == nil then
        result.state = entriesState
        addDiagnostic(diagnostics, rootPath .. ".visuals", entriesState, entriesDetail)
        result.truncated = budget.truncated
        return result
    end

    result.state = "present"
    for _, source in ipairs(entries) do
        local normalized, normalizedDetail = normalizeScalar(source.value)
        local sourceType = type(source.value)
        local guid
        if normalizedDetail ~= nil then
            guid = field("read-error", nil, normalizedDetail)
        elseif normalized == "" then
            guid = field("empty", "")
        elseif (sourceType ~= "string" and sourceType ~= "userdata")
            or type(normalized) ~= "string" then
            guid = field("unresolved", nil, "expected-guid")
        else
            guid = field("present", normalized)
        end

        local entry = {
            index = field("present", source.index),
            guid = guid,
            ccsv = {
                state = "unavailable",
                VisualResource = field("unavailable", nil),
            },
        }
        if guid.state == "present" then
            local sharedVisual, sharedState, sharedDetail = safeCall(
                deps.getStaticData,
                guid.value,
                "CharacterCreationSharedVisual"
            )
            entry.ccsv.state = sharedState == "present" and "present"
                or sharedState == "read-error" and "read-error"
                or "unavailable"
            if sharedVisual ~= nil then
                entry.ccsv.VisualResource = safeRead(sharedVisual, "VisualResource", "absent")
            elseif sharedState == "read-error" then
                addDiagnostic(
                    diagnostics,
                    rootPath .. ".visuals." .. tostring(source.index),
                    sharedState,
                    sharedDetail
                )
            end
        end
        result.entries[#result.entries + 1] = entry
    end
    result.truncated = budget.truncated
    return result
end

local function captureAppearanceData(appearance, deps, budget, diagnostics, rootPath, includeVisuals)
    local result = { state = "unavailable", elements = {}, truncated = false }
    rootPath = rootPath or "appearance"
    if appearance == nil then return result end

    if includeVisuals then
        result.visuals = captureAppliedVisuals(appearance, deps, budget, diagnostics, rootPath)
    end

    local elements, elementsState, elementsDetail = readObject(appearance, "Elements", "absent")
    if elements == nil then
        result.state = elementsState
        if elementsState == "read-error" then
            addDiagnostic(diagnostics, rootPath .. ".elements", elementsState, elementsDetail)
        end
        return result
    end

    local entries, entriesState, entriesDetail = safeEntries(elements, budget)
    if entries == nil then
        result.state = entriesState
        addDiagnostic(diagnostics, rootPath .. ".elements", entriesState, entriesDetail)
        result.truncated = budget.truncated
        return result
    end

    result.state = "present"
    for _, entrySource in ipairs(entries) do
        local setting = entrySource.value
        local appearanceMaterialGuid = safeRead(setting, "Material", "absent")
        local entry = {
            index = field("present", entrySource.key),
            guid = appearanceMaterialGuid,
            setting = {
                Material = appearanceMaterialGuid,
                Color = safeRead(setting, "Color", "absent"),
                ColorIntensity = safeRead(setting, "ColorIntensity", "absent"),
                MetallicTint = safeRead(setting, "MetallicTint", "absent"),
                GlossyTint = safeRead(setting, "GlossyTint", "absent"),
            },
            static = {
                state = "unavailable",
                Name = field("unavailable", nil),
                MaterialType = field("unavailable", nil),
                MaterialPresetUUID = field("unavailable", nil),
            },
            presets = {},
            tattooRelated = false,
            reasons = {},
        }

        local staticData, staticState, staticDetail
        if appearanceMaterialGuid.state == "present" then
            staticData, staticState, staticDetail = safeCall(
                deps.getStaticData,
                appearanceMaterialGuid.value,
                "CharacterCreationAppearanceMaterial"
            )
        else
            staticState = appearanceMaterialGuid.state == "read-error" and "read-error" or "unavailable"
            staticDetail = appearanceMaterialGuid.detail
        end
        entry.static.state = staticState
        if staticData ~= nil then
            entry.static.Name = safeRead(staticData, "Name", "absent")
            entry.static.MaterialType = safeRead(staticData, "MaterialType", "absent")
            entry.static.MaterialPresetUUID = safeRead(staticData, "MaterialPresetUUID", "absent")
        elseif staticState == "read-error" then
            addDiagnostic(
                diagnostics,
                rootPath .. ".static." .. entrySource.key,
                staticState,
                staticDetail
            )
        end

        local presetGuids = {}
        local presetSeen = {}
        local function rememberPreset(source, candidate)
            if candidate.state ~= "present" or type(candidate.value) ~= "string" then return end
            if candidate.value == "" or presetSeen[candidate.value] then return end
            presetSeen[candidate.value] = true
            presetGuids[#presetGuids + 1] = { source = source, guid = candidate.value }
        end
        entry.tattooRelated = isBodyTattooAppearance(
            entry.static.Name.value,
            entry.static.MaterialType.value
        )
        if entry.tattooRelated then
            entry.reasons[#entry.reasons + 1] = "body-tattoo-identity"
            rememberPreset("static.MaterialPresetUUID", entry.static.MaterialPresetUUID)
        end
        table.sort(presetGuids, function(a, b)
            if a.guid == b.guid then return a.source < b.source end
            return a.guid < b.guid
        end)

        for _, presetSource in ipairs(presetGuids) do
            local preset, presetState, presetDetail = safeCall(
                deps.getResource,
                presetSource.guid,
                "MaterialPreset"
            )
            local presetRow = {
                source = field("present", presetSource.source),
                guid = field("present", presetSource.guid),
                state = presetState,
                relevant = {},
            }
            if preset ~= nil then
                local presetData, presetDataState, presetDataDetail = readObject(
                    preset,
                    "Presets",
                    "absent"
                )
                if presetData ~= nil then
                    presetRow.relevant = captureRelevantParameters(
                        presetData,
                        "MaterialPreset." .. presetSource.guid .. ".Presets",
                        budget,
                        diagnostics,
                        "preset"
                    )
                    presetRow.MaterialResource = safeRead(presetData, "MaterialResource", "absent")
                    presetRow.material = {
                        guid = presetRow.MaterialResource,
                        state = presetRow.MaterialResource.state == "present"
                            and "unavailable"
                            or presetRow.MaterialResource.state,
                        relevant = {},
                    }
                    if presetRow.MaterialResource.state == "present"
                        and presetRow.MaterialResource.value ~= "" then
                        local material, materialState, materialDetail = safeCall(
                            deps.getResource,
                            presetRow.MaterialResource.value,
                            "Material"
                        )
                        presetRow.material.state = materialState == "absent"
                            and "unavailable"
                            or materialState
                        if material ~= nil then
                            presetRow.material.state = "present"
                            presetRow.material.relevant = captureRelevantParameters(
                                material,
                                "MaterialPreset." .. presetSource.guid
                                    .. ".Material." .. presetRow.MaterialResource.value,
                                budget,
                                diagnostics,
                                "material"
                            )
                        elseif materialState == "read-error" then
                            addDiagnostic(
                                diagnostics,
                                rootPath .. ".preset." .. presetSource.guid .. ".MaterialResource",
                                materialState,
                                materialDetail
                            )
                        end
                    end
                elseif presetDataState == "read-error" then
                    presetRow.state = "read-error"
                    presetRow.MaterialResource = field("read-error", nil, presetDataDetail)
                    addDiagnostic(
                        diagnostics,
                        rootPath .. ".preset." .. presetSource.guid .. ".Presets",
                        presetDataState,
                        presetDataDetail
                    )
                else
                    presetRow.MaterialResource = field(presetDataState, nil)
                end
            elseif presetState == "read-error" then
                addDiagnostic(
                    diagnostics,
                    rootPath .. ".preset." .. presetSource.guid,
                    presetState,
                    presetDetail
                )
            end
            entry.presets[#entry.presets + 1] = presetRow
        end

        table.sort(entry.reasons)
        if entry.tattooRelated then result.elements[#result.elements + 1] = entry end
    end
    result.truncated = budget.truncated
    return result
end

local function captureAppearance(entity, deps, budget, diagnostics)
    local result = { state = "unavailable", elements = {}, truncated = false }
    if entity == nil then return result end

    local appearance, appearanceState, appearanceDetail = readObject(
        entity,
        "CharacterCreationAppearance",
        "unavailable"
    )
    if appearance == nil then
        result.state = appearanceState
        if appearanceState == "read-error" then
            addDiagnostic(diagnostics, "appearance", appearanceState, appearanceDetail)
        end
        return result
    end
    return captureAppearanceData(appearance, deps, budget, diagnostics, "appearance", true)
end

local function captureEntityOverrides(entity, deps, budget, diagnostics)
    local result = {
        appearance = { state = "absent", elements = {}, truncated = false },
        materialParameters = {
            state = "absent",
            guids = {},
            entries = {},
            truncated = false,
        },
        truncated = false,
    }
    if entity == nil then
        result.appearance.state = "unavailable"
        result.materialParameters.state = "unavailable"
        return result
    end

    local appearanceOverride, appearanceState, appearanceDetail = readObject(
        entity,
        "AppearanceOverride",
        "absent"
    )
    if appearanceOverride ~= nil then
        local visual, visualState, visualDetail = readObject(
            appearanceOverride,
            "Visual",
            "absent"
        )
        if visual ~= nil then
            result.appearance = captureAppearanceData(
                visual,
                deps,
                budget,
                diagnostics,
                "entityOverrides.appearance"
            )
        else
            result.appearance.state = visualState
            if visualState == "read-error" then
                addDiagnostic(
                    diagnostics,
                    "entityOverrides.appearance.Visual",
                    visualState,
                    visualDetail
                )
            end
        end
    else
        result.appearance.state = appearanceState
        if appearanceState == "read-error" then
            addDiagnostic(
                diagnostics,
                "entityOverrides.appearance",
                appearanceState,
                appearanceDetail
            )
        end
    end

    local materialOverride, materialState, materialDetail = readObject(
        entity,
        "MaterialParameterOverride",
        "absent"
    )
    if materialOverride ~= nil then
        result.materialParameters.state = "present"
        local guidValues, guidState, guidDetail = readObject(
            materialOverride,
            "field_0",
            "absent"
        )
        if guidValues ~= nil then
            local guidEntries, entriesState, entriesDetail = safeEntries(guidValues, budget)
            if guidEntries ~= nil then
                for _, entry in ipairs(guidEntries) do
                    local value, detail = normalizeScalar(entry.value)
                    result.materialParameters.guids[#result.materialParameters.guids + 1] =
                        detail and field("read-error", nil, detail)
                        or field(stateForScalar(value), value)
                end
            else
                result.materialParameters.state = entriesState
                addDiagnostic(
                    diagnostics,
                    "entityOverrides.materialParameters.field_0",
                    entriesState,
                    entriesDetail
                )
            end
        elseif guidState == "read-error" then
            result.materialParameters.state = "read-error"
            addDiagnostic(
                diagnostics,
                "entityOverrides.materialParameters.field_0",
                guidState,
                guidDetail
            )
        end

        local values, valuesState, valuesDetail = readObject(
            materialOverride,
            "field_10",
            "absent"
        )
        if values ~= nil then
            local entries, entriesState, entriesDetail = safeEntries(values, budget)
            if entries ~= nil then
                for _, entry in ipairs(entries) do
                    result.materialParameters.entries[#result.materialParameters.entries + 1] = {
                        index = field("present", entry.key),
                        field_0 = safeRead(entry.value, "field_0", "absent"),
                        field_18 = safeRead(entry.value, "field_18", "absent"),
                    }
                end
            else
                result.materialParameters.state = entriesState
                addDiagnostic(
                    diagnostics,
                    "entityOverrides.materialParameters.field_10",
                    entriesState,
                    entriesDetail
                )
            end
        elseif valuesState == "read-error" then
            result.materialParameters.state = "read-error"
            addDiagnostic(
                diagnostics,
                "entityOverrides.materialParameters.field_10",
                valuesState,
                valuesDetail
            )
        end
    else
        result.materialParameters.state = materialState
        if materialState == "read-error" then
            addDiagnostic(
                diagnostics,
                "entityOverrides.materialParameters",
                materialState,
                materialDetail
            )
        end
    end

    result.appearance.truncated = result.appearance.truncated or budget.truncated
    result.materialParameters.truncated = budget.truncated
    result.truncated = budget.truncated
    return result
end

local function captureVisualResource(
    visualGuid,
    deps,
    budget,
    diagnostics,
    rootPath,
    includeMaterialDetails
)
    local result = {
        guid = visualGuid,
        state = "unavailable",
        objects = {},
        truncated = false,
    }
    rootPath = rootPath or "Visual"
    if visualGuid.state ~= "present" then
        result.state = visualGuid.state == "read-error" and "read-error" or "unavailable"
        return result
    end

    local visual, visualState, visualDetail = safeCall(
        deps.getResource,
        visualGuid.value,
        "Visual"
    )
    if visual == nil then
        result.state = visualState == "absent" and "unavailable" or visualState
        if visualState == "read-error" then
            addDiagnostic(diagnostics, rootPath, visualState, visualDetail)
        end
        return result
    end

    local objects, objectsState, objectsDetail = readObject(visual, "Objects", "absent")
    if objects == nil then
        result.state = objectsState == "absent" and "unresolved" or objectsState
        if objectsState == "read-error" then
            addDiagnostic(diagnostics, rootPath .. ".Objects", objectsState, objectsDetail)
        end
        return result
    end

    local entries, entriesState, entriesDetail = safeEntries(objects, budget)
    if entries == nil then
        result.state = entriesState
        addDiagnostic(diagnostics, rootPath .. ".Objects", entriesState, entriesDetail)
        result.truncated = budget.truncated
        return result
    end

    local referencedMaterials = 0
    local resolvedMaterials = 0
    for _, entrySource in ipairs(entries) do
        local object = entrySource.value
        local materialGuid = safeRead(object, "MaterialID", "absent")
        local row = {
            index = field("present", entrySource.key),
            ObjectID = safeRead(object, "ObjectID", "absent"),
            MaterialID = materialGuid,
            LOD = safeRead(object, "LOD", "absent"),
            material = {
                guid = materialGuid,
                state = materialGuid.state == "present" and "unavailable" or materialGuid.state,
                relevant = {},
            },
        }
        if materialGuid.state == "present" and materialGuid.value ~= "" then
            referencedMaterials = referencedMaterials + 1
            if includeMaterialDetails == false then
                resolvedMaterials = resolvedMaterials + 1
            else
                local material, materialState, materialDetail = safeCall(
                    deps.getResource,
                    materialGuid.value,
                    "Material"
                )
                row.material.state = materialState == "absent" and "unavailable" or materialState
                if material ~= nil then
                    row.material.state = "present"
                    row.material.relevant = captureRelevantParameters(
                        material,
                        rootPath .. ".Objects." .. entrySource.key .. ".Material." .. materialGuid.value,
                        budget,
                        diagnostics,
                        "material"
                    )
                    resolvedMaterials = resolvedMaterials + 1
                elseif materialState == "read-error" then
                    addDiagnostic(
                        diagnostics,
                        rootPath .. ".Objects." .. entrySource.key .. ".Material",
                        materialState,
                        materialDetail
                    )
                end
            end
        end
        result.objects[#result.objects + 1] = row
    end

    if #entries > 0 and referencedMaterials > 0 and resolvedMaterials == referencedMaterials then
        result.state = "present"
    else
        result.state = "unresolved"
    end
    result.truncated = budget.truncated
    return result
end

local function captureCharacterVisual(characterVisualGuid, deps, budget, diagnostics)
    local result = {
        state = "unavailable",
        bodySetVisual = field("unavailable", nil),
        bodyVisual = {
            guid = field("unavailable", nil),
            state = "unavailable",
            objects = {},
            truncated = false,
        },
        relevant = {},
        containers = {},
        truncated = false,
    }
    if characterVisualGuid.state ~= "present" then
        result.state = characterVisualGuid.state == "read-error" and "read-error" or "unavailable"
        return result
    end

    local visual, visualState, visualDetail = safeCall(
        deps.getResource,
        characterVisualGuid.value,
        "CharacterVisual"
    )
    if visual == nil then
        result.state = visualState == "absent" and "unavailable" or visualState
        if visualState == "read-error" then
            addDiagnostic(diagnostics, "characterVisual", visualState, visualDetail)
        end
        return result
    end
    local visualSet, visualSetState, visualSetDetail = readObject(visual, "VisualSet", "absent")
    if visualSet ~= nil then
        result.bodySetVisual = safeRead(visualSet, "BodySetVisual", "absent")
    elseif visualSetState == "read-error" then
        result.bodySetVisual = field("read-error", nil, visualSetDetail)
        addDiagnostic(diagnostics, "characterVisual.VisualSet", visualSetState, visualSetDetail)
    else
        result.bodySetVisual = field(visualSetState, nil)
    end

    result.bodyVisual = captureVisualResource(
        result.bodySetVisual,
        deps,
        budget,
        diagnostics,
        "CharacterVisual.BodySetVisual"
    )

    for _, containerName in ipairs({
        "Materials",
        "MaterialOverrides",
        "MaterialRemaps",
    }) do
        local container, containerState, containerDetail = readObject(visualSet, containerName, "absent")
        result.containers[containerName] = field(containerState, nil, containerDetail)
        if container ~= nil then
            if containerName == "Materials" then
                local materialEntries, materialState, materialDetail = safeEntries(container, budget)
                if materialEntries == nil then
                    addDiagnostic(
                        diagnostics,
                        "CharacterVisual.VisualSet.Materials",
                        materialState,
                        materialDetail
                    )
                else
                    for _, materialEntry in ipairs(materialEntries) do
                        local leaves = captureRelevantParameters(
                            materialEntry.value,
                            "CharacterVisual.VisualSet.Materials." .. materialEntry.key,
                            budget,
                            diagnostics
                        )
                        for _, leaf in ipairs(leaves) do
                            result.relevant[#result.relevant + 1] = leaf
                        end
                    end
                end
            else
                local leaves = collectRelevant(
                    container,
                    "CharacterVisual.VisualSet." .. containerName,
                    budget,
                    diagnostics
                )
                for _, leaf in ipairs(leaves) do result.relevant[#result.relevant + 1] = leaf end
            end
        elseif containerState == "read-error" then
            addDiagnostic(
                diagnostics,
                "characterVisual.VisualSet." .. containerName,
                containerState,
                containerDetail
            )
        end
    end
    table.sort(result.relevant, function(a, b)
        if a.path == b.path then return a.state < b.state end
        return a.path < b.path
    end)
    if result.bodySetVisual.state == "present" and result.bodyVisual.state == "present" then
        result.state = "present"
    else
        result.state = "unresolved"
    end
    result.truncated = budget.truncated
    return result
end

local function normalizeRow(source)
    return {
        key = safeRead(source, "key", "unresolved"),
        bodyChoice = safeRead(source, "bodyChoice", "unresolved"),
        environment = safeRead(source, "environment", "unresolved"),
        policy = safeRead(source, "policy", "unresolved"),
        vr = safeRead(source, "vr", "unresolved"),
        ccsv = safeRead(source, "ccsv", "absent"),
    }
end

local function appendRows(destination, source, budget, diagnostics, label)
    if source == nil then return "unavailable" end
    local entries, state, detail = safeEntries(source, budget)
    if entries == nil then
        addDiagnostic(diagnostics, "staticBodies." .. label, state, detail)
        return state
    end
    for _, entry in ipairs(entries) do
        if type(entry.value) == "table" or type(entry.value) == "userdata" then
            destination[#destination + 1] = normalizeRow(entry.value)
        else
            addDiagnostic(diagnostics, "staticBodies." .. label .. "." .. entry.key, "unresolved", type(entry.value))
        end
    end
    return "present"
end

local function captureStaticBodies(deps, budget, diagnostics, target)
    local result = { state = "unavailable", rows = {}, truncated = false }
    local normalizedRows = {}

    local variants, variantState, variantDetail = safeCall(deps.getVariantRows)
    if variantState == "read-error" then
        addDiagnostic(diagnostics, "staticBodies.variants", variantState, variantDetail)
    end
    local rowsState = appendRows(normalizedRows, variants, budget, diagnostics, "variants")
    local vanillaState = appendRows(
        normalizedRows,
        deps.vanillaRows,
        budget,
        diagnostics,
        "vanilla"
    )
    table.sort(normalizedRows, function(a, b)
        return (safeToString(a.key.value) or "") < (safeToString(b.key.value) or "")
    end)

    local targetBodyChoice = target and target.bodyChoice or nil
    local targetPolicy = target and target.policy or nil
    local targetEnvironment = target and target.environment or nil
    if targetBodyChoice ~= nil and targetPolicy ~= nil and targetEnvironment ~= nil then
        local focusedRows = {}
        for _, row in ipairs(normalizedRows) do
            local isVanilla = row.bodyChoice.value == "vanilla"
            local isSelected = row.bodyChoice.value == targetBodyChoice
                and row.policy.value == targetPolicy
                and row.environment.value == targetEnvironment
            if isVanilla or isSelected then focusedRows[#focusedRows + 1] = row end
        end
        normalizedRows = focusedRows
    end

    local resolvedCount = 0
    local expectedCount = 0
    for _, rowSource in ipairs(normalizedRows) do
        expectedCount = expectedCount + 1
        local row = {
            key = rowSource.key,
            bodyChoice = rowSource.bodyChoice,
            environment = rowSource.environment,
            policy = rowSource.policy,
            vr = {
                guid = rowSource.vr,
                state = "unavailable",
                objects = {},
                truncated = false,
            },
            ccsv = {
                guid = rowSource.ccsv,
                state = rowSource.ccsv.state == "absent" and "absent" or "unavailable",
                VisualResource = field("unavailable", nil),
            },
            state = "unresolved",
        }

        local ccsvRequired = rowSource.ccsv.state == "present"
        local ccsvResolved = not ccsvRequired
        if ccsvRequired then
            local sharedVisual, sharedState, sharedDetail = safeCall(
                deps.getStaticData,
                rowSource.ccsv.value,
                "CharacterCreationSharedVisual"
            )
            row.ccsv.state = sharedState == "absent" and "unavailable" or sharedState
            if sharedVisual ~= nil then
                row.ccsv.state = "present"
                row.ccsv.VisualResource = safeRead(sharedVisual, "VisualResource", "absent")
                ccsvResolved = true
            elseif sharedState == "read-error" then
                addDiagnostic(
                    diagnostics,
                    "staticBodies." .. (safeToString(rowSource.key.value) or "row") .. ".ccsv",
                    sharedState,
                    sharedDetail
                )
            end
        end

        local visualResolved = false
        if rowSource.vr.state == "present" then
            row.vr = captureVisualResource(
                rowSource.vr,
                deps,
                budget,
                diagnostics,
                "StaticBodies." .. (safeToString(rowSource.key.value) or "row") .. ".Visual",
                false
            )
            visualResolved = row.vr.state == "present"
        end

        if ccsvResolved and visualResolved then
            row.state = "present"
            resolvedCount = resolvedCount + 1
        end
        result.rows[#result.rows + 1] = row
    end

    if expectedCount > 0 and resolvedCount == expectedCount then
        result.state = "present"
    elseif resolvedCount > 0 then
        result.state = "unresolved"
    elseif rowsState == "read-error" or vanillaState == "read-error" then
        result.state = "read-error"
    else
        result.state = "unavailable"
    end
    result.truncated = budget.truncated
    return result
end

local function rememberMaterial(materials, candidate)
    if type(candidate) ~= "table" or candidate.state ~= "present" then return end
    local value = safeToString(candidate.value)
    if value ~= nil and value ~= "" then materials[value:lower()] = true end
end

local function collectBodyMaterials(characterVisual, staticBodies)
    local materials = {}
    local function collectVisual(visual)
        if type(visual) ~= "table" or type(visual.objects) ~= "table" then return end
        for _, object in ipairs(visual.objects) do rememberMaterial(materials, object.MaterialID) end
    end
    if type(characterVisual) == "table" then collectVisual(characterVisual.bodyVisual) end
    if type(staticBodies) == "table" and type(staticBodies.rows) == "table" then
        for _, row in ipairs(staticBodies.rows) do collectVisual(row.vr) end
    end
    return materials
end

local function captureMaterialBridges(
    deps,
    characterVisual,
    staticBodies,
    budget,
    diagnostics
)
    local result = { state = "unavailable", rows = {}, truncated = false }
    local guids, allState, allDetail = safeCall(
        deps.getAllStaticData,
        "CharacterCreationMaterialOverride"
    )
    if guids == nil then
        result.state = allState
        if allState == "read-error" then
            addDiagnostic(diagnostics, "materialBridges", allState, allDetail)
        end
        return result
    end

    local entries, entriesState, entriesDetail, staticTruncated = safeStaticGuids(guids)
    if entries == nil then
        result.state = entriesState
        addDiagnostic(diagnostics, "materialBridges", entriesState, entriesDetail)
        result.truncated = budget.truncated
        return result
    end

    local bodyMaterials = collectBodyMaterials(characterVisual, staticBodies)
    result.state = "present"
    for index, entry in ipairs(entries) do
        local guid, guidDetail = entry.value, entry.detail
        if guidDetail == nil and guid ~= nil and safeToString(guid) ~= "" then
            local resource, resourceState, resourceDetail = safeCall(
                deps.getStaticData,
                guid,
                "CharacterCreationMaterialOverride"
            )
            if resource ~= nil then
                local row = {
                    guid = field("present", guid),
                    MaterialType = safeRead(resource, "MaterialType", "absent"),
                    ActiveMaterialPresetUUID = safeRead(
                        resource,
                        "ActiveMaterialPresetUUID",
                        "absent"
                    ),
                    InactiveMaterialPresetUUID = safeRead(
                        resource,
                        "InactiveMaterialPresetUUID",
                        "absent"
                    ),
                    SourceMaterialUUID = safeRead(resource, "SourceMaterialUUID", "absent"),
                    TargetMaterialUUID = safeRead(resource, "TargetMaterialUUID", "absent"),
                }
                local materialType = (safeToString(row.MaterialType.value) or ""):lower()
                local source = (safeToString(row.SourceMaterialUUID.value) or ""):lower()
                local target = (safeToString(row.TargetMaterialUUID.value) or ""):lower()
                if materialType == "tattoo"
                    or bodyMaterials[source] == true
                    or bodyMaterials[target] == true then
                    result.rows[#result.rows + 1] = row
                end
            elseif resourceState == "read-error" then
                result.state = "unresolved"
                addDiagnostic(
                    diagnostics,
                    "materialBridges." .. (safeToString(guid) or tostring(index)),
                    resourceState,
                    resourceDetail
                )
            end
        elseif guidDetail ~= nil then
            result.state = "unresolved"
            addDiagnostic(
                diagnostics,
                "materialBridges." .. tostring(index),
                "read-error",
                guidDetail
            )
        end
    end
    table.sort(result.rows, function(a, b)
        return (safeToString(a.guid.value) or "") < (safeToString(b.guid.value) or "")
    end)
    result.truncated = budget.truncated or staticTruncated
    if result.truncated then result.state = "unresolved" end
    return result
end

local function normalizeGuid(value)
    if value == nil then return nil, "unresolved", "missing-character-guid" end
    local normalized, detail = safeToString(value)
    if detail ~= nil then return nil, "read-error", detail end
    if normalized == "" then return nil, "unresolved", "missing-character-guid" end
    return normalized, "present", nil
end

local function readCharacterVisualGuid(entity)
    local serverCharacter, serverState, serverDetail = readObject(
        entity,
        "ServerCharacter",
        "absent"
    )
    if serverCharacter ~= nil then
        local template, templateState, templateDetail = readObject(
            serverCharacter,
            "Template",
            "absent"
        )
        if template ~= nil then
            local fromTemplate = safeRead(template, "CharacterVisualResourceID", "absent")
            if fromTemplate.state == "present" then return fromTemplate end
            if fromTemplate.state == "read-error" then
                templateState = "read-error"
                templateDetail = fromTemplate.detail
            end
        end
        if templateState == "read-error" then
            serverState = "read-error"
            serverDetail = templateDetail
        end
    end

    local direct = safeRead(entity, "CharacterVisualResourceID", "absent")
    if direct.state == "present" or direct.state == "read-error" then return direct end
    if serverState == "read-error" then return field("read-error", nil, serverDetail) end
    return direct
end

function M.Capture(characterGuid, deps)
    deps = deps or {}
    local diagnostics = {}
    local normalizedGuid, guidState, guidDetail = normalizeGuid(characterGuid)
    if normalizedGuid == nil then normalizedGuid = "<unresolved>" end

    local report = {
        version = M.VERSION,
        status = "unresolved",
        target = {
            characterGuid = normalizedGuid,
            entityState = "unavailable",
            race = field("unavailable", nil),
            bodyType = field("unavailable", nil),
            bodyShape = field("unavailable", nil),
            bodyChoice = field("unavailable", nil),
            policy = field("unavailable", nil),
            characterVisualGuid = field("unavailable", nil),
            activeBodyVisualGuid = field("unavailable", nil),
        },
        environment = nil,
        appearance = nil,
        entityOverrides = nil,
        characterVisual = nil,
        staticBodies = nil,
        materialBridges = nil,
        diagnostics = diagnostics,
    }
    if guidState ~= "present" then
        addDiagnostic(diagnostics, "target.characterGuid", guidState, guidDetail)
    end

    local entity, entityState, entityDetail = safeCall(deps.getEntity, normalizedGuid)
    report.target.entityState = entityState == "absent" and "unavailable" or entityState
    if entityState == "read-error" then
        addDiagnostic(diagnostics, "target.entity", entityState, entityDetail)
    end

    if entity ~= nil then
        if type(deps.readCharStats) == "function" then
            local ok, race, bodyType, bodyShape = pcall(deps.readCharStats, entity)
            if ok then
                local normalizedRace, raceDetail = normalizeScalar(race)
                local normalizedBodyType, bodyTypeDetail = normalizeScalar(bodyType)
                local normalizedBodyShape, bodyShapeDetail = normalizeScalar(bodyShape)
                report.target.race = raceDetail and field("read-error", nil, raceDetail)
                    or field(stateForScalar(normalizedRace), normalizedRace)
                report.target.bodyType = bodyTypeDetail and field("read-error", nil, bodyTypeDetail)
                    or field(stateForScalar(normalizedBodyType), normalizedBodyType)
                report.target.bodyShape = bodyShapeDetail and field("read-error", nil, bodyShapeDetail)
                    or field(stateForScalar(normalizedBodyShape), normalizedBodyShape)
            else
                local detail = safeToString(race)
                report.target.race = field("read-error", nil, detail)
                report.target.bodyType = field("read-error", nil, detail)
                report.target.bodyShape = field("read-error", nil, detail)
                addDiagnostic(diagnostics, "target.stats", "read-error", detail)
            end
        end
        report.target.bodyChoice = callField(deps.getBodyChoice, normalizedGuid)
        report.target.policy = callField(deps.getPolicy)
        if report.target.bodyChoice.state == "read-error" then
            addDiagnostic(diagnostics, "target.bodyChoice", "read-error", report.target.bodyChoice.detail)
        end
        if report.target.policy.state == "read-error" then
            addDiagnostic(diagnostics, "target.policy", "read-error", report.target.policy.detail)
        end
        report.target.characterVisualGuid = readCharacterVisualGuid(entity)
    end

    report.environment = captureEnvironment(deps, diagnostics)
    report.appearance = captureAppearance(entity, deps, newBudget(), diagnostics)
    report.entityOverrides = captureEntityOverrides(entity, deps, newBudget(), diagnostics)
    report.characterVisual = captureCharacterVisual(
        report.target.characterVisualGuid,
        deps,
        newBudget(),
        diagnostics
    )
    report.target.activeBodyVisualGuid = report.characterVisual.bodySetVisual
    report.staticBodies = captureStaticBodies(deps, newBudget(), diagnostics, {
        bodyChoice = report.target.bodyChoice.value,
        policy = report.target.policy.value,
        environment = report.environment.classification.value,
    })
    report.materialBridges = captureMaterialBridges(
        deps,
        report.characterVisual,
        report.staticBodies,
        newBudget(),
        diagnostics
    )

    if report.target.entityState ~= "present" or guidState ~= "present" then
        report.status = "unresolved"
    elseif report.appearance.state == "present"
        and report.characterVisual.state == "present"
        and report.staticBodies.state == "present"
        and report.environment.classification.state == "present"
        and report.appearance.truncated ~= true
        and report.characterVisual.truncated ~= true
        and report.staticBodies.truncated ~= true
        and #diagnostics == 0 then
        report.status = "complete"
    else
        report.status = "partial"
    end
    return report
end

local function escape(value)
    local text = safeToString(value)
    if text == nil then text = "<nil>" end
    text = text:gsub("\\", "\\\\")
    text = text:gsub("\n", "\\n")
    text = text:gsub("\r", "\\r")
    text = text:gsub("\t", "\\t")
    if #text > 512 then text = text:sub(1, 509) .. "..." end
    return text
end

local function sortedKeys(value)
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local aType, bType = type(a), type(b)
        if aType == bType and aType == "number" then return a < b end
        local aText, bText = safeToString(a) or "", safeToString(b) or ""
        if aText == bText then return aType < bType end
        return aText < bText
    end)
    return keys
end

local function isFieldTable(value)
    if type(value) ~= "table" or VALID_STATES[value.state] ~= true then return false end
    for key in pairs(value) do
        if key ~= "state" and key ~= "value" and key ~= "detail" then return false end
    end
    return true
end

function M.Format(report)
    report = type(report) == "table" and report or {}
    local version = tonumber(report.version) or M.VERSION
    local status = VALID_REPORT_STATUS[report.status] and report.status or "unresolved"
    local target = type(report.target) == "table" and report.target or {}
    local character = target.characterGuid or "<unresolved>"
    local diagnostics = type(report.diagnostics) == "table" and report.diagnostics or {}
    local diagnosticCount = #diagnostics
    local middle = {}
    local formatTruncated = false

    local function emit(path, state, value, detail)
        if #middle >= 510 then
            formatTruncated = true
            return
        end
        local rendered = value
        if rendered == nil and detail ~= nil then rendered = detail end
        middle[#middle + 1] = "CM_TATTOO field=" .. escape(path)
            .. " state=" .. escape(VALID_STATES[state] and state or "unresolved")
            .. " value=" .. escape(rendered)
    end

    local function walk(value, path, depth)
        if #middle >= 510 then
            formatTruncated = true
            return
        end
        if depth > M.MAX_DEPTH + 4 then
            emit(path, "unresolved", nil, "format-depth-limit")
            return
        end
        if type(value) ~= "table" then
            emit(path, stateForScalar(value), value)
            return
        end
        if type(value.path) == "string" and VALID_STATES[value.state] == true then
            emit(path .. "." .. value.path, value.state, value.value, value.detail)
            return
        end
        if isFieldTable(value) then
            emit(path, value.state, value.value, value.detail)
            return
        end
        if VALID_STATES[value.state] == true then
            emit(path, value.state, nil)
        end
        for _, key in ipairs(sortedKeys(value)) do
            if key ~= "state" then
                local keyText = safeToString(key) or "<unprintable-key>"
                walk(value[key], path == "" and keyText or path .. "." .. keyText, depth + 1)
            end
        end
    end

    for _, key in ipairs(sortedKeys(report)) do
        if key ~= "version" and key ~= "status" and key ~= "diagnostics" then
            local keyText = safeToString(key) or "<unprintable-key>"
            walk(report[key], keyText, 0)
        end
    end
    for index, message in ipairs(diagnostics) do
        emit("diagnostics." .. tostring(index), "unresolved", message)
    end

    if formatTruncated then
        if #middle >= 510 then middle[#middle] = nil end
        middle[#middle + 1] = "CM_TATTOO field=format state=unresolved value=truncated:true"
        diagnosticCount = diagnosticCount + 1
    end

    local lines = {
        "CM_TATTOO_DUMP_BEGIN version=" .. tostring(version)
            .. " character=" .. escape(character)
            .. " status=" .. status,
    }
    for _, line in ipairs(middle) do lines[#lines + 1] = line end
    lines[#lines + 1] = "CM_TATTOO_DUMP_END version=" .. tostring(version)
        .. " status=" .. status
        .. " diagnostics=" .. tostring(diagnosticCount)
    return lines
end

return M
