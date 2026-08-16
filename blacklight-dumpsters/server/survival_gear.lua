--[[ ==========================================================================
     BlackLight Dumpsters — Survival Gear Items (server)
========================================================================== ]]

local random = math.random

local DEPLOY_EVENT = "bl_dumpsters:client:DeployGear"

-- --------------------------------------------------------------------------
--  BEDDING
-- --------------------------------------------------------------------------

Framework.CreateUseableItem("cardboard_bed", function(source)
    if not GuardRate(source, "use_bedding", 1000) then
        return
    end

    if Framework.RemoveItem(source, "cardboard_bed", 1) then
        TriggerClientEvent(DEPLOY_EVENT, source, "cardboard_bed")
    end
end)

Framework.CreateUseableItem("sleeping_bag", function(source)
    if not GuardRate(source, "use_bedding", 1000) then
        return
    end

    if Framework.RemoveItem(source, "sleeping_bag", 1) then
        TriggerClientEvent(DEPLOY_EVENT, source, "sleeping_bag")
    end
end)

RegisterNetEvent("bl_dumpsters:server:RetrieveCardboardBed", function()
    local playerSource = source
    if not Framework.GetPlayer(playerSource) then
        return
    end

    if not GuardRate(playerSource, "retrieve_bedding", 1000) then
        return
    end

    Framework.AddItem(playerSource, "cardboard_bed", 1)
end)

RegisterNetEvent("bl_dumpsters:server:RetrieveSleepingBag", function()
    local playerSource = source
    if not Framework.GetPlayer(playerSource) then
        return
    end

    if not GuardRate(playerSource, "retrieve_bedding", 1000) then
        return
    end

    Framework.AddItem(playerSource, "sleeping_bag", 1)
end)

-- --------------------------------------------------------------------------
--  SHELTER (tent)
-- --------------------------------------------------------------------------

--- Reads the shelter id out of an inventory item's metadata, if present.
local function ReadShelterId(itemData)
    if type(itemData) ~= "table" then
        return nil
    end
    return itemData.metadata and itemData.metadata.tentID or nil
end

Framework.CreateUseableItem("hobo_tent", function(source, itemName, itemData)
    if not GuardRate(source, "use_shelter", 1000) then
        return
    end

    local player = Framework.GetPlayer(source)
    if not player or type(itemData) ~= "table" then
        return
    end

    local shelterId = ReadShelterId(itemData)

    -- First deployment: brand the tent with a unique persistent id.
    if not shelterId then
        local newShelterId = player.Identifier .. Framework.RandomString(5) .. Framework.RandomInteger(5)

        Framework.SetItemMetadata(source, itemData.slot, { tentID = newShelterId })
        Framework.Notify(source, Settings.Text.home_sweet_home, "success")

        if Framework.RemoveItem(source, "hobo_tent", 1, nil, itemData.slot) then
            TriggerClientEvent(DEPLOY_EVENT, source, "hobo_tent", { tentID = newShelterId })
        end

        return
    end

    if Framework.RemoveItem(source, "hobo_tent", 1, itemData.metadata, itemData.slot) then
        TriggerClientEvent(DEPLOY_EVENT, source, "hobo_tent", itemData.metadata)
    end
end)

RegisterNetEvent("bl_dumpsters:server:RetrieveShelter", function(shelterData)
    local playerSource = source
    if not Framework.GetPlayer(playerSource) then
        return
    end

    if not GuardRate(playerSource, "retrieve_shelter", 1000) then
        return
    end

    Framework.AddItem(playerSource, "hobo_tent", 1, shelterData)
end)

Framework.CreateCallback("bl_dumpsters:server:OpenShelterStash", function(source, cb, data)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    if player.Job.Name ~= Settings.VagrantJobName then
        Framework.Notify(source, Settings.Text.not_a_scavenger, "error")
        return cb(false)
    end

    local shelterId = type(data) == "table" and data.tentID or nil
    if not shelterId then
        return cb(false)
    end

    Framework.RegisterStash(shelterId, 60, 200000, nil, { [Settings.VagrantJobName] = 0 })
    cb(true)
end)

Framework.CreateCallback("bl_dumpsters:server:OpenPackStash", function(source, cb, data)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    if player.Job.Name ~= Settings.VagrantJobName then
        Framework.Notify(source, Settings.Text.not_a_scavenger, "error")
        return cb(false)
    end

    local packId = type(data) == "table" and data.backpackID or nil
    if not packId then
        return cb(false)
    end

    Framework.RegisterStash(packId, 30, 100000, nil, { [Settings.VagrantJobName] = 0 })
    cb(true)
end)

-- --------------------------------------------------------------------------
--  FLASK
-- --------------------------------------------------------------------------

Framework.CreateUseableItem("hobo_bottle", function(source, itemName, itemData)
    if not GuardRate(source, "use_flask", 1000) then
        return
    end

    if type(itemData) ~= "table" then
        return
    end

    local capacity = Settings.GearBehaviour.hobo_bottle.charges
    local charges = itemData.metadata and itemData.metadata.uses

    -- Un-branded flask: initialise its charge counter on first sip.
    if not charges then
        Framework.SetItemMetadata(source, itemData.slot, { uses = capacity - 1 })
        TriggerClientEvent(DEPLOY_EVENT, source, "hobo_bottle")
        Framework.Notify(source, string.format(Settings.Text.charges_left, capacity - 1), "success")
        return
    end

    if charges > 0 then
        Framework.SetItemMetadata(source, itemData.slot, { uses = charges - 1 })
        TriggerClientEvent(DEPLOY_EVENT, source, "hobo_bottle", itemData.metadata)
        Framework.Notify(source, string.format(Settings.Text.charges_left, charges - 1), "success")
        return
    end

    Framework.Notify(source, Settings.Text.flask_dry, "error")
end)

RegisterNetEvent("bl_dumpsters:server:TopUpFlask", function(slot)
    local playerSource = source
    if not Framework.GetPlayer(playerSource) then
        return
    end

    if not GuardRate(playerSource, "top_up_flask", 5000) then
        return
    end

    Framework.SetItemMetadata(playerSource, slot, { uses = Settings.GearBehaviour.hobo_bottle.charges })
    Framework.Notify(playerSource, Settings.Text.flask_topped_up, "success")
end)

RegisterNetEvent("bl_dumpsters:server:SipFlask", function()
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "sip_flask", 1000) then
        return
    end

    local committed = player.Job.Name == Settings.VagrantJobName
    local hydration = Settings.GearBehaviour.hobo_bottle.hydration or 20

    -- Framework contract — GetStatus / SetStatus are core APIs.
    player.SetStatus("thirst", player.GetStatus("thirst") + hydration)

    if committed then
        player.SetStatus("hunger", player.GetStatus("hunger") + 3)
        Framework.Notify(playerSource, Settings.Text.feeling_restored, "success")
        TriggerClientEvent("bl_dumpsters:client:FlaskVigour", playerSource)
    else
        player.SetStatus("hunger", player.GetStatus("hunger") - 10)
        Framework.Notify(playerSource, Settings.Text.stomach_turns, "error")
        TriggerClientEvent("bl_dumpsters:client:FlaskSickness", playerSource)
    end
end)

-- --------------------------------------------------------------------------
--  RATION PACK
-- --------------------------------------------------------------------------

local RATION_CONTENTS = Settings.GearBehaviour.ration_pack.yields

Framework.CreateUseableItem("ration_pack", function(source)
    if not GuardRate(source, "use_ration", 1000) then
        return
    end

    if not Framework.RemoveItem(source, "ration_pack", 1) then
        return
    end

    TriggerClientEvent(DEPLOY_EVENT, source, "ration_pack")

    for _, entry in ipairs(RATION_CONTENTS) do
        Framework.AddItem(source, entry.item, random(1, entry.max))
    end
end)

-- --------------------------------------------------------------------------
--  PLACARD
-- --------------------------------------------------------------------------

Framework.CreateUseableItem("begging_sign", function(source)
    if not GuardRate(source, "use_placard", 1000) then
        return
    end

    TriggerClientEvent(DEPLOY_EVENT, source, "begging_sign")
end)

-- --------------------------------------------------------------------------
--  RODENT CONTROL
-- --------------------------------------------------------------------------

Framework.CreateUseableItem("rat_bait", function(source)
    if not GuardRate(source, "use_bait", 2000) then
        return
    end

    if Framework.RemoveItem(source, "rat_bait", 1) then
        TriggerClientEvent("bl_dumpsters:client:DeployRodentBait", source)
    end
end)

RegisterNetEvent("bl_dumpsters:server:ConsumeRodentTreats", function()
    local playerSource = source
    if not Framework.GetPlayer(playerSource) then
        return
    end

    if not GuardRate(playerSource, "consume_treats", 1000) then
        return
    end

    if not GuardInventory(playerSource, "rat_treats", 1) then
        return
    end

    Framework.RemoveItem(playerSource, "rat_treats", 1)
    Framework.Notify(playerSource, Settings.Text.treats_consumed, "success")
end)

-- --------------------------------------------------------------------------
--  MEDICAL PARCEL
-- --------------------------------------------------------------------------

Framework.CreateUseableItem("medical_care_package", function(source)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    local standing = FetchStanding(player.Identifier)

    if not standing then
        Framework.Notify(source, Settings.Text.looks_valuable, "info")
        return
    end

    if standing.level ~= 6 then
        Framework.Notify(source, Settings.Text.looks_valuable, "info")
        return
    end

    local chapterState = standing.mission_data[6] or {}

    if chapterState.package_found and not chapterState.package_delivered then
        Framework.Notify(source, Settings.Text.deliver_the_parcel, "info")
    end
end)
