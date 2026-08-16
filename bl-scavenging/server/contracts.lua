-- ============================================================
--  MISSION PROGRESS / CALLBACKS
-- ============================================================

Framework.CreateCallback("bl_scav:server:GetMissionProgress", function(source, cb, missionId)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb({})
    end

    local progress = ReadContractState(player.Identifier, missionId)
    cb(progress)
end)

Framework.CreateCallback("bl_scav:server:isRecyclerUnlocked", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    if not Config.ReclaimSettings.unlockedByMission then
        cb(true)
        return
    end

    local progression = FetchStreetRecord(player.Identifier)
    local missionData = progression.mission_data[5]
    if missionData then
        if missionData.recycler_unlocked then
            cb(true)
        end
    else
        cb(false)
    end
end)

-- SECURITY: `missionId` and `data` are attacker-controlled. The original passed both
-- straight into the progression writer, so a client could inject arbitrary keys into the
-- persisted mission_data JSON (or mark any mission complete). We now require a known
-- mission id and copy only flat scalar values out of the payload.
RegisterNetEvent("bl_scav:server:UpdateMissionProgress", function(missionId, data)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end

    local id = tonumber(missionId)
    if not id or not Config.Contracts[id] then
        Security.Flag(src, "unknown contract id in progress update")
        return
    end

    if type(data) ~= "table" then
        return
    end

    if not Security.RateLimit(src, "missionProgress", 250) then
        return
    end

    -- Whitelist scalars only: no nested tables, no functions, bounded key/value sizes.
    local safeData = {}
    local fields = 0
    for key, value in pairs(data) do
        if type(key) == "string" and #key <= 48 then
            local vt = type(value)
            if vt == "boolean" or vt == "number" or (vt == "string" and #value <= 128) then
                safeData[key] = value
                fields = fields + 1
            elseif vt == "table" then
                -- Mission 1 tracks a `visited` array of booleans; allow that single shape.
                local nested, count = {}, 0
                for k2, v2 in pairs(value) do
                    if type(v2) == "boolean" and count < 32 then
                        nested[tonumber(k2) or k2] = v2
                        count = count + 1
                    end
                end
                if count > 0 then
                    safeData[key] = nested
                    fields = fields + 1
                end
            end
        end
        if fields >= 32 then break end
    end

    AdvanceContract(player.Identifier, id, safeData)
end)

RegisterNetEvent("bl_scav:server:BuyYourFreedom", function()
    local player, playerId = Security.ResolvePlayer(source)
    if not player then
        return
    end
    if not Security.RateLimit(playerId, "buyFreedom", 3000) then
        return
    end

    local progression = FetchStreetRecord(player.Identifier)
    if not (progression and progression.level >= 10) then
        Framework.Notify(playerId, Config.Lang.must_be_level_10_freedom, "error")
        return
    end

    local capCount = Framework.GetItemCount(playerId, Config.CapCurrencyItem or "bottle_cap")
    local buyoutCost = Config.StreetWarden.FreedomCost
    if capCount < buyoutCost then
        Framework.Notify(playerId, Config.Lang.not_enough_caps_freedom, "error")
        return
    end

    local removed = Framework.RemoveItem(playerId, Config.CapCurrencyItem or "bottle_cap", Config.StreetWarden.FreedomCost)
    if not removed then
        Framework.Notify(playerId, Config.Lang.not_enough_caps_freedom, "error")
        return
    end

    Framework.Notify(playerId, Config.Lang.freedom_bought, "success")
    Database.query("DELETE FROM bl_scav_progression WHERE identifier = ?", {player.Identifier})
    TriggerClientEvent("bl_scav:client:RemoveFromGroup", playerId)
    player.SetJob("unemployed", 0)
end)

Framework.CreateCallback("bl_scav:server:HasItem", function(source, cb, itemName)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    local hasItem = Framework.GetItemCount(source, itemName) > 0
    cb(hasItem)
end)

-- REMOVED (security): "bl_scav:server:RemoveItem" was a net event that deleted ANY item,
-- in ANY quantity, from the calling player's inventory with no validation whatsoever.
-- It was a griefing/exploit primitive (e.g. a malicious resource or injected client could
-- wipe a player's inventory) and nothing in this resource ever triggered it from the
-- client. It has been deleted rather than hardened. Item removal now only happens inside
-- the specific server-side flows that own it (purchases, tributes, item usage).

--- Purchase a single catalogue item.
---
--- SECURITY: the original took BOTH the item name AND its `cost` from the client, so a
--- modified client could buy any item in the game for 0 bottle caps (and even award
--- itself XP equal to a negative cost). The price and the level requirement are now
--- resolved server-side from Config.UnlockCatalogue; the client only names the item.
Framework.CreateCallback("bl_scav:server:BuyItem", function(source, cb, itemName)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    if type(itemName) ~= "string" or #itemName > 64 then
        Security.Flag(src, "malformed item name in purchase")
        return cb(false, Config.Lang.player_not_found)
    end

    if not Security.RateLimit(src, "buyItem", 500) then
        return cb(false, Config.Lang.player_not_found)
    end

    -- Authoritative price + unlock level straight from the catalogue.
    local catalogueEntry, requiredLevel
    for level, entries in pairs(Config.UnlockCatalogue) do
        for _, entry in ipairs(entries) do
            if entry.name == itemName then
                catalogueEntry, requiredLevel = entry, level
                break
            end
        end
        if catalogueEntry then break end
    end

    if not catalogueEntry or type(catalogueEntry.price) ~= "number" then
        Security.Flag(src, "purchase of an item that is not in the catalogue")
        return cb(false, Config.Lang.player_not_found)
    end

    local progression = FetchStreetRecord(player.Identifier)
    if (progression and progression.level or 1) < requiredLevel then
        return cb(false, Config.Lang.level_too_low)
    end

    local cost = math.floor(catalogueEntry.price)
    local capItem = Config.CapCurrencyItem or "bottle_cap"
    if Framework.GetItemCount(src, capItem) < cost then
        return cb(false, Config.Lang.not_enough_caps)
    end

    if not Framework.RemoveItem(src, capItem, cost) then
        return cb(false, Config.Lang.not_enough_caps)
    end

    if not Framework.AddItem(src, itemName, 1) then
        -- Refund on failure so caps are never lost to a full inventory.
        Framework.AddItem(src, capItem, cost)
        return cb(false, Config.Lang.failed_add_item)
    end

    AwardStreetXP(player.Identifier, cost)
    cb(true, string.format(Config.Lang.item_purchased, itemName, cost))
end)

-- SECURITY: this was a net event taking the target source AND a full `progression` table
-- from the caller, letting a client drive another player's contract state with fabricated
-- level data. It is only ever raised server-side (server/progress_loot.lua), so it is now
-- an ordinary event handler and is unreachable from the network.
AddEventHandler("bl_scav:server:TrackJunkItems", function(amount, progression, src)
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

            AdvanceContract(player.Identifier, 5, missionData)
            Framework.Notify(src, string.format(Config.Lang.supply_chain_progress, itemsCollected, Config.Contracts[5].RequiredItems), "info")

            if itemsCollected >= Config.Contracts[5].RequiredItems then
                FinalizeContract(player.Identifier, 5)
                Framework.Notify(src, Config.Lang.junk_items_collected, "success")
                missionData.recycler_unlocked = true
                AdvanceContract(player.Identifier, 5, missionData)
            end
        end
    end
end)

Framework.CreateCallback("bl_scav:server:GiveRaccoonTreats", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local progression = FetchStreetRecord(player.Identifier)
    if progression then
        if progression.level == 8 then
            local missionData = progression.mission_data[8]
            if not missionData then
                missionData = {}
            end

            local treatsGiven = missionData.treats_received
            if not treatsGiven then
                Framework.AddItem(source, "racoon_treats", 5)
                missionData.treats_received = true
                AdvanceContract(player.Identifier, 8, missionData)
                cb(true, Config.Lang.raccoon_treats_received)
            else
                cb(false, Config.Lang.find_raccoon_to_tame)
            end
        end
    else
        cb(false, Config.Lang.not_ready_for_mission)
    end
end)

Framework.CreateCallback("bl_scav:server:TameRaccoon", function(source, cb)
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

    local progression = FetchStreetRecord(player.Identifier)
    if progression then
        if progression.level == 8 then
            local missionData = progression.mission_data[8]
            if not missionData then
                missionData = {}
            end

            missionData.raccoon_tamed = true
            AdvanceContract(player.Identifier, 8, missionData)
            FinalizeContract(player.Identifier, 8)
            cb(true, Config.Lang.raccoon_tamed_well_done)
        end
    else
        cb(true, Config.Lang.raccoon_tamed)
    end
end)

-- ============================================================
--  HOBO KING
-- ============================================================

Framework.CreateCallback("bl_scav:server:ChallengeHoboKing", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    Framework.TriggerCallback("bl_scav:server:GetProgression", function(progression)
        if not (progression and progression.level >= 10) then
            return cb(false, Config.Lang.must_be_level_10_challenge)
        end

        local currentKingIdentifier = Database.scalar("SELECT identifier FROM bl_scav_progression WHERE is_king = 1")
        if not currentKingIdentifier then
            CrownStreetWarden(player.Identifier)
            return cb(true, Config.Lang.no_current_king)
        end

        local isInactive = Database.scalar([[
            SELECT 1 FROM bl_scav_progression
            WHERE identifier = ?
            AND last_active < DATE_SUB(NOW(), INTERVAL ? DAY)
        ]], {currentKingIdentifier, Config.StreetWarden.InactivityDays})
        if isInactive then
            CrownStreetWarden(player.Identifier)
            return cb(true, Config.Lang.inactive_king)
        end

        local missionData = progression.mission_data[11]
        if not missionData then
            missionData = {}
        end
        missionData.king_fight_started = true
        AdvanceContract(player.Identifier, 11, missionData)
        TriggerClientEvent("bl_scav:client:StartKingFight", source)
        cb(true, Config.Lang.challenge_begun)
    end)
end)

RegisterNetEvent("bl_scav:server:ratAttack", function()
    local player, playerId = Security.ResolvePlayer(source)
    if not player then
        return
    end
    if not Security.RateLimit(playerId, "ratAttack", 1000) then
        return
    end

    local removed = Framework.RemoveItem(playerId, "WEAPON_HOBO_STICK", 1)
    if removed then
        Framework.AddItem(playerId, "WEAPON_HOBO_RATSTICK", 1)
    end
end)

RegisterNetEvent("bl_scav:server:CompleteKingChallenge", function()
    local player, playerId = Security.ResolvePlayer(source)
    if not player then
        return
    end
    if not Security.RateLimit(playerId, "completeGauntlet", 5000) then
        return
    end

    Framework.TriggerCallback("bl_scav:server:GetProgression", function(progression)
        if not (progression and progression.level >= 10) then
            return
        end

        local missionData = progression.mission_data[11]
        if not missionData then
            missionData = {}
        end

        local wardenDuelStarted = missionData.king_fight_started
        if not wardenDuelStarted then
            return
        end

        FinalizeContract(player.Identifier, 11)
        CrownStreetWarden(player.Identifier)
        Framework.Notify(playerId, Config.Lang.congrats_new_king, "success")
    end)
end)

-- Rate limited: guarded by the level-4 contract state, but the reward loop is otherwise
-- repeatable as fast as a client can send events.
RegisterNetEvent("bl_scav:server:CompleteThrillRide", function()
    local player, playerId = Security.ResolvePlayer(source)
    if not player then
        return
    end
    if not Security.RateLimit(playerId, "thrillRide", 3000) then
        return
    end

    local identifier = player.Identifier
    local progression = FetchStreetRecord(identifier)
    if progression then
        if progression.level == 4 then
            FinalizeContract(identifier, 4)
            Framework.AddItem(playerId, Config.CapCurrencyItem or "bottle_cap", math.random(5, 15))
            AwardStreetXP(identifier, Config.ProgressionSettings.ContractXP[4] or 100)
            Framework.Notify(playerId, Config.Lang.thrill_ride_complete, "success")
        end
    end
end)

-- SECURITY: `tipPercent` came from the client and fed the bottle-cap payout directly.
-- Although the original clamped the multiplier at 50, it never rejected non-numeric or
-- negative input, so a crafted value could zero out or invert the reward maths (and the
-- value was echoed into a notification format string). The tip is now always rolled
-- server-side; the client parameter is ignored entirely.
Framework.CreateCallback("bl_scav:server:CompleteTaxiMission", function(source, cb, _tipPercent)
    local player, playerId = Security.ResolvePlayer(source)
    if not player then
        return cb(false)
    end

    if not Security.RateLimit(playerId, "taxiComplete", 2000) then
        return cb(false)
    end

    local tipPercent = math.random(10, 25)

    local identifier = player.Identifier
    local progression = FetchStreetRecord(identifier)
    if not (progression and progression.level >= 9) then
        Framework.Notify(playerId, Config.Lang.taxi_level_requirement, "error")
        return cb(false)
    end

    FinalizeContract(identifier, 9)

    local baseXP = Config.ProgressionSettings.ContractXP[9] or 200
    local baseReward = 25
    local payoutMultiplier = 1 + (math.min(tipPercent, 50) / 100)
    local xpAwarded = math.floor(baseXP)
    local capsAwarded = math.floor(baseReward * payoutMultiplier)

    AwardStreetXP(identifier, xpAwarded)
    Framework.AddItem(playerId, Config.CapCurrencyItem or "bottle_cap", capsAwarded)
    Framework.Notify(playerId, string.format(Config.Lang.taxi_mission_completed, xpAwarded, capsAwarded, tipPercent), "success")
    cb(true)
end)

Framework.CreateCallback("bl_scav:server:GetHoboKingLeaderboard", function(source, cb)
    local leaderboard = Database.query("SELECT player_name, kill_count, date_achieved, time_survived FROM bl_scav_warden_leaderboard ORDER BY kill_count DESC LIMIT 10")
    cb(leaderboard or {})
end)

-- SECURITY: `killCount` and `timeSurvived` are client-reported and are written straight
-- to the public leaderboard. There is no way to fully verify them server-side without
-- simulating the whole gauntlet, so they are validated as integers and clamped to the
-- maximum values the challenge can physically produce. This turns "any client can post
-- an arbitrary world record" into "a cheater can at best claim a legitimate-looking
-- perfect run".
local MAX_GAUNTLET_KILLS = 500
local MAX_GAUNTLET_SECONDS = 60 * 60

RegisterNetEvent("bl_scav:server:RecordKingChallengeAttempt", function(killCount, timeSurvived)
    local player, playerId = Security.ResolvePlayer(source)
    if not player then
        return
    end

    if not Security.RateLimit(playerId, "recordGauntlet", 5000) then
        return
    end

    killCount = tonumber(killCount)
    timeSurvived = tonumber(timeSurvived)
    if not killCount or not timeSurvived then
        Security.Flag(playerId, "non-numeric gauntlet score")
        return
    end

    killCount = math.floor(killCount)
    timeSurvived = math.floor(timeSurvived)
    if killCount < 0 or timeSurvived < 0
        or killCount > MAX_GAUNTLET_KILLS or timeSurvived > MAX_GAUNTLET_SECONDS then
        Security.Flag(playerId, "implausible gauntlet score")
        return
    end

    local playerName = player.Name
    if not playerName then
        playerName = "Unknown Hobo"
    end

    local identifier = player.Identifier
    local minTopKillCount = Database.scalar("SELECT MIN(kill_count) FROM (SELECT kill_count FROM bl_scav_warden_leaderboard ORDER BY kill_count DESC LIMIT 10) as top10")

    if minTopKillCount == nil or killCount >= minTopKillCount then
        local existingRows = Database.query("SELECT kill_count FROM bl_scav_warden_leaderboard WHERE identifier = ?", {identifier})
        local existingRow = existingRows[1]

        if existingRow and not (killCount > existingRow.kill_count) then
            Framework.Notify(playerId, string.format(Config.Lang.challenge_complete_best, killCount, existingRows[1].kill_count), "info")
        else
            Database.query([[
                INSERT INTO bl_scav_warden_leaderboard (identifier, player_name, kill_count, date_achieved, time_survived)
                VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?)
                ON DUPLICATE KEY UPDATE
                kill_count = ?,
                player_name = ?,
                date_achieved = CURRENT_TIMESTAMP,
                time_survived = ?
            ]], {identifier, playerName, killCount, timeSurvived, killCount, playerName, timeSurvived})

            local newMaxKillCount = Database.scalar("SELECT MAX(kill_count) FROM bl_scav_warden_leaderboard")

            Database.query([[
                DELETE FROM bl_scav_warden_leaderboard
                WHERE identifier NOT IN (
                    SELECT identifier FROM (
                        SELECT identifier FROM bl_scav_warden_leaderboard
                        ORDER BY kill_count DESC LIMIT 10
                    ) as top10
                )
            ]])

            if newMaxKillCount == killCount then
                CrownStreetWarden(identifier)
                TriggerClientEvent("bl_scav:client:NewKing", -1, playerName)
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

RegisterNetEvent("bl_scav:server:RequestRoutingBucket", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    local bucketId = 10000 + playerId
    SetRoutingBucketPopulationEnabled(bucketId, false)
    SetPlayerRoutingBucket(playerId, bucketId)
    TriggerClientEvent("bl_scav:client:SetRoutingBucket", playerId, bucketId)
end)

RegisterNetEvent("bl_scav:server:ReturnToNormalBucket", function()
    local playerId = source
    local player = Framework.GetPlayer(playerId)
    if not player then
        return
    end

    SetPlayerRoutingBucket(playerId, 0)
end)

Framework.CreateCallback("bl_scav:server:IsHoboKing", function(source, cb)
    print("Checking if player is Hobo King...")

    local player = Framework.GetPlayer(source)
    if not player then
        print("Player not found, returning false")
        return cb(false)
    end

    print("Checking database for player identifier: " .. player.Identifier)

    local rows = Database.query("SELECT is_king FROM bl_scav_progression WHERE identifier = ?", {player.Identifier})
    if not (rows and #rows ~= 0) then
        print("No database entry found, returning false")
        return cb(false)
    end

    local isKing = rows[1].is_king
    print("Database returned is_king value: " .. tostring(isKing))
    cb(isKing)
end)
