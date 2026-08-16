--[[ ==========================================================================
     BlackLight Dumpsters — Chapter Callbacks & Throne Contests (server)
========================================================================== ]]

local random, floor, min = math.random, math.floor, math.min

local STANDING_TABLE = "bl_scavenger_standing"
local GAUNTLET_TABLE = "bl_gauntlet_board"

-- --------------------------------------------------------------------------
--  CHAPTER PROGRESS
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:GetChapterProgress", function(source, cb, chapterId)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb({})
    end

    cb(ReadChapterProgress(player.Identifier, chapterId))
end)

RegisterNetEvent("bl_dumpsters:server:PushChapterProgress", function(chapterId, data)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "chapter_progress", 500) then
        return
    end

    chapterId = GuardNumber(chapterId, 1, 11)
    if not chapterId or type(data) ~= "table" then
        return
    end

    PushChapterProgress(player.Identifier, chapterId, data)
end)

Framework.CreateCallback("bl_dumpsters:server:IsReclaimerUnlocked", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    if not Settings.ReclaimerBehaviour.chapterGated then
        return cb(true)
    end

    local chapterState = ReadChapterProgress(player.Identifier, 5)
    cb(chapterState.recycler_unlocked == true)
end)

-- --------------------------------------------------------------------------
--  BUYING YOUR WAY OUT
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:server:PurchaseExit", function()
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "purchase_exit", 3000) then
        return
    end

    local standing = FetchStanding(player.Identifier)
    if not (standing and standing.level >= 10) then
        Framework.Notify(playerSource, Settings.Text.exit_needs_rank_ten, "error")
        return
    end

    local price = Settings.Overseer.BuyoutPrice
    local currencyItem = Settings.CurrencyItem or "bottle_cap"

    if not GuardInventory(playerSource, currencyItem, price) then
        Framework.Notify(playerSource, Settings.Text.cant_afford_exit, "error")
        return
    end

    if not Framework.RemoveItem(playerSource, currencyItem, price) then
        Framework.Notify(playerSource, Settings.Text.cant_afford_exit, "error")
        return
    end

    Framework.Notify(playerSource, Settings.Text.exit_purchased, "success")
    Database.query(("DELETE FROM `%s` WHERE identifier = ?"):format(STANDING_TABLE), { player.Identifier })
    TriggerClientEvent("bl_dumpsters:client:DisbandRetinue", playerSource)

    -- Framework contract — SetJob is a core API.
    player.SetJob("unemployed", 0)
end)

-- --------------------------------------------------------------------------
--  CHAPTER 5 — SALVAGE RUN
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:server:TrackSalvageHaul", function(playerSource, amount, standing)
    local player = Framework.GetPlayer(playerSource)
    if not (player and standing and standing.level == 5) then
        return
    end

    local chapterState = standing.mission_data[5] or {}
    local collected = (chapterState.items_collected or 0) + amount
    chapterState.items_collected = collected

    PushChapterProgress(player.Identifier, 5, chapterState)
    Framework.Notify(playerSource, string.format(Settings.Text.salvage_progress, collected, Settings.Chapters[5].TargetSalvage), "info")

    if collected >= Settings.Chapters[5].TargetSalvage then
        CloseChapter(player.Identifier, 5)
        Framework.Notify(playerSource, Settings.Text.salvage_quota_met, "success")

        chapterState.recycler_unlocked = true
        PushChapterProgress(player.Identifier, 5, chapterState)
    end
end)

-- --------------------------------------------------------------------------
--  CHAPTER 8 — BANDIT BOND
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:IssueBanditTreats", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Settings.Text.profile_not_found)
    end

    if not GuardRate(source, "bandit_treats", 2000) then
        return cb(false, Settings.Text.chapter_not_ready)
    end

    local standing = FetchStanding(player.Identifier)
    if not (standing and standing.level == 8) then
        return cb(false, Settings.Text.chapter_not_ready)
    end

    local chapterState = standing.mission_data[8] or {}

    if chapterState.treats_received then
        return cb(false, Settings.Text.go_find_a_bandit)
    end

    Framework.AddItem(source, "racoon_treats", 5)
    chapterState.treats_received = true
    PushChapterProgress(player.Identifier, 8, chapterState)

    cb(true, Settings.Text.treats_handed_over)
end)

Framework.CreateCallback("bl_dumpsters:server:CoaxBandit", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Settings.Text.profile_not_found)
    end

    if not GuardRate(source, "coax_bandit", 2000) then
        return cb(false, Settings.Text.taming_failed)
    end

    if not GuardInventory(source, "racoon_treats", 1) then
        return cb(false, Settings.Text.treats_required)
    end

    Framework.RemoveItem(source, "racoon_treats", 1)

    -- Coin-flip odds of winning the bandit over.
    if random(1, 100) <= 50 then
        return cb(false, Settings.Text.taming_failed)
    end

    local standing = FetchStanding(player.Identifier)

    if standing and standing.level == 8 then
        local chapterState = standing.mission_data[8] or {}
        chapterState.raccoon_tamed = true

        PushChapterProgress(player.Identifier, 8, chapterState)
        CloseChapter(player.Identifier, 8)

        return cb(true, Settings.Text.taming_success_bonus)
    end

    cb(true, Settings.Text.taming_success)
end)

-- --------------------------------------------------------------------------
--  THE THRONE
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:ContestThrone", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Settings.Text.profile_not_found)
    end

    if not GuardRate(source, "contest_throne", 5000) then
        return cb(false, Settings.Text.throne_occupied)
    end

    local identifier = player.Identifier
    local standing = FetchStanding(identifier)

    if not (standing and standing.level >= 10) then
        return cb(false, Settings.Text.throne_needs_rank_ten)
    end

    local currentHolder = Database.scalar(("SELECT identifier FROM `%s` WHERE is_king = 1"):format(STANDING_TABLE))

    -- Third return value tells the client whether a gauntlet must be fought.
    -- (The original inferred this by substring-matching the message, which broke
    --  the moment the text was translated.)
    if not currentHolder then
        SeatOnThrone(identifier)
        return cb(true, Settings.Text.throne_vacant, false)
    end

    local holderDormant = Database.scalar(([[
        SELECT 1 FROM `%s`
        WHERE identifier = ? AND last_active < DATE_SUB(NOW(), INTERVAL ? DAY)
    ]]):format(STANDING_TABLE), { currentHolder, Settings.Overseer.DormancyDays })

    if holderDormant then
        SeatOnThrone(identifier)
        return cb(true, Settings.Text.throne_holder_dormant, false)
    end

    -- An active holder must be fought for the seat.
    local chapterState = standing.mission_data[11] or {}
    chapterState.king_fight_started = true
    PushChapterProgress(identifier, 11, chapterState)

    TriggerClientEvent("bl_dumpsters:client:LaunchGauntlet", source)
    cb(true, Settings.Text.gauntlet_underway, true)
end)

RegisterNetEvent("bl_dumpsters:server:ClaimThrone", function()
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "claim_throne", 5000) then
        return
    end

    local identifier = player.Identifier
    local standing = FetchStanding(identifier)

    if not (standing and standing.level >= 10) then
        return
    end

    local chapterState = standing.mission_data[11] or {}
    if not chapterState.king_fight_started then
        return
    end

    CloseChapter(identifier, 11)
    SeatOnThrone(identifier)
    Framework.Notify(playerSource, Settings.Text.throne_congratulations, "success")
end)

Framework.CreateCallback("bl_dumpsters:server:HoldsThrone", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    local isKing = Database.scalar(("SELECT is_king FROM `%s` WHERE identifier = ?"):format(STANDING_TABLE), { player.Identifier })

    cb(isKing == 1 or isKing == true)
end)

-- --------------------------------------------------------------------------
--  WEAPON UPGRADE
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:server:UpgradeStickToRatStick", function()
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "stick_upgrade", 2000) then
        return
    end

    if Framework.RemoveItem(playerSource, "WEAPON_HOBO_STICK", 1) then
        Framework.AddItem(playerSource, "WEAPON_HOBO_RATSTICK", 1)
    end
end)

-- --------------------------------------------------------------------------
--  CHAPTER 4 — DOWNHILL RUSH
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:server:CompleteDownhillRush", function()
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "downhill_rush", 5000) then
        return
    end

    local identifier = player.Identifier
    local standing = FetchStanding(identifier)

    if not (standing and standing.level == 4) then
        return
    end

    CloseChapter(identifier, 4)
    Framework.AddItem(playerSource, Settings.CurrencyItem or "bottle_cap", random(5, 15))
    GrantReputationXP(identifier, Settings.Reputation.ChapterXP[4] or 100)
    Framework.Notify(playerSource, Settings.Text.rush_chapter_cleared, "success")
end)

-- --------------------------------------------------------------------------
--  CHAPTER 9 — TROLLEY CAB
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:SettleCabRun", function(source, cb, tipPercent)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return cb(false)
    end

    if not GuardRate(playerSource, "settle_cab", 5000) then
        return cb(false)
    end

    tipPercent = GuardNumber(tipPercent, 0, 50) or random(10, 25)

    local identifier = player.Identifier
    local standing = FetchStanding(identifier)

    if not (standing and standing.level >= 9) then
        Framework.Notify(playerSource, Settings.Text.cab_needs_rank_nine, "error")
        return cb(false)
    end

    CloseChapter(identifier, 9)

    local xpGained = floor(Settings.Reputation.ChapterXP[9] or 200)
    local currencyGained = floor(25 * (1 + (min(tipPercent, 50) / 100)))

    GrantReputationXP(identifier, xpGained)
    Framework.AddItem(playerSource, Settings.CurrencyItem or "bottle_cap", currencyGained)
    Framework.Notify(playerSource, string.format(Settings.Text.cab_run_paid, xpGained, currencyGained, tipPercent), "success")

    cb(true)
end)

-- --------------------------------------------------------------------------
--  GAUNTLET LEADERBOARD
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:GetGauntletBoard", function(source, cb)
    local board = Database.query(([[
        SELECT player_name, kill_count, date_achieved, time_survived
        FROM `%s` ORDER BY kill_count DESC LIMIT 10
    ]]):format(GAUNTLET_TABLE))

    cb(board or {})
end)

RegisterNetEvent("bl_dumpsters:server:LogGauntletRun", function(takedowns, secondsSurvived)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "log_gauntlet", 3000) then
        return
    end

    -- Sanity bounds: 10 minutes of combat cannot plausibly exceed these.
    takedowns = GuardNumber(takedowns, 0, 2000)
    secondsSurvived = GuardNumber(secondsSurvived, 0, 3600)

    if not takedowns or not secondsSurvived then
        return
    end

    local identifier = player.Identifier
    local playerName = player.Name or "Unknown Scavenger"

    local lowestTopScore = Database.scalar(([[
        SELECT MIN(kill_count) FROM (
            SELECT kill_count FROM `%s` ORDER BY kill_count DESC LIMIT 10
        ) AS ranked
    ]]):format(GAUNTLET_TABLE))

    if lowestTopScore ~= nil and takedowns < lowestTopScore then
        Framework.Notify(playerSource, string.format(Settings.Text.gauntlet_unranked, takedowns), "info")
        return
    end

    local existing = Database.prepare(("SELECT kill_count FROM `%s` WHERE identifier = ?"):format(GAUNTLET_TABLE), { identifier })

    if existing and takedowns <= existing.kill_count then
        Framework.Notify(playerSource, string.format(Settings.Text.gauntlet_vs_personal, takedowns, existing.kill_count), "info")
        return
    end

    Database.query(([[
        INSERT INTO `%s` (identifier, player_name, kill_count, date_achieved, time_survived)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?)
        ON DUPLICATE KEY UPDATE
            kill_count = VALUES(kill_count),
            player_name = VALUES(player_name),
            date_achieved = CURRENT_TIMESTAMP,
            time_survived = VALUES(time_survived)
    ]]):format(GAUNTLET_TABLE), { identifier, playerName, takedowns, secondsSurvived })

    local topScore = Database.scalar(("SELECT MAX(kill_count) FROM `%s`"):format(GAUNTLET_TABLE))

    -- Trim the board back down to its top ten.
    Database.query(([[
        DELETE FROM `%s`
        WHERE identifier NOT IN (
            SELECT identifier FROM (
                SELECT identifier FROM `%s` ORDER BY kill_count DESC LIMIT 10
            ) AS ranked
        )
    ]]):format(GAUNTLET_TABLE, GAUNTLET_TABLE))

    if topScore == takedowns then
        SeatOnThrone(identifier)
        TriggerClientEvent("bl_dumpsters:client:ThroneAnnouncement", -1, playerName)
        Framework.Notify(playerSource, string.format(Settings.Text.throne_won_with_kills, takedowns), "success")
    else
        Framework.Notify(playerSource, string.format(Settings.Text.gauntlet_vs_record, takedowns, topScore), "success")
    end
end)

-- --------------------------------------------------------------------------
--  ROUTING BUCKETS (gauntlet instancing)
-- --------------------------------------------------------------------------

local BUCKET_BASE = 10000

RegisterNetEvent("bl_dumpsters:server:RequestPrivateBucket", function()
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "request_bucket", 3000) then
        return
    end

    local bucketId = BUCKET_BASE + playerSource
    SetRoutingBucketPopulationEnabled(bucketId, false)
    SetPlayerRoutingBucket(playerSource, bucketId)
    TriggerClientEvent("bl_dumpsters:client:AssignBucket", playerSource, bucketId)
end)

RegisterNetEvent("bl_dumpsters:server:RestoreDefaultBucket", function()
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    SetPlayerRoutingBucket(playerSource, 0)
end)

-- Safety net: never strand a disconnecting player in a private bucket.
AddEventHandler("playerDropped", function()
    local playerSource = source
    if GetPlayerRoutingBucket(playerSource) ~= 0 then
        SetPlayerRoutingBucket(playerSource, 0)
    end
end)
