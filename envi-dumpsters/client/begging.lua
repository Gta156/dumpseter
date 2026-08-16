local approachingPeds = {}
local isOnBegCooldown = false
local isBegging = false
local ignoredPeds = {}
local beggingProp = nil
local cleaningVehicles = {}

local function deleteBeggingProp()
    if beggingProp then
        if DoesEntityExist(beggingProp) then
            DeleteObject(beggingProp)
            beggingProp = nil
        end
    end
end

local function waitForPedToApproach(ped)
    local arrived = false
    local attempts = 0

    table.insert(approachingPeds, ped)

    TaskGoToEntity(ped, cache.ped, -1, 1.0, 0.5, 0, 0)

    CreateThread(function()
        while true do
            local pedCoords = GetEntityCoords(ped)
            local playerCoords = GetEntityCoords(cache.ped)
            local distance = #(pedCoords - playerCoords)
            if distance < 1.0 then
                arrived = true
                break
            end
            if not DoesEntityExist(ped) then
                break
            end
            Wait(1000)
        end
    end)

    while not arrived do
        Wait(1000)
        attempts = attempts + 1
        if attempts > 20 then
            break
        end
    end

    for index, queuedPed in ipairs(approachingPeds) do
        if queuedPed == ped then
            table.remove(approachingPeds, index)
            break
        end
    end

    return arrived
end

local function findNearestPed(coords, radius)
    local peds = Framework.GetPeds()
    local nearestPed = nil
    local nearestCoords = nil

    if not radius then
        radius = 2.0
    end

    for i = 1, #peds, 1 do
        local ped = peds[i]
        if not IsPedAPlayer(ped) then
            if not IsEntityPositionFrozen(ped) then
                local pedCoords = GetEntityCoords(ped)
                local distance = #(coords - pedCoords)
                if radius > distance then
                    if not ignoredPeds[ped] then
                        radius = distance
                        nearestPed = ped
                        nearestCoords = pedCoords
                    end
                end
            end
        end
    end

    return nearestPed, nearestCoords
end

local function beggingLoop(hasSign)
    Wait(math.random(1000, 5000))

    while true do
        if not isBegging then
            break
        end

        local nearestPed = findNearestPed(GetEntityCoords(cache.ped), 30.0)
        if nearestPed then
            if not ignoredPeds[nearestPed] then
                local ignoreRoll = math.random(1, 100)
                if ignoreRoll >= Config.BeggingSettings.IgnoreChance then
                    local pedCoords = GetEntityCoords(nearestPed)
                    local playerCoords = GetEntityCoords(cache.ped)
                    local distance = #(pedCoords - playerCoords)
                    local aggressiveRoll = math.random(1, 100)

                    if distance < 5.0 then
                        ignoredPeds[nearestPed] = true
                        TaskTurnPedToFaceEntity(nearestPed, cache.ped, -1)
                        Wait(math.random(500, 3000))

                        if aggressiveRoll <= Config.BeggingSettings.AggressivePedChance then
                            local refuseRoll = math.random(1, 5)

                            if refuseRoll <= 0 then
                                TaskTurnPedToFaceEntity(nearestPed, cache.ped, 5000)

                                local insults = { "GENERIC_INSULT_HIGH", "GENERIC_INSULT_MED", "GENERIC_SHOCKED_HIGH" }
                                PlayPedAmbientSpeechNative(nearestPed, insults[math.random(#insults)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")

                                SetPedAsNoLongerNeeded(nearestPed)
                                print(Config.Lang.ped_refuse_help)

                                ClearPedTasks(cache.ped)
                                isBegging = false
                                deleteBeggingProp()
                                break
                            else
                                local combatRoll = math.random(1, 2)

                                if 1 == combatRoll then
                                    local insults = { "GENERIC_INSULT_HIGH", "GENERIC_INSULT_MED", "GENERIC_SHOCKED_HIGH" }
                                    PlayPedAmbientSpeechNative(nearestPed, insults[math.random(#insults)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")

                                    SetBlockingOfNonTemporaryEvents(nearestPed, true)
                                    TaskGoToEntity(nearestPed, cache.ped, -1, 0.7, 0.5, 0, 0)
                                    Wait(2000)

                                    local animDict = "melee@unarmed@streamed_variations"
                                    local animName = "plyr_takedown_front_slap"
                                    TaskTurnPedToFaceEntity(nearestPed, cache.ped, 2000)
                                    Wait(2000)

                                    Framework.LoadAnimDict(animDict)
                                    TaskPlayAnim(nearestPed, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
                                    Wait(650)

                                    local forward = GetEntityForwardVector(nearestPed)
                                    SetPedToRagdoll(cache.ped, 1000, 5000, 0, true, true, false)
                                    ApplyForceToEntity(cache.ped, 1, forward.x * 3.0, forward.y * 3.0, forward.z * 0.5, 0, 0, 0.1, 0, false, true, true, false, true)
                                    SetPedToRagdoll(cache.ped, 3000, 7000, 0, true, true, false)
                                    Wait(1000)

                                    PlayPedAmbientSpeechNative(nearestPed, insults[math.random(#insults)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
                                    SetPedAsNoLongerNeeded(nearestPed)
                                    TaskSmartFleePed(nearestPed, cache.ped, 1000, -1, true, true)

                                    isBegging = false
                                    deleteBeggingProp()
                                    break
                                else
                                    TaskCombatPed(nearestPed, cache.ped, 0, 16)
                                    Wait(math.random(500, 1500))

                                    ClearPedTasks(cache.ped)
                                    isBegging = false
                                    deleteBeggingProp()
                                    break
                                end
                            end
                            SetPedAsNoLongerNeeded(nearestPed)
                        else
                            local arrived = waitForPedToApproach(nearestPed)
                            if arrived then
                                TaskTurnPedToFaceEntity(nearestPed, cache.ped, -1)
                                PlayPedAmbientSpeechNative(nearestPed, "GENERIC_HOWS_IT_GOING", "SPEECH_PARAMS_DEFAULT")
                                Wait(math.random(0, 1000))

                                local animDict = "mp_common"
                                local animName = "givetake1_a"
                                Framework.LoadAnimDict(animDict)

                                ClearPedTasks(cache.ped)
                                TaskTurnPedToFaceEntity(cache.ped, nearestPed, 2000)
                                Wait(2000)

                                TaskPlayAnim(nearestPed, animDict, animName, 8.0, 8.0, -1, 49, 0, false, false, false)
                                local animDuration = GetAnimDuration(animDict, animName) * 1000
                                Wait(animDuration)

                                ClearPedTasks(nearestPed)
                                SetPedAsNoLongerNeeded(nearestPed)

                                local moneyReceived = Framework.TriggerCallback.Await("envi-dumpsters:server:DoCooldown", hasSign)
                                Framework.Notify(string.format(Config.Lang.begging_received_money, moneyReceived), "success")

                                isOnBegCooldown = true
                                SetTimeout(Config.BeggingSettings.BegCooldown * 1000, function()
                                    isOnBegCooldown = false
                                end)

                                ClearPedTasks(cache.ped)
                                isBegging = false

                                if Config.AggressivePedsAttack then
                                    MakeHobosHateYou(models)
                                end

                                deleteBeggingProp()
                                break
                            end
                        end
                    end
                else
                    local rejectionSpeech = { "GENERIC_NO", "GENERIC_INSULT_HIGH", "GENERIC_INSULT_MED", "GENERIC_SHOCKED_HIGH" }
                    PlayPedAmbientSpeechNative(nearestPed, rejectionSpeech[math.random(#rejectionSpeech)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
                    ignoredPeds[nearestPed] = true
                end
            end
        end

        Wait(5000)
    end
end

RegisterCommand("stopbegging", function()
    isBegging = false

    if IsEntityPlayingAnim(cache.ped, "missheist_agency3aig_24", "agent02_conversation", 3) then
        StopAnimTask(cache.ped, "missheist_agency3aig_24", "agent02_conversation", 3)
    end

    deleteBeggingProp()
    ClearPedTasks(cache.ped)
end, false)

RegisterKeyMapping("stopbegging", Config.Lang.stop_begging, "keyboard", "x")

local beggingSignModels = { -245386275, -533655168, -1109340972, -801803927 }

RegisterCommand(Config.BeggingSettings.BegCommand, function()
    if isOnBegCooldown then
        Framework.Notify(Config.Lang.begging_cooldown, "error")
        return
    end

    if isBegging then
        Framework.Notify(Config.Lang.begging_already_begging, "error")
        return
    end

    local playerPed = cache.ped
    local hasSign = Framework.HasItem("begging_sign", 1)

    if hasSign then
        local animDict = "amb@world_human_bum_freeway@male@idle_a"
        local animName = "idle_a"
        Framework.LoadAnimDict(animDict)
        TaskPlayAnim(playerPed, animDict, animName, 8.0, 8.0, -1, 49, 0, false, false, false)

        local modelHash = beggingSignModels[math.random(#beggingSignModels)]
        RequestModel(modelHash)
        while true do
            if HasModelLoaded(modelHash) then
                break
            end
            Wait(100)
        end

        local prop = CreateObject(modelHash, 0, 0, 0, true, true, true)
        beggingProp = prop
        AttachEntityToEntity(beggingProp, playerPed, GetPedBoneIndex(playerPed, 18905), 0.06397625058889, -0.077691398561, 0.2065776884558, -85.892402648928, 88.618576498046, -11.269510269165, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(modelHash)
    else
        local animDict = "missheist_agency3aig_24"
        local animName = "agent02_conversation"
        Framework.LoadAnimDict(animDict)
        TaskPlayAnim(playerPed, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
    end

    CreateThread(function()
        isBegging = true
        beggingLoop(hasSign)
        deleteBeggingProp()
    end)

    if Config.BeggingSettings.ProgressBar then
        local completed = lib.progressBar({
            duration = 30000,
            label = Config.Lang.begging_progressbar,
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true,
            },
        })

        if completed then
            isBegging = false
            deleteBeggingProp()
        else
            Framework.Notify(Config.Lang.begging_cancelled, "error")
            isBegging = false
            deleteBeggingProp()
        end
    else
        SetTimeout(30000, function()
            if isBegging then
                isBegging = false
                ClearPedTasks(playerPed)
                deleteBeggingProp()
            end
        end)
    end
end, false)

function CleanCar(vehicle)
    if not IsEntityAVehicle(vehicle) then
        return
    end

    local playerPed = PlayerPedId()

    if cleaningVehicles[vehicle] then
        Framework.Notify(Config.Lang.car_already_cleaning or "This car is already clean!", "error")
        return
    end

    cleaningVehicles[vehicle] = true

    local spongeModel = -678752633
    RequestModel(spongeModel)
    while true do
        if HasModelLoaded(spongeModel) then
            break
        end
        Wait(10)
    end

    local spongeProp = CreateObject(spongeModel, 0, 0, 0, true, true, false)
    AttachEntityToEntity(spongeProp, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, -0.01, 90.0, 0.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(spongeModel)

    local animDict = "timetable@floyd@clean_kitchen@base"
    local animName = "base"
    Framework.LoadAnimDict(animDict)
    TaskPlayAnim(playerPed, animDict, animName, 3.0, 3.0, -1, 1, 0, false, false, false)

    local aggressiveRoll = math.random(1, 100) <= Config.BeggingSettings.AggressiveCleanCarChance
    local driverPed = GetPedInVehicleSeat(vehicle, -1)

    if 0 ~= driverPed and aggressiveRoll then
        TaskCombatPed(driverPed, playerPed, 0, 16)
        Wait(math.random(1000, 3000))

        ClearPedTasks(playerPed)
        DeleteEntity(spongeProp)
        return
    end

    local isCleaning = true
    CreateThread(function()
        while true do
            if not isCleaning then
                break
            end
            if IsControlJustPressed(0, 73) then
                isCleaning = false
                break
            end
            Wait(0)
        end
    end)

    local startTime = GetGameTimer()
    local cleanDuration = math.random(Config.BeggingSettings.MinCleanTime * 1000, Config.BeggingSettings.MaxCleanTime * 1000)
    local animCompleted = true

    while isCleaning do
        local elapsed = GetGameTimer() - startTime
        if not (cleanDuration > elapsed) then
            break
        end

        Wait(100)

        if not IsEntityPlayingAnim(playerPed, animDict, animName, 3) then
            animCompleted = false
            break
        end
    end

    DeleteEntity(spongeProp)
    ClearPedTasks(playerPed)

    if not isCleaning or not animCompleted then
        return
    end

    local playerCoords = GetEntityCoords(playerPed)
    local vehicleCoords = GetEntityCoords(vehicle)
    local distance = #(playerCoords - vehicleCoords)
    print(distance)

    if distance <= 4.0 then
        local dirtLevel = GetVehicleDirtLevel(vehicle)
        if dirtLevel > 0.0 then
            SetVehicleDirtLevel(vehicle, 0.0)
        end

        if 0 ~= driverPed then
            if not IsPedAPlayer(driverPed) then
                local passengerAnimDict = "oddjobs@taxi@cyi"
                local passengerAnimName = "std_hand_off_ps_passenger"
                Framework.LoadAnimDict(passengerAnimDict)
                TaskPlayAnim(driverPed, passengerAnimDict, passengerAnimName, 3.0, 3.0, -1, 1, 0, false, false, false)
                Wait(1000)
                StopAnimTask(driverPed, passengerAnimDict, passengerAnimName, 3.0)

                local reward = Framework.TriggerCallback.Await("envi-dumpsters:server:DoCooldown", false)
                Framework.Notify(string.format(Config.Lang.clean_car_success or "You cleaned the car and received %s", reward), "success")
            end
        end
    end
end

if Config.BeggingSettings.CleanCars then
    if Config.Target then
        local cleanCarOption = {
            distance = 1.5,
            name = "clean_car",
            label = Config.Lang.clean_car_label or "Clean Car",
            icon = "fa-solid fa-soap",
            onSelect = function(data)
                CleanCar(data.entity)
            end,
            canInteract = function()
                return Framework.Player.Job.Name == Config.HoboJobRole
            end,
        }

        Target.AddGlobalVehicle({ cleanCarOption })
    else
        local interact = exports["envi-interact"]

        interact:InteractionGlobalVehicle({
            name = "clean_car",
            distance = 3.0,
            radius = 5.0,
            bones = "bonnet",
            options = {
                {
                    label = Config.Lang.clean_car_label or "Clean Car",
                    selected = function(data)
                        CleanCar(data.entity)
                    end,
                    canSee = function()
                        return Framework.Player.Job.Name == Config.HoboJobRole
                    end,
                },
            },
        })
    end
end
