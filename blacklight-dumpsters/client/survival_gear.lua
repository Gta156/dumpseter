--[[ ==========================================================================
     BlackLight Dumpsters — Survival Gear Deployment (client)
     Bedrolls, tents, flasks and ration packs.
========================================================================== ]]

local min = math.min

local gearBusy = false

local REST_DICT = "amb@medic@standing@tendtodead@idle_a"
local REST_CLIP = "idle_a"
local REST_SCENARIO = "WORLD_HUMAN_BUM_SLUMPED"
local STAND_UP_CONTROL = 73
local INTERACT = "blacklight-interact"

--- Shared guard for every gear interaction.
local function GearInteractionAllowed()
    return not gearBusy and not Framework.IsPlayerDead()
end

--- Runs the shared sleep loop on a deployed bedding prop.
---@param prop number Deployed prop.
---@param recovery number HP restored every 3 seconds.
---@param healthCeiling number Health cap this bedding can regenerate to.
local function RestOnBedding(prop, recovery, healthCeiling)
    gearBusy = true

    TaskGoToEntity(cache.ped, prop, 10000, 1.0, 1.0, 0, 0)
    Wait(1000)
    TaskStartScenarioInPlace(cache.ped, REST_SCENARIO, 0, true)
    Wait(1000)

    lib.showTextUI(Settings.Text.stand_up_key, { position = "top-center", icon = "bed" })

    -- Watch for the stand-up key; runs at 0ms only while actually resting.
    CreateThread(function()
        while gearBusy do
            Wait(0)
            if IsControlJustPressed(0, STAND_UP_CONTROL) then
                gearBusy = false
                ClearPedTasks(cache.ped)
                lib.hideTextUI()
            end
        end
    end)

    while gearBusy do
        Wait(3000)

        if IsPedUsingScenario(cache.ped, REST_SCENARIO) then
            local health = GetEntityHealth(cache.ped)
            if health < healthCeiling then
                SetEntityHealth(cache.ped, min(health + recovery, healthCeiling))
            end
        else
            gearBusy = false
            lib.hideTextUI()
        end
    end
end

--- Places a prop in front of / underneath the player and returns the handle.
local function DeployProp(modelHash, forwardOffset)
    Framework.LoadModel(modelHash)
    Framework.LoadAnimDict(REST_DICT)
    TaskPlayAnim(cache.ped, REST_DICT, REST_CLIP, 8.0, 8.0, -1, 1, 0, false, false, false)
    Wait(2000)

    local coords = GetEntityCoords(cache.ped)
    local prop

    if forwardOffset and forwardOffset > 0 then
        local forward = GetEntityForwardVector(cache.ped)
        prop = CreateObject(modelHash,
            coords.x + forward.x * forwardOffset,
            coords.y + forward.y * forwardOffset,
            coords.z + forward.z * forwardOffset,
            true, true, false)
    else
        prop = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
    end

    PlaceObjectOnGroundProperly(prop)
    ClearPedTasks(cache.ped)

    while not DoesEntityExist(prop) do
        Wait(0)
    end

    return prop
end

--- Registers "rest" / "collect" interactions on a deployed bedding prop.
local function RegisterBeddingInteractions(prop, restHandler, collectHandler, interactionName)
    if Settings.UseTargetSystem then
        Target.AddEntity(prop, {
            {
                name = interactionName .. "_rest",
                icon = "fas fa-bed",
                label = Settings.Text.rest,
                distance = 2.0,
                canInteract = GearInteractionAllowed,
                onSelect = restHandler,
            },
            {
                name = interactionName .. "_collect",
                icon = "fas fa-bed",
                label = Settings.Text.collect,
                distance = 2.0,
                canInteract = GearInteractionAllowed,
                onSelect = collectHandler,
            },
        })
        return
    end

    exports[INTERACT]:InteractionEntity(prop, {
        {
            name = interactionName,
            distance = 2.0,
            radius = 5.0,
            options = {
                { label = Settings.Text.rest_key, selected = restHandler },
                { label = Settings.Text.collect_key, selected = collectHandler },
            },
        },
    })
end

--- Packs a bedding prop back into the player's inventory.
local function CollectBedding(prop, retrieveEvent)
    DeleteObject(prop)
    gearBusy = true

    Framework.LoadAnimDict(REST_DICT)
    TaskPlayAnim(cache.ped, REST_DICT, REST_CLIP, 8.0, 8.0, -1, 1, 0, false, false, false)
    TriggerServerEvent(retrieveEvent)
    Wait(2000)

    ClearPedTasks(cache.ped)
    gearBusy = false
end

-- --------------------------------------------------------------------------
--  ITEM HANDLERS
-- --------------------------------------------------------------------------

local gearHandlers = {}

gearHandlers.cardboard_bed = function()
    local prop = DeployProp(GetHashKey(Settings.GearBehaviour.cardboard_bed.model))
    local recovery = Settings.GearBehaviour.cardboard_bed.recovery or 1

    RegisterBeddingInteractions(prop,
        function() RestOnBedding(prop, recovery, 150) end,
        function() CollectBedding(prop, "bl_dumpsters:server:RetrieveCardboardBed") end,
        "bl_cardboard_bed"
    )
end

gearHandlers.sleeping_bag = function()
    local prop = DeployProp(GetHashKey(Settings.GearBehaviour.sleeping_bag.model))
    local recovery = Settings.GearBehaviour.sleeping_bag.recovery or 2

    RegisterBeddingInteractions(prop,
        function() RestOnBedding(prop, recovery, 170) end,
        function() CollectBedding(prop, "bl_dumpsters:server:RetrieveSleepingBag") end,
        "bl_sleeping_bag"
    )
end

gearHandlers.hobo_tent = function(gearData)
    local prop = DeployProp(GetHashKey("prop_skid_tent_cloth"), 1.0)
    SetEntityAsMissionEntity(prop, true, true)
    SetEntityInvincible(prop, true)

    local recovery = Settings.GearBehaviour.hobo_tent.recovery or 5

    local function OpenTentStash()
        Framework.TriggerCallback("bl_dumpsters:server:OpenShelterStash", function(allowed)
            if allowed then
                Framework.OpenStash(gearData.tentID)
            end
        end, gearData)
    end

    local function RestInTent()
        RestOnBedding(prop, recovery, 200)
    end

    local function CollectTent()
        gearBusy = true
        DeleteObject(prop)

        Framework.LoadAnimDict(REST_DICT)
        TaskPlayAnim(cache.ped, REST_DICT, REST_CLIP, 8.0, 8.0, -1, 1, 0, false, false, false)
        Wait(2000)

        ClearPedTasks(cache.ped)
        TriggerServerEvent("bl_dumpsters:server:RetrieveShelter", gearData)
        gearBusy = false
    end

    if Settings.UseTargetSystem then
        Target.AddEntity(prop, {
            {
                name = "bl_shelter_stash",
                icon = "fas fa-tent",
                label = Settings.Text.open_container,
                distance = 1.5,
                canInteract = GearInteractionAllowed,
                onSelect = OpenTentStash,
            },
            {
                name = "bl_shelter_rest",
                label = Settings.Text.rest,
                icon = "fas fa-bed",
                distance = 1.5,
                onSelect = RestInTent,
            },
            {
                name = "bl_shelter_collect",
                label = Settings.Text.collect,
                icon = "fas fa-arrow-up-right-from-square",
                distance = 1.5,
                onSelect = CollectTent,
            },
        })
    else
        exports[INTERACT]:InteractionEntity(prop, {
            {
                name = "bl_shelter_interaction",
                distance = 2.0,
                options = {
                    { label = Settings.Text.open_container_key, selected = OpenTentStash },
                    { label = Settings.Text.rest_key, selected = RestInTent },
                    { label = Settings.Text.collect_key, selected = CollectTent },
                },
            },
        })
    end
end

gearHandlers.hobo_bottle = function()
    if gearBusy then
        return
    end

    gearBusy = true

    local clipDict = "mp_player_intdrink"
    local clipName = "loop_bottle"
    local propModel = "p_cs_bottle_01"
    local boneId = 60309

    Framework.LoadAnimDict(clipDict)

    local coords = GetEntityCoords(cache.ped)
    local flask = CreateObject(GetHashKey(propModel), coords.x, coords.y, coords.z + 0.2, true, true, true)

    AttachEntityToEntity(flask, cache.ped, GetPedBoneIndex(cache.ped, boneId), 0.0, 0.0, -0.05, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    TaskPlayAnim(cache.ped, clipDict, clipName, 8.0, -8.0, -1, 49, 0, false, false, false)
    Wait(3000)

    DeleteObject(flask)
    ClearPedTasks(cache.ped)
    TriggerServerEvent("bl_dumpsters:server:SipFlask")
    gearBusy = false
end

gearHandlers.ration_pack = function()
    Framework.Notify(Settings.Text.ration_unpacked, "success", 5000)
end

gearHandlers.begging_sign = function()
    ExecuteCommand(Settings.Panhandling.Command)
end

RegisterNetEvent("bl_dumpsters:client:DeployGear", function(itemName, gearData)
    local handler = gearHandlers[itemName]
    if handler then
        handler(gearData)
    end
end)
