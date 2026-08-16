PlayerTasks = {}
local playerTaskHistory = {}

local function ensurePlayerTaskTables(identifier)
    if not PlayerTasks[identifier] then
        PlayerTasks[identifier] = {}
    end
    if not playerTaskHistory[identifier] then
        playerTaskHistory[identifier] = {}
    end
end

function IsTaskActive(identifier, taskType)
    if not identifier or not taskType then
        return false
    end
    local tasks = PlayerTasks[identifier]
    if not tasks then
        ensurePlayerTaskTables(identifier)
    end
    tasks = PlayerTasks[identifier]
    local isActive
    if tasks then
        isActive = tasks[taskType] ~= nil
    end
    return isActive
end

RegisterNetEvent("envi-dumpsters:server:StartStreetHustlerTask", function(taskType)
    local src = source
    local player = Framework.GetPlayer(src)
    if not player then
        return
    end
    local identifier = player.Identifier
    ensurePlayerTaskTables(identifier)
    if IsTaskActive(identifier, taskType) then
        Framework.Notify(src, Config.Lang.already_working_task, "error")
        return
    end
    local task
    for _, missionTask in ipairs(Config.Missions[10].Tasks) do
        if missionTask.type == taskType then
            task = missionTask
            break
        end
    end
    if not task then
        Framework.Notify(src, Config.Lang.task_not_found, "error")
        return
    end
    PlayerTasks[identifier][taskType] = {
        progress = 0,
        bottleCaps = task.bottleCaps,
        required = task.count
    }
    TriggerClientEvent("envi-dumpsters:client:StartStreetHustlerTask", src, taskType, task.count)
    Framework.Notify(src, string.format(Config.Lang.task_started, task.name), "success")
end)

RegisterNetEvent("envi-dumpsters:server:UpdateStreetHustlerTaskProgress", function(arg1, taskType, progress)
    local src = arg1
    if type(arg1) ~= "number" then
        src = source
        taskType = arg1
        -- mirrors original decompiled shuffle exactly: progress ends up equal to taskType here
        progress = taskType
    end
    local player = Framework.GetPlayer(src)
    if not player then
        return
    end
    local identifier = player.Identifier
    ensurePlayerTaskTables(identifier)
    if not IsTaskActive(identifier, taskType) then
        local task
        for _, missionTask in ipairs(Config.Missions[10].Tasks) do
            if missionTask.type == taskType then
                task = missionTask
                break
            end
        end
        if task then
            PlayerTasks[identifier][taskType] = {
                progress = 1,
                bottleCaps = task.bottleCaps,
                required = task.count
            }
        else
            return
        end
    end
    PlayerTasks[identifier][taskType].progress = progress
    TriggerClientEvent("envi-dumpsters:client:UpdateTaskProgress", src, taskType, progress, PlayerTasks[identifier][taskType].required)
    if progress >= PlayerTasks[identifier][taskType].required then
        CompleteTask(src, taskType)
    end
end)

function CompleteTask(src, taskType)
    local player = Framework.GetPlayer(src)
    if not player then
        return
    end
    local identifier = player.Identifier
    if not IsTaskActive(identifier, taskType) then
        return
    end
    local bottleCaps = PlayerTasks[identifier][taskType].bottleCaps
    Framework.AddItem(src, Config.BottleCapItem or "bottle_cap", bottleCaps)
    playerTaskHistory[identifier][taskType] = {
        timestamp = os.time(),
        bottleCaps = bottleCaps
    }
    PlayerTasks[identifier][taskType] = nil
    TriggerClientEvent("envi-dumpsters:client:TaskCompleted", src, taskType, bottleCaps)
end

RegisterNetEvent("envi-dumpsters:server:CancelStreetHustlerTask", function(taskType)
    local src = source
    local identifier = Framework.GetPlayer(src).Identifier
    if not IsTaskActive(identifier, taskType) then
        return
    end
    PlayerTasks[identifier][taskType] = nil
    Framework.Notify(src, Config.Lang.task_canceled, "info")
end)

AddEventHandler("playerDropped", function()
    local src = source
    local identifier = Framework.GetPlayer(src).Identifier
    PlayerTasks[identifier] = nil
end)

Framework.CreateCallback("envi-dumpsters:server:GetTaskHistory", function(src, cb)
    local identifier = Framework.GetPlayer(src).Identifier
    ensurePlayerTaskTables(identifier)
    cb(playerTaskHistory[identifier])
end)

local function AddTaskProgress(src, taskType, amount)
    local identifier = Framework.GetPlayer(src).Identifier
    ensurePlayerTaskTables(identifier)
    local isActive = IsTaskActive(identifier, taskType)
    if isActive then
        local newProgress = PlayerTasks[identifier][taskType].progress + amount
        TriggerEvent("envi-dumpsters:server:UpdateStreetHustlerTaskProgress", src, taskType, newProgress)
    end
end

RegisterNetEvent("envi-dumpsters:server:BottleCapCollected", function(playerId, amount)
    playerId = playerId or source
    AddTaskProgress(playerId, "bottle_collection", amount)
end)

RegisterNetEvent("envi-dumpsters:server:BeggingReceived", function(playerId, amount)
    playerId = playerId or source
    AddTaskProgress(playerId, "begging_challenge", amount)
end)

RegisterNetEvent("cart_derby:tournamentFinished", function(tournamentId, results, options)
    local src = source
    local hostSource = nil
    if options then
        hostSource = options.hostSource
    else
        if not (ActiveTournaments and ActiveTournaments[tournamentId]) then
            return
        end
        local hostIdentifier = ActiveTournaments[tournamentId].host_identifier
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
        local isActive = IsTaskActive(identifier, "cart_derby_tournament")
        local participantCount = 0
        for _ in pairs(results) do
            participantCount = participantCount + 1
        end
        ensurePlayerTaskTables(identifier)
        if isActive then
            if participantCount >= PlayerTasks[identifier].cart_derby_tournament.required then
                CompleteTask(hostSource, "cart_derby_tournament")
            end
        else
            local task
            for _, missionTask in ipairs(Config.Missions[10].Tasks) do
                if missionTask.type == "cart_derby_tournament" then
                    task = missionTask
                    break
                end
            end
            if task then
                PlayerTasks[identifier].cart_derby_tournament = {
                    progress = participantCount,
                    bottleCaps = task.bottleCaps,
                    required = task.count,
                    startTime = os.time()
                }
                if participantCount >= task.count then
                    CompleteTask(hostSource, "cart_derby_tournament")
                end
            end
        end
    end
end)

RegisterNetEvent("hobo_bowling:gameFinished", function(playerId, resultData, score)
    playerId = playerId or source
    local identifier = Framework.GetPlayer(playerId).Identifier
    local isActive = IsTaskActive(identifier, "hobo_bowling")
    ensurePlayerTaskTables(identifier)
    if isActive then
        if score >= PlayerTasks[identifier].hobo_bowling.required then
            CompleteTask(playerId, "hobo_bowling")
        end
    end
end)
