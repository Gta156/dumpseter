-- ============================================================
--  DATABASE INITIALIZATION
-- ============================================================

CreateThread(function()
    Wait(1000)

    Database.query([[
        CREATE TABLE IF NOT EXISTS bl_scav_progression (
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

    Database.query("UPDATE bl_scav_progression SET donated_drugs = 0")

    local expiredKing = Database.prepare([[
        SELECT identifier FROM bl_scav_progression
        WHERE is_king = 1
        AND last_active < DATE_SUB(NOW(), INTERVAL ? DAY)
    ]], { Config.StreetWarden.InactivityDays })

    if expiredKing then
        Database.query("UPDATE bl_scav_progression SET is_king = 0 WHERE identifier = ?", { expiredKing.identifier })
    end

    Database.query([[
        CREATE TABLE IF NOT EXISTS bl_scav_warden_leaderboard (
            identifier VARCHAR(255) PRIMARY KEY,
            player_name VARCHAR(255) NOT NULL,
            kill_count INT NOT NULL DEFAULT 0,
            date_achieved DATETIME DEFAULT CURRENT_TIMESTAMP,
            time_survived INT DEFAULT 0
        )
    ]])

    Database.query([[
        CREATE TABLE IF NOT EXISTS bl_scav_derby_leaderboards (
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

function FetchStreetRecord(identifier)
    local row = Database.prepare("SELECT * FROM bl_scav_progression WHERE identifier = ?", { identifier })

    if not row then
        Database.query("INSERT INTO bl_scav_progression (identifier, last_active) VALUES (?, NOW())", { identifier })

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

    Database.query("UPDATE bl_scav_progression SET last_active = NOW() WHERE identifier = ?", { identifier })

    local missionData = json.decode(row.mission_data)
    if not missionData then
        missionData = {}
    end
    row.mission_data = missionData

    return row
end

function PersistStreetRecord(identifier, progression)
    local missionDataJson = json.encode(progression.mission_data)

    Database.query([[
        UPDATE bl_scav_progression
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

    if Config.DiagnosticsEnabled then
        print("Updated progression for " .. identifier .. ": Level=" .. (progression.level or 1) .. ", XP=" .. (progression.xp or 0))
    end
end

function AwardStreetXP(identifier, amount, playerSource)
    local progression = FetchStreetRecord(identifier)

    local updated = {}
    updated.level = progression.level
    updated.xp = (tonumber(progression.xp) or 0) + amount
    updated.mission_data = progression.mission_data
    updated.is_king = progression.is_king
    updated.donated_drugs = progression.donated_drugs
    updated.true_hobo = progression.true_hobo

    if Config.DiagnosticsEnabled then
        print("Adding XP: " .. amount .. " to " .. identifier .. " | Old XP: " .. (progression.xp or 0) .. " | New XP: " .. updated.xp)
    end

    PersistStreetRecord(identifier, updated)

    return updated
end

local function FlagLifetimeVagrant(identifier, playerSource)
    local progression = FetchStreetRecord(identifier)
    progression.true_hobo = true
    PersistStreetRecord(identifier, progression)
    SyncVagrantJobRole(identifier, playerSource or source)
end

local function AttemptRankPromotion(identifier, playerSource)
    local progression = FetchStreetRecord(identifier)
    local nextLevel = progression.level + 1

    if nextLevel <= 10 then
        local xp = progression.xp
        local xpThreshold = Config.ProgressionSettings.RankThresholds[nextLevel]

        if xp >= xpThreshold then
            local levelMissionData = progression.mission_data[progression.level]

            if levelMissionData and progression.mission_data[progression.level].completed then
                progression.level = nextLevel

                local targetSource = source or playerSource
                if targetSource then
                    TriggerClientEvent("bl_scav:client:LevelUp", targetSource, nextLevel)
                end
            end
        end
    end

    PersistStreetRecord(identifier, progression)

    if nextLevel >= 5 then
        FlagLifetimeVagrant(identifier, playerSource)
    end

    return progression
end

-- ============================================================
--  MISSIONS
-- ============================================================

function ResolveRankContractName(level)
    if Config.Contracts[level] then
        return Config.Contracts[level].name
    end
    return nil
end

function FinalizeContract(identifier, missionId, playerSource)
    if Config.ProgressionSettings.ContractXP[missionId] then
        if Config.DiagnosticsEnabled then
            print("Adding XP: ", Config.ProgressionSettings.ContractXP[missionId])
        end
        AwardStreetXP(identifier, Config.ProgressionSettings.ContractXP[missionId], playerSource or source)
    end

    local progression = FetchStreetRecord(identifier)

    if Config.DiagnosticsEnabled then
        print("Complete Mission: ", identifier, missionId, playerSource or source)
    end

    if not progression.mission_data[missionId] then
        progression.mission_data[missionId] = {}
    end

    if progression.mission_data[missionId].completed then
        return
    end

    progression.mission_data[missionId].completed = true
    PersistStreetRecord(identifier, progression)

    return progression
end

function AdvanceContract(identifier, missionId, data)
    local progression = FetchStreetRecord(identifier)

    if not progression.mission_data[missionId] then
        progression.mission_data[missionId] = {}
    end

    for key, value in pairs(data) do
        progression.mission_data[missionId][key] = value
    end

    if missionId == 1 then
        local mission = progression.mission_data[missionId]
        if mission.zone_1_visited and mission.zone_2_visited and mission.zone_3_visited and mission.zone_4_visited and mission.zone_5_visited then
            FinalizeContract(identifier, missionId)
            return progression
        end
    end

    if missionId == 2 then
        local clearedList = progression.mission_data[missionId].cleared_list
        if not clearedList then
            clearedList = {}
        end
        if clearedList[1] and clearedList[2] and clearedList[3] then
            FinalizeContract(identifier, missionId)
            return progression
        end
    end

    if missionId == 7 then
        if progression.mission_data[missionId].rival_defeated then
            FinalizeContract(identifier, missionId)
            return progression
        end
    end

    PersistStreetRecord(identifier, progression)

    return progression
end

function ReadContractState(identifier, missionId)
    local progression = FetchStreetRecord(identifier)
    local mission = progression.mission_data[missionId]
    if not mission then
        mission = {}
    end
    return mission
end

-- ============================================================
--  DONATIONS
-- ============================================================

function TributeContraband(identifier, drugType, quantity, playerSource)
    local progression = FetchStreetRecord(identifier)

    if progression.donated_drugs == 1 then
        return false, Config.Lang.already_donated_drugs
    end

    local xpAmount = Config.ProgressionSettings.ContrabandTributeXP[drugType].xp * quantity
    if not xpAmount then
        return false, Config.Lang.invalid_drug_type
    end

    progression.donated_drugs = 1
    PersistStreetRecord(identifier, progression)

    AwardStreetXP(identifier, xpAmount, playerSource or source)

    return true, string.format(Config.Lang.donation_thank_you, xpAmount)
end

function TributeBottleCaps(identifier, amount, playerSource)
    local itemCount = Framework.GetItemCount(playerSource, Config.CapCurrencyItem or "bottle_cap")

    if not (amount <= itemCount) then
        return false, Config.Lang.not_enough_caps
    end

    local removed = Framework.RemoveItem(playerSource, Config.CapCurrencyItem or "bottle_cap", amount)
    if not removed then
        return false, Config.Lang.failed_remove_caps
    end

    local xpAmount = amount * Config.ProgressionSettings.XPPerCapTributed
    AwardStreetXP(identifier, xpAmount, playerSource)

    return true, string.format(Config.Lang.bottle_caps_spent, amount, xpAmount)
end

-- ============================================================
--  HOBO KING
-- ============================================================

function CrownStreetWarden(identifier)
    local currentKing = Database.scalar("SELECT identifier FROM bl_scav_progression WHERE is_king = 1")

    if currentKing then
        local kingIsInactive = Database.scalar([[
            SELECT 1 FROM bl_scav_progression
            WHERE identifier = ?
            AND last_active < DATE_SUB(NOW(), INTERVAL ? DAY)
        ]], { currentKing, Config.StreetWarden.InactivityDays })

        if not kingIsInactive then
            return false, Config.Lang.active_king_exists
        end

        Database.query("UPDATE bl_scav_progression SET is_king = 0 WHERE identifier = ?", { currentKing })
    end

    Database.query([[
        UPDATE bl_scav_progression
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
        TriggerClientEvent("bl_scav:client:NewKing", -1, player.Name)
    end

    return true, Config.Lang.now_hobo_king
end

-- ============================================================
--  EXPORTS
-- ============================================================

exports("GetPlayerProgression", FetchStreetRecord)
exports("AddHoboXP", AwardStreetXP)
exports("CompleteMission", FinalizeContract)
exports("UpdateMissionProgress", AdvanceContract)
exports("GetMissionProgress", ReadContractState)
exports("DonateBottleCaps", TributeBottleCaps)
exports("DonateDrugs", TributeContraband)

-- ============================================================
--  FRAMEWORK CALLBACKS
-- ============================================================

Framework.CreateCallback("bl_scav:server:GetProgression", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(nil)
    end

    local progression = FetchStreetRecord(player.Identifier)
    cb(progression)
end)

Framework.CreateCallback("bl_scav:server:DonateBottleCaps", function(source, cb, amount)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local success, message = TributeBottleCaps(player.Identifier, amount, source)
    cb(success, message)
end)

Framework.CreateCallback("bl_scav:server:DonateDrugs", function(source, cb, drugType, quantity)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local drugConfig = Config.ProgressionSettings.ContrabandTributeXP[drugType]
    if not drugConfig then
        return cb(false, Config.Lang.invalid_drug_type)
    end

    local itemCount = Framework.GetItemCount(source, drugType)
    if not (quantity <= itemCount) then
        return cb(false, string.format(Config.Lang.not_enough_drug, drugConfig.label))
    end

    Framework.RemoveItem(source, drugType, quantity)

    local success, message = TributeContraband(player.Identifier, drugType, quantity)
    cb(success, message)
end)

Framework.CreateCallback("bl_scav:server:isTrueHobo", function(source, cb)
    local player = Framework.GetPlayer(source)
    local identifier = player.Identifier
    local progression = FetchStreetRecord(identifier)
    local isLifetimeVagrant = progression.true_hobo == 1

    if isLifetimeVagrant then
        SyncVagrantJobRole(identifier, source)
    end

    cb(isLifetimeVagrant)
end)

-- ============================================================
--  EVENTS
-- ============================================================

RegisterNetEvent("bl_scav:server:LevelUp", function()
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    AttemptRankPromotion(player.Identifier, playerSource)
end)

-- ============================================================
--  HOBO FOR LIFE JOB ROLE
-- ============================================================

local lastReminderAt = {}
local VAGRANT_REMINDER_COOLDOWN = 1000

function SyncVagrantJobRole(identifier, playerSource)
    local player = Framework.GetPlayer(source or playerSource)
    local progression = FetchStreetRecord(identifier)

    if player then
        if progression.true_hobo == 1 or progression.true_hobo == true then
            local now = GetGameTimer()

            if not lastReminderAt[identifier] or (now - lastReminderAt[identifier]) > VAGRANT_REMINDER_COOLDOWN then
                Framework.Notify(source or playerSource, Config.Lang.hobo_for_life_reminder, "success")
                lastReminderAt[identifier] = now
            end

            player.SetJob(Config.VagrantJobRole, 0)
        end
    end
end

Framework.OnPlayerLoaded = function(source)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    SyncVagrantJobRole(player.Identifier, source)
end

-- ============================================================
--  DEBUG COMMANDS
-- ============================================================

if Config.DiagnosticsEnabled then
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

        local progression = FetchStreetRecord(player.Identifier)
        progression.level = level

        if level > 1 then
            progression.xp = Config.ProgressionSettings.RankThresholds[level]
        else
            progression.xp = 0
        end

        if level >= 5 then
            progression.true_hobo = true
        end

        PersistStreetRecord(player.Identifier, progression)
        Framework.Notify(source, string.format(Config.Lang.hobo_level_set, level), "success")
    end, false)
end
