--[[ ==========================================================================
     BlackLight Dumpsters — Core Scavenging Loop (server)
========================================================================== ]]

local random, floor = math.random, math.floor

local depletedContainers = {}
local depletedAnchors = {}
local treasureSpent = {}
local occupiedSkips = {}
local skipOccupant = {}
local knownStashes = {}

local SEARCH_COOLDOWN_MS = 1200

-- --------------------------------------------------------------------------
--  DEPLETION BOOKKEEPING
-- --------------------------------------------------------------------------

local function QueueDepletionReset(netId)
    SetTimeout(Settings.ContainerRefreshMinutes * 60000, function()
        depletedContainers[netId] = nil
        depletedAnchors[netId] = nil
    end)
end

local function QueueTreasureReset(netId)
    SetTimeout(Settings.ContainerRefreshMinutes * 60000, function()
        treasureSpent[netId] = nil
    end)
end

--- Blocks a second player from farming the exact same container position.
local function AnchorAlreadyDepleted(coords)
    for _, anchor in pairs(depletedAnchors) do
        if #(coords - anchor) < 1.0 then
            return true
        end
    end
    return false
end

local function MarkDepleted(netId, coords)
    if not netId then
        return
    end
    depletedContainers[netId] = true
    depletedAnchors[netId] = coords
    QueueDepletionReset(netId)
end

-- --------------------------------------------------------------------------
--  WEIGHTED LOOT SELECTION
-- --------------------------------------------------------------------------

--- Picks an index from a loot table weighted by inverse rarity.
--- A rarity of 90 is far less likely to be drawn than a rarity of 10.
local function RollWeightedIndex(pool)
    if not (pool[1] and pool[1].rarity) then
        return random(1, #pool)
    end

    local weights, totalWeight = {}, 0

    for i, entry in ipairs(pool) do
        local weight = 100 - (entry.rarity or 50)
        if weight < 1 then
            weight = 1
        end
        weights[i] = weight
        totalWeight = totalWeight + weight
    end

    local roll = random(1, totalWeight)
    local running = 0

    for i, weight in ipairs(weights) do
        running = running + weight
        if roll <= running then
            return i
        end
    end

    return random(1, #pool)
end

-- --------------------------------------------------------------------------
--  LOOT DISPENSING
-- --------------------------------------------------------------------------

--- Grants a batch of distinct loot entries and marks the container depleted.
local function DispenseLoot(playerSource, pool, netId, coords)
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if depletedContainers[netId] then
        Framework.Notify(playerSource, Settings.Text.container_empty, "error")
        return
    end

    if AnchorAlreadyDepleted(coords) then
        Framework.Notify(playerSource, Settings.Text.try_elsewhere, "error")
        return
    end

    if Settings.StrictEntityValidation then
        local entityValid = GuardEntity(netId)
        if not entityValid then
            Framework.Notify(playerSource, Settings.Text.exploit_detected, "error")
            return
        end
    end

    if not pool or #pool == 0 then
        return
    end

    local drawn = {}
    local picks = random(Settings.LootRoll.minPicks, Settings.LootRoll.maxPicks)

    for _ = 1, picks do
        local index, attempts = nil, 0

        -- Keep drawing until we hit an entry we have not already granted.
        repeat
            index = RollWeightedIndex(pool)
            attempts = attempts + 1
        until not drawn[index] or attempts > #pool

        if not drawn[index] then
            local entry = pool[index]
            if entry then
                local amount = random(entry.min, entry.max)
                if amount > 0 then
                    Framework.AddItem(playerSource, entry.name, amount, entry.metadata)
                end
                drawn[index] = true
                MarkDepleted(netId, coords)
            end
        end
    end

    AwardSalvageAndProgress(playerSource, netId, coords)
end

--- Grants a single bonus treasure entry (once per container cooldown).
local function DispenseTreasure(playerSource, pool, netId)
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if Settings.StrictEntityValidation then
        local entityValid = GuardEntity(netId)
        if not entityValid then
            Framework.Notify(playerSource, Settings.Text.exploit_detected, "error")
            return
        end
    end

    if treasureSpent[netId] or not pool or #pool == 0 then
        return
    end

    local entry = pool[RollWeightedIndex(pool)]
    if not entry then
        return
    end

    local amount = random(entry.min, entry.max)
    if amount > 0 then
        Framework.AddItem(playerSource, entry.name, amount, entry.metadata)
    end

    if netId then
        treasureSpent[netId] = true
        QueueTreasureReset(netId)
    end
end

--- Loot dispenser for burst refuse sacks (no distinct-entry guarantee).
local function DispenseSackLoot(playerSource, pool, netId, coords)
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if depletedContainers[netId] then
        Framework.Notify(playerSource, Settings.Text.container_empty, "error")
        return
    end

    if AnchorAlreadyDepleted(coords) then
        Framework.Notify(playerSource, Settings.Text.search_elsewhere, "error")
        return
    end

    if not pool or #pool == 0 then
        return
    end

    for _ = 1, random(Settings.LootRoll.minPicks, Settings.LootRoll.maxPicks) do
        local entry = pool[RollWeightedIndex(pool)]
        if entry then
            local amount = random(entry.min, entry.max)
            if amount > 0 then
                Framework.AddItem(playerSource, entry.name, amount, entry.metadata)
            end
            MarkDepleted(netId, coords)
        end
    end
end

--- Grants exactly one entry from a pool with no bookkeeping.
local function DispenseSingle(playerSource, pool)
    if not pool or #pool == 0 then
        return
    end

    local entry = pool[RollWeightedIndex(pool)]
    if not entry then
        return
    end

    local amount = random(entry.min, entry.max)
    if amount > 0 then
        Framework.AddItem(playerSource, entry.name, amount, entry.metadata)
    end
end

-- --------------------------------------------------------------------------
--  DISTRICT RESOLUTION
-- --------------------------------------------------------------------------

--- Resolves the loot pool to use — the district's bespoke table or the default.
local function ResolvePool(districtIndex, defaultPool)
    if not districtIndex then
        return defaultPool
    end

    local district = Settings.SignatureLootDistricts[districtIndex]
    if not district then
        return defaultPool
    end

    if random(1, 100) <= district.chance then
        return district.items
    end

    return defaultPool
end

--- Shared body behind every container-family loot callback.
local function HandleContainerLoot(playerSource, netId, coords, districtIndex, defaultPool, treasurePool, treasureChance, actionKey)
    if not GuardRate(playerSource, actionKey, SEARCH_COOLDOWN_MS) then
        return
    end

    if depletedContainers[netId] then
        Framework.Notify(playerSource, Settings.Text.container_empty, "error")
        return
    end

    if not GuardProximity(playerSource, coords) then
        Framework.Notify(playerSource, Settings.Text.exploit_detected, "error")
        return
    end

    DispenseLoot(playerSource, ResolvePool(districtIndex, defaultPool), netId, coords)

    if random(1, 100) <= treasureChance then
        DispenseTreasure(playerSource, treasurePool, netId)
    end
end

-- --------------------------------------------------------------------------
--  LOOT CALLBACKS
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:LootSeasideBin", function(source, cb, netId, coords, districtIndex)
    HandleContainerLoot(source, netId, coords, districtIndex,
        Settings.SeasideBinLoot, Settings.SeasideBinTreasure, Settings.SeasideBinTreasureChance, "loot_seaside")
    cb(true)
end)

Framework.CreateCallback("bl_dumpsters:server:LootSkip", function(source, cb, netId, coords, districtIndex)
    HandleContainerLoot(source, netId, coords, districtIndex,
        Settings.SkipLoot, Settings.SkipTreasure, Settings.SkipTreasureChance, "loot_skip")
    cb(true)
end)

Framework.CreateCallback("bl_dumpsters:server:LootWasteBin", function(source, cb, netId, coords, districtIndex)
    HandleContainerLoot(source, netId, coords, districtIndex,
        Settings.WasteBinLoot, Settings.WasteBinTreasure, Settings.WasteBinTreasureChance, "loot_wastebin")
    cb(true)
end)

Framework.CreateCallback("bl_dumpsters:server:LootEncampment", function(source, cb, netId, coords, districtIndex)
    HandleContainerLoot(source, netId, coords, districtIndex,
        Settings.EncampmentLoot, Settings.EncampmentTreasure, Settings.EncampmentTreasureChance, "loot_encampment")
    cb(true)
end)

Framework.CreateCallback("bl_dumpsters:server:LootRefuseSack", function(source, cb, netId, coords, districtIndex)
    if not GuardRate(source, "loot_sack", SEARCH_COOLDOWN_MS) then
        return cb(false)
    end

    DispenseSackLoot(source, ResolvePool(districtIndex, Settings.RefuseSackLoot), netId, coords)

    if random(1, 100) <= Settings.RefuseSackTreasureChance then
        DispenseSingle(source, Settings.RefuseSackTreasure)
    end

    cb(true)
end)

Framework.CreateCallback("bl_dumpsters:server:LootBespoke", function(source, cb, netId, coords, districtIndex, bespokeIndex)
    if not GuardRate(source, "loot_bespoke", SEARCH_COOLDOWN_MS) then
        return cb(false)
    end

    if depletedContainers[netId] then
        Framework.Notify(source, Settings.Text.container_empty, "error")
        return cb(false)
    end

    local bespoke = Settings.BespokeSearchables[bespokeIndex]
    if not bespoke then
        return cb(false)
    end

    if AnchorAlreadyDepleted(coords) then
        Framework.Notify(source, Settings.Text.try_elsewhere, "error")
        return cb(false)
    end

    if not GuardProximity(source, coords) then
        Framework.Notify(source, Settings.Text.exploit_detected, "error")
        return cb(false)
    end

    if Settings.StrictEntityValidation then
        local entityValid = GuardEntity(netId)
        if not entityValid then
            Framework.Notify(source, Settings.Text.exploit_detected, "error")
            return cb(false)
        end
    end

    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false)
    end

    -- A signature district can override the prop's own loot table entirely.
    if districtIndex then
        local district = Settings.SignatureLootDistricts[districtIndex]
        if district and random(1, 100) <= district.chance then
            DispenseLoot(source, district.items, netId, coords)
            return cb(true)
        end
    end

    if bespoke.loot and #bespoke.loot > 0 then
        DispenseLoot(source, bespoke.loot, netId, coords)
    end

    cb(true)
end)

-- --------------------------------------------------------------------------
--  CONTAINER STASHES
-- --------------------------------------------------------------------------

--- Deterministic per-position stash key.
function HashPosition(coords)
    return ("%.0f%.0f%.0f"):format(coords.x, coords.y, coords.z)
end

--- Registers (or re-registers) a per-container stash and hands back its key.
local function RegisterContainerStash(playerSource, coords, prefix, slots, weight, actionKey, cb)
    if not GuardRate(playerSource, actionKey, SEARCH_COOLDOWN_MS) then
        return cb(nil)
    end

    if not GuardProximity(playerSource, coords) then
        Framework.Notify(playerSource, Settings.Text.exploit_detected, "error")
        return cb(nil)
    end

    local hash = HashPosition(coords)
    Framework.RegisterStash(prefix .. hash, slots, weight)
    knownStashes[prefix .. hash] = true

    cb(hash)
end

Framework.CreateCallback("bl_dumpsters:server:OpenSeasideBin", function(source, cb, netId, coords)
    RegisterContainerStash(source, coords, "Beach", Settings.SeasideBinSlots, Settings.SeasideBinWeight, "stash_seaside", cb)
end)

Framework.CreateCallback("bl_dumpsters:server:OpenSkip", function(source, cb, netId, coords)
    RegisterContainerStash(source, coords, "Dumpster", Settings.SkipSlots, Settings.SkipWeight, "stash_skip", cb)
end)

Framework.CreateCallback("bl_dumpsters:server:OpenWasteBin", function(source, cb, netId, coords)
    RegisterContainerStash(source, coords, "Garbage", Settings.WasteBinSlots, Settings.WasteBinWeight, "stash_wastebin", cb)
end)

Framework.CreateCallback("bl_dumpsters:server:OpenEncampment", function(source, cb, netId, coords)
    RegisterContainerStash(source, coords, "Hobo", Settings.EncampmentSlots, Settings.EncampmentWeight, "stash_encampment", cb)
end)

-- --------------------------------------------------------------------------
--  SKIP CONCEALMENT
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:server:FlagSkipOccupied", function(netId, occupied)
    local playerSource = source

    if not netId then
        return
    end

    occupiedSkips[netId] = occupied and true or nil
    skipOccupant[netId] = occupied and playerSource or nil
end)

Framework.CreateCallback("bl_dumpsters:server:IsSkipVacant", function(source, cb, netId)
    if not occupiedSkips[netId] then
        return cb(true)
    end

    -- Somebody is already inside: evict them and deny this attempt.
    Framework.Notify(source, Settings.Text.skip_taken, "error")

    local occupant = skipOccupant[netId]
    if occupant then
        TriggerClientEvent("bl_dumpsters:client:EvictFromSkip", occupant)
    end

    skipOccupant[netId] = nil
    occupiedSkips[netId] = nil

    cb(false)
end)

-- --------------------------------------------------------------------------
--  INFORMANTS
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:server:ReportScavenger", function(coords, districtIndex)
    local playerSource = source

    if not GuardRate(playerSource, "informant", 3000) then
        return
    end

    local district = Settings.SignatureLootDistricts[districtIndex]
    if not (district and district.watched) then
        return
    end

    if not GuardProximity(playerSource, coords) then
        return
    end

    local chance = tonumber(district.informantChance)
    if not chance then
        return
    end

    if random(1, 100) <= chance then
        TriggerClientEvent("bl_dumpsters:client:InformantAlert", -1, coords, district.alertJobs or {})
    end
end)

-- --------------------------------------------------------------------------
--  ENTITY CLEANUP
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:server:PurgeEntity", function(netId)
    if not GuardRate(source, "purge_entity", 500) then
        return
    end

    local exists, entity = GuardEntity(netId)
    if exists then
        DeleteEntity(entity)
    end
end)

-- --------------------------------------------------------------------------
--  OPTIONAL STASH WIPE ON RESTART
-- --------------------------------------------------------------------------

if Settings.WipeStorageOnRestart then
    AddEventHandler("onResourceStop", function(resourceName)
        if GetCurrentResourceName() ~= resourceName then
            return
        end

        for stashId in pairs(knownStashes) do
            Framework.ClearInventory(stashId)
        end
    end)
end
