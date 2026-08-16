--[[ ==========================================================================
     BlackLight Dumpsters — Salvage Reclaimer (client)
========================================================================== ]]

local random, sin = math.random, math.sin

local reclaimerProps = {}
local reclaimerState = {}
local cyclesRunning = {}

local RECLAIMER_MODEL = -1698683516
local AUDIBLE_RANGE = 5.0
local INTERACT = "blacklight-interact"

--- Plays a sound from a prop only when the player is close enough to hear it.
local function PlayNearbySound(prop, soundName, soundSet)
    if not DoesEntityExist(prop) then
        return
    end

    if #(GetEntityCoords(prop) - GetEntityCoords(cache.ped)) <= AUDIBLE_RANGE then
        PlaySoundFromEntity(-1, soundName, prop, soundSet, true, 0)
    end
end

--- Opens the reclaimer's feedstock stash.
function OpenReclaimerStash(siteId)
    Framework.OpenStash("bl_reclaimer_" .. siteId)
end

--- Requests the server start a reclaim cycle at the given site.
function StartReclaimCycle(siteId)
    Framework.TriggerCallback("bl_dumpsters:server:IsReclaimerFree", function(available)
        if not available then
            Framework.Notify(Settings.Text.reclaimer_busy, "error")
            return
        end
        TriggerServerEvent("bl_dumpsters:server:RunReclaimCycle", siteId)
    end, siteId)
end

local function BuildReclaimers()
    for siteId, site in pairs(Settings.ReclaimerSites) do
        local prop = CreateObject(RECLAIMER_MODEL, site.coords.x, site.coords.y, site.coords.z - 1.0, false, false, false)
        SetEntityHeading(prop, site.heading)
        FreezeEntityPosition(prop, true)
        SetEntityAsMissionEntity(prop, true, true)

        reclaimerProps[#reclaimerProps + 1] = prop

        reclaimerState[siteId] = {
            prop = prop,
            busy = false,
            anchor = site.coords,
        }

        local function OnOpenSelected()
            Framework.TriggerCallback("bl_dumpsters:server:IsReclaimerFree", function(available)
                if not available then
                    Framework.Notify(Settings.Text.reclaimer_busy, "error")
                    return
                end
                OpenReclaimerStash(siteId)
            end, siteId)
        end

        local function OnRunSelected()
            Framework.TriggerCallback("bl_dumpsters:server:IsReclaimerUnlocked", function(unlocked)
                if not unlocked then
                    Framework.Notify(Settings.Text.reclaimer_locked, "error")
                    return
                end
                StartReclaimCycle(siteId)
            end)
        end

        if Settings.UseTargetSystem then
            Target.AddEntity(prop, {
                {
                    label = Settings.Text.reclaimer_open,
                    icon = "fas fa-recycle",
                    onSelect = OnOpenSelected,
                },
                {
                    label = Settings.Text.reclaimer_run,
                    icon = "fas fa-cogs",
                    onSelect = OnRunSelected,
                },
            })
        else
            exports[INTERACT]:InteractionEntity(prop, {
                {
                    name = "bl_reclaimer_interaction",
                    distance = 2.0,
                    radius = 5.0,
                    options = {
                        { label = Settings.Text.reclaimer_open_key, selected = OnOpenSelected },
                        { label = Settings.Text.reclaimer_run_key, selected = OnRunSelected },
                    },
                },
            })
        end
    end
end

RegisterNetEvent("bl_dumpsters:client:ReclaimCycleEffect", function(siteId, seconds)
    local state = reclaimerState[siteId]
    if not state then
        return
    end

    local prop = state.prop
    if not DoesEntityExist(prop) then
        return
    end

    state.busy = true
    cyclesRunning[siteId] = true

    PlayNearbySound(prop, "container_detach", "dlc_vw_slot_machines_sounds")

    CreateThread(function()
        local endsAt = GetGameTimer() + (seconds * 1000)
        local lastRattleAt = 0

        while GetGameTimer() < endsAt and DoesEntityExist(prop) do
            local coords = GetEntityCoords(prop)

            -- Tiny jitter so the machine visibly shudders while it grinds.
            SetEntityCoordsNoOffset(
                prop,
                coords.x + (random(-1, 1) * 0.001),
                coords.y + (random(-1, 1) * 0.001),
                coords.z,
                true, true, true
            )

            local now = GetGameTimer()
            if now - lastRattleAt >= 500 then
                lastRattleAt = now
                PlayNearbySound(prop, "Drill_Pin_Break", "DLC_HEIST_FLEECA_SOUNDSET")
            end

            Wait(0)
        end

        if DoesEntityExist(prop) then
            SetEntityCoordsNoOffset(prop, state.anchor.x, state.anchor.y, state.anchor.z - 1.0, true, true, true)
            SetEntityHeading(prop, Settings.ReclaimerSites[siteId].heading)
            PlayNearbySound(prop, "container_attach", "dlc_vw_slot_machines_sounds")
        end
    end)
end)

RegisterNetEvent("bl_dumpsters:client:ReclaimCycleDone", function(siteId)
    local state = reclaimerState[siteId]
    cyclesRunning[siteId] = nil

    if not state then
        return
    end

    state.busy = false
    PlayNearbySound(state.prop, "container_attach", "dlc_vw_slot_machines_sounds")
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end

    for _, prop in pairs(reclaimerProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
end)

CreateThread(function()
    while not Framework.Player.Identifier do
        Wait(500)
    end

    BuildReclaimers()
end)
