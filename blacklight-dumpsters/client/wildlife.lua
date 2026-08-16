--[[ ==========================================================================
     BlackLight Dumpsters — Ambient Wildlife (client)
     Swaps a portion of the ambient cat population for masked bandits.
========================================================================== ]]

local random = math.random

local BANDIT_MODEL = -333702667  -- enviraccoon
local AMBIENT_CAT_MODEL = 1462895032
local SWAP_CHANCE = 50
local DESPAWN_MS = 120000

CreateThread(function()
    Framework.LoadModel(BANDIT_MODEL)
end)

AddEventHandler("populationPedCreating", function(x, y, z, model, _)
    if cache.vehicle then
        return
    end

    if not IsEntityVisible(cache.ped) then
        return
    end

    if model ~= AMBIENT_CAT_MODEL then
        return
    end

    if random(1, 100) > SWAP_CHANCE then
        return
    end

    if not HasModelLoaded(BANDIT_MODEL) then
        return
    end

    local bandit = CreatePed(0, BANDIT_MODEL, x + 0.2, y, z, 0.0, true, true)
    TaskWanderStandard(bandit, 10.0, 10)
    SetPedFleeAttributes(bandit, 1, true)

    SetTimeout(DESPAWN_MS, function()
        SetPedAsNoLongerNeeded(bandit)
    end)

    CancelEvent()
end)
