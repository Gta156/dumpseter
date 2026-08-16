local dumpsterBusy = {}
local dumpsterBusyCoords = {}
local rareItemBusy = {}
local dumpsterOccupied = {}
local dumpsterOccupiedBy = {}
local registeredStashes = {}

local function ScheduleClearBusy(netId)
    SetTimeout(Config.TrashCooldown * 60000, function()
        dumpsterBusy[netId] = false
        dumpsterBusyCoords[netId] = nil
    end)
end

local function ScheduleClearRareBusy(netId)
    SetTimeout(Config.TrashCooldown * 60000, function()
        rareItemBusy[netId] = false
    end)
end

local function IsNearBusyDumpster(coords)
    for _, busyCoords in pairs(dumpsterBusyCoords) do
        if #(coords - busyCoords) < 1.0 then
            return true
        end
    end
    return false
end

local function SelectWeightedRandomIndex(items)
    if not (items[1] and items[1].rarity) then
        print("No rarity defined, using random selection")
        return math.random(1, #items)
    end

    local weights = {}
    local totalWeight = 0
    for i, item in ipairs(items) do
        local weight = item.rarity or 50
        weight = 100 - weight
        weights[i] = weight
        totalWeight = totalWeight + weight
    end

    local roll = math.random(1, totalWeight)
    local cumulative = 0
    for i, weight in pairs(weights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            return i
        end
    end

    return math.random(1, #items)
end

local function GiveRandomItems(source, items, netId, coords)
    local player = Framework.GetPlayer(source)
    if dumpsterBusy[netId] then
        Framework.Notify(source, Config.Lang.notrash, "error")
        return
    end

    if IsNearBusyDumpster(coords) then
        Framework.Notify(source, Config.Lang.look, "error")
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then
        if Config.AdvancedCheaterCheck then
            Framework.Notify(source, Config.Lang.cheater, "error")
            return
        end
    end

    if not player then
        return
    end

    if Config and items then
        if Config.RandomSelection then
            local usedIndexes = {}
            local itemCount = math.random(Config.RandomSelection.itemCountMin, Config.RandomSelection.itemCountMax)

            for i = 1, itemCount, 1 do
                local index
                local tries = 0
                repeat
                    index = SelectWeightedRandomIndex(items)
                    tries = tries + 1
                until usedIndexes[index] or tries > #items

                if tries <= #items then
                    local item = items[index]
                    if item then
                        local amount = math.random(item.min, item.max)
                        if amount > 0 then
                            Framework.AddItem(source, item.name, amount, item.metadata)
                        end
                        usedIndexes[index] = true
                        if netId then
                            dumpsterBusy[netId] = true
                            dumpsterBusyCoords[netId] = coords
                            ScheduleClearBusy(netId)
                        end
                    end
                end
            end
        end

        AddHoboProgessionLoot(source, netId, coords)
    end
end

local function GiveRareItem(source, items, netId)
    local player = Framework.GetPlayer(source)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then
        if Config.AdvancedCheaterCheck then
            Framework.Notify(source, Config.Lang.cheater, "error")
            return
        end
    end

    if rareItemBusy[netId] then
        return
    end

    if not player then
        return
    end

    if Config and items then
        local index = SelectWeightedRandomIndex(items)
        local item = items[index]
        if item then
            local amount = math.random(item.min, item.max)
            if amount > 0 then
                Framework.AddItem(source, item.name, amount, item.metadata)
            end
            if netId then
                rareItemBusy[netId] = true
                ScheduleClearRareBusy(netId)
            end
        end
    end
end

local function GiveBagItems(source, items, netId, coords)
    local player = Framework.GetPlayer(source)
    if dumpsterBusy[netId] then
        Framework.Notify(source, Config.Lang.notrash, "error")
        return
    end

    if IsNearBusyDumpster(coords) then
        Framework.Notify(source, Config.Lang.look_somewhere_else, "error")
        return
    end

    if not player then
        return
    end

    if Config and items then
        if Config.RandomSelection then
            local usedIndexes = {}
            local itemCount = math.random(Config.RandomSelection.itemCountMin, Config.RandomSelection.itemCountMax)

            for i = 1, itemCount, 1 do
                local index = SelectWeightedRandomIndex(items)
                local item = items[index]
                if item then
                    local amount = math.random(item.min, item.max)
                    if amount > 0 then
                        Framework.AddItem(source, item.name, amount, item.metadata)
                    end

                    if netId then
                        dumpsterBusy[netId] = true
                        dumpsterBusyCoords[netId] = coords
                        ScheduleClearBusy(netId)
                    end
                end
            end
        end
    end
end

local function GiveSingleItem(source, items)
    local player = Framework.GetPlayer(source)
    if Config and items then
        local index = SelectWeightedRandomIndex(items)
        local item = items[index]
        if item then
            local amount = math.random(item.min, item.max)
            if amount > 0 then
                Framework.AddItem(source, item.name, amount, item.metadata)
            end
        end
    end
end

Framework.CreateCallback("envi-dumpsters:GiveItemsBeach", function(source, cb, netId, coords, zoneName)
    if dumpsterBusy[netId] then
        Framework.Notify(source, Config.Lang.notrash, "error")
        return
    end

    if not zoneName then
        GiveRandomItems(source, Config.BeachCanItems, netId, coords)
    else
        for _, zone in pairs(Config.ExclusiveItemZones) do
            if zoneName == zone.name then
                if math.random(1, 100) <= zone.chance then
                    GiveRandomItems(source, zone.items, netId, coords)
                else
                    GiveRandomItems(source, Config.BeachCanItems, netId, coords)
                end
            end
        end
    end

    if math.random(1, 100) <= Config.BeachCanItemsRareChance then
        GiveRareItem(source, Config.BeachCanItemsRare, netId)
    end
end)

Framework.CreateCallback("envi-dumpsters:GiveItemsDumpster", function(source, cb, netId, coords, zoneName)
    if dumpsterBusy[netId] then
        Framework.Notify(source, Config.Lang.notrash, "error")
        return
    end

    if not zoneName then
        GiveRandomItems(source, Config.DumpsterItems, netId, coords)
    else
        for _, zone in pairs(Config.ExclusiveItemZones) do
            if zoneName == zone.name then
                if math.random(1, 100) <= zone.chance then
                    GiveRandomItems(source, zone.items, netId, coords)
                else
                    GiveRandomItems(source, Config.DumpsterItems, netId, coords)
                end
            end
        end
    end

    if math.random(1, 100) <= Config.DumpsterItemsRareChance then
        GiveRareItem(source, Config.DumpsterItemsRare, netId)
    end
end)

Framework.CreateCallback("envi-dumpsters:GiveItemsGarbageCans", function(source, cb, netId, coords, zoneName)
    if dumpsterBusy[netId] then
        Framework.Notify(source, Config.Lang.notrash, "error")
        return
    end

    if not zoneName then
        GiveRandomItems(source, Config.GarbageCanItems, netId, coords)
    else
        for _, zone in pairs(Config.ExclusiveItemZones) do
            if zoneName == zone.name then
                if math.random(1, 100) <= zone.chance then
                    GiveRandomItems(source, zone.items, netId, coords)
                else
                    GiveRandomItems(source, Config.GarbageCanItems, netId, coords)
                end
            end
        end
    end

    if math.random(1, 100) <= Config.GarbageCanItemsRareChance then
        GiveRareItem(source, Config.GarbageCanItemsRare, netId)
    end
end)

Framework.CreateCallback("envi-dumpsters:GiveItemsOther", function(source, cb, netId, coords, zoneName)
    if dumpsterBusy[netId] then
        Framework.Notify(source, Config.Lang.notrash, "error")
        return
    end

    if not zoneName then
        GiveRandomItems(source, Config.OtherSeachablesItems, netId, coords)
    else
        for _, zone in pairs(Config.ExclusiveItemZones) do
            if zoneName == zone.name then
                if math.random(1, 100) <= zone.chance then
                    GiveRandomItems(source, zone.items, netId, coords)
                else
                    GiveRandomItems(source, Config.OtherSeachablesItems, netId, coords)
                end
            end
        end
    end

    if math.random(1, 100) <= Config.OtherSeachablesItemsRareChance then
        GiveRareItem(source, Config.OtherSeachablesItemsRare, netId)
    end
end)

Framework.CreateCallback("envi-dumpsters:GiveItemsBags", function(source, cb, netId, coords, zoneName)
    if not zoneName then
        GiveBagItems(source, Config.GarbageBagsItems, netId, coords)
    else
        for _, zone in pairs(Config.ExclusiveItemZones) do
            if zoneName == zone.name then
                if math.random(1, 100) <= zone.chance then
                    GiveBagItems(source, zone.items, netId, coords)
                else
                    GiveBagItems(source, Config.GarbageBagsItems, netId, coords)
                end
            end
        end
    end

    if math.random(1, 100) <= Config.GarbageBagsItemsRareChance then
        GiveSingleItem(source, Config.GarbageBagsItemsRare)
    end

    cb(true)
end)

Framework.CreateCallback("envi-dumpsters:GiveItemsCustom", function(source, cb, netId, coords, zoneName, customIndex)
    if dumpsterBusy[netId] then
        Framework.Notify(source, Config.Lang.notrash, "error")
        return
    end

    local custom = CustomSearchables[customIndex]
    if not custom then
        return
    end

    if IsNearBusyDumpster(coords) then
        Framework.Notify(source, Config.Lang.look, "error")
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then
        if Config.AdvancedCheaterCheck then
            Framework.Notify(source, Config.Lang.cheater, "error")
            return
        end
    end

    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    if zoneName then
        for _, zone in pairs(Config.ExclusiveItemZones) do
            if zoneName == zone.name then
                if math.random(1, 100) <= zone.chance then
                    GiveRandomItems(source, zone.items, netId, coords)
                    return
                end
            end
        end
    end

    if custom.loot and #custom.loot > 0 then
        if Config.RandomSelection then
            local usedIndexes = {}
            local itemCount = math.random(Config.RandomSelection.itemCountMin, Config.RandomSelection.itemCountMax)

            for i = 1, itemCount, 1 do
                local index
                local tries = 0
                repeat
                    index = SelectWeightedRandomIndex(custom.loot)
                    tries = tries + 1
                until usedIndexes[index] or tries > #custom.loot

                if tries <= #custom.loot then
                    local item = custom.loot[index]
                    if item then
                        local amount = math.random(item.min, item.max)
                        if amount > 0 then
                            Framework.AddItem(source, item.name, amount, item.metadata)
                        end
                        usedIndexes[index] = true
                        if netId then
                            dumpsterBusy[netId] = true
                            dumpsterBusyCoords[netId] = coords
                            ScheduleClearBusy(netId)
                        end
                    end
                end
            end
        end

        AddHoboProgessionLoot(source, netId, coords)
    end
end)

function HashCoords(coords)
    return string.format("%.0f", coords.x) .. string.format("%.0f", coords.y) .. string.format("%.0f", coords.z)
end

Framework.CreateCallback("envi-dumpsters:OpenBeach", function(source, cb, netId, coords)
    local hash = HashCoords(coords)
    Framework.RegisterStash("Beach" .. hash, Config.BeachCanStorageSlots, Config.BeachCanStorageWeight)
    registeredStashes["Beach" .. hash] = true
    cb(hash)
end)

Framework.CreateCallback("envi-dumpsters:OpenDumpster", function(source, cb, netId, coords)
    local hash = HashCoords(coords)
    Framework.RegisterStash("Dumpster" .. hash, Config.DumpsterStorageSlots, Config.DumpsterStorageWeight)
    registeredStashes["Dumpster" .. hash] = true
    cb(hash)
end)

Framework.CreateCallback("envi-dumpsters:OpenGarbage", function(source, cb, netId, coords)
    local hash = HashCoords(coords)
    Framework.RegisterStash("Garbage" .. hash, Config.GarbageCanStorageSlots, Config.GarbageCanStorageWeight)
    registeredStashes["Garbage" .. hash] = true
    cb(hash)
end)

Framework.CreateCallback("envi-dumpsters:OpenOther", function(source, cb, netId, coords)
    local hash = HashCoords(coords)
    Framework.RegisterStash("Hobo" .. hash, Config.OtherStorageSlots, Config.OtherStorageWeight)
    registeredStashes["Hobo" .. hash] = true
    cb(hash)
end)

RegisterNetEvent("envi-dumpsters:setDumpsterBusy", function(netId, busy)
    dumpsterOccupied[netId] = busy
    dumpsterOccupiedBy[netId] = source
end)

Framework.CreateCallback("envi-dumpsters:checkDumpsterIsFree", function(source, cb, netId)
    local isBusy = false
    if dumpsterOccupied[netId] then
        isBusy = true
    end

    if isBusy then
        Framework.Notify(source, Config.Lang.dumpster_busy, "error")
        TriggerClientEvent("envi-dumpsters:kickOutOfDumpster", dumpsterOccupiedBy[netId])
        dumpsterOccupiedBy[netId] = nil
        dumpsterOccupied[netId] = false
        cb(false)
    else
        cb(true)
    end
end)

RegisterNetEvent("envi-dumpsters:snitch", function(coords, zoneName)
    local zone = Config.ExclusiveItemZones[zoneName]
    local jobs = zone.jobsToInform

    if math.random(1, 100) <= zone.snitchChance then
        TriggerClientEvent("envi-dumpsters:snitchReport", -1, coords, jobs)
    end
end)

if Config.ClearDumpstersOnRestart then
    AddEventHandler("onResourceStop", function(resourceName)
        if GetCurrentResourceName() ~= resourceName then
            return
        end

        for stashId, isRegistered in pairs(registeredStashes) do
            if isRegistered then
                Framework.ClearInventory(stashId)
            end
        end
    end)
end
