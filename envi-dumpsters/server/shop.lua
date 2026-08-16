Framework.CreateCallback("envi-dumpsters:server:BuyHoboItem", function(source, cb, itemKey, itemName, quantity)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local bottleCapItem = Config.BottleCapItem or "bottle_cap"
    local capCount = Framework.GetItemCount(source, bottleCapItem)
    if quantity > capCount then
        return cb(false, Config.Lang.not_enough_caps)
    end

    local identifier = player.Identifier
    local playerLevel = GetPlayerProgression(identifier).level
    local requiredLevel = GetItemLevel(itemKey)
    if requiredLevel > playerLevel then
        return cb(false, Config.Lang.level_too_low)
    end

    local removed = Framework.RemoveItem(source, bottleCapItem, quantity)
    if not removed then
        return cb(false, Config.Lang.failed_remove_caps)
    end

    local added = Framework.AddItem(source, itemName, quantity)
    if not added then
        Framework.AddItem(source, bottleCapItem, quantity)
        return cb(false, Config.Lang.failed_add_item)
    end

    AddHoboXP(identifier, quantity)
    return cb(true, string.format(Config.Lang.purchased_quantity, itemName, itemKey, quantity))
end)

function GetItemLevel(itemName)
    for level, items in pairs(Config.Unlockables) do
        for _, item in ipairs(items) do
            if item.name == itemName then
                return level
            end
        end
    end
    return 10
end

Framework.CreateCallback("envi-dumpsters:server:HasItem", function(source, cb, itemName)
    cb(Framework.HasItem(source, itemName))
end)

RegisterNetEvent("envi-dumpsters:server:RemoveItem", function(itemName, count)
    Framework.RemoveItem(source, itemName, count)
end)

local beggingLocked = false
local BEG_COOLDOWN_MS = 2000

Framework.CreateCallback("envi-dumpsters:server:DoCooldown", function(source, cb, hasSign)
    local player = Framework.GetPlayer(source)

    local reward = math.random(1, Config.BeggingSettings.MaxBaseReward)
    if hasSign then
        reward = reward * Config.BeggingSettings.BegWithSignMultiplier
    end

    if player.Job.Name == Config.HoboJobRole then
        reward = reward * Config.BeggingSettings.TrueHoboMultiplier
    end

    if reward > Config.BeggingSettings.MaxTotalReward then
        reward = Config.BeggingSettings.MaxTotalReward
    end

    if not player then
        return
    end

    if beggingLocked then
        reward = 1
        return
    end

    player.AddMoney("cash", reward)
    beggingLocked = true

    local identifier = player.Identifier
    local progression = GetPlayerProgression(identifier)
    if progression.level == 3 then
        local missionData = progression.mission_data[3] or {}
        missionData.money_collected = (missionData.money_collected or 0) + reward
        UpdateMissionProgress(identifier, 3, missionData)

        Framework.Notify(source, string.format(Config.Lang.begging_progress, missionData.money_collected, Config.Missions[3].RequiredAmount), "info")

        if missionData.money_collected >= Config.Missions[3].RequiredAmount then
            CompleteMission(identifier, 3)
            Framework.Notify(source, Config.Lang.collected_enough_money, "success")
        end
    end

    TriggerEvent("envi-dumpsters:server:BeggingReceived", source, reward)

    SetTimeout(BEG_COOLDOWN_MS, function()
        beggingLocked = false
    end)

    cb(reward)
end)

Framework.CreateCallback("envi-dumpsters:server:DeliverMedicalPackage", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local hasPackage = Framework.GetItemCount(source, "medical_care_package") > 0
    if not hasPackage then
        return cb(false, Config.Lang.no_medical_package)
    end

    Framework.RemoveItem(source, "medical_care_package", 1)

    local identifier = player.Identifier
    local progression = GetPlayerProgression(identifier)

    if progression.level == 6 then
        local missionData = progression.mission_data[6] or {}
        missionData.package_delivered = true
        UpdateMissionProgress(identifier, 6, missionData)

        if missionData.dumpsters_searched >= 100 then
            if missionData.package_found then
                if missionData.package_delivered then
                    CompleteMission(identifier, 6)
                    cb(true, Config.Lang.package_delivered_complete)
                end
            end
        else
            cb(true, Config.Lang.package_delivered)
        end
    else
        cb(true, Config.Lang.package_delivered)
    end
end)
