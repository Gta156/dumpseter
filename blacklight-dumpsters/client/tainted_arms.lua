--[[ ==========================================================================
     BlackLight Dumpsters — Tainted Armaments / Toxin Effects (client)
========================================================================== ]]

local random = math.random

local afflicted = false
local taintedRegistry = {}
local secondsLeft = 0
local tickDamage = 0
local currentAffliction = {}
local tickerRunning = false

local WARNING_INTERVAL_MS = 5000
local warningMuted = false

CreateThread(function()
    for _, entry in pairs(Settings.TaintedArms) do
        taintedRegistry[entry.weapon] = {
            tickDamage = entry.tickDamage,
            durationSeconds = entry.durationSeconds,
            cureItem = entry.cureItem,
        }
    end
end)

--- Drains health once per second while the toxin runs its course.
local function RunToxinTicker(afflictionData)
    if tickerRunning then
        return
    end

    tickerRunning = true
    currentAffliction = afflictionData

    while afflicted do
        Wait(1000)
        SetEntityHealth(cache.ped, GetEntityHealth(cache.ped) - tickDamage)

        if not warningMuted then
            Framework.Notify(Settings.Text.toxin_active, "error")
            warningMuted = true
            SetTimeout(WARNING_INTERVAL_MS, function()
                warningMuted = false
            end)
        end

        secondsLeft = secondsLeft - 1
        if secondsLeft <= 0 then
            afflicted = false
            tickDamage = 0
            currentAffliction = {}
            tickerRunning = false
            Framework.Notify(Settings.Text.toxin_cleared, "success")
        end
    end

    tickerRunning = false
end

AddEventHandler("gameEventTriggered", function(eventName, data)
    if eventName ~= "CEventNetworkEntityDamage" then
        return
    end

    local weaponHash = tonumber(data[7])
    if data[1] ~= Store.Ped or not weaponHash then
        return
    end

    local afflictionData = taintedRegistry[weaponHash]
    if not afflictionData then
        return
    end

    afflicted = true
    secondsLeft = afflictionData.durationSeconds
    tickDamage = afflictionData.tickDamage

    CreateThread(function()
        RunToxinTicker(afflictionData)
    end)
end)

RegisterNetEvent("bl_dumpsters:client:AdministerCure", function(cureItem)
    Framework.Notify(Settings.Text.cure_administered, "success")

    SetTimeout(random(5000, 15000), function()
        if currentAffliction.cureItem == cureItem then
            afflicted = false
            secondsLeft = 0
            tickDamage = 0
            currentAffliction = {}
            Framework.Notify(Settings.Text.cure_effective, "success")
        else
            Framework.Notify(Settings.Text.cure_useless, "error")
        end
    end)
end)

if Settings.DiagnosticMode then
    RegisterCommand("bl_testtoxin", function()
        local spawnCoords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 3.0, 0.0)
        Framework.LoadModel(516505552)

        local attacker = CreatePed(4, 516505552, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, true, true)
        LogDiagnostic("Spawned toxin test attacker: " .. tostring(attacker))

        SetEntityAsMissionEntity(attacker, true, true)
        TaskCombatPed(attacker, cache.ped, 0, 16)
        SetPedCombatAttributes(attacker, 46, true)

        local pool = {}
        for _, entry in pairs(Settings.TaintedArms) do
            pool[#pool + 1] = entry.weapon
        end

        local chosen = pool[random(#pool)]
        LogDiagnostic("Issuing tainted weapon: " .. tostring(chosen))

        GiveWeaponToPed(attacker, chosen, 999, false, true)
        Wait(100)

        if HasPedGotWeapon(attacker, chosen, false) then
            SetCurrentPedWeapon(attacker, chosen, true)
        else
            GiveWeaponToPed(attacker, pool[1], 999, false, true)
            SetCurrentPedWeapon(attacker, pool[1], true)
        end

        SetTimeout(60000, function()
            if DoesEntityExist(attacker) then
                DeleteEntity(attacker)
                LogDiagnostic("Cleaned up toxin test attacker")
            end
        end)
    end, false)
end
