local missionTimeoutTimer, passengerPed, currentMission, pickupZone, approachZone, dropoffZone, pickupBlip, attachedCart

function StartHoboTaxiMission()
    if currentMission then
        Framework.Notify(Config.Lang.taxi_already_active, "error")
        return
    end

    local attempts = 0
    local maxAttempts = 10
    local pickup, dropoff

    repeat
        pickup = Config.Missions[9].PickupLocations[math.random(#Config.Missions[9].PickupLocations)]
        dropoff = Config.Missions[9].DropoffLocations[math.random(#Config.Missions[9].DropoffLocations)]
        attempts = attempts + 1
        if pickup.x ~= dropoff.x then
            break
        end
    until pickup.y ~= dropoff.y or maxAttempts <= attempts

    if maxAttempts <= attempts then
        Framework.Notify(Config.Lang.taxi_find_customer_failed, "error")
        return
    end

    pickupBlip = AddBlipForCoord(pickup.x, pickup.y, pickup.z)
    SetBlipSprite(pickupBlip, 280)
    SetBlipColour(pickupBlip, 5)
    SetBlipAsShortRange(pickupBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Lang.taxi_pickup_blip)
    EndTextCommandSetBlipName(pickupBlip)
    SetBlipRoute(pickupBlip, true)

    pickupZone = Zone.SphereZone({
        coords = pickup,
        radius = 30.0,
        debug = false,
        onEnter = function()
            if not passengerPed then
                SpawnTaxiPassenger(pickup, dropoff)
            end
        end
    })

    local mission = {}
    mission.pickup = pickup
    mission.dropoff = dropoff
    mission.startTime = GetGameTimer()
    mission.pickupZone = pickupZone
    mission.id = math.random(1, 1000000)
    currentMission = mission

    missionTimeoutTimer = SetTimeout(Config.Missions[9].TimeLimit * 60000, function()
        if currentMission.id == mission.id then
            FailTaxiMission(Config.Lang.taxi_time_up)
        end
    end)

    Framework.Notify(Config.Lang.taxi_goto_pickup, "info")
end

if Config.DebugMode then
    RegisterCommand("testTaxi", function()
        StartHoboTaxiMission()
    end, false)

    RegisterCommand("testTaxiFail", function()
        FailTaxiMission("Test failed mission")
    end, false)

    RegisterCommand("testTaxiComplete", function()
        CompleteTaxiMission()
    end, false)
end

function SpawnTaxiPassenger(pickupCoords, dropoffCoords)
    local pedModel = Config.AggressivePeds[math.random(#Config.AggressivePeds)]
    Framework.LoadModel(pedModel)

    passengerPed = CreatePed(4, pedModel, pickupCoords.x, pickupCoords.y, pickupCoords.z - 1.0, 0.0, true, true)
    SetEntityInvincible(passengerPed, true)
    SetBlockingOfNonTemporaryEvents(passengerPed, true)
    SetPedCanRagdoll(passengerPed, false)
    SetPedCanBeTargetted(passengerPed, false)
    SetEntityHeading(passengerPed, pickupCoords.w)

    if pickupZone then
        pickupZone.remove()
    end

    approachZone = Zone.SphereZone({
        coords = pickupCoords,
        radius = 2.1,
        debug = false,
        onEnter = function()
            if not currentMission then
                return
            end

            SetEntityNoCollisionEntity(cache.ped, passengerPed, false)

            if not IsEntityAttached(CurrentCart) then
                print("No cart attached")
                return
            end

            attachedCart = CurrentCart

            if approachZone then
                approachZone.remove()
            end

            SetBlipCoords(pickupBlip, dropoffCoords.x, dropoffCoords.y, dropoffCoords.z)
            SetBlipRoute(pickupBlip, true)

            local animDict = "amb@code_human_train_driver@base"
            local animName = "sit"
            Framework.LoadAnimDict(animDict)
            TaskPlayAnim(passengerPed, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
            AttachEntityToEntity(passengerPed, CurrentCart, 0, 0.0, 0.0, 0.1, 0.0, 0.0, 180.0, true, true, false, true, 1, true)

            exports["envi-interact"]:PlaySpeech(passengerPed, "Hello", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")

            CreateThread(function()
                while passengerPed do
                    if not DoesEntityExist(passengerPed) then
                        break
                    end
                    Wait(math.random(10000, 20000))
                    exports["envi-interact"]:PlaySpeech(passengerPed, "Conversation", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
                end
            end)

            dropoffZone = Zone.SphereZone({
                coords = vector3(dropoffCoords.x, dropoffCoords.y, dropoffCoords.z),
                radius = 15.0,
                debug = false,
                onEnter = function()
                    CompleteTaxiMission()
                end
            })
            currentMission.dropoffZone = dropoffZone

            CreateThread(function()
                while IsEntityAttachedToEntity(passengerPed, attachedCart) do
                    Wait(0)

                    if not IsEntityPlayingAnim(passengerPed, animDict, animName, 3) then
                        TaskPlayAnim(passengerPed, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
                    end

                    local distance = #(GetEntityCoords(cache.ped) - GetEntityCoords(attachedCart))
                    local cartRotation = GetEntityRotation(attachedCart)

                    if math.abs(cartRotation.x) > 45.0 or math.abs(cartRotation.y) > 45.0 then
                        local cartSpeed = GetEntitySpeed(attachedCart)
                        ClearPedTasks(passengerPed)
                        DetachEntity(passengerPed, true, true)
                        SetPedCanRagdoll(passengerPed, true)
                        SetPedToRagdoll(passengerPed, 1000, 6000, 2, false, false, false)
                        if cartSpeed > 0.1 then
                            local forward = GetEntityForwardVector(attachedCart)
                            SetEntityVelocity(passengerPed, forward.x * cartSpeed, forward.y * cartSpeed, 0.0)
                        end
                        SetPedCanBeTargetted(passengerPed, true)
                        SetEntityInvincible(passengerPed, false)
                        SetBlockingOfNonTemporaryEvents(passengerPed, false)
                        SetPedAsNoLongerNeeded(passengerPed)
                        passengerPed = nil
                        FailTaxiMission(Config.Lang.taxi_passenger_fell)
                        break
                    else
                        if distance > 10.0 then
                            FailTaxiMission(Config.Lang.taxi_cart_abandoned)
                            ClearPedTasks(passengerPed)
                            DetachEntity(passengerPed, true, true)
                            SetPedCanBeTargetted(passengerPed, true)
                            SetEntityInvincible(passengerPed, false)
                            SetBlockingOfNonTemporaryEvents(passengerPed, false)
                            SetPedAsNoLongerNeeded(passengerPed)
                            passengerPed = nil
                        end
                    end
                end
            end)
        end
    })
end

function CompleteTaxiMission()
    if not currentMission then
        return
    end

    if passengerPed then
        DetachEntity(passengerPed, true, true)
        ClearPedTasks(passengerPed)
        SetPedAsNoLongerNeeded(passengerPed)
    end

    Framework.TriggerCallback("envi-dumpsters:server:CompleteTaxiMission", function(paid)
        if not paid then
            Framework.Notify(Config.Lang.taxi_no_payment, "error")
            exports["envi-interact"]:PlaySpeech(passengerPed, "AngryReaction", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
            if passengerPed then
                TaskSmartFleePed(passengerPed, cache.ped, 100.0, -1, true, true)
            end
        else
            exports["envi-interact"]:PlaySpeech(passengerPed, "Thanks", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
        end
    end)

    if pickupBlip then
        RemoveBlip(pickupBlip)
        pickupBlip = nil
    end

    if pickupZone then
        pickupZone.remove()
        pickupZone = nil
    end

    if dropoffZone then
        dropoffZone.remove()
        dropoffZone = nil
    end

    if approachZone then
        approachZone.remove()
        approachZone = nil
    end

    currentMission = nil
    passengerPed = nil
    attachedCart = nil

    SetTimeout(10000, function()
        if not currentMission then
            StartHoboTaxiMission()
        end
    end)
end

function FailTaxiMission(reason)
    if not currentMission then
        return
    end

    if passengerPed then
        DetachEntity(passengerPed, true, true)
        exports["envi-interact"]:PlaySpeech(passengerPed, "AngryReaction", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
        SetPedAsNoLongerNeeded(passengerPed)
        passengerPed = nil
    end

    if pickupBlip then
        RemoveBlip(pickupBlip)
        pickupBlip = nil
    end

    if pickupZone then
        pickupZone.remove()
    end

    if dropoffZone then
        dropoffZone.remove()
    end

    currentMission = nil

    Framework.Notify(reason, "error")
end
