local inboundPeds = {}
local panhandleOnCooldown = false
local isPanhandling = false
local skippedPeds = {}
local panhandleProp = nil
local vehicleWashJobs = {}

local function removePanhandleProp()
    if panhandleProp then
        if DoesEntityExist(panhandleProp) then
            DeleteObject(panhandleProp)
            panhandleProp = nil
        end
    end
end

local function awaitPedArrival(ped)
    local arrived = false
    local attempts = 0

    table.insert(inboundPeds, ped)

    TaskGoToEntity(ped, cache.ped, -1, 1.0, 0.5, 0, 0)

    CreateThread(function()
        -- Bounded: a ped whose path is blocked would otherwise never reach 1.0 and this
        -- thread (and the caller waiting on `arrived`) would spin for the whole session.
        local giveUpAt = GetGameTimer() + 30000
        while true do
            if not DoesEntityExist(ped) then
                break
            end
            local distance = #(GetEntityCoords(ped) - GetEntityCoords(cache.ped))
            if distance < 1.0 then
                arrived = true
                break
            end
            if GetGameTimer() > giveUpAt then
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

    for index, queuedPed in ipairs(inboundPeds) do
        if queuedPed == ped then
            table.remove(inboundPeds, index)
            break
        end
    end

    return arrived
end

local function findClosestPed(coords, radius)
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
                    if not skippedPeds[ped] then
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

local function panhandleLoop(hasSign)
    Wait(math.random(1000, 5000))

    while true do
        if not isPanhandling then
            break
        end

        local nearestPed = findClosestPed(GetEntityCoords(cache.ped), 30.0)
        if nearestPed then
            if not skippedPeds[nearestPed] then
                local ignoreRoll = math.random(1, 100)
                if ignoreRoll >= Config.PanhandleSettings.IgnoreChance then
                    local pedCoords = GetEntityCoords(nearestPed)
                    local playerCoords = GetEntityCoords(cache.ped)
                    local distance = #(pedCoords - playerCoords)
                    local aggressiveRoll = math.random(1, 100)

                    if distance < 5.0 then
                        skippedPeds[nearestPed] = true
                        TaskTurnPedToFaceEntity(nearestPed, cache.ped, -1)
                        Wait(math.random(500, 3000))

                        if aggressiveRoll <= Config.PanhandleSettings.AggressivePedChance then
                            local refuseRoll = math.random(1, 5)

                            if refuseRoll <= 0 then
                                TaskTurnPedToFaceEntity(nearestPed, cache.ped, 5000)

                                local tauntLines = { "GENERIC_INSULT_HIGH", "GENERIC_INSULT_MED", "GENERIC_SHOCKED_HIGH" }
                                PlayPedAmbientSpeechNative(nearestPed, tauntLines[math.random(#tauntLines)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")

                                SetPedAsNoLongerNeeded(nearestPed)
                                print(Config.Lang.ped_refuse_help)

                                ClearPedTasks(cache.ped)
                                isPanhandling = false
                                removePanhandleProp()
                                break
                            else
                                local combatRoll = math.random(1, 2)

                                if 1 == combatRoll then
                                    local tauntLines = { "GENERIC_INSULT_HIGH", "GENERIC_INSULT_MED", "GENERIC_SHOCKED_HIGH" }
                                    PlayPedAmbientSpeechNative(nearestPed, tauntLines[math.random(#tauntLines)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")

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

                                    PlayPedAmbientSpeechNative(nearestPed, tauntLines[math.random(#tauntLines)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
                                    SetPedAsNoLongerNeeded(nearestPed)
                                    TaskSmartFleePed(nearestPed, cache.ped, 1000, -1, true, true)

                                    isPanhandling = false
                                    removePanhandleProp()
                                    break
                                else
                                    TaskCombatPed(nearestPed, cache.ped, 0, 16)
                                    Wait(math.random(500, 1500))

                                    ClearPedTasks(cache.ped)
                                    isPanhandling = false
                                    removePanhandleProp()
                                    break
                                end
                            end
                            SetPedAsNoLongerNeeded(nearestPed)
                        else
                            local arrived = awaitPedArrival(nearestPed)
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

                                local cashReceived = Framework.TriggerCallback.Await("bl_scav:server:DoCooldown", hasSign)
                                Framework.Notify(string.format(Config.Lang.begging_received_money, cashReceived), "success")

                                panhandleOnCooldown = true
                                SetTimeout(Config.PanhandleSettings.BegCooldown * 1000, function()
                                    panhandleOnCooldown = false
                                end)

                                ClearPedTasks(cache.ped)
                                isPanhandling = false

                                if Config.HostileVagrantsEnabled then
                                    ProvokeVagrantCrowd(models)
                                end

                                removePanhandleProp()
                                break
                            end
                        end
                    end
                else
                    local brushOffLines = { "GENERIC_NO", "GENERIC_INSULT_HIGH", "GENERIC_INSULT_MED", "GENERIC_SHOCKED_HIGH" }
                    PlayPedAmbientSpeechNative(nearestPed, brushOffLines[math.random(#brushOffLines)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
                    skippedPeds[nearestPed] = true
                end
            end
        end

        Wait(5000)
    end
end

RegisterCommand("stopbegging", function()
    isPanhandling = false

    if IsEntityPlayingAnim(cache.ped, "missheist_agency3aig_24", "agent02_conversation", 3) then
        StopAnimTask(cache.ped, "missheist_agency3aig_24", "agent02_conversation", 3)
    end

    removePanhandleProp()
    ClearPedTasks(cache.ped)
end, false)

RegisterKeyMapping("stopbegging", Config.Lang.stop_begging, "keyboard", "x")

local beggingSignModels = { -245386275, -533655168, -1109340972, -801803927 }

RegisterCommand(Config.PanhandleSettings.PanhandleCommand, function()
    if panhandleOnCooldown then
        Framework.Notify(Config.Lang.begging_cooldown, "error")
        return
    end

    if isPanhandling then
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
        -- Bounded wait: the original spun forever if the model never streamed in
        -- (bad model hash, missing asset pack), permanently wedging this thread.
        local modelTimeoutAt = GetGameTimer() + 5000
        while not HasModelLoaded(modelHash) do
            if GetGameTimer() > modelTimeoutAt then
                SetModelAsNoLongerNeeded(modelHash)
                return
            end
            Wait(50)
        end

        local prop = CreateObject(modelHash, 0, 0, 0, true, true, true)
        panhandleProp = prop
        AttachEntityToEntity(panhandleProp, playerPed, GetPedBoneIndex(playerPed, 18905), 0.06397625058889, -0.077691398561, 0.2065776884558, -85.892402648928, 88.618576498046, -11.269510269165, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(modelHash)
    else
        local animDict = "missheist_agency3aig_24"
        local animName = "agent02_conversation"
        Framework.LoadAnimDict(animDict)
        TaskPlayAnim(playerPed, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
    end

    CreateThread(function()
        isPanhandling = true
        panhandleLoop(hasSign)
        removePanhandleProp()
    end)

    if Config.PanhandleSettings.ProgressBar then
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
            isPanhandling = false
            removePanhandleProp()
        else
            Framework.Notify(Config.Lang.begging_cancelled, "error")
            isPanhandling = false
            removePanhandleProp()
        end
    else
        SetTimeout(30000, function()
            if isPanhandling then
                isPanhandling = false
                ClearPedTasks(playerPed)
                removePanhandleProp()
            end
        end)
    end
end, false)

function WashVehicle(vehicle)
    if not IsEntityAVehicle(vehicle) then
        return
    end

    local playerPed = PlayerPedId()

    if vehicleWashJobs[vehicle] then
        Framework.Notify(Config.Lang.car_already_cleaning or "This car is already clean!", "error")
        return
    end

    vehicleWashJobs[vehicle] = true

    local scrubberModel = -678752633
    RequestModel(scrubberModel)
    -- Bounded wait (see note on the begging-sign model above). Also raised from a
    -- 10ms to a 50ms poll: this only runs while starting a wash, and 10ms polling
    -- burned frames for no perceptible gain.
    local scrubberTimeoutAt = GetGameTimer() + 5000
    while not HasModelLoaded(scrubberModel) do
        if GetGameTimer() > scrubberTimeoutAt then
            vehicleWashJobs[vehicle] = nil
            SetModelAsNoLongerNeeded(scrubberModel)
            return
        end
        Wait(50)
    end

    local scrubberProp = CreateObject(scrubberModel, 0, 0, 0, true, true, false)
    AttachEntityToEntity(scrubberProp, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, -0.01, 90.0, 0.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(scrubberModel)

    local animDict = "timetable@floyd@clean_kitchen@base"
    local animName = "base"
    Framework.LoadAnimDict(animDict)
    TaskPlayAnim(playerPed, animDict, animName, 3.0, 3.0, -1, 1, 0, false, false, false)

    local aggressiveRoll = math.random(1, 100) <= Config.PanhandleSettings.AggressiveCleanCarChance
    local driverPed = GetPedInVehicleSeat(vehicle, -1)

    if 0 ~= driverPed and aggressiveRoll then
        TaskCombatPed(driverPed, playerPed, 0, 16)
        Wait(math.random(1000, 3000))

        ClearPedTasks(playerPed)
        DeleteEntity(scrubberProp)
        return
    end

    local isWashing = true
    CreateThread(function()
        -- Wait(0) is correct here: this polls a keypress every frame while the player is
        -- actively washing. It is bounded by isWashing plus a hard ceiling so the thread can
        -- never survive the interaction (e.g. if the wash loop errors out).
        local watchdog = GetGameTimer() + ((Config.PanhandleSettings.MaxCleanTime or 30) * 1000) + 5000
        while isWashing do
            if IsControlJustPressed(0, 73) then
                isWashing = false
                break
            end
            if GetGameTimer() > watchdog then
                isWashing = false
                break
            end
            Wait(0)
        end
    end)

    local startTime = GetGameTimer()
    local washDuration = math.random(Config.PanhandleSettings.MinCleanTime * 1000, Config.PanhandleSettings.MaxCleanTime * 1000)
    local animCompleted = true

    while isWashing do
        local elapsed = GetGameTimer() - startTime
        if not (washDuration > elapsed) then
            break
        end

        Wait(100)

        if not IsEntityPlayingAnim(playerPed, animDict, animName, 3) then
            animCompleted = false
            break
        end
    end

    DeleteEntity(scrubberProp)
    ClearPedTasks(playerPed)

    if not isWashing or not animCompleted then
        return
    end

    local playerCoords = GetEntityCoords(playerPed)
    local vehicleCoords = GetEntityCoords(vehicle)
    local distance = #(playerCoords - vehicleCoords)

    if distance <= 4.0 then
        local grimeLevel = GetVehicleDirtLevel(vehicle)
        if grimeLevel > 0.0 then
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

                local reward = Framework.TriggerCallback.Await("bl_scav:server:DoCooldown", false)
                Framework.Notify(string.format(Config.Lang.clean_car_success or "You cleaned the car and received %s", reward), "success")
            end
        end
    end
end

if Config.PanhandleSettings.CleanCars then
    if Config.Target then
        local washVehicleOption = {
            distance = 1.5,
            name = "clean_car",
            label = Config.Lang.clean_car_label or "Clean Car",
            icon = "fa-solid fa-soap",
            onSelect = function(data)
                WashVehicle(data.entity)
            end,
            canInteract = function()
                return Framework.Player.Job.Name == Config.VagrantJobRole
            end,
        }

        Target.AddGlobalVehicle({ washVehicleOption })
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
                        WashVehicle(data.entity)
                    end,
                    canSee = function()
                        return Framework.Player.Job.Name == Config.VagrantJobRole
                    end,
                },
            },
        })
    end
end
