local function isTrackedJunkItem(itemName)
    for _, tier in pairs(Config.JunkItems.Items) do
        for _, item in pairs(tier.items) do
            if item.name == itemName then
                return true
            end
        end
    end
    return false
end

function AddHoboProgessionLoot(source, netId, coords)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    local identifier = player.Identifier
    local progression = GetPlayerProgression(identifier)
    local level = progression.level

    if 60 >= math.random(1, 100) then
        local amount = math.random(1, math.min(level + 1, 5))

        Framework.AddItem(source, Config.BottleCapItem or "bottle_cap", amount)
        Framework.Notify(
            source,
            string.format(Config.Lang.found_bottle_caps, amount, amount > 1 and "s" or ""),
            "success"
        )
        TriggerEvent("envi-dumpsters:server:BottleCapCollected", source, amount)
    end

    if 100 >= math.random(1, 100) then
        local roll = math.random(1, 100)
        local lootPool

        if roll <= Config.JunkItems.Items.common.chance then
            lootPool = Config.JunkItems.Items.common.items
        elseif roll <= Config.JunkItems.Items.common.chance + Config.JunkItems.Items.uncommon.chance then
            lootPool = Config.JunkItems.Items.uncommon.items
        elseif roll <= Config.JunkItems.Items.common.chance + Config.JunkItems.Items.uncommon.chance + Config.JunkItems.Items.rare.chance then
            lootPool = Config.JunkItems.Items.rare.items
        else
            lootPool = Config.JunkItems.Items.very_rare.items
        end

        for _, item in ipairs(lootPool) do
            if math.random(1, 100) <= item.chance then
                local amount = math.random(item.amount[1], item.amount[2])

                if amount > 0 then
                    Framework.AddItem(source, item.name, amount)
                end

                if level == 5 then
                    if isTrackedJunkItem(item.name) then
                        -- Passes the full progression table (not the identifier) as-is, matching original behavior
                        TriggerEvent("envi-dumpsters:server:TrackJunkItems", amount, progression, source)
                    end
                end
            end
        end
    end

    if level == 1 then
        local missionData = progression.mission_data[1] or {}

        if missionData.visited then
            for zoneIndex, zoneCoords in ipairs(Config.Missions[1].Zones) do
                local distance = #(vector3(coords.x, coords.y, coords.z) - zoneCoords)

                if distance < Config.Missions[1].ZoneRadius then
                    if not missionData.visited[zoneIndex] then
                        missionData.visited[zoneIndex] = true
                        UpdateMissionProgress(identifier, 1, missionData)
                        Framework.Notify(source, string.format(Config.Lang.zone_visited, zoneIndex), "success")

                        local allVisited = true
                        local visitedCount = 0

                        for i = 1, #Config.Missions[1].Zones, 1 do
                            if not missionData.visited[i] then
                                allVisited = false
                            else
                                visitedCount = visitedCount + 1
                            end
                        end

                        Framework.Notify(source, string.format(Config.Lang.mission_progress_zones, visitedCount, 5), "info")

                        if allVisited then
                            CompleteMission(identifier, 1)
                            Framework.Notify(source, Config.Lang.mission_complete_return, "success")
                        end

                        break
                    end
                end
            end
        else
            local visited = {}

            for i = 1, #Config.Missions[1].Zones, 1 do
                visited[i] = false
            end

            for zoneIndex, zoneCoords in ipairs(Config.Missions[1].Zones) do
                local distance = #(vector3(coords.x, coords.y, coords.z) - zoneCoords)

                if distance < Config.Missions[1].ZoneRadius then
                    visited[zoneIndex] = true
                    Framework.Notify(source, string.format(Config.Lang.zone_visited, zoneIndex), "success")
                    break
                end
            end

            UpdateMissionProgress(identifier, 1, { visited = visited })
        end
    elseif level == 6 then
        local missionData = progression.mission_data[6] or {}
        local dumpstersSearched = (missionData.dumpsters_searched or 0) + 1
        missionData.dumpsters_searched = dumpstersSearched

        if dumpstersSearched >= Config.Missions[6].RequiredDumpsters then
            if not missionData.package_found then
                if Config.Missions[6].PackageChance >= math.random(1, 100) then
                    missionData.package_found = true
                    Framework.AddItem(source, "medical_care_package", 1)
                    Framework.Notify(source, Config.Lang.found_medical_package, "success")
                end
            end
        end

        UpdateMissionProgress(identifier, 6, missionData)
    end
end

RegisterNetEvent("envi-dumpsters:server:deleteEntity", function(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end)
