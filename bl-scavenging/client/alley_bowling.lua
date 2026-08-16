if not Config.AlleyBowling.Enabled then
    return
end

local hostNPCs = {}
local pins = {}
local competitorStartZone = nil
local createdTrolley = nil
local activeMatch = nil
local currentLocation = nil
local isHost = false
local isLocalFrame = false

local function ShowAlleyJoinMenu(location)
    Framework.TriggerCallback("bl_scav:alley:getAvailableGames", function(games)
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
            TriggerServerEvent("bl_scav:alley:joinGame", input[1])
        end
    end, location.name)
end

local function ShowAlleyHostMenu(location)
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
        TriggerServerEvent("bl_scav:alley:createGame", {
            location = location.name,
            maxPlayers = input[1],
        })
    end
end

local function ClearPins()
    if not isHost then
        return
    end

    if Config.DiagnosticsEnabled then
        print("^2[Hobo Bowling]^7 HOST: Cleaning up all pins")
    end

    for _, pin in pairs(pins) do
        if DoesEntityExist(pin.handle) then
            DeleteEntity(pin.handle)
        end
    end

    pins = {}
end

local function RackPins()
    if not (isHost and currentLocation) then
        return
    end

    ClearPins()

    if Config.DiagnosticsEnabled then
        print("^2[Hobo Bowling]^7 HOST: Spawning exactly 10 pins")
    end

    local pinGap = Config.AlleyBowling.PinSpacing or 1.5
    local basePos = vector3(currentLocation.pins.x, currentLocation.pins.y, currentLocation.pins.z)
    local laneAngle = math.rad(currentLocation.laneHeading)
    local rowDir = vector3(math.sin(laneAngle), math.cos(laneAngle), 0.0)
    local pinDir = vector3(math.sin(laneAngle - math.pi / 2), math.cos(laneAngle - math.pi / 2), 0.0)

    local pinFormation = {
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
        local layout = pinFormation[i]
        local offset = (rowDir * (layout.row * pinGap)) + (pinDir * (layout.pin * pinGap))
        local pos = basePos + offset

        local modelHash = GetHashKey(Config.AlleyBowling.PinPedModels[math.random(#Config.AlleyBowling.PinPedModels)])
        Framework.LoadModel(modelHash)

        local ped = CreatePed(4, modelHash, pos.x, pos.y, pos.z - 1.0, currentLocation.laneHeading - 90.0, true, false)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetPedCanRagdoll(ped, true)

        pins[i] = { handle = ped, isKnockedDown = false, originalPos = pos }
    end

    if Config.DiagnosticsEnabled then
        print("^2[Hobo Bowling]^7 HOST: Spawned " .. #pins .. " pins")
    end
end

local function TallyFelledPins()
    local count = 0
    for _, pin in pairs(pins) do
        if not pin.isKnockedDown then
            if DoesEntityExist(pin.handle) then
                local moved = #(GetEntityCoords(pin.handle) - pin.originalPos) > 0.5
                local felled = moved or IsEntityDead(pin.handle) or IsPedRagdoll(pin.handle)
                if felled then
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

local function BroadcastStandings()
    if not (activeMatch and activeMatch.scores) then
        return
    end

    local scores = activeMatch.scores
    local localScore = scores[Framework.Player.Identifier]
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
        local localTotal = localScore and localScore.total or 0
        message = string.format(Config.Lang.player_leads or "%s is in the lead with %d points - You have %d points", leaderName, highest, localTotal)
    end

    Framework.Notify(message, "info")
end

local function CreateTrolley()
    if not currentLocation then
        return nil
    end

    local model = BLSCAV_TROLLEY_MODELS[math.random(#BLSCAV_TROLLEY_MODELS)]
    local spawnPos = currentLocation.cartSpawn

    Framework.LoadModel(model)
    local cart = CreateObject(model, spawnPos.x, spawnPos.y, spawnPos.z, true, true, false)
    SetEntityAsMissionEntity(cart, true, true)
    SetEntityHeading(cart, currentLocation.laneHeading)

    return cart
end

local function BindOutOfBoundsZone()
    if not currentLocation then
        return
    end

    if competitorStartZone then
        competitorStartZone.remove()
    end

    competitorStartZone = Points.New({
        debug = currentLocation.showFoulZone,
        coords = vector3(currentLocation.playerStart.x, currentLocation.playerStart.y, currentLocation.playerStart.z),
        distance = Config.AlleyBowling.PlayerStartDistance,
        onEnter = function(point)
            competitorStartZone = point
        end,
        onExit = function(point)
            if createdTrolley then
                if IsEntityAttachedToEntity(createdTrolley, cache.ped) then
                    Framework.Notify(Config.Lang.foul_warning or "Foul! Cart detached outside play area", "error")
                    DetachEntity(createdTrolley, false, false)

                    if isLocalFrame then
                        if activeMatch then
                            TriggerServerEvent("bl_scav:alley:submitScore", activeMatch.id, 0)
                            if createdTrolley then
                                DeleteEntity(createdTrolley)
                                createdTrolley = nil
                            end
                            isLocalFrame = false
                        end
                    end
                end
            end
        end,
    })
end

local function BeginLocalFrame()
    if not (isLocalFrame and currentLocation) then
        return
    end

    if Config.DiagnosticsEnabled then
        print("^2[Hobo Bowling]^7 Starting my turn")
    end

    Framework.Notify(Config.Lang.bowl_cart or "Your turn! Bowl the cart!", "success")

    SetEntityCoords(cache.ped, currentLocation.playerStart.x, currentLocation.playerStart.y, currentLocation.playerStart.z)
    SetEntityHeading(cache.ped, currentLocation.playerStart.w)

    createdTrolley = CreateTrolley()
    if not createdTrolley then
        return
    end

    CreateThread(function()
        GripTrolley(createdTrolley, true)

        SetTimeout(2000, function()
            while createdTrolley and IsEntityAttachedToEntity(createdTrolley, cache.ped) do
                Wait(0)
            end

            if not isLocalFrame then
                if Config.DiagnosticsEnabled then
                    print("^2[Hobo Bowling]^7 Turn already ended (foul), skipping normal scoring")
                end
                return
            end

            if not createdTrolley then
                if Config.DiagnosticsEnabled then
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

            if Config.DiagnosticsEnabled then
                print("^2[Hobo Bowling]^7 Cart detached, waiting for physics to settle...")
            end

            Wait(3000)
            local firstCount = TallyFelledPins()
            if Config.DiagnosticsEnabled then
                print("^2[Hobo Bowling]^7 First pin check: " .. firstCount .. " pins knocked down")
            end

            Wait(2000)
            local finalCount = TallyFelledPins()
            if Config.DiagnosticsEnabled then
                print("^2[Hobo Bowling]^7 Final pin check: " .. finalCount .. " pins knocked down")
            end

            local felledPins = math.max(firstCount, finalCount)
            Framework.Notify(string.format(Config.Lang.turn_complete or "Turn complete! Knocked down %d pins", felledPins), "info")

            if Config.DiagnosticsEnabled then
                print("^2[Hobo Bowling]^7 Submitting final score: " .. knockedPins .. " pins")
            end

            TriggerServerEvent("bl_scav:alley:submitScore", activeMatch.id, felledPins)

            if createdTrolley then
                DeleteEntity(createdTrolley)
                createdTrolley = nil
            end

            SetTimeout(3000, function()
                BroadcastStandings()
            end)

            isLocalFrame = false
        end)
    end)
end

local function CreateAlleyHostNPC(location)
    local model = Config.AlleyBowling.BowlingHostModel
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
                    ShowAlleyHostMenu(location)
                end,
            },
            {
                key = "J",
                label = Config.Lang.join_game or "Join Game",
                reaction = "Yes",
                speech = Config.Lang.bowling_host_find or "Let me find you a game!",
                selected = function()
                    ShowAlleyJoinMenu(location)
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

    table.insert(hostNPCs, npc)
end

RegisterNetEvent("bl_scav:alley:gameStarted")
AddEventHandler("bl_scav:alley:gameStarted", function(game)
    activeMatch = game
    isHost = game.host == Framework.Player.Identifier

    for _, location in pairs(Config.AlleyBowling.Locations) do
        if location.name == game.location then
            currentLocation = location
            break
        end
    end

    if not currentLocation then
        return
    end

    BindOutOfBoundsZone()

    if Config.DiagnosticsEnabled then
        print("^2[Hobo Bowling]^7 Game started. I am host: " .. tostring(isHost))
    end

    Framework.Notify(Config.Lang.game_started or "Game started! Get ready...", "success")
end)

RegisterNetEvent("bl_scav:alley:startTurn")
AddEventHandler("bl_scav:alley:startTurn", function(game)
    activeMatch = game
    isLocalFrame = true
    BroadcastStandings()
    BeginLocalFrame()
end)

RegisterNetEvent("bl_scav:alley:updateGame")
AddEventHandler("bl_scav:alley:updateGame", function(game)
    activeMatch = game
    if game then
        if game.players then
            local currentPlayerId = game.players[game.currentPlayerIndex]
            if currentPlayerId then
                if currentPlayerId == Framework.Player.Identifier then
                    Framework.Notify(Config.Lang.turn_coming_up or "Your turn is coming up!", "info")
                else
                    Framework.Notify(Config.Lang.waiting_players or "Waiting for other players...", "info")
                    BroadcastStandings()
                end
            end
        end
    end
end)

RegisterNetEvent("bl_scav:alley:spawnPins")
AddEventHandler("bl_scav:alley:spawnPins", function()
    if isHost then
        RackPins()
    end
end)

RegisterNetEvent("bl_scav:alley:cleanupPins")
AddEventHandler("bl_scav:alley:cleanupPins", function()
    if isHost then
        ClearPins()
    end
end)

RegisterNetEvent("bl_scav:alley:gameFinished")
AddEventHandler("bl_scav:alley:gameFinished", function(data)
    if activeMatch then
        if activeMatch.id == data.gameId then
            if data.winner == Framework.Player.Identifier then
                Framework.Notify(Config.Lang.you_won or "You won the game!", "success")
            else
                Framework.Notify(Config.Lang.game_finished or "Game finished!", "info")
            end

            if createdTrolley then
                DeleteEntity(createdTrolley)
                createdTrolley = nil
            end

            if competitorStartZone then
                competitorStartZone.remove()
                competitorStartZone = nil
            end

            if isHost then
                ClearPins()
            end

            activeMatch = nil
            currentLocation = nil
            isHost = false
            isLocalFrame = false
        end
    end
end)

CreateThread(function()
    Wait(1000)
    for _, location in pairs(Config.AlleyBowling.Locations) do
        CreateAlleyHostNPC(location)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if isHost then
            ClearPins()
        end

        if createdTrolley then
            DeleteEntity(createdTrolley)
        end

        for _, npc in ipairs(hostNPCs) do
            DeleteEntity(npc)
        end
    end
end)
