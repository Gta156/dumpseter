--[[ ==========================================================================
     BlackLight Dumpsters — Trolley Handling & Derby (client)
========================================================================== ]]

local random, floor, abs, min = math.random, math.floor, math.abs, math.min
local insert = table.insert

-- Shared globals consumed by other modules
TrolleyHeld = false
HeldTrolley = nil
TROLLEY_MODELS = { 1395334609, 979462386, 1918323043, -230045366 }

local ridingTrolley = false
local riddenTrolley = nil
local compereNPCs = {}
local derbyTrolley = nil
local grabInProgress = false

local CARRY_DICT = "anim@heists@box_carry@"
local CARRY_CLIP = "idle"
local SIT_DICT = "amb@code_human_train_driver@base"
local SIT_CLIP = "sit"

local INTERACT = "blacklight-interact"

local downhillRush = {
    running = false,
    metres = 0,
    lastAnchor = nil,
    markers = {},
}

local launchZone = nil

-- --------------------------------------------------------------------------
--  VENUE BLIPS
-- --------------------------------------------------------------------------

local function AddVenueBlip(venue)
    local blip = AddBlipForCoord(venue.npc.x, venue.npc.y, venue.npc.z)
    SetBlipSprite(blip, 127)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)
    SetBlipScale(blip, Settings.TrolleyDerby.BlipSize or 0.8)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Settings.Text.derby_blip)
    EndTextCommandSetBlipName(blip)
    return blip
end

CreateThread(function()
    if Settings.TrolleyDerby.AlwaysShowBlips then
        for _, venue in pairs(Settings.TrolleyDerby.Venues) do
            AddVenueBlip(venue)
        end
    end
end)

-- --------------------------------------------------------------------------
--  CHAPTER 4 — DOWNHILL RUSH
-- --------------------------------------------------------------------------

function BeginDownhillRush()
    downhillRush.running = true
    downhillRush.metres = 0
    downhillRush.lastAnchor = nil
    downhillRush.markers = {}

    if not Settings.TrolleyDerby.AlwaysShowBlips then
        for _, venue in pairs(Settings.TrolleyDerby.Venues) do
            insert(downhillRush.markers, AddVenueBlip(venue))
        end
    end

    Framework.Notify(Settings.Text.derby_check_map, "info", 10000)

    CreateThread(function()
        local wasRiding = false

        while downhillRush.running do
            Wait(500)

            if ridingTrolley then
                downhillRush.lastAnchor = downhillRush.lastAnchor or GetEntityCoords(cache.ped)
                wasRiding = true
            else
                if wasRiding and downhillRush.lastAnchor then
                    local covered = #(GetEntityCoords(cache.ped) - downhillRush.lastAnchor)
                    downhillRush.metres = downhillRush.metres + covered

                    TriggerServerEvent("bl_dumpsters:server:PushChapterProgress", 4, {
                        total_distance = floor(downhillRush.metres),
                    })

                    if downhillRush.metres >= Settings.Chapters[4].TargetMetres then
                        CompleteDownhillRush()
                    end

                    Framework.Notify(string.format(Settings.Text.rush_progress, floor(downhillRush.metres), Settings.Chapters[4].TargetMetres), "info")
                end

                downhillRush.lastAnchor = nil
                wasRiding = false
            end
        end
    end)

    Framework.Notify(string.format(Settings.Text.rush_briefing, Settings.Chapters[4].TargetMetres), "info")
end

function CompleteDownhillRush()
    if not downhillRush.running then
        return
    end

    downhillRush.running = false

    for _, marker in pairs(downhillRush.markers or {}) do
        if DoesBlipExist(marker) then
            RemoveBlip(marker)
        end
    end
    downhillRush.markers = nil

    TriggerServerEvent("bl_dumpsters:server:CompleteDownhillRush")
end

-- --------------------------------------------------------------------------
--  TROLLEY CARRYING
-- --------------------------------------------------------------------------

--- Ejects an attached passenger when the trolley is launched or tipped.
local function EjectPassengerFromTrolley(trolleySpeed)
    if not (CabPassenger and IsEntityAttachedToEntity(CabPassenger, HeldTrolley)) then
        return
    end

    Wait(random(1500, 4500))
    ClearPedTasks(CabPassenger)
    DetachEntity(CabPassenger, true, true)
    SetPedCanRagdoll(CabPassenger, true)
    SetPedToRagdoll(CabPassenger, 1000, 5000, 2, false, false, false)

    local forward = GetEntityForwardVector(CabPassenger)
    SetEntityVelocity(CabPassenger, forward.x * trolleySpeed * 2, forward.y * trolleySpeed * 2, 0.5)
    SetPedCanBeTargetted(CabPassenger, true)
    SetEntityInvincible(CabPassenger, false)
    SetBlockingOfNonTemporaryEvents(CabPassenger, false)
    CabPassenger = nil

    AbortCabRun(Settings.Text.fare_abandoned)
end

--- Releases the trolley with a charged shove.
---@param chargeSeconds number How long the launch was charged for.
---@param forceLaunch boolean|nil Bypasses the job requirement (used by bowling).
function LaunchTrolley(chargeSeconds, forceLaunch)
    if not HeldTrolley then
        return
    end

    local trolley = HeldTrolley

    DetachEntity(trolley, true, true)
    ClearPedTasks(cache.ped)
    SetEntityCollision(trolley, true, true)

    local trolleySpeed = GetEntitySpeed(trolley)

    if trolleySpeed > 4.0 and (Framework.Player.Job.Name == Settings.VagrantJobName or forceLaunch) then
        if GetFollowPedCamViewMode() ~= 4 then
            local clipDict = "move_jump@beastjump"
            local clipName = "jump_launch_l"
            Framework.LoadAnimDict(clipDict)
            TaskPlayAnim(cache.ped, clipDict, clipName, 8.0, -8.0, -1, 49, 0, false, false, false)
            RemoveAnimDict(clipDict)
        end

        local forward = GetEntityForwardVector(trolley)
        local power = trolleySpeed * random(floor(chargeSeconds / 2), floor(chargeSeconds))

        power = math.max(5.0, math.min(power, 20.0))

        -- Lucky launches get a rarity-weighted multiplier.
        if power > 10.0 then
            local rarityRoll = random(1, 10)
            if rarityRoll <= 1 then
                power = power * 2
            elseif rarityRoll <= 3 then
                power = power * 1.5
            elseif rarityRoll <= 5 then
                power = power * 1.25
            elseif rarityRoll <= 7 then
                power = power * 1.1
            elseif rarityRoll <= 9 then
                power = power * 1.05
            end
        end

        if forceLaunch then
            power = power * 2
        end

        SetEntityVelocity(trolley, -forward.x * power, -forward.y * power, 0.0)

        SetTimeout(random(500, 2000), function()
            ClearPedTasks(cache.ped)
        end)
    end

    if trolleySpeed > 4.0 then
        EjectPassengerFromTrolley(trolleySpeed)
    end

    HeldTrolley = nil
    TrolleyHeld = false
end

--- Drops the trolley without any launch impulse.
function DropTrolley()
    if not HeldTrolley then
        return
    end

    local trolley = HeldTrolley

    DetachEntity(trolley, true, true)
    ClearPedTasks(cache.ped)
    SetEntityCollision(trolley, true, true)

    local trolleySpeed = GetEntitySpeed(trolley)
    if trolleySpeed > 5.0 then
        EjectPassengerFromTrolley(trolleySpeed)
    end

    HeldTrolley = nil
    TrolleyHeld = false
end

--- Attaches a trolley to the player so it can be pushed around.
---@param entity number Trolley object.
---@param skipApproach boolean|nil Skip the walk-up step (used by bowling).
function GrabTrolley(entity, skipApproach)
    -- Respawn drifting world trolleys as mission entities so physics behave.
    if NetworkGetNetworkIdFromEntity(entity) and not Entity(entity).state.isOccupied and not IsEntityAMissionEntity(entity) then
        local model = GetEntityModel(entity)
        local coords = GetEntityCoords(entity)
        SetEntityAsMissionEntity(entity, true, true)
        DeleteEntity(entity)
        entity = CreateObject(model, coords.x, coords.y, coords.z - 0.5, true, true, true)
        HeldTrolley = entity
    end

    grabInProgress = true

    if not skipApproach then
        local coords = GetEntityCoords(entity)
        TaskGoStraightToCoord(cache.ped, coords.x, coords.y, coords.z, 1.0, 100, 0, 0)
        Wait(100)
    end

    if not DoesEntityExist(entity) or IsEntityAttached(entity) then
        grabInProgress = false
        return
    end

    NetworkRequestControlOfEntity(entity)
    NetworkRegisterEntityAsNetworked(entity)
    SetEntityAsMissionEntity(entity, true, true)

    Framework.LoadAnimDict(CARRY_DICT)
    TaskPlayAnim(cache.ped, CARRY_DICT, CARRY_CLIP, 8.0, 8.0, -1, 50, 0, false, false, false)
    Wait(150)

    AttachEntityToEntity(entity, cache.ped, GetPedBoneIndex(cache.ped, 28422),
        -0.0, -0.49, -0.763, 195.0, 180.0, 180.0,
        0.0, false, false, true, false, 2, true)

    TrolleyHeld = true
    grabInProgress = false
    HeldTrolley = entity

    lib.showTextUI(Settings.Text.trolley_controls)
    SetTimeout(7000, function()
        lib.hideTextUI()
    end)

    CreateThread(function()
        local chargeStartedAt = 0

        while IsEntityAttachedToEntity(entity, cache.ped) do
            Wait(0)
            DisableControlAction(0, 24, true)

            if not IsEntityPlayingAnim(cache.ped, CARRY_DICT, CARRY_CLIP, 3)
                or IsPedDeadOrDying(cache.ped)
                or IsPedRagdoll(cache.ped) then
                DropTrolley()
                break
            end

            -- Charge & release on the dedicated key.
            if IsControlJustPressed(0, 73) then
                chargeStartedAt = GetGameTimer()
            elseif IsControlJustReleased(0, 73) and chargeStartedAt > 0 then
                LaunchTrolley(min(1.0 + (GetGameTimer() - chargeStartedAt) / 200, 10.0), skipApproach)
                break
            end

            -- Charge & release on attack (unless aiming).
            if IsDisabledControlJustPressed(0, 24) and not IsControlPressed(0, 19) then
                chargeStartedAt = GetGameTimer()
            elseif IsDisabledControlJustReleased(0, 24) and chargeStartedAt > 0 and not IsControlPressed(0, 19) then
                LaunchTrolley(min(1.0 + (GetGameTimer() - chargeStartedAt) / 200, 10.0), skipApproach)
                break
            end

            -- Tipping the trolley over drops it (and any fare).
            if HeldTrolley then
                local rotation = GetEntityRotation(HeldTrolley)
                if abs(rotation.x) > 45.0 or abs(rotation.y) > 45.0 then
                    DropTrolley()
                    if CabPassenger then
                        CabPassenger = nil
                        AbortCabRun(Settings.Text.trolley_flipped)
                    end
                    break
                end
            end
        end

        TrolleyHeld = false
        HeldTrolley = nil
    end)
end

-- --------------------------------------------------------------------------
--  TROLLEY RIDING
-- --------------------------------------------------------------------------

--- Detaches the player from a trolley they are sitting in and ragdolls them.
local function BailFromTrolley(trolley, netId, hardBail)
    ridingTrolley = false
    riddenTrolley = nil
    DetachEntity(cache.ped, true, false)

    if hardBail then
        SetFollowPedCamViewMode(0)
        SetPedToRagdoll(cache.ped, 5000, 20000, 2, false, false, false)
    else
        local trolleySpeed = math.max(1, math.min(GetEntitySpeed(trolley), 10))
        SetPedToRagdoll(cache.ped, trolleySpeed * 1000, trolleySpeed * 1500, 2, false, false, false)
    end

    if netId > 0 then
        Entity(trolley).state:set("isOccupied", false, true)
    end
end

--- Sits the player inside the trolley and runs the ride loop until they bail.
local function RideTrolley(trolley)
    Framework.LoadAnimDict(SIT_DICT)

    AttachEntityToEntity(cache.ped, trolley, 0, 0.0, 0.0, 0.1, 0.0, 0.0, 180.0, true, true, false, true, 1, true)
    TaskPlayAnim(cache.ped, SIT_DICT, SIT_CLIP, 8.0, 8.0, -1, 1, 0, false, false, false)

    ridingTrolley = true
    riddenTrolley = trolley

    NetworkRequestControlOfEntity(trolley)
    NetworkRegisterEntityAsNetworked(trolley)
    SetEntityAsMissionEntity(trolley, true, true)

    local netId = NetworkGetNetworkIdFromEntity(trolley)
    if netId > 0 then
        Entity(trolley).state:set("isOccupied", true, true)
    end

    while ridingTrolley do
        Wait(0)

        if GetFollowPedCamViewMode() ~= 4 then
            SetFollowPedCamViewMode(4)
        end

        if not IsEntityPlayingAnim(cache.ped, SIT_DICT, SIT_CLIP, 3) then
            TaskPlayAnim(cache.ped, SIT_DICT, SIT_CLIP, 8.0, 8.0, -1, 1, 0, false, false, false)
        end

        local rotation = GetEntityRotation(trolley)
        if abs(rotation.x) > 60.0 or abs(rotation.y) > 60.0 then
            BailFromTrolley(trolley, netId, true)
        elseif IsControlJustPressed(0, 73) then
            BailFromTrolley(trolley, netId, false)
        end
    end

    HeldTrolley = nil
    SetFollowPedCamViewMode(0)
end

--- Is the trolley currently free to be sat in?
local function TrolleyRideable(entity)
    if TrolleyHeld or ridingTrolley or grabInProgress then
        return false
    end
    if not IsEntityUpright(entity, 45) then
        return false
    end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId > 0 and Entity(entity).state.isOccupied then
        return false
    end

    return true
end

if Settings.UseTargetSystem then
    Target.AddModel(TROLLEY_MODELS, {
        {
            label = Settings.Text.trolley_push,
            icon = "fas fa-hand",
            distance = 2.0,
            canInteract = function()
                return not TrolleyHeld
            end,
            onSelect = function(data)
                if TrolleyHeld then
                    return
                end
                HeldTrolley = data.entity
                GrabTrolley(data.entity)
            end,
        },
        {
            label = Settings.Text.trolley_mount,
            icon = "fas fa-hand",
            distance = 2.0,
            canInteract = TrolleyRideable,
            onSelect = function(data)
                RideTrolley(data.entity)
            end,
        },
    })
else
    exports[INTERACT]:InteractionModel(TROLLEY_MODELS, {
        {
            name = "bl_trolley_interaction",
            distance = 1.5,
            radius = 5.0,
            options = {
                {
                    label = Settings.Text.trolley_push_key,
                    canSee = function()
                        return not (grabInProgress or TrolleyHeld)
                    end,
                    selected = function(data)
                        if grabInProgress or TrolleyHeld then
                            return
                        end
                        grabInProgress = true
                        HeldTrolley = data.entity
                        GrabTrolley(data.entity)
                        grabInProgress = false
                    end,
                },
                {
                    label = Settings.Text.trolley_mount_key,
                    canSee = TrolleyRideable,
                    selected = function(data)
                        if grabInProgress then
                            return
                        end
                        grabInProgress = true
                        RideTrolley(data.entity)
                        grabInProgress = false
                    end,
                },
            },
        },
    })
end

-- --------------------------------------------------------------------------
--  KEYBINDS
-- --------------------------------------------------------------------------

RegisterCommand("bl_dismount_trolley", function()
    if not ridingTrolley or not riddenTrolley then
        return
    end

    local trolley = riddenTrolley
    BailFromTrolley(trolley, NetworkGetNetworkIdFromEntity(trolley), false)
end, false)

RegisterKeyMapping("bl_dismount_trolley", Settings.Text.dismount_trolley_key, "keyboard", Settings.DismountCartKey or "X")

RegisterCommand("bl_mount_trolley", function()
    if grabInProgress or not HeldTrolley then
        return
    end

    local trolley = HeldTrolley
    DropTrolley()
    RideTrolley(trolley)
end, false)

RegisterKeyMapping("bl_mount_trolley", Settings.Text.mount_trolley_key, "keyboard", "E")

-- --------------------------------------------------------------------------
--  SCORE SUBMISSION
-- --------------------------------------------------------------------------

--- Waits for the ride to end and returns the distance covered in metres.
local function MeasureRunDistance()
    local startCoords = GetEntityCoords(Store.Ped)
    local endCoords = startCoords

    while ridingTrolley do
        Wait(100)
        endCoords = GetEntityCoords(Store.Ped)
    end

    while IsPedRagdoll(Store.Ped) do
        Wait(1000)
    end

    return floor(#(endCoords - startCoords) * 100) / 100
end

local function SubmitFreeRunScore(venue, trolley, zonePoint)
    local metres = MeasureRunDistance()

    Framework.Notify(string.format(Settings.Text.trolley_distance, metres))
    SetEntityAsNoLongerNeeded(trolley)
    zonePoint.remove()

    Framework.TriggerCallback("bl_dumpsters:server:SubmitRunScore", function(success, position)
        if success and tonumber(position) and tonumber(position) <= 10 then
            Framework.Notify(string.format(Settings.Text.ranked_on_board, position))
        elseif not success then
            Framework.Notify(Settings.Text.good_attempt)
        end
    end, metres, venue.name)
end

local function SubmitCupScore(cup, trolley)
    local metres = MeasureRunDistance()

    Framework.Notify(string.format(Settings.Text.distance_covered, metres))
    SetEntityAsNoLongerNeeded(trolley)

    Framework.TriggerCallback("bl_dumpsters:server:SubmitCupScore", function(success, position)
        SetTimeout(1500, function()
            if success and tonumber(position) and tonumber(position) <= 10 then
                Framework.Notify(string.format(Settings.Text.ranked_on_board, position))
            elseif not success then
                Framework.Notify(Settings.Text.good_attempt)
            end
        end)
    end, metres, cup.name)
end

-- --------------------------------------------------------------------------
--  CUP EVENTS
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:client:CupScoreLogged", function(metres, isLeading)
    local rounded = floor(metres * 100) / 100

    if isLeading then
        Framework.Notify(string.format(Settings.Text.leading_distance, rounded), "success")
    else
        Framework.Notify(string.format(Settings.Text.personal_best, rounded), "info")
    end
end)

RegisterNetEvent("bl_dumpsters:client:CupCountdown", function(venue, minutesRemaining)
    Framework.Notify(string.format(Settings.Text.cup_countdown, minutesRemaining))
end)

RegisterNetEvent("bl_dumpsters:client:CupUnderway", function(cup)
    local playerCoords = GetEntityCoords(Store.Ped)
    local launchPoint = vector3(cup.launchPoint.x, cup.launchPoint.y, cup.launchPoint.z)

    if #(playerCoords - launchPoint) > cup.launchRadius then
        Framework.Notify(Settings.Text.outside_launch_zone, "error")
        return
    end

    Framework.Notify(string.format(Settings.Text.cup_underway, cup.name))

    local model = TROLLEY_MODELS[random(1, #TROLLEY_MODELS)]
    Framework.LoadModel(model)

    derbyTrolley = CreateObject(model, playerCoords.x, playerCoords.y, playerCoords.z, true, true, true)
    HeldTrolley = derbyTrolley
    PlaceObjectOnGroundProperly(derbyTrolley)
    SetEntityAsMissionEntity(derbyTrolley, true, true)

    Wait(1000)
    GrabTrolley(HeldTrolley)

    launchZone = Points.New({
        debug = cup.revealLaunchZone,
        coords = launchPoint,
        distance = cup.launchRadius,
        onExit = function(point)
            point.nearby = false
            if ridingTrolley then
                CreateThread(function()
                    SubmitCupScore(cup, riddenTrolley)
                end)
            end
        end,
        onEnter = function(point)
            point.nearby = true
            launchZone = point
        end,
    })
end)

RegisterNetEvent("bl_dumpsters:client:CupConcluded", function(cupId, outcome)
    if launchZone then
        launchZone.remove()
        launchZone = nil
    end

    if outcome.source == Store.ServerId then
        Framework.Notify(Settings.Text.cup_victory, "success")
    else
        Framework.Notify(string.format(Settings.Text.cup_results, outcome.name, floor(outcome.winnerDistance * 100) / 100), "info")
    end
end)

-- --------------------------------------------------------------------------
--  COMPERE MENUS
-- --------------------------------------------------------------------------

local function OpenCupHostDialog(venue)
    local input = lib.inputDialog(Settings.Text.host_cup, {
        { type = "number", label = Settings.Text.starts_in_field, default = 10, required = true },
        { type = "number", label = Settings.Text.duration_field, default = 10, min = 5, max = 60, required = true },
        { type = "number", label = Settings.Text.entry_fee_field, default = 10, min = 0, max = 1000, required = true },
    })

    if not input then
        return
    end

    local startsIn, duration, entryFee = input[1], input[2], input[3]

    Framework.TriggerCallback("bl_dumpsters:server:HostCup", function(success, errorMessage)
        if success then
            Framework.Notify(string.format(Settings.Text.cup_scheduled, startsIn))
        else
            Framework.Notify(errorMessage, "error")
        end
    end, venue.name, startsIn, duration, entryFee)
end

local function OpenCupSignupDialog(venue, entryFee)
    local body = Settings.Text.cup_signup_prompt

    if entryFee and entryFee > 0 then
        body = body .. " " .. string.format(Settings.Text.cup_entry_fee, entryFee)
    end

    local answer = lib.alertDialog({
        title = Settings.Text.cup_label,
        content = body,
        cancel = true,
        labels = { cancel = Settings.Text.decline_polite, confirm = Settings.Text.accept_polite },
    })

    if answer ~= "confirm" then
        return
    end

    Framework.TriggerCallback("bl_dumpsters:server:JoinCup", function(success, errorMessage)
        if success then
            Framework.Notify(Settings.Text.cup_entered)
        else
            Framework.Notify(string.format(Settings.Text.cup_entry_failed, errorMessage), "error")
        end
    end, venue.name, entryFee or 0)
end

local function OpenReplacementTrolleyDialog(cupInfo, venue)
    local price = cupInfo.entryFee
    if not price or price <= 0 then
        price = 25
    end

    local answer = lib.alertDialog({
        title = Settings.Text.lost_trolley_title,
        content = string.format(Settings.Text.trolley_lost, price),
        cancel = true,
        labels = { cancel = Settings.Text.decline_polite, confirm = Settings.Text.accept_polite },
    })

    if answer ~= "confirm" then
        return
    end

    Framework.TriggerCallback("bl_dumpsters:server:BuyReplacementTrolley", function(success, errorMessage)
        if not success then
            Framework.Notify(errorMessage, "error")
            return
        end

        Framework.Notify(Settings.Text.replacement_trolley)

        local model = TROLLEY_MODELS[random(1, #TROLLEY_MODELS)]
        Framework.LoadModel(model)
        derbyTrolley = CreateObject(model, venue.trolleySpot.x, venue.trolleySpot.y, venue.trolleySpot.z, true, true, true)
        PlaceObjectOnGroundProperly(derbyTrolley)
        SetEntityAsMissionEntity(derbyTrolley, true, true)

        Wait(1000)
        GrabTrolley(derbyTrolley)
    end, venue.name, price)
end

local function OpenLeaderboardDialog(venue)
    Framework.TriggerCallback("bl_dumpsters:server:GetVenueLeaderboard", function(board)
        local body = "# " .. string.format(Settings.Text.board_title, venue.name) .. "\n\n"
        body = body .. ("| %s | %s | %s |\n"):format(Settings.Text.rank_column, Settings.Text.player_column, Settings.Text.distance_column)
        body = body .. "|:--------:|:-------|:--------:|\n"

        for _, entry in ipairs(board) do
            body = body .. ("| **#%s** | %s | %.2f |\n"):format(entry.position, entry.name, entry.distance)
        end

        lib.alertDialog({
            title = string.format(Settings.Text.top_riders, venue.name),
            content = body,
        })
    end, venue.name)
end

local function OpenCompereMenu(venue)
    Framework.TriggerCallback("bl_dumpsters:server:GetCupStatus", function(cup, entryFee, status)
        local options = {}

        if status ~= "active" then
            insert(options, 1, {
                key = "E",
                label = Settings.Text.lets_roll,
                reaction = "Conversation",
                selected = function(data)
                    exports[INTERACT]:UpdateSpeech(data.menuID, Settings.Text.ride_it_far)

                    if derbyTrolley and DoesEntityExist(derbyTrolley) then
                        DeleteEntity(derbyTrolley)
                    end

                    local model = TROLLEY_MODELS[random(1, #TROLLEY_MODELS)]
                    Framework.LoadModel(model)
                    derbyTrolley = CreateObject(model, venue.trolleySpot.x, venue.trolleySpot.y, venue.trolleySpot.z, true, true, true)
                    PlaceObjectOnGroundProperly(derbyTrolley)
                    SetEntityAsMissionEntity(derbyTrolley, true, true)

                    Points.New({
                        debug = venue.revealLaunchZone,
                        coords = vector3(venue.launchPoint.x, venue.launchPoint.y, venue.launchPoint.z),
                        distance = venue.launchRadius,
                        onExit = function(point)
                            point.nearby = false
                            if ridingTrolley then
                                CreateThread(function()
                                    SubmitFreeRunScore(venue, riddenTrolley, point)
                                end)
                            end
                        end,
                        onEnter = function(point)
                            point.nearby = true
                        end,
                    })

                    exports[INTERACT]:CloseMenu(data.menuID)
                end,
            })

            insert(options, 2, {
                key = "L",
                label = Settings.Text.scoreboard,
                reaction = "Conversation",
                speech = Settings.Text.peek_at_board,
                selected = function(data)
                    exports[INTERACT]:CloseMenu(data.menuID)
                    OpenLeaderboardDialog(venue)
                end,
            })
        end

        insert(options, {
            key = "X",
            label = Settings.Text.never_mind,
            reaction = "Bye",
            speech = Settings.Text.derby_farewell,
            selected = function(data)
                exports[INTERACT]:CloseMenu(data.menuID)
            end,
        })

        if Framework.Player.Job.Name == Settings.VagrantJobName and not cup then
            insert(options, 2, {
                key = "H",
                label = Settings.Text.host_cup,
                reaction = "Conversation",
                speech = Settings.Text.glad_to_help,
                selected = function(data)
                    exports[INTERACT]:CloseMenu(data.menuID)
                    OpenCupHostDialog(venue)
                end,
            })
        end

        if cup and status == "signup" then
            insert(options, 2, {
                key = "T",
                label = Settings.Text.cup_label,
                reaction = "Yes",
                speech = Settings.Text.cup_in_progress,
                selected = function()
                    OpenCupSignupDialog(venue, entryFee)
                end,
            })
        elseif cup and status == "active" then
            insert(options, 2, {
                key = "T",
                label = Settings.Text.cup_label,
                reaction = "Yes",
                speech = Settings.Text.cup_in_progress,
                selected = function()
                    OpenReplacementTrolleyDialog(cup, venue)
                end,
            })
        end

        exports[INTERACT]:OpenChoiceMenu({
            title = Settings.Text.derby_menu_title,
            speech = Settings.Text.derby_objective,
            menuID = "bl_derby_compere_" .. venue.name:lower():gsub("%s+", "_"),
            position = "right",
            options = options,
        })
    end, venue.name)
end

CreateThread(function()
    Wait(1000)

    for index, venue in ipairs(Settings.TrolleyDerby.Venues) do
        local menuID = "bl_derby_compere_" .. venue.name:lower():gsub("%s+", "_")

        compereNPCs[index] = exports[INTERACT]:CreateNPC({
            name = menuID,
            model = "a_m_m_skidrow_01",
            coords = vector3(venue.npc.x, venue.npc.y, venue.npc.z - 1.0),
            heading = venue.npc.w,
            isFrozen = true,
        }, {
            title = Settings.Text.derby_compere,
            speech = Settings.Text.derby_hello,
            menuID = menuID,
            greeting = "Conversation",
            position = "right",
            focusCam = true,
            options = {
                {
                    key = "E",
                    label = Settings.Text.derby_menu_title,
                    reaction = "Conversation",
                    selected = function()
                        OpenCompereMenu(venue)
                    end,
                },
                {
                    key = "X",
                    label = Settings.Text.never_mind,
                    reaction = "Bye",
                    speech = Settings.Text.derby_farewell,
                    selected = function(data)
                        exports[INTERACT]:CloseMenu(data.menuID)
                    end,
                },
            },
        })
    end
end)

-- --------------------------------------------------------------------------
--  CLEANUP & STATE SAFETY
-- --------------------------------------------------------------------------

--- Frees the occupancy flag on whichever trolley the player is riding.
local function ReleaseOccupancyFlag()
    if riddenTrolley and DoesEntityExist(riddenTrolley) and NetworkGetNetworkIdFromEntity(riddenTrolley) > 0 then
        Entity(riddenTrolley).state:set("isOccupied", false, true)
    end
end

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if derbyTrolley and DoesEntityExist(derbyTrolley) then
        DeleteEntity(derbyTrolley)
    end

    if ridingTrolley then
        ReleaseOccupancyFlag()
    end

    for _, npc in ipairs(compereNPCs) do
        DeleteEntity(npc)
    end
end)

-- Someone else claimed the trolley we are pushing — let go of it.
CreateThread(function()
    AddStateBagChangeHandler("isOccupied", nil, function(bagName, _, value)
        if not value then
            return
        end

        local entityIdString = bagName:match("entity:(%d+)")
        local entityId = entityIdString and tonumber(entityIdString)
        if not entityId then
            return
        end

        local entity = NetworkGetEntityFromNetworkId(entityId)
        if not (entity and DoesEntityExist(entity)) then
            return
        end

        if HeldTrolley == entity and TrolleyHeld then
            DropTrolley()
        end
    end)
end)

AddEventHandler("playerDropped", function()
    if ridingTrolley then
        ReleaseOccupancyFlag()
    end
end)

AddEventHandler("playerSpawned", function()
    if not ridingTrolley then
        return
    end

    ridingTrolley = false
    ReleaseOccupancyFlag()
    riddenTrolley = nil
    HeldTrolley = nil
end)

-- Safety net: release the trolley if the rider dies.
CreateThread(function()
    while true do
        Wait(5000)

        if ridingTrolley and Framework.IsPlayerDead() then
            ridingTrolley = false

            if riddenTrolley and DoesEntityExist(riddenTrolley) then
                ReleaseOccupancyFlag()
                DetachEntity(cache.ped, true, false)
            end

            riddenTrolley = nil
            HeldTrolley = nil
        end
    end
end)
