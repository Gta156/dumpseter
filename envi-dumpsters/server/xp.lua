-- ============================================================
--  DATABASE INITIALIZATION
-- ============================================================

CreateThread(function()
    Wait(1000)

    Database.query([[
        CREATE TABLE IF NOT EXISTS hobo_progression (
            identifier VARCHAR(60) PRIMARY KEY,
            level INT DEFAULT 1,
            xp INT DEFAULT 0,
            mission_data JSON DEFAULT '{}',
            is_king BOOLEAN DEFAULT 0,
            king_since DATETIME,
            last_active DATETIME,
            donated_drugs INT DEFAULT 0,
            true_hobo BOOLEAN DEFAULT 0
        )
    ]])

    Database.query("UPDATE hobo_progression SET donated_drugs = 0")

    local expiredKing = Database.prepare([[
        SELECT identifier FROM hobo_progression
        WHERE is_king = 1
        AND last_active < DATE_SUB(NOW(), INTERVAL ? DAY)
    ]], { Config.HoboKing.InactivityTimer })

    if expiredKing then
        Database.query("UPDATE hobo_progression SET is_king = 0 WHERE identifier = ?", { expiredKing.identifier })
    end

    Database.query([[
        CREATE TABLE IF NOT EXISTS hobo_king_leaderboard (
            identifier VARCHAR(255) PRIMARY KEY,
            player_name VARCHAR(255) NOT NULL,
            kill_count INT NOT NULL DEFAULT 0,
            date_achieved DATETIME DEFAULT CURRENT_TIMESTAMP,
            time_survived INT DEFAULT 0
        )
    ]])

    Database.query([[
        CREATE TABLE IF NOT EXISTS hobo_cart_leaderboards (
            id INT AUTO_INCREMENT PRIMARY KEY,
            identifier VARCHAR(60),
            track VARCHAR(100),
            distance FLOAT,
            name VARCHAR(100),
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_track_distance (track, distance DESC)
        )
    ]])
end)

-- ============================================================
--  PROGRESSION CORE
-- ============================================================

function GetPlayerProgression(identifier)
    local row = Database.prepare("SELECT * FROM hobo_progression WHERE identifier = ?", { identifier })

    if not row then
        Database.query("INSERT INTO hobo_progression (identifier, last_active) VALUES (?, NOW())", { identifier })

        local progression = {}
        progression.identifier = identifier
        progression.level = 1
        progression.xp = 0
        progression.mission_data = {}
        progression.is_king = false
        progression.king_since = nil
        progression.last_active = os.time()
        progression.donated_drugs = 0
        progression.true_hobo = false
        return progression
    end

    Database.query("UPDATE hobo_progression SET last_active = NOW() WHERE identifier = ?", { identifier })

    local missionData = json.decode(row.mission_data)
    if not missionData then
        missionData = {}
    end
    row.mission_data = missionData

    return row
end

function UpdatePlayerProgression(identifier, progression)
    local missionDataJson = json.encode(progression.mission_data)

    Database.query([[
        UPDATE hobo_progression
        SET level = ?, xp = ?, mission_data = ?, is_king = ?, last_active = NOW(), donated_drugs = ?, true_hobo = ?
        WHERE identifier = ?
    ]], {
        progression.level,
        progression.xp,
        missionDataJson,
        progression.is_king,
        progression.donated_drugs,
        progression.true_hobo,
        identifier
    })

    if Config.DebugMode then
        print("Updated progression for " .. identifier .. ": Level=" .. (progression.level or 1) .. ", XP=" .. (progression.xp or 0))
    end
end

function AddHoboXP(identifier, amount, playerSource)
    local progression = GetPlayerProgression(identifier)

    local updated = {}
    updated.level = progression.level
    updated.xp = (tonumber(progression.xp) or 0) + amount
    updated.mission_data = progression.mission_data
    updated.is_king = progression.is_king
    updated.donated_drugs = progression.donated_drugs
    updated.true_hobo = progression.true_hobo

    if Config.DebugMode then
        print("Adding XP: " .. amount .. " to " .. identifier .. " | Old XP: " .. (progression.xp or 0) .. " | New XP: " .. updated.xp)
    end

    UpdatePlayerProgression(identifier, updated)

    return updated
end

local function MarkAsTrueHobo(identifier, playerSource)
    local progression = GetPlayerProgression(identifier)
    progression.true_hobo = true
    UpdatePlayerProgression(identifier, progression)
    EnsureHoboJobRole(identifier, playerSource or source)
end

local function TryLevelUp(identifier, playerSource)
    local progression = GetPlayerProgression(identifier)
    local nextLevel = progression.level + 1

    if nextLevel <= 10 then
        local xp = progression.xp
        local xpRequired = Config.XPSettings.LevelRequirements[nextLevel]

        if xp >= xpRequired then
            local levelMissionData = progression.mission_data[progression.level]

            if levelMissionData and progression.mission_data[progression.level].completed then
                progression.level = nextLevel

                local targetSource = source or playerSource
                if targetSource then
                    TriggerClientEvent("envi-dumpsters:client:LevelUp", targetSource, nextLevel)
                end
            end
        end
    end

    UpdatePlayerProgression(identifier, progression)

    if nextLevel >= 5 then
        MarkAsTrueHobo(identifier, playerSource)
    end

    return progression
end

-- ============================================================
--  MISSIONS
-- ============================================================

function GetLevelMissionName(level)
    if Config.Missions[level] then
        return Config.Missions[level].name
    end
    return nil
end

function CompleteMission(identifier, missionId, playerSource)
    if Config.XPSettings.MissionXP[missionId] then
        if Config.DebugMode then
            print("Adding XP: ", Config.XPSettings.MissionXP[missionId])
        end
        AddHoboXP(identifier, Config.XPSettings.MissionXP[missionId], playerSource or source)
    end

    local progression = GetPlayerProgression(identifier)

    if Config.DebugMode then
        print("Complete Mission: ", identifier, missionId, playerSource or source)
    end

    if not progression.mission_data[missionId] then
        progression.mission_data[missionId] = {}
    end

    if progression.mission_data[missionId].completed then
        return
    end

    progression.mission_data[missionId].completed = true
    UpdatePlayerProgression(identifier, progression)

    return progression
end

function UpdateMissionProgress(identifier, missionId, data)
    local progression = GetPlayerProgression(identifier)

    if not progression.mission_data[missionId] then
        progression.mission_data[missionId] = {}
    end

    for key, value in pairs(data) do
        progression.mission_data[missionId][key] = value
    end

    if missionId == 1 then
        local mission = progression.mission_data[missionId]
        if mission.zone_1_visited and mission.zone_2_visited and mission.zone_3_visited and mission.zone_4_visited and mission.zone_5_visited then
            CompleteMission(identifier, missionId)
            return progression
        end
    end

    if missionId == 2 then
        local clearedList = progression.mission_data[missionId].cleared_list
        if not clearedList then
            clearedList = {}
        end
        if clearedList[1] and clearedList[2] and clearedList[3] then
            CompleteMission(identifier, missionId)
            return progression
        end
    end

    if missionId == 7 then
        if progression.mission_data[missionId].rival_defeated then
            CompleteMission(identifier, missionId)
            return progression
        end
    end

    UpdatePlayerProgression(identifier, progression)

    return progression
end

function GetMissionProgress(identifier, missionId)
    local progression = GetPlayerProgression(identifier)
    local mission = progression.mission_data[missionId]
    if not mission then
        mission = {}
    end
    return mission
end

-- ============================================================
--  DONATIONS
-- ============================================================

function DonateDrugs(identifier, drugType, quantity, playerSource)
    local progression = GetPlayerProgression(identifier)

    if progression.donated_drugs == 1 then
        return false, Config.Lang.already_donated_drugs
    end

    local xpAmount = Config.XPSettings.DrugDonationXP[drugType].xp * quantity
    if not xpAmount then
        return false, Config.Lang.invalid_drug_type
    end

    progression.donated_drugs = 1
    UpdatePlayerProgression(identifier, progression)

    AddHoboXP(identifier, xpAmount, playerSource or source)

    return true, string.format(Config.Lang.donation_thank_you, xpAmount)
end

function DonateBottleCaps(identifier, amount, playerSource)
    local itemCount = Framework.GetItemCount(playerSource, Config.BottleCapItem or "bottle_cap")

    if not (amount <= itemCount) then
        return false, Config.Lang.not_enough_caps
    end

    local removed = Framework.RemoveItem(playerSource, Config.BottleCapItem or "bottle_cap", amount)
    if not removed then
        return false, Config.Lang.failed_remove_caps
    end

    local xpAmount = amount * Config.XPSettings.XPPerBottleCapDonated
    AddHoboXP(identifier, xpAmount, playerSource)

    return true, string.format(Config.Lang.bottle_caps_spent, amount, xpAmount)
end

-- ============================================================
--  HOBO KING
-- ============================================================

function SetHoboKing(identifier)
    local currentKing = Database.scalar("SELECT identifier FROM hobo_progression WHERE is_king = 1")

    if currentKing then
        local kingIsInactive = Database.scalar([[
            SELECT 1 FROM hobo_progression
            WHERE identifier = ?
            AND last_active < DATE_SUB(NOW(), INTERVAL ? DAY)
        ]], { currentKing, Config.HoboKing.InactivityTimer })

        if not kingIsInactive then
            return false, Config.Lang.active_king_exists
        end

        Database.query("UPDATE hobo_progression SET is_king = 0 WHERE identifier = ?", { currentKing })
    end

    Database.query([[
        UPDATE hobo_progression
        SET is_king = 1, king_since = NOW()
        WHERE identifier = ?
    ]], { identifier })

    local existingPlayer = Framework.GetPlayerByIdentifier(identifier)
    local playerSource
    if existingPlayer then
        playerSource = existingPlayer.source
    end

    local player
    if playerSource then
        player = Framework.GetPlayer(playerSource)
    end

    if player then
        Framework.AddItem(playerSource, "hobo_crown", 1)
        TriggerClientEvent("envi-dumpsters:client:NewKing", -1, player.Name)
    end

    return true, Config.Lang.now_hobo_king
end

-- ============================================================
--  EXPORTS
-- ============================================================

exports("GetPlayerProgression", GetPlayerProgression)
exports("AddHoboXP", AddHoboXP)
exports("CompleteMission", CompleteMission)
exports("UpdateMissionProgress", UpdateMissionProgress)
exports("GetMissionProgress", GetMissionProgress)
exports("DonateBottleCaps", DonateBottleCaps)
exports("DonateDrugs", DonateDrugs)

-- ============================================================
--  FRAMEWORK CALLBACKS
-- ============================================================

Framework.CreateCallback("envi-dumpsters:server:GetProgression", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(nil)
    end

    local progression = GetPlayerProgression(player.Identifier)
    cb(progression)
end)

Framework.CreateCallback("envi-dumpsters:server:DonateBottleCaps", function(source, cb, amount)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local success, message = DonateBottleCaps(player.Identifier, amount, source)
    cb(success, message)
end)

Framework.CreateCallback("envi-dumpsters:server:DonateDrugs", function(source, cb, drugType, quantity)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local drugConfig = Config.XPSettings.DrugDonationXP[drugType]
    if not drugConfig then
        return cb(false, Config.Lang.invalid_drug_type)
    end

    local itemCount = Framework.GetItemCount(source, drugType)
    if not (quantity <= itemCount) then
        return cb(false, string.format(Config.Lang.not_enough_drug, drugConfig.label))
    end

    Framework.RemoveItem(source, drugType, quantity)

    local success, message = DonateDrugs(player.Identifier, drugType, quantity)
    cb(success, message)
end)

Framework.CreateCallback("envi-dumpsters:server:isTrueHobo", function(source, cb)
    local player = Framework.GetPlayer(source)
    local identifier = player.Identifier
    local progression = GetPlayerProgression(identifier)
    local isTrueHobo = progression.true_hobo == 1

    if isTrueHobo then
        EnsureHoboJobRole(identifier, source)
    end

    cb(isTrueHobo)
end)

-- ============================================================
--  EVENTS
-- ============================================================

RegisterNetEvent("envi-dumpsters:server:LevelUp", function()
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    TryLevelUp(player.Identifier, playerSource)
end)

-- ============================================================
--  HOBO FOR LIFE JOB ROLE
-- ============================================================

local lastReminderTime = {}
local HOBO_REMINDER_COOLDOWN = 1000

function EnsureHoboJobRole(identifier, playerSource)
    local player = Framework.GetPlayer(source or playerSource)
    local progression = GetPlayerProgression(identifier)

    if player then
        if progression.true_hobo == 1 or progression.true_hobo == true then
            local now = GetGameTimer()

            if not lastReminderTime[identifier] or (now - lastReminderTime[identifier]) > HOBO_REMINDER_COOLDOWN then
                Framework.Notify(source or playerSource, Config.Lang.hobo_for_life_reminder, "success")
                lastReminderTime[identifier] = now
            end

            player.SetJob(Config.HoboJobRole, 0)
        end
    end
end

Framework.OnPlayerLoaded = function(source)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    EnsureHoboJobRole(player.Identifier, source)
end

-- ============================================================
--  DEBUG COMMANDS
-- ============================================================

if Config.DebugMode then
    RegisterCommand("ed_setHoboLevel", function(source, args)
        local player = Framework.GetPlayer(source)
        if not player then
            return
        end

        local level = tonumber(args[1])
        if not level or level < 1 or level > 10 then
            Framework.Notify(source, Config.Lang.specify_valid_level, "error")
            return
        end

        local progression = GetPlayerProgression(player.Identifier)
        progression.level = level

        if level > 1 then
            progression.xp = Config.XPSettings.LevelRequirements[level]
        else
            progression.xp = 0
        end

        if level >= 5 then
            progression.true_hobo = true
        end

        UpdatePlayerProgression(player.Identifier, progression)
        Framework.Notify(source, string.format(Config.Lang.hobo_level_set, level), "success")
    end, false)
end
