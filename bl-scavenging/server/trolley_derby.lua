BLScav_LiveTournaments = {}

Framework.CreateCallback("bl_scav:getTournamentStatus", function(source, cb, trackName)
    local tournament = BLScav_LiveTournaments[trackName]
    if tournament then
        cb(tournament, tournament.buyIn or 0, tournament.status)
    else
        cb(nil, 0, nil)
    end
end)

Framework.CreateCallback("bl_scav:getNewCart", function(source, cb, trackName, capCost)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.invalid_player)
    end

    local tournament = BLScav_LiveTournaments[trackName]
    if not tournament then
        return cb(false, Config.Lang.no_tournament_found)
    end

    local capCount = Framework.GetItemCount(source, Config.CapCurrencyItem or "bottle_cap")
    if capCost > capCount then
        return cb(false, Config.Lang.not_enough_caps_new_cart)
    end

    local removed = Framework.RemoveItem(source, Config.CapCurrencyItem or "bottle_cap", capCost)
    if not removed then
        return cb(false, Config.Lang.not_enough_caps_new_cart)
    end

    cb(true)
end)

Framework.CreateCallback("bl_scav:joinTournament", function(source, cb, trackName, entryFee)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.invalid_player)
    end

    local tournament = BLScav_LiveTournaments[trackName]
    if tournament and tournament.status ~= "signup" then
        return cb(false, Config.Lang.tournament_already_started)
    end

    for _, playerEntry in pairs(BLScav_LiveTournaments[trackName].players) do
        if playerEntry.source == source then
            return cb(false, Config.Lang.already_in_tournament)
        end
    end

    if entryFee and entryFee > 0 then
        local capCount = Framework.GetItemCount(source, Config.CapCurrencyItem or "bottle_cap")
        if entryFee > capCount then
            return cb(false, Config.Lang.not_enough_caps_buyin)
        end

        local removed = Framework.RemoveItem(source, Config.CapCurrencyItem or "bottle_cap", entryFee)
        if not removed then
            return cb(false, Config.Lang.not_enough_caps_buyin)
        end
    end

    local identifier = player.Identifier
    local fullName = player.Firstname .. " " .. player.Lastname

    if BLScav_LiveTournaments[trackName].prizePool then
        BLScav_LiveTournaments[trackName].prizePool = BLScav_LiveTournaments[trackName].prizePool + (entryFee or 0)
    else
        BLScav_LiveTournaments[trackName].prizePool = entryFee or 0
    end

    BLScav_LiveTournaments[trackName].players[identifier] = {
        name = fullName,
        bestDistance = 0,
        source = source,
    }

    cb(true)
end)

Framework.CreateCallback("bl_scav:hostTournament", function(source, cb, startsIn, track, duration, entryFee)
    local trackName = track.name

    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.invalid_player)
    end

    if BLScav_LiveTournaments[trackName] then
        return cb(false, Config.Lang.tournament_already_exists)
    end

    if entryFee and entryFee > 0 then
        local capCount = Framework.GetItemCount(source, Config.CapCurrencyItem or "bottle_cap")
        if entryFee > capCount then
            return cb(false, Config.Lang.not_enough_caps_buyin)
        end

        local removed = Framework.RemoveItem(source, Config.CapCurrencyItem or "bottle_cap", entryFee)
        if not removed then
            return cb(false, Config.Lang.not_enough_caps_buyin)
        end
    end

    local identifier = player.Identifier
    local fullName = player.Firstname .. " " .. player.Lastname

    BLScav_LiveTournaments[trackName] = {
        host_identifier = identifier,
        host_name = fullName,
        track = trackName,
        status = "signup",
        buyIn = entryFee or 0,
        prizePool = (entryFee or 0) * 0.9,
        currentWinner = {
            identifier = identifier,
            name = fullName,
            source = source,
            winnerDistance = 0,
        },
        players = {
            [identifier] = {
                name = fullName,
                bestDistance = 0,
                source = source,
            },
        },
    }

    cb(true)

    if startsIn >= 10 then
        SetTimeout((startsIn - 10) * 60000, function()
            local tournament = BLScav_LiveTournaments[trackName]
            if tournament then
                local players = BLScav_LiveTournaments[trackName].players
                if players then
                    for _, playerEntry in pairs(BLScav_LiveTournaments[trackName].players) do
                        TriggerClientEvent("bl_scav:tournamentStarting", playerEntry.source, trackName, 10)
                    end
                end
            end
        end)
    end

    if startsIn >= 5 then
        SetTimeout((startsIn - 5) * 60000, function()
            local tournament = BLScav_LiveTournaments[trackName]
            if tournament then
                local players = BLScav_LiveTournaments[trackName].players
                if players then
                    for _, playerEntry in pairs(BLScav_LiveTournaments[trackName].players) do
                        TriggerClientEvent("bl_scav:tournamentStarting", playerEntry.source, trackName, 5)
                    end
                end
            end
        end)
    end

    if startsIn >= 1 then
        SetTimeout((startsIn - 1) * 60000, function()
            local tournament = BLScav_LiveTournaments[trackName]
            if tournament then
                local players = BLScav_LiveTournaments[trackName].players
                if players then
                    for _, playerEntry in pairs(BLScav_LiveTournaments[trackName].players) do
                        -- NOTE: original sends the full `track` table here instead of `trackName`
                        -- like the 10/5 minute warnings above (preserved as-is).
                        TriggerClientEvent("bl_scav:tournamentStarting", playerEntry.source, track, 1)
                    end
                end
            end
        end)
    end

    SetTimeout(startsIn * 60000, function()
        local tournament = BLScav_LiveTournaments[trackName]
        if tournament then
            BLScav_LiveTournaments[trackName].status = "active"

            local players = BLScav_LiveTournaments[trackName].players
            if players then
                for _, playerEntry in pairs(BLScav_LiveTournaments[trackName].players) do
                    -- NOTE: original sends the full `track` table here instead of `trackName` (preserved as-is).
                    TriggerClientEvent("bl_scav:tournamentStarted", playerEntry.source, track)
                end
            end
        end
    end)

    SetTimeout((startsIn + duration) * 60000, function()
        local tournament = BLScav_LiveTournaments[trackName]
        if tournament then
            BLScav_LiveTournaments[trackName].status = "finished"

            local players = BLScav_LiveTournaments[trackName].players
            if players then
                local currentWinner = BLScav_LiveTournaments[trackName].currentWinner

                for _, playerEntry in pairs(BLScav_LiveTournaments[trackName].players) do
                    TriggerClientEvent("bl_scav:tournamentFinished", playerEntry.source, trackName, currentWinner)
                end

                if currentWinner then
                    Framework.Notify(currentWinner.source, Config.Lang.tournament_won, "success")

                    local rewardPot = BLScav_LiveTournaments[trackName].prizePool
                    if rewardPot then
                        if BLScav_LiveTournaments[trackName].prizePool > 0 then
                            Framework.AddItem(currentWinner.source, Config.CapCurrencyItem or "bottle_cap", BLScav_LiveTournaments[trackName].prizePool)
                        end
                    end
                end

                TriggerEvent("bl_scav:derby:tournamentFinished", trackName, BLScav_LiveTournaments[trackName].players, {
                    hostIdentifier = BLScav_LiveTournaments[trackName].host_identifier,
                    hostSource = BLScav_LiveTournaments[trackName].players[BLScav_LiveTournaments[trackName].host_identifier].source,
                })

                BLScav_LiveTournaments[trackName] = nil
            end
        end
    end)
end)

-- ---------------------------------------------------------------------------
--  Leaderboard input validation
-- ---------------------------------------------------------------------------
-- SECURITY: derby distances and track names arrive from the client and are written
-- straight into the public leaderboard table. A distance cannot be proven server-side
-- without simulating the ride, so it is validated as a finite number and clamped to the
-- longest run the physics can realistically produce. The track name is checked against
-- the configured track list, which also prevents unbounded strings reaching the database.
local MAX_DERBY_DISTANCE = 5000.0

--- @return number|nil distance, string|nil track
local function ValidateDerbySubmission(src, distance, track)
    distance = tonumber(distance)
    if not distance or distance ~= distance or distance <= 0 or distance > MAX_DERBY_DISTANCE then
        Security.Flag(src, "implausible derby distance")
        return nil
    end

    if type(track) ~= "string" or #track == 0 or #track > 100 then
        Security.Flag(src, "malformed derby track name")
        return nil
    end

    -- Confirm the track actually exists in the config.
    local known = false
    for _, candidate in ipairs(Config.TrolleyDerby and Config.TrolleyDerby.Tracks or {}) do
        if candidate.name == track then
            known = true
            break
        end
    end
    if not known then
        Security.Flag(src, "derby submission for an unknown track")
        return nil
    end

    return math.floor(distance * 100) / 100, track
end

Framework.CreateCallback("bl_scav:derbyScore", function(source, cb, distance, track)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return cb(false)
    end

    if not Security.RateLimit(src, "derbyScore", 2000) then
        return cb(false)
    end

    distance, track = ValidateDerbySubmission(src, distance, track)
    if not distance then
        return cb(false)
    end

    local identifier = player.Identifier
    local fullName = player.Firstname .. " " .. player.Lastname

    Database.query("SELECT MIN(distance) as min_distance, COUNT(*) as count FROM bl_scav_derby_leaderboards WHERE track = ? ORDER BY distance DESC LIMIT 10", { track }, function(rows)
        if rows and #rows ~= 0 then
            local count = rows[1].count or 0
            local minDistance = rows[1].min_distance or 0

            if count < 10 or minDistance < distance then
                Database.query(
                    "INSERT INTO bl_scav_derby_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE distance = IF(? > distance, ?, distance), name = IF(? > distance, ?, name)",
                    { identifier, track, distance, fullName, distance, distance, distance, fullName }
                )

                if count >= 10 then
                    Database.query("DELETE FROM bl_scav_derby_leaderboards WHERE track = ? AND distance < ? ORDER BY distance ASC LIMIT 1", { track, distance })
                end

                Database.query("SELECT COUNT(*) as position FROM bl_scav_derby_leaderboards WHERE track = ? AND distance > ?", { track, distance }, function(rows2)
                    if rows2 and #rows2 ~= 0 then
                        local position = rows2[1].position + 1
                        if position > 10 then
                            Database.query("DELETE FROM bl_scav_derby_leaderboards WHERE track = ? AND identifier = ?", { track, identifier })
                        end
                        cb(true, position)
                    else
                        cb(true, 1)
                    end
                end)
            else
                cb(true, "10+")
            end
        else
            Database.query("INSERT INTO bl_scav_derby_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?)", { identifier, track, distance, fullName })
            cb(true, 1)
        end
    end)
end)

Framework.CreateCallback("bl_scav:derbyScoreTournament", function(source, cb, distance, track)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return cb(false)
    end

    if not Security.RateLimit(src, "derbyScore", 2000) then
        return cb(false)
    end

    distance, track = ValidateDerbySubmission(src, distance, track)
    if not distance then
        return cb(false)
    end

    local identifier = player.Identifier
    local fullName = player.Firstname .. " " .. player.Lastname

    Database.query("SELECT MIN(distance) as min_distance, COUNT(*) as count FROM bl_scav_derby_leaderboards WHERE track = ? ORDER BY distance DESC LIMIT 10", { track }, function(rows)
        if rows and #rows ~= 0 then
            local count = rows[1].count or 0
            local minDistance = rows[1].min_distance or 0

            if count < 10 or minDistance < distance then
                Database.query(
                    "INSERT INTO bl_scav_derby_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE distance = IF(? > distance, ?, distance), name = IF(? > distance, ?, name)",
                    { identifier, track, distance, fullName, distance, distance, distance, fullName }
                )

                if count >= 10 then
                    Database.query("DELETE FROM bl_scav_derby_leaderboards WHERE track = ? AND distance < ? ORDER BY distance ASC LIMIT 1", { track, distance })
                end

                Database.query("SELECT COUNT(*) as position FROM bl_scav_derby_leaderboards WHERE track = ? AND distance > ?", { track, distance }, function(rows2)
                    if rows2 and #rows2 ~= 0 then
                        local position = rows2[1].position + 1
                        if position > 10 then
                            Database.query("DELETE FROM bl_scav_derby_leaderboards WHERE track = ? AND identifier = ?", { track, identifier })
                        end
                        cb(true, position)
                    else
                        cb(true, 1)
                    end
                end)
            else
                cb(true, nil)
            end
        else
            Database.query("INSERT INTO bl_scav_derby_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?)", { identifier, track, distance, fullName })
            cb(true, 1)
        end
    end)

    local tournament = BLScav_LiveTournaments[track]
    if tournament then
        local isNewWinner = false

        if distance > BLScav_LiveTournaments[track].players[identifier].bestDistance then
            BLScav_LiveTournaments[track].players[identifier].bestDistance = distance

            if distance > BLScav_LiveTournaments[track].currentWinner.winnerDistance then
                BLScav_LiveTournaments[track].currentWinner = {
                    identifier = identifier,
                    name = fullName,
                    source = source,
                    winnerDistance = distance,
                }
                isNewWinner = true
            end

            TriggerClientEvent("bl_scav:tournamentScoreUpdated", source, distance, isNewWinner)
        end
    end
end)

Framework.CreateCallback("bl_scav:getLeaderboard", function(source, cb, track)
    Database.query(
        "SELECT name, distance, created_at, (@row_number:=@row_number + 1) AS position FROM bl_scav_derby_leaderboards, (SELECT @row_number:=0) AS r WHERE track = ? ORDER BY distance DESC LIMIT 10",
        { track },
        function(rows)
            cb(rows or {})
        end
    )
end)

if Config.DiagnosticsEnabled then
    RegisterCommand("add10DerbyMockData", function(source, args)
        local player = Framework.GetPlayer(source)
        if not player then
            return
        end

        local identifier = player.Identifier
        local track = args[1] or "Downhill Trail"
        local baseDistance = tonumber(args[2]) or 5000
        local fullName = player.Firstname .. " " .. player.Lastname

        for i = 1, 10, 1 do
            local distance = baseDistance + math.random(-100, 100)
            distance = distance + math.random(0, 100) / 100

            Database.query("SELECT MIN(distance) as min_distance, COUNT(*) as count FROM bl_scav_derby_leaderboards WHERE track = ? ORDER BY distance DESC LIMIT 10", { track }, function(rows)
                if rows and #rows ~= 0 then
                    local count = rows[1].count or 0
                    local minDistance = rows[1].min_distance or 0

                    if count < 10 or minDistance < distance then
                        Database.query(
                            "INSERT INTO bl_scav_derby_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE distance = IF(? > distance, ?, distance), name = IF(? > distance, ?, name)",
                            { identifier, track, distance, fullName, distance, distance, distance, fullName }
                        )

                        if count >= 10 then
                            Database.query("DELETE FROM bl_scav_derby_leaderboards WHERE track = ? AND distance < ? ORDER BY distance ASC LIMIT 1", { track, distance })
                        end

                        Database.query("SELECT COUNT(*) as position FROM bl_scav_derby_leaderboards WHERE track = ? AND distance > ?", { track, distance }, function(rows2)
                            if rows2 and #rows2 ~= 0 then
                                local position = rows2[1].position + 1
                                if position > 10 then
                                    Database.query("DELETE FROM bl_scav_derby_leaderboards WHERE track = ? AND identifier = ?", { track, identifier })
                                end
                            end
                        end)
                    else
                        return
                    end
                else
                    Database.query("INSERT INTO bl_scav_derby_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?)", { identifier, track, distance, fullName })
                end
            end)
        end
    end, false)
end
