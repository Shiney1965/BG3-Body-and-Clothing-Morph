-- ClothMorphRuntime / Targeting.lua
-- Multiplayer-safe character targeting helpers. Pure functions accept injected
-- deps so the logic is testable outside BG3SE.

local M = {}

local GUID_PATTERN = "(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)"

local function read(o, k)
    if o == nil then return nil end
    local ok, v = pcall(function() return o[k] end)
    if ok then return v end
    return nil
end

function M.NormGuid(value)
    local s = tostring(value or "")
    local g = s:match(GUID_PATTERN .. "%s*$") or s:match(GUID_PATTERN)
    if g == nil then return nil end
    return g:lower()
end

function M.EntityGuid(entity)
    if entity == nil then return nil end
    local direct = M.NormGuid(read(entity, "Guid") or read(entity, "GUID") or read(entity, "Uuid") or read(entity, "UUID"))
    if direct ~= nil then return direct end
    local uuid = read(entity, "Uuid") or read(entity, "UUID")
    if type(uuid) == "table" or type(uuid) == "userdata" then
        return M.NormGuid(read(uuid, "EntityUuid") or read(uuid, "EntityUUID") or read(uuid, "Guid") or tostring(uuid))
    end
    return M.NormGuid(tostring(entity))
end

function M.ExtractUserId(user)
    if user == nil then return nil end
    if type(user) == "number" or type(user) == "string" then return tostring(user) end
    for _, key in ipairs({ "UserID", "UserId", "userID", "userId", "Id", "ID", "NetId", "NetID", "PeerId", "PeerID" }) do
        local v = read(user, key)
        if v ~= nil and tostring(v) ~= "" then return tostring(v) end
    end
    return nil
end

function M.GetReservedUserId(char, deps)
    deps = deps or {}
    local getEntity = deps.getEntity
    if getEntity == nil and Ext ~= nil and Ext.Entity ~= nil then
        getEntity = function(guid) return Ext.Entity.Get(guid) end
    end
    if getEntity == nil then return nil, "entity-api-unavailable" end
    local ok, entity = pcall(getEntity, char)
    if not ok or entity == nil then return nil, "entity-unavailable" end
    local reservation = read(entity, "UserReservedFor")
    if reservation == nil then return nil, "reservation-unavailable" end
    local userId = M.ExtractUserId(read(reservation, "UserID"))
    if userId == nil then return nil, "reserved-user-unavailable" end
    return userId, nil
end

function M.CanUserControl(user, char, deps)
    deps = deps or {}
    local userId = M.ExtractUserId(user)
    if userId == nil then return false, "missing-user" end
    local reserved, reservedWhy
    if deps.getReservedUserId then
        reserved, reservedWhy = deps.getReservedUserId(char)
    else
        reserved, reservedWhy = M.GetReservedUserId(char, deps)
    end
    if reserved ~= nil and tostring(reserved) ~= "" then
        if tostring(reserved) == userId then return true end
        return false, "reserved-user-mismatch"
    end
    if deps.sameUser ~= nil then
        local ok = deps.sameUser(user, char)
        if ok == true then return true end
        if ok == false then return false, "same-user-failed" end
    end
    return false, reservedWhy or "ownership-unknown"
end

function M.ResolveTarget(payload, user, deps)
    deps = deps or {}
    payload = payload or {}
    local requested = M.NormGuid(payload.target or payload.char or payload.character)
    local isNetwork = user ~= nil
    if requested == nil and not isNetwork and deps.getHostChar ~= nil then
        requested = M.NormGuid(deps.getHostChar())
    end
    if requested == nil then return nil, "missing-target" end
    if isNetwork then
        local ok, why = M.CanUserControl(user, requested, deps)
        if not ok then return nil, "not-owned", why end
    end
    return requested, nil
end

function M.GetClientControlTarget(deps)
    deps = deps or {}
    local getAll = deps.getAllClientControl
    if getAll == nil and Ext ~= nil and Ext.Entity ~= nil then
        getAll = function() return Ext.Entity.GetAllEntitiesWithComponent("ClientControl") end
    end
    if getAll == nil then return nil end
    local ok, list = pcall(getAll)
    if not ok or list == nil then return nil end
    for _, entity in ipairs(list) do
        local hasAppearance = read(entity, "CharacterCreationAppearance") ~= nil
        if hasAppearance then
            local guid = M.EntityGuid(entity)
            if guid ~= nil then return guid end
        end
    end
    if list[1] ~= nil then return M.EntityGuid(list[1]) end
    return nil
end

return M
