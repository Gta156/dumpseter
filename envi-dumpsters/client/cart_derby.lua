local deadPassengerRef = nil -- always nil in the original; every assignment site sets it back to nil, so the `if deadPassengerRef then ... end` blocks below are dead code. Preserved as-is.
local isSittingInCart = false
local sittingCartEntity = nil
IsPushingCart = false
CurrentCart = nil
local spawnedHostNPCs = {}
local tournamentCart = nil
local pushCartBusy = false

CART_MODELS = { 1395334609, 979462386, 1918323043, -230045366 }

local thrillRide = {
    active = false,
    totalDistance = 0,
    lastPosition = nil,
    blips = {},
}

local tournamentStartZone = nil

CreateThread(function()
    if Config.CartDerby.ConstantBlips then
        for _, track in pairs(Config.CartDerby.Tracks) do
            local blip = AddBlipForCoord(track.npc.x, track.npc.y, track.npc.z)
            SetBlipSprite(blip, 127)
            SetBlipColour(blip, 5)
            SetBlipAsShortRange(blip, true)
            SetBlipScale(blip, Config.CartDerby.BlipScale or 0.8)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.Lang.cart_derby_blip)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

function StartThrillRideMission()
    thrillRide.active = true
    thrillRide.totalDistance = 0
    thrillRide.lastPosition = nil
    thrillRide.blips = {}

    if not Config.CartDerby.ConstantBlips then
        for _, track in pairs(Config.CartDerby.Tracks) do
            local blip = AddBlipForCoord(track.npc.x, track.npc.y, track.npc.z)
            SetBlipSprite(blip, 127)
            SetBlipColour(blip, 5)
            SetBlipAsShortRange(blip, true)
            SetBlipScale(blip, Config.CartDerby.BlipScale or 0.8)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.Lang.cart_derby_blip)
            EndTextCommandSetBlipName(blip)
            table.insert(thrillRide.blips, blip)
        end
    end

    Framework.Notify(Config.Lang.check_map_derby, "info", 10000)

    CreateThread(function()
        local wasSitting = false
        while thrillRide.active do
            Wait(500)
            if isSittingInCart then
                if not thrillRide.lastPosition then
                    thrillRide.lastPosition = GetEntityCoords(cache.ped)
                end
                wasSitting = true
            else
                if wasSitting then
                    if thrillRide.lastPosition then
                        local traveled = #(GetEntityCoords(cache.ped) - thrillRide.lastPosition)
                        thrillRide.totalDistance = thrillRide.totalDistance + traveled

                        TriggerServerEvent("envi-dumpsters:server:UpdateMissionProgress", 4, {
                            total_distance = math.floor(thrillRide.totalDistance),
                        })

                        if thrillRide.totalDistance >= Config.Missions[4].RequiredDistance then
                            CompleteThrillRideMission()
                        end

                        Framework.Notify(string.format(Config.Lang.thrill_ride_distance, math.floor(thrillRide.totalDistance), Config.Missions[4].RequiredDistance), "info")
                    end
                end
                thrillRide.lastPosition = nil
                wasSitting = false
            end
        end
    end)

    Framework.Notify(string.format(Config.Lang.find_cart_ride, Config.Missions[4].RequiredDistance), "info")
end

function CompleteThrillRideMission()
    if thrillRide.active then
        thrillRide.active = false

        if thrillRide.blips then
            for _, blip in pairs(thrillRide.blips) do
                if DoesBlipExist(blip) then
                    RemoveBlip(blip)
                end
            end
            thrillRide.blips = nil
        end

        TriggerServerEvent("envi-dumpsters:server:CompleteThrillRide")
    end
end

function DetachCartWithBoost(chargeSeconds, forceLaunch)
    if not CurrentCart then
        return
    end

    DetachEntity(CurrentCart, true, true)
    ClearPedTasks(cache.ped)
    SetEntityCollision(CurrentCart, true, true)

    local cartSpeed = GetEntitySpeed(CurrentCart)

    if cartSpeed > 4.0 or forceLaunch then
        if Framework.Player.Job.Name == Config.HoboJobRole or forceLaunch then
            if GetFollowPedCamViewMode() ~= 4 then
                local animDict = "move_jump@beastjump"
                local animName = "jump_launch_l"
                Framework.LoadAnimDict(animDict)
                TaskPlayAnim(cache.ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            local forward = GetEntityForwardVector(CurrentCart)
            local boostPower = cartSpeed * math.random(math.floor(chargeSeconds / 2), math.floor(chargeSeconds))

            if boostPower < 5.0 then
                boostPower = 5.0
            elseif boostPower > 20.0 then
                boostPower = 20.0
            end

            if boostPower > 10.0 then
                local rarityRoll = math.random(1, 10)
                if rarityRoll <= 1 then
                    boostPower = boostPower * 2
                elseif rarityRoll <= 3 then
                    boostPower = boostPower * 1.5
                elseif rarityRoll <= 5 then
                    boostPower = boostPower * 1.25
                elseif rarityRoll <= 7 then
                    boostPower = boostPower * 1.1
                elseif rarityRoll <= 9 then
                    boostPower = boostPower * 1.05
                end
            end

            if forceLaunch then
                boostPower = boostPower * 2
            end

            SetEntityVelocity(CurrentCart, -forward.x * boostPower, -forward.y * boostPower, 0.0)

            RemoveAnimDict(dict)

            SetTimeout(math.random(500, 2000), function()
                ClearPedTasks(cache.ped)
            end)
        end
    end

    if cartSpeed > 4.0 then
        if deadPassengerRef then
            if IsEntityAttachedToEntity(deadPassengerRef, CurrentCart) then
                Wait(math.random(1500, 4500))
                ClearPedTasks(deadPassengerRef)
                DetachEntity(deadPassengerRef, true, true)
                SetPedCanRagdoll(deadPassengerRef, true)
                SetPedToRagdoll(deadPassengerRef, 1000, 5000, 2, false, false, false)

                local passengerForward = GetEntityForwardVector(deadPassengerRef)
                SetEntityVelocity(deadPassengerRef, passengerForward.x * cartSpeed * 2, passengerForward.y * cartSpeed * 2, 0.5)
                SetPedCanBeTargetted(deadPassengerRef, true)
                SetEntityInvincible(deadPassengerRef, false)
                SetBlockingOfNonTemporaryEvents(deadPassengerRef, false)
                deadPassengerRef = nil

                FailTaxiMission(Config.Lang.abandoned_passenger)
            end
        end
    end

    CurrentCart = nil
    IsPushingCart = false
end

function DetachCartFromPlayerNoBoost()
    if not CurrentCart then
        return
    end

    DetachEntity(CurrentCart, true, true)
    ClearPedTasks(cache.ped)
    SetEntityCollision(CurrentCart, true, true)

    local cartSpeed = GetEntitySpeed(CurrentCart)

    if cartSpeed > 5.0 then
        if deadPassengerRef then
            if IsEntityAttachedToEntity(deadPassengerRef, CurrentCart) then
                Wait(math.random(1500, 4500))
                ClearPedTasks(deadPassengerRef)
                DetachEntity(deadPassengerRef, true, true)
                SetPedCanRagdoll(deadPassengerRef, true)
                SetPedToRagdoll(deadPassengerRef, 1000, 5000, 2, false, false, false)

                local passengerForward = GetEntityForwardVector(deadPassengerRef)
                SetEntityVelocity(deadPassengerRef, passengerForward.x * cartSpeed * 2, passengerForward.y * cartSpeed * 2, 0.5)
                SetPedCanBeTargetted(deadPassengerRef, true)
                SetEntityInvincible(deadPassengerRef, false)
                SetBlockingOfNonTemporaryEvents(deadPassengerRef, false)
                deadPassengerRef = nil

                FailTaxiMission(Config.Lang.abandoned_passenger)
            end
        end
    end

    CurrentCart = nil
    IsPushingCart = false
end

function AttachCartToPlayer(entity, skipWalkTo)
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
                CurrentCart = entity
            end
        end
    end

    pushCartBusy = true

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

    IsPushingCart = true
    pushCartBusy = false
    CurrentCart = entity

    local boostChargeStart = 0
    lib.showTextUI(Config.Lang.cart_controls)
    SetTimeout(7000, function()
        lib.hideTextUI()
    end)

    CreateThread(function()
        while IsEntityAttachedToEntity(entity, cache.ped) do
            Wait(0)
            DisableControlAction(0, 24, true)

            if not IsEntityPlayingAnim(cache.ped, "anim@heists@box_carry@", "idle", 3) then
                DetachCartFromPlayerNoBoost()
                break
            end

            if IsPedDeadOrDying(cache.ped) then
                DetachCartFromPlayerNoBoost()
                break
            end

            if IsPedRagdoll(cache.ped) then
                DetachCartFromPlayerNoBoost()
                break
            end

            if IsControlJustPressed(0, 73) then
                boostChargeStart = GetGameTimer()
            elseif IsControlJustReleased(0, 73) then
                if boostChargeStart > 0 then
                    local chargeSeconds = math.min(1.0 + (GetGameTimer() - boostChargeStart) / 200, 10.0)
                    boostChargeStart = chargeSeconds
                    DetachCartWithBoost(boostChargeStart, skipWalkTo)
                    boostChargeStart = 0
                    break
                end
            end

            if IsDisabledControlJustPressed(0, 24) then
                if not IsControlPressed(0, 19) then
                    boostChargeStart = GetGameTimer()
                end
            elseif IsDisabledControlJustReleased(0, 24) then
                if boostChargeStart > 0 then
                    if not IsControlPressed(0, 19) then
                        local chargeSeconds = math.min(1.0 + (GetGameTimer() - boostChargeStart) / 200, 10.0)
                        boostChargeStart = chargeSeconds
                        DetachCartWithBoost(boostChargeStart, skipWalkTo)
                        boostChargeStart = 0
                        break
                    end
                end
            end

            if CurrentCart then
                local rotation = GetEntityRotation(CurrentCart)
                if math.abs(rotation.x) > 45.0 or math.abs(rotation.y) > 45.0 then
                    DetachCartFromPlayerNoBoost()
                    if deadPassengerRef then
                        deadPassengerRef = nil
                        FailTaxiMission(Config.Lang.cart_tipped)
                    end
                    break
                end
            end
        end

        IsPushingCart = false
        CurrentCart = nil
    end)
end

if Config.Target then
    Target.AddModel(CART_MODELS, {
        {
            label = Config.Lang.push_cart,
            icon = "fas fa-hand",
            distance = 2.0,
            canInteract = function(entity)
                return not IsPushingCart
            end,
            onSelect = function(data)
                print("netId", NetworkGetNetworkIdFromEntity(data.entity))
                if IsPushingCart then
                    return
                end
                CurrentCart = data.entity
                AttachCartToPlayer(data.entity)
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

                isSittingInCart = true
                sittingCartEntity = cart

                NetworkRequestControlOfEntity(cart)
                NetworkRegisterEntityAsNetworked(cart)
                SetEntityAsMissionEntity(cart, true, true)

                local netId = NetworkGetNetworkIdFromEntity(cart)
                if netId > 0 then
                    Entity(cart).state:set("isOccupied", true, true)
                    print("setting cart occupied")
                end

                while isSittingInCart do
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
                        isSittingInCart = false
                        sittingCartEntity = nil

                        if netId > 0 then
                            Entity(cart).state:set("isOccupied", false, true)
                        end
                    else
                        if IsControlJustPressed(0, 73) then
                            isSittingInCart = false
                            sittingCartEntity = nil
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

                CurrentCart = nil
                SetFollowPedCamViewMode(0)
            end,
            canInteract = function(entity)
                if IsPushingCart then
                    return false
                end
                if isSittingInCart then
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
    exports["envi-interact"]:InteractionModel(CART_MODELS, {
        {
            name = "cart_interaction",
            distance = 1.5,
            radius = 5.0,
            options = {
                {
                    label = Config.Lang.push_cart_e,
                    canSee = function()
                        if pushCartBusy then
                            return false
                        end
                        if IsPushingCart then
                            return false
                        end
                        return true
                    end,
                    selected = function(data)
                        print("pushing cart")
                        if not (pushCartBusy or IsPushingCart) then
                            pushCartBusy = true
                            CurrentCart = data.entity
                            AttachCartToPlayer(data.entity)
                            pushCartBusy = false
                        end
                    end,
                },
                {
                    label = Config.Lang.sit_in_cart_e,
                    canSee = function(entity)
                        if pushCartBusy then
                            return false
                        end
                        if IsPushingCart then
                            return false
                        end
                        if isSittingInCart then
                            return false
                        end
                        if not IsEntityUpright(entity, 45) then
                            return false
                        end
                        return true
                    end,
                    selected = function(data)
                        if pushCartBusy then
                            return
                        end
                        pushCartBusy = true

                        local animDict = "amb@code_human_train_driver@base"
                        local animName = "sit"
                        Framework.LoadAnimDict(animDict)

                        local cart = data.entity
                        AttachEntityToEntity(cache.ped, cart, 0, 0.0, 0.0, 0.1, 0.0, 0.0, 180.0, true, true, false, true, 1, true)
                        TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)

                        isSittingInCart = true
                        sittingCartEntity = cart

                        NetworkRequestControlOfEntity(cart)
                        NetworkRegisterEntityAsNetworked(cart)
                        SetEntityAsMissionEntity(cart, true, true)

                        local netId = NetworkGetNetworkIdFromEntity(cart)
                        if netId > 0 then
                            Entity(cart).state:set("isOccupied", true, true)
                        end

                        while isSittingInCart do
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
                                isSittingInCart = false
                                sittingCartEntity = nil

                                if netId > 0 then
                                    Entity(cart).state:set("isOccupied", false, true)
                                end
                            end
                        end

                        CurrentCart = nil
                        SetFollowPedCamViewMode(0)
                    end,
                },
            },
        },
    })
end

RegisterCommand("leave_cart", function()
    if not isSittingInCart then
        return
    end

    isSittingInCart = false

    if not sittingCartEntity then
        return
    end

    local cart = sittingCartEntity
    sittingCartEntity = nil

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

RegisterKeyMapping("leave_cart", Config.Lang.leave_cart or "Leave Cart", "keyboard", Config.LeaveCartKey or "X")

RegisterCommand("rideCart", function()
    if pushCartBusy then
        return
    end
    if not CurrentCart then
        return
    end

    local animDict = "amb@code_human_train_driver@base"
    local animName = "sit"
    local cart = CurrentCart

    DetachCartFromPlayerNoBoost()
    Framework.LoadAnimDict(animDict)

    local netId = NetworkGetNetworkIdFromEntity(cart)
    AttachEntityToEntity(cache.ped, cart, 0, 0.0, 0.0, 0.1, 0.0, 0.0, 180.0, true, true, false, true, 1, true)
    TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 1, 0, false, false, false)

    isSittingInCart = true
    sittingCartEntity = cart

    if netId > 0 then
        Entity(cart).state:set("isOccupied", true, true)
    end

    while isSittingInCart do
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
            isSittingInCart = false
            sittingCartEntity = nil

            if netId > 0 then
                Entity(cart).state:set("isOccupied", false, true)
            end
        end

        if IsControlJustPressed(0, 73) then
            isSittingInCart = false
            sittingCartEntity = nil
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

    CurrentCart = nil
    SetFollowPedCamViewMode(0)
end, false)

RegisterKeyMapping("rideCart", Config.Lang.ride_cart or "Ride Cart", "keyboard", "E")

local function SubmitDerbyScore(track, cart, zonePoint)
    local startCoords = GetEntityCoords(Store.Ped)
    local endCoords = nil

    while isSittingInCart do
        Wait(100)
        endCoords = GetEntityCoords(Store.Ped)
        if not isSittingInCart then
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

    Framework.TriggerCallback("envi-dumpsters:derbyScore", function(success, position)
        if success then
            if tonumber(position) <= 10 then
                Framework.Notify(string.format(Config.Lang.placed_leaderboard, position))
            end
        else
            Framework.Notify(Config.Lang.nice_try)
        end
    end, distance, track.name)
end

local function SubmitTournamentScore(tournament, cart)
    local startCoords = GetEntityCoords(Store.Ped)
    local endCoords = nil

    while isSittingInCart do
        Wait(100)
        endCoords = GetEntityCoords(Store.Ped)
        if not isSittingInCart then
            break
        end
    end

    while IsPedRagdoll(Store.Ped) do
        Wait(1000)
    end

    local distance = math.floor(#(endCoords - startCoords) * 100) / 100

    Framework.Notify(string.format(Config.Lang.traveled_distance, distance))
    SetEntityAsNoLongerNeeded(cart)

    Framework.TriggerCallback("envi-dumpsters:derbyScoreTournament", function(success, position)
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

RegisterNetEvent("envi-dumpsters:tournamentScoreUpdated", function(distance, isFirstPlace)
    local rounded = math.floor(distance * 100) / 100

    if isFirstPlace then
        Framework.Notify(string.format(Config.Lang.first_place_distance, rounded), "success")
    else
        Framework.Notify(string.format(Config.Lang.new_best_distance, rounded), "info")
    end
end)

RegisterNetEvent("envi-dumpsters:tournamentStarting", function(track, minutesUntilStart)
    Framework.Notify(string.format(Config.Lang.derby_starting_soon, minutesUntilStart))
end)

RegisterNetEvent("envi-dumpsters:tournamentStarted", function(tournament)
    local playerCoords = GetEntityCoords(Store.Ped)
    local startPoint = vector3(tournament.startPoint.x, tournament.startPoint.y, tournament.startPoint.z)

    if #(playerCoords - startPoint) > tournament.startPointRadius then
        Framework.Notify(Config.Lang.too_far_from_start, "error")
        return
    end

    Framework.Notify(string.format(Config.Lang.derby_started, tournament.name))

    local model = CART_MODELS[math.random(1, #CART_MODELS)]
    Framework.LoadModel(model)

    tournamentCart = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
    CurrentCart = tournamentCart
    PlaceObjectOnGroundProperly(tournamentCart)
    SetEntityAsMissionEntity(tournamentCart, true, true)

    Wait(1000)
    AttachCartToPlayer(CurrentCart)

    tournamentStartZone = Points.New({
        debug = tournament.showStartZone,
        coords = vector3(tournament.startPoint.x, tournament.startPoint.y, tournament.startPoint.z),
        distance = tournament.startPointRadius,
        onExit = function(point)
            point.nearby = false
            if isSittingInCart then
                CreateThread(function()
                    SubmitTournamentScore(tournament, sittingCartEntity)
                end)
            end
        end,
        onEnter = function(point)
            point.nearby = true
            tournamentStartZone = point
        end,
    })
end)

RegisterNetEvent("envi-dumpsters:tournamentFinished", function(tournamentId, result)
    if tournamentStartZone then
        tournamentStartZone.remove()
        tournamentStartZone = nil
    end

    if result.source == Store.ServerId then
        Framework.Notify(Config.Lang.won_tournament, "success")
    else
        local rounded = math.floor(result.winnerDistance * 100) / 100
        Framework.Notify(string.format(Config.Lang.tournament_ended, result.name, rounded), "info")
    end
end)

local function HostTournamentMenu(track)
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

    Framework.TriggerCallback("envi-dumpsters:hostTournament", function(success, errorMessage)
        if success then
            Framework.Notify(string.format(Config.Lang.tournament_will_start, startsIn))
        else
            Framework.Notify(errorMessage, "error")
        end
    end, track.name, startsIn, duration, buyIn)
end

local function ShowTournamentSignupMenu(tournamentInfo, track, buyIn)
    local content = Config.Lang.tournament_signup

    if buyIn and buyIn > 0 then
        content = content .. " " .. string.format(Config.Lang.tournament_buyin, buyIn)
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
        Framework.TriggerCallback("envi-dumpsters:joinTournament", function(success, errorMessage)
            if success then
                Framework.Notify(Config.Lang.joined_tournament)
            else
                Framework.Notify(string.format(Config.Lang.failed_join_tournament, errorMessage), "error")
            end
        end, track.name, buyIn or 0)
    end
end

local function ShowLostCartMenu(tournamentInfo, track)
    local buyIn = tournamentInfo.buyIn
    if not buyIn or buyIn <= 0 then
        buyIn = 25
    end

    local result = lib.alertDialog({
        title = Config.Lang.lost_cart_title or "Lost your Cart?",
        content = string.format(Config.Lang.lost_cart, buyIn),
        cancel = true,
        labels = {
            cancel = Config.Lang.no_thanks or "No Thanks",
            confirm = Config.Lang.yes_please or "Yes Please!",
        },
    })

    if result == "confirm" then
        Framework.TriggerCallback("envi-dumpsters:getNewCart", function(success, errorMessage)
            if success then
                Framework.Notify(Config.Lang.got_new_cart)

                local model = CART_MODELS[math.random(1, #CART_MODELS)]
                Framework.LoadModel(model)
                tournamentCart = CreateObject(model, track.cartLocation.x, track.cartLocation.y, track.cartLocation.z, true, true, true)
                PlaceObjectOnGroundProperly(tournamentCart)
                SetEntityAsMissionEntity(tournamentCart, true, true)

                Wait(1000)
                AttachCartToPlayer(tournamentCart)
            else
                Framework.Notify(errorMessage, "error")
            end
        end, track.name, buyIn)
    end
end

local function OpenTrackNPCMenu(track)
    Framework.TriggerCallback("envi-dumpsters:getTournamentStatus", function(tournament, buyIn, status)
        local options = {}

        if not status or status ~= "active" then
            table.insert(options, 1, {
                key = "E",
                label = Config.Lang.let_go or "Let's go!",
                reaction = "Conversation",
                selected = function(data)
                    exports["envi-interact"]:UpdateSpeech(data.menuID, Config.Lang.take_cart_far)

                    tournamentCart = track
                    if tournamentCart then
                        if DoesEntityExist(tournamentCart) then
                            DeleteEntity(tournamentCart)
                        end
                    end

                    local model = CART_MODELS[math.random(1, #CART_MODELS)]
                    Framework.LoadModel(model)
                    tournamentCart = CreateObject(model, track.cartLocation.x, track.cartLocation.y, track.cartLocation.z, true, true, true)
                    PlaceObjectOnGroundProperly(tournamentCart)
                    SetEntityAsMissionEntity(tournamentCart, true, true)

                    Points.New({
                        debug = track.showStartZone,
                        coords = vector3(track.startPoint.x, track.startPoint.y, track.startPoint.z),
                        distance = track.startPointRadius,
                        onExit = function(point)
                            point.nearby = false
                            if isSittingInCart then
                                CreateThread(function()
                                    SubmitDerbyScore(track, sittingCartEntity, point)
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

                    Framework.TriggerCallback("envi-dumpsters:getLeaderboard", function(leaderboard)
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

        if Framework.Player.Job.Name == Config.HoboJobRole and not tournament then
            table.insert(options, 2, {
                key = "H",
                label = Config.Lang.host_tournament or "Host Tournament",
                reaction = "Conversation",
                speech = Config.Lang.help_fellow_hobo,
                selected = function(data)
                    exports["envi-interact"]:CloseMenu(data.menuID)
                    HostTournamentMenu(track)
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
                    ShowTournamentSignupMenu(tournament, track, buyIn)
                end,
            })
        elseif tournament and status == "active" then
            table.insert(options, 2, {
                key = "T",
                label = Config.Lang.tournament or "Tournament",
                reaction = "Yes",
                speech = Config.Lang.tournament_active,
                selected = function(data)
                    ShowLostCartMenu(tournament, track)
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

    for index, track in ipairs(Config.CartDerby.Tracks) do
        local menuID = "cart_derby_host_" .. track.name:lower():gsub("%s+", "_")

        spawnedHostNPCs[index] = exports["envi-interact"]:CreateNPC({
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
                        OpenTrackNPCMenu(track)
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
        if tournamentCart then
            if DoesEntityExist(tournamentCart) then
                DeleteEntity(tournamentCart)
            end
        end

        if isSittingInCart then
            if sittingCartEntity then
                if DoesEntityExist(sittingCartEntity) then
                    if NetworkGetNetworkIdFromEntity(sittingCartEntity) > 0 then
                        Entity(sittingCartEntity).state:set("isOccupied", false, true)
                    end
                end
            end
        end

        for _, npc in ipairs(spawnedHostNPCs) do
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
            if CurrentCart == entity then
                if IsPushingCart then
                    DetachCartFromPlayerNoBoost()
                end
            end
        end
    end)
end)

RegisterNetEvent("onPlayerDropped")

AddEventHandler("playerDropped", function()
    if isSittingInCart then
        if sittingCartEntity then
            if DoesEntityExist(sittingCartEntity) then
                if NetworkGetNetworkIdFromEntity(sittingCartEntity) > 0 then
                    Entity(sittingCartEntity).state:set("isOccupied", false, true)
                end
            end
        end
    end
end)

AddEventHandler("playerSpawned", function()
    if isSittingInCart then
        isSittingInCart = false

        if sittingCartEntity then
            if DoesEntityExist(sittingCartEntity) then
                if NetworkGetNetworkIdFromEntity(sittingCartEntity) > 0 then
                    Entity(sittingCartEntity).state:set("isOccupied", false, true)
                end
            end
        end

        sittingCartEntity = nil
        CurrentCart = nil
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        if isSittingInCart then
            if Framework.IsPlayerDead() then
                isSittingInCart = false

                if sittingCartEntity then
                    if DoesEntityExist(sittingCartEntity) then
                        if NetworkGetNetworkIdFromEntity(sittingCartEntity) > 0 then
                            Entity(sittingCartEntity).state:set("isOccupied", false, true)
                        end

                        DetachEntity(cache.ped, true, false)
                    end
                end

                sittingCartEntity = nil
                CurrentCart = nil
            end
        end
    end
end)
