BLScav_HustleState = {}
local hustleHistory = {}

local function ensureHustleTables(identifier)
    if not BLScav_HustleState[identifier] then
        BLScav_HustleState[identifier] = {}
    end
    if not hustleHistory[identifier] then
        hustleHistory[identifier] = {}
    end
end

function IsHustleActive(identifier, taskType)
    if not identifier or not taskType then
        return false
    end
    local tasks = BLScav_HustleState[identifier]
    if not tasks then
        ensureHustleTables(identifier)
    end
    tasks = BLScav_HustleState[identifier]
    local isActive
    if tasks then
        isActive = tasks[taskType] ~= nil
    end
    return isActive
end

RegisterNetEvent("bl_scav:server:StartStreetHustlerTask", function(taskType)
    local src = source
    local player = Framework.GetPlayer(src)
    if not player then
        return
    end
    local identifier = player.Identifier
    ensureHustleTables(identifier)
    if IsHustleActive(identifier, taskType) then
        Framework.Notify(src, Config.Lang.already_working_task, "error")
        return
    end
    local task
    for _, missionTask in ipairs(Config.Contracts[10].Tasks) do
        if missionTask.type == taskType then
            task = missionTask
            break
        end
    end
    if not task then
        Framework.Notify(src, Config.Lang.task_not_found, "error")
        return
    end
    BLScav_HustleState[identifier][taskType] = {
        progress = 0,
        bottleCaps = task.bottleCaps,
        required = task.count
    }
    TriggerClientEvent("bl_scav:client:StartStreetHustlerTask", src, taskType, task.count)
    Framework.Notify(src, string.format(Config.Lang.task_started, task.name), "success")
end)

--- Look up a level-10 hustle definition by its type key.
local function FindHustleDefinition(taskType)
    for _, missionTask in ipairs(Config.Contracts[10].Tasks) do
        if missionTask.type == taskType then
            return missionTask
        end
    end
    return nil
end

--- Authoritative progress writer. SERVER-INTERNAL ONLY — never bind this to a net event.
---
--- SECURITY: the original registered this as a *net* event whose first parameter was the
--- target player id and whose third was the new progress value. That meant any client
--- could (a) drive another player's task state and (b) submit an arbitrary progress
--- number, instantly completing a hustle and minting the bottle-cap reward. It also
--- contained a parameter-shuffle bug where `progress` was assigned from `taskType`, so
--- the client-triggered path could never report a sane value anyway.
---
--- Progress is now only ever advanced by trusted server-side callers, and is clamped to
--- the task's requirement.
function ApplyHustleProgress(src, taskType, progress)
    local player = Framework.GetPlayer(src)
    if not player then
        return
    end

    if type(taskType) ~= "string" then
        return
    end

    progress = tonumber(progress)
    if not progress or progress < 0 then
        return
    end

    local identifier = player.Identifier
    ensureHustleTables(identifier)

    if not IsHustleActive(identifier, taskType) then
        local task = FindHustleDefinition(taskType)
        if not task then
            return
        end
        BLScav_HustleState[identifier][taskType] = {
            progress = 1,
            bottleCaps = task.bottleCaps,
            required = task.count
        }
    end

    local state = BLScav_HustleState[identifier][taskType]
    -- Never let progress run past the requirement or move backwards.
    progress = math.min(math.floor(progress), state.required)
    if progress <= state.progress then
        progress = state.progress
    end
    state.progress = progress

    TriggerClientEvent("bl_scav:client:UpdateTaskProgress", src, taskType, progress, state.required)
    if progress >= state.required then
        FinalizeHustle(src, taskType)
    end
end

function FinalizeHustle(src, taskType)
    local player = Framework.GetPlayer(src)
    if not player then
        return
    end
    local identifier = player.Identifier
    if not IsHustleActive(identifier, taskType) then
        return
    end
    local bottleCaps = BLScav_HustleState[identifier][taskType].bottleCaps
    Framework.AddItem(src, Config.CapCurrencyItem or "bottle_cap", bottleCaps)
    hustleHistory[identifier][taskType] = {
        timestamp = os.time(),
        bottleCaps = bottleCaps
    }
    BLScav_HustleState[identifier][taskType] = nil
    TriggerClientEvent("bl_scav:client:TaskCompleted", src, taskType, bottleCaps)
end

RegisterNetEvent("bl_scav:server:CancelStreetHustlerTask", function(taskType)
    local src = source
    local identifier = Framework.GetPlayer(src).Identifier
    if not IsHustleActive(identifier, taskType) then
        return
    end
    BLScav_HustleState[identifier][taskType] = nil
    Framework.Notify(src, Config.Lang.task_canceled, "info")
end)

AddEventHandler("playerDropped", function()
    local src = source
    local identifier = Framework.GetPlayer(src).Identifier
    BLScav_HustleState[identifier] = nil
end)

Framework.CreateCallback("bl_scav:server:GetTaskHistory", function(src, cb)
    local identifier = Framework.GetPlayer(src).Identifier
    ensureHustleTables(identifier)
    cb(hustleHistory[identifier])
end)

--- Add `amount` to an in-flight hustle. Server-internal.
local function AdvanceHustle(src, taskType, amount)
    local player = Framework.GetPlayer(src)
    if not player then
        return
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        return
    end

    local identifier = player.Identifier
    ensureHustleTables(identifier)
    if IsHustleActive(identifier, taskType) then
        local newProgress = BLScav_HustleState[identifier][taskType].progress + math.floor(amount)
        ApplyHustleProgress(src, taskType, newProgress)
    end
end

-- SECURITY: these two were RegisterNetEvent with a caller-supplied `playerId`, so a
-- client could credit hustle progress to ANY player (including themselves) with any
-- amount. They are only ever raised server-side (see server/progress_loot.lua), so they
-- are now plain AddEventHandler — unreachable from the network entirely.
AddEventHandler("bl_scav:server:BottleCapCollected", function(playerId, amount)
    AdvanceHustle(playerId, "bottle_collection", amount)
end)

AddEventHandler("bl_scav:server:BeggingReceived", function(playerId, amount)
    AdvanceHustle(playerId, "begging_challenge", amount)
end)

RegisterNetEvent("bl_scav:derby:tournamentFinished", function(tournamentId, results, options)
    local src = source
    local hostSource = nil
    if options then
        hostSource = options.hostSource
    else
        if not (BLScav_LiveTournaments and BLScav_LiveTournaments[tournamentId]) then
            return
        end
        local hostIdentifier = BLScav_LiveTournaments[tournamentId].host_identifier
        for _, playerId in pairs(GetPlayers()) do
            local player = Framework.GetPlayer(playerId)
            if player and player.Identifier == hostIdentifier then
                hostSource = playerId
                break
            end
        end
    end
    if hostSource then
        local identifier = Framework.GetPlayer(hostSource).Identifier
        local isActive = IsHustleActive(identifier, "cart_derby_tournament")
        local participantCount = 0
        for _ in pairs(results) do
            participantCount = participantCount + 1
        end
        ensureHustleTables(identifier)
        if isActive then
            if participantCount >= BLScav_HustleState[identifier].cart_derby_tournament.required then
                FinalizeHustle(hostSource, "cart_derby_tournament")
            end
        else
            local task
            for _, missionTask in ipairs(Config.Contracts[10].Tasks) do
                if missionTask.type == "cart_derby_tournament" then
                    task = missionTask
                    break
                end
            end
            if task then
                BLScav_HustleState[identifier].cart_derby_tournament = {
                    progress = participantCount,
                    bottleCaps = task.bottleCaps,
                    required = task.count,
                    startTime = os.time()
                }
                if participantCount >= task.count then
                    FinalizeHustle(hostSource, "cart_derby_tournament")
                end
            end
        end
    end
end)

RegisterNetEvent("bl_scav:alley:gameFinished", function(playerId, resultData, score)
    playerId = playerId or source
    local identifier = Framework.GetPlayer(playerId).Identifier
    local isActive = IsHustleActive(identifier, "hobo_bowling")
    ensureHustleTables(identifier)
    if isActive then
        if score >= BLScav_HustleState[identifier].hobo_bowling.required then
            FinalizeHustle(playerId, "hobo_bowling")
        end
    end
end)
