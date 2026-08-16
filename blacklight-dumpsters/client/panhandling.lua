--[[ ==========================================================================
     BlackLight Dumpsters — Panhandling & Windscreen Washing (client)
========================================================================== ]]

local random = math.random
local insert, remove = table.insert, table.remove

local queuedPedestrians = {}
local panhandleCoolingDown = false
local panhandleRunning = false
local snubbedPedestrians = {}
local placardProp = nil
local vehiclesBeingWashed = {}

local PLACARD_MODELS = { -245386275, -533655168, -1109340972, -801803927 }
local SPONGE_MODEL = -678752633
local SESSION_LENGTH_MS = 30000

local INSULT_LINES = { "GENERIC_INSULT_HIGH", "GENERIC_INSULT_MED", "GENERIC_SHOCKED_HIGH" }
local REFUSAL_LINES = { "GENERIC_NO", "GENERIC_INSULT_HIGH", "GENERIC_INSULT_MED", "GENERIC_SHOCKED_HIGH" }

local function DiscardPlacard()
    if placardProp and DoesEntityExist(placardProp) then
        DeleteObject(placardProp)
    end
    placardProp = nil
end

--- Waits for a pedestrian to walk over to the player.
---@return boolean arrived
local function AwaitPedestrian(ped)
    local arrived = false
    local ticks = 0

    insert(queuedPedestrians, ped)
    TaskGoToEntity(ped, cache.ped, -1, 1.0, 0.5, 0, 0)

    CreateThread(function()
        while true do
            if not DoesEntityExist(ped) then
                break
            end
            if #(GetEntityCoords(ped) - GetEntityCoords(cache.ped)) < 1.0 then
                arrived = true
                break
            end
            Wait(1000)
        end
    end)

    while not arrived do
        Wait(1000)
        ticks = ticks + 1
        if ticks > 20 then
            break
        end
    end

    for index, queued in ipairs(queuedPedestrians) do
        if queued == ped then
            remove(queuedPedestrians, index)
            break
        end
    end

    return arrived
end

--- Finds the closest eligible pedestrian within `radius`.
local function ClosestPedestrian(coords, radius)
    local peds = Framework.GetPeds()
    local closest, closestCoords = nil, nil
    radius = radius or 2.0

    for i = 1, #peds do
        local ped = peds[i]

        if not IsPedAPlayer(ped) and not IsEntityPositionFrozen(ped) and not snubbedPedestrians[ped] then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(coords - pedCoords)

            if distance < radius then
                radius = distance
                closest = ped
                closestCoords = pedCoords
            end
        end
    end

    return closest, closestCoords
end

--- A pedestrian decides to shove the player over instead of paying up.
local function PedestrianShoves(ped)
    PlayPedAmbientSpeechNative(ped, INSULT_LINES[random(#INSULT_LINES)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")

    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskGoToEntity(ped, cache.ped, -1, 0.7, 0.5, 0, 0)
    Wait(2000)

    local clipDict = "melee@unarmed@streamed_variations"
    local clipName = "plyr_takedown_front_slap"
    TaskTurnPedToFaceEntity(ped, cache.ped, 2000)
    Wait(2000)

    Framework.LoadAnimDict(clipDict)
    TaskPlayAnim(ped, clipDict, clipName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(650)

    local forward = GetEntityForwardVector(ped)
    SetPedToRagdoll(cache.ped, 1000, 5000, 0, true, true, false)
    ApplyForceToEntity(cache.ped, 1, forward.x * 3.0, forward.y * 3.0, forward.z * 0.5, 0, 0, 0.1, 0, false, true, true, false, true)
    SetPedToRagdoll(cache.ped, 3000, 7000, 0, true, true, false)
    Wait(1000)

    PlayPedAmbientSpeechNative(ped, INSULT_LINES[random(#INSULT_LINES)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
    SetPedAsNoLongerNeeded(ped)
    TaskSmartFleePed(ped, cache.ped, 1000, -1, true, true)
end

--- A pedestrian hands over some change.
local function PedestrianPays(ped, holdingPlacard)
    TaskTurnPedToFaceEntity(ped, cache.ped, -1)
    PlayPedAmbientSpeechNative(ped, "GENERIC_HOWS_IT_GOING", "SPEECH_PARAMS_DEFAULT")
    Wait(random(0, 1000))

    local clipDict = "mp_common"
    local clipName = "givetake1_a"
    Framework.LoadAnimDict(clipDict)

    ClearPedTasks(cache.ped)
    TaskTurnPedToFaceEntity(cache.ped, ped, 2000)
    Wait(2000)

    TaskPlayAnim(ped, clipDict, clipName, 8.0, 8.0, -1, 49, 0, false, false, false)
    Wait(GetAnimDuration(clipDict, clipName) * 1000)

    ClearPedTasks(ped)
    SetPedAsNoLongerNeeded(ped)

    local payout = Framework.TriggerCallback.Await("bl_dumpsters:server:ClaimStreetEarnings", holdingPlacard)
    Framework.Notify(string.format(Settings.Text.panhandle_payout, payout), "success")

    panhandleCoolingDown = true
    SetTimeout(Settings.Panhandling.CooldownSeconds * 1000, function()
        panhandleCoolingDown = false
    end)

    ClearPedTasks(cache.ped)

    if Settings.HostileVagrantsEnabled then
        ProvokeLocalVagrants()
    end
end

--- Main panhandling loop — approaches pedestrians until the session ends.
local function PanhandleSession(holdingPlacard)
    Wait(random(1000, 5000))

    while panhandleRunning do
        local target = ClosestPedestrian(GetEntityCoords(cache.ped), 30.0)

        if target and not snubbedPedestrians[target] then
            if random(1, 100) >= Settings.Panhandling.BrushOffChance then
                local distance = #(GetEntityCoords(target) - GetEntityCoords(cache.ped))

                if distance < 5.0 then
                    snubbedPedestrians[target] = true
                    TaskTurnPedToFaceEntity(target, cache.ped, -1)
                    Wait(random(500, 3000))

                    if random(1, 100) <= Settings.Panhandling.HostileChance then
                        if random(1, 2) == 1 then
                            PedestrianShoves(target)
                        else
                            TaskCombatPed(target, cache.ped, 0, 16)
                            Wait(random(500, 1500))
                            ClearPedTasks(cache.ped)
                        end

                        panhandleRunning = false
                        DiscardPlacard()
                        break
                    end

                    if AwaitPedestrian(target) then
                        PedestrianPays(target, holdingPlacard)
                        panhandleRunning = false
                        DiscardPlacard()
                        break
                    end
                end
            else
                PlayPedAmbientSpeechNative(target, REFUSAL_LINES[random(#REFUSAL_LINES)], "SPEECH_PARAMS_FORCE_NORMAL_CLEAR")
                snubbedPedestrians[target] = true
            end
        end

        Wait(5000)
    end
end

-- --------------------------------------------------------------------------
--  COMMANDS
-- --------------------------------------------------------------------------

RegisterCommand("bl_stop_panhandling", function()
    panhandleRunning = false

    if IsEntityPlayingAnim(cache.ped, "missheist_agency3aig_24", "agent02_conversation", 3) then
        StopAnimTask(cache.ped, "missheist_agency3aig_24", "agent02_conversation", 3)
    end

    DiscardPlacard()
    ClearPedTasks(cache.ped)
end, false)

RegisterKeyMapping("bl_stop_panhandling", Settings.Text.panhandle_stop_key, "keyboard", "x")

RegisterCommand(Settings.Panhandling.Command, function()
    if panhandleCoolingDown then
        Framework.Notify(Settings.Text.panhandle_cooldown, "error")
        return
    end

    if panhandleRunning then
        Framework.Notify(Settings.Text.panhandle_busy, "error")
        return
    end

    local playerPed = cache.ped
    local holdingPlacard = Framework.HasItem("begging_sign", 1)

    if holdingPlacard then
        local clipDict = "amb@world_human_bum_freeway@male@idle_a"
        local clipName = "idle_a"
        Framework.LoadAnimDict(clipDict)
        TaskPlayAnim(playerPed, clipDict, clipName, 8.0, 8.0, -1, 49, 0, false, false, false)

        local modelHash = PLACARD_MODELS[random(#PLACARD_MODELS)]
        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(100)
        end

        placardProp = CreateObject(modelHash, 0, 0, 0, true, true, true)
        AttachEntityToEntity(placardProp, playerPed, GetPedBoneIndex(playerPed, 18905),
            0.06397625058889, -0.077691398561, 0.2065776884558,
            -85.892402648928, 88.618576498046, -11.269510269165,
            true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(modelHash)
    else
        local clipDict = "missheist_agency3aig_24"
        local clipName = "agent02_conversation"
        Framework.LoadAnimDict(clipDict)
        TaskPlayAnim(playerPed, clipDict, clipName, 8.0, 8.0, -1, 1, 0, false, false, false)
    end

    CreateThread(function()
        panhandleRunning = true
        PanhandleSession(holdingPlacard)
        DiscardPlacard()
    end)

    if Settings.Panhandling.ShowProgressBar then
        local completed = lib.progressBar({
            duration = SESSION_LENGTH_MS,
            label = Settings.Text.panhandle_progress,
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true },
        })

        if not completed then
            Framework.Notify(Settings.Text.panhandle_stopped, "error")
        end

        panhandleRunning = false
        DiscardPlacard()
        return
    end

    SetTimeout(SESSION_LENGTH_MS, function()
        if panhandleRunning then
            panhandleRunning = false
            ClearPedTasks(playerPed)
            DiscardPlacard()
        end
    end)
end, false)

-- --------------------------------------------------------------------------
--  WINDSCREEN WASHING
-- --------------------------------------------------------------------------

--- Sponges down a vehicle's windscreen for a small tip.
function WashWindscreen(vehicle)
    if not IsEntityAVehicle(vehicle) then
        return
    end

    if vehiclesBeingWashed[vehicle] then
        Framework.Notify(Settings.Text.vehicle_already_clean, "error")
        return
    end

    vehiclesBeingWashed[vehicle] = true

    local playerPed = cache.ped

    RequestModel(SPONGE_MODEL)
    while not HasModelLoaded(SPONGE_MODEL) do
        Wait(10)
    end

    local sponge = CreateObject(SPONGE_MODEL, 0, 0, 0, true, true, false)
    AttachEntityToEntity(sponge, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, -0.01, 90.0, 0.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(SPONGE_MODEL)

    local clipDict = "timetable@floyd@clean_kitchen@base"
    local clipName = "base"
    Framework.LoadAnimDict(clipDict)
    TaskPlayAnim(playerPed, clipDict, clipName, 3.0, 3.0, -1, 1, 0, false, false, false)

    local driver = GetPedInVehicleSeat(vehicle, -1)
    local driverHostile = random(1, 100) <= Settings.Panhandling.HostileWashChance

    if driver ~= 0 and driverHostile then
        TaskCombatPed(driver, playerPed, 0, 16)
        Wait(random(1000, 3000))

        ClearPedTasks(playerPed)
        DeleteEntity(sponge)
        vehiclesBeingWashed[vehicle] = nil
        return
    end

    local washing = true

    CreateThread(function()
        while washing do
            if IsControlJustPressed(0, 73) then
                washing = false
                break
            end
            Wait(0)
        end
    end)

    local startedAt = GetGameTimer()
    local requiredMs = random(Settings.Panhandling.MinWashSeconds * 1000, Settings.Panhandling.MaxWashSeconds * 1000)
    local clipHeld = true

    while washing do
        if GetGameTimer() - startedAt >= requiredMs then
            break
        end

        Wait(100)

        if not IsEntityPlayingAnim(playerPed, clipDict, clipName, 3) then
            clipHeld = false
            break
        end
    end

    DeleteEntity(sponge)
    ClearPedTasks(playerPed)
    vehiclesBeingWashed[vehicle] = nil

    if not washing or not clipHeld then
        return
    end

    if #(GetEntityCoords(playerPed) - GetEntityCoords(vehicle)) > 4.0 then
        return
    end

    if GetVehicleDirtLevel(vehicle) > 0.0 then
        SetVehicleDirtLevel(vehicle, 0.0)
    end

    if driver ~= 0 and not IsPedAPlayer(driver) then
        local tipDict = "oddjobs@taxi@cyi"
        local tipClip = "std_hand_off_ps_passenger"
        Framework.LoadAnimDict(tipDict)
        TaskPlayAnim(driver, tipDict, tipClip, 3.0, 3.0, -1, 1, 0, false, false, false)
        Wait(1000)
        StopAnimTask(driver, tipDict, tipClip, 3.0)

        local payout = Framework.TriggerCallback.Await("bl_dumpsters:server:ClaimStreetEarnings", false)
        Framework.Notify(string.format(Settings.Text.wash_payout, payout), "success")
    end
end

if Settings.Panhandling.WashingEnabled then
    if Settings.UseTargetSystem then
        Target.AddGlobalVehicle({
            {
                distance = 1.5,
                name = "bl_wash_windscreen",
                label = Settings.Text.wash_option,
                icon = "fa-solid fa-soap",
                onSelect = function(data)
                    WashWindscreen(data.entity)
                end,
                canInteract = function()
                    return Framework.Player.Job.Name == Settings.VagrantJobName
                end,
            },
        })
    else
        exports["blacklight-interact"]:InteractionGlobalVehicle({
            name = "bl_wash_windscreen",
            distance = 3.0,
            radius = 5.0,
            bones = "bonnet",
            options = {
                {
                    label = Settings.Text.wash_option,
                    selected = function(data)
                        WashWindscreen(data.entity)
                    end,
                    canSee = function()
                        return Framework.Player.Job.Name == Settings.VagrantJobName
                    end,
                },
            },
        })
    end
end
