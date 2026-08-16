-- ============================================================
--  MISSION PROGRESS / CALLBACKS
-- ============================================================

Framework.CreateCallback("envi-dumpsters:server:GetMissionProgress", function(source, cb, missionId)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb({})
    end

    local progress = GetMissionProgress(player.Identifier, missionId)
    cb(progress)
end)

Framework.CreateCallback("envi-dumpsters:server:isRecyclerUnlocked", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    if not Config.RecycleSettings.unlockedByMission then
        cb(true)
        return
    end

    local progression = GetPlayerProgression(player.Identifier)
    local missionData = progression.mission_data[5]
    if missionData then
        if missionData.recycler_unlocked then
            cb(true)
        end
    else
        cb(false)
    end
end)

RegisterNetEvent("envi-dumpsters:server:UpdateMissionProgress", function(missionId, data)
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    UpdateMissionProgress(player.Identifier, missionId, data)
end)

RegisterNetEvent("envi-dumpsters:server:BuyYourFreedom", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    local progression = GetPlayerProgression(player.Identifier)
    if not (progression and progression.level >= 10) then
        Framework.Notify(playerId, Config.Lang.must_be_level_10_freedom, "error")
        return
    end

    local capCount = Framework.GetItemCount(playerId, Config.BottleCapItem or "bottle_cap")
    local freedomCost = Config.HoboKing.FreedomCost
    if capCount < freedomCost then
        Framework.Notify(playerId, Config.Lang.not_enough_caps_freedom, "error")
        return
    end

    local removed = Framework.RemoveItem(playerId, Config.BottleCapItem or "bottle_cap", Config.HoboKing.FreedomCost)
    if not removed then
        Framework.Notify(playerId, Config.Lang.not_enough_caps_freedom, "error")
        return
    end

    Framework.Notify(playerId, Config.Lang.freedom_bought, "success")
    Database.query("DELETE FROM hobo_progression WHERE identifier = ?", {player.Identifier})
    TriggerClientEvent("envi-dumpsters:client:RemoveFromGroup", playerId)
    player.SetJob("unemployed", 0)
end)

Framework.CreateCallback("envi-dumpsters:server:HasItem", function(source, cb, itemName)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    local hasItem = Framework.GetItemCount(source, itemName) > 0
    cb(hasItem)
end)

RegisterNetEvent("envi-dumpsters:server:RemoveItem", function(itemName, count)
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    Framework.RemoveItem(playerId, itemName, count)
end)

Framework.CreateCallback("envi-dumpsters:server:BuyItem", function(source, cb, itemName, cost)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local capCount = Framework.GetItemCount(source, Config.BottleCapItem or "bottle_cap")
    if not (cost <= capCount) then
        return cb(false, Config.Lang.not_enough_caps)
    end

    local removed = Framework.RemoveItem(source, Config.BottleCapItem or "bottle_cap", cost)
    if not removed then
        return cb(false, Config.Lang.not_enough_caps)
    end

    if removed then
        Framework.AddItem(source, itemName, 1)
    end

    AddHoboXP(player.Identifier, cost)
    cb(true, string.format(Config.Lang.item_purchased, itemName, cost))
end)

RegisterNetEvent("envi-dumpsters:server:TrackJunkItems", function(amount, progression, src)
    local player = Framework.GetPlayer(src)
    if not player then
        return
    end

    if progression then
        if progression.level == 5 then
            local missionData = progression.mission_data[5]
            if not missionData then
                missionData = {}
            end

            local itemsCollected = missionData.items_collected
            if not itemsCollected then
                itemsCollected = 0
            end
            itemsCollected = itemsCollected + amount
            missionData.items_collected = itemsCollected

            UpdateMissionProgress(player.Identifier, 5, missionData)
            Framework.Notify(src, string.format(Config.Lang.supply_chain_progress, itemsCollected, Config.Missions[5].RequiredItems), "info")

            if itemsCollected >= Config.Missions[5].RequiredItems then
                CompleteMission(player.Identifier, 5)
                Framework.Notify(src, Config.Lang.junk_items_collected, "success")
                missionData.recycler_unlocked = true
                UpdateMissionProgress(player.Identifier, 5, missionData)
            end
        end
    end
end)

Framework.CreateCallback("envi-dumpsters:server:GiveRaccoonTreats", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local progression = GetPlayerProgression(player.Identifier)
    if progression then
        if progression.level == 8 then
            local missionData = progression.mission_data[8]
            if not missionData then
                missionData = {}
            end

            local treatsReceived = missionData.treats_received
            if not treatsReceived then
                Framework.AddItem(source, "racoon_treats", 5)
                missionData.treats_received = true
                UpdateMissionProgress(player.Identifier, 8, missionData)
                cb(true, Config.Lang.raccoon_treats_received)
            else
                cb(false, Config.Lang.find_raccoon_to_tame)
            end
        end
    else
        cb(false, Config.Lang.not_ready_for_mission)
    end
end)

Framework.CreateCallback("envi-dumpsters:server:TameRaccoon", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local hasTreats = Framework.GetItemCount(source, "racoon_treats") > 0
    if not hasTreats then
        return cb(false, Config.Lang.need_raccoon_treats)
    end

    Framework.RemoveItem(source, "racoon_treats", 1)

    local roll = math.random(1, 100)
    if roll <= 50 then
        return cb(false, Config.Lang.failed_tame_raccoon)
    end

    local progression = GetPlayerProgression(player.Identifier)
    if progression then
        if progression.level == 8 then
            local missionData = progression.mission_data[8]
            if not missionData then
                missionData = {}
            end

            missionData.raccoon_tamed = true
            UpdateMissionProgress(player.Identifier, 8, missionData)
            CompleteMission(player.Identifier, 8)
            cb(true, Config.Lang.raccoon_tamed_well_done)
        end
    else
        cb(true, Config.Lang.raccoon_tamed)
    end
end)

-- ============================================================
--  HOBO KING
-- ============================================================

Framework.CreateCallback("envi-dumpsters:server:ChallengeHoboKing", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    Framework.TriggerCallback("envi-dumpsters:server:GetProgression", function(progression)
        if not (progression and progression.level >= 10) then
            return cb(false, Config.Lang.must_be_level_10_challenge)
        end

        local currentKingIdentifier = Database.scalar("SELECT identifier FROM hobo_progression WHERE is_king = 1")
        if not currentKingIdentifier then
            SetHoboKing(player.Identifier)
            return cb(true, Config.Lang.no_current_king)
        end

        local isInactive = Database.scalar([[
            SELECT 1 FROM hobo_progression
            WHERE identifier = ?
            AND last_active < DATE_SUB(NOW(), INTERVAL ? DAY)
        ]], {currentKingIdentifier, Config.HoboKing.InactivityTimer})
        if isInactive then
            SetHoboKing(player.Identifier)
            return cb(true, Config.Lang.inactive_king)
        end

        local missionData = progression.mission_data[11]
        if not missionData then
            missionData = {}
        end
        missionData.king_fight_started = true
        UpdateMissionProgress(player.Identifier, 11, missionData)
        TriggerClientEvent("envi-dumpsters:client:StartKingFight", source)
        cb(true, Config.Lang.challenge_begun)
    end)
end)

RegisterNetEvent("envi-dumpsters:server:ratAttack", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    local removed = Framework.RemoveItem(playerId, "WEAPON_HOBO_STICK", 1)
    if removed then
        Framework.AddItem(playerId, "WEAPON_HOBO_RATSTICK", 1)
    end
end)

RegisterNetEvent("envi-dumpsters:server:CompleteKingChallenge", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    Framework.TriggerCallback("envi-dumpsters:server:GetProgression", function(progression)
        if not (progression and progression.level >= 10) then
            return
        end

        local missionData = progression.mission_data[11]
        if not missionData then
            missionData = {}
        end

        local kingFightStarted = missionData.king_fight_started
        if not kingFightStarted then
            return
        end

        CompleteMission(player.Identifier, 11)
        SetHoboKing(player.Identifier)
        Framework.Notify(playerId, Config.Lang.congrats_new_king, "success")
    end)
end)

RegisterNetEvent("envi-dumpsters:server:CompleteThrillRide", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    local identifier = player.Identifier
    local progression = GetPlayerProgression(identifier)
    if progression then
        if progression.level == 4 then
            CompleteMission(identifier, 4)
            Framework.AddItem(playerId, Config.BottleCapItem or "bottle_cap", math.random(5, 15))
            AddHoboXP(identifier, Config.XPSettings.MissionXP[4] or 100)
            Framework.Notify(playerId, Config.Lang.thrill_ride_complete, "success")
        end
    end
end)

Framework.CreateCallback("envi-dumpsters:server:CompleteTaxiMission", function(source, cb, tipPercent)
    local playerId = source
    if not tipPercent then
        tipPercent = math.random(10, 25)
    end

    local player = Framework.GetPlayer(playerId)
    if not player then
        return cb(false)
    end

    local identifier = player.Identifier
    local progression = GetPlayerProgression(identifier)
    if not (progression and progression.level >= 9) then
        Framework.Notify(playerId, Config.Lang.taxi_level_requirement, "error")
        return cb(false)
    end

    CompleteMission(identifier, 9)

    local baseXP = Config.XPSettings.MissionXP[9] or 200
    local baseReward = 25
    local tipMultiplier = 1 + (math.min(tipPercent, 50) / 100)
    local xpGained = math.floor(baseXP)
    local capsGained = math.floor(baseReward * tipMultiplier)

    AddHoboXP(identifier, xpGained)
    Framework.AddItem(playerId, Config.BottleCapItem or "bottle_cap", capsGained)
    Framework.Notify(playerId, string.format(Config.Lang.taxi_mission_completed, xpGained, capsGained, tipPercent), "success")
    cb(true)
end)

Framework.CreateCallback("envi-dumpsters:server:GetHoboKingLeaderboard", function(source, cb)
    local leaderboard = Database.query("SELECT player_name, kill_count, date_achieved, time_survived FROM hobo_king_leaderboard ORDER BY kill_count DESC LIMIT 10")
    cb(leaderboard or {})
end)

RegisterNetEvent("envi-dumpsters:server:RecordKingChallengeAttempt", function(killCount, timeSurvived)
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    local playerName = player.Name
    if not playerName then
        playerName = "Unknown Hobo"
    end

    local identifier = player.Identifier
    local minTopKillCount = Database.scalar("SELECT MIN(kill_count) FROM (SELECT kill_count FROM hobo_king_leaderboard ORDER BY kill_count DESC LIMIT 10) as top10")

    if minTopKillCount == nil or killCount >= minTopKillCount then
        local existingRows = Database.query("SELECT kill_count FROM hobo_king_leaderboard WHERE identifier = ?", {identifier})
        local existingRow = existingRows[1]

        if existingRow and not (killCount > existingRow.kill_count) then
            Framework.Notify(playerId, string.format(Config.Lang.challenge_complete_best, killCount, existingRows[1].kill_count), "info")
        else
            Database.query([[
                INSERT INTO hobo_king_leaderboard (identifier, player_name, kill_count, date_achieved, time_survived)
                VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?)
                ON DUPLICATE KEY UPDATE
                kill_count = ?,
                player_name = ?,
                date_achieved = CURRENT_TIMESTAMP,
                time_survived = ?
            ]], {identifier, playerName, killCount, timeSurvived, killCount, playerName, timeSurvived})

            local newMaxKillCount = Database.scalar("SELECT MAX(kill_count) FROM hobo_king_leaderboard")

            Database.query([[
                DELETE FROM hobo_king_leaderboard
                WHERE identifier NOT IN (
                    SELECT identifier FROM (
                        SELECT identifier FROM hobo_king_leaderboard
                        ORDER BY kill_count DESC LIMIT 10
                    ) as top10
                )
            ]])

            if newMaxKillCount == killCount then
                SetHoboKing(identifier)
                TriggerClientEvent("envi-dumpsters:client:NewKing", -1, playerName)
                Framework.Notify(playerId, string.format(Config.Lang.new_king_with_kills, killCount), "success")
            else
                Framework.Notify(playerId, string.format(Config.Lang.challenge_complete_record, killCount, newMaxKillCount), "success")
            end
        end
    else
        Framework.Notify(playerId, string.format(Config.Lang.challenge_complete_no_qualify, killCount), "info")
    end
end)

-- ============================================================
--  ROUTING BUCKETS
-- ============================================================

RegisterNetEvent("envi-dumpsters:server:RequestRoutingBucket", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    local bucketId = 10000 + playerId
    SetRoutingBucketPopulationEnabled(bucketId, false)
    SetPlayerRoutingBucket(playerId, bucketId)
    TriggerClientEvent("envi-dumpsters:client:SetRoutingBucket", playerId, bucketId)
end)

RegisterNetEvent("envi-dumpsters:server:ReturnToNormalBucket", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    SetPlayerRoutingBucket(playerId, 0)
end)

Framework.CreateCallback("envi-dumpsters:server:IsHoboKing", function(source, cb)
    print("Checking if player is Hobo King...")

    local player = Framework.GetPlayer(source)
    if not player then
        print("Player not found, returning false")
        return cb(false)
    end

    print("Checking database for player identifier: " .. player.Identifier)

    local rows = Database.query("SELECT is_king FROM hobo_progression WHERE identifier = ?", {player.Identifier})
    if not (rows and #rows ~= 0) then
        print("No database entry found, returning false")
        return cb(false)
    end

    local isKing = rows[1].is_king
    print("Database returned is_king value: " .. tostring(isKing))
    cb(isKing)
end)
