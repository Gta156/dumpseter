--[[ ==========================================================================
     BlackLight Dumpsters — Trolley Derby Cups & Leaderboards (server)
========================================================================== ]]

local random, floor = math.random, math.floor

ActiveCups = {}

local RECORDS_TABLE = "bl_derby_records"
local BOARD_SIZE = 10

--- Confirms a venue name genuinely exists in config.
local function VenueExists(venueName)
    for _, venue in pairs(Settings.TrolleyDerby.Venues) do
        if venue.name == venueName then
            return venue
        end
    end
    return nil
end

--- Player display name, framework-agnostic.
local function DisplayName(player)
    if player.Firstname and player.Lastname then
        return player.Firstname .. " " .. player.Lastname
    end
    return player.Name or "Unknown Scavenger"
end

-- --------------------------------------------------------------------------
--  LEADERBOARD WRITES
-- --------------------------------------------------------------------------

--- Records a run on the venue leaderboard and returns the finishing position.
---@param cb function Called with (success, position)
local function RecordRun(identifier, displayName, venueName, metres, cb)
    Database.query(([[
        SELECT MIN(distance) AS min_distance, COUNT(*) AS entries
        FROM `%s` WHERE venue = ?
    ]]):format(RECORDS_TABLE), { venueName }, function(rows)
        local summary = rows and rows[1]
        local entries = (summary and summary.entries) or 0
        local weakest = (summary and summary.min_distance) or 0

        -- Board has room, or this run beats the weakest entry on it.
        if entries >= BOARD_SIZE and weakest >= metres then
            return cb(true, nil)
        end

        Database.query(([[
            INSERT INTO `%s` (identifier, venue, distance, name)
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE
                distance = IF(VALUES(distance) > distance, VALUES(distance), distance),
                name = IF(VALUES(distance) > distance, VALUES(name), name)
        ]]):format(RECORDS_TABLE), { identifier, venueName, metres, displayName })

        Database.query(([[
            SELECT COUNT(*) AS ahead FROM `%s` WHERE venue = ? AND distance > ?
        ]]):format(RECORDS_TABLE), { venueName, metres }, function(positionRows)
            local position = 1

            if positionRows and positionRows[1] then
                position = (positionRows[1].ahead or 0) + 1
            end

            -- Anything past the board size gets trimmed off again.
            if position > BOARD_SIZE then
                Database.query(("DELETE FROM `%s` WHERE venue = ? AND identifier = ?"):format(RECORDS_TABLE), { venueName, identifier })
            end

            cb(true, position)
        end)
    end)
end

-- --------------------------------------------------------------------------
--  CUP STATE
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:GetCupStatus", function(source, cb, venueName)
    local cup = ActiveCups[venueName]

    if not cup then
        return cb(nil, 0, nil)
    end

    cb(cup, cup.entryFee or 0, cup.status)
end)

Framework.CreateCallback("bl_dumpsters:server:BuyReplacementTrolley", function(source, cb, venueName, price)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Settings.Text.player_invalid)
    end

    if not GuardRate(source, "replacement_trolley", 2000) then
        return cb(false, Settings.Text.cant_afford_trolley)
    end

    local cup = ActiveCups[venueName]
    if not cup then
        return cb(false, Settings.Text.cup_missing)
    end

    price = GuardNumber(price, 0, 1000)
    if not price then
        return cb(false, Settings.Text.cant_afford_trolley)
    end

    local currencyItem = Settings.CurrencyItem or "bottle_cap"

    if not GuardInventory(source, currencyItem, price) then
        return cb(false, Settings.Text.cant_afford_trolley)
    end

    if not Framework.RemoveItem(source, currencyItem, price) then
        return cb(false, Settings.Text.cant_afford_trolley)
    end

    cb(true)
end)

Framework.CreateCallback("bl_dumpsters:server:JoinCup", function(source, cb, venueName, entryFee)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Settings.Text.player_invalid)
    end

    if not GuardRate(source, "join_cup", 2000) then
        return cb(false, Settings.Text.cup_already_entered)
    end

    local cup = ActiveCups[venueName]
    if not cup then
        return cb(false, Settings.Text.cup_missing)
    end

    if cup.status ~= "signup" then
        return cb(false, Settings.Text.cup_already_running)
    end

    local identifier = player.Identifier

    if cup.entrants[identifier] then
        return cb(false, Settings.Text.cup_already_entered)
    end

    -- The fee is taken from config, never from the client payload.
    local fee = cup.entryFee or 0
    local currencyItem = Settings.CurrencyItem or "bottle_cap"

    if fee > 0 then
        if not GuardInventory(source, currencyItem, fee) then
            return cb(false, Settings.Text.cant_afford_entry)
        end

        if not Framework.RemoveItem(source, currencyItem, fee) then
            return cb(false, Settings.Text.cant_afford_entry)
        end
    end

    cup.prizePool = (cup.prizePool or 0) + fee
    cup.entrants[identifier] = {
        name = DisplayName(player),
        bestDistance = 0,
        source = source,
    }

    cb(true)
end)

-- --------------------------------------------------------------------------
--  HOSTING A CUP
-- --------------------------------------------------------------------------

--- Broadcasts a countdown warning to everybody signed up.
local function BroadcastCountdown(venueName, minutesRemaining)
    local cup = ActiveCups[venueName]
    if not cup then
        return
    end

    for _, entrant in pairs(cup.entrants) do
        TriggerClientEvent("bl_dumpsters:client:CupCountdown", entrant.source, venueName, minutesRemaining)
    end
end

Framework.CreateCallback("bl_dumpsters:server:HostCup", function(source, cb, venueName, startsIn, duration, entryFee)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Settings.Text.player_invalid)
    end

    if not GuardRate(source, "host_cup", 5000) then
        return cb(false, Settings.Text.cup_already_exists)
    end

    local venue = VenueExists(venueName)
    if not venue then
        return cb(false, Settings.Text.cup_missing)
    end

    if ActiveCups[venueName] then
        return cb(false, Settings.Text.cup_already_exists)
    end

    startsIn = GuardNumber(startsIn, 1, 120)
    duration = GuardNumber(duration, 5, 60)
    entryFee = GuardNumber(entryFee, 0, 1000)

    if not (startsIn and duration and entryFee) then
        return cb(false, Settings.Text.player_invalid)
    end

    local currencyItem = Settings.CurrencyItem or "bottle_cap"

    if entryFee > 0 then
        if not GuardInventory(source, currencyItem, entryFee) then
            return cb(false, Settings.Text.cant_afford_entry)
        end

        if not Framework.RemoveItem(source, currencyItem, entryFee) then
            return cb(false, Settings.Text.cant_afford_entry)
        end
    end

    local identifier = player.Identifier
    local hostName = DisplayName(player)

    ActiveCups[venueName] = {
        hostIdentifier = identifier,
        hostName = hostName,
        venue = venueName,
        status = "signup",
        entryFee = entryFee,
        prizePool = entryFee,
        leader = {
            identifier = identifier,
            name = hostName,
            source = source,
            winnerDistance = 0,
        },
        entrants = {
            [identifier] = {
                name = hostName,
                bestDistance = 0,
                source = source,
            },
        },
    }

    cb(true)

    -- Countdown warnings at 10, 5 and 1 minutes out.
    for _, warning in ipairs({ 10, 5, 1 }) do
        if startsIn >= warning then
            SetTimeout((startsIn - warning) * 60000, function()
                BroadcastCountdown(venueName, warning)
            end)
        end
    end

    -- Cup goes live.
    SetTimeout(startsIn * 60000, function()
        local cup = ActiveCups[venueName]
        if not cup then
            return
        end

        cup.status = "active"

        -- Entrants receive the full venue definition so they can build the launch zone.
        for _, entrant in pairs(cup.entrants) do
            TriggerClientEvent("bl_dumpsters:client:CupUnderway", entrant.source, venue)
        end
    end)

    -- Cup concludes.
    SetTimeout((startsIn + duration) * 60000, function()
        local cup = ActiveCups[venueName]
        if not cup then
            return
        end

        cup.status = "finished"

        local leader = cup.leader

        for _, entrant in pairs(cup.entrants) do
            TriggerClientEvent("bl_dumpsters:client:CupConcluded", entrant.source, venueName, leader)
        end

        if leader and leader.source then
            Framework.Notify(leader.source, Settings.Text.cup_prize_claimed, "success")

            -- The house keeps a 10% cut of the pool.
            local prize = floor((cup.prizePool or 0) * 0.9)
            if prize > 0 then
                Framework.AddItem(leader.source, currencyItem, prize)
            end
        end

        local hostEntry = cup.entrants[cup.hostIdentifier]

        TriggerEvent("bl_dumpsters:server:CupWrapped", venueName, cup.entrants, {
            hostIdentifier = cup.hostIdentifier,
            hostSource = hostEntry and hostEntry.source,
        })

        ActiveCups[venueName] = nil
    end)
end)

-- --------------------------------------------------------------------------
--  SCORE SUBMISSION
-- --------------------------------------------------------------------------

--- Upper bound on a plausible single trolley run, to reject spoofed distances.
local MAX_PLAUSIBLE_METRES = 15000

Framework.CreateCallback("bl_dumpsters:server:SubmitRunScore", function(source, cb, metres, venueName)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    if not GuardRate(source, "submit_run", 2000) then
        return cb(false)
    end

    metres = GuardNumber(metres, 0, MAX_PLAUSIBLE_METRES)
    if not metres or not VenueExists(venueName) then
        return cb(false)
    end

    RecordRun(player.Identifier, DisplayName(player), venueName, metres, cb)
end)

Framework.CreateCallback("bl_dumpsters:server:SubmitCupScore", function(source, cb, metres, venueName)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    if not GuardRate(source, "submit_cup", 2000) then
        return cb(false)
    end

    metres = GuardNumber(metres, 0, MAX_PLAUSIBLE_METRES)
    if not metres or not VenueExists(venueName) then
        return cb(false)
    end

    local identifier = player.Identifier
    local displayName = DisplayName(player)

    RecordRun(identifier, displayName, venueName, metres, cb)

    -- Update the live cup standings.
    local cup = ActiveCups[venueName]
    if not cup then
        return
    end

    local entrant = cup.entrants[identifier]
    if not entrant or metres <= entrant.bestDistance then
        return
    end

    entrant.bestDistance = metres

    local tookTheLead = false
    if metres > cup.leader.winnerDistance then
        cup.leader = {
            identifier = identifier,
            name = displayName,
            source = source,
            winnerDistance = metres,
        }
        tookTheLead = true
    end

    TriggerClientEvent("bl_dumpsters:client:CupScoreLogged", source, metres, tookTheLead)
end)

-- --------------------------------------------------------------------------
--  LEADERBOARD READS
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:GetVenueLeaderboard", function(source, cb, venueName)
    Database.query(([[
        SELECT name, distance, created_at
        FROM `%s` WHERE venue = ?
        ORDER BY distance DESC LIMIT %d
    ]]):format(RECORDS_TABLE, BOARD_SIZE), { venueName }, function(rows)
        local board = {}

        -- Positions are numbered here rather than with a MySQL session variable,
        -- which keeps the query compatible with MySQL 8 and MariaDB alike.
        for index, row in ipairs(rows or {}) do
            board[index] = {
                position = index,
                name = row.name,
                distance = row.distance,
                created_at = row.created_at,
            }
        end

        cb(board)
    end)
end)

-- --------------------------------------------------------------------------
--  DIAGNOSTIC SEEDER
-- --------------------------------------------------------------------------

if Settings.DiagnosticMode then
    RegisterCommand("bl_seed_derby", function(source, args)
        local player = Framework.GetPlayer(source)
        if not player then
            return
        end

        local venueName = args[1] or "Downhill Trail"
        local baseline = tonumber(args[2]) or 5000
        local identifier = player.Identifier
        local displayName = DisplayName(player)

        for _ = 1, 10 do
            local metres = baseline + random(-100, 100) + (random(0, 100) / 100)
            RecordRun(identifier, displayName, venueName, metres, function() end)
        end
    end, false)
end
