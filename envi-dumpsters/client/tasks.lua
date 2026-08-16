local activeTasks = {}

local taskProgressMessages = {
    bottle_collection = Config.Lang.task_progress_bottle,
    cart_derby_tournament = Config.Lang.task_progress_derby,
    begging_challenge = Config.Lang.task_progress_begging,
    hobo_bowling = Config.Lang.task_progress_bowling,
}

RegisterNetEvent("envi-dumpsters:client:StartStreetHustlerTask", function(taskType, required)
    activeTasks[taskType] = { progress = 0, required = required }
    UpdateTaskProgressUI(taskType, 0, required)
end)

RegisterNetEvent("envi-dumpsters:client:UpdateTaskProgress", function(taskType, progress, required)
    activeTasks[taskType] = { progress = progress, required = required }
    UpdateTaskProgressUI(taskType, progress, required)
end)

RegisterNetEvent("envi-dumpsters:client:TaskCompleted", function(taskType, taskLabel)
    Framework.Notify(string.format(Config.Lang.task_completed, taskLabel), "success")
    PlaySoundFrontend(-1, "COLLECTED", "HUD_AWARDS", true)
    activeTasks[taskType] = nil
end)

function UpdateTaskProgressUI(taskType, progress, required)
    local message = taskProgressMessages[taskType]
    if not message then
        return
    end

    local percent = math.floor((progress / required) * 100)
    local text = string.format(message, progress, required, percent)
    Framework.Notify(text, "info")
end

function IsTaskActive(taskType)
    return activeTasks[taskType] ~= nil
end

function GetActiveTasks()
    return activeTasks
end

exports("IsTaskActive", IsTaskActive)
exports("GetActiveTasks", GetActiveTasks)
