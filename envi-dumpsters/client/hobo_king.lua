local hoboKingNPC = nil
local missionBlips = {}
local ratZones = {}
local currentRatAreaIndex = nil
local ratKillCounts = {}
local raccoonTameBusy = false
RacoonPal = nil
IsTrueHobo = false
local bodyguards = {}
local MAX_BODYGUARDS = 3
local isHoboKing = false
local bodyguardRelGroup = nil
local generalRelGroup = nil
local playerRelGroup = nil

if Config.DebugMode then
    RegisterCommand("tphk", function()
        SetEntityCoords(cache.ped, Config.HoboKing.Position.x + 2, Config.HoboKing.Position.y, Config.HoboKing.Position.z)
    end, false)

    RegisterCommand("testTrolley", function()
        local model = CART_MODELS[3]
        local coords = GetEntityCoords(cache.ped)
        Framework.LoadModel(model)
        local cart = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)

        if IsPushingCart then
            return
        end

        CurrentCart = cart
        AttachCartToPlayer(CurrentCart)
    end, false)

    RegisterCommand("testbodyguards", function()
        isHoboKing = not isHoboKing
        Framework.Notify("Hobo King status set to: " .. tostring(isHoboKing), "info")
        if isHoboKing then
            SetupRelationshipGroups()
        end
    end, false)

    RegisterCommand("spawnbodyguard", function()
        if isHoboKing and #bodyguards < MAX_BODYGUARDS then
            local coords = GetEntityCoords(cache.ped)
            local offset = math.random(-3, 3)
            local model = Config.AggressivePeds[math.random(#Config.AggressivePeds)]
            local modelHash = GetHashKey(model)

            RequestModel(modelHash)
            while not HasModelLoaded(modelHash) do
                Wait(10)
            end

            local ped = CreatePed(4, modelHash, coords.x + offset, coords.y + offset, coords.z, 0.0, true, true)
            SetModelAsNoLongerNeeded(modelHash)
            RecruitBodyguard(ped)
        else
            Framework.Notify("You must be the Hobo King and have fewer than 3 bodyguards.", "error")
        end
    end, false)
end

CreateThread(function()
    Wait(1000)

    if Config.DisableHoboKingProgressionFeatures then
        return
    end

    local position = Config.HoboKing.Position

    hoboKingNPC = exports["envi-interact"]:CreateNPC({
        name = "hoboking",
        model = Config.HoboKing.Model,
        coords = vector3(position.x, position.y, position.z - 0.9),
        heading = position.w,
        isFrozen = true,
    }, {
        title = Config.Lang.hobo_king_title,
        speech = Config.Lang.hobo_king_welcome,
        menuID = "hoboking-menu",
        greeting = "Hello",
        position = "right",
        focusCam = true,
        options = {
            {
                key = "E",
                label = Config.Lang.check_progress,
                reaction = "Conversation",
                selected = function(data)
                    OpenProgressMenu(data)
                end,
            },
            {
                key = "M",
                label = Config.Lang.current_mission,
                reaction = "Conversation",
                selected = function(data)
                    OpenMissionMenu(data)
                end,
            },
            {
                key = "T",
                label = Config.Lang.hobo_tasks,
                reaction = "Conversation",
                canSee = function()
                    local progression = Framework.TriggerCallback.Await("envi-dumpsters:server:GetProgression")
                    cachedTaskProgression = progression
                    return progression.level >= Config.Missions[10].unlockLevel
                end,
                selected = function()
                    Framework.TriggerCallback("envi-dumpsters:server:GetTaskHistory", function(history)
                        local tasks = Config.Missions[10].Tasks
                        local hasActiveTask = false

                        for _ in pairs(exports["envi-dumpsters"]:GetActiveTasks() or {}) do
                            hasActiveTask = true
                            break
                        end

                        if hasActiveTask then
                            Framework.Notify(Config.Lang.active_task_error, "error")
                            return
                        end

                        local options = {}
                        local key = "A"

                        for _, task in ipairs(tasks) do
                            table.insert(options, {
                                key = key,
                                label = task.name,
                                selected = function()
                                    exports["envi-interact"]:CloseMenu("hobo-task-menu")
                                    TriggerServerEvent("envi-dumpsters:server:StartStreetHustlerTask", task.type)

                                    if task.type == "hobo_taxi" then
                                        Framework.Notify(Config.Lang.hobo_taxi_started, "success")
                                        StartHoboTaxiMission()
                                    end
                                end,
                                canSee = function()
                                    return cachedTaskProgression and cachedTaskProgression.level >= task.level
                                end,
                            })
                            key = string.char(key:byte() + 1)
                        end

                        table.insert(options, {
                            key = "X",
                            label = Config.Lang.back,
                            selected = function()
                                exports["envi-interact"]:CloseMenu("hobo-task-menu")
                            end,
                        })

                        exports["envi-interact"]:OpenChoiceMenu({
                            title = Config.Lang.hobo_tasks,
                            speech = Config.Lang.choose_task,
                            menuID = "hobo-task-menu",
                            position = "right",
                            options = options,
                        })
                    end)
                end,
            },
            {
                key = "D",
                label = Config.Lang.donate_drugs,
                reaction = "Thanks",
                selected = function(data)
                    OpenDonateMenu(data)
                end,
            },
            {
                key = "B",
                label = Config.Lang.donate_caps,
                reaction = "Thanks",
                stayOpen = true,
                selected = function(data)
                    OpenBottleCapMenu(data)
                end,
            },
            {
                key = "S",
                label = Config.Lang.hobo_shop,
                reaction = "Conversation",
                selected = function(data)
                    exports["envi-interact"]:CloseMenu(data.menuID)
                    OpenHoboShop()
                end,
            },
            {
                key = "X",
                label = Config.Lang.nevermind,
                reaction = "Bye",
                selected = function(data)
                    exports["envi-interact"]:CloseMenu(data.menuID)
                end,
            },
        },
    })
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if hoboKingNPC then
            DeleteEntity(hoboKingNPC)
        end
    end
end)

function OpenProgressMenu(data)
    Framework.TriggerCallback("envi-dumpsters:server:GetProgression", function(progression)
        if not progression then
            exports["envi-interact"]:UpdateSpeech(data.menuID, Config.Lang.id_error)
            return
        end

        local nextLevel = progression.level + 1
        local xpNeeded = Config.XPSettings.LevelRequirements[nextLevel]
        if not xpNeeded then
            xpNeeded = "MAX"
        end

        local percent = 100
        if nextLevel <= 10 then
            percent = math.floor((progression.xp / Config.XPSettings.LevelRequirements[nextLevel]) * 100) or 100
        end

        exports["envi-interact"]:PercentageBar("hobo-xp-bar", percent, "Level " .. progression.level .. " Progress: " .. progression.xp .. "/" .. xpNeeded .. " XP", "top", "always")

        local message = string.format(Config.Lang.level_progress_msg, progression.level, progression.xp)
        if progression.is_king == 1 then
            message = message .. Config.Lang.hobo_king_msg
        elseif progression.level == 10 then
            message = message .. Config.Lang.max_level_msg
        else
            message = message .. string.format(Config.Lang.next_level_msg, nextLevel)
        end

        exports["envi-interact"]:UpdateSpeech(data.menuID, message)

        local isMaxLevel = progression.level == 10
        local levelUpLabel = Config.Lang.level_up
        if isMaxLevel then
            levelUpLabel = Config.Lang.challenge_king
        end

        local options = {
            {
                key = "E",
                label = levelUpLabel,
                selected = function(menuData)
                    TryLevelUp(progression)
                    exports["envi-interact"]:CloseMenu(menuData.menuID)
                    exports["envi-interact"]:CloseMenu("hobo-xp-bar")
                end,
            },
        }

        if isMaxLevel then
            table.insert(options, {
                key = "L",
                label = Config.Lang.buy_freedom,
                selected = function(menuData)
                    exports["envi-interact"]:UpdateSpeech(menuData.menuID, Config.Lang.freedom_cost_msg)

                    local result = lib.alertDialog({
                        header = Config.Lang.freedom_title,
                        content = string.format(Config.Lang.freedom_description, Config.HoboKing.FreedomCost),
                        size = "lg",
                        cancel = true,
                        labels = { cancel = Config.Lang.no, confirm = Config.Lang.yes_sure },
                    })

                    if result == "confirm" then
                        TriggerServerEvent("envi-dumpsters:server:BuyYourFreedom")
                    end
                end,
            })
        end

        table.insert(options, {
            key = "X",
            label = Config.Lang.nevermind,
            selected = function()
                exports["envi-interact"]:CloseMenu("hobo-xp-bar")
                exports["envi-interact"]:OpenChoiceMenu({
                    title = Config.Lang.hobo_tasks,
                    speech = Config.Lang.choose_task,
                    menuID = "return_menu",
                    position = "right",
                    options = {
                        {
                            key = "E",
                            label = Config.Lang.check_progress,
                            reaction = "Conversation",
                            selected = function(returnData)
                                OpenProgressMenu(returnData)
                            end,
                        },
                        {
                            key = "M",
                            label = Config.Lang.current_mission,
                            reaction = "Conversation",
                            selected = function(returnData)
                                OpenMissionMenu(returnData)
                            end,
                        },
                        {
                            key = "T",
                            label = Config.Lang.hobo_tasks,
                            reaction = "Conversation",
                            canSee = function()
                                local freshProgression = Framework.TriggerCallback.Await("envi-dumpsters:server:GetProgression")
                                progression = freshProgression
                                return progression.level >= Config.Missions[10].unlockLevel
                            end,
                            selected = function()
                                Framework.TriggerCallback("envi-dumpsters:server:GetTaskHistory", function(history)
                                    local tasks = Config.Missions[10].Tasks
                                    local hasActiveTask = false

                                    for _ in pairs(exports["envi-dumpsters"]:GetActiveTasks() or {}) do
                                        hasActiveTask = true
                                        break
                                    end

                                    if hasActiveTask then
                                        Framework.Notify(Config.Lang.active_task_error, "error")
                                        return
                                    end

                                    local taskOptions = {}
                                    local key = "A"

                                    for _, task in ipairs(tasks) do
                                        table.insert(taskOptions, {
                                            key = key,
                                            label = task.name,
                                            selected = function()
                                                exports["envi-interact"]:CloseMenu("hobo-task-menu")
                                                TriggerServerEvent("envi-dumpsters:server:StartStreetHustlerTask", task.type)

                                                if task.type == "hobo_taxi" then
                                                    Framework.Notify(Config.Lang.hobo_taxi_started, "success")
                                                    StartHoboTaxiMission()
                                                end
                                            end,
                                            canSee = function()
                                                return progression and progression.level >= task.level
                                            end,
                                        })
                                        key = string.char(key:byte() + 1)
                                    end

                                    table.insert(taskOptions, {
                                        key = "X",
                                        label = Config.Lang.back,
                                        selected = function()
                                            exports["envi-interact"]:CloseMenu("hobo-task-menu")
                                        end,
                                    })

                                    exports["envi-interact"]:OpenChoiceMenu({
                                        title = Config.Lang.hobo_tasks,
                                        speech = Config.Lang.choose_task,
                                        menuID = "hobo-task-menu",
                                        position = "right",
                                        options = taskOptions,
                                    })
                                end)
                            end,
                        },
                        {
                            key = "D",
                            label = Config.Lang.donate_drugs,
                            reaction = "Thanks",
                            selected = function(returnData)
                                OpenDonateMenu(returnData)
                            end,
                        },
                        {
                            key = "B",
                            label = Config.Lang.donate_caps,
                            reaction = "Thanks",
                            stayOpen = true,
                            selected = function(returnData)
                                OpenBottleCapMenu(returnData)
                            end,
                        },
                        {
                            key = "S",
                            label = Config.Lang.hobo_shop,
                            reaction = "Conversation",
                            selected = function(returnData)
                                exports["envi-interact"]:CloseMenu(returnData.menuID)
                                OpenHoboShop()
                            end,
                        },
                        {
                            key = "X",
                            label = Config.Lang.nevermind,
                            reaction = "Bye",
                            selected = function(returnData)
                                exports["envi-interact"]:CloseMenu(returnData.menuID)
                            end,
                        },
                    },
                })
            end,
        })

        exports["envi-interact"]:OpenChoiceMenu({
            title = Config.Lang.hobo_progression,
            speech = Config.Lang.what_you_doing,
            menuID = "hobo-progress-menu",
            position = "right",
            options = options,
        })
    end, data)
end

function TryLevelUp(progression)
    local nextLevel = progression.level + 1

    if progression.level == 10 then
        local result = lib.alertDialog({
            header = Config.Lang.hobo_king_challenge,
            content = Config.Lang.challenge_begin,
            size = "lg",
            cancel = true,
            labels = { cancel = Config.Lang.not_yet, confirm = Config.Lang.yes_ready },
        })

        if result == "confirm" then
            StartHoboKingEndlessChallenge()
        end
        return
    end

    if progression.xp < Config.XPSettings.LevelRequirements[nextLevel] then
        Framework.Notify(Config.Lang.not_enough_xp, "error")
        return
    end

    local missionName = GetLevelMissionName(progression.level)
    if missionName then
        local missionData = progression.mission_data[progression.level]
        local completed = missionData and missionData.completed

        if not completed then
            Framework.Notify(string.format(Config.Lang.need_complete_mission, missionName), "error")
            return
        end
    end

    if nextLevel == 5 then
        local result = lib.alertDialog({
            header = Config.Lang.hobo_warning_title,
            content = Config.Lang.hobo_warning_content,
            size = "xl",
            cancel = true,
            labels = { cancel = Config.Lang.hell_no, confirm = Config.Lang.yes_ready },
        })

        if result ~= "confirm" then
            Framework.Notify(Config.Lang.not_ready_hobo, "error")
            return
        end
    end

    TriggerServerEvent("envi-dumpsters:server:LevelUp")
end

function GetLevelMissionName(level)
    return Config.Missions[level].name or nil
end

local lastJobUpdateCheck = 500
local lastJobUpdateTime = 0

Framework.OnJobUpdate = function()
    local now = GetGameTimer()
    if now - lastJobUpdateTime < lastJobUpdateCheck then
        return
    end
    lastJobUpdateTime = now

    Framework.TriggerCallback("envi-dumpsters:server:isTrueHobo", function(isTrueHobo)
        if isTrueHobo then
            IsTrueHobo = true
        end
    end)
end

function ShowUnlockables(level, data)
    local unlockables = Config.Unlockables[level] or {}
    local list = ""

    if #unlockables == 0 then
        list = "None"
    else
        for _, item in ipairs(unlockables) do
            list = list .. "- " .. item .. "\n"
        end
    end

    exports["envi-interact"]:UpdateSpeech(data.menuID, "At level " .. level .. [[
, you can use these items:

]] .. list)
end

function OpenMissionMenu(data)
    Framework.TriggerCallback("envi-dumpsters:server:GetProgression", function(progression)
        if not progression then
            return
        end

        local level = progression.level
        local missionName = GetLevelMissionName(level)
        if not missionName then
            exports["envi-interact"]:UpdateSpeech(data.menuID, Config.Lang.no_mission)
        end

        local mission = Config.Missions[level]
        local missionData = progression.mission_data[level] or {}
        local completed = missionData.completed or false

        local speech = GetMissionDescription(missionName)
        if completed then
            speech = GetCompletedMissionDescription(missionName)
        end

        local options = {}

        table.insert(options, {
            key = "S",
            label = completed and (Config.Lang.completed or "Completed \226\156\148") or (Config.Lang.start_mission or "Start Mission"),
            selected = function(menuData)
                if completed then
                    Framework.Notify(Config.Lang.already_completed, "error")
                else
                    StartMission(missionName, mission)
                    exports["envi-interact"]:CloseMenu(menuData.menuID)
                end
            end,
        })

        if missionName == Config.Missions[6].name then
            if missionData.package_found then
                if not missionData.package_delivered then
                    table.insert(options, {
                        key = "D",
                        label = Config.Lang.deliver_package or "Deliver Package",
                        selected = function(menuData)
                            Framework.TriggerCallback("envi-dumpsters:server:DeliverMedicalPackage", function(success, message)
                                Framework.Notify(message, success and "success" or "error")
                                exports["envi-interact"]:CloseMenu(menuData.menuID)
                            end)
                        end,
                    })
                end
            end
        end

        table.insert(options, {
            key = "X",
            label = Config.Lang.back,
            selected = function(menuData)
                exports["envi-interact"]:CloseMenu(menuData.menuID)
            end,
        })

        exports["envi-interact"]:OpenChoiceMenu({
            title = missionName,
            speech = speech,
            menuID = "mission-menu",
            position = "right",
            options = options,
        })
    end)
end

local function GetMissionLevelByName(name)
    for level, mission in pairs(Config.Missions) do
        if mission.name == name then
            return level
        end
    end
end

function GetMissionDescription(name)
    local level = GetMissionLevelByName(name)
    return Config.Missions[level].description or "What brings you here?"
end

function GetCompletedMissionDescription(name)
    local level = GetMissionLevelByName(name)
    return Config.Missions[level].descriptionCompleted or "You've done what needed to be done. The community respects that."
end

function StartMission(name, mission)
    ClearMissionBlips()

    if name == Config.Missions[1].name then
        StartFirstStepsMission(mission)
    elseif name == Config.Missions[2].name then
        StartRatProblemsMission(mission)
    elseif name == Config.Missions[3].name then
        StartProfessionalBeggarMission(mission)
    elseif name == Config.Missions[4].name then
        StartThrillRideMission()
    elseif name == Config.Missions[5].name then
        StartSupplyChainMission(mission)
    elseif name == Config.Missions[6].name then
        Framework.Notify("Continue searching dumpsters to find a Medical Care Package", "info")
    elseif name == Config.Missions[7].name then
        StartBumFightsMission(mission)
    elseif name == Config.Missions[8].name then
        StartRaccoonWhispererMission(mission)
    elseif name == Config.Missions[9].name then
        StartHoboTaxiMission()
    end

    Framework.Notify(string.format(Config.Lang.mission_started, name), "success")
end

function ClearMissionBlips()
    for _, blip in ipairs(missionBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    missionBlips = {}
end

function StartFirstStepsMission(mission)
    for zoneIndex, zoneCoords in ipairs(mission.Zones) do
        local areaBlip = AddBlipForRadius(zoneCoords.x, zoneCoords.y, zoneCoords.z, mission.ZoneRadius)
        SetBlipColour(areaBlip, 1)
        SetBlipAlpha(areaBlip, 128)

        local pinBlip = AddBlipForCoord(zoneCoords.x, zoneCoords.y, zoneCoords.z)
        SetBlipSprite(pinBlip, 587)
        SetBlipColour(pinBlip, 2)
        SetBlipAsShortRange(pinBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString((Config.Lang.dumpster_zone or "Dumpster Zone ") .. zoneIndex)
        EndTextCommandSetBlipName(pinBlip)

        table.insert(missionBlips, areaBlip)
        table.insert(missionBlips, pinBlip)

        Zone.SphereZone({
            debug = false,
            coords = zoneCoords,
            radius = mission.ZoneRadius,
            onEnter = function()
                TriggerServerEvent("envi-dumpsters:server:UpdateMissionProgress", 1, { ["zone_" .. zoneIndex .. "_visited"] = true })
                RemoveBlip(areaBlip)
                RemoveBlip(pinBlip)
            end,
        })
    end

    Framework.Notify(Config.Lang.visit_zones, "info")
end

local function FindNearestObject(coords, maxDistance)
    local objects = GetGamePool("CObject")
    local nearest = nil
    local nearestDistance = maxDistance

    for _, object in ipairs(objects) do
        local distance = #(coords - GetEntityCoords(object))
        if nearestDistance > distance then
            nearestDistance = distance
            nearest = object
        end
    end

    return nearest
end

local activeRatCount = 0

function StartRatProblemsMission(mission)
    local allAreas = {}
    for _, area in ipairs(mission.RatAreas) do
        table.insert(allAreas, area)
    end

    local chosenAreas = {}
    local pool = table.clone(allAreas)
    for i = 1, 3, 1 do
        local index = math.random(1, #pool)
        table.insert(chosenAreas, pool[index])
        table.remove(pool, index)
    end

    for areaIndex, areaCoords in ipairs(chosenAreas) do
        local areaBlip = AddBlipForRadius(areaCoords.x, areaCoords.y, areaCoords.z, mission.AreaRadius)
        SetBlipColour(areaBlip, 1)
        SetBlipAlpha(areaBlip, 128)

        local pinBlip = AddBlipForCoord(areaCoords.x, areaCoords.y, areaCoords.z)
        SetBlipSprite(pinBlip, 442)
        SetBlipColour(pinBlip, 1)
        SetBlipAsShortRange(pinBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(string.format(Config.Lang.rat_infestation_cleared, areaIndex))
        EndTextCommandSetBlipName(pinBlip)

        table.insert(missionBlips, areaBlip)
        table.insert(missionBlips, pinBlip)

        ratZones[areaIndex] = Zone.SphereZone({
            debug = false,
            coords = areaCoords,
            radius = mission.AreaRadius,
            onEnter = function()
                currentRatAreaIndex = areaIndex
            end,
            onExit = function()
                currentRatAreaIndex = nil
            end,
            inside = function()
                Wait(math.random(2500, 10000))

                if activeRatCount < 10 then
                    if not HasModelLoaded("a_c_rat") then
                        Framework.LoadModel("a_c_rat")
                    end

                    local nearest = FindNearestObject(GetEntityCoords(cache.ped), 20.0)
                    local spawnCoords = nearest and GetEntityCoords(nearest) or GetEntityCoords(cache.ped)

                    local rat = CreatePed(4, "a_c_rat", spawnCoords.x + math.random(-5, 5), spawnCoords.y + math.random(-5, 5), spawnCoords.z, 0.0, true, true)
                    activeRatCount = activeRatCount + 1
                    SetEntityAsMissionEntity(rat, true, true)

                    local roll = math.random(1, 10)
                    if roll <= 3 then
                        TaskGoToEntity(rat, cache.ped, 60000, 1.0, 1.0, 0, 0)
                    else
                        TaskWanderStandard(rat, 60000, 10)
                    end

                    SetTimeout(60000, function()
                        SetEntityAsNoLongerNeeded(rat)
                        activeRatCount = activeRatCount - 1
                    end)
                end
            end,
        })
    end
end

RegisterNetEvent("envi-dumpsters:client:useRatBait", function()
    local coords = GetEntityCoords(cache.ped)
    local animDict = "anim@mp_fireworks"
    local animName = "place_firework_4_cone"

    lib.requestAnimDict(animDict)
    TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(5000)
    RemoveAnimDict(animDict)

    Zone.SphereZone({
        debug = Config.DebugMode,
        coords = coords,
        radius = 20.0,
        inside = function()
            Wait(math.random(2500, 10000))

            local nearest = FindNearestObject(coords, 20.0)
            local spawnCoords = nearest and GetEntityCoords(nearest) or GetEntityCoords(cache.ped)

            if activeRatCount < 10 then
                if not HasModelLoaded("a_c_rat") then
                    Framework.LoadModel("a_c_rat")
                end

                local rat = CreatePed(4, "a_c_rat", spawnCoords.x + math.random(-5, 5), spawnCoords.y + math.random(-5, 5), spawnCoords.z, 0.0, true, true)
                activeRatCount = activeRatCount + 1
                SetEntityAsMissionEntity(rat, true, true)

                local roll = math.random(1, 10)
                if roll <= 2 then
                    TaskGoToEntity(rat, cache.ped, 60000, 1.0, 1.0, 0, 0)
                elseif roll <= 8 then
                    TaskGoToCoordAnyMeans(rat, coords.x + math.random(-1, 1), coords.y + math.random(-1, 1), coords.z, 60000, 1.0, 1.0, 0, 0)
                else
                    TaskGoToEntity(rat, cache.ped, 60000, 1.0, 1.0, 0, 0)
                end

                SetTimeout(60000, function()
                    SetEntityAsNoLongerNeeded(rat)
                    activeRatCount = activeRatCount - 1
                end)
            end
        end,
    })

    SetTimeout(Config.RatBaitDuration * 1000, function()
        -- the zone created above is intentionally not captured; matches original (zone reference was never stored, so this cleanup never actually runs)
    end)
end)

AddEventHandler("gameEventTriggered", function(eventName, data)
    if not currentRatAreaIndex then
        return
    end

    if eventName == "CEventNetworkEntityDamage" then
        local victim = data[1]
        local attacker = data[2]
        local isFatal = data[6] == 1

        if attacker == cache.ped then
            if DoesEntityExist(victim) then
                if IsEntityAPed(victim) then
                    if GetEntityModel(victim) == -1011537562 and isFatal then
                        ratKillCounts[currentRatAreaIndex] = (ratKillCounts[currentRatAreaIndex] or 0) + 1

                        if ratKillCounts[currentRatAreaIndex] >= 5 then
                            Framework.TriggerCallback("envi-dumpsters:server:GetMissionProgress", function(missionData)
                                local clearedAreas = missionData.cleared_areas or 0
                                local clearedList = missionData.cleared_list or {}
                                clearedList[currentRatAreaIndex] = true

                                TriggerServerEvent("envi-dumpsters:server:UpdateMissionProgress", 2, {
                                    cleared_areas = clearedAreas + 1,
                                    cleared_list = clearedList,
                                })

                                Framework.Notify("Rat infestation " .. currentRatAreaIndex .. " cleared!", "success")
                                ratZones[currentRatAreaIndex].remove()
                            end, 2)
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler("gameEventTriggered", function(eventName, data)
    if eventName == "CEventNetworkEntityDamage" then
        local victim = data[1]
        local attacker = data[2]
        local isFatal = data[6] == 1
        local weaponHash = tonumber(data[7])

        if attacker == Store.Ped then
            if DoesEntityExist(victim) then
                if IsEntityAPed(victim) then
                    if GetEntityModel(victim) == -1011537562 and isFatal and weaponHash == -1901127961 then
                        TriggerServerEvent("envi-dumpsters:server:ratAttack")
                        Framework.Notify("You've killed a rat with your hobo stick!", "success")
                        Wait(500)
                        GiveWeaponToPed(Store.Ped, -1638292314, 0, false, true)
                        SetPedCanSwitchWeapon(Store.Ped, true)
                        SetCurrentPedWeapon(Store.Ped, -1638292314, true)
                    end
                end
            end
        end
    end
end)

function StartProfessionalBeggarMission()
    Framework.Notify("Use the /beg command in populated areas to earn money.", "info")
end

function StartSupplyChainMission()
    Framework.Notify("Collect 100 junk items by searching dumpsters and trash cans.", "info")
end

local rivalPed = nil
local rivalFleeing = false

function StartBumFightsMission(mission)
    local rivalLocation = mission.RivalLocation

    local areaBlip = AddBlipForRadius(rivalLocation.x, rivalLocation.y, rivalLocation.z, 70.0)
    SetBlipColour(areaBlip, 1)
    SetBlipAlpha(areaBlip, 128)
    table.insert(missionBlips, areaBlip)

    local pinBlip = AddBlipForCoord(rivalLocation.x, rivalLocation.y, rivalLocation.z)
    SetBlipSprite(pinBlip, 280)
    SetBlipColour(pinBlip, 5)
    SetBlipAsShortRange(pinBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Lang.thief_name)
    EndTextCommandSetBlipName(pinBlip)
    SetBlipRoute(pinBlip, true)

    Zone.SphereZone({
        coords = vec3(rivalLocation.x, rivalLocation.y, rivalLocation.z),
        radius = 70.0,
        debug = Config.DebugMode,
        onEnter = function()
            RemoveBlip(pinBlip)

            if not rivalPed then
                local modelHash = GetHashKey("a_m_m_trampbeac_01")
                Framework.LoadModel(modelHash)
                rivalPed = CreatePed(4, modelHash, rivalLocation.x, rivalLocation.y, rivalLocation.z, 0.0, true, true)
                SetEntityAsMissionEntity(rivalPed, true, true)
                SetEntityHeading(rivalPed, rivalLocation.w)
                TaskUseNearestScenarioChainToCoordWarp(rivalPed, rivalLocation.x, rivalLocation.y, rivalLocation.z, 30.0)
                SetPedCombatAttributes(rivalPed, 46, true)
                SetPedCombatAttributes(rivalPed, 2, true)
                SetPedCombatAttributes(rivalPed, 5, true)
                SetPedCombatAttributes(rivalPed, 0, true)
                SetPedFleeAttributes(rivalPed, 0, false)
                SetPedCombatRange(rivalPed, 2)
                SetPedCombatMovement(rivalPed, 3)
                SetPedAccuracy(rivalPed, 80)
                SetPedArmour(rivalPed, 100)

                local pedBlip = AddBlipForEntity(rivalPed)
                SetBlipSprite(pedBlip, 303)
                SetBlipColour(pedBlip, 1)
                SetBlipScale(pedBlip, 0.8)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(Config.Lang.thief_name)
                EndTextCommandSetBlipName(pedBlip)
                table.insert(missionBlips, pedBlip)

                CreateThread(function()
                    while not IsEntityDead(rivalPed) do
                        Wait(1500)
                    end

                    TriggerServerEvent("envi-dumpsters:server:UpdateMissionProgress", 7, { rival_defeated = true })
                    Framework.Notify(Config.Lang.thief_defeated, "success")
                    ClearMissionBlips()
                    Wait(60000)
                    SetPedAsNoLongerNeeded(rivalPed)
                end)

                Zone.SphereZone({
                    coords = vec3(rivalLocation.x, rivalLocation.y, rivalLocation.z),
                    radius = 20.0,
                    debug = Config.DebugMode,
                    onEnter = function()
                        if DoesEntityExist(rivalPed) then
                            if not rivalFleeing then
                                Framework.Notify(Config.Lang.thief_fleeing, "warning")
                                PlayPain(rivalPed, 7, 100)
                                TaskSmartFleePed(rivalPed, cache.ped, 100.0, -1, false, false)
                                rivalFleeing = true
                            end
                        end
                    end,
                })
            end
        end,
    })
end

function StartRaccoonWhispererMission()
    Framework.TriggerCallback("envi-dumpsters:server:GiveRaccoonTreats", function(success, message)
        Framework.Notify(message, success and "success" or "error")
        raccoonTameBusy = false
    end)
end

local function TameRaccoonSequence(entity)
    raccoonTameBusy = true

    TaskTurnPedToFaceEntity(cache.ped, entity, -1)
    Wait(500)
    TaskTurnPedToFaceEntity(entity, cache.ped, -1)
    Wait(500)
    TaskStartScenarioInPlace(cache.ped, "CODE_HUMAN_MEDIC_KNEEL", 0, true)
    Framework.Notify(Config.Lang.taming_raccoon, "info")

    SetTimeout(4000, function()
        ClearPedTasks(cache.ped)

        if not (IsEntityDead(entity) or not DoesEntityExist(entity)) then
            Framework.TriggerCallback("envi-dumpsters:server:TameRaccoon", function(success, message)
                if success then
                    Framework.Notify(message, "success")
                    RacoonPal = entity
                    Entity(entity).state:set("IsTamed", true, true)
                    Wait(2500)

                    local animDict = "creatures@cat@player_action@"
                    local animName = "action_a"
                    Framework.LoadAnimDict(animDict)
                    TaskPlayAnim(entity, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
                    Wait(2500)
                    TaskFollowToOffsetOfEntity(entity, cache.ped, 1.0, 1.0, 0.0, 5.0, -1, 1.0, true)

                    SetTimeout(Config.ItemSettings.racoon_treats.duration * 60000, function()
                        if DoesEntityExist(entity) then
                            ClearPedTasks(entity)
                            Framework.Notify(Config.Lang.raccoon_left, "error")
                            TaskSmartFleePed(entity, cache.ped, 100.0, -1, false, false)

                            SetTimeout(30000, function()
                                ClearPedTasks(entity)
                                TaskWanderStandard(entity, 10.0, 10)
                                if RacoonPal == entity then
                                    RacoonPal = nil
                                end
                            end)
                        end
                    end)

                    ClearMissionBlips()
                else
                    Framework.Notify(message, "error")
                    TaskSmartFleePed(entity, cache.ped, 100.0, -1, false, false)
                    SetTimeout(30000, function()
                        TaskWanderStandard(entity, 10.0, 10)
                    end)
                end
            end)
        end
    end)

    raccoonTameBusy = false
end

if Config.Target then
    Target.AddModel(-333702667, {
        {
            label = "Tame Raccoon",
            icon = "fas fa-paw",
            distance = 2.0,
            canInteract = function(data)
                if raccoonTameBusy then
                    return false
                end
                if Framework.Player.Job.Name ~= Config.HoboJobRole then
                    return false
                end
                return Framework.HasItem("racoon_treats", 1)
            end,
            onSelect = function(data)
                TameRaccoonSequence(data.entity)
            end,
        },
    })
else
    exports["envi-interact"]:InteractionModel(-333702667, {
        {
            name = "raccoon_interaction",
            distance = 2.0,
            radius = 5.0,
            options = {
                {
                    label = "Tame Raccoon",
                    canSee = function()
                        if Framework.Player.Job.Name ~= Config.HoboJobRole then
                            return false
                        end
                        if raccoonTameBusy then
                            return false
                        end
                        return Framework.HasItem("racoon_treats", 1)
                    end,
                    selected = function(data)
                        TameRaccoonSequence(data.entity)
                    end,
                },
            },
        },
    })
end

function StartUltimateChallengeMission(mission)
    Framework.TriggerCallback("envi-dumpsters:server:GetProgression", function(progression)
        if progression.level < 10 then
            Framework.Notify(Config.Lang.must_be_level_ten, "error")
            return
        end

        Framework.TriggerCallback("envi-dumpsters:server:ChallengeHoboKing", function(success, message)
            if success then
                Framework.Notify(message, "success")

                if message:find("inactive") or message:find("no current") then
                    StartKingFight(mission.ChallengeLocation)
                else
                    TriggerServerEvent("envi-dumpsters:server:CompleteKingChallenge")
                end
            else
                Framework.Notify(message, "error")
            end
        end)
    end)
end

function OpenDonateMenu(data)
    local options = {}
    local key = "A"

    for drugType, drugConfig in pairs(Config.XPSettings.DrugDonationXP) do
        table.insert(options, {
            key = key,
            label = (Config.Lang.donate or "Donate") .. " " .. drugConfig.label,
            reaction = "Conversation",
            selected = function(menuData)
                OpenDrugAmountMenu(menuData, drugType)
            end,
        })
        key = string.char(key:byte() + 1)
    end

    table.insert(options, {
        key = "X",
        label = Config.Lang.cancel or "Cancel",
        reaction = "Bye",
        selected = function(menuData)
            exports["envi-interact"]:CloseMenu(menuData.menuID)
        end,
    })

    exports["envi-interact"]:OpenChoiceMenu({
        title = Config.Lang.donate_drugs,
        speech = Config.Lang.donate_drugs_speech,
        menuID = "donate-menu",
        position = "right",
        options = options,
    })
end

function OpenDrugAmountMenu(data, drugType)
    exports["envi-interact"]:UseSlider(data.menuID, {
        title = Config.Lang.donate_amount,
        min = 1,
        max = 10,
        sliderState = "unlocked",
        sliderValue = 1,
        nextState = "disabled",
        confirm = function(amount)
            Framework.TriggerCallback("envi-dumpsters:server:DonateDrugs", function(success, message)
                Framework.Notify(message, success and "success" or "error")
                exports["envi-interact"]:CloseMenu(data.menuID)
            end, drugType, amount)
        end,
    })
end

function OpenBottleCapMenu(data)
    exports["envi-interact"]:UseSlider(data.menuID, {
        title = Config.Lang.donate_caps_xp,
        min = 1,
        max = 100,
        sliderState = "unlocked",
        sliderValue = 10,
        nextState = "disabled",
        confirm = function(amount)
            Framework.TriggerCallback("envi-dumpsters:server:DonateBottleCaps", function(success, message)
                Framework.Notify(message, success and "success" or "error")
                exports["envi-interact"]:CloseMenu(data.menuID)
            end, amount)
        end,
    })
end

function OpenHoboShop()
    Framework.TriggerCallback("envi-dumpsters:server:GetProgression", function(progression)
        if not progression then
            return
        end

        local options = {}

        for level = 1, progression.level, 1 do
            for _, item in ipairs(Config.Unlockables[level] or {}) do
                table.insert(options, {
                    title = item.label,
                    description = item.description .. "\n" .. (Config.Lang.price or "Price") .. ": " .. item.price .. " " .. (Config.Lang.bottle_caps or "bottle caps") .. "\n" .. (Config.Lang.unlocked_at_level or "Unlocked at Level") .. " " .. level,
                    icon = "shopping-cart",
                    onSelect = function()
                        local input = lib.inputDialog(string.format(Config.Lang.purchase_quantity, item.label), {
                            { type = "number", label = "Quantity", default = 1, min = 1, max = 10 },
                        })

                        if input then
                            if input[1] then
                                if input[1] > 0 then
                                    BuyHoboItem(item.name, item.price, input[1])
                                end
                            end
                        end
                    end,
                })
            end
        end

        lib.registerContext({ id = "hobo_shop", title = Config.Lang.hobo_shop_title, options = options })
        lib.showContext("hobo_shop")
    end)
end

function BuyHoboItem(itemName, price, quantity)
    local totalPrice = price * quantity
    Framework.TriggerCallback("envi-dumpsters:server:BuyHoboItem", function(success, message)
        Framework.Notify(message, success and "success" or "error")
    end, itemName, quantity, totalPrice)
end

RegisterNetEvent("envi-dumpsters:client:LevelUp")
AddEventHandler("envi-dumpsters:client:LevelUp", function(level)
    Framework.Notify(string.format(Config.Lang.level_up_notification, level), "success")

    local unlockables = Config.Unlockables[level]
    if unlockables then
        if #unlockables > 0 then
            local labels = ""
            for i, item in ipairs(unlockables) do
                if i == 1 then
                    labels = item.label
                else
                    labels = labels .. ", " .. item.label
                end
            end
            Framework.Notify(string.format(Config.Lang.unlocked_items, labels), "info")
        end
    end

    if level == 10 then
        Framework.Notify(Config.Lang.challenge_king_notification, "info")
    end
end)

-- This first definition of UpdateKingStatus is dead code: the later `function UpdateKingStatus(...)` below
-- reassigns the same global name before this one is ever invoked, matching the original's redundant definitions.
local function UnusedFirstUpdateKingStatus()
    Framework.TriggerCallback("envi-dumpsters:server:IsHoboKing", function(kingStatus)
        isHoboKing = kingStatus
        if isHoboKing then
            if generalRelGroup then
                SetRelationshipBetweenGroups(0, generalRelGroup, playerRelGroup)
            end
        end
    end)
end

AddEventHandler("envi-dumpsters:client:NewKing", function()
    Wait(1000)
    UpdateKingStatus()
end)

function SetupRelationshipGroups()
    if not bodyguardRelGroup then
        bodyguardRelGroup = AddRelationshipGroup("HOBO_BODYGUARDS")
    end
    if not generalRelGroup then
        generalRelGroup = AddRelationshipGroup("HOBO_GENERAL")
    end

    playerRelGroup = GetPedRelationshipGroupHash(PlayerPedId())

    SetRelationshipBetweenGroups(0, bodyguardRelGroup, playerRelGroup)
    SetRelationshipBetweenGroups(0, playerRelGroup, bodyguardRelGroup)
    SetRelationshipBetweenGroups(5, bodyguardRelGroup, GetHashKey("HATES_PLAYER"))

    if isHoboKing then
        SetRelationshipBetweenGroups(0, generalRelGroup, playerRelGroup)
    else
        SetRelationshipBetweenGroups(3, generalRelGroup, playerRelGroup)
    end

    SetRelationshipBetweenGroups(0, bodyguardRelGroup, generalRelGroup)
    SetRelationshipBetweenGroups(0, generalRelGroup, bodyguardRelGroup)
end

CreateThread(function()
    Wait(1000)
    while true do
        Wait(10000)

        local playerCoords = GetEntityCoords(PlayerPedId())
        local peds = GetGamePool("CPed")

        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) then
                if not IsPedDeadOrDying(ped, true) then
                    if ped ~= PlayerPedId() then
                        local model = GetEntityModel(ped)
                        for _, modelName in ipairs(Config.AggressivePeds) do
                            if model == GetHashKey(modelName) then
                                if not TableContains(bodyguards, ped) then
                                    if GetPedRelationshipGroupHash(ped) ~= bodyguardRelGroup then
                                        SetPedRelationshipGroupHash(ped, generalRelGroup)
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

function RecruitBodyguard(entity)
    if not (DoesEntityExist(entity) and #bodyguards < MAX_BODYGUARDS) then
        return
    end

    ClearPedTasksImmediately(entity)
    SetEntityAsMissionEntity(entity, true, true)
    SetPedRelationshipGroupHash(entity, bodyguardRelGroup)
    table.insert(bodyguards, entity)

    local weapons = {
        "WEAPON_BAT", "WEAPON_BOTTLE", "WEAPON_CROWBAR", "WEAPON_GOLFCLUB", "WEAPON_HAMMER",
        "WEAPON_KNIFE", "WEAPON_KNUCKLE", "WEAPON_MACHETE", "WEAPON_SWITCHBLADE", "WEAPON_WRENCH",
        "WEAPON_HOBO_REBAR", "WEAPON_HOBO_DUSTER", "WEAPON_HOBO_OLDMACHETE", "WEAPON_HOBO_TOILET",
        "WEAPON_HOBO_PLANK", "WEAPON_HOBO_PIPE",
    }

    local weaponHash = GetHashKey(weapons[math.random(1, #weapons)])
    GiveWeaponToPed(entity, weaponHash, 1, false, true)
    SetPedArmour(entity, 50)
    SetPedCombatAbility(entity, 100)
    SetPedCombatAttributes(entity, 46, true)
    SetPedCombatAttributes(entity, 5, true)
    SetPedCombatAttributes(entity, 0, true)
    SetPedCombatAttributes(entity, 2, true)
    SetPedCombatAttributes(entity, 3, true)
    SetPedFleeAttributes(entity, 0, false)
    SetPedCombatMovement(entity, 3)
    SetPedCombatRange(entity, 2)
    SetPedAccuracy(entity, 70)
    SetPedAsGroupMember(entity, GetPedGroupIndex(PlayerPedId()))
    SetGroupFormation(GetPedGroupIndex(PlayerPedId()), 4)
    SetPedAsEnemy(entity, false)
    SetPedKeepTask(entity, true)
    TaskSetBlockingOfNonTemporaryEvents(entity, true)

    CreateThread(function()
        while DoesEntityExist(entity) and TableContains(bodyguards, entity) do
            Wait(1000)

            if not IsPedGroupMember(entity, GetPedGroupIndex(PlayerPedId())) then
                SetPedAsGroupMember(entity, GetPedGroupIndex(PlayerPedId()))
            end

            local targetEntity, hasTarget = GetPlayerTargetEntity(PlayerId())
            if hasTarget then
                if DoesEntityExist(targetEntity) then
                    if IsEntityAPed(targetEntity) then
                        TaskCombatPed(entity, targetEntity, 0, 16)
                    end
                end
            else
                local nearbyPeds = Framework.GetNearbyPeds(GetEntityCoords(PlayerPedId()), 5.0)
                for _, pedData in ipairs(nearbyPeds) do
                    if IsPedInCombat(pedData.ped, PlayerPedId()) then
                        TaskCombatPed(entity, pedData.ped, 0, 16)
                        break
                    end
                end
            end

            local entityCoords = GetEntityCoords(entity)
            local playerCoords = GetEntityCoords(PlayerPedId())
            if #(entityCoords - playerCoords) > 50.0 then
                local groundZ, foundGround = GetGroundZFor_3dCoord(playerCoords.x + math.random(-5, 5), playerCoords.y + math.random(-5, 5), playerCoords.z, 0)
                SetEntityCoords(entity, playerCoords.x + math.random(-5, 5), playerCoords.y + math.random(-5, 5), groundZ, false, false, false, false)
            end
        end
    end)

    Framework.Notify(string.format(Config.Lang.bodyguard_recruited, #bodyguards, MAX_BODYGUARDS), "success")
end

function GetNearestEnemyToPed(entity, radius)
    local coords = GetEntityCoords(entity)
    local nearbyPeds = Framework.GetNearbyPeds(coords, radius)
    local nearest = nil
    local nearestDistance = radius

    for _, ped in ipairs(nearbyPeds) do
        if not IsPedInCombat(ped, entity) then
            if not (GetRelationshipBetweenPeds(entity, ped) > 3) then
                goto continueLoop
            end
        end

        local distance = #(coords - GetEntityCoords(ped))
        if nearestDistance > distance then
            nearestDistance = distance
            nearest = ped
        end

        ::continueLoop::
    end

    return nearest
end

if Config.DebugMode then
    RegisterCommand("testspawnhobo", function()
        isHoboKing = true
        SetupRelationshipGroups()
        SetupBodyguardRecruitment()

        local model = Config.AggressivePeds[math.random(#Config.AggressivePeds)]
        local coords = GetEntityCoords(PlayerPedId())
        local modelHash = GetHashKey(model)

        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(10)
        end

        CreatePed(4, modelHash, coords.x, coords.y, coords.z, 0, true, true)
    end, false)
end

function DismissBodyguard(entity)
    if not DoesEntityExist(entity) then
        return
    end

    for index, bodyguard in ipairs(bodyguards) do
        if bodyguard == entity then
            table.remove(bodyguards, index)
            break
        end
    end

    RemovePedFromGroup(entity)
    ClearPedTasksImmediately(entity)
    TaskWanderStandard(entity, 10.0, 10)
    SetPedRelationshipGroupHash(entity, generalRelGroup)
    SetPedCombatAttributes(entity, 46, false)
    SetPedCombatAttributes(entity, 5, false)

    SetTimeout(60000, function()
        if DoesEntityExist(entity) then
            SetPedAsNoLongerNeeded(entity)
        end
    end)

    Framework.Notify(Config.Lang.bodyguard_dismissed, "info")
end

AddEventHandler("gameEventTriggered", function(eventName, data)
    if eventName == "CEventNetworkEntityDamage" then
        local victim = data[1]
        local isFatal = data[6] == 1

        if victim == PlayerPedId() and isFatal then
            for _, bodyguard in ipairs(bodyguards) do
                if DoesEntityExist(bodyguard) then
                    DismissBodyguard(bodyguard)
                end
            end
            bodyguards = {}
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)

        if #bodyguards > 0 then
            if IsPedInCombat(PlayerPedId(), nil) then
                for _, bodyguard in ipairs(bodyguards) do
                    if DoesEntityExist(bodyguard) then
                        if not IsPedDeadOrDying(bodyguard, true) then
                            local meleeTarget = GetMeleeTargetForPed(PlayerPedId())
                            if DoesEntityExist(meleeTarget) then
                                if not IsPedDeadOrDying(meleeTarget, true) then
                                    SetPedCombatAttributes(bodyguard, 46, true)
                                    TaskCombatPed(bodyguard, meleeTarget, 0, 16)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

function SetupBodyguardRecruitment()
    if Config.Target then
        Target.AddModel(Config.AggressivePeds, {
            {
                label = Config.Lang.recruit_bodyguard,
                icon = "fas fa-user-shield",
                distance = 3.0,
                canInteract = function(entity)
                    return isHoboKing and not TableContains(bodyguards, entity) and #bodyguards < MAX_BODYGUARDS
                end,
                onSelect = function(data)
                    RecruitBodyguard(data.entity)
                end,
            },
            {
                label = Config.Lang.dismiss_bodyguard,
                icon = "fas fa-user-times",
                distance = 3.0,
                canInteract = function(entity)
                    return isHoboKing and TableContains(bodyguards, entity)
                end,
                onSelect = function(data)
                    DismissBodyguard(data.entity)
                end,
            },
        })
    else
        for _, model in ipairs(Config.AggressivePeds) do
            exports["envi-interact"]:InteractionModel(GetHashKey(model), {
                {
                    name = "hobo_bodyguard_interaction",
                    distance = 3.0,
                    radius = 1.5,
                    options = {
                        {
                            label = Config.Lang.recruit_bodyguard,
                            canSee = function(data)
                                if type(data) == "table" then
                                    return isHoboKing and not TableContains(bodyguards, data.entity) and #bodyguards < MAX_BODYGUARDS
                                else
                                    return false
                                end
                            end,
                            selected = function(data)
                                RecruitBodyguard(data.entity)
                            end,
                        },
                        {
                            label = Config.Lang.dismiss_bodyguard,
                            canSee = function(data)
                                return isHoboKing and TableContains(bodyguards, data.entity)
                            end,
                            selected = function(data)
                                DismissBodyguard(data.entity)
                            end,
                        },
                    },
                },
            })
        end
    end
end

Framework.OnPlayerLoaded = function()
    Wait(2000)
    SetupRelationshipGroups()
    SetupBodyguardRecruitment()

    Framework.TriggerCallback("envi-dumpsters:server:GetProgression", function(progression)
        if progression then
            if progression.level > 1 then
                Framework.Notify(string.format(Config.Lang.welcome_back, progression.level), "info")
            end
        end
        UpdateKingStatus()
    end)
end

function TableContains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

function UpdateKingStatus()
    Framework.TriggerCallback("envi-dumpsters:server:IsHoboKing", function(kingStatus)
        isHoboKing = kingStatus
        if isHoboKing then
            SetRelationshipBetweenGroups(0, generalRelGroup, playerRelGroup)
        else
            SetRelationshipBetweenGroups(3, generalRelGroup, playerRelGroup)
        end

        local peds = GetGamePool("CPed")
        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) then
                if not IsPedDeadOrDying(ped, true) then
                    if ped ~= PlayerPedId() then
                        local model = GetEntityModel(ped)
                        for _, modelName in ipairs(Config.AggressivePeds) do
                            if model == GetHashKey(modelName) then
                                if not TableContains(bodyguards, ped) then
                                    SetPedRelationshipGroupHash(ped, generalRelGroup)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

RegisterNetEvent("envi-dumpsters:client:NewKingNotification")
AddEventHandler("envi-dumpsters:client:NewKingNotification", function()
    UpdateKingStatus()
end)

RegisterNetEvent("envi-dumpsters:client:RemoveFromGroup", function()
    if #bodyguards > 0 then
        for _, bodyguard in ipairs(bodyguards) do
            DismissBodyguard(bodyguard)
        end
    end

    RemovePedFromGroup(PlayerPedId())
    UpdateKingStatus()
end)
