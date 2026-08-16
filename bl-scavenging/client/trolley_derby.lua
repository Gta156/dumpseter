local lostFareRef = nil -- always nil in the original; every assignment site sets it back to nil, so the `if deadPassengerRef then ... end` blocks below are dead code. Preserved as-is.
local isRidingTrolley = false
local riddenTrolleyEntity = nil
BLScav_PushingTrolley = false
BLScav_ActiveTrolley = nil
local hostNPCs = {}
local derbyTrolley = nil
local trolleyPushBusy = false

BLSCAV_TROLLEY_MODELS = { 1395334609, 979462386, 1918323043, -230045366 }

local downhillRun = {
    active = false,
    totalDistance = 0,
    lastPosition = nil,
    blips = {},
}

local derbyLaunchZone = nil

CreateThread(function()
    if Config.TrolleyDerby.ConstantBlips then
        for _, track in pairs(Config.TrolleyDerby.Tracks) do
            local blip = AddBlipForCoord(track.npc.x, track.npc.y, track.npc.z)
            SetBlipSprite(blip, 127)
            SetBlipColour(blip, 5)
            SetBlipAsShortRange(blip, true)
            SetBlipScale(blip, Config.TrolleyDerby.BlipScale or 0.8)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.Lang.cart_derby_blip)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

function LaunchDownhillContract()
    downhillRun.active = true
    downhillRun.totalDistance = 0
    downhillRun.lastPosition = nil
    downhillRun.blips = {}

    if not Config.TrolleyDerby.ConstantBlips then
        for _, track in pairs(Config.TrolleyDerby.Tracks) do
            local blip = AddBlipForCoord(track.npc.x, track.npc.y, track.npc.z)
            SetBlipSprite(blip, 127)
            SetBlipColour(blip, 5)
            SetBlipAsShortRange(blip, true)
            SetBlipScale(blip, Config.TrolleyDerby.BlipScale or 0.8)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.Lang.cart_derby_blip)
            EndTextCommandSetBlipName(blip)
            table.insert(downhillRun.blips, blip)
        end
    end

    Framework.Notify(Config.Lang.check_map_derby, "info", 10000)

    CreateThread(function()
        local wasSitting = false
        while downhillRun.active do
            Wait(500)
            if isRidingTrolley then
                if not downhillRun.lastPosition then
                    downhillRun.lastPosition = GetEntityCoords(cache.ped)
                end
                wasSitting = true
            else
                if wasSitting then
                    if downhillRun.lastPosition then
                        local traveled = #(GetEntityCoords(cache.ped) - downhillRun.lastPosition)
                        downhillRun.totalDistance = downhillRun.totalDistance + traveled

                        TriggerServerEvent("bl_scav:server:UpdateMissionProgress", 4, {
                            total_distance = math.floor(downhillRun.totalDistance),
                        })

                        if downhillRun.totalDistance >= Config.Contracts[4].RequiredDistance then
                            FinalizeDownhillContract()
                        end

                        Framework.Notify(string.format(Config.Lang.thrill_ride_distance, math.floor(downhillRun.totalDistance), Config.Contracts[4].RequiredDistance), "info")
                    end
                end
                downhillRun.lastPosition = nil
                wasSitting = false
            end
        end
    end)

    Framework.Notify(string.format(Config.Lang.find_cart_ride, Config.Contracts[4].RequiredDistance), "info")
end

function FinalizeDownhillContract()
    if downhillRun.active then
        downhillRun.active = false

        if downhillRun.blips then
            for _, blip in pairs(downhillRun.blips) do
                if DoesBlipExist(blip) then
                    RemoveBlip(blip)
                end
            end
            downhillRun.blips = nil
        end

        TriggerServerEvent("bl_scav:server:CompleteThrillRide")
    end
end

function LaunchTrolley(chargeSeconds, forceLaunch)
    if not BLScav_ActiveTrolley then
        return
    end

    DetachEntity(BLScav_ActiveTrolley, true, true)
    ClearPedTasks(cache.ped)
    SetEntityCollision(BLScav_ActiveTrolley, true, true)

    local cartSpeed = GetEntitySpeed(BLScav_ActiveTrolley)

    if cartSpeed > 4.0 or forceLaunch then
        if Framework.Player.Job.Name == Config.VagrantJobRole or forceLaunch then
            if GetFollowPedCamViewMode() ~= 4 then
                local animDict = "move_jump@beastjump"
                local animName = "jump_launch_l"
                Framework.LoadAnimDict(animDict)
                TaskPlayAnim(cache.ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            local forward = GetEntityForwardVector(BLScav_ActiveTrolley)
            local launchPower = cartSpeed * math.random(math.floor(chargeSeconds / 2), math.floor(chargeSeconds))

            if launchPower < 5.0 then
                launchPower = 5.0
            elseif launchPower > 20.0 then
                launchPower = 20.0
            end

            if launchPower > 10.0 then
                local rarityRoll = math.random(1, 10)
                if rarityRoll <= 1 then
                    launchPower = launchPower * 2
                elseif rarityRoll <= 3 then
                    launchPower = launchPower * 1.5
                elseif rarityRoll <= 5 then
                    launchPower = launchPower * 1.25
                elseif rarityRoll <= 7 then
                    launchPower = launchPower * 1.1
                elseif rarityRoll <= 9 then
                    launchPower = launchPower * 1.05
                end
            end

            if forceLaunch then
                launchPower = launchPower * 2
            end

            SetEntityVelocity(BLScav_ActiveTrolley, -forward.x * launchPower, -forward.y * launchPower, 0.0)

            RemoveAnimDict(dict)

            SetTimeout(math.random(500, 2000), function()
                ClearPedTasks(cache.ped)
            end)
        end
    end

    if cartSpeed > 4.0 then
        if lostFareRef then
            if IsEntityAttachedToEntity(lostFareRef, BLScav_ActiveTrolley) then
                Wait(math.random(1500, 4500))
                ClearPedTasks(lostFareRef)
                DetachEntity(lostFareRef, true, true)
                SetPedCanRagdoll(lostFareRef, true)
                SetPedToRagdoll(lostFareRef, 1000, 5000, 2, false, false, false)

                local passengerForward = GetEntityForwardVector(lostFareRef)
                SetEntityVelocity(lostFareRef, passengerForward.x * cartSpeed * 2, passengerForward.y * cartSpeed * 2, 0.5)
                SetPedCanBeTargetted(lostFareRef, true)
                SetEntityInvincible(lostFareRef, false)
                SetBlockingOfNonTemporaryEvents(lostFareRef, false)
                lostFareRef = nil

                AbortCartFareRun(Config.Lang.abandoned_passenger)
            end
        end
    end

    BLScav_ActiveTrolley = nil
    BLScav_PushingTrolley = false
end

function ReleaseTrolley()
    if not BLScav_ActiveTrolley then
        return
    end

    DetachEntity(BLScav_ActiveTrolley, true, true)
    ClearPedTasks(cache.ped)
    SetEntityCollision(BLScav_ActiveTrolley, true, true)

    local cartSpeed = GetEntitySpeed(BLScav_ActiveTrolley)

    if cartSpeed > 5.0 then
        if lostFareRef then
            if IsEntityAttachedToEntity(lostFareRef, BLScav_ActiveTrolley) then
                Wait(math.random(1500, 4500))
                ClearPedTasks(lostFareRef)
                DetachEntity(lostFareRef, true, true)
                SetPedCanRagdoll(lostFareRef, true)
                SetPedToRagdoll(lostFareRef, 1000, 5000, 2, false, false, false)

                local passengerForward = GetEntityForwardVector(lostFareRef)
                SetEntityVelocity(lostFareRef, passengerForward.x * cartSpeed * 2, passengerForward.y * cartSpeed * 2, 0.5)
                SetPedCanBeTargetted(lostFareRef, true)
                SetEntityInvincible(lostFareRef, false)
                SetBlockingOfNonTemporaryEvents(lostFareRef, false)
                lostFareRef = nil

                AbortCartFareRun(Config.Lang.abandoned_passenger)
            end
        end
    end

    BLScav_ActiveTrolley = nil
    BLScav_PushingTrolley = false
end

function GripTrolley(entity, skipWalkTo)
    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId then
        if Entity(entity).state.isOccupied then
            -- occupied: fall through without replacing the entity
        else
            if not IsEntityAMissionEntity(entity) then
                local model = GetEntityModel(entity)
                local coords = GetEntityCoords(entity)
                SetEntityAsMissionEntity(entity, true, true)
                DeleteEntity(entity)
                entity = CreateObject(model, coords.x, coords.y, coords.z - 0.5, true, true, true)
                BLScav_ActiveTrolley = entity
            end
        end
    end

    trolleyPushBusy = true

    if not skipWalkTo then
        local coords = GetEntityCoords(entity)
        TaskGoStraightToCoord(cache.ped, coords.x, coords.y, coords.z, 1.0, 100, 0, 0)
        Wait(100)
    end

    if not DoesEntityExist(entity) then
        return
    end

    if IsEntityAttached(entity) then
        return
    end

    NetworkRequestControlOfEntity(entity)
    NetworkRegisterEntityAsNetworked(entity)
    SetEntityAsMissionEntity(entity, true, true)

    Framework.LoadAnimDict("anim@heists@box_carry@")
    TaskPlayAnim(cache.ped, "anim@heists@box_carry@", "idle", 8.0, 8.0, -1, 50, 0, false, false, false)
    Wait(150)

    AttachEntityToEntity(entity, cache.ped, GetPedBoneIndex(cache.ped, 28422), -0.0, -0.49, -0.763, 195.0, 180.0, 180.0, 0.0, false, false, true, false, 2, true)

    BLScav_PushingTrolley = true
    trolleyPushBusy = false
    BLScav_ActiveTrolley = entity

    local launchChargeStart = 0
    lib.showTextUI(Config.Lang.cart_controls)
    SetTimeout(7000, function()
        lib.hideTextUI()
    end)

    CreateThread(function()
        while IsEntityAttachedToEntity(entity, cache.ped) do
            Wait(0)
            DisableControlAction(0, 24, true)

            if not IsEntityPlayingAnim(cache.ped, "anim@heists@box_carry@", "idle", 3) then
                ReleaseTrolley()
                break
            end

            if IsPedDeadOrDying(cache.ped) then
                ReleaseTrolley()
                break
            end

            if IsPedRagdoll(cache.ped) then
                ReleaseTrolley()
                break
            end

            if IsControlJustPressed(0, 73) then
                launchChargeStart = GetGameTimer()
            elseif IsControlJustReleased(0, 73) then
                if launchChargeStart > 0 then
                    local chargeSeconds = math.min(1.0 + (GetGameTimer() - launchChargeStart) / 200, 10.0)
                    launchChargeStart = chargeSeconds
                    LaunchTrolley(launchChargeStart, skipWalkTo)
                    launchChargeStart = 0
                    break
                end
            end

            if IsDisabledControlJustPressed(0, 24) then
                if not IsControlPressed(0, 19) then
                    launchChargeStart = GetGameTimer()
                end
            elseif IsDisabledControlJustReleased(0, 24) then
                if launchChargeStart > 0 then
                    if not IsControlPressed(0, 19) then
                        local chargeSeconds = math.min(1.0 + (GetGameTimer() - launchChargeStart) / 200, 10.0)
                        launchChargeStart = chargeSeconds
                        LaunchTrolley(launchChargeStart, skipWalkTo)
                        launchChargeStart = 0
                        break
                    end
                end
            end

            if BLScav_ActiveTrolley then
                local rotation = GetEntityRotation(BLScav_ActiveTrolley)
                if math.abs(rotation.x) > 45.0 or math.abs(rotation.y) > 45.0 then
                    ReleaseTrolley()
                    if lostFareRef then
                        lostFareRef = nil
                        AbortCartFareRun(Config.Lang.cart_tipped)
                    end
                    break
                end
            end
        end

        BLScav_PushingTrolley = false
        BLScav_ActiveTrolley = nil
    end)
end

if Config.Target then
    Target.AddModel(BLSCAV_TROLLEY_MODELS, {
        {
            label = Config.Lang.push_cart,
            icon = "fas fa-hand",
            distance = 2.0,
            canInteract = function(entity)
                return not BLScav_PushingTrolley
            end,
            onSelect = function(data)
                print("netId", NetworkGetNetworkIdFromEntity(data.entity))
                if BLScav_PushingTrolley then
                    return
                end
                BLScav_ActiveTrolley = data.entity
                GripTrolley(data.entity)
            end,
        },
        {
            label = Config.Lang.sit_in_cart,
            icon = "fas fa-hand",
            distance = 2.0,
            onSelect = function(data)
                local animDict = "amb@code_human_train_driver@base"
                local animName = "sit"
                Framework.LoadAnimDict(animDict)

                local cart = data.entity
                AttachEntityToEntity(cache.ped, cart, 0, 0.0, 0.0, 0.1, 0.0, 0.0, 180.0, true, true, false, true, 1, true)
                TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)

                isRidingTrolley = true
                riddenTrolleyEntity = cart

                NetworkRequestControlOfEntity(cart)
                NetworkRegisterEntityAsNetworked(cart)
                SetEntityAsMissionEntity(cart, true, true)

                local netId = NetworkGetNetworkIdFromEntity(cart)
                if netId > 0 then
                    Entity(cart).state:set("isOccupied", true, true)
                    print("setting cart occupied")
                end

                while isRidingTrolley do
                    Wait(0)

                    if GetFollowPedCamViewMode() ~= 4 then
                        SetFollowPedCamViewMode(4)
                    end

                    if not IsEntityPlayingAnim(cache.ped, animDict, animName, 3) then
                        TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
                    end

                    local rotation = GetEntityRotation(cart)
                    if math.abs(rotation.x) > 60.0 or math.abs(rotation.y) > 60.0 then
                        DetachEntity(cache.ped, true, false)
                        SetFollowPedCamViewMode(0)
                        SetPedToRagdoll(cache.ped, 5000, 20000, 2, false, false, false)
                        isRidingTrolley = false
                        riddenTrolleyEntity = nil

                        if netId > 0 then
                            Entity(cart).state:set("isOccupied", false, true)
                        end
                    else
                        if IsControlJustPressed(0, 73) then
                            isRidingTrolley = false
                            riddenTrolleyEntity = nil
                            DetachEntity(cache.ped, true, false)

                            local cartSpeed = GetEntitySpeed(cart)
                            if cartSpeed < 1 then
                                cartSpeed = 1
                            end
                            if cartSpeed > 10 then
                                cartSpeed = 10
                            end

                            SetPedToRagdoll(cache.ped, cartSpeed * 1000, cartSpeed * 1500, 2, false, false, false)

                            if netId > 0 then
                                Entity(cart).state:set("isOccupied", false, true)
                            end
                        end
                    end
                end

                BLScav_ActiveTrolley = nil
                SetFollowPedCamViewMode(0)
            end,
            canInteract = function(entity)
                if BLScav_PushingTrolley then
                    return false
                end
                if isRidingTrolley then
                    return false
                end
                if not IsEntityUpright(entity, 45) then
                    return false
                end

                local netId = NetworkGetNetworkIdFromEntity(entity)
                if netId > 0 then
                    if Entity(entity).state.isOccupied then
                        return false
                    end
                end

                return true
            end,
        },
    })
else
    exports["envi-interact"]:InteractionModel(BLSCAV_TROLLEY_MODELS, {
        {
            name = "cart_interaction",
            distance = 1.5,
            radius = 5.0,
            options = {
                {
                    label = Config.Lang.push_cart_e,
                    canSee = function()
                        if trolleyPushBusy then
                            return false
                        end
                        if BLScav_PushingTrolley then
                            return false
                        end
                        return true
                    end,
                    selected = function(data)
                        print("pushing cart")
                        if not (trolleyPushBusy or BLScav_PushingTrolley) then
                            trolleyPushBusy = true
                            BLScav_ActiveTrolley = data.entity
                            GripTrolley(data.entity)
                            trolleyPushBusy = false
                        end
                    end,
                },
                {
                    label = Config.Lang.sit_in_cart_e,
                    canSee = function(entity)
                        if trolleyPushBusy then
                            return false
                        end
                        if BLScav_PushingTrolley then
                            return false
                        end
                        if isRidingTrolley then
                            return false
                        end
                        if not IsEntityUpright(entity, 45) then
                            return false
                        end
                        return true
                    end,
                    selected = function(data)
                        if trolleyPushBusy then
                            return
                        end
                        trolleyPushBusy = true

                        local animDict = "amb@code_human_train_driver@base"
                        local animName = "sit"
                        Framework.LoadAnimDict(animDict)

                        local cart = data.entity
                        AttachEntityToEntity(cache.ped, cart, 0, 0.0, 0.0, 0.1, 0.0, 0.0, 180.0, true, true, false, true, 1, true)
                        TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)

                        isRidingTrolley = true
                        riddenTrolleyEntity = cart

                        NetworkRequestControlOfEntity(cart)
                        NetworkRegisterEntityAsNetworked(cart)
                        SetEntityAsMissionEntity(cart, true, true)

                        local netId = NetworkGetNetworkIdFromEntity(cart)
                        if netId > 0 then
                            Entity(cart).state:set("isOccupied", true, true)
                        end

                        while isRidingTrolley do
                            Wait(0)

                            if GetFollowPedCamViewMode() ~= 4 then
                                SetFollowPedCamViewMode(4)
                            end

                            if not IsEntityPlayingAnim(cache.ped, animDict, animName, 3) then
                                TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
                            end

                            local rotation = GetEntityRotation(cart)
                            if math.abs(rotation.x) > 60.0 or math.abs(rotation.y) > 60.0 then
                                DetachEntity(cache.ped, true, false)
                                SetFollowPedCamViewMode(0)
                                SetPedToRagdoll(cache.ped, 5000, 20000, 2, false, false, false)
                                isRidingTrolley = false
                                riddenTrolleyEntity = nil

                                if netId > 0 then
                                    Entity(cart).state:set("isOccupied", false, true)
                                end
                            end
                        end

                        BLScav_ActiveTrolley = nil
                        SetFollowPedCamViewMode(0)
                    end,
                },
            },
        },
    })
end

RegisterCommand("leave_cart", function()
    if not isRidingTrolley then
        return
    end

    isRidingTrolley = false

    if not riddenTrolleyEntity then
        return
    end

    local cart = riddenTrolleyEntity
    riddenTrolleyEntity = nil

    local netId = NetworkGetNetworkIdFromEntity(cart)
    DetachEntity(cache.ped, true, false)

    local cartSpeed = GetEntitySpeed(cart)
    if cartSpeed < 1 then
        cartSpeed = 1
    end
    if cartSpeed > 10 then
        cartSpeed = 10
    end

    SetPedToRagdoll(cache.ped, cartSpeed * 1000, cartSpeed * 1500, 2, false, false, false)

    if netId > 0 then
        Entity(cart).state:set("isOccupied", false, true)
    end
end, false)

RegisterKeyMapping("leave_cart", Config.Lang.leave_cart or "Leave Cart", "keyboard", Config.ReleaseTrolleyKey or "X")

RegisterCommand("rideCart", function()
    if trolleyPushBusy then
        return
    end
    if not BLScav_ActiveTrolley then
        return
    end

    local animDict = "amb@code_human_train_driver@base"
    local animName = "sit"
    local cart = BLScav_ActiveTrolley

    ReleaseTrolley()
    Framework.LoadAnimDict(animDict)

    local netId = NetworkGetNetworkIdFromEntity(cart)
    AttachEntityToEntity(cache.ped, cart, 0, 0.0, 0.0, 0.1, 0.0, 0.0, 180.0, true, true, false, true, 1, true)
    TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)

    isRidingTrolley = true
    riddenTrolleyEntity = cart

    if netId > 0 then
        Entity(cart).state:set("isOccupied", true, true)
    end

    while isRidingTrolley do
        Wait(0)

        if GetFollowPedCamViewMode() ~= 4 then
            SetFollowPedCamViewMode(4)
        end

        if not IsEntityPlayingAnim(cache.ped, animDict, animName, 3) then
            TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)
        end

        local rotation = GetEntityRotation(cart)
        if math.abs(rotation.x) > 60.0 or math.abs(rotation.y) > 60.0 then
            DetachEntity(cache.ped, true, false)
            SetFollowPedCamViewMode(0)
            SetPedToRagdoll(cache.ped, 5000, 20000, 2, false, false, false)
            isRidingTrolley = false
            riddenTrolleyEntity = nil

            if netId > 0 then
                Entity(cart).state:set("isOccupied", false, true)
            end
        end

        if IsControlJustPressed(0, 73) then
            isRidingTrolley = false
            riddenTrolleyEntity = nil
            DetachEntity(cache.ped, true, false)

            local cartSpeed = GetEntitySpeed(cart)
            if cartSpeed < 1 then
                cartSpeed = 1
            end
            if cartSpeed > 10 then
                cartSpeed = 10
            end

            SetPedToRagdoll(cache.ped, cartSpeed * 1000, cartSpeed * 1500, 2, false, false, false)

            if netId > 0 then
                Entity(cart).state:set("isOccupied", false, true)
            end
        end
    end

    BLScav_ActiveTrolley = nil
    SetFollowPedCamViewMode(0)
end, false)

RegisterKeyMapping("rideCart", Config.Lang.ride_cart or "Ride Cart", "keyboard", "E")

local function ReportDerbyRun(track, cart, zonePoint)
    local startCoords = GetEntityCoords(Store.Ped)
    local endCoords = nil

    while isRidingTrolley do
        Wait(100)
        endCoords = GetEntityCoords(Store.Ped)
        if not isRidingTrolley then
            break
        end
    end

    while IsPedRagdoll(Store.Ped) do
        Wait(1000)
    end

    local distance = math.floor(#(endCoords - startCoords) * 100) / 100

    Framework.Notify(string.format(Config.Lang.traveled_distance_cart, distance))
    SetEntityAsNoLongerNeeded(cart)
    zonePoint.remove()

    Framework.TriggerCallback("bl_scav:derbyScore", function(success, position)
        if success then
            if tonumber(position) <= 10 then
                Framework.Notify(string.format(Config.Lang.placed_leaderboard, position))
            end
        else
            Framework.Notify(Config.Lang.nice_try)
        end
    end, distance, track.name)
end

local function ReportDerbyTournamentRun(tournament, cart)
    local startCoords = GetEntityCoords(Store.Ped)
    local endCoords = nil

    while isRidingTrolley do
        Wait(100)
        endCoords = GetEntityCoords(Store.Ped)
        if not isRidingTrolley then
            break
        end
    end

    while IsPedRagdoll(Store.Ped) do
        Wait(1000)
    end

    local distance = math.floor(#(endCoords - startCoords) * 100) / 100

    Framework.Notify(string.format(Config.Lang.traveled_distance, distance))
    SetEntityAsNoLongerNeeded(cart)

    Framework.TriggerCallback("bl_scav:derbyScoreTournament", function(success, position)
        SetTimeout(1500, function()
            if success then
                if tonumber(position) <= 10 then
                    Framework.Notify(string.format(Config.Lang.placed_leaderboard, position))
                end
            else
                Framework.Notify(Config.Lang.nice_try)
            end
        end)
    end, distance, tournament.name)
end

RegisterNetEvent("bl_scav:tournamentScoreUpdated", function(distance, isFirstPlace)
    local rounded = math.floor(distance * 100) / 100

    if isFirstPlace then
        Framework.Notify(string.format(Config.Lang.first_place_distance, rounded), "success")
    else
        Framework.Notify(string.format(Config.Lang.new_best_distance, rounded), "info")
    end
end)

RegisterNetEvent("bl_scav:tournamentStarting", function(track, minutesUntilStart)
    Framework.Notify(string.format(Config.Lang.derby_starting_soon, minutesUntilStart))
end)

RegisterNetEvent("bl_scav:tournamentStarted", function(tournament)
    local playerCoords = GetEntityCoords(Store.Ped)
    local startPoint = vector3(tournament.startPoint.x, tournament.startPoint.y, tournament.startPoint.z)

    if #(playerCoords - startPoint) > tournament.startPointRadius then
        Framework.Notify(Config.Lang.too_far_from_start, "error")
        return
    end

    Framework.Notify(string.format(Config.Lang.derby_started, tournament.name))

    local model = BLSCAV_TROLLEY_MODELS[math.random(1, #BLSCAV_TROLLEY_MODELS)]
    Framework.LoadModel(model)

    derbyTrolley = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
    BLScav_ActiveTrolley = derbyTrolley
    PlaceObjectOnGroundProperly(derbyTrolley)
    SetEntityAsMissionEntity(derbyTrolley, true, true)

    Wait(1000)
    GripTrolley(BLScav_ActiveTrolley)

    derbyLaunchZone = Points.New({
        debug = tournament.showStartZone,
        coords = vector3(tournament.startPoint.x, tournament.startPoint.y, tournament.startPoint.z),
        distance = tournament.startPointRadius,
        onExit = function(point)
            point.nearby = false
            if isRidingTrolley then
                CreateThread(function()
                    ReportDerbyTournamentRun(tournament, riddenTrolleyEntity)
                end)
            end
        end,
        onEnter = function(point)
            point.nearby = true
            derbyLaunchZone = point
        end,
    })
end)

RegisterNetEvent("bl_scav:tournamentFinished", function(tournamentId, result)
    if derbyLaunchZone then
        derbyLaunchZone.remove()
        derbyLaunchZone = nil
    end

    if result.source == Store.ServerId then
        Framework.Notify(Config.Lang.won_tournament, "success")
    else
        local rounded = math.floor(result.winnerDistance * 100) / 100
        Framework.Notify(string.format(Config.Lang.tournament_ended, result.name, rounded), "info")
    end
end)

local function ShowDerbyHostSetupMenu(track)
    local input = lib.inputDialog("Host Tournament", {
        {
            type = "number",
            label = Config.Lang.starts_in or "Starts In (Minutes)",
            default = 10,
            required = true,
        },
        {
            type = "number",
            label = Config.Lang.duration or "Duration (Minutes)",
            default = 10,
            min = 5,
            max = 60,
            required = true,
        },
        {
            type = "number",
            label = Config.Lang.buy_in or "Buy-In (Number of Bottle Caps)",
            default = 10,
            min = 0,
            max = 1000,
            required = true,
        },
    })

    if not input then
        return
    end

    local startsIn, duration, buyIn = input[1], input[2], input[3]

    Framework.TriggerCallback("bl_scav:hostTournament", function(success, errorMessage)
        if success then
            Framework.Notify(string.format(Config.Lang.tournament_will_start, startsIn))
        else
            Framework.Notify(errorMessage, "error")
        end
    end, track.name, startsIn, duration, entryFee)
end

local function ShowDerbySignupMenu(tournamentInfo, track, entryFee)
    local content = Config.Lang.tournament_signup

    if entryFee and entryFee > 0 then
        content = content .. " " .. string.format(Config.Lang.tournament_buyin, entryFee)
    end

    local result = lib.alertDialog({
        title = Config.Lang.tournament or "Tournament",
        content = content,
        cancel = true,
        labels = {
            cancel = Config.Lang.no_thanks or "No Thanks",
            confirm = Config.Lang.yes_please or "Yes Please!",
        },
    })

    if result == "confirm" then
        Framework.TriggerCallback("bl_scav:joinTournament", function(success, errorMessage)
            if success then
                Framework.Notify(Config.Lang.joined_tournament)
            else
                Framework.Notify(string.format(Config.Lang.failed_join_tournament, errorMessage), "error")
            end
        end, track.name, entryFee or 0)
    end
end

local function ShowTrolleyRecoveryMenu(tournamentInfo, track)
    local entryFee = tournamentInfo.buyIn
    if not entryFee or entryFee <= 0 then
        entryFee = 25
    end

    local result = lib.alertDialog({
        title = Config.Lang.lost_cart_title or "Lost your Cart?",
        content = string.format(Config.Lang.lost_cart, entryFee),
        cancel = true,
        labels = {
            cancel = Config.Lang.no_thanks or "No Thanks",
            confirm = Config.Lang.yes_please or "Yes Please!",
        },
    })

    if result == "confirm" then
        Framework.TriggerCallback("bl_scav:getNewCart", function(success, errorMessage)
            if success then
                Framework.Notify(Config.Lang.got_new_cart)

                local model = BLSCAV_TROLLEY_MODELS[math.random(1, #BLSCAV_TROLLEY_MODELS)]
                Framework.LoadModel(model)
                derbyTrolley = CreateObject(model, track.cartLocation.x, track.cartLocation.y, track.cartLocation.z, true, true, true)
                PlaceObjectOnGroundProperly(derbyTrolley)
                SetEntityAsMissionEntity(derbyTrolley, true, true)

                Wait(1000)
                GripTrolley(derbyTrolley)
            else
                Framework.Notify(errorMessage, "error")
            end
        end, track.name, entryFee)
    end
end

local function ShowDerbyHostMenu(track)
    Framework.TriggerCallback("bl_scav:getTournamentStatus", function(tournament, entryFee, status)
        local options = {}

        if not status or status ~= "active" then
            table.insert(options, 1, {
                key = "E",
                label = Config.Lang.let_go or "Let's go!",
                reaction = "Conversation",
                selected = function(data)
                    exports["envi-interact"]:UpdateSpeech(data.menuID, Config.Lang.take_cart_far)

                    derbyTrolley = track
                    if derbyTrolley then
                        if DoesEntityExist(derbyTrolley) then
                            DeleteEntity(derbyTrolley)
                        end
                    end

                    local model = BLSCAV_TROLLEY_MODELS[math.random(1, #BLSCAV_TROLLEY_MODELS)]
                    Framework.LoadModel(model)
                    derbyTrolley = CreateObject(model, track.cartLocation.x, track.cartLocation.y, track.cartLocation.z, true, true, true)
                    PlaceObjectOnGroundProperly(derbyTrolley)
                    SetEntityAsMissionEntity(derbyTrolley, true, true)

                    Points.New({
                        debug = track.showStartZone,
                        coords = vector3(track.startPoint.x, track.startPoint.y, track.startPoint.z),
                        distance = track.startPointRadius,
                        onExit = function(point)
                            point.nearby = false
                            if isRidingTrolley then
                                CreateThread(function()
                                    ReportDerbyRun(track, riddenTrolleyEntity, point)
                                end)
                            end
                        end,
                        onEnter = function(point)
                            point.nearby = true
                        end,
                    })

                    exports["envi-interact"]:CloseMenu(data.menuID)
                end,
            })

            table.insert(options, 2, {
                key = "L",
                label = Config.Lang.leaderboard or "Leaderboard",
                reaction = "Conversation",
                speech = Config.Lang.check_leaderboard,
                selected = function(data)
                    exports["envi-interact"]:CloseMenu(data.menuID)

                    Framework.TriggerCallback("bl_scav:getLeaderboard", function(leaderboard)
                        local header = "# " .. string.format(Config.Lang.leaderboard_title, track.name) .. [[

]]
                        header = header .. "| " .. (Config.Lang.position or "Position") .. " | " .. (Config.Lang.player or "Player") .. " | " .. (Config.Lang.distance or "Distance") .. " |\n"
                        header = header .. "|:--------:|:-------|:--------:|\n"

                        for _, entry in ipairs(leaderboard) do
                            local distanceText = string.format("%.2f", entry.distance)
                            header = header .. "| **#" .. entry.position .. "** | " .. entry.name .. " | " .. distanceText .. " |\n"
                        end

                        lib.alertDialog({
                            title = string.format(Config.Lang.top_racers, track.name),
                            content = header,
                        })
                    end, track.name)
                end,
            })
        end

        table.insert(options, {
            key = "X",
            label = Config.Lang.nevermind or "Nevermind",
            reaction = "Bye",
            speech = Config.Lang.derby_goodbye,
            selected = function(data)
                exports["envi-interact"]:CloseMenu(data.menuID)
            end,
        })

        if Framework.Player.Job.Name == Config.VagrantJobRole and not tournament then
            table.insert(options, 2, {
                key = "H",
                label = Config.Lang.host_tournament or "Host Tournament",
                reaction = "Conversation",
                speech = Config.Lang.help_fellow_hobo,
                selected = function(data)
                    exports["envi-interact"]:CloseMenu(data.menuID)
                    ShowDerbyHostSetupMenu(track)
                end,
            })
        end

        if tournament and status == "signup" then
            table.insert(options, 2, {
                key = "T",
                label = Config.Lang.tournament or "Tournament",
                reaction = "Yes",
                speech = Config.Lang.tournament_active,
                selected = function(data)
                    ShowDerbySignupMenu(tournament, track, entryFee)
                end,
            })
        elseif tournament and status == "active" then
            table.insert(options, 2, {
                key = "T",
                label = Config.Lang.tournament or "Tournament",
                reaction = "Yes",
                speech = Config.Lang.tournament_active,
                selected = function(data)
                    ShowTrolleyRecoveryMenu(tournament, track)
                end,
            })
        end

        exports["envi-interact"]:OpenChoiceMenu({
            title = Config.Lang.hobo_cart_derby or "Hobo Cart Derby",
            speech = Config.Lang.derby_goal,
            menuID = "cart_derby_host_" .. track.name:lower():gsub("%s+", "_"),
            position = "right",
            options = options,
        })
    end, track.name)
end

CreateThread(function()
    Wait(1000)

    for index, track in ipairs(Config.TrolleyDerby.Tracks) do
        local menuID = "cart_derby_host_" .. track.name:lower():gsub("%s+", "_")

        hostNPCs[index] = exports["envi-interact"]:CreateNPC({
            name = menuID,
            model = "a_m_m_skidrow_01",
            coords = vector3(track.npc.x, track.npc.y, track.npc.z - 1.0),
            heading = track.npc.w,
            isFrozen = true,
        }, {
            title = Config.Lang.cart_derby_host or "Cart Derby Host",
            speech = Config.Lang.derby_greeting,
            menuID = menuID,
            greeting = "Conversation",
            position = "right",
            focusCam = true,
            options = {
                {
                    key = "E",
                    label = Config.Lang.hobo_cart_derby or "Hobo Cart Derby",
                    reaction = "Conversation",
                    selected = function(data)
                        ShowDerbyHostMenu(track)
                    end,
                },
                {
                    key = "X",
                    label = Config.Lang.nevermind or "Nevermind",
                    reaction = "Bye",
                    speech = Config.Lang.derby_goodbye,
                    selected = function(data)
                        exports["envi-interact"]:CloseMenu(data.menuID)
                    end,
                },
            },
        })
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if derbyTrolley then
            if DoesEntityExist(derbyTrolley) then
                DeleteEntity(derbyTrolley)
            end
        end

        if isRidingTrolley then
            if riddenTrolleyEntity then
                if DoesEntityExist(riddenTrolleyEntity) then
                    if NetworkGetNetworkIdFromEntity(riddenTrolleyEntity) > 0 then
                        Entity(riddenTrolleyEntity).state:set("isOccupied", false, true)
                    end
                end
            end
        end

        for _, npc in ipairs(hostNPCs) do
            DeleteEntity(npc)
        end
    end
end)

CreateThread(function()
    AddStateBagChangeHandler("isOccupied", nil, function(bagName, key, value, unused, replicated)
        local entityIdString = bagName:match("entity:(%d+)")
        if not entityIdString then
            return
        end

        local entityId = tonumber(entityIdString)
        if not entityId then
            return
        end

        local entity = NetworkGetEntityFromNetworkId(entityId)
        if not (entity and DoesEntityExist(entity)) then
            return
        end

        if value then
            if BLScav_ActiveTrolley == entity then
                if BLScav_PushingTrolley then
                    ReleaseTrolley()
                end
            end
        end
    end)
end)

RegisterNetEvent("onPlayerDropped")

AddEventHandler("playerDropped", function()
    if isRidingTrolley then
        if riddenTrolleyEntity then
            if DoesEntityExist(riddenTrolleyEntity) then
                if NetworkGetNetworkIdFromEntity(riddenTrolleyEntity) > 0 then
                    Entity(riddenTrolleyEntity).state:set("isOccupied", false, true)
                end
            end
        end
    end
end)

AddEventHandler("playerSpawned", function()
    if isRidingTrolley then
        isRidingTrolley = false

        if riddenTrolleyEntity then
            if DoesEntityExist(riddenTrolleyEntity) then
                if NetworkGetNetworkIdFromEntity(riddenTrolleyEntity) > 0 then
                    Entity(riddenTrolleyEntity).state:set("isOccupied", false, true)
                end
            end
        end

        riddenTrolleyEntity = nil
        BLScav_ActiveTrolley = nil
    end
end)

-- Trolley death-watch: releases the player from a trolley if they die while riding.
-- Idles at 5s when not riding (nothing to watch) and tightens to 1s while mounted so
-- the detach happens promptly instead of up to five seconds late.
CreateThread(function()
    while true do
        Wait(isRidingTrolley and 1000 or 5000)
        if isRidingTrolley then
            if Framework.IsPlayerDead() then
                isRidingTrolley = false

                if riddenTrolleyEntity then
                    if DoesEntityExist(riddenTrolleyEntity) then
                        if NetworkGetNetworkIdFromEntity(riddenTrolleyEntity) > 0 then
                            Entity(riddenTrolleyEntity).state:set("isOccupied", false, true)
                        end

                        DetachEntity(cache.ped, true, false)
                    end
                end

                riddenTrolleyEntity = nil
                BLScav_ActiveTrolley = nil
            end
        end
    end
end)
