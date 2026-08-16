local isSleeping = false

RegisterNetEvent("envi-dumpsters:client:UseItem", function(itemName, itemData)
    if itemName == "cardboard_bed" then
        local animDict = "amb@medic@standing@tendtodead@idle_a"
        local animName = "idle_a"
        local modelHash = GetHashKey(Config.ItemSettings.cardboard_bed.model)
        local spawnCoords = GetEntityCoords(Store.Ped)

        Framework.LoadModel(modelHash)
        Framework.LoadAnimDict(animDict)
        TaskPlayAnim(Store.Ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
        Wait(2000)

        local prop = CreateObject(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true, false)
        PlaceObjectOnGroundProperly(prop)
        ClearPedTasks(Store.Ped)

        while not DoesEntityExist(prop) do
            Wait(0)
        end

        local function CanSleepOrPickUp()
            return not isSleeping and not Framework.IsPlayerDead()
        end

        local function SleepOnBed()
            isSleeping = true
            TaskGoToEntity(Store.Ped, prop, 10000, 1.0, 1.0, 0, 0)
            Wait(1000)
            TaskStartScenarioInPlace(Store.Ped, "WORLD_HUMAN_BUM_SLUMPED", 0, true)
            Wait(1000)
            lib.showTextUI(Config.Lang.get_up, { position = "top-center", icon = "bed" })

            CreateThread(function()
                while isSleeping do
                    Wait(0)
                    if IsControlJustPressed(0, 73) then
                        isSleeping = false
                        ClearPedTasks(Store.Ped)
                        lib.hideTextUI()
                    end
                end
            end)

            local regen = Config.ItemSettings.cardboard_bed.regeneration or 1
            while isSleeping do
                Wait(3000)
                if IsPedUsingScenario(Store.Ped, "WORLD_HUMAN_BUM_SLUMPED") then
                    local health = GetEntityHealth(Store.Ped)
                    if health < 150 then
                        SetEntityHealth(Store.Ped, math.min(health + regen, 150))
                    end
                else
                    isSleeping = false
                    lib.hideTextUI()
                end
            end
        end

        local function PickUpBed()
            DeleteObject(prop)
            isSleeping = true
            Framework.LoadAnimDict(animDict)
            TaskPlayAnim(Store.Ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
            TriggerServerEvent("envi-dumpsters:server:PickUpCardboardBed")
            Wait(2000)
            ClearPedTasks(Store.Ped)
            isSleeping = false
        end

        if Config.Target then
            Target.AddEntity(prop, {
                {
                    name = "Sleep",
                    icon = "fas fa-bed",
                    label = Config.Lang.sleep,
                    distance = 2.0,
                    canInteract = CanSleepOrPickUp,
                    onSelect = SleepOnBed,
                },
                {
                    icon = "fas fa-bed",
                    label = Config.Lang.pick_up,
                    distance = 2.0,
                    canInteract = CanSleepOrPickUp,
                    onSelect = PickUpBed,
                },
            })
        else
            exports["envi-interact"]:InteractionEntity(prop, {
                {
                    name = "cardboard_bed_interaction",
                    distance = 2.0,
                    radius = 5.0,
                    options = {
                        { label = Config.Lang.sleep_e, selected = SleepOnBed },
                        { label = Config.Lang.pick_up_e, selected = PickUpBed },
                    },
                },
            })
        end
    elseif itemName == "sleeping_bag" then
        local animDict = "amb@medic@standing@tendtodead@idle_a"
        local animName = "idle_a"
        local modelHash = GetHashKey("prop_skid_sleepbag_1")
        local spawnCoords = GetEntityCoords(Store.Ped)

        Framework.LoadModel(modelHash)
        Framework.LoadAnimDict(animDict)
        TaskPlayAnim(Store.Ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
        Wait(2000)

        local prop = CreateObject(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, true, true, false)
        PlaceObjectOnGroundProperly(prop)
        ClearPedTasks(Store.Ped)

        local function CanSleepOrPickUp()
            return not isSleeping and not Framework.IsPlayerDead()
        end

        local function SleepOnBag()
            isSleeping = true
            TaskGoToEntity(Store.Ped, prop, 10000, 1.0, 1.0, 0, 0)
            Wait(1000)
            TaskStartScenarioInPlace(Store.Ped, "WORLD_HUMAN_BUM_SLUMPED", 0, true)
            Wait(1000)
            lib.showTextUI(Config.Lang.get_up, { position = "top-center", icon = "bed" })

            CreateThread(function()
                while isSleeping do
                    Wait(0)
                    if IsControlJustPressed(0, 73) then
                        isSleeping = false
                        ClearPedTasks(Store.Ped)
                        lib.hideTextUI()
                    end
                end
            end)

            local regen = Config.ItemSettings.sleeping_bag.regeneration or 2
            while isSleeping do
                Wait(3000)
                if IsPedUsingScenario(Store.Ped, "WORLD_HUMAN_BUM_SLUMPED") then
                    local health = GetEntityHealth(Store.Ped)
                    if health < 170 then
                        SetEntityHealth(Store.Ped, math.min(health + regen, 170))
                    end
                else
                    isSleeping = false
                    lib.hideTextUI()
                end
            end
        end

        local function PickUpBag()
            DeleteObject(prop)
            isSleeping = true
            Framework.LoadAnimDict(animDict)
            TaskPlayAnim(Store.Ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
            TriggerServerEvent("envi-dumpsters:server:PickUpSleepingBag")
            Wait(2000)
            ClearPedTasks(Store.Ped)
            isSleeping = false
        end

        if Config.Target then
            Target.AddEntity(prop, {
                {
                    name = "Sleep",
                    icon = "fas fa-bed",
                    label = Config.Lang.sleep,
                    distance = 2.0,
                    canInteract = CanSleepOrPickUp,
                    onSelect = SleepOnBag,
                },
                {
                    icon = "fas fa-bed",
                    label = Config.Lang.pick_up,
                    distance = 2.0,
                    canInteract = CanSleepOrPickUp,
                    onSelect = PickUpBag,
                },
            })
        else
            exports["envi-interact"]:InteractionEntity(prop, {
                {
                    name = "sleeping_bag_interaction",
                    distance = 2.0,
                    radius = 5.0,
                    options = {
                        { label = Config.Lang.sleep_e, selected = SleepOnBag },
                        { label = Config.Lang.pick_up_e, selected = PickUpBag },
                    },
                },
            })
        end
    elseif itemName == "hobo_tent" then
        local animDict = "amb@medic@standing@tendtodead@idle_a"
        local animName = "idle_a"
        local modelHash = GetHashKey("prop_skid_tent_cloth")
        local pedCoords = GetEntityCoords(Store.Ped)

        Framework.LoadModel(modelHash)
        Framework.LoadAnimDict(animDict)
        TaskPlayAnim(Store.Ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
        Wait(2000)

        local forward = GetEntityForwardVector(Store.Ped)
        local prop = CreateObject(modelHash, pedCoords.x + forward.x * 1.0, pedCoords.y + forward.y * 1.0, pedCoords.z + forward.z * 1.0, true, true, false)
        PlaceObjectOnGroundProperly(prop)
        SetEntityAsMissionEntity(prop, true, true)
        SetEntityInvincible(prop, true)
        ClearPedTasks(Store.Ped)

        while not DoesEntityExist(prop) do
            Wait(0)
        end

        local function CanSleepOrPickUp()
            return not isSleeping and not Framework.IsPlayerDead()
        end

        local function OpenTentStash()
            Framework.TriggerCallback("envi-dumpsters:server:OpenTent", function(opened)
                if opened then
                    Framework.OpenStash(itemData.tentID)
                end
            end, itemData)
        end

        local function SleepInTent()
            isSleeping = true
            TaskGoToEntity(Store.Ped, prop, 10000, 1.0, 0.5, 1.0, 0)
            Wait(1000)
            TaskStartScenarioInPlace(Store.Ped, "WORLD_HUMAN_BUM_SLUMPED", 0, true)
            Wait(1000)
            lib.showTextUI(Config.Lang.get_up, { position = "top-center", icon = "bed" })

            CreateThread(function()
                while isSleeping do
                    Wait(0)
                    if IsControlJustPressed(0, 73) then
                        isSleeping = false
                        ClearPedTasks(Store.Ped)
                        lib.hideTextUI()
                    end
                end
            end)

            local regen = Config.ItemSettings.hobo_tent.regeneration or 5
            while isSleeping do
                Wait(3000)
                if IsPedUsingScenario(Store.Ped, "WORLD_HUMAN_BUM_SLUMPED") then
                    local health = GetEntityHealth(Store.Ped)
                    if health < 200 then
                        SetEntityHealth(Store.Ped, math.min(health + regen, 200))
                    end
                else
                    isSleeping = false
                    lib.hideTextUI()
                end
            end
        end

        local function PickUpTent()
            isSleeping = true
            DeleteObject(prop)
            Framework.LoadAnimDict(animDict)
            TaskPlayAnim(Store.Ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
            Wait(2000)
            ClearPedTasks(Store.Ped)
            TriggerServerEvent("envi-dumpsters:server:PickUpTent", itemData)
            isSleeping = false
        end

        if Config.Target then
            Target.AddEntity(prop, {
                {
                    name = "TentInteraction",
                    icon = "fas fa-tent",
                    label = Config.Lang.open_stash,
                    distance = 1.5,
                    canInteract = CanSleepOrPickUp,
                    onSelect = OpenTentStash,
                },
                {
                    label = Config.Lang.sleep,
                    icon = "fas fa-bed",
                    distance = 1.5,
                    onSelect = SleepInTent,
                },
                {
                    label = Config.Lang.pick_up,
                    icon = "fas fa-arrow-up-right-from-square",
                    distance = 1.5,
                    onSelect = PickUpTent,
                },
            })
        else
            exports["envi-interact"]:InteractionEntity(prop, {
                {
                    name = "TentInteraction",
                    distance = 2.0,
                    options = {
                        { label = Config.Lang.open_stash_e, selected = OpenTentStash },
                        { label = Config.Lang.sleep_e, selected = SleepInTent },
                        { label = Config.Lang.pick_up_e, selected = PickUpTent },
                    },
                },
            })
        end
    elseif itemName == "hobo_bottle" then
        if isSleeping then
            return
        end

        local animDict = "mp_player_intdrink"
        local animName = "loop_bottle"
        local propModel = "p_cs_bottle_01"
        local boneId = 60309
        local boneOffset = vector3(0.0, 0.0, 0.0)
        local boneRotation = vector3(0.0, 0.0, 0.0)

        isSleeping = true
        Framework.LoadAnimDict(animDict)

        local pedCoords = GetEntityCoords(Store.Ped)
        local bottle = CreateObject(GetHashKey(propModel), pedCoords.x, pedCoords.y, pedCoords.z + 0.2, true, true, true)
        local boneIndex = GetPedBoneIndex(Store.Ped, boneId)

        AttachEntityToEntity(bottle, Store.Ped, boneIndex, boneOffset.x, boneOffset.y, boneOffset.z - 0.05, boneRotation.x, boneRotation.y, boneRotation.z, true, true, false, true, 1, true)
        TaskPlayAnim(Store.Ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
        Wait(3000)

        DeleteObject(bottle)
        ClearPedTasks(Store.Ped)
        TriggerServerEvent("envi-dumpsters:server:DrinkBottle")
        isSleeping = false
    elseif itemName == "ration_pack" then
        Framework.Notify(Config.Lang.ration_opened, "success", 5000)
    elseif itemName == "begging_sign" then
        ExecuteCommand(Config.BeggingSettings.BegCommand)
    end
end)
