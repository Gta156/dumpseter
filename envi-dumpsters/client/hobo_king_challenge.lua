local reservedSlot1 = nil -- unused (present in original decompiled source, never read)
local spawnedPeds = {}
local killCount = 0
local challengeActive = false
local routingBucket = 0
local challengeTimeout = nil
local maxActivePeds = 25
local spawnInterval = 5000
local challengeStartTime = 0
local reservedSlot2 = nil -- unused (present in original decompiled source, never read)

local function GetRandomSpawnPoint()
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

function StartHoboKingEndlessChallenge()
    StartEndlessChallenge()
end

function StartEndlessChallenge()
    if challengeActive then
        return
    end

    TriggerServerEvent("envi-dumpsters:server:RequestRoutingBucket")
    challengeActive = true
    killCount = 0
    spawnedPeds = {}
    challengeStartTime = GetGameTimer()

    local coords = GetEntityCoords(cache.ped)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 310)
    SetBlipColour(blip, 1)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Lang.hobo_king_challenge)
    EndTextCommandSetBlipName(blip)

    challengeTimeout = SetTimeout(600000, function()
        EndChallenge("time")
    end)

    CreateThread(function()
        SpawnPedLoop()
    end)

    CreateThread(function()
        TrackChallengeStatus()
    end)

    Framework.Notify(Config.Lang.challenge_begin, "info")
end

function SpawnPedLoop()
    while challengeActive do
        if #spawnedPeds < maxActivePeds then
            SpawnEnemyPed()
        end
        Wait(spawnInterval)
    end
end

function SpawnEnemyPed()
    local model = Config.AggressivePeds[math.random(1, #Config.AggressivePeds)]
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

    local spawnPoint = GetRandomSpawnPoint()
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

    table.insert(spawnedPeds, ped)

    CreateThread(function()
        while true do
            if not DoesEntityExist(ped) then
                break
            end
            if IsEntityDead(ped) then
                break
            end
            if not challengeActive then
                break
            end
            Wait(500)
        end

        if IsEntityDead(ped) then
            if challengeActive then
                killCount = killCount + 1
                RemovePedFromTable(ped)
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

function RemovePedFromTable(ped)
    for index, existingPed in ipairs(spawnedPeds) do
        if existingPed == ped then
            table.remove(spawnedPeds, index)
            break
        end
    end
end

function TrackChallengeStatus()
    local ped = cache.ped
    while challengeActive do
        Wait(500)
        if IsEntityDead(ped) then
            EndChallenge("death")
            break
        end
    end
end

function EndChallenge(reason)
    if not challengeActive then
        return
    end

    challengeActive = false
    local survived = math.floor((GetGameTimer() - challengeStartTime) / 1000)

    if challengeTimeout then
        challengeTimeout = nil
    end

    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            SetPedAsNoLongerNeeded(ped)
            DeleteEntity(ped)
        end
    end
    spawnedPeds = {}

    TriggerServerEvent("envi-dumpsters:server:ReturnToNormalBucket")
    TriggerServerEvent("envi-dumpsters:server:RecordKingChallengeAttempt", killCount, survived)

    local message = nil
    if reason == "time" then
        message = string.format(Config.Lang.challenge_complete, killCount)
        Framework.Notify(message, "success")
    else
        message = string.format(Config.Lang.challenge_failed, math.floor(survived / 60), survived % 60, killCount)
        Framework.Notify(message, "error")
    end

    Wait(1000)
    ShowKingLeaderboard()
end

function ShowKingLeaderboard()
    Framework.TriggerCallback("envi-dumpsters:server:GetHoboKingLeaderboard", function(leaderboard)
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

RegisterNetEvent("envi-dumpsters:client:SetRoutingBucket")
AddEventHandler("envi-dumpsters:client:SetRoutingBucket", function(bucketId)
    routingBucket = bucketId
end)

RegisterNetEvent("envi-dumpsters:client:StartKingFight")
AddEventHandler("envi-dumpsters:client:StartKingFight", function()
    StartHoboKingEndlessChallenge()
end)

RegisterNetEvent("envi-dumpsters:client:NewKing")
AddEventHandler("envi-dumpsters:client:NewKing", function(newKingName)
    Framework.Notify(string.format(Config.Lang.new_king, newKingName), "info")
end)

if Config.DebugMode then
    RegisterCommand("testking", function()
        StartHoboKingEndlessChallenge()
    end, false)
end
