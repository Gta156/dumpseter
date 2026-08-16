if not Config.AlleyBowling.Enabled then
    return
end

local liveMatches = {}
local matchIdCounter = 0

local function OpenAlleyMatch(data)
    matchIdCounter = matchIdCounter + 1
    local gameId = matchIdCounter

    local game = {}
    game.id = gameId
    game.location = data.location
    game.maxPlayers = data.maxPlayers
    game.private = data.private
    game.host = data.host
    game.players = {data.host}
    game.scores = {}
    game.currentPlayerIndex = 1
    game.status = "waiting"
    game.round = 1
    game.maxRounds = 5
    game.pinsActive = false
    game.scores[data.host] = {total = 0, throws = 0}

    liveMatches[gameId] = game

    if Config.DiagnosticsEnabled then
        print("^2[Hobo Bowling]^7 Created game " .. gameId .. " at " .. data.location)
    end

    return game
end

local function ResolveHostSource(gameId)
    local game = liveMatches[gameId]
    if not game then
        return nil
    end

    for _, playerId in pairs(GetPlayers()) do
        local player = Framework.GetPlayer(playerId)
        if player then
            if player.Identifier == game.host then
                return tonumber(playerId)
            end
        end
    end

    return nil
end

local function ResolveSourceByIdentifier(identifier)
    for _, playerId in pairs(GetPlayers()) do
        local player = Framework.GetPlayer(playerId)
        if player then
            if player.Identifier == identifier then
                return tonumber(playerId)
            end
        end
    end

    return nil
end

local function BroadcastToAlleyMatch(gameId, message, notifyType)
    local game = liveMatches[gameId]
    if not game then
        return
    end

    for _, playerId in ipairs(game.players) do
        local playerSource = ResolveSourceByIdentifier(playerId)
        if playerSource then
            local finalType = notifyType or "info"
            Framework.Notify(playerSource, message, finalType)
        end
    end
end

local function ResolveActiveCompetitor(gameId)
    local game = liveMatches[gameId]
    if game then
        local currentPlayer = game.players[game.currentPlayerIndex]
        if currentPlayer then
            return currentPlayer
        end
    end

    return nil
end

local function BeginAlleyMatch(gameId)
    local game = liveMatches[gameId]
    if not game then
        return
    end

    game.status = "active"

    if Config.DiagnosticsEnabled then
        print("^2[Hobo Bowling]^7 Starting game " .. gameId)
    end

    for _, playerId in ipairs(game.players) do
        local playerSource = ResolveSourceByIdentifier(playerId)
        if playerSource then
            TriggerClientEvent("bl_scav:alley:gameStarted", playerSource, game)
        end
    end

    BeginFrame(gameId)
end

function BeginFrame(gameId)
    local game = liveMatches[gameId]
    if not (game and game.status == "active") then
        return
    end

    local currentPlayerIdentifier = ResolveActiveCompetitor(gameId)
    if not currentPlayerIdentifier then
        return
    end

    local currentPlayerSource = ResolveSourceByIdentifier(currentPlayerIdentifier)
    if not currentPlayerSource then
        return
    end

    if Config.DiagnosticsEnabled then
        print("^2[Hobo Bowling]^7 Starting turn for player " .. currentPlayerIdentifier .. " in game " .. gameId)
    end

    local hostSource = ResolveHostSource(gameId)
    if hostSource then
        TriggerClientEvent("bl_scav:alley:cleanupPins", hostSource)

        SetTimeout(1000, function()
            if liveMatches[gameId] and liveMatches[gameId].status == "active" then
                TriggerClientEvent("bl_scav:alley:spawnPins", hostSource)
                game.pinsActive = true

                SetTimeout(500, function()
                    if liveMatches[gameId] and liveMatches[gameId].status == "active" then
                        TriggerClientEvent("bl_scav:alley:startTurn", currentPlayerSource, game)

                        for _, playerId in ipairs(game.players) do
                            if playerId ~= currentPlayerIdentifier then
                                local otherSource = ResolveSourceByIdentifier(playerId)
                                if otherSource then
                                    TriggerClientEvent("bl_scav:alley:updateGame", otherSource, game)
                                end
                            end
                        end
                    end
                end)
            end
        end)
    end
end

local function AdvanceFrame(gameId)
    local game = liveMatches[gameId]
    if not game then
        return
    end

    game.currentPlayerIndex = game.currentPlayerIndex + 1

    if game.currentPlayerIndex > #game.players then
        game.currentPlayerIndex = 1
        game.round = game.round + 1

        if Config.DiagnosticsEnabled then
            print("^2[Hobo Bowling]^7 Round " .. game.round .. " starting for game " .. gameId)
        end
    end

    if game.round > game.maxRounds then
        CloseAlleyMatch(gameId)
        return
    end

    SetTimeout(2000, function()
        if liveMatches[gameId] then
            BeginFrame(gameId)
        end
    end)
end

function CloseAlleyMatch(gameId)
    local game = liveMatches[gameId]
    if not game then
        return
    end

    game.status = "finished"

    local highestScore = 0
    local winner = nil

    for identifier, scoreData in pairs(game.scores) do
        if highestScore < scoreData.total then
            highestScore = scoreData.total
            winner = identifier
        end
    end

    if Config.DiagnosticsEnabled then
        local winnerLabel = winner or "none"
        print("^2[Hobo Bowling]^7 Game " .. gameId .. " finished. Winner: " .. winnerLabel)
    end

    local hostSource = ResolveHostSource(gameId)
    if hostSource then
        TriggerClientEvent("bl_scav:alley:cleanupPins", hostSource)
    end

    for _, playerId in ipairs(game.players) do
        local playerSource = ResolveSourceByIdentifier(playerId)
        if playerSource then
            TriggerClientEvent("bl_scav:alley:gameFinished", playerSource, {
                gameId = gameId,
                winner = winner,
                scores = game.scores
            })
        end
    end

    liveMatches[gameId] = nil
end

Framework.CreateCallback("bl_scav:alley:getAvailableGames", function(source, cb, location)
    local games = {}

    for _, game in pairs(liveMatches) do
        if game.location == location then
            if game.status == "waiting" then
                if #game.players < game.maxPlayers then
                    table.insert(games, {
                        id = game.id,
                        location = game.location,
                        players = #game.players,
                        maxPlayers = game.maxPlayers
                    })
                end
            end
        end
    end

    cb(games)
end)

RegisterNetEvent("bl_scav:alley:createGame")
AddEventHandler("bl_scav:alley:createGame", function(data)
    local src = source
    local player = Framework.GetPlayer(src)
    if not player then
        local message = Config.Lang.player_data_not_found
        if not message then
            message = "Error: Player data not found!"
        end
        Framework.Notify(src, message, "error")
        return
    end

    for _, game in pairs(liveMatches) do
        if game.location == data.location then
            if game.status ~= "finished" then
                local message = Config.Lang.server_location_in_use
                if not message then
                    message = "Location already in use"
                end
                Framework.Notify(src, message, "error")
                return
            end
        end
    end

    local freshMatchData = {}
    freshMatchData.location = data.location
    freshMatchData.maxPlayers = data.maxPlayers
    local private = data.private
    if not private then
        private = false
    end
    freshMatchData.private = private
    freshMatchData.host = player.Identifier

    local game = OpenAlleyMatch(freshMatchData)

    local message = Config.Lang.server_game_created
    if not message then
        message = "Game created! Waiting for players..."
    end
    Framework.Notify(src, message, "success")

    if game.maxPlayers == 1 then
        SetTimeout(1000, function()
            BeginAlleyMatch(game.id)
        end)
    end
end)

RegisterNetEvent("bl_scav:alley:joinGame")
AddEventHandler("bl_scav:alley:joinGame", function(gameId)
    local src = source
    local player = Framework.GetPlayer(src)
    local game = liveMatches[gameId]

    if not player or not game then
        local message = Config.Lang.server_invalid_game
        if not message then
            message = "Invalid game or player"
        end
        Framework.Notify(src, message, "error")
        return
    end

    if #game.players >= game.maxPlayers then
        local message = Config.Lang.server_game_full
        if not message then
            message = "Game is full"
        end
        Framework.Notify(src, message, "error")
        return
    end

    for _, playerId in ipairs(game.players) do
        if playerId == player.Identifier then
            local message = Config.Lang.server_already_in_game
            if not message then
                message = "Already in this game"
            end
            Framework.Notify(src, message, "error")
            return
        end
    end

    table.insert(game.players, player.Identifier)
    game.scores[player.Identifier] = {total = 0, throws = 0}

    local message = Config.Lang.server_joined_game
    if not message then
        message = "Joined game!"
    end
    Framework.Notify(src, message, "success")

    if #game.players >= game.maxPlayers then
        SetTimeout(2000, function()
            BeginAlleyMatch(gameId)
        end)
    end
end)

RegisterNetEvent("bl_scav:alley:submitScore")
AddEventHandler("bl_scav:alley:submitScore", function(gameId, pins)
    local src = source
    local player = Framework.GetPlayer(src)
    local game = liveMatches[gameId]

    if not (player and game and game.status == "active") then
        return
    end

    local currentPlayerIdentifier = ResolveActiveCompetitor(gameId)
    if currentPlayerIdentifier ~= player.Identifier then
        return
    end

    local scoreData = game.scores[player.Identifier]
    if scoreData then
        scoreData.total = scoreData.total + pins
        scoreData.throws = scoreData.throws + 1

        if pins == 10 then
            scoreData.total = scoreData.total + 5
        end
    end

    if Config.DiagnosticsEnabled then
        print("^2[Hobo Bowling]^7 Player " .. player.Identifier .. " scored " .. pins .. " pins")
    end

    game.pinsActive = false
    AdvanceFrame(gameId)
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    local player = Framework.GetPlayer(src)
    if not player then
        return
    end

    for gameId, game in pairs(liveMatches) do
        for index, playerId in ipairs(game.players) do
            if playerId == player.Identifier then
                table.remove(game.players, index)
                game.scores[playerId] = nil

                if #game.players == 0 then
                    local hostSource = ResolveHostSource(gameId)
                    if hostSource then
                        TriggerClientEvent("bl_scav:alley:cleanupPins", hostSource)
                    end
                    liveMatches[gameId] = nil
                    break
                end

                if game.host == playerId then
                    game.host = game.players[1]
                end

                if game.currentPlayerIndex > #game.players then
                    game.currentPlayerIndex = 1
                end

                break
            end
        end
    end
end)
