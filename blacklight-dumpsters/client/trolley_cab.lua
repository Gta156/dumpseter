--[[ ==========================================================================
     BlackLight Dumpsters — Trolley Cab Contracts (client)
     Ferry street folk across town in a shopping trolley.
========================================================================== ]]

local random, abs = math.random, math.abs

-- Shared global consumed by trolley_derby.lua when the trolley is launched/tipped.
CabPassenger = nil

local runDeadline = nil
local activeRun = nil
local collectionZone = nil
local boardingZone = nil
local deliveryZone = nil
local routeBlip = nil
local ferryingTrolley = nil

local SIT_DICT = "amb@code_human_train_driver@base"
local SIT_CLIP = "sit"
local INTERACT = "blacklight-interact"

--- Tears down every zone / blip belonging to the current run.
local function ClearRunMarkers()
    if routeBlip then
        RemoveBlip(routeBlip)
        routeBlip = nil
    end

    if collectionZone then
        collectionZone.remove()
        collectionZone = nil
    end

    if boardingZone then
        boardingZone.remove()
        boardingZone = nil
    end

    if deliveryZone then
        deliveryZone.remove()
        deliveryZone = nil
    end
end

--- Releases the passenger ped back to the world.
local function ReleasePassenger(ragdoll, launchSpeed)
    if not CabPassenger then
        return
    end

    ClearPedTasks(CabPassenger)
    DetachEntity(CabPassenger, true, true)

    if ragdoll then
        SetPedCanRagdoll(CabPassenger, true)
        SetPedToRagdoll(CabPassenger, 1000, 6000, 2, false, false, false)

        if launchSpeed and launchSpeed > 0.1 and ferryingTrolley and DoesEntityExist(ferryingTrolley) then
            local forward = GetEntityForwardVector(ferryingTrolley)
            SetEntityVelocity(CabPassenger, forward.x * launchSpeed, forward.y * launchSpeed, 0.0)
        end
    end

    SetPedCanBeTargetted(CabPassenger, true)
    SetEntityInvincible(CabPassenger, false)
    SetBlockingOfNonTemporaryEvents(CabPassenger, false)
    SetPedAsNoLongerNeeded(CabPassenger)
    CabPassenger = nil
end

--- Spawns the fare at the collection point and wires up the boarding zone.
function SpawnCabFare(collectionPoint, deliveryPoint)
    local modelName = Settings.VagrantModels[random(#Settings.VagrantModels)]
    Framework.LoadModel(modelName)

    CabPassenger = CreatePed(4, modelName, collectionPoint.x, collectionPoint.y, collectionPoint.z - 1.0, 0.0, true, true)
    SetEntityInvincible(CabPassenger, true)
    SetBlockingOfNonTemporaryEvents(CabPassenger, true)
    SetPedCanRagdoll(CabPassenger, false)
    SetPedCanBeTargetted(CabPassenger, false)
    SetEntityHeading(CabPassenger, collectionPoint.w)

    if collectionZone then
        collectionZone.remove()
        collectionZone = nil
    end

    boardingZone = Zone.SphereZone({
        coords = collectionPoint,
        radius = 2.1,
        debug = false,
        onEnter = function()
            if not activeRun then
                return
            end

            SetEntityNoCollisionEntity(cache.ped, CabPassenger, false)

            if not IsEntityAttached(HeldTrolley) then
                LogDiagnostic("No trolley in hand — fare will not board")
                return
            end

            ferryingTrolley = HeldTrolley

            if boardingZone then
                boardingZone.remove()
                boardingZone = nil
            end

            SetBlipCoords(routeBlip, deliveryPoint.x, deliveryPoint.y, deliveryPoint.z)
            SetBlipRoute(routeBlip, true)

            Framework.LoadAnimDict(SIT_DICT)
            TaskPlayAnim(CabPassenger, SIT_DICT, SIT_CLIP, 8.0, 8.0, -1, 1, 0, false, false, false)
            AttachEntityToEntity(CabPassenger, HeldTrolley, 0, 0.0, 0.0, 0.1, 0.0, 0.0, 180.0, true, true, false, true, 1, true)

            exports[INTERACT]:PlaySpeech(CabPassenger, "Hello", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")

            -- Idle chatter from the fare.
            CreateThread(function()
                while CabPassenger and DoesEntityExist(CabPassenger) do
                    Wait(random(10000, 20000))
                    if CabPassenger and DoesEntityExist(CabPassenger) then
                        exports[INTERACT]:PlaySpeech(CabPassenger, "Conversation", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
                    end
                end
            end)

            deliveryZone = Zone.SphereZone({
                coords = vector3(deliveryPoint.x, deliveryPoint.y, deliveryPoint.z),
                radius = 15.0,
                debug = false,
                onEnter = function()
                    FinishCabRun()
                end,
            })
            activeRun.deliveryZone = deliveryZone

            -- Watchdog: fare must stay seated and the driver must stay close.
            CreateThread(function()
                while CabPassenger and IsEntityAttachedToEntity(CabPassenger, ferryingTrolley) do
                    Wait(0)

                    if not IsEntityPlayingAnim(CabPassenger, SIT_DICT, SIT_CLIP, 3) then
                        TaskPlayAnim(CabPassenger, SIT_DICT, SIT_CLIP, 8.0, 8.0, -1, 1, 0, false, false, false)
                    end

                    local rotation = GetEntityRotation(ferryingTrolley)

                    if abs(rotation.x) > 45.0 or abs(rotation.y) > 45.0 then
                        ReleasePassenger(true, GetEntitySpeed(ferryingTrolley))
                        AbortCabRun(Settings.Text.cab_passenger_thrown)
                        break
                    end

                    if #(GetEntityCoords(cache.ped) - GetEntityCoords(ferryingTrolley)) > 10.0 then
                        AbortCabRun(Settings.Text.cab_trolley_dropped)
                        ReleasePassenger(false)
                        break
                    end
                end
            end)
        end,
    })
end

--- Accepts a new cab contract and marks the collection point.
function BeginTrolleyCabRun()
    if activeRun then
        Framework.Notify(Settings.Text.cab_already_running, "error")
        return
    end

    local chapter = Settings.Chapters[9]
    local attempts, maxAttempts = 0, 10
    local collectionPoint, deliveryPoint

    -- Keep drawing until the collection and delivery points differ.
    repeat
        collectionPoint = chapter.CollectionPoints[random(#chapter.CollectionPoints)]
        deliveryPoint = chapter.DeliveryPoints[random(#chapter.DeliveryPoints)]
        attempts = attempts + 1
    until (collectionPoint.x ~= deliveryPoint.x or collectionPoint.y ~= deliveryPoint.y) or attempts >= maxAttempts

    if attempts >= maxAttempts and collectionPoint.x == deliveryPoint.x and collectionPoint.y == deliveryPoint.y then
        Framework.Notify(Settings.Text.cab_no_client, "error")
        return
    end

    routeBlip = AddBlipForCoord(collectionPoint.x, collectionPoint.y, collectionPoint.z)
    SetBlipSprite(routeBlip, 280)
    SetBlipColour(routeBlip, 5)
    SetBlipAsShortRange(routeBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Settings.Text.cab_pickup_blip)
    EndTextCommandSetBlipName(routeBlip)
    SetBlipRoute(routeBlip, true)

    collectionZone = Zone.SphereZone({
        coords = collectionPoint,
        radius = 30.0,
        debug = false,
        onEnter = function()
            if not CabPassenger then
                SpawnCabFare(collectionPoint, deliveryPoint)
            end
        end,
    })

    activeRun = {
        collectionPoint = collectionPoint,
        deliveryPoint = deliveryPoint,
        startedAt = GetGameTimer(),
        collectionZone = collectionZone,
        id = random(1, 1000000),
    }

    local runId = activeRun.id

    runDeadline = SetTimeout(Settings.Chapters[9].MinutesAllowed * 60000, function()
        if activeRun and activeRun.id == runId then
            AbortCabRun(Settings.Text.cab_out_of_time)
        end
    end)

    Framework.Notify(Settings.Text.cab_head_to_pickup, "info")
end

--- Delivers the fare and claims payment, then queues the next run.
function FinishCabRun()
    if not activeRun then
        return
    end

    local fare = CabPassenger

    if fare then
        DetachEntity(fare, true, true)
        ClearPedTasks(fare)
    end

    Framework.TriggerCallback("bl_dumpsters:server:SettleCabRun", function(paid)
        if not fare or not DoesEntityExist(fare) then
            return
        end

        if paid then
            exports[INTERACT]:PlaySpeech(fare, "Thanks", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
        else
            Framework.Notify(Settings.Text.cab_stiffed, "error")
            exports[INTERACT]:PlaySpeech(fare, "AngryReaction", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
            TaskSmartFleePed(fare, cache.ped, 100.0, -1, true, true)
        end

        SetPedAsNoLongerNeeded(fare)
    end)

    ClearRunMarkers()

    activeRun = nil
    CabPassenger = nil
    ferryingTrolley = nil

    -- Cab work is continuous; queue the next fare shortly.
    SetTimeout(10000, function()
        if not activeRun then
            BeginTrolleyCabRun()
        end
    end)
end

--- Cancels the current run with the supplied reason.
function AbortCabRun(reason)
    if not activeRun then
        return
    end

    if CabPassenger then
        DetachEntity(CabPassenger, true, true)
        exports[INTERACT]:PlaySpeech(CabPassenger, "AngryReaction", "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
        SetPedAsNoLongerNeeded(CabPassenger)
        CabPassenger = nil
    end

    ClearRunMarkers()

    activeRun = nil
    ferryingTrolley = nil

    Framework.Notify(reason, "error")
end

if Settings.DiagnosticMode then
    RegisterCommand("bl_test_cab", function()
        BeginTrolleyCabRun()
    end, false)

    RegisterCommand("bl_test_cab_fail", function()
        AbortCabRun("Diagnostic: forced contract failure")
    end, false)

    RegisterCommand("bl_test_cab_done", function()
        FinishCabRun()
    end, false)
end
