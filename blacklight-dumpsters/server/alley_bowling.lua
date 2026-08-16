--[[ ==========================================================================
     BlackLight Dumpsters — Alley Bowling (server)
========================================================================== ]]

if not Settings.AlleyBowling.Enabled then
    return
end

local insert, remove = table.insert, table.remove

local liveMatches = {}
local matchCounter = 0

local BADGE = "[^3BlackLight^7][Alley Bowling]"

local function BowlingLog(message)
    if Settings.DiagnosticMode then
        print(("%s %s"):format(BADGE, message))
    end
end

--- Confirms a venue name genuinely exists in config.
local function VenueExists(venueName)
    for _, venue in pairs(Settings.AlleyBowling.Venues) do
        if venue.name == venueName then
            return venue
        end
    end
    return nil
end

-- --------------------------------------------------------------------------
--  MATCH CREATION
-- --------------------------------------------------------------------------

local function OpenMatch(data)
    matchCounter = matchCounter + 1

    local match = {
        id = matchCounter,
        venue = data.venue,
        maxEntrants = data.maxEntrants,
        private = data.private or false,
        host = data.host,
        entrants = { data.host },
        scores = { [data.host] = { total = 0, throws = 0 } },
        currentEntrantIndex = 1,
        status = "waiting",
        frame = 1,
        maxFrames = 5,
        pinsUp = false,
    }

    liveMatches[match.id] = match
    BowlingLog(("Opened match %d at %s"):format(match.id, data.venue))

    return match
end

-- --------------------------------------------------------------------------
--  IDENTITY LOOKUPS
-- --------------------------------------------------------------------------

--- Resolves a stored identifier back to a live server id.
local function SourceForIdentifier(identifier)
    for _, playerId in pairs(GetPlayers()) do
        local player = Framework.GetPlayer(playerId)
        if player and player.Identifier == identifier then
            return tonumber(playerId)
        end
    end
    return nil
end

local function HostSourceFor(matchId)
    local match = liveMatches[matchId]
    if not match then
        return nil
    end
    return SourceForIdentifier(match.host)
end

--- Which identifier is up next?
local function CurrentEntrant(matchId)
    local match = liveMatches[matchId]
    if not match then
        return nil
    end
    return match.entrants[match.currentEntrantIndex]
end

-- --------------------------------------------------------------------------
--  TURN FLOW
-- --------------------------------------------------------------------------

function BeginTurn(matchId)
    local match = liveMatches[matchId]
    if not (match and match.status == "active") then
        return
    end

    local entrantIdentifier = CurrentEntrant(matchId)
    if not entrantIdentifier then
        return
    end

    local entrantSource = SourceForIdentifier(entrantIdentifier)
    if not entrantSource then
        return
    end

    BowlingLog(("Turn starting for %s in match %d"):format(entrantIdentifier, matchId))

    local hostSource = HostSourceFor(matchId)
    if not hostSource then
        return
    end

    TriggerClientEvent("bl_dumpsters:client:ClearPins", hostSource)

    SetTimeout(1000, function()
        local current = liveMatches[matchId]
        if not (current and current.status == "active") then
            return
        end

        TriggerClientEvent("bl_dumpsters:client:RaisePins", hostSource)
        current.pinsUp = true

        SetTimeout(500, function()
            local stillLive = liveMatches[matchId]
            if not (stillLive and stillLive.status == "active") then
                return
            end

            TriggerClientEvent("bl_dumpsters:client:MatchTurnBegan", entrantSource, stillLive)

            for _, otherIdentifier in ipairs(stillLive.entrants) do
                if otherIdentifier ~= entrantIdentifier then
                    local otherSource = SourceForIdentifier(otherIdentifier)
                    if otherSource then
                        TriggerClientEvent("bl_dumpsters:client:MatchStateSync", otherSource, stillLive)
                    end
                end
            end
        end)
    end)
end

local function StartMatch(matchId)
    local match = liveMatches[matchId]
    if not match then
        return
    end

    match.status = "active"
    BowlingLog(("Match %d starting"):format(matchId))

    for _, identifier in ipairs(match.entrants) do
        local entrantSource = SourceForIdentifier(identifier)
        if entrantSource then
            TriggerClientEvent("bl_dumpsters:client:MatchStarted", entrantSource, match)
        end
    end

    BeginTurn(matchId)
end

function ConcludeMatch(matchId)
    local match = liveMatches[matchId]
    if not match then
        return
    end

    match.status = "finished"

    local bestScore, victor = 0, nil
    for identifier, entry in pairs(match.scores) do
        if entry.total > bestScore then
            bestScore = entry.total
            victor = identifier
        end
    end

    BowlingLog(("Match %d finished. Victor: %s"):format(matchId, victor or "none"))

    local hostSource = HostSourceFor(matchId)
    if hostSource then
        TriggerClientEvent("bl_dumpsters:client:ClearPins", hostSource)
    end

    for _, identifier in ipairs(match.entrants) do
        local entrantSource = SourceForIdentifier(identifier)
        if entrantSource then
            TriggerClientEvent("bl_dumpsters:client:MatchConcluded", entrantSource, {
                matchId = matchId,
                victor = victor,
                scores = match.scores,
            })
        end
    end

    -- Feed the host's Corner Grinder contract, if they have one running.
    if hostSource then
        TriggerEvent("bl_dumpsters:server:MatchWrapped", hostSource, match.scores, #match.entrants)
    end

    -- Reward the victor with XP scaled by turnout.
    if victor then
        local victorSource = SourceForIdentifier(victor)
        if victorSource then
            local xp = Settings.AlleyBowling.VictorXP * #match.entrants
            local victorPlayer = Framework.GetPlayer(victorSource)

            if victorPlayer then
                GrantReputationXP(victorPlayer.Identifier, xp)
                Framework.Notify(victorSource, string.format(Settings.Text.match_won_xp, xp), "success")
            end
        end
    end

    liveMatches[matchId] = nil
end

local function AdvanceTurn(matchId)
    local match = liveMatches[matchId]
    if not match then
        return
    end

    match.currentEntrantIndex = match.currentEntrantIndex + 1

    if match.currentEntrantIndex > #match.entrants then
        match.currentEntrantIndex = 1
        match.frame = match.frame + 1
        BowlingLog(("Frame %d beginning in match %d"):format(match.frame, matchId))
    end

    if match.frame > match.maxFrames then
        ConcludeMatch(matchId)
        return
    end

    SetTimeout(2000, function()
        if liveMatches[matchId] then
            BeginTurn(matchId)
        end
    end)
end

-- --------------------------------------------------------------------------
--  CALLBACKS & EVENTS
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:ListOpenMatches", function(source, cb, venueName)
    local listing = {}

    for _, match in pairs(liveMatches) do
        if match.venue == venueName and match.status == "waiting" and #match.entrants < match.maxEntrants then
            insert(listing, {
                id = match.id,
                venue = match.venue,
                entrants = #match.entrants,
                maxEntrants = match.maxEntrants,
            })
        end
    end

    cb(listing)
end)

RegisterNetEvent("bl_dumpsters:server:OpenMatch", function(data)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)

    if not player then
        Framework.Notify(playerSource, Settings.Text.profile_missing, "error")
        return
    end

    if not GuardRate(playerSource, "open_match", 3000) then
        return
    end

    if type(data) ~= "table" or not VenueExists(data.venue) then
        Framework.Notify(playerSource, Settings.Text.match_data_invalid, "error")
        return
    end

    local maxEntrants = GuardNumber(data.maxEntrants, Settings.AlleyBowling.MinEntrants, Settings.AlleyBowling.MaxEntrants)
    if not maxEntrants then
        Framework.Notify(playerSource, Settings.Text.match_data_invalid, "error")
        return
    end

    for _, match in pairs(liveMatches) do
        if match.venue == data.venue and match.status ~= "finished" then
            Framework.Notify(playerSource, Settings.Text.srv_lane_occupied, "error")
            return
        end
    end

    local match = OpenMatch({
        venue = data.venue,
        maxEntrants = maxEntrants,
        private = data.private or false,
        host = player.Identifier,
    })

    Framework.Notify(playerSource, Settings.Text.srv_match_opened, "success")

    -- Solo matches begin immediately.
    if match.maxEntrants == 1 then
        SetTimeout(1000, function()
            StartMatch(match.id)
        end)
    end
end)

RegisterNetEvent("bl_dumpsters:server:JoinMatch", function(matchId)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    local match = liveMatches[matchId]

    if not player or not match then
        Framework.Notify(playerSource, Settings.Text.srv_match_invalid, "error")
        return
    end

    if not GuardRate(playerSource, "join_match", 1000) then
        return
    end

    if #match.entrants >= match.maxEntrants then
        Framework.Notify(playerSource, Settings.Text.srv_match_full, "error")
        return
    end

    for _, identifier in ipairs(match.entrants) do
        if identifier == player.Identifier then
            Framework.Notify(playerSource, Settings.Text.srv_already_entered, "error")
            return
        end
    end

    insert(match.entrants, player.Identifier)
    match.scores[player.Identifier] = { total = 0, throws = 0 }

    Framework.Notify(playerSource, Settings.Text.srv_match_joined, "success")

    if #match.entrants >= match.maxEntrants then
        SetTimeout(2000, function()
            StartMatch(matchId)
        end)
    end
end)

RegisterNetEvent("bl_dumpsters:server:SubmitPinScore", function(matchId, pins)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    local match = liveMatches[matchId]

    if not (player and match and match.status == "active") then
        return
    end

    -- Only the entrant whose turn it is may submit a score.
    if CurrentEntrant(matchId) ~= player.Identifier then
        BowlingLog(("Rejected out-of-turn score from %s"):format(player.Identifier))
        return
    end

    -- A frame can only ever topple ten pins.
    pins = GuardNumber(pins, 0, 10)
    if not pins then
        return
    end

    local entry = match.scores[player.Identifier]
    if entry then
        entry.total = entry.total + (pins * Settings.AlleyBowling.ScorePerPin)
        entry.throws = entry.throws + 1

        -- A clean sweep earns the perfect-frame bonus.
        if pins == 10 then
            entry.total = entry.total + Settings.AlleyBowling.PerfectBonus
        end
    end

    BowlingLog(("%s toppled %d pins"):format(player.Identifier, pins))

    match.pinsUp = false
    AdvanceTurn(matchId)
end)

-- --------------------------------------------------------------------------
--  DISCONNECT HANDLING
-- --------------------------------------------------------------------------

AddEventHandler("playerDropped", function()
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    for matchId, match in pairs(liveMatches) do
        for index, identifier in ipairs(match.entrants) do
            if identifier ~= player.Identifier then
                goto continue
            end

            remove(match.entrants, index)
            match.scores[identifier] = nil

            -- Last entrant out: tear the match down entirely.
            if #match.entrants == 0 then
                local hostSource = HostSourceFor(matchId)
                if hostSource then
                    TriggerClientEvent("bl_dumpsters:client:ClearPins", hostSource)
                end
                liveMatches[matchId] = nil
                break
            end

            -- Hand hosting duties to whoever remains.
            if match.host == identifier then
                match.host = match.entrants[1]
            end

            if match.currentEntrantIndex > #match.entrants then
                match.currentEntrantIndex = 1
            end

            break

            ::continue::
        end
    end
end)
