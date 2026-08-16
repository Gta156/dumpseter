--[[ ==========================================================================
     BlackLight Dumpsters — Salvage Reclaimer (server)
========================================================================== ]]

local random = math.random
local insert = table.insert

local reclaimerBusy = {}
local reclaimerFinishAt = {}

local IDLE_TICK_MS = 1000
local STASH_PREFIX = "bl_reclaimer_"

-- Register a feedstock stash for every configured reclaimer site.
CreateThread(function()
    for siteId in pairs(Settings.ReclaimerSites) do
        Framework.RegisterStash(STASH_PREFIX .. siteId, 20, 100000)
    end
end)

--- Converts every eligible item in a reclaimer stash into its output material.
---@return boolean processedAnything
local function ProcessReclaimer(containerId)
    local inventory = Framework.GetInventory(containerId)
    if not inventory then
        return false
    end

    local conversions = {}

    for slot, item in pairs(inventory) do
        local recipe = Settings.ReclaimRecipes[item.name]
        if recipe then
            insert(conversions, {
                name = item.name,
                count = item.count,
                slot = slot,
                recipe = recipe,
            })
        end
    end

    -- Remove all feedstock first, then deposit the outputs.
    for _, entry in ipairs(conversions) do
        Framework.RemoveItem(containerId, entry.name, entry.count, nil, entry.slot)
    end

    for _, entry in ipairs(conversions) do
        local amount = random(entry.recipe.min, entry.recipe.max) * entry.count
        if amount > 0 then
            Framework.AddItem(containerId, entry.recipe.output, amount)
        end
    end

    return #conversions > 0
end

Framework.CreateCallback("bl_dumpsters:server:IsReclaimerFree", function(source, cb, siteId)
    cb(not reclaimerBusy[siteId])
end)

RegisterNetEvent("bl_dumpsters:server:SetReclaimerBusy", function(siteId, busy)
    local playerSource = source
    if not Framework.GetPlayer(playerSource) then
        return
    end

    if not Settings.ReclaimerSites[siteId] then
        return
    end

    if busy then
        reclaimerBusy[siteId] = true
        reclaimerFinishAt[siteId] = os.time() + Settings.ReclaimerBehaviour.cycleSeconds
    else
        reclaimerBusy[siteId] = nil
        reclaimerFinishAt[siteId] = nil
    end
end)

RegisterNetEvent("bl_dumpsters:server:RunReclaimCycle", function(siteId)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "reclaim_cycle", 2000) then
        return
    end

    local site = Settings.ReclaimerSites[siteId]
    if not site then
        return
    end

    -- The player must actually be standing at the machine.
    if not GuardProximity(playerSource, site.coords, 10.0) then
        Framework.Notify(playerSource, Settings.Text.exploit_detected, "error")
        return
    end

    if reclaimerBusy[siteId] then
        Framework.Notify(playerSource, Settings.Text.reclaimer_busy, "error")
        return
    end

    reclaimerBusy[siteId] = true
    reclaimerFinishAt[siteId] = os.time() + Settings.ReclaimerBehaviour.cycleSeconds

    TriggerClientEvent("bl_dumpsters:client:ReclaimCycleEffect", -1, siteId, Settings.ReclaimerBehaviour.cycleSeconds)
    Framework.Notify(playerSource, Settings.Text.reclaim_cycle_started, "success")
end)

-- Cycle watcher. Idles at 1000ms and only does work when a cycle is due.
CreateThread(function()
    while true do
        Wait(IDLE_TICK_MS)

        local now = os.time()

        for siteId, finishAt in pairs(reclaimerFinishAt) do
            if finishAt <= now then
                ProcessReclaimer(STASH_PREFIX .. siteId)
                reclaimerBusy[siteId] = nil
                reclaimerFinishAt[siteId] = nil
                TriggerClientEvent("bl_dumpsters:client:ReclaimCycleDone", -1, siteId)
            end
        end
    end
end)
