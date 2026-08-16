--[[ ==========================================================================
     BlackLight Dumpsters — Alley Bowling (client)
========================================================================== ]]

if not Settings.AlleyBowling.Enabled then
    return
end

local random, floor, rad, sin, cos, max = math.random, math.floor, math.rad, math.sin, math.cos, math.max
local insert = table.insert

local compereNPCs = {}
local pinPeds = {}
local throwZone = nil
local laneTrolley = nil
local activeMatch = nil
local activeVenue = nil
local isMatchHost = false
local myTurn = false

local INTERACT = "blacklight-interact"

-- Standard ten-pin triangle laid out as { row, lateral offset }.
local PIN_LAYOUT = {
    { row = 0, lane = 0 },
    { row = 1, lane = -0.5 },
    { row = 1, lane = 0.5 },
    { row = 2, lane = -1 },
    { row = 2, lane = 0 },
    { row = 2, lane = 1 },
    { row = 3, lane = -1.5 },
    { row = 3, lane = -0.5 },
    { row = 3, lane = 0.5 },
    { row = 3, lane = 1.5 },
}

local function BowlingLog(message)
    if Settings.DiagnosticMode then
        print(("[^3BlackLight^7][Alley Bowling] %s"):format(message))
    end
end

-- --------------------------------------------------------------------------
--  MATCH SETUP MENUS
-- --------------------------------------------------------------------------

local function OpenJoinMatchDialog(venue)
    Framework.TriggerCallback("bl_dumpsters:server:ListOpenMatches", function(matches)
        if #matches == 0 then
            Framework.Notify(Settings.Text.no_open_matches, "error")
            return
        end

        local options = {}
        for _, match in ipairs(matches) do
            insert(options, {
                label = string.format(Settings.Text.match_listing, match.venue, match.entrants, match.maxEntrants),
                value = match.id,
            })
        end

        local input = lib.inputDialog(Settings.Text.bowling_join, {
            { type = "select", label = Settings.Text.pick_match, options = options, required = true },
        })

        if input then
            TriggerServerEvent("bl_dumpsters:server:JoinMatch", input[1])
        end
    end, venue.name)
end

local function OpenHostMatchDialog(venue)
    local input = lib.inputDialog(Settings.Text.bowling_host, {
        {
            type = "number",
            label = Settings.Text.entrant_count,
            description = Settings.Text.entrant_hint,
            required = true,
            min = 1,
            max = 4,
        },
    })

    if input then
        TriggerServerEvent("bl_dumpsters:server:OpenMatch", {
            venue = venue.name,
            maxEntrants = input[1],
        })
    end
end

-- --------------------------------------------------------------------------
--  PIN MANAGEMENT (host authoritative)
-- --------------------------------------------------------------------------

local function ClearPins()
    if not isMatchHost then
        return
    end

    BowlingLog("HOST: clearing all pins")

    for _, pin in pairs(pinPeds) do
        if DoesEntityExist(pin.handle) then
            DeleteEntity(pin.handle)
        end
    end

    pinPeds = {}
end

local function RaisePins()
    if not (isMatchHost and activeVenue) then
        return
    end

    ClearPins()
    BowlingLog("HOST: raising 10 pins")

    local gap = Settings.AlleyBowling.PinGap or 1.5
    local origin = vector3(activeVenue.pinCluster.x, activeVenue.pinCluster.y, activeVenue.pinCluster.z)
    local bearing = rad(activeVenue.laneBearing)
    local rowAxis = vector3(sin(bearing), cos(bearing), 0.0)
    local laneAxis = vector3(sin(bearing - math.pi / 2), cos(bearing - math.pi / 2), 0.0)

    for i = 1, 10 do
        local slot = PIN_LAYOUT[i]
        local position = origin + (rowAxis * (slot.row * gap)) + (laneAxis * (slot.lane * gap))

        local modelHash = GetHashKey(Settings.AlleyBowling.PinModels[random(#Settings.AlleyBowling.PinModels)])
        Framework.LoadModel(modelHash)

        local pin = CreatePed(4, modelHash, position.x, position.y, position.z - 1.0, activeVenue.laneBearing - 90.0, true, false)
        SetBlockingOfNonTemporaryEvents(pin, true)
        SetPedCanRagdoll(pin, true)

        pinPeds[i] = { handle = pin, toppled = false, origin = position }
    end

    BowlingLog("HOST: raised " .. #pinPeds .. " pins")
end

--- Counts freshly toppled pins (each pin only ever counts once).
local function TallyToppledPins()
    local toppled = 0

    for _, pin in pairs(pinPeds) do
        if not pin.toppled then
            if not DoesEntityExist(pin.handle) then
                pin.toppled = true
                toppled = toppled + 1
            else
                local displaced = #(GetEntityCoords(pin.handle) - pin.origin) > 0.5
                if displaced or IsEntityDead(pin.handle) or IsPedRagdoll(pin.handle) then
                    pin.toppled = true
                    toppled = toppled + 1
                end
            end
        end
    end

    return toppled
end

-- --------------------------------------------------------------------------
--  SCOREBOARD
-- --------------------------------------------------------------------------

local function AnnounceScoreboard()
    if not (activeMatch and activeMatch.scores) then
        return
    end

    local myIdentifier = Framework.Player.Identifier
    local myEntry = activeMatch.scores[myIdentifier]
    local best, leader = 0, nil

    for identifier, entry in pairs(activeMatch.scores) do
        if entry.total > best then
            best = entry.total
            leader = identifier
        end
    end

    if leader == myIdentifier then
        Framework.Notify(string.format(Settings.Text.you_are_leading, best), "info")
    else
        local myTotal = myEntry and myEntry.total or 0
        Framework.Notify(string.format(Settings.Text.rival_is_leading, Settings.Text.unnamed_rival, best, myTotal), "info")
    end
end

-- --------------------------------------------------------------------------
--  TURN HANDLING
-- --------------------------------------------------------------------------

local function SpawnLaneTrolley()
    if not activeVenue then
        return nil
    end

    local model = TROLLEY_MODELS[random(#TROLLEY_MODELS)]
    local spot = activeVenue.trolleySpawn

    Framework.LoadModel(model)
    local trolley = CreateObject(model, spot.x, spot.y, spot.z, true, true, false)
    SetEntityAsMissionEntity(trolley, true, true)
    SetEntityHeading(trolley, activeVenue.laneBearing)

    return trolley
end

--- Creates the foul zone the thrower must stay inside.
local function ArmFoulZone()
    if not activeVenue then
        return
    end

    if throwZone then
        throwZone.remove()
    end

    throwZone = Points.New({
        debug = activeVenue.revealFoulZone,
        coords = vector3(activeVenue.throwMark.x, activeVenue.throwMark.y, activeVenue.throwMark.z),
        distance = Settings.AlleyBowling.ThrowLineRadius,
        onEnter = function(point)
            throwZone = point
        end,
        onExit = function()
            if not (laneTrolley and IsEntityAttachedToEntity(laneTrolley, cache.ped)) then
                return
            end

            Framework.Notify(Settings.Text.foul_called, "error")
            DetachEntity(laneTrolley, false, false)

            if myTurn and activeMatch then
                TriggerServerEvent("bl_dumpsters:server:SubmitPinScore", activeMatch.id, 0)

                if laneTrolley then
                    DeleteEntity(laneTrolley)
                    laneTrolley = nil
                end

                myTurn = false
            end
        end,
    })
end

local function TakeMyTurn()
    if not (myTurn and activeVenue) then
        return
    end

    BowlingLog("Starting my turn")
    Framework.Notify(Settings.Text.throw_the_trolley, "success")

    SetEntityCoords(cache.ped, activeVenue.throwMark.x, activeVenue.throwMark.y, activeVenue.throwMark.z)
    SetEntityHeading(cache.ped, activeVenue.throwMark.w)

    laneTrolley = SpawnLaneTrolley()
    if not laneTrolley then
        return
    end

    CreateThread(function()
        GrabTrolley(laneTrolley, true)

        SetTimeout(2000, function()
            while laneTrolley and IsEntityAttachedToEntity(laneTrolley, cache.ped) do
                Wait(0)
            end

            if not myTurn then
                BowlingLog("Turn already resolved (foul) — skipping scoring")
                return
            end

            if not laneTrolley then
                BowlingLog("Trolley was cleaned up — turn already over")
                return
            end

            BowlingLog("Trolley released — letting physics settle")

            Wait(3000)
            local earlyCount = TallyToppledPins()
            BowlingLog("First tally: " .. earlyCount .. " pins")

            Wait(2000)
            local lateCount = TallyToppledPins()
            BowlingLog("Second tally: " .. lateCount .. " pins")

            -- Two settling passes are taken and the larger is used, matching the
            -- original scoring behaviour (pins that fall late still get counted).
            local toppled = max(earlyCount, lateCount)
            Framework.Notify(string.format(Settings.Text.turn_summary, toppled), "info")
            BowlingLog("Submitting score: " .. toppled)

            TriggerServerEvent("bl_dumpsters:server:SubmitPinScore", activeMatch.id, toppled)

            if laneTrolley then
                DeleteEntity(laneTrolley)
                laneTrolley = nil
            end

            SetTimeout(3000, AnnounceScoreboard)

            myTurn = false
        end)
    end)
end

-- --------------------------------------------------------------------------
--  COMPERE NPC
-- --------------------------------------------------------------------------

local function CreateCompere(venue)
    local model = Settings.AlleyBowling.CompereModel
    Framework.LoadModel(model)

    local menuID = "bl_bowling_compere_" .. venue.name:lower():gsub("%s+", "_")

    local npc = exports[INTERACT]:CreateNPC({
        name = menuID,
        model = model,
        coords = vector3(venue.npc.x, venue.npc.y, venue.npc.z - 1.0),
        heading = venue.npc.w,
        isFrozen = true,
    }, {
        title = Settings.Text.compere_title,
        speech = string.format(Settings.Text.compere_welcome, venue.name),
        menuID = menuID,
        greeting = "Hi",
        position = "right",
        focusCam = true,
        options = {
            {
                key = "H",
                label = Settings.Text.host_match,
                reaction = "Conversation",
                speech = Settings.Text.compere_setup,
                selected = function()
                    OpenHostMatchDialog(venue)
                end,
            },
            {
                key = "J",
                label = Settings.Text.join_match,
                reaction = "Yes",
                speech = Settings.Text.compere_search,
                selected = function()
                    OpenJoinMatchDialog(venue)
                end,
            },
            {
                key = "X",
                label = Settings.Text.never_mind,
                reaction = "Bye",
                speech = Settings.Text.compere_goodbye,
                selected = function(data)
                    exports[INTERACT]:CloseMenu(data.menuID)
                end,
            },
        },
    })

    insert(compereNPCs, npc)
end

-- --------------------------------------------------------------------------
--  NETWORK EVENTS
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:client:MatchStarted", function(match)
    activeMatch = match
    isMatchHost = match.host == Framework.Player.Identifier

    for _, venue in pairs(Settings.AlleyBowling.Venues) do
        if venue.name == match.venue then
            activeVenue = venue
            break
        end
    end

    if not activeVenue then
        return
    end

    ArmFoulZone()
    BowlingLog("Match started. Hosting: " .. tostring(isMatchHost))
    Framework.Notify(Settings.Text.match_underway, "success")
end)

RegisterNetEvent("bl_dumpsters:client:MatchTurnBegan", function(match)
    activeMatch = match
    myTurn = true
    AnnounceScoreboard()
    TakeMyTurn()
end)

RegisterNetEvent("bl_dumpsters:client:MatchStateSync", function(match)
    activeMatch = match

    if not (match and match.entrants) then
        return
    end

    local upNext = match.entrants[match.currentEntrantIndex]
    if not upNext then
        return
    end

    if upNext == Framework.Player.Identifier then
        Framework.Notify(Settings.Text.your_go_soon, "info")
    else
        Framework.Notify(Settings.Text.awaiting_entrants, "info")
        AnnounceScoreboard()
    end
end)

RegisterNetEvent("bl_dumpsters:client:RaisePins", function()
    if isMatchHost then
        RaisePins()
    end
end)

RegisterNetEvent("bl_dumpsters:client:ClearPins", function()
    if isMatchHost then
        ClearPins()
    end
end)

RegisterNetEvent("bl_dumpsters:client:MatchConcluded", function(data)
    if not (activeMatch and activeMatch.id == data.matchId) then
        return
    end

    if data.victor == Framework.Player.Identifier then
        Framework.Notify(Settings.Text.match_won, "success")
    else
        Framework.Notify(Settings.Text.match_over, "info")
    end

    if laneTrolley then
        DeleteEntity(laneTrolley)
        laneTrolley = nil
    end

    if throwZone then
        throwZone.remove()
        throwZone = nil
    end

    if isMatchHost then
        ClearPins()
    end

    activeMatch = nil
    activeVenue = nil
    isMatchHost = false
    myTurn = false
end)

-- --------------------------------------------------------------------------
--  BOOTSTRAP & CLEANUP
-- --------------------------------------------------------------------------

CreateThread(function()
    Wait(1000)
    for _, venue in pairs(Settings.AlleyBowling.Venues) do
        CreateCompere(venue)
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if isMatchHost then
        ClearPins()
    end

    if laneTrolley then
        DeleteEntity(laneTrolley)
    end

    for _, npc in ipairs(compereNPCs) do
        DeleteEntity(npc)
    end
end)
