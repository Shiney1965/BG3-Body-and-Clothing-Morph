-- ClothMorphRuntime / SharedTemplateProbe.lua
-- Diagnostics for proving whether two characters sharing one template can keep
-- distinct body/clothing choices.

local M = {}

local function value(x)
    if x == nil then return nil end
    return tostring(x):lower()
end

function M.CompareSnapshots(input)
    input = input or {}
    local a, b = input.a or {}, input.b or {}
    local expectedA = value(input.expectedA)
    local expectedB = value(input.expectedB)
    local actualA = value(a.equipmentRace or a.choice)
    local actualB = value(b.equipmentRace or b.choice)
    local sameTemplate = a.templateId ~= nil and b.templateId ~= nil and tostring(a.templateId):lower() == tostring(b.templateId):lower()
    local leak = false
    if sameTemplate and expectedA ~= nil and expectedB ~= nil and expectedA ~= expectedB then
        leak = actualA == actualB or actualA ~= expectedA or actualB ~= expectedB
    end
    return {
        charA = a.char,
        charB = b.char,
        templateA = a.templateId,
        templateB = b.templateId,
        observedA = actualA,
        observedB = actualB,
        expectedA = expectedA,
        expectedB = expectedB,
        sameTemplate = sameTemplate,
        equipmentRaceLeak = leak,
        pass = sameTemplate and not leak,
    }
end

local function read(o, k)
    if o == nil then return nil end
    local ok, v = pcall(function() return o[k] end)
    if ok then return v end
    return nil
end

function M.ReadSnapshot(char, deps)
    deps = deps or {}
    local ent = nil
    if deps.getEntity then ent = deps.getEntity(char) elseif Ext and Ext.Entity then pcall(function() ent = Ext.Entity.Get(char) end) end
    local serverChar = read(ent, "ServerCharacter")
    local template = read(serverChar, "Template")
    return {
        char = char,
        templateId = read(template, "Id"),
        equipmentRace = read(template, "EquipmentRace"),
    }
end

function M.FormatReport(report)
    return ("sharedTemplate=%s leak=%s pass=%s A[%s]=%s/%s B[%s]=%s/%s"):format(
        tostring(report.sameTemplate),
        tostring(report.equipmentRaceLeak),
        tostring(report.pass),
        tostring(report.charA),
        tostring(report.templateA),
        tostring(report.observedA),
        tostring(report.charB),
        tostring(report.templateB),
        tostring(report.observedB))
end

return M
