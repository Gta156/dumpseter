local reclaimUnitProps = {}
local reclaimUnitData = {}
local reclaimCycleRunning = {}

local function BuildReclaimUnits()
    for locationId, location in pairs(Config.ReclaimUnitLocations) do
        local prop = CreateObject(-1698683516, location.coords.x, location.coords.y, location.coords.z - 1.0, false, false, false)
        SetEntityHeading(prop, location.heading)
        FreezeEntityPosition(prop, true)
        SetEntityAsMissionEntity(prop, true, true)

        reclaimUnitProps[#reclaimUnitProps + 1] = prop

        reclaimUnitData[locationId] = {
            prop = prop,
            busy = false,
            location = location.coords,
        }

        if Config.Target then
            Target.AddEntity(prop, {
                {
                    label = Config.Lang.open_recycler,
                    icon = "fas fa-recycle",
                    onSelect = function()
                        Framework.TriggerCallback("bl_scav:CheckRecyclerStatus", function(canOpen)
                            if not canOpen then
                                Framework.Notify(Config.Lang.recycler_in_use, "error")
                                return
                            end
                            ShowReclaimUnit(locationId)
                        end, locationId)
                    end,
                },
                {
                    label = Config.Lang.use_recycler,
                    icon = "fas fa-cogs",
                    onSelect = function()
                        Framework.TriggerCallback("bl_scav:server:isRecyclerUnlocked", function(isUnlocked)
                            if not isUnlocked then
                                Framework.Notify(Config.Lang.recycler_level_error, "error")
                                return
                            end
                            BeginReclaimCycle(locationId)
                        end)
                    end,
                },
            })
        else
            print("no target")
            exports["envi-interact"]:InteractionEntity(prop, {
                {
                    name = "recycler_interaction",
                    distance = 2.0,
                    radius = 5.0,
                    options = {
                        {
                            label = Config.Lang.open_recycler_e,
                            selected = function()
                                Framework.TriggerCallback("bl_scav:CheckRecyclerStatus", function(canOpen)
                                    if not canOpen then
                                        Framework.Notify(Config.Lang.recycler_in_use, "error")
                                        return
                                    end
                                    ShowReclaimUnit(locationId)
                                end, locationId)
                            end,
                        },
                        {
                            label = Config.Lang.use_recycler_e,
                            selected = function()
                                Framework.TriggerCallback("bl_scav:server:isRecyclerUnlocked", function(isUnlocked)
                                    if not isUnlocked then
                                        Framework.Notify(Config.Lang.recycler_level_error, "error")
                                        return
                                    end
                                    BeginReclaimCycle(locationId)
                                end)
                            end,
                        },
                    },
                },
            })
        end
    end
end

function ShowReclaimUnit(locationId)
    local stashId = "bl_scav_reclaim_" .. locationId
    Framework.OpenStash(stashId)
end

function BeginReclaimCycle(locationId)
    Framework.TriggerCallback("bl_scav:CheckRecyclerStatus", function(canStart)
        if not canStart then
            Framework.Notify(Config.Lang.recycler_in_use, "error")
            return
        end
        TriggerServerEvent("bl_scav:StartRecycling", locationId)
    end, locationId)
end

RegisterNetEvent("bl_scav:StartRecyclingEffect", function(locationId, duration)
    local data = reclaimUnitData[locationId]
    if not data then
        return
    end

    local prop = data.prop
    if not DoesEntityExist(prop) then
        return
    end

    data.busy = true
    reclaimCycleRunning[locationId] = true

    local propCoords = GetEntityCoords(prop)
    local pedCoords = GetEntityCoords(PlayerPedId())
    if #(propCoords - pedCoords) <= 5.0 then
        PlaySoundFromEntity(-1, "container_detach", prop, "dlc_vw_slot_machines_sounds", true, 0)
    end

    local swayAmplitude = 0.2

    CreateThread(function()
        local startTime = GetGameTimer()
        local endTime = startTime + (duration * 1000)

        while endTime > GetGameTimer() and DoesEntityExist(prop) do
            local swayOffset = math.sin(GetGameTimer() * 0.01) * swayAmplitude -- computed but unused, kept to match original
            local coords = GetEntityCoords(prop)
            SetEntityCoordsNoOffset(
                prop,
                coords.x + (math.random(-1, 1) * 0.001),
                coords.y + (math.random(-1, 1) * 0.001),
                coords.z,
                true, true, true
            )

            if GetGameTimer() % 500 < 50 then
                if #(coords - GetEntityCoords(PlayerPedId())) <= 5.0 then
                    PlaySoundFromEntity(-1, "Drill_Pin_Break", prop, "DLC_HEIST_FLEECA_SOUNDSET", true, 0)
                end
            end

            Wait(0)
        end

        if DoesEntityExist(prop) then
            SetEntityCoordsNoOffset(prop, data.location.x, data.location.y, data.location.z - 1.0, true, true, true)
            SetEntityHeading(prop, Config.ReclaimUnitLocations[locationId].heading)

            local pedCoords2 = GetEntityCoords(PlayerPedId())
            local propCoords2 = GetEntityCoords(prop)
            if #(propCoords2 - pedCoords2) <= 5.0 then
                PlaySoundFromEntity(-1, "container_attach", prop, "dlc_vw_slot_machines_sounds", true, 0)
            end
        end
    end)
end)

RegisterNetEvent("bl_scav:RecyclerCompleted", function(locationId, _unused)
    local data = reclaimUnitData[locationId]
    if data then
        data.busy = false
    end

    reclaimCycleRunning[locationId] = nil

    if data then
        if DoesEntityExist(data.prop) then
            local pedCoords = GetEntityCoords(PlayerPedId())
            local propCoords = GetEntityCoords(data.prop)
            if #(propCoords - pedCoords) <= 5.0 then
                PlaySoundFromEntity(-1, "container_attach", data.prop, "dlc_vw_slot_machines_sounds", true, 0)
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    for _, prop in pairs(reclaimUnitProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
end)

CreateThread(function()
    while not Framework.Player.Identifier do
        Wait(500)
    end

    BuildReclaimUnits()
end)
