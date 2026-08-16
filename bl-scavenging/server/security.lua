--[[
    BlackLight Scavenging — server-side trust boundary
    ---------------------------------------------------
    Every value that arrives from a client is untrusted. This module centralises the
    checks that the rest of the server code applies before acting on client input.

    The original resource accepted client-supplied coordinates and network IDs at face
    value, which allowed a modified client to loot containers it was nowhere near, spam
    reward callbacks, and index config tables with arbitrary strings. Nothing here changes
    legitimate gameplay behaviour — a normal player passes every check.
]]

Security = {}

--- Maximum distance (metres) between a player and the entity/point they claim to interact
--- with. Generous enough to absorb latency and prop bounding boxes, tight enough that a
--- teleport-loot exploit fails.
local MAX_INTERACT_DISTANCE = 12.0

--- Resolve a real, connected player. Returns nil for disconnected or spoofed sources.
---@param src any
---@return table|nil player, number|nil source
function Security.ResolvePlayer(src)
    local source = tonumber(src)
    if not source or source <= 0 then
        return nil, nil
    end
    -- GetPlayerName returns nil for a source that is not actually connected.
    if not GetPlayerName(source) then
        return nil, nil
    end
    local player = Framework.GetPlayer(source)
    if not player then
        return nil, nil
    end
    return player, source
end

--- Validate that a value is a finite number.
local function isFiniteNumber(v)
    return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

--- Coerce arbitrary client input into a trusted vector3, or nil.
--- Accepts a vector3 or a {x=,y=,z=} table, rejects NaN/inf and absurd magnitudes.
---@param value any
---@return vector3|nil
function Security.SanitiseCoords(value)
    local x, y, z
    if type(value) == "vector3" then
        x, y, z = value.x, value.y, value.z
    elseif type(value) == "table" then
        x, y, z = value.x or value[1], value.y or value[2], value.z or value[3]
    else
        return nil
    end
    if not (isFiniteNumber(x) and isFiniteNumber(y) and isFiniteNumber(z)) then
        return nil
    end
    -- GTA V's playable volume; anything outside is fabricated.
    if math.abs(x) > 20000.0 or math.abs(y) > 20000.0 or math.abs(z) > 5000.0 then
        return nil
    end
    return vector3(x + 0.0, y + 0.0, z + 0.0)
end

--- Validate a network ID and return the entity it refers to.
--- `strict` mirrors Config.StrictEntityValidation: when enabled a missing entity is a hard fail.
---@param netId any
---@param strict boolean
---@return number|nil entity, number|nil netId
function Security.ResolveEntity(netId, strict)
    local id = tonumber(netId)
    if not id or id <= 0 or id ~= math.floor(id) then
        return nil, nil
    end
    local entity = NetworkGetEntityFromNetworkId(id)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        if strict then
            return nil, id
        end
        return nil, id -- caller decides whether a missing entity is fatal
    end
    return entity, id
end

--- Is the player close enough to the supplied point?
---@param source number
---@param coords vector3
---@param maxDistance number|nil
---@return boolean
function Security.IsPlayerNear(source, coords, maxDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then
        return false
    end
    local playerCoords = GetEntityCoords(ped)
    return #(playerCoords - coords) <= (maxDistance or MAX_INTERACT_DISTANCE)
end

--- Combined check used by every loot/stash entry point.
--- Confirms: real player, sane coords, valid net entity, player is actually next to it,
--- and (when the entity resolves) that the client's claimed coords match the server's
--- view of where that entity really is.
---@return table|nil player, number|nil source, vector3|nil coords, number|nil netId
function Security.ValidateContainerAccess(src, netId, rawCoords)
    local player, source = Security.ResolvePlayer(src)
    if not player then
        return nil
    end

    local coords = Security.SanitiseCoords(rawCoords)
    if not coords then
        Security.Flag(source, "malformed coordinates")
        return nil
    end

    local strict = Config.StrictEntityValidation and true or false
    local entity, id = Security.ResolveEntity(netId, strict)
    if not id then
        Security.Flag(source, "malformed network id")
        return nil
    end

    if entity then
        -- Trust the server's entity position over the client's claim.
        local entityCoords = GetEntityCoords(entity)
        if #(entityCoords - coords) > 5.0 then
            Security.Flag(source, "coordinate/entity mismatch")
            return nil
        end
        coords = entityCoords
    elseif strict then
        Security.Flag(source, "references a non-existent entity")
        return nil
    end

    if not Security.IsPlayerNear(source, coords) then
        Security.Flag(source, "acted on an out-of-range container")
        return nil
    end

    return player, source, coords, id
end

-- ---------------------------------------------------------------------------
--  Rate limiting
-- ---------------------------------------------------------------------------

local buckets = {}

--- Simple per-player, per-action cooldown.
---@param source number
---@param action string
---@param intervalMs number
---@return boolean allowed
function Security.RateLimit(source, action, intervalMs)
    local now = GetGameTimer()
    local key = action .. ":" .. source
    local nextAllowed = buckets[key]
    if nextAllowed and now < nextAllowed then
        return false
    end
    buckets[key] = now + intervalMs
    return true
end

AddEventHandler("playerDropped", function()
    local src = tostring(source)
    for key in pairs(buckets) do
        if key:sub(-#src - 1) == ":" .. src then
            buckets[key] = nil
        end
    end
end)

-- ---------------------------------------------------------------------------
--  Reporting
-- ---------------------------------------------------------------------------

--- Record a rejected request. Deliberately does not kick: false positives from lag or
--- unusual props should never remove a legitimate player. Server owners can hook this.
---@param source number
---@param reason string
function Security.Flag(source, reason)
    if Config.DiagnosticsEnabled then
        print(("[bl-scavenging] rejected request from %s (%s): %s")
            :format(GetPlayerName(source) or "unknown", source, reason))
    end
    TriggerEvent("bl_scav:server:SecurityFlag", source, reason)
end

return Security
