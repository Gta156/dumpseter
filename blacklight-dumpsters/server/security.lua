--[[ ==========================================================================
     BlackLight Dumpsters — Server-side Security Helpers
     --------------------------------------------------------------------------
     Rate limiting, proximity validation and inventory verification used by
     every net event and callback in this resource.
========================================================================== ]]

local rateBuckets = {}

--- Simple per-player, per-action rate limiter.
---@param playerSource number
---@param actionKey string Unique key for the action being throttled.
---@param cooldownMs number Minimum milliseconds between invocations.
---@return boolean allowed
function GuardRate(playerSource, actionKey, cooldownMs)
    if not playerSource or playerSource <= 0 then
        return false
    end

    local bucket = rateBuckets[playerSource]
    if not bucket then
        bucket = {}
        rateBuckets[playerSource] = bucket
    end

    local now = GetGameTimer()
    local lastCall = bucket[actionKey]

    if lastCall and (now - lastCall) < (cooldownMs or 500) then
        if Settings.DiagnosticMode then
            print(("[^3BlackLight^7] Rate limit hit: %s tried '%s' too quickly."):format(playerSource, actionKey))
        end
        return false
    end

    bucket[actionKey] = now
    return true
end

--- Verifies the player is genuinely near the coordinates they claim.
---@param playerSource number
---@param coords vector3|table
---@param maxDistance number|nil Defaults to 12.0 metres of tolerance.
---@return boolean withinRange
function GuardProximity(playerSource, coords, maxDistance)
    if not coords then
        return false
    end

    local ped = GetPlayerPed(playerSource)
    if not ped or ped == 0 then
        return false
    end

    local target = vector3(coords.x + 0.0, coords.y + 0.0, coords.z + 0.0)
    local distance = #(GetEntityCoords(ped) - target)

    if distance > (maxDistance or 12.0) then
        if Settings.DiagnosticMode then
            print(("[^3BlackLight^7] Proximity check failed for %s (%.1fm away)."):format(playerSource, distance))
        end
        return false
    end

    return true
end

--- Confirms a networked entity really exists before trusting a claim about it.
---@param netId number
---@return boolean, number|nil
function GuardEntity(netId)
    if not netId or netId == 0 then
        return false, nil
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return false, nil
    end

    return true, entity
end

--- Verifies the player is holding at least `quantity` of an item, server-side.
---@return boolean
function GuardInventory(playerSource, itemName, quantity)
    if not itemName then
        return false
    end

    local held = Framework.GetItemCount(playerSource, itemName) or 0
    return held >= (quantity or 1)
end

--- Clamps a client-supplied number into a trusted range.
---@return number|nil
function GuardNumber(value, minimum, maximum)
    local number = tonumber(value)
    if not number then
        return nil
    end

    if number ~= number then -- NaN guard
        return nil
    end

    if number < minimum or number > maximum then
        return nil
    end

    return number
end

-- Housekeeping: drop rate buckets when a player disconnects.
AddEventHandler("playerDropped", function()
    rateBuckets[source] = nil
end)
