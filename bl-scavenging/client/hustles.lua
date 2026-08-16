local activeHustles = {}

local hustleProgressMessages = {
    bottle_collection = Config.Lang.task_progress_bottle,
    cart_derby_tournament = Config.Lang.task_progress_derby,
    begging_challenge = Config.Lang.task_progress_begging,
    hobo_bowling = Config.Lang.task_progress_bowling,
}

RegisterNetEvent("bl_scav:client:StartStreetHustlerTask", function(taskType, required)
    activeHustles[taskType] = { progress = 0, required = required }
    RenderHustleTracker(taskType, 0, required)
end)

RegisterNetEvent("bl_scav:client:UpdateTaskProgress", function(taskType, progress, required)
    activeHustles[taskType] = { progress = progress, required = required }
    RenderHustleTracker(taskType, progress, required)
end)

RegisterNetEvent("bl_scav:client:TaskCompleted", function(taskType, taskLabel)
    Framework.Notify(string.format(Config.Lang.task_completed, taskLabel), "success")
    PlaySoundFrontend(-1, "COLLECTED", "HUD_AWARDS", true)
    activeHustles[taskType] = nil
end)

function RenderHustleTracker(taskType, progress, required)
    local message = hustleProgressMessages[taskType]
    if not message then
        return
    end

    local percent = math.floor((progress / required) * 100)
    local text = string.format(message, progress, required, percent)
    Framework.Notify(text, "info")
end

function IsHustleActive(taskType)
    return activeHustles[taskType] ~= nil
end

function GetActiveHustles()
    return activeHustles
end

exports("IsTaskActive", IsHustleActive)
exports("GetActiveTasks", GetActiveHustles)
