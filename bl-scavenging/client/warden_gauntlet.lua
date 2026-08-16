local reservedSlot1 = nil -- unused (present in original decompiled source, never read)
local livingFoes = {}
local killCount = 0
local gauntletActive = false
local routingBucket = 0
local gauntletTimeoutAt = nil
local maxLivingFoes = 25
local spawnInterval = 5000
local gauntletStartedAt = 0
local reservedSlot2 = nil -- unused (present in original decompiled source, never read)

local function PickSpawnPoint()
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local distance = math.random(40, 60)
    local angle = math.rad((heading + 180 + math.random(-90, 90)) % 360)
    local spawnX = coords.x + math.cos(angle) * distance
    local spawnY = coords.y + math.sin(angle) * distance
    local spawnZ = coords.z
    local groundZ, foundGround = GetGroundZFor_3dCoord(spawnX, spawnY, spawnZ + 10.0, 0)
    if foundGround then
        spawnZ = groundZ
    end
    return vector4(spawnX, spawnY, spawnZ, (angle * 180 / math.pi) % 360)
end

function LaunchWardenGauntlet()
    LaunchGauntlet()
end

function LaunchGauntlet()
    if gauntletActive then
        return
    end

    TriggerServerEvent("bl_scav:server:RequestRoutingBucket")
    gauntletActive = true
    killCount = 0
    livingFoes = {}
    gauntletStartedAt = GetGameTimer()

    local coords = GetEntityCoords(cache.ped)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 310)
    SetBlipColour(blip, 1)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Lang.hobo_king_challenge)
    EndTextCommandSetBlipName(blip)

    gauntletTimeoutAt = SetTimeout(600000, function()
        ConcludeGauntlet("time")
    end)

    CreateThread(function()
        RunFoeSpawnCycle()
    end)

    CreateThread(function()
        MonitorGauntletState()
    end)

    Framework.Notify(Config.Lang.challenge_begin, "info")
end

function RunFoeSpawnCycle()
    while gauntletActive do
        if #livingFoes < maxLivingFoes then
            SpawnGauntletFoe()
        end
        Wait(spawnInterval)
    end
end

function SpawnGauntletFoe()
    local model = Config.HostileVagrantModels[math.random(1, #Config.HostileVagrantModels)]
    local modelHash = GetHashKey(model)
    RequestModel(modelHash)

    local timeoutAt = GetGameTimer() + 5000
    while true do
        if HasModelLoaded(modelHash) then
            break
        end
        if timeoutAt < GetGameTimer() then
            return
        end
        Wait(50)
    end

    local spawnPoint = PickSpawnPoint()
    local ped = CreatePed(4, modelHash, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 5, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedArmour(ped, math.random(0, 50))
    SetPedMaxHealth(ped, 150)
    SetEntityHealth(ped, 150)

    local weapons = {
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
    local weaponHash = GetHashKey(weapons[math.random(1, #weapons)])
    GiveWeaponToPed(ped, weaponHash, 1, false, true)

    TaskCombatPed(ped, cache.ped, 0, 16)

    table.insert(livingFoes, ped)

    CreateThread(function()
        while true do
            if not DoesEntityExist(ped) then
                break
            end
            if IsEntityDead(ped) then
                break
            end
            if not gauntletActive then
                break
            end
            Wait(500)
        end

        if IsEntityDead(ped) then
            if gauntletActive then
                killCount = killCount + 1
                DropFoeReference(ped)
                SetPedAsNoLongerNeeded(ped)
                Framework.Notify(string.format(Config.Lang.kills_count, killCount), "success")
            end
        else
            if DoesEntityExist(ped) then
                SetPedAsNoLongerNeeded(ped)
            end
        end
    end)
end

function DropFoeReference(ped)
    for index, existingPed in ipairs(livingFoes) do
        if existingPed == ped then
            table.remove(livingFoes, index)
            break
        end
    end
end

function MonitorGauntletState()
    local ped = cache.ped
    while gauntletActive do
        Wait(500)
        if IsEntityDead(ped) then
            ConcludeGauntlet("death")
            break
        end
    end
end

function ConcludeGauntlet(reason)
    if not gauntletActive then
        return
    end

    gauntletActive = false
    local survived = math.floor((GetGameTimer() - gauntletStartedAt) / 1000)

    if gauntletTimeoutAt then
        gauntletTimeoutAt = nil
    end

    for _, ped in ipairs(livingFoes) do
        if DoesEntityExist(ped) then
            SetPedAsNoLongerNeeded(ped)
            DeleteEntity(ped)
        end
    end
    livingFoes = {}

    TriggerServerEvent("bl_scav:server:ReturnToNormalBucket")
    TriggerServerEvent("bl_scav:server:RecordKingChallengeAttempt", killCount, survived)

    local message = nil
    if reason == "time" then
        message = string.format(Config.Lang.challenge_complete, killCount)
        Framework.Notify(message, "success")
    else
        message = string.format(Config.Lang.challenge_failed, math.floor(survived / 60), survived % 60, killCount)
        Framework.Notify(message, "error")
    end

    Wait(1000)
    ShowWardenRankings()
end

function ShowWardenRankings()
    Framework.TriggerCallback("bl_scav:server:GetHoboKingLeaderboard", function(leaderboard)
        if not (leaderboard and #leaderboard ~= 0) then
            Framework.Notify(Config.Lang.no_completions, "info")
            return
        end

        local header = Config.Lang.king_leaderboard_header .. [[

]]
        for rank, entry in ipairs(leaderboard) do
            local minutes = math.floor(entry.time_survived / 60)
            local seconds = entry.time_survived % 60
            header = header .. rank .. ". " .. entry.player_name .. " - " .. entry.kill_count .. " kills (" .. minutes .. "m " .. seconds .. "s)\n"
            if rank >= 10 then
                break
            end
        end

        lib.alertDialog({
            header = Config.Lang.king_leaderboard_title,
            content = header,
            size = "lg",
        })
    end)
end

RegisterNetEvent("bl_scav:client:SetRoutingBucket")
AddEventHandler("bl_scav:client:SetRoutingBucket", function(bucketId)
    routingBucket = bucketId
end)

RegisterNetEvent("bl_scav:client:StartKingFight")
AddEventHandler("bl_scav:client:StartKingFight", function()
    LaunchWardenGauntlet()
end)

RegisterNetEvent("bl_scav:client:NewKing")
AddEventHandler("bl_scav:client:NewKing", function(newKingName)
    Framework.Notify(string.format(Config.Lang.new_king, newKingName), "info")
end)

if Config.DiagnosticsEnabled then
    RegisterCommand("testking", function()
        LaunchWardenGauntlet()
    end, false)
end
