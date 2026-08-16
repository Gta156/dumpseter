if not Config.HoboBowling.Enabled then
    return
end

local spawnedHostNPCs = {}
local pins = {}
local playerStartZone = nil
local spawnedCart = nil
local currentGame = nil
local currentLocation = nil
local isHost = false
local isMyTurn = false

local function JoinGameMenu(location)
    Framework.TriggerCallback("hobo_bowling:getAvailableGames", function(games)
        if #games == 0 then
            Framework.Notify(Config.Lang.no_games_available or "No games available", "error")
            return
        end

        local options = {}
        for _, game in ipairs(games) do
            table.insert(options, {
                label = string.format(Config.Lang.game_at_location or "Game at %s (%d/%d players)", game.location, game.players, game.maxPlayers),
                value = game.id,
            })
        end

        local input = lib.inputDialog(Config.Lang.join_bowling or "Join Bowling Game", {
            {
                type = "select",
                label = Config.Lang.select_game or "Select Game",
                options = options,
                required = true,
            },
        })

        if input then
            TriggerServerEvent("hobo_bowling:joinGame", input[1])
        end
    end, location.name)
end

local function HostGameMenu(location)
    local input = lib.inputDialog(Config.Lang.host_bowling or "Host Bowling Game", {
        {
            type = "number",
            label = Config.Lang.number_of_players or "Number of Players",
            description = Config.Lang.enter_1_4_players or "Enter 1-4 players",
            required = true,
            min = 1,
            max = 4,
        },
    })

    if input then
        TriggerServerEvent("hobo_bowling:createGame", {
            location = location.name,
            maxPlayers = input[1],
        })
    end
end

local function CleanupPins()
    if not isHost then
        return
    end

    if Config.DebugMode then
        print("^2[Hobo Bowling]^7 HOST: Cleaning up all pins")
    end

    for _, pin in pairs(pins) do
        if DoesEntityExist(pin.handle) then
            DeleteEntity(pin.handle)
        end
    end

    pins = {}
end

local function SpawnPins()
    if not (isHost and currentLocation) then
        return
    end

    CleanupPins()

    if Config.DebugMode then
        print("^2[Hobo Bowling]^7 HOST: Spawning exactly 10 pins")
    end

    local pinSpacing = Config.HoboBowling.PinSpacing or 1.5
    local basePos = vector3(currentLocation.pins.x, currentLocation.pins.y, currentLocation.pins.z)
    local laneAngle = math.rad(currentLocation.laneHeading)
    local rowDir = vector3(math.sin(laneAngle), math.cos(laneAngle), 0.0)
    local pinDir = vector3(math.sin(laneAngle - math.pi / 2), math.cos(laneAngle - math.pi / 2), 0.0)

    local pinLayout = {
        { row = 0, pin = 0 },
        { row = 1, pin = -0.5 },
        { row = 1, pin = 0.5 },
        { row = 2, pin = -1 },
        { row = 2, pin = 0 },
        { row = 2, pin = 1 },
        { row = 3, pin = -1.5 },
        { row = 3, pin = -0.5 },
        { row = 3, pin = 0.5 },
        { row = 3, pin = 1.5 },
    }

    for i = 1, 10, 1 do
        local layout = pinLayout[i]
        local offset = (rowDir * (layout.row * pinSpacing)) + (pinDir * (layout.pin * pinSpacing))
        local pos = basePos + offset

        local modelHash = GetHashKey(Config.HoboBowling.PinPedModels[math.random(#Config.HoboBowling.PinPedModels)])
        Framework.LoadModel(modelHash)

        local ped = CreatePed(4, modelHash, pos.x, pos.y, pos.z - 1.0, currentLocation.laneHeading - 90.0, true, false)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, true)

        pins[i] = { handle = ped, isKnockedDown = false, originalPos = pos }
    end

    if Config.DebugMode then
        print("^2[Hobo Bowling]^7 HOST: Spawned " .. #pins .. " pins")
    end
end

local function CountKnockedDownPins()
    local count = 0
    for _, pin in pairs(pins) do
        if not pin.isKnockedDown then
            if DoesEntityExist(pin.handle) then
                local moved = #(GetEntityCoords(pin.handle) - pin.originalPos) > 0.5
                local knockedDown = moved or IsEntityDead(pin.handle) or IsPedRagdoll(pin.handle)
                if knockedDown then
                    pin.isKnockedDown = true
                    count = count + 1
                end
            else
                pin.isKnockedDown = true
                count = count + 1
            end
        end
    end
    return count
end

local function AnnounceStandings()
    if not (currentGame and currentGame.scores) then
        return
    end

    local scores = currentGame.scores
    local myScore = scores[Framework.Player.Identifier]
    local highest = 0
    local leaderId = nil
    local leaderName = "Unknown"

    for identifier, scoreData in pairs(scores) do
        if highest < scoreData.total then
            highest = scoreData.total
            leaderId = identifier
        end
    end

    if leaderId == Framework.Player.Identifier then
        leaderName = "You"
    else
        leaderName = Config.Lang.another_player or "Another Player"
    end

    local message
    if leaderId == Framework.Player.Identifier then
        message = string.format(Config.Lang.you_lead or "You are in the lead with %d points!", highest)
    else
        local myTotal = myScore and myScore.total or 0
        message = string.format(Config.Lang.player_leads or "%s is in the lead with %d points - You have %d points", leaderName, highest, myTotal)
    end

    Framework.Notify(message, "info")
end

local function SpawnCart()
    if not currentLocation then
        return nil
    end

    local model = CART_MODELS[math.random(#CART_MODELS)]
    local spawnPos = currentLocation.cartSpawn

    Framework.LoadModel(model)
    local cart = CreateObject(model, spawnPos.x, spawnPos.y, spawnPos.z, true, true, false)
    SetEntityAsMissionEntity(cart, true, true)
    SetEntityHeading(cart, currentLocation.laneHeading)

    return cart
end

local function SetupFoulZone()
    if not currentLocation then
        return
    end

    if playerStartZone then
        playerStartZone.remove()
    end

    playerStartZone = Points.New({
        debug = currentLocation.showFoulZone,
        coords = vector3(currentLocation.playerStart.x, currentLocation.playerStart.y, currentLocation.playerStart.z),
        distance = Config.HoboBowling.PlayerStartDistance,
        onEnter = function(point)
            playerStartZone = point
        end,
        onExit = function(point)
            if spawnedCart then
                if IsEntityAttachedToEntity(spawnedCart, cache.ped) then
                    Framework.Notify(Config.Lang.foul_warning or "Foul! Cart detached outside play area", "error")
                    DetachEntity(spawnedCart, false, false)

                    if isMyTurn then
                        if currentGame then
                            TriggerServerEvent("hobo_bowling:submitScore", currentGame.id, 0)
                            if spawnedCart then
                                DeleteEntity(spawnedCart)
                                spawnedCart = nil
                            end
                            isMyTurn = false
                        end
                    end
                end
            end
        end,
    })
end

local function StartMyTurn()
    if not (isMyTurn and currentLocation) then
        return
    end

    if Config.DebugMode then
        print("^2[Hobo Bowling]^7 Starting my turn")
    end

    Framework.Notify(Config.Lang.bowl_cart or "Your turn! Bowl the cart!", "success")

    SetEntityCoords(cache.ped, currentLocation.playerStart.x, currentLocation.playerStart.y, currentLocation.playerStart.z)
    SetEntityHeading(cache.ped, currentLocation.playerStart.w)

    spawnedCart = SpawnCart()
    if not spawnedCart then
        return
    end

    CreateThread(function()
        AttachCartToPlayer(spawnedCart, true)

        SetTimeout(2000, function()
            while spawnedCart and IsEntityAttachedToEntity(spawnedCart, cache.ped) do
                Wait(0)
            end

            if not isMyTurn then
                if Config.DebugMode then
                    print("^2[Hobo Bowling]^7 Turn already ended (foul), skipping normal scoring")
                end
                return
            end

            if not spawnedCart then
                if Config.DebugMode then
                    print("^2[Hobo Bowling]^7 Cart was cleaned up, turn likely ended")
                end
                return
            end

            for _, pin in pairs(pins) do
                if not pin.isKnockedDown then
                    if DoesEntityExist(pin.handle) then
                    end
                end
            end

            if Config.DebugMode then
                print("^2[Hobo Bowling]^7 Cart detached, waiting for physics to settle...")
            end

            Wait(3000)
            local firstCount = CountKnockedDownPins()
            if Config.DebugMode then
                print("^2[Hobo Bowling]^7 First pin check: " .. firstCount .. " pins knocked down")
            end

            Wait(2000)
            local finalCount = CountKnockedDownPins()
            if Config.DebugMode then
                print("^2[Hobo Bowling]^7 Final pin check: " .. finalCount .. " pins knocked down")
            end

            local knockedPins = math.max(firstCount, finalCount)
            Framework.Notify(string.format(Config.Lang.turn_complete or "Turn complete! Knocked down %d pins", knockedPins), "info")

            if Config.DebugMode then
                print("^2[Hobo Bowling]^7 Submitting final score: " .. knockedPins .. " pins")
            end

            TriggerServerEvent("hobo_bowling:submitScore", currentGame.id, knockedPins)

            if spawnedCart then
                DeleteEntity(spawnedCart)
                spawnedCart = nil
            end

            SetTimeout(3000, function()
                AnnounceStandings()
            end)

            isMyTurn = false
        end)
    end)
end

local function CreateBowlingHostNPC(location)
    local model = Config.HoboBowling.BowlingHostModel
    Framework.LoadModel(model)

    local menuID = "bowling_host_" .. location.name:lower():gsub("%s+", "_")

    local npc = exports["envi-interact"]:CreateNPC({
        name = "bowling_host_" .. location.name:lower():gsub("%s+", "_"),
        model = model,
        coords = vector3(location.npc.x, location.npc.y, location.npc.z - 1.0),
        heading = location.npc.w,
        isFrozen = true,
    }, {
        title = Config.Lang.bowling_host_title or "Bowling Host",
        speech = string.format(Config.Lang.bowling_host_welcome or "Welcome to %s! Want to play some hobo bowling?", location.name),
        menuID = menuID,
        greeting = "Hi",
        position = "right",
        focusCam = true,
        options = {
            {
                key = "H",
                label = Config.Lang.host_game or "Host Game",
                reaction = "Conversation",
                speech = Config.Lang.bowling_host_setup or "I can set up a game for you!",
                selected = function()
                    HostGameMenu(location)
                end,
            },
            {
                key = "J",
                label = Config.Lang.join_game or "Join Game",
                reaction = "Yes",
                speech = Config.Lang.bowling_host_find or "Let me find you a game!",
                selected = function()
                    JoinGameMenu(location)
                end,
            },
            {
                key = "X",
                label = Config.Lang.nevermind or "Nevermind",
                reaction = "Bye",
                speech = Config.Lang.bowling_host_goodbye or "Come back anytime!",
                selected = function(npcRef)
                    exports["envi-interact"]:CloseMenu(npcRef.menuID)
                end,
            },
        },
    })

    table.insert(spawnedHostNPCs, npc)
end

RegisterNetEvent("hobo_bowling:gameStarted")
AddEventHandler("hobo_bowling:gameStarted", function(game)
    currentGame = game
    isHost = game.host == Framework.Player.Identifier

    for _, location in pairs(Config.HoboBowling.Locations) do
        if location.name == game.location then
            currentLocation = location
            break
        end
    end

    if not currentLocation then
        return
    end

    SetupFoulZone()

    if Config.DebugMode then
        print("^2[Hobo Bowling]^7 Game started. I am host: " .. tostring(isHost))
    end

    Framework.Notify(Config.Lang.game_started or "Game started! Get ready...", "success")
end)

RegisterNetEvent("hobo_bowling:startTurn")
AddEventHandler("hobo_bowling:startTurn", function(game)
    currentGame = game
    isMyTurn = true
    AnnounceStandings()
    StartMyTurn()
end)

RegisterNetEvent("hobo_bowling:updateGame")
AddEventHandler("hobo_bowling:updateGame", function(game)
    currentGame = game
    if game then
        if game.players then
            local currentPlayerId = game.players[game.currentPlayerIndex]
            if currentPlayerId then
                if currentPlayerId == Framework.Player.Identifier then
                    Framework.Notify(Config.Lang.turn_coming_up or "Your turn is coming up!", "info")
                else
                    Framework.Notify(Config.Lang.waiting_players or "Waiting for other players...", "info")
                    AnnounceStandings()
                end
            end
        end
    end
end)

RegisterNetEvent("hobo_bowling:spawnPins")
AddEventHandler("hobo_bowling:spawnPins", function()
    if isHost then
        SpawnPins()
    end
end)

RegisterNetEvent("hobo_bowling:cleanupPins")
AddEventHandler("hobo_bowling:cleanupPins", function()
    if isHost then
        CleanupPins()
    end
end)

RegisterNetEvent("hobo_bowling:gameFinished")
AddEventHandler("hobo_bowling:gameFinished", function(data)
    if currentGame then
        if currentGame.id == data.gameId then
            if data.winner == Framework.Player.Identifier then
                Framework.Notify(Config.Lang.you_won or "You won the game!", "success")
            else
                Framework.Notify(Config.Lang.game_finished or "Game finished!", "info")
            end

            if spawnedCart then
                DeleteEntity(spawnedCart)
                spawnedCart = nil
            end

            if playerStartZone then
                playerStartZone.remove()
                playerStartZone = nil
            end

            if isHost then
                CleanupPins()
            end

            currentGame = nil
            currentLocation = nil
            isHost = false
            isMyTurn = false
        end
    end
end)

CreateThread(function()
    Wait(1000)
    for _, location in pairs(Config.HoboBowling.Locations) do
        CreateBowlingHostNPC(location)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if isHost then
            CleanupPins()
        end

        if spawnedCart then
            DeleteEntity(spawnedCart)
        end

        for _, npc in ipairs(spawnedHostNPCs) do
            DeleteEntity(npc)
        end
    end
end)
