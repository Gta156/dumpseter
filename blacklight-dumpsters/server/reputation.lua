--[[ ==========================================================================
     BlackLight Dumpsters — Reputation Core (server)
     Ranks, XP, chapter state, tithing and the throne.
========================================================================== ]]

local STANDING_TABLE = "bl_scavenger_standing"

-- --------------------------------------------------------------------------
--  STANDING RECORDS
-- --------------------------------------------------------------------------

--- Fetches (or lazily creates) a scavenger's standing record.
---@param identifier string
---@return table standing
function FetchStanding(identifier)
    local row = Database.prepare(("SELECT * FROM `%s` WHERE identifier = ?"):format(STANDING_TABLE), { identifier })

    if not row then
        Database.query(("INSERT INTO `%s` (identifier, mission_data, last_active) VALUES (?, ?, NOW())"):format(STANDING_TABLE), {
            identifier, "{}",
        })

        return {
            identifier = identifier,
            level = 1,
            xp = 0,
            mission_data = {},
            is_king = false,
            king_since = nil,
            last_active = os.time(),
            donated_drugs = 0,
            true_hobo = false,
        }
    end

    Database.query(("UPDATE `%s` SET last_active = NOW() WHERE identifier = ?"):format(STANDING_TABLE), { identifier })

    row.mission_data = (row.mission_data and json.decode(row.mission_data)) or {}

    return row
end

--- Persists a standing record back to the database.
function PersistStanding(identifier, standing)
    Database.query(([[
        UPDATE `%s`
        SET level = ?, xp = ?, mission_data = ?, is_king = ?, last_active = NOW(), donated_drugs = ?, true_hobo = ?
        WHERE identifier = ?
    ]]):format(STANDING_TABLE), {
        standing.level,
        standing.xp,
        json.encode(standing.mission_data or {}),
        standing.is_king and 1 or 0,
        standing.donated_drugs or 0,
        standing.true_hobo and 1 or 0,
        identifier,
    })

    if Settings.DiagnosticMode then
        print(("[^3BlackLight^7] Standing saved for %s — Rank %s, %s XP"):format(identifier, standing.level or 1, standing.xp or 0))
    end
end

--- Grants XP and returns the updated standing snapshot.
function GrantReputationXP(identifier, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return FetchStanding(identifier)
    end

    local standing = FetchStanding(identifier)
    local previousXP = tonumber(standing.xp) or 0

    standing.xp = previousXP + amount

    if Settings.DiagnosticMode then
        print(("[^3BlackLight^7] +%s XP for %s (%s -> %s)"):format(amount, identifier, previousXP, standing.xp))
    end

    PersistStanding(identifier, standing)

    return standing
end

-- --------------------------------------------------------------------------
--  COMMITTED SCAVENGER (job assignment)
-- --------------------------------------------------------------------------

local lastCommitmentReminder = {}
local REMINDER_GAP_MS = 1000

--- Ensures a committed scavenger keeps the street-dweller job.
function EnforceScavengerJob(identifier, playerSource)
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    local standing = FetchStanding(identifier)
    local committed = standing.true_hobo == 1 or standing.true_hobo == true

    if not committed then
        return
    end

    local now = GetGameTimer()
    if not lastCommitmentReminder[identifier] or (now - lastCommitmentReminder[identifier]) > REMINDER_GAP_MS then
        Framework.Notify(playerSource, Settings.Text.commitment_reminder, "success")
        lastCommitmentReminder[identifier] = now
    end

    -- Framework contract — SetJob is a core API.
    player.SetJob(Settings.VagrantJobName, 0)
end

local function MarkAsCommitted(identifier, playerSource)
    local standing = FetchStanding(identifier)
    standing.true_hobo = true
    PersistStanding(identifier, standing)
    EnforceScavengerJob(identifier, playerSource)
end

--- Attempts to promote a scavenger to the next rank.
local function TryAdvanceRank(identifier, playerSource)
    local standing = FetchStanding(identifier)
    local nextRank = standing.level + 1

    if nextRank <= 10 then
        local requiredXP = Settings.Reputation.RankThresholds[nextRank]
        local chapterState = standing.mission_data[standing.level] or standing.mission_data[tostring(standing.level)]

        if standing.xp >= requiredXP and chapterState and chapterState.completed then
            standing.level = nextRank

            if playerSource then
                TriggerClientEvent("bl_dumpsters:client:RankGained", playerSource, nextRank)
            end
        end
    end

    PersistStanding(identifier, standing)

    -- Reaching rank 5 makes the commitment permanent.
    if standing.level >= 5 then
        MarkAsCommitted(identifier, playerSource)
    end

    return standing
end

-- --------------------------------------------------------------------------
--  CHAPTER STATE
-- --------------------------------------------------------------------------

function ChapterNameForRank(rank)
    return Settings.Chapters[rank] and Settings.Chapters[rank].name or nil
end

--- Marks a chapter complete and pays out its XP.
function CloseChapter(identifier, chapterId, playerSource)
    local xpReward = Settings.Reputation.ChapterXP[chapterId]
    if xpReward then
        if Settings.DiagnosticMode then
            print(("[^3BlackLight^7] Chapter %s XP payout: %s"):format(chapterId, xpReward))
        end
        GrantReputationXP(identifier, xpReward)
    end

    local standing = FetchStanding(identifier)

    if Settings.DiagnosticMode then
        print(("[^3BlackLight^7] Closing chapter %s for %s"):format(chapterId, identifier))
    end

    standing.mission_data[chapterId] = standing.mission_data[chapterId] or {}

    if standing.mission_data[chapterId].completed then
        return standing
    end

    standing.mission_data[chapterId].completed = true
    PersistStanding(identifier, standing)

    return standing
end

--- Merges partial progress into a chapter's state and auto-closes when met.
function PushChapterProgress(identifier, chapterId, data)
    local standing = FetchStanding(identifier)
    standing.mission_data[chapterId] = standing.mission_data[chapterId] or {}

    for key, value in pairs(data or {}) do
        standing.mission_data[chapterId][key] = value
    end

    local chapterState = standing.mission_data[chapterId]

    -- Chapter 1 closes once all five districts have been visited.
    if chapterId == 1 then
        if chapterState.zone_1_visited and chapterState.zone_2_visited and chapterState.zone_3_visited
            and chapterState.zone_4_visited and chapterState.zone_5_visited then
            PersistStanding(identifier, standing)
            return CloseChapter(identifier, chapterId)
        end
    end

    -- Chapter 2 closes once all three nests are cleared.
    if chapterId == 2 then
        local cleared = chapterState.cleared_list or {}
        if cleared[1] and cleared[2] and cleared[3] then
            PersistStanding(identifier, standing)
            return CloseChapter(identifier, chapterId)
        end
    end

    -- Chapter 7 closes the moment the rival is beaten.
    if chapterId == 7 and chapterState.rival_defeated then
        PersistStanding(identifier, standing)
        return CloseChapter(identifier, chapterId)
    end

    PersistStanding(identifier, standing)

    return standing
end

--- Returns the stored state for a single chapter.
function ReadChapterProgress(identifier, chapterId)
    local standing = FetchStanding(identifier)
    return standing.mission_data[chapterId] or {}
end

-- --------------------------------------------------------------------------
--  TITHING
-- --------------------------------------------------------------------------

--- Converts contraband into XP. Once per in-game day.
function TitheContraband(identifier, contrabandType, quantity, playerSource)
    local standing = FetchStanding(identifier)

    if standing.donated_drugs == 1 then
        return false, Settings.Text.contraband_daily_limit
    end

    local contrabandConfig = Settings.Reputation.ContrabandXP[contrabandType]
    if not contrabandConfig then
        return false, Settings.Text.contraband_unknown
    end

    local xpAmount = contrabandConfig.xp * quantity

    standing.donated_drugs = 1
    PersistStanding(identifier, standing)

    GrantReputationXP(identifier, xpAmount)

    return true, string.format(Settings.Text.tithe_acknowledged, xpAmount)
end

--- Converts currency items into XP.
function TitheCurrency(identifier, quantity, playerSource)
    quantity = tonumber(quantity)
    if not quantity or quantity < 1 then
        return false, Settings.Text.currency_short
    end

    local held = Framework.GetItemCount(playerSource, Settings.CurrencyItem or "bottle_cap")
    if quantity > held then
        return false, Settings.Text.currency_short
    end

    local removed = Framework.RemoveItem(playerSource, Settings.CurrencyItem or "bottle_cap", quantity)
    if not removed then
        return false, Settings.Text.currency_removal_failed
    end

    local xpAmount = quantity * Settings.Reputation.XPPerCurrencyTithed
    GrantReputationXP(identifier, xpAmount)

    return true, string.format(Settings.Text.currency_converted, quantity, xpAmount)
end

-- --------------------------------------------------------------------------
--  THE THRONE
-- --------------------------------------------------------------------------

--- Seats a scavenger on the throne, unseating a dormant holder if needed.
function SeatOnThrone(identifier)
    local currentHolder = Database.scalar(("SELECT identifier FROM `%s` WHERE is_king = 1"):format(STANDING_TABLE))

    if currentHolder then
        local holderDormant = Database.scalar(([[
            SELECT 1 FROM `%s`
            WHERE identifier = ? AND last_active < DATE_SUB(NOW(), INTERVAL ? DAY)
        ]]):format(STANDING_TABLE), { currentHolder, Settings.Overseer.DormancyDays })

        if not holderDormant then
            return false, Settings.Text.throne_occupied
        end

        Database.query(("UPDATE `%s` SET is_king = 0 WHERE identifier = ?"):format(STANDING_TABLE), { currentHolder })
    end

    Database.query(("UPDATE `%s` SET is_king = 1, king_since = NOW() WHERE identifier = ?"):format(STANDING_TABLE), { identifier })

    local record = Framework.GetPlayerByIdentifier(identifier)
    local playerSource = record and record.source
    local player = playerSource and Framework.GetPlayer(playerSource)

    if player then
        Framework.AddItem(playerSource, "hobo_crown", 1)
        TriggerClientEvent("bl_dumpsters:client:ThroneAnnouncement", -1, player.Name)
    end

    return true, Settings.Text.throne_is_yours
end

-- --------------------------------------------------------------------------
--  EXPORTS (public API for other resources)
-- --------------------------------------------------------------------------

exports("FetchStanding", FetchStanding)
exports("GrantReputationXP", GrantReputationXP)
exports("CloseChapter", CloseChapter)
exports("PushChapterProgress", PushChapterProgress)
exports("ReadChapterProgress", ReadChapterProgress)
exports("TitheCurrency", TitheCurrency)
exports("TitheContraband", TitheContraband)

-- --------------------------------------------------------------------------
--  CALLBACKS
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:GetStanding", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(nil)
    end

    cb(FetchStanding(player.Identifier))
end)

Framework.CreateCallback("bl_dumpsters:server:TitheCurrency", function(source, cb, quantity)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Settings.Text.profile_not_found)
    end

    if not GuardRate(source, "tithe", 1000) then
        return cb(false, Settings.Text.currency_short)
    end

    local success, message = TitheCurrency(player.Identifier, quantity, source)
    cb(success, message)
end)

Framework.CreateCallback("bl_dumpsters:server:TitheContraband", function(source, cb, contrabandType, quantity)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Settings.Text.profile_not_found)
    end

    if not GuardRate(source, "tithe", 1000) then
        return cb(false, Settings.Text.contraband_short)
    end

    local contrabandConfig = Settings.Reputation.ContrabandXP[contrabandType]
    if not contrabandConfig then
        return cb(false, Settings.Text.contraband_unknown)
    end

    quantity = tonumber(quantity)
    if not quantity or quantity < 1 or quantity > 10 then
        return cb(false, Settings.Text.contraband_unknown)
    end

    local held = Framework.GetItemCount(source, contrabandType)
    if quantity > held then
        return cb(false, string.format(Settings.Text.contraband_short, contrabandConfig.label))
    end

    Framework.RemoveItem(source, contrabandType, quantity)

    local success, message = TitheContraband(player.Identifier, contrabandType, quantity, source)
    cb(success, message)
end)

Framework.CreateCallback("bl_dumpsters:server:IsCommittedScavenger", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    local standing = FetchStanding(player.Identifier)
    local committed = standing.true_hobo == 1 or standing.true_hobo == true

    if committed then
        EnforceScavengerJob(player.Identifier, source)
    end

    cb(committed)
end)

-- --------------------------------------------------------------------------
--  EVENTS
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:server:AdvanceRank", function()
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "advance_rank", 2000) then
        return
    end

    TryAdvanceRank(player.Identifier, playerSource)
end)

Framework.OnPlayerLoaded = function(playerSource)
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    EnforceScavengerJob(player.Identifier, playerSource)
end

-- --------------------------------------------------------------------------
--  DIAGNOSTIC COMMANDS
-- --------------------------------------------------------------------------

if Settings.DiagnosticMode then
    RegisterCommand("bl_setrank", function(source, args)
        local player = Framework.GetPlayer(source)
        if not player then
            return
        end

        local rank = tonumber(args[1])
        if not rank or rank < 1 or rank > 10 then
            Framework.Notify(source, Settings.Text.rank_range_error, "error")
            return
        end

        local standing = FetchStanding(player.Identifier)
        standing.level = rank
        standing.xp = rank > 1 and Settings.Reputation.RankThresholds[rank] or 0

        if rank >= 5 then
            standing.true_hobo = true
        end

        PersistStanding(player.Identifier, standing)
        Framework.Notify(source, string.format(Settings.Text.rank_forced, rank), "success")
    end, false)
end
