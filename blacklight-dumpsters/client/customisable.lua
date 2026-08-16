--[[ ==========================================================================
     BlackLight Dumpsters — Customisable Hooks
     --------------------------------------------------------------------------
     This file is deliberately left outside of escrow. Wire your own dispatch,
     status effects and third-party integrations in here.
========================================================================== ]]

local random = math.random
local max = math.max

--- Broadcast a theft report to your dispatch resource of choice.
--- Called whenever a player loots inside a watched district or lifts an illicit prop.
---@param coords vector3
function RelayTheftReport(coords)
    -- ps-dispatch integration (external contract — do not rename these keys)
    if GetResourceState("ps-dispatch") == "started" then
        exports["ps-dispatch"]:CustomAlert({
            coords = vector3(coords.x, coords.y, coords.z),
            message = "Trash Theft",
            dispatchCode = "10-4 Rubber Ducky",
            description = "Trash Theft",
            radius = 0,
            sprite = 480,
            color = 1,
            scale = 1.0,
            length = 3,
        })
    end

    -- Add your own dispatch integration below (cd_dispatch, qs-dispatch, core_dispatch, ...)
end

--- Fired when a player is pricked by a discarded syringe while rummaging.
function ApplySharpsAffliction()
    if Framework.HasItem("hobo_gloves", 1) then
        Framework.Notify(Settings.Text['gloves_saved_you'], "success", 5000)
        return
    end

    ScavengerImpaired = true

    local healthCost = Settings.Mishaps.SharpsHealthCost
    if not healthCost then
        LogDiagnostic("Error: SharpsHealthCost is not defined in Settings")
        return
    end

    local clip = Settings.SharpsReactionClip
    Framework.LoadAnimDict(clip.dict)
    TaskPlayAnim(cache.ped, clip.dict, clip.anim, 8.0, 8.0, -1, 49, 0, false, false, false)

    local clipMs = GetAnimDuration(clip.dict, clip.anim) * 1000
    if clipMs < 2000 then
        clipMs = random(2700, 4000)
    end

    Wait(clipMs - 500)
    ClearPedTasks(cache.ped)

    local currentHealth = GetEntityHealth(cache.ped)
    SetEntityHealth(cache.ped, max(currentHealth - healthCost, 1))

    AnimpostfxPlay("DrugsMichaelAliensFight", 0, true)
    ApplyPedBlood(cache.ped, 0, 0.0, 0.0, 0.0, "wound_sheet")

    RequestAnimSet("MOVE_M@DRUNK@MODERATEDRUNK")
    while not HasAnimSetLoaded("MOVE_M@DRUNK@MODERATEDRUNK") do
        Wait(0)
    end

    SetPedMovementClipset(cache.ped, "MOVE_M@DRUNK@MODERATEDRUNK", 0.0)
    Framework.Notify(Settings.Text["sharps_hit"], "error", 5000)

    Wait(Settings.Mishaps.SharpsEffectSeconds * 1000)

    ScavengerImpaired = false
    AnimpostfxStop("DrugsMichaelAliensFight")
    ResetPedMovementClipset(cache.ped, 0)
end

--- Fired when a rodent or masked bandit ambushes the player mid-search.
function ApplyVerminAmbush()
    local isBandit = random(1, 100) <= (Settings.Mishaps.BanditChance or 65)

    if not isBandit and Framework.HasItem("rat_treats", 1) then
        TriggerServerEvent('bl_dumpsters:server:ConsumeRodentTreats')
        Framework.Notify(Settings.Text['treats_saved_you'], "success", 5000)
        return
    end

    local clip = Settings.VerminReactionClip

    if not isBandit then
        local healthCost = Settings.Mishaps.VerminHealthCost
        if not healthCost then
            LogDiagnostic("Error: VerminHealthCost is not defined in Settings")
            return
        end

        SetEntityHealth(cache.ped, GetEntityHealth(cache.ped) - healthCost)

        Framework.LoadAnimDict(clip.dict)
        TaskPlayAnim(cache.ped, clip.dict, clip.anim, 8.0, 8.0, -1, 49, 0, false, false, false)

        Framework.LoadModel(`a_c_rat`)
        local coords = GetEntityCoords(cache.ped)
        local rodent = CreatePed(4, `a_c_rat`, coords.x, coords.y, coords.z, 0.0, true, false)
        TaskSmartFleePed(rodent, cache.ped, 50.0, -1, false, false)

        local clipMs = GetAnimDuration(clip.dict, clip.anim) * 1000
        if clipMs < 2000 then
            clipMs = random(2700, 4000)
        end

        Wait(clipMs - 500)
        ClearPedTasks(cache.ped)
        Framework.Notify(Settings.Text['vermin_bite'], "error", 5000)
        return
    end

    local healthCost = Settings.Mishaps.BanditHealthCost or 50
    SetEntityHealth(cache.ped, GetEntityHealth(cache.ped) - healthCost)

    Framework.LoadAnimDict(clip.dict)
    TaskPlayAnim(cache.ped, clip.dict, clip.anim, 8.0, 8.0, -1, 49, 0, false, false, false)
    Framework.Notify(Settings.Text['bandit_mauling'], "error", 5000)

    Framework.LoadModel(`enviraccoon`)
    local coords = GetEntityCoords(cache.ped)
    local forward = GetEntityForwardVector(cache.ped)
    local bandit = CreatePed(4, `enviraccoon`, coords.x + forward.x * 0.02, coords.y + forward.y * 0.02, coords.z + 0.4, 0.0, true, false)
    SetEntityAsMissionEntity(bandit, true, true)

    PlayBanditStartle(bandit)
    TaskSmartFleePed(bandit, cache.ped, 100.0, -1, false, false)

    local clipMs = GetAnimDuration(clip.dict, clip.anim) * 1000
    if clipMs < 2000 then
        clipMs = random(2700, 4000)
    end

    Wait(clipMs - 1000)
    ClearPedTasks(cache.ped)

    SetTimeout(30000, function()
        TaskWanderStandard(bandit, 10.0, 10)
        Wait(60000)
        SetPedAsNoLongerNeeded(bandit)
    end)
end

if Settings.DiagnosticMode then
    RegisterCommand('bl_spawnbandit', function()
        local coords = GetEntityCoords(cache.ped)
        local forward = GetEntityForwardVector(cache.ped)
        Framework.LoadModel(`enviraccoon`)
        local bandit = CreatePed(4, `enviraccoon`, coords.x + forward.x * 0.02, coords.y + forward.y * 0.02, coords.z + 0.4, 0.0, true, false)
        SetEntityAsMissionEntity(bandit, true, true)
        TaskWanderStandard(bandit, 10.0, 10)
    end, false)
end

--- An informant has phoned in a scavenger. Ping the relevant on-duty jobs.
RegisterNetEvent('bl_dumpsters:client:InformantAlert', function(coords, alertJobs)
    if type(alertJobs) ~= "table" then
        return
    end

    for _, jobName in ipairs(alertJobs) do
        if Framework.Player.Job.Name == jobName then
            Framework.Notify(Settings.Text['informant_alert'], "error", 8000)
            PlaySoundFromEntity(-1, "SELECT", cache.ped, "HUD_LIQUOR_STORE_SOUNDSET", 0, 0)

            local marker = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(marker, 408)
            SetBlipColour(marker, 1)
            SetBlipScale(marker, 0.8)
            SetBlipAsShortRange(marker, false)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Settings.Text['informant_blip'])
            EndTextCommandSetBlipName(marker)

            Wait(90000)
            RemoveBlip(marker)
        end
    end
end)

--- Sipping from the flask while NOT living the street life.
RegisterNetEvent('bl_dumpsters:client:FlaskSickness', function()
    SetEntityHealth(cache.ped, GetEntityHealth(cache.ped) - 10)
end)

--- Sipping from the flask as a committed street dweller.
RegisterNetEvent('bl_dumpsters:client:FlaskVigour', function()
    SetEntityHealth(cache.ped, GetEntityHealth(cache.ped) + 10)
end)
