--[[ ==========================================================================
     BlackLight Dumpsters — The Final Gauntlet (client)
     A wave-survival instance fought inside a private routing bucket.
========================================================================== ]]

local random, floor, rad, sin, cos, pi = math.random, math.floor, math.rad, math.sin, math.cos, math.pi
local insert, remove = table.insert, table.remove

local waveAttackers = {}
local takedowns = 0
local gauntletLive = false
local assignedBucket = 0
local gauntletDeadline = nil
local ATTACKER_CAP = 25
local WAVE_INTERVAL_MS = 5000
local GAUNTLET_LENGTH_MS = 600000
local startedAt = 0

local ATTACKER_ARMS = {
    "WEAPON_BAT",
    "WEAPON_BOTTLE",
    "WEAPON_CROWBAR",
    "WEAPON_GOLFCLUB",
    "WEAPON_HAMMER",
    "WEAPON_HOBOSTICK",
    "WEAPON_KNIFE",
    "WEAPON_KNUCKLE",
    "WEAPON_MACHETE",
    "WEAPON_SWITCHBLADE",
    "WEAPON_WRENCH",
}

--- Picks a spawn point behind the player, 40-60m out, snapped to the ground.
local function PickSpawnPoint()
    local coords = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)
    local distance = random(40, 60)
    local angle = rad((heading + 180 + random(-90, 90)) % 360)

    local spawnX = coords.x + cos(angle) * distance
    local spawnY = coords.y + sin(angle) * distance
    local spawnZ = coords.z

    local groundZ, foundGround = GetGroundZFor_3dCoord(spawnX, spawnY, spawnZ + 10.0, 0)
    if foundGround then
        spawnZ = groundZ
    end

    return vector4(spawnX, spawnY, spawnZ, (angle * 180 / pi) % 360)
end

local function ForgetAttacker(ped)
    for index, existing in ipairs(waveAttackers) do
        if existing == ped then
            remove(waveAttackers, index)
            break
        end
    end
end

local function SpawnAttacker()
    local modelHash = GetHashKey(Settings.VagrantModels[random(1, #Settings.VagrantModels)])
    RequestModel(modelHash)

    local timeoutAt = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) do
        if GetGameTimer() > timeoutAt then
            return
        end
        Wait(50)
    end

    local spawnPoint = PickSpawnPoint()
    local attacker = CreatePed(4, modelHash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, true)

    SetEntityAsMissionEntity(attacker, true, true)
    SetPedCombatAttributes(attacker, 46, true)
    SetPedCombatAttributes(attacker, 5, true)
    SetPedFleeAttributes(attacker, 0, false)
    SetPedArmour(attacker, random(0, 50))
    SetPedMaxHealth(attacker, 150)
    SetEntityHealth(attacker, 150)

    GiveWeaponToPed(attacker, GetHashKey(ATTACKER_ARMS[random(1, #ATTACKER_ARMS)]), 1, false, true)
    TaskCombatPed(attacker, cache.ped, 0, 16)

    insert(waveAttackers, attacker)

    CreateThread(function()
        while DoesEntityExist(attacker) and not IsEntityDead(attacker) and gauntletLive do
            Wait(500)
        end

        if IsEntityDead(attacker) and gauntletLive then
            takedowns = takedowns + 1
            ForgetAttacker(attacker)
            SetPedAsNoLongerNeeded(attacker)
            Framework.Notify(string.format(Settings.Text.takedown_tally, takedowns), "success")
        elseif DoesEntityExist(attacker) then
            SetPedAsNoLongerNeeded(attacker)
        end
    end)
end

local function RunWaveSpawner()
    while gauntletLive do
        if #waveAttackers < ATTACKER_CAP then
            SpawnAttacker()
        end
        Wait(WAVE_INTERVAL_MS)
    end
end

local function WatchForDefeat()
    while gauntletLive do
        Wait(500)
        if IsEntityDead(cache.ped) then
            ConcludeGauntlet("defeat")
            break
        end
    end
end

--- Opens the all-time gauntlet leaderboard dialog.
function ShowGauntletBoard()
    Framework.TriggerCallback("bl_dumpsters:server:GetGauntletBoard", function(board)
        if not (board and #board > 0) then
            Framework.Notify(Settings.Text.board_empty, "info")
            return
        end

        local body = Settings.Text.gauntlet_board_header .. "\n\n"

        for rank, entry in ipairs(board) do
            local minutes = floor(entry.time_survived / 60)
            local seconds = entry.time_survived % 60
            body = body .. ("%s. %s - %s takedowns (%sm %ss)\n"):format(rank, entry.player_name, entry.kill_count, minutes, seconds)

            if rank >= 10 then
                break
            end
        end

        lib.alertDialog({
            header = Settings.Text.gauntlet_board_title,
            content = body,
            size = "lg",
        })
    end)
end

--- Wraps up the gauntlet, cleans the instance and reports the result.
function ConcludeGauntlet(reason)
    if not gauntletLive then
        return
    end

    gauntletLive = false
    local secondsSurvived = floor((GetGameTimer() - startedAt) / 1000)
    gauntletDeadline = nil

    for _, attacker in ipairs(waveAttackers) do
        if DoesEntityExist(attacker) then
            SetPedAsNoLongerNeeded(attacker)
            DeleteEntity(attacker)
        end
    end
    waveAttackers = {}

    TriggerServerEvent("bl_dumpsters:server:RestoreDefaultBucket")
    TriggerServerEvent("bl_dumpsters:server:LogGauntletRun", takedowns, secondsSurvived)

    if reason == "time" then
        Framework.Notify(string.format(Settings.Text.gauntlet_survived, takedowns), "success")
    else
        Framework.Notify(string.format(Settings.Text.gauntlet_lost, floor(secondsSurvived / 60), secondsSurvived % 60, takedowns), "error")
    end

    Wait(1000)
    ShowGauntletBoard()
end

--- Entry point — puts the player into a private bucket and starts the waves.
function BeginThroneGauntlet()
    if gauntletLive then
        return
    end

    TriggerServerEvent("bl_dumpsters:server:RequestPrivateBucket")

    gauntletLive = true
    takedowns = 0
    waveAttackers = {}
    startedAt = GetGameTimer()

    local coords = GetEntityCoords(cache.ped)
    local marker = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(marker, 310)
    SetBlipColour(marker, 1)
    SetBlipAsShortRange(marker, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Settings.Text.gauntlet_title)
    EndTextCommandSetBlipName(marker)

    gauntletDeadline = SetTimeout(GAUNTLET_LENGTH_MS, function()
        ConcludeGauntlet("time")
    end)

    CreateThread(RunWaveSpawner)
    CreateThread(WatchForDefeat)

    Framework.Notify(Settings.Text.gauntlet_start, "info")
end

RegisterNetEvent("bl_dumpsters:client:AssignBucket", function(bucketId)
    assignedBucket = bucketId
end)

RegisterNetEvent("bl_dumpsters:client:LaunchGauntlet", function()
    BeginThroneGauntlet()
end)

RegisterNetEvent("bl_dumpsters:client:ThroneAnnouncement", function(newHolderName)
    Framework.Notify(string.format(Settings.Text.throne_claimed, newHolderName), "info")
end)

if Settings.DiagnosticMode then
    RegisterCommand("bl_test_gauntlet", function()
        BeginThroneGauntlet()
    end, false)
end
