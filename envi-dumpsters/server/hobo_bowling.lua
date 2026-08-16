if not Config.HoboBowling.Enabled then
    return
end

local activeGames = {}
local gameIdCounter = 0

local function CreateGame(data)
    gameIdCounter = gameIdCounter + 1
    local gameId = gameIdCounter

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

    activeGames[gameId] = game

    if Config.DebugMode then
        print("^2[Hobo Bowling]^7 Created game " .. gameId .. " at " .. data.location)
    end

    return game
end

local function GetHostSource(gameId)
    local game = activeGames[gameId]
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

local function GetSourceByIdentifier(identifier)
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

local function NotifyGamePlayers(gameId, message, notifyType)
    local game = activeGames[gameId]
    if not game then
        return
    end

    for _, playerId in ipairs(game.players) do
        local playerSource = GetSourceByIdentifier(playerId)
        if playerSource then
            local finalType = notifyType or "info"
            Framework.Notify(playerSource, message, finalType)
        end
    end
end

local function GetCurrentPlayer(gameId)
    local game = activeGames[gameId]
    if game then
        local currentPlayer = game.players[game.currentPlayerIndex]
        if currentPlayer then
            return currentPlayer
        end
    end

    return nil
end

local function StartGame(gameId)
    local game = activeGames[gameId]
    if not game then
        return
    end

    game.status = "active"

    if Config.DebugMode then
        print("^2[Hobo Bowling]^7 Starting game " .. gameId)
    end

    for _, playerId in ipairs(game.players) do
        local playerSource = GetSourceByIdentifier(playerId)
        if playerSource then
            TriggerClientEvent("hobo_bowling:gameStarted", playerSource, game)
        end
    end

    StartTurn(gameId)
end

function StartTurn(gameId)
    local game = activeGames[gameId]
    if not (game and game.status == "active") then
        return
    end

    local currentPlayerIdentifier = GetCurrentPlayer(gameId)
    if not currentPlayerIdentifier then
        return
    end

    local currentPlayerSource = GetSourceByIdentifier(currentPlayerIdentifier)
    if not currentPlayerSource then
        return
    end

    if Config.DebugMode then
        print("^2[Hobo Bowling]^7 Starting turn for player " .. currentPlayerIdentifier .. " in game " .. gameId)
    end

    local hostSource = GetHostSource(gameId)
    if hostSource then
        TriggerClientEvent("hobo_bowling:cleanupPins", hostSource)

        SetTimeout(1000, function()
            if activeGames[gameId] and activeGames[gameId].status == "active" then
                TriggerClientEvent("hobo_bowling:spawnPins", hostSource)
                game.pinsActive = true

                SetTimeout(500, function()
                    if activeGames[gameId] and activeGames[gameId].status == "active" then
                        TriggerClientEvent("hobo_bowling:startTurn", currentPlayerSource, game)

                        for _, playerId in ipairs(game.players) do
                            if playerId ~= currentPlayerIdentifier then
                                local otherSource = GetSourceByIdentifier(playerId)
                                if otherSource then
                                    TriggerClientEvent("hobo_bowling:updateGame", otherSource, game)
                                end
                            end
                        end
                    end
                end)
            end
        end)
    end
end

local function NextTurn(gameId)
    local game = activeGames[gameId]
    if not game then
        return
    end

    game.currentPlayerIndex = game.currentPlayerIndex + 1

    if game.currentPlayerIndex > #game.players then
        game.currentPlayerIndex = 1
        game.round = game.round + 1

        if Config.DebugMode then
            print("^2[Hobo Bowling]^7 Round " .. game.round .. " starting for game " .. gameId)
        end
    end

    if game.round > game.maxRounds then
        EndGame(gameId)
        return
    end

    SetTimeout(2000, function()
        if activeGames[gameId] then
            StartTurn(gameId)
        end
    end)
end

function EndGame(gameId)
    local game = activeGames[gameId]
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

    if Config.DebugMode then
        local winnerLabel = winner or "none"
        print("^2[Hobo Bowling]^7 Game " .. gameId .. " finished. Winner: " .. winnerLabel)
    end

    local hostSource = GetHostSource(gameId)
    if hostSource then
        TriggerClientEvent("hobo_bowling:cleanupPins", hostSource)
    end

    for _, playerId in ipairs(game.players) do
        local playerSource = GetSourceByIdentifier(playerId)
        if playerSource then
            TriggerClientEvent("hobo_bowling:gameFinished", playerSource, {
                gameId = gameId,
                winner = winner,
                scores = game.scores
            })
        end
    end

    activeGames[gameId] = nil
end

Framework.CreateCallback("hobo_bowling:getAvailableGames", function(source, cb, location)
    local games = {}

    for _, game in pairs(activeGames) do
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

RegisterNetEvent("hobo_bowling:createGame")
AddEventHandler("hobo_bowling:createGame", function(data)
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

    for _, game in pairs(activeGames) do
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

    local newGameData = {}
    newGameData.location = data.location
    newGameData.maxPlayers = data.maxPlayers
    local private = data.private
    if not private then
        private = false
    end
    newGameData.private = private
    newGameData.host = player.Identifier

    local game = CreateGame(newGameData)

    local message = Config.Lang.server_game_created
    if not message then
        message = "Game created! Waiting for players..."
    end
    Framework.Notify(src, message, "success")

    if game.maxPlayers == 1 then
        SetTimeout(1000, function()
            StartGame(game.id)
        end)
    end
end)

RegisterNetEvent("hobo_bowling:joinGame")
AddEventHandler("hobo_bowling:joinGame", function(gameId)
    local src = source
    local player = Framework.GetPlayer(src)
    local game = activeGames[gameId]

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
            StartGame(gameId)
        end)
    end
end)

RegisterNetEvent("hobo_bowling:submitScore")
AddEventHandler("hobo_bowling:submitScore", function(gameId, pins)
    local src = source
    local player = Framework.GetPlayer(src)
    local game = activeGames[gameId]

    if not (player and game and game.status == "active") then
        return
    end

    local currentPlayerIdentifier = GetCurrentPlayer(gameId)
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

    if Config.DebugMode then
        print("^2[Hobo Bowling]^7 Player " .. player.Identifier .. " scored " .. pins .. " pins")
    end

    game.pinsActive = false
    NextTurn(gameId)
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    local player = Framework.GetPlayer(src)
    if not player then
        return
    end

    for gameId, game in pairs(activeGames) do
        for index, playerId in ipairs(game.players) do
            if playerId == player.Identifier then
                table.remove(game.players, index)
                game.scores[playerId] = nil

                if #game.players == 0 then
                    local hostSource = GetHostSource(gameId)
                    if hostSource then
                        TriggerClientEvent("hobo_bowling:cleanupPins", hostSource)
                    end
                    activeGames[gameId] = nil
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
