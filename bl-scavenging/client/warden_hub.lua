local streetWardenNPC = nil
local contractBlips = {}
local verminZones = {}
local activeVerminAreaIndex = nil
local verminKillCounts = {}
local critterTamingBusy = false
BLScav_CritterCompanion = nil
BLScav_LifetimeVagrant = false
local streetEscorts = {}
local MAX_STREET_ESCORTS = 3
local isStreetWarden = false
local escortRelGroup = nil
local generalRelGroup = nil
local playerRelGroup = nil

if Config.DiagnosticsEnabled then
    RegisterCommand("tphk", function()
        SetEntityCoords(cache.ped, Config.StreetWarden.Position.x + 2, Config.StreetWarden.Position.y, Config.StreetWarden.Position.z)
    end, false)

    RegisterCommand("testTrolley", function()
        local model = BLSCAV_TROLLEY_MODELS[3]
        local coords = GetEntityCoords(cache.ped)
        Framework.LoadModel(model)
        local cart = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)

        if BLScav_PushingTrolley then
            return
        end

        BLScav_ActiveTrolley = cart
        GripTrolley(BLScav_ActiveTrolley)
    end, false)

    RegisterCommand("testbodyguards", function()
        isStreetWarden = not isStreetWarden
        Framework.Notify("Hobo King status set to: " .. tostring(isStreetWarden), "info")
        if isStreetWarden then
            ConfigureFactionGroups()
        end
    end, false)

    RegisterCommand("spawnbodyguard", function()
        if isStreetWarden and #streetEscorts < MAX_STREET_ESCORTS then
            local coords = GetEntityCoords(cache.ped)
            local offset = math.random(-3, 3)
            local model = Config.HostileVagrantModels[math.random(#Config.HostileVagrantModels)]
            local modelHash = GetHashKey(model)

            RequestModel(modelHash)
            while not HasModelLoaded(modelHash) do
                Wait(10)
            end

            local ped = CreatePed(4, modelHash, coords.x + offset, coords.y + offset, coords.z, 0.0, true, true)
            SetModelAsNoLongerNeeded(modelHash)
            HireStreetEscort(ped)
        else
            Framework.Notify("You must be the Hobo King and have fewer than 3 bodyguards.", "error")
        end
    end, false)
end

CreateThread(function()
    Wait(1000)

    if Config.DisableProgressionFeatures then
        return
    end

    local position = Config.StreetWarden.Position

    streetWardenNPC = exports["envi-interact"]:CreateNPC({
        name = "hoboking",
        model = Config.StreetWarden.Model,
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
                    ShowProgressPanel(data)
                end,
            },
            {
                key = "M",
                label = Config.Lang.current_mission,
                reaction = "Conversation",
                selected = function(data)
                    ShowContractBoard(data)
                end,
            },
            {
                key = "T",
                label = Config.Lang.hobo_tasks,
                reaction = "Conversation",
                canSee = function()
                    local progression = Framework.TriggerCallback.Await("bl_scav:server:GetProgression")
                    cachedTaskProgression = progression
                    return progression.level >= Config.Contracts[10].unlockLevel
                end,
                selected = function()
                    Framework.TriggerCallback("bl_scav:server:GetTaskHistory", function(history)
                        local tasks = Config.Contracts[10].Tasks
                        local hasActiveTask = false

                        for _ in pairs(exports["bl-scavenging"]:GetActiveTasks() or {}) do
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
                                    TriggerServerEvent("bl_scav:server:StartStreetHustlerTask", task.type)

                                    if task.type == "hobo_taxi" then
                                        Framework.Notify(Config.Lang.hobo_taxi_started, "success")
                                        LaunchCartFareRun()
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
                    ShowTributeMenu(data)
                end,
            },
            {
                key = "B",
                label = Config.Lang.donate_caps,
                reaction = "Thanks",
                stayOpen = true,
                selected = function(data)
                    ShowCapTributeMenu(data)
                end,
            },
            {
                key = "S",
                label = Config.Lang.hobo_shop,
                reaction = "Conversation",
                selected = function(data)
                    exports["envi-interact"]:CloseMenu(data.menuID)
                    ShowStreetMarket()
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
        if streetWardenNPC then
            DeleteEntity(streetWardenNPC)
        end
    end
end)

function ShowProgressPanel(data)
    Framework.TriggerCallback("bl_scav:server:GetProgression", function(progression)
        if not progression then
            exports["envi-interact"]:UpdateSpeech(data.menuID, Config.Lang.id_error)
            return
        end

        local nextLevel = progression.level + 1
        local xpToNextRank = Config.ProgressionSettings.RankThresholds[nextLevel]
        if not xpToNextRank then
            xpToNextRank = "MAX"
        end

        local percent = 100
        if nextLevel <= 10 then
            percent = math.floor((progression.xp / Config.ProgressionSettings.RankThresholds[nextLevel]) * 100) or 100
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

        local atMaxRank = progression.level == 10
        local promotionLabel = Config.Lang.level_up
        if atMaxRank then
            promotionLabel = Config.Lang.challenge_king
        end

        local options = {
            {
                key = "E",
                label = promotionLabel,
                selected = function(menuData)
                    AttemptRankPromotion(progression)
                    exports["envi-interact"]:CloseMenu(menuData.menuID)
                    exports["envi-interact"]:CloseMenu("hobo-xp-bar")
                end,
            },
        }

        if atMaxRank then
            table.insert(options, {
                key = "L",
                label = Config.Lang.buy_freedom,
                selected = function(menuData)
                    exports["envi-interact"]:UpdateSpeech(menuData.menuID, Config.Lang.freedom_cost_msg)

                    local result = lib.alertDialog({
                        header = Config.Lang.freedom_title,
                        content = string.format(Config.Lang.freedom_description, Config.StreetWarden.FreedomCost),
                        size = "lg",
                        cancel = true,
                        labels = { cancel = Config.Lang.no, confirm = Config.Lang.yes_sure },
                    })

                    if result == "confirm" then
                        TriggerServerEvent("bl_scav:server:BuyYourFreedom")
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
                                ShowProgressPanel(returnData)
                            end,
                        },
                        {
                            key = "M",
                            label = Config.Lang.current_mission,
                            reaction = "Conversation",
                            selected = function(returnData)
                                ShowContractBoard(returnData)
                            end,
                        },
                        {
                            key = "T",
                            label = Config.Lang.hobo_tasks,
                            reaction = "Conversation",
                            canSee = function()
                                local freshProgression = Framework.TriggerCallback.Await("bl_scav:server:GetProgression")
                                progression = freshProgression
                                return progression.level >= Config.Contracts[10].unlockLevel
                            end,
                            selected = function()
                                Framework.TriggerCallback("bl_scav:server:GetTaskHistory", function(history)
                                    local tasks = Config.Contracts[10].Tasks
                                    local hasActiveTask = false

                                    for _ in pairs(exports["bl-scavenging"]:GetActiveTasks() or {}) do
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
                                                TriggerServerEvent("bl_scav:server:StartStreetHustlerTask", task.type)

                                                if task.type == "hobo_taxi" then
                                                    Framework.Notify(Config.Lang.hobo_taxi_started, "success")
                                                    LaunchCartFareRun()
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
                                ShowTributeMenu(returnData)
                            end,
                        },
                        {
                            key = "B",
                            label = Config.Lang.donate_caps,
                            reaction = "Thanks",
                            stayOpen = true,
                            selected = function(returnData)
                                ShowCapTributeMenu(returnData)
                            end,
                        },
                        {
                            key = "S",
                            label = Config.Lang.hobo_shop,
                            reaction = "Conversation",
                            selected = function(returnData)
                                exports["envi-interact"]:CloseMenu(returnData.menuID)
                                ShowStreetMarket()
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

function AttemptRankPromotion(progression)
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
            LaunchWardenGauntlet()
        end
        return
    end

    if progression.xp < Config.ProgressionSettings.RankThresholds[nextLevel] then
        Framework.Notify(Config.Lang.not_enough_xp, "error")
        return
    end

    local missionName = ResolveRankContractName(progression.level)
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

    TriggerServerEvent("bl_scav:server:LevelUp")
end

function ResolveRankContractName(level)
    return Config.Contracts[level].name or nil
end

local lastJobUpdateCheck = 500
local lastJobUpdateTime = 0

Framework.OnJobUpdate = function()
    local now = GetGameTimer()
    if now - lastJobUpdateTime < lastJobUpdateCheck then
        return
    end
    lastJobUpdateTime = now

    Framework.TriggerCallback("bl_scav:server:isTrueHobo", function(isLifetimeVagrant)
        if isLifetimeVagrant then
            BLScav_LifetimeVagrant = true
        end
    end)
end

function ShowUnlockCatalogue(level, data)
    local unlockables = Config.UnlockCatalogue[level] or {}
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

function ShowContractBoard(data)
    Framework.TriggerCallback("bl_scav:server:GetProgression", function(progression)
        if not progression then
            return
        end

        local level = progression.level
        local missionName = ResolveRankContractName(level)
        if not missionName then
            exports["envi-interact"]:UpdateSpeech(data.menuID, Config.Lang.no_mission)
        end

        local mission = Config.Contracts[level]
        local missionData = progression.mission_data[level] or {}
        local completed = missionData.completed or false

        local speech = DescribeContract(missionName)
        if completed then
            speech = DescribeFinishedContract(missionName)
        end

        local options = {}

        table.insert(options, {
            key = "S",
            label = completed and (Config.Lang.completed or "Completed \226\156\148") or (Config.Lang.start_mission or "Start Mission"),
            selected = function(menuData)
                if completed then
                    Framework.Notify(Config.Lang.already_completed, "error")
                else
                    LaunchContract(missionName, mission)
                    exports["envi-interact"]:CloseMenu(menuData.menuID)
                end
            end,
        })

        if missionName == Config.Contracts[6].name then
            if missionData.package_found then
                if not missionData.package_delivered then
                    table.insert(options, {
                        key = "D",
                        label = Config.Lang.deliver_package or "Deliver Package",
                        selected = function(menuData)
                            Framework.TriggerCallback("bl_scav:server:DeliverMedicalPackage", function(success, message)
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

local function ResolveRankByContractName(name)
    for level, mission in pairs(Config.Contracts) do
        if mission.name == name then
            return level
        end
    end
end

function DescribeContract(name)
    local level = ResolveRankByContractName(name)
    return Config.Contracts[level].description or "What brings you here?"
end

function DescribeFinishedContract(name)
    local level = ResolveRankByContractName(name)
    return Config.Contracts[level].descriptionCompleted or "You've done what needed to be done. The community respects that."
end

function LaunchContract(name, mission)
    PurgeContractBlips()

    if name == Config.Contracts[1].name then
        LaunchOrientationContract(mission)
    elseif name == Config.Contracts[2].name then
        LaunchVerminPurgeContract(mission)
    elseif name == Config.Contracts[3].name then
        LaunchPanhandleContract(mission)
    elseif name == Config.Contracts[4].name then
        LaunchDownhillContract()
    elseif name == Config.Contracts[5].name then
        LaunchSupplyRunContract(mission)
    elseif name == Config.Contracts[6].name then
        Framework.Notify("Continue searching dumpsters to find a Medical Care Package", "info")
    elseif name == Config.Contracts[7].name then
        LaunchStreetBrawlContract(mission)
    elseif name == Config.Contracts[8].name then
        LaunchCritterBondContract(mission)
    elseif name == Config.Contracts[9].name then
        LaunchCartFareRun()
    end

    Framework.Notify(string.format(Config.Lang.mission_started, name), "success")
end

function PurgeContractBlips()
    for _, blip in ipairs(contractBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    contractBlips = {}
end

function LaunchOrientationContract(mission)
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

        table.insert(contractBlips, areaBlip)
        table.insert(contractBlips, pinBlip)

        Zone.SphereZone({
            debug = false,
            coords = zoneCoords,
            radius = mission.ZoneRadius,
            onEnter = function()
                TriggerServerEvent("bl_scav:server:UpdateMissionProgress", 1, { ["zone_" .. zoneIndex .. "_visited"] = true })
                RemoveBlip(areaBlip)
                RemoveBlip(pinBlip)
            end,
        })
    end

    Framework.Notify(Config.Lang.visit_zones, "info")
end

local function FindClosestProp(coords, maxDistance)
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

local activeVerminCount = 0

function LaunchVerminPurgeContract(mission)
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

        table.insert(contractBlips, areaBlip)
        table.insert(contractBlips, pinBlip)

        verminZones[areaIndex] = Zone.SphereZone({
            debug = false,
            coords = areaCoords,
            radius = mission.AreaRadius,
            onEnter = function()
                activeVerminAreaIndex = areaIndex
            end,
            onExit = function()
                activeVerminAreaIndex = nil
            end,
            inside = function()
                Wait(math.random(2500, 10000))

                if activeVerminCount < 10 then
                    if not HasModelLoaded("a_c_rat") then
                        Framework.LoadModel("a_c_rat")
                    end

                    local nearest = FindClosestProp(GetEntityCoords(cache.ped), 20.0)
                    local spawnCoords = nearest and GetEntityCoords(nearest) or GetEntityCoords(cache.ped)

                    local rat = CreatePed(4, "a_c_rat", spawnCoords.x + math.random(-5, 5), spawnCoords.y + math.random(-5, 5), spawnCoords.z, 0.0, true, true)
                    activeVerminCount = activeVerminCount + 1
                    SetEntityAsMissionEntity(rat, true, true)

                    local roll = math.random(1, 10)
                    if roll <= 3 then
                        TaskGoToEntity(rat, cache.ped, 60000, 1.0, 1.0, 0, 0)
                    else
                        TaskWanderStandard(rat, 60000, 10)
                    end

                    SetTimeout(60000, function()
                        SetEntityAsNoLongerNeeded(rat)
                        activeVerminCount = activeVerminCount - 1
                    end)
                end
            end,
        })
    end
end

RegisterNetEvent("bl_scav:client:useRatBait", function()
    local coords = GetEntityCoords(cache.ped)
    local animDict = "anim@mp_fireworks"
    local animName = "place_firework_4_cone"

    lib.requestAnimDict(animDict)
    TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(5000)
    RemoveAnimDict(animDict)

    Zone.SphereZone({
        debug = Config.DiagnosticsEnabled,
        coords = coords,
        radius = 20.0,
        inside = function()
            Wait(math.random(2500, 10000))

            local nearest = FindClosestProp(coords, 20.0)
            local spawnCoords = nearest and GetEntityCoords(nearest) or GetEntityCoords(cache.ped)

            if activeVerminCount < 10 then
                if not HasModelLoaded("a_c_rat") then
                    Framework.LoadModel("a_c_rat")
                end

                local rat = CreatePed(4, "a_c_rat", spawnCoords.x + math.random(-5, 5), spawnCoords.y + math.random(-5, 5), spawnCoords.z, 0.0, true, true)
                activeVerminCount = activeVerminCount + 1
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
                    activeVerminCount = activeVerminCount - 1
                end)
            end
        end,
    })

    SetTimeout(Config.VerminBaitDuration * 1000, function()
        -- the zone created above is intentionally not captured; matches original (zone reference was never stored, so this cleanup never actually runs)
    end)
end)

AddEventHandler("gameEventTriggered", function(eventName, data)
    if not activeVerminAreaIndex then
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
                        verminKillCounts[activeVerminAreaIndex] = (verminKillCounts[activeVerminAreaIndex] or 0) + 1

                        if verminKillCounts[activeVerminAreaIndex] >= 5 then
                            Framework.TriggerCallback("bl_scav:server:GetMissionProgress", function(missionData)
                                local clearedAreas = missionData.cleared_areas or 0
                                local clearedList = missionData.cleared_list or {}
                                clearedList[activeVerminAreaIndex] = true

                                TriggerServerEvent("bl_scav:server:UpdateMissionProgress", 2, {
                                    cleared_areas = clearedAreas + 1,
                                    cleared_list = clearedList,
                                })

                                Framework.Notify("Rat infestation " .. currentRatAreaIndex .. " cleared!", "success")
                                verminZones[activeVerminAreaIndex].remove()
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
                        TriggerServerEvent("bl_scav:server:ratAttack")
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

function LaunchPanhandleContract()
    Framework.Notify("Use the /beg command in populated areas to earn money.", "info")
end

function LaunchSupplyRunContract()
    Framework.Notify("Collect 100 junk items by searching dumpsters and trash cans.", "info")
end

local challengerPed = nil
local challengerFleeing = false

function LaunchStreetBrawlContract(mission)
    local challengerSpot = mission.RivalLocation

    local areaBlip = AddBlipForRadius(challengerSpot.x, challengerSpot.y, challengerSpot.z, 70.0)
    SetBlipColour(areaBlip, 1)
    SetBlipAlpha(areaBlip, 128)
    table.insert(contractBlips, areaBlip)

    local pinBlip = AddBlipForCoord(challengerSpot.x, challengerSpot.y, challengerSpot.z)
    SetBlipSprite(pinBlip, 280)
    SetBlipColour(pinBlip, 5)
    SetBlipAsShortRange(pinBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.Lang.thief_name)
    EndTextCommandSetBlipName(pinBlip)
    SetBlipRoute(pinBlip, true)

    Zone.SphereZone({
        coords = vec3(challengerSpot.x, challengerSpot.y, challengerSpot.z),
        radius = 70.0,
        debug = Config.DiagnosticsEnabled,
        onEnter = function()
            RemoveBlip(pinBlip)

            if not challengerPed then
                local modelHash = GetHashKey("a_m_m_trampbeac_01")
                Framework.LoadModel(modelHash)
                challengerPed = CreatePed(4, modelHash, challengerSpot.x, challengerSpot.y, challengerSpot.z, 0.0, true, true)
                SetEntityAsMissionEntity(challengerPed, true, true)
                SetEntityHeading(challengerPed, challengerSpot.w)
                TaskUseNearestScenarioChainToCoordWarp(challengerPed, challengerSpot.x, challengerSpot.y, challengerSpot.z, 30.0)
                SetPedCombatAttributes(challengerPed, 46, true)
                SetPedCombatAttributes(challengerPed, 2, true)
                SetPedCombatAttributes(challengerPed, 5, true)
                SetPedCombatAttributes(challengerPed, 0, true)
                SetPedFleeAttributes(challengerPed, 0, false)
                SetPedCombatRange(challengerPed, 2)
                SetPedCombatMovement(challengerPed, 3)
                SetPedAccuracy(challengerPed, 80)
                SetPedArmour(challengerPed, 100)

                local pedBlip = AddBlipForEntity(challengerPed)
                SetBlipSprite(pedBlip, 303)
                SetBlipColour(pedBlip, 1)
                SetBlipScale(pedBlip, 0.8)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(Config.Lang.thief_name)
                EndTextCommandSetBlipName(pedBlip)
                table.insert(contractBlips, pedBlip)

                CreateThread(function()
                    while not IsEntityDead(challengerPed) do
                        Wait(1500)
                    end

                    TriggerServerEvent("bl_scav:server:UpdateMissionProgress", 7, { rival_defeated = true })
                    Framework.Notify(Config.Lang.thief_defeated, "success")
                    PurgeContractBlips()
                    Wait(60000)
                    SetPedAsNoLongerNeeded(challengerPed)
                end)

                Zone.SphereZone({
                    coords = vec3(challengerSpot.x, challengerSpot.y, challengerSpot.z),
                    radius = 20.0,
                    debug = Config.DiagnosticsEnabled,
                    onEnter = function()
                        if DoesEntityExist(challengerPed) then
                            if not challengerFleeing then
                                Framework.Notify(Config.Lang.thief_fleeing, "warning")
                                PlayPain(challengerPed, 7, 100)
                                TaskSmartFleePed(challengerPed, cache.ped, 100.0, -1, false, false)
                                challengerFleeing = true
                            end
                        end
                    end,
                })
            end
        end,
    })
end

function LaunchCritterBondContract()
    Framework.TriggerCallback("bl_scav:server:GiveRaccoonTreats", function(success, message)
        Framework.Notify(message, success and "success" or "error")
        critterTamingBusy = false
    end)
end

local function RunCritterTamingSequence(entity)
    critterTamingBusy = true

    TaskTurnPedToFaceEntity(cache.ped, entity, -1)
    Wait(500)
    TaskTurnPedToFaceEntity(entity, cache.ped, -1)
    Wait(500)
    TaskStartScenarioInPlace(cache.ped, "CODE_HUMAN_MEDIC_KNEEL", 0, true)
    Framework.Notify(Config.Lang.taming_raccoon, "info")

    SetTimeout(4000, function()
        ClearPedTasks(cache.ped)

        if not (IsEntityDead(entity) or not DoesEntityExist(entity)) then
            Framework.TriggerCallback("bl_scav:server:TameRaccoon", function(success, message)
                if success then
                    Framework.Notify(message, "success")
                    BLScav_CritterCompanion = entity
                    Entity(entity).state:set("IsTamed", true, true)
                    Wait(2500)

                    local animDict = "creatures@cat@player_action@"
                    local animName = "action_a"
                    Framework.LoadAnimDict(animDict)
                    TaskPlayAnim(entity, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
                    Wait(2500)
                    TaskFollowToOffsetOfEntity(entity, cache.ped, 1.0, 1.0, 0.0, 5.0, -1, 1.0, true)

                    SetTimeout(Config.GearSettings.racoon_treats.duration * 60000, function()
                        if DoesEntityExist(entity) then
                            ClearPedTasks(entity)
                            Framework.Notify(Config.Lang.raccoon_left, "error")
                            TaskSmartFleePed(entity, cache.ped, 100.0, -1, false, false)

                            SetTimeout(30000, function()
                                ClearPedTasks(entity)
                                TaskWanderStandard(entity, 10.0, 10)
                                if BLScav_CritterCompanion == entity then
                                    BLScav_CritterCompanion = nil
                                end
                            end)
                        end
                    end)

                    PurgeContractBlips()
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

    critterTamingBusy = false
end

if Config.Target then
    Target.AddModel(-333702667, {
        {
            label = "Tame Raccoon",
            icon = "fas fa-paw",
            distance = 2.0,
            canInteract = function(data)
                if critterTamingBusy then
                    return false
                end
                if Framework.Player.Job.Name ~= Config.VagrantJobRole then
                    return false
                end
                return Framework.HasItem("racoon_treats", 1)
            end,
            onSelect = function(data)
                RunCritterTamingSequence(data.entity)
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
                        if Framework.Player.Job.Name ~= Config.VagrantJobRole then
                            return false
                        end
                        if critterTamingBusy then
                            return false
                        end
                        return Framework.HasItem("racoon_treats", 1)
                    end,
                    selected = function(data)
                        RunCritterTamingSequence(data.entity)
                    end,
                },
            },
        },
    })
end

function LaunchApexContract(mission)
    Framework.TriggerCallback("bl_scav:server:GetProgression", function(progression)
        if progression.level < 10 then
            Framework.Notify(Config.Lang.must_be_level_ten, "error")
            return
        end

        Framework.TriggerCallback("bl_scav:server:ChallengeHoboKing", function(success, message)
            if success then
                Framework.Notify(message, "success")

                if message:find("inactive") or message:find("no current") then
                    StartKingFight(mission.ChallengeLocation)
                else
                    TriggerServerEvent("bl_scav:server:CompleteKingChallenge")
                end
            else
                Framework.Notify(message, "error")
            end
        end)
    end)
end

function ShowTributeMenu(data)
    local options = {}
    local key = "A"

    for drugType, drugConfig in pairs(Config.ProgressionSettings.ContrabandTributeXP) do
        table.insert(options, {
            key = key,
            label = (Config.Lang.donate or "Donate") .. " " .. drugConfig.label,
            reaction = "Conversation",
            selected = function(menuData)
                ShowContrabandQuantityMenu(menuData, drugType)
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

function ShowContrabandQuantityMenu(data, drugType)
    exports["envi-interact"]:UseSlider(data.menuID, {
        title = Config.Lang.donate_amount,
        min = 1,
        max = 10,
        sliderState = "unlocked",
        sliderValue = 1,
        nextState = "disabled",
        confirm = function(amount)
            Framework.TriggerCallback("bl_scav:server:DonateDrugs", function(success, message)
                Framework.Notify(message, success and "success" or "error")
                exports["envi-interact"]:CloseMenu(data.menuID)
            end, drugType, amount)
        end,
    })
end

function ShowCapTributeMenu(data)
    exports["envi-interact"]:UseSlider(data.menuID, {
        title = Config.Lang.donate_caps_xp,
        min = 1,
        max = 100,
        sliderState = "unlocked",
        sliderValue = 10,
        nextState = "disabled",
        confirm = function(amount)
            Framework.TriggerCallback("bl_scav:server:DonateBottleCaps", function(success, message)
                Framework.Notify(message, success and "success" or "error")
                exports["envi-interact"]:CloseMenu(data.menuID)
            end, amount)
        end,
    })
end

function ShowStreetMarket()
    Framework.TriggerCallback("bl_scav:server:GetProgression", function(progression)
        if not progression then
            return
        end

        local options = {}

        for level = 1, progression.level, 1 do
            for _, item in ipairs(Config.UnlockCatalogue[level] or {}) do
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
                                    PurchaseMarketGoods(item.name, item.price, input[1])
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

-- The price argument is intentionally ignored: the server prices the purchase from
-- Config.UnlockCatalogue so a tampered client cannot dictate what it pays. It is kept in
-- the signature because the menu builder passes it positionally.
function PurchaseMarketGoods(itemName, _price, quantity)
    Framework.TriggerCallback("bl_scav:server:BuyHoboItem", function(success, message)
        Framework.Notify(message, success and "success" or "error")
    end, itemName, quantity)
end

RegisterNetEvent("bl_scav:client:LevelUp")
AddEventHandler("bl_scav:client:LevelUp", function(level)
    Framework.Notify(string.format(Config.Lang.level_up_notification, level), "success")

    local unlockables = Config.UnlockCatalogue[level]
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
local function LegacyRefreshWardenStatus()
    Framework.TriggerCallback("bl_scav:server:IsHoboKing", function(kingStatus)
        isStreetWarden = kingStatus
        if isStreetWarden then
            if generalRelGroup then
                SetRelationshipBetweenGroups(0, generalRelGroup, playerRelGroup)
            end
        end
    end)
end

AddEventHandler("bl_scav:client:NewKing", function()
    Wait(1000)
    RefreshWardenStatus()
end)

function ConfigureFactionGroups()
    if not escortRelGroup then
        escortRelGroup = AddRelationshipGroup("HOBO_BODYGUARDS")
    end
    if not generalRelGroup then
        generalRelGroup = AddRelationshipGroup("HOBO_GENERAL")
    end

    playerRelGroup = GetPedRelationshipGroupHash(PlayerPedId())

    SetRelationshipBetweenGroups(0, escortRelGroup, playerRelGroup)
    SetRelationshipBetweenGroups(0, playerRelGroup, escortRelGroup)
    SetRelationshipBetweenGroups(5, escortRelGroup, GetHashKey("HATES_PLAYER"))

    if isStreetWarden then
        SetRelationshipBetweenGroups(0, generalRelGroup, playerRelGroup)
    else
        SetRelationshipBetweenGroups(3, generalRelGroup, playerRelGroup)
    end

    SetRelationshipBetweenGroups(0, escortRelGroup, generalRelGroup)
    SetRelationshipBetweenGroups(0, generalRelGroup, escortRelGroup)
end

-- Faction sweep.
--
-- Perf notes vs. the original implementation:
--   * The hostile-model list is hashed ONCE into a lookup set instead of running a
--     nested string->hash comparison for every ped on every sweep. The original did
--     GetHashKey() inside a double loop, i.e. |peds| x |models| native calls each tick.
--   * The sweep only runs while the player is actually a lifetime vagrant / has escorts,
--     because that is the only situation in which the relationship groups matter.
--     Otherwise it idles at a long interval and costs effectively nothing.
local hostileModelSet
local function BuildHostileModelSet()
    if hostileModelSet then return hostileModelSet end
    hostileModelSet = {}
    for _, modelName in ipairs(Config.HostileVagrantModels) do
        hostileModelSet[GetHashKey(modelName)] = true
    end
    return hostileModelSet
end

CreateThread(function()
    Wait(1000)

    while true do
        -- Idle cheaply until the faction system is actually relevant.
        if not BLScav_LifetimeVagrant and #streetEscorts == 0 then
            Wait(15000)
            goto continue
        end

        do
            local models = BuildHostileModelSet()
            local localPed = PlayerPedId()
            local escortLookup = {}
            for i = 1, #streetEscorts do
                escortLookup[streetEscorts[i]] = true
            end

            for _, ped in ipairs(GetGamePool("CPed")) do
                if ped ~= localPed and not escortLookup[ped]
                    and DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true)
                    and models[GetEntityModel(ped)]
                    and GetPedRelationshipGroupHash(ped) ~= escortRelGroup
                then
                    SetPedRelationshipGroupHash(ped, generalRelGroup)
                end
            end
        end

        Wait(10000)
        ::continue::
    end
end)

function HireStreetEscort(entity)
    if not (DoesEntityExist(entity) and #streetEscorts < MAX_STREET_ESCORTS) then
        return
    end

    ClearPedTasksImmediately(entity)
    SetEntityAsMissionEntity(entity, true, true)
    SetPedRelationshipGroupHash(entity, escortRelGroup)
    table.insert(streetEscorts, entity)

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
        while DoesEntityExist(entity) and ListContains(streetEscorts, entity) do
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

    Framework.Notify(string.format(Config.Lang.bodyguard_recruited, #streetEscorts, MAX_STREET_ESCORTS), "success")
end

function FindClosestFoe(entity, radius)
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

if Config.DiagnosticsEnabled then
    RegisterCommand("testspawnhobo", function()
        isStreetWarden = true
        ConfigureFactionGroups()
        BindEscortRecruitment()

        local model = Config.HostileVagrantModels[math.random(#Config.HostileVagrantModels)]
        local coords = GetEntityCoords(PlayerPedId())
        local modelHash = GetHashKey(model)

        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(10)
        end

        CreatePed(4, modelHash, coords.x, coords.y, coords.z, 0, true, true)
    end, false)
end

function ReleaseStreetEscort(entity)
    if not DoesEntityExist(entity) then
        return
    end

    for index, bodyguard in ipairs(streetEscorts) do
        if bodyguard == entity then
            table.remove(streetEscorts, index)
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
            for _, bodyguard in ipairs(streetEscorts) do
                if DoesEntityExist(bodyguard) then
                    ReleaseStreetEscort(bodyguard)
                end
            end
            streetEscorts = {}
        end
    end
end)

-- Escort combat assist.
--
-- Perf notes: with no escorts hired (the overwhelmingly common case) this thread
-- now sleeps for 5s at a time instead of waking every second to evaluate a
-- guaranteed-false branch. The melee target is resolved once per tick rather than
-- once per escort, which removes a redundant native call per bodyguard.
CreateThread(function()
    while true do
        if #streetEscorts == 0 then
            Wait(5000)
            goto continue
        end

        if IsPedInCombat(PlayerPedId(), nil) then
            local brawlTarget = GetMeleeTargetForPed(PlayerPedId())
            if DoesEntityExist(brawlTarget) and not IsPedDeadOrDying(brawlTarget, true) then
                for _, bodyguard in ipairs(streetEscorts) do
                    if DoesEntityExist(bodyguard) and not IsPedDeadOrDying(bodyguard, true) then
                        SetPedCombatAttributes(bodyguard, 46, true)
                        TaskCombatPed(bodyguard, brawlTarget, 0, 16)
                    end
                end
            end
        end

        Wait(1000)
        ::continue::
    end
end)

function BindEscortRecruitment()
    if Config.Target then
        Target.AddModel(Config.HostileVagrantModels, {
            {
                label = Config.Lang.recruit_bodyguard,
                icon = "fas fa-user-shield",
                distance = 3.0,
                canInteract = function(entity)
                    return isStreetWarden and not ListContains(streetEscorts, entity) and #streetEscorts < MAX_STREET_ESCORTS
                end,
                onSelect = function(data)
                    HireStreetEscort(data.entity)
                end,
            },
            {
                label = Config.Lang.dismiss_bodyguard,
                icon = "fas fa-user-times",
                distance = 3.0,
                canInteract = function(entity)
                    return isStreetWarden and ListContains(streetEscorts, entity)
                end,
                onSelect = function(data)
                    ReleaseStreetEscort(data.entity)
                end,
            },
        })
    else
        for _, model in ipairs(Config.HostileVagrantModels) do
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
                                    return isStreetWarden and not ListContains(streetEscorts, data.entity) and #streetEscorts < MAX_STREET_ESCORTS
                                else
                                    return false
                                end
                            end,
                            selected = function(data)
                                HireStreetEscort(data.entity)
                            end,
                        },
                        {
                            label = Config.Lang.dismiss_bodyguard,
                            canSee = function(data)
                                return isStreetWarden and ListContains(streetEscorts, data.entity)
                            end,
                            selected = function(data)
                                ReleaseStreetEscort(data.entity)
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
    ConfigureFactionGroups()
    BindEscortRecruitment()

    Framework.TriggerCallback("bl_scav:server:GetProgression", function(progression)
        if progression then
            if progression.level > 1 then
                Framework.Notify(string.format(Config.Lang.welcome_back, progression.level), "info")
            end
        end
        RefreshWardenStatus()
    end)
end

function ListContains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

function RefreshWardenStatus()
    Framework.TriggerCallback("bl_scav:server:IsHoboKing", function(kingStatus)
        isStreetWarden = kingStatus
        if isStreetWarden then
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
                        for _, modelName in ipairs(Config.HostileVagrantModels) do
                            if model == GetHashKey(modelName) then
                                if not ListContains(streetEscorts, ped) then
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

RegisterNetEvent("bl_scav:client:NewKingNotification")
AddEventHandler("bl_scav:client:NewKingNotification", function()
    RefreshWardenStatus()
end)

RegisterNetEvent("bl_scav:client:RemoveFromGroup", function()
    if #streetEscorts > 0 then
        for _, bodyguard in ipairs(streetEscorts) do
            ReleaseStreetEscort(bodyguard)
        end
    end

    RemovePedFromGroup(PlayerPedId())
    RefreshWardenStatus()
end)
