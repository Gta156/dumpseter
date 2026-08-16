local recyclerBusy = {}
local recyclerEndTime = {}

CreateThread(function()
    for i = 1, #Config.RecyclerLocations, 1 do
        Framework.RegisterStash("hobo_recycler_" .. i, 20, 100000)
    end
end)

local function ProcessRecycler(containerId)
    local inventory = Framework.GetInventory(containerId)
    local itemsToReward = {}
    local itemsToRemove = {}

    for slot, item in pairs(inventory) do
        local recycleConfig = Config.RecyclingItems[item.name]
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

Framework.CreateCallback("envi-hobo:CheckRecyclerStatus", function(source, cb, recyclerId)
    cb(not recyclerBusy[recyclerId])
end)

RegisterNetEvent("envi-hobo:SetRecyclerBusy", function(recyclerId, busy)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    if busy then
        recyclerBusy[recyclerId] = true
        recyclerEndTime[recyclerId] = os.time() + Config.RecycleSettings.duration
    else
        if recyclerBusy[recyclerId] and recyclerEndTime[recyclerId] then
            recyclerBusy[recyclerId] = nil
            recyclerEndTime[recyclerId] = nil
        end
    end
end)

CreateThread(function()
    while true do
        local now = os.time()
        for recyclerId, endTime in pairs(recyclerEndTime) do
            if endTime <= now then
                ProcessRecycler("hobo_recycler_" .. recyclerId)
                recyclerBusy[recyclerId] = nil
                recyclerEndTime[recyclerId] = nil
            end
        end
        Wait(2000)
    end
end)

RegisterNetEvent("envi-hobo:StartRecycling", function(recyclerId)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    if recyclerBusy[recyclerId] then
        Framework.Notify(source, Config.Lang.recycler_in_use, "error")
        return
    end

    recyclerBusy[recyclerId] = true
    recyclerEndTime[recyclerId] = os.time() + Config.RecycleSettings.duration

    TriggerClientEvent("envi-hobo:StartRecyclingEffect", -1, recyclerId, Config.RecycleSettings.duration)
    Framework.Notify(source, Config.Lang.recycling_started, "success")
end)
