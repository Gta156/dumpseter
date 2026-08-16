local function isSalvageTracked(itemName)
    for _, tier in pairs(Config.SalvageTable.Items) do
        for _, item in pairs(tier.items) do
            if item.name == itemName then
                return true
            end
        end
    end
    return false
end

function AwardStreetProgressLoot(source, netId, coords)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    local identifier = player.Identifier
    local progression = FetchStreetRecord(identifier)
    local level = progression.level

    if 60 >= math.random(1, 100) then
        local amount = math.random(1, math.min(level + 1, 5))

        Framework.AddItem(source, Config.CapCurrencyItem or "bottle_cap", amount)
        Framework.Notify(
            source,
            string.format(Config.Lang.found_bottle_caps, amount, amount > 1 and "s" or ""),
            "success"
        )
        TriggerEvent("bl_scav:server:BottleCapCollected", source, amount)
    end

    -- The original guarded this block with `if 100 >= math.random(1,100)`, which is always
    -- true. Keeping the behaviour (salvage always rolls) but dropping the dead comparison so
    -- the intent is explicit rather than looking like a chance that was meant to be tunable.
    do
        local roll = math.random(1, 100)
        local lootPool

        if roll <= Config.SalvageTable.Items.common.chance then
            lootPool = Config.SalvageTable.Items.common.items
        elseif roll <= Config.SalvageTable.Items.common.chance + Config.SalvageTable.Items.uncommon.chance then
            lootPool = Config.SalvageTable.Items.uncommon.items
        elseif roll <= Config.SalvageTable.Items.common.chance + Config.SalvageTable.Items.uncommon.chance + Config.SalvageTable.Items.rare.chance then
            lootPool = Config.SalvageTable.Items.rare.items
        else
            lootPool = Config.SalvageTable.Items.very_rare.items
        end

        for _, item in ipairs(lootPool) do
            if math.random(1, 100) <= item.chance then
                local amount = math.random(item.amount[1], item.amount[2])

                if amount > 0 then
                    Framework.AddItem(source, item.name, amount)
                end

                if level == 5 then
                    if isSalvageTracked(item.name) then
                        -- Passes the full progression table (not the identifier) as-is, matching original behavior
                        TriggerEvent("bl_scav:server:TrackJunkItems", amount, progression, source)
                    end
                end
            end
        end
    end

    if level == 1 then
        local missionData = progression.mission_data[1] or {}

        if missionData.visited then
            for zoneIndex, zoneCoords in ipairs(Config.Contracts[1].Zones) do
                local distance = #(vector3(coords.x, coords.y, coords.z) - zoneCoords)

                if distance < Config.Contracts[1].ZoneRadius then
                    if not missionData.visited[zoneIndex] then
                        missionData.visited[zoneIndex] = true
                        AdvanceContract(identifier, 1, missionData)
                        Framework.Notify(source, string.format(Config.Lang.zone_visited, zoneIndex), "success")

                        local allVisited = true
                        local visitedCount = 0

                        for i = 1, #Config.Contracts[1].Zones, 1 do
                            if not missionData.visited[i] then
                                allVisited = false
                            else
                                visitedCount = visitedCount + 1
                            end
                        end

                        Framework.Notify(source, string.format(Config.Lang.mission_progress_zones, visitedCount, 5), "info")

                        if allVisited then
                            FinalizeContract(identifier, 1)
                            Framework.Notify(source, Config.Lang.mission_complete_return, "success")
                        end

                        break
                    end
                end
            end
        else
            local visited = {}

            for i = 1, #Config.Contracts[1].Zones, 1 do
                visited[i] = false
            end

            for zoneIndex, zoneCoords in ipairs(Config.Contracts[1].Zones) do
                local distance = #(vector3(coords.x, coords.y, coords.z) - zoneCoords)

                if distance < Config.Contracts[1].ZoneRadius then
                    visited[zoneIndex] = true
                    Framework.Notify(source, string.format(Config.Lang.zone_visited, zoneIndex), "success")
                    break
                end
            end

            AdvanceContract(identifier, 1, { visited = visited })
        end
    elseif level == 6 then
        local missionData = progression.mission_data[6] or {}
        local dumpstersSearched = (missionData.dumpsters_searched or 0) + 1
        missionData.dumpsters_searched = dumpstersSearched

        if dumpstersSearched >= Config.Contracts[6].RequiredDumpsters then
            if not missionData.package_found then
                if Config.Contracts[6].PackageChance >= math.random(1, 100) then
                    missionData.package_found = true
                    Framework.AddItem(source, "medical_care_package", 1)
                    Framework.Notify(source, Config.Lang.found_medical_package, "success")
                end
            end
        end

        AdvanceContract(identifier, 6, missionData)
    end
end

--[[
    Prop cleanup after looting a deletable operator searchable.

    The original deleted ANY entity whose network id a client sent -- vehicles, other
    players' props, mission entities, anything. It is a one-line server wipe primitive.

    Deletion is now allowed only when the entity is really one of the models configured as a
    deletable searchable in BLScav_OperatorProps, and only when the caller is standing next
    to it. Anything else is ignored and flagged.
]]
local deletableSearchableModels

--- Build (once) the set of model hashes that operator config marks as deleteProp.
local function GetDeletableModels()
    if deletableSearchableModels then
        return deletableSearchableModels
    end

    deletableSearchableModels = {}
    for _, custom in ipairs(BLScav_OperatorProps or {}) do
        if custom.deleteProp and custom.models then
            for _, model in ipairs(custom.models) do
                deletableSearchableModels[GetHashKey(model)] = true
            end
        end
    end
    return deletableSearchableModels
end

RegisterNetEvent("bl_scav:server:deleteEntity", function(netId)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end

    if not Security.RateLimit(src, "delete_prop", 500) then
        return
    end

    local entity = Security.ResolveEntity(netId, true)
    if not entity then
        return
    end

    -- Must be a prop the operator explicitly configured as deletable.
    if not GetDeletableModels()[GetEntityModel(entity)] then
        Security.Flag(src, "requested deletion of an entity that is not a deletable searchable")
        return
    end

    -- ...and the player must actually be there.
    if not Security.IsPlayerNear(src, GetEntityCoords(entity), 12.0) then
        Security.Flag(src, "requested deletion of a distant entity")
        return
    end

    DeleteEntity(entity)
end)
