--[[ ==========================================================================
     BlackLight Dumpsters — Salvage Drops & Chapter Hooks (server)
     --------------------------------------------------------------------------
     Every successful container search routes through here so that currency,
     salvage tiers and chapter progression all resolve in one place.
========================================================================== ]]

local random, min = math.random, math.min

local CURRENCY_DROP_CHANCE = 60

--- Is this item part of any salvage tier? (used for Salvage Run tracking)
local function IsSalvageItem(itemName)
    for _, tier in pairs(Settings.SalvageTiers.Tiers) do
        for _, entry in pairs(tier.items) do
            if entry.name == itemName then
                return true
            end
        end
    end
    return false
end

--- Rolls a salvage tier and returns its item list.
local function RollSalvageTier()
    local tiers = Settings.SalvageTiers.Tiers
    local roll = random(1, 100)

    local commonCeiling = tiers.common.chance
    local uncommonCeiling = commonCeiling + tiers.uncommon.chance
    local rareCeiling = uncommonCeiling + tiers.rare.chance

    if roll <= commonCeiling then
        return tiers.common.items
    elseif roll <= uncommonCeiling then
        return tiers.uncommon.items
    elseif roll <= rareCeiling then
        return tiers.rare.items
    end

    return tiers.very_rare.items
end

--- Chapter 1 — logs which signature district the search took place in.
local function TrackDistrictExploration(playerSource, identifier, chapterState, coords)
    local districts = Settings.Chapters[1].Districts
    local radius = Settings.Chapters[1].DistrictRadius
    local searchCoords = vector3(coords.x, coords.y, coords.z)

    -- First ever search: seed the visited table.
    if not chapterState.visited then
        local visited = {}
        for i = 1, #districts do
            visited[i] = false
        end

        for index, districtCoords in ipairs(districts) do
            if #(searchCoords - districtCoords) < radius then
                visited[index] = true
                Framework.Notify(playerSource, string.format(Settings.Text.district_logged, index), "success")
                break
            end
        end

        PushChapterProgress(identifier, 1, { visited = visited })
        return
    end

    for index, districtCoords in ipairs(districts) do
        if #(searchCoords - districtCoords) < radius and not chapterState.visited[index] then
            chapterState.visited[index] = true
            PushChapterProgress(identifier, 1, chapterState)
            Framework.Notify(playerSource, string.format(Settings.Text.district_logged, index), "success")

            local allVisited, visitedCount = true, 0
            for i = 1, #districts do
                if chapterState.visited[i] then
                    visitedCount = visitedCount + 1
                else
                    allVisited = false
                end
            end

            Framework.Notify(playerSource, string.format(Settings.Text.district_tracker, visitedCount, 5), "info")

            if allVisited then
                CloseChapter(identifier, 1)
                Framework.Notify(playerSource, Settings.Text.chapter_report_back, "success")
            end

            break
        end
    end
end

--- Chapter 6 — counts searches and eventually surfaces the medical parcel.
local function TrackParcelHunt(playerSource, identifier, chapterState)
    local searched = (chapterState.dumpsters_searched or 0) + 1
    chapterState.dumpsters_searched = searched

    if searched >= Settings.Chapters[6].TargetContainers and not chapterState.package_found then
        if random(1, 100) <= Settings.Chapters[6].ParcelChance then
            chapterState.package_found = true
            Framework.AddItem(playerSource, "medical_care_package", 1)
            Framework.Notify(playerSource, Settings.Text.parcel_recovered, "success")
        end
    end

    PushChapterProgress(identifier, 6, chapterState)
end

--- Called after every successful container search.
--- Awards currency, rolls salvage and advances any relevant chapter.
function AwardSalvageAndProgress(playerSource, netId, coords)
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    local identifier = player.Identifier
    local standing = FetchStanding(identifier)
    local rank = standing.level

    -- 1. Currency drop (scales gently with rank)
    if random(1, 100) <= CURRENCY_DROP_CHANCE then
        local amount = random(1, min(rank + 1, 5))

        Framework.AddItem(playerSource, Settings.CurrencyItem or "bottle_cap", amount)
        Framework.Notify(
            playerSource,
            string.format(Settings.Text.currency_found, amount, amount > 1 and "s" or ""),
            "success"
        )

        TriggerEvent("bl_dumpsters:server:CurrencyCollected", playerSource, amount)
    end

    -- 2. Salvage tier roll
    local tierItems = RollSalvageTier()

    for _, entry in ipairs(tierItems) do
        if random(1, 100) <= entry.chance then
            local amount = random(entry.amount[1], entry.amount[2])

            if amount > 0 then
                Framework.AddItem(playerSource, entry.name, amount)
            end

            -- Chapter 5 counts salvage pieces towards the quota.
            if rank == 5 and IsSalvageItem(entry.name) then
                TriggerEvent("bl_dumpsters:server:TrackSalvageHaul", playerSource, amount, standing)
            end
        end
    end

    -- 3. Rank-specific chapter tracking
    if rank == 1 then
        TrackDistrictExploration(playerSource, identifier, standing.mission_data[1] or {}, coords)
    elseif rank == 6 then
        TrackParcelHunt(playerSource, identifier, standing.mission_data[6] or {})
    end
end
