Framework.CreateUseableItem("cardboard_bed", function(source)
    local removed = Framework.RemoveItem(source, "cardboard_bed", 1)
    if removed then
        TriggerClientEvent("envi-dumpsters:client:UseItem", source, "cardboard_bed")
    end
end)

Framework.CreateUseableItem("sleeping_bag", function(source)
    local removed = Framework.RemoveItem(source, "sleeping_bag", 1)
    if removed then
        TriggerClientEvent("envi-dumpsters:client:UseItem", source, "sleeping_bag")
    end
end)

Framework.CreateUseableItem("hobo_tent", function(source, itemName, itemData)
    local tentID = itemData or nil
    if itemData then
        tentID = itemData.metadata
        if tentID then
            tentID = tentID.tentID
        end
    end

    if not tentID then
        local identifier = Framework.GetPlayer(source).Identifier
        local newTentID = identifier .. Framework.RandomString(5) .. Framework.RandomInteger(5)

        Framework.SetItemMetadata(source, itemData.slot, { tentID = newTentID })
        Framework.Notify(source, Config.Lang.welcome_new_home, "success")

        local removed = Framework.RemoveItem(source, "hobo_tent", 1, nil, itemData.slot)
        if removed then
            TriggerClientEvent("envi-dumpsters:client:UseItem", source, "hobo_tent", { tentID = newTentID })
        end
        return
    end

    tentID = itemData or tentID
    if itemData then
        tentID = itemData.metadata
        if tentID then
            tentID = tentID.tentID
        end
    end

    if tentID then
        local removed = Framework.RemoveItem(source, "hobo_tent", 1, itemData.metadata, itemData.slot)
        if removed then
            TriggerClientEvent("envi-dumpsters:client:UseItem", source, "hobo_tent", itemData.metadata)
        end
        return
    end
end)

Framework.CreateUseableItem("hobo_bottle", function(source, itemName, itemData)
    local uses = itemData or nil
    if itemData then
        uses = itemData.metadata
        if uses then
            uses = uses.uses
        end
    end

    if not uses then
        Framework.SetItemMetadata(source, itemData.slot, { uses = Config.ItemSettings.hobo_bottle.capacity - 1 })
        TriggerClientEvent("envi-dumpsters:client:UseItem", source, "hobo_bottle")
        Framework.Notify(source, string.format(Config.Lang.remaining_uses, Config.ItemSettings.hobo_bottle.capacity - 1), "success")
        return
    end

    uses = itemData or uses
    if itemData then
        uses = itemData.metadata
        if uses then
            uses = uses.uses
        end
    end

    if uses then
        uses = itemData.metadata.uses
        if uses > 0 then
            Framework.SetItemMetadata(source, itemData.slot, { uses = itemData.metadata.uses - 1 })
            TriggerClientEvent("envi-dumpsters:client:UseItem", source, "hobo_bottle", itemData.metadata)
            Framework.Notify(source, string.format(Config.Lang.remaining_uses, itemData.metadata.uses - 1), "success")
        end
    else
        Framework.Notify(source, Config.Lang.bottle_empty, "error")
    end
end)

local rationPackProvides = Config.ItemSettings.ration_pack.provides

Framework.CreateUseableItem("ration_pack", function(source)
    local removed = Framework.RemoveItem(source, "ration_pack", 1)
    if removed then
        TriggerClientEvent("envi-dumpsters:client:UseItem", source, "ration_pack")

        for _, entry in ipairs(rationPackProvides) do
            Framework.AddItem(source, entry.item, math.random(1, entry.max))
        end
    end
end)

Framework.CreateUseableItem("begging_sign", function(source)
    TriggerClientEvent("envi-dumpsters:client:UseItem", source, "begging_sign")
end)

RegisterNetEvent("envi-dumpsters:server:RefillBottle", function(slot)
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    Framework.SetItemMetadata(playerId, slot, { uses = Config.ItemSettings.hobo_bottle.capacity })
    Framework.Notify(playerId, Config.Lang.bottle_refilled, "success")
end)

RegisterNetEvent("envi-dumpsters:server:DrinkBottle", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    local isHobo = player.Job.Name == Config.HoboJobRole

    local thirst = player.GetStatus("thirst")
    local hydration = Config.ItemSettings.hobo_bottle.hydration
    if not hydration then
        hydration = 20
    end
    player.SetStatus("thirst", thirst + hydration)

    if not isHobo then
        player.SetStatus("hunger", player.GetStatus("hunger") - 10)
        Framework.Notify(playerId, Config.Lang.feel_sick, "error")
        TriggerClientEvent("envi-dumpsters:client:DrinkBottleBadEffect", playerId)
    else
        player.SetStatus("hunger", player.GetStatus("hunger") + 3)
        Framework.Notify(playerId, Config.Lang.feel_refreshed, "success")
        TriggerClientEvent("envi-dumpsters:client:DrinkBottleGoodEffect", playerId)
    end
end)

Framework.CreateUseableItem("rat_bait", function(source)
    local removed = Framework.RemoveItem(source, "rat_bait", 1)
    if removed then
        TriggerClientEvent("envi-dumpsters:client:useRatBait", source)
    end
end)

RegisterNetEvent("envi-dumpsters:server:PickUpCardboardBed", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    Framework.AddItem(playerId, "cardboard_bed", 1)
end)

RegisterNetEvent("envi-dumpsters:server:PickUpSleepingBag", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    Framework.AddItem(playerId, "sleeping_bag", 1)
end)

RegisterNetEvent("envi-dumpsters:server:PickUpTent", function(tentData)
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    Framework.AddItem(playerId, "hobo_tent", 1, tentData)
end)

Framework.CreateUseableItem("medical_care_package", function(source)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    local progression = GetPlayerProgression(player.Identifier)
    if progression then
        if progression.level == 6 then
            local missionData = progression.mission_data[6]
            if not missionData then
                missionData = {}
            end

            if missionData.package_found then
                if not missionData.package_delivered then
                    Framework.Notify(source, Config.Lang.take_medical_package, "info")
                end
            end
        end
    else
        Framework.Notify(source, Config.Lang.valuable_medical_supplies, "info")
    end
end)

RegisterNetEvent("envi-dumpsters:server:UseRatTreats", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    Framework.RemoveItem(playerId, "rat_treats", 1)
    Framework.Notify(playerId, Config.Lang.rat_treats_used, "success")
end)

Framework.CreateCallback("envi-dumpsters:server:OpenBackpack", function(source, cb, data)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    if player.Job.Name ~= Config.HoboJobRole then
        Framework.Notify(source, Config.Lang.not_hobo, "error")
        cb(false)
        return
    end

    local backpackID = data or Config.HoboJobRole
    if data then
        backpackID = data.backpackID
    end

    if not backpackID then
        cb(false)
        return
    end

    Framework.RegisterStash(data.backpackID, 30, 100000, nil, { [Config.HoboJobRole] = 0 })
    cb(true)
end)

Framework.CreateCallback("envi-dumpsters:server:OpenTent", function(source, cb, data)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    if player.Job.Name ~= Config.HoboJobRole then
        Framework.Notify(source, Config.Lang.not_hobo, "error")
        cb(false)
        return
    end

    local tentID = data or Config.HoboJobRole
    if data then
        tentID = data.tentID
    end

    if not tentID then
        cb(false)
        return
    end

    Framework.RegisterStash(data.tentID, 60, 200000, nil, { [Config.HoboJobRole] = 0 })
    cb(true)
end)
