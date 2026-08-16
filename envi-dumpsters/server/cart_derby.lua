ActiveTournaments = {}

Framework.CreateCallback("envi-dumpsters:getTournamentStatus", function(source, cb, trackName)
    local tournament = ActiveTournaments[trackName]
    if tournament then
        cb(tournament, tournament.buyIn or 0, tournament.status)
    else
        cb(nil, 0, nil)
    end
end)

Framework.CreateCallback("envi-dumpsters:getNewCart", function(source, cb, trackName, capCost)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.invalid_player)
    end

    local tournament = ActiveTournaments[trackName]
    if not tournament then
        return cb(false, Config.Lang.no_tournament_found)
    end

    local capCount = Framework.GetItemCount(source, Config.BottleCapItem or "bottle_cap")
    if capCost > capCount then
        return cb(false, Config.Lang.not_enough_caps_new_cart)
    end

    local removed = Framework.RemoveItem(source, Config.BottleCapItem or "bottle_cap", capCost)
    if not removed then
        return cb(false, Config.Lang.not_enough_caps_new_cart)
    end

    cb(true)
end)

Framework.CreateCallback("envi-dumpsters:joinTournament", function(source, cb, trackName, buyIn)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.invalid_player)
    end

    local tournament = ActiveTournaments[trackName]
    if tournament and tournament.status ~= "signup" then
        return cb(false, Config.Lang.tournament_already_started)
    end

    for _, playerEntry in pairs(ActiveTournaments[trackName].players) do
        if playerEntry.source == source then
            return cb(false, Config.Lang.already_in_tournament)
        end
    end

    if buyIn and buyIn > 0 then
        local capCount = Framework.GetItemCount(source, Config.BottleCapItem or "bottle_cap")
        if buyIn > capCount then
            return cb(false, Config.Lang.not_enough_caps_buyin)
        end

        local removed = Framework.RemoveItem(source, Config.BottleCapItem or "bottle_cap", buyIn)
        if not removed then
            return cb(false, Config.Lang.not_enough_caps_buyin)
        end
    end

    local identifier = player.Identifier
    local fullName = player.Firstname .. " " .. player.Lastname

    if ActiveTournaments[trackName].prizePool then
        ActiveTournaments[trackName].prizePool = ActiveTournaments[trackName].prizePool + (buyIn or 0)
    else
        ActiveTournaments[trackName].prizePool = buyIn or 0
    end

    ActiveTournaments[trackName].players[identifier] = {
        name = fullName,
        bestDistance = 0,
        source = source,
    }

    cb(true)
end)

Framework.CreateCallback("envi-dumpsters:hostTournament", function(source, cb, startsIn, track, duration, buyIn)
    local trackName = track.name

    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.invalid_player)
    end

    if ActiveTournaments[trackName] then
        return cb(false, Config.Lang.tournament_already_exists)
    end

    if buyIn and buyIn > 0 then
        local capCount = Framework.GetItemCount(source, Config.BottleCapItem or "bottle_cap")
        if buyIn > capCount then
            return cb(false, Config.Lang.not_enough_caps_buyin)
        end

        local removed = Framework.RemoveItem(source, Config.BottleCapItem or "bottle_cap", buyIn)
        if not removed then
            return cb(false, Config.Lang.not_enough_caps_buyin)
        end
    end

    local identifier = player.Identifier
    local fullName = player.Firstname .. " " .. player.Lastname

    ActiveTournaments[trackName] = {
        host_identifier = identifier,
        host_name = fullName,
        track = trackName,
        status = "signup",
        buyIn = buyIn or 0,
        prizePool = (buyIn or 0) * 0.9,
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
            local tournament = ActiveTournaments[trackName]
            if tournament then
                local players = ActiveTournaments[trackName].players
                if players then
                    for _, playerEntry in pairs(ActiveTournaments[trackName].players) do
                        TriggerClientEvent("envi-dumpsters:tournamentStarting", playerEntry.source, trackName, 10)
                    end
                end
            end
        end)
    end

    if startsIn >= 5 then
        SetTimeout((startsIn - 5) * 60000, function()
            local tournament = ActiveTournaments[trackName]
            if tournament then
                local players = ActiveTournaments[trackName].players
                if players then
                    for _, playerEntry in pairs(ActiveTournaments[trackName].players) do
                        TriggerClientEvent("envi-dumpsters:tournamentStarting", playerEntry.source, trackName, 5)
                    end
                end
            end
        end)
    end

    if startsIn >= 1 then
        SetTimeout((startsIn - 1) * 60000, function()
            local tournament = ActiveTournaments[trackName]
            if tournament then
                local players = ActiveTournaments[trackName].players
                if players then
                    for _, playerEntry in pairs(ActiveTournaments[trackName].players) do
                        -- NOTE: original sends the full `track` table here instead of `trackName`
                        -- like the 10/5 minute warnings above (preserved as-is).
                        TriggerClientEvent("envi-dumpsters:tournamentStarting", playerEntry.source, track, 1)
                    end
                end
            end
        end)
    end

    SetTimeout(startsIn * 60000, function()
        local tournament = ActiveTournaments[trackName]
        if tournament then
            ActiveTournaments[trackName].status = "active"

            local players = ActiveTournaments[trackName].players
            if players then
                for _, playerEntry in pairs(ActiveTournaments[trackName].players) do
                    -- NOTE: original sends the full `track` table here instead of `trackName` (preserved as-is).
                    TriggerClientEvent("envi-dumpsters:tournamentStarted", playerEntry.source, track)
                end
            end
        end
    end)

    SetTimeout((startsIn + duration) * 60000, function()
        local tournament = ActiveTournaments[trackName]
        if tournament then
            ActiveTournaments[trackName].status = "finished"

            local players = ActiveTournaments[trackName].players
            if players then
                local currentWinner = ActiveTournaments[trackName].currentWinner

                for _, playerEntry in pairs(ActiveTournaments[trackName].players) do
                    TriggerClientEvent("envi-dumpsters:tournamentFinished", playerEntry.source, trackName, currentWinner)
                end

                if currentWinner then
                    Framework.Notify(currentWinner.source, Config.Lang.tournament_won, "success")

                    local prizePool = ActiveTournaments[trackName].prizePool
                    if prizePool then
                        if ActiveTournaments[trackName].prizePool > 0 then
                            Framework.AddItem(currentWinner.source, Config.BottleCapItem or "bottle_cap", ActiveTournaments[trackName].prizePool)
                        end
                    end
                end

                TriggerEvent("cart_derby:tournamentFinished", trackName, ActiveTournaments[trackName].players, {
                    hostIdentifier = ActiveTournaments[trackName].host_identifier,
                    hostSource = ActiveTournaments[trackName].players[ActiveTournaments[trackName].host_identifier].source,
                })

                ActiveTournaments[trackName] = nil
            end
        end
    end)
end)

Framework.CreateCallback("envi-dumpsters:derbyScore", function(source, cb, distance, track)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    local identifier = player.Identifier
    local fullName = player.Firstname .. " " .. player.Lastname

    Database.query("SELECT MIN(distance) as min_distance, COUNT(*) as count FROM hobo_cart_leaderboards WHERE track = ? ORDER BY distance DESC LIMIT 10", { track }, function(rows)
        if rows and #rows ~= 0 then
            local count = rows[1].count or 0
            local minDistance = rows[1].min_distance or 0

            if count < 10 or minDistance < distance then
                Database.query(
                    "INSERT INTO hobo_cart_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE distance = IF(? > distance, ?, distance), name = IF(? > distance, ?, name)",
                    { identifier, track, distance, fullName, distance, distance, distance, fullName }
                )

                if count >= 10 then
                    Database.query("DELETE FROM hobo_cart_leaderboards WHERE track = ? AND distance < ? ORDER BY distance ASC LIMIT 1", { track, distance })
                end

                Database.query("SELECT COUNT(*) as position FROM hobo_cart_leaderboards WHERE track = ? AND distance > ?", { track, distance }, function(rows2)
                    if rows2 and #rows2 ~= 0 then
                        local position = rows2[1].position + 1
                        if position > 10 then
                            Database.query("DELETE FROM hobo_cart_leaderboards WHERE track = ? AND identifier = ?", { track, identifier })
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
            Database.query("INSERT INTO hobo_cart_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?)", { identifier, track, distance, fullName })
            cb(true, 1)
        end
    end)
end)

Framework.CreateCallback("envi-dumpsters:derbyScoreTournament", function(source, cb, distance, track)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    local identifier = player.Identifier
    local fullName = player.Firstname .. " " .. player.Lastname

    Database.query("SELECT MIN(distance) as min_distance, COUNT(*) as count FROM hobo_cart_leaderboards WHERE track = ? ORDER BY distance DESC LIMIT 10", { track }, function(rows)
        if rows and #rows ~= 0 then
            local count = rows[1].count or 0
            local minDistance = rows[1].min_distance or 0

            if count < 10 or minDistance < distance then
                Database.query(
                    "INSERT INTO hobo_cart_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE distance = IF(? > distance, ?, distance), name = IF(? > distance, ?, name)",
                    { identifier, track, distance, fullName, distance, distance, distance, fullName }
                )

                if count >= 10 then
                    Database.query("DELETE FROM hobo_cart_leaderboards WHERE track = ? AND distance < ? ORDER BY distance ASC LIMIT 1", { track, distance })
                end

                Database.query("SELECT COUNT(*) as position FROM hobo_cart_leaderboards WHERE track = ? AND distance > ?", { track, distance }, function(rows2)
                    if rows2 and #rows2 ~= 0 then
                        local position = rows2[1].position + 1
                        if position > 10 then
                            Database.query("DELETE FROM hobo_cart_leaderboards WHERE track = ? AND identifier = ?", { track, identifier })
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
            Database.query("INSERT INTO hobo_cart_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?)", { identifier, track, distance, fullName })
            cb(true, 1)
        end
    end)

    local tournament = ActiveTournaments[track]
    if tournament then
        local isNewWinner = false

        if distance > ActiveTournaments[track].players[identifier].bestDistance then
            ActiveTournaments[track].players[identifier].bestDistance = distance

            if distance > ActiveTournaments[track].currentWinner.winnerDistance then
                ActiveTournaments[track].currentWinner = {
                    identifier = identifier,
                    name = fullName,
                    source = source,
                    winnerDistance = distance,
                }
                isNewWinner = true
            end

            TriggerClientEvent("envi-dumpsters:tournamentScoreUpdated", source, distance, isNewWinner)
        end
    end
end)

Framework.CreateCallback("envi-dumpsters:getLeaderboard", function(source, cb, track)
    Database.query(
        "SELECT name, distance, created_at, (@row_number:=@row_number + 1) AS position FROM hobo_cart_leaderboards, (SELECT @row_number:=0) AS r WHERE track = ? ORDER BY distance DESC LIMIT 10",
        { track },
        function(rows)
            cb(rows or {})
        end
    )
end)

if Config.DebugMode then
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

            Database.query("SELECT MIN(distance) as min_distance, COUNT(*) as count FROM hobo_cart_leaderboards WHERE track = ? ORDER BY distance DESC LIMIT 10", { track }, function(rows)
                if rows and #rows ~= 0 then
                    local count = rows[1].count or 0
                    local minDistance = rows[1].min_distance or 0

                    if count < 10 or minDistance < distance then
                        Database.query(
                            "INSERT INTO hobo_cart_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE distance = IF(? > distance, ?, distance), name = IF(? > distance, ?, name)",
                            { identifier, track, distance, fullName, distance, distance, distance, fullName }
                        )

                        if count >= 10 then
                            Database.query("DELETE FROM hobo_cart_leaderboards WHERE track = ? AND distance < ? ORDER BY distance ASC LIMIT 1", { track, distance })
                        end

                        Database.query("SELECT COUNT(*) as position FROM hobo_cart_leaderboards WHERE track = ? AND distance > ?", { track, distance }, function(rows2)
                            if rows2 and #rows2 ~= 0 then
                                local position = rows2[1].position + 1
                                if position > 10 then
                                    Database.query("DELETE FROM hobo_cart_leaderboards WHERE track = ? AND identifier = ?", { track, identifier })
                                end
                            end
                        end)
                    else
                        return
                    end
                else
                    Database.query("INSERT INTO hobo_cart_leaderboards (identifier, track, distance, name) VALUES (?, ?, ?, ?)", { identifier, track, distance, fullName })
                end
            end)
        end
    end, false)
end
