local reclaimUnitBusy = {}
local reclaimUnitFinishAt = {}

--[[
    Reclaim-unit hardening.

    The original took `recyclerId` straight from the client with no checks, so any player
    could: lock every unit on the map by spamming ids (including ids that do not exist,
    which leaked memory in the busy tables), release a unit somebody else was using, or
    start a machine they were nowhere near and collect the output remotely.

    We now require the id to be a real index into Config.ReclaimUnitLocations, require the
    caller to be standing at that unit, record who started it so only they (or the timer)
    can clear it, and rate limit the entry points.
]]
local RECLAIM_USE_DISTANCE = 8.0
local reclaimUnitOwner = {}

--- Validate a client-supplied unit id against the configured locations.
--- Returns the numeric index and its coords, or nil.
local function ResolveReclaimUnit(recyclerId)
    local id = tonumber(recyclerId)
    if not id or id ~= math.floor(id) or id < 1 then
        return nil
    end
    local location = Config.ReclaimUnitLocations[id]
    if not location then
        return nil
    end
    return id, location.coords
end

CreateThread(function()
    for i = 1, #Config.ReclaimUnitLocations, 1 do
        Framework.RegisterStash("bl_scav_reclaim_" .. i, 20, 100000)
    end
end)

local function ProcessReclaimUnit(containerId)
    local inventory = Framework.GetInventory(containerId)
    local itemsToReward = {}
    local itemsToRemove = {}

    for slot, item in pairs(inventory) do
        local recycleConfig = Config.ReclaimExchangeRates[item.name]
        if recycleConfig then
            table.insert(itemsToReward, {
                name = item.name,
                count = item.count,
                slot = slot,
                reward = recycleConfig,
            })
            table.insert(itemsToRemove, {
                name = item.name,
                count = item.count,
                slot = slot,
            })
        end
    end

    for _, item in ipairs(itemsToRemove) do
        Framework.RemoveItem(containerId, item.name, item.count, nil, item.slot)
    end

    for _, item in ipairs(itemsToReward) do
        local reward = item.reward
        local amount = math.random(reward.min, reward.max) * item.count
        if amount > 0 then
            Framework.AddItem(containerId, reward.material, amount)
        end
    end

    return #itemsToReward > 0
end

Framework.CreateCallback("bl_scav:CheckRecyclerStatus", function(source, cb, recyclerId)
    local id = ResolveReclaimUnit(recyclerId)
    if not id then
        return cb(false)
    end
    cb(not reclaimUnitBusy[id])
end)

RegisterNetEvent("bl_scav:SetRecyclerBusy", function(recyclerId, busy)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end

    if not Security.RateLimit(src, "reclaim_busy", 500) then
        return
    end

    local id, coords = ResolveReclaimUnit(recyclerId)
    if not id then
        Security.Flag(src, "SetRecyclerBusy with an unknown reclaim unit id")
        return
    end

    if not Security.IsPlayerNear(src, coords, RECLAIM_USE_DISTANCE) then
        Security.Flag(src, "SetRecyclerBusy from out of range")
        return
    end

    if busy then
        -- Do not let a second player seize a unit that is already running.
        if reclaimUnitBusy[id] then
            return
        end
        reclaimUnitBusy[id] = true
        reclaimUnitOwner[id] = player.Identifier
        reclaimUnitFinishAt[id] = os.time() + Config.ReclaimSettings.duration
    else
        -- Only the player who started the cycle may cancel it early.
        if reclaimUnitBusy[id] and reclaimUnitFinishAt[id]
            and reclaimUnitOwner[id] == player.Identifier then
            reclaimUnitBusy[id] = nil
            reclaimUnitOwner[id] = nil
            reclaimUnitFinishAt[id] = nil
        end
    end
end)

CreateThread(function()
    while true do
        local now = os.time()
        for recyclerId, endTime in pairs(reclaimUnitFinishAt) do
            if endTime <= now then
                ProcessReclaimUnit("bl_scav_reclaim_" .. recyclerId)
                reclaimUnitBusy[recyclerId] = nil
                reclaimUnitOwner[recyclerId] = nil
                reclaimUnitFinishAt[recyclerId] = nil
            end
        end
        Wait(2000)
    end
end)

RegisterNetEvent("bl_scav:StartRecycling", function(recyclerId)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end

    if not Security.RateLimit(src, "reclaim_start", 1000) then
        return
    end

    local id, coords = ResolveReclaimUnit(recyclerId)
    if not id then
        Security.Flag(src, "StartRecycling with an unknown reclaim unit id")
        return
    end

    if not Security.IsPlayerNear(src, coords, RECLAIM_USE_DISTANCE) then
        Security.Flag(src, "StartRecycling from out of range")
        return
    end

    if reclaimUnitBusy[id] then
        Framework.Notify(src, Config.Lang.recycler_in_use, "error")
        return
    end

    reclaimUnitBusy[id] = true
    reclaimUnitOwner[id] = player.Identifier
    reclaimUnitFinishAt[id] = os.time() + Config.ReclaimSettings.duration

    TriggerClientEvent("bl_scav:StartRecyclingEffect", -1, id, Config.ReclaimSettings.duration)
    Framework.Notify(src, Config.Lang.recycling_started, "success")
end)
