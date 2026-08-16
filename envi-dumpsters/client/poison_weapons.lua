local isPoisoned = false
local poisonWeapons = {}
local remainingSeconds = 0
local damagePerSecond = 0
local activePoison = {}
local tickActive = false
local NOTIFY_COOLDOWN = 5000
local notifyOnCooldown = false

CreateThread(function()
    for _, weaponData in pairs(Config.PoisonWeapons) do
        poisonWeapons[weaponData.weapon] = {
            damagePerSecond = weaponData.damagePerSecond,
            poisonDuration = weaponData.poisonDuration,
            antidoteItem = weaponData.antidoteItem,
        }
    end
end)

local function RunPoisonTick(weaponData)
    if tickActive then
        return
    end
    tickActive = true
    activePoison = weaponData

    while isPoisoned do
        Wait(1000)
        SetEntityHealth(cache.ped, GetEntityHealth(cache.ped) - damagePerSecond)

        if not notifyOnCooldown then
            Framework.Notify(Config.Lang.poisoned_status, "error")
            notifyOnCooldown = true
            SetTimeout(NOTIFY_COOLDOWN, function()
                notifyOnCooldown = false
            end)
        end

        remainingSeconds = remainingSeconds - 1
        if remainingSeconds <= 0 then
            isPoisoned = false
            damagePerSecond = 0
            Framework.Notify(Config.Lang.poison_worn_off, "success")
            tickActive = false
            activePoison = {}
        end
    end
end

AddEventHandler("gameEventTriggered", function(eventName, data)
    if eventName == "CEventNetworkEntityDamage" then
        local weaponHash = tonumber(data[7])
        if data[1] == Store.Ped and weaponHash then
            local weaponData = poisonWeapons[weaponHash]
            if weaponData then
                isPoisoned = true
                remainingSeconds = weaponData.poisonDuration
                damagePerSecond = weaponData.damagePerSecond

                CreateThread(function()
                    RunPoisonTick(weaponData)
                end)
            end
        end
    end
end)

RegisterNetEvent("envi-dumpsters:client:PoisonAntidote", function(item)
    Framework.Notify(Config.Lang.antidote_taken, "success")

    SetTimeout(math.random(5000, 15000), function()
        if activePoison.antidoteItem == item then
            isPoisoned = false
            remainingSeconds = 0
            damagePerSecond = 0
            activePoison = {}
            Framework.Notify(Config.Lang.antidote_working, "success")
        else
            Framework.Notify(Config.Lang.antidote_ineffective, "error")
        end
    end)
end)

if Config.DebugMode then
    RegisterCommand("testpoison", function()
        local spawnCoords = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 3.0, 0.0)
        Framework.LoadModel(516505552)

        local hobo = CreatePed(4, 516505552, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, true, true)
        print("Created hobo:", hobo)
        SetEntityAsMissionEntity(hobo, true, true)
        TaskCombatPed(hobo, cache.ped, 0, 16)
        SetPedCombatAttributes(hobo, 46, true)

        local weapons = {}
        for _, weaponData in pairs(Config.PoisonWeapons) do
            table.insert(weapons, weaponData.weapon)
            print("Added weapon:", weaponData.weapon)
        end

        local weapon = weapons[math.random(#weapons)]
        print("Selected weapon:", weapon)

        GiveWeaponToPed(hobo, weapon, 999, false, true)
        Wait(100)

        if HasPedGotWeapon(hobo, weapon, false) then
            print("Successfully gave weapon")
            SetCurrentPedWeapon(hobo, weapon, true)
        else
            print("Failed to give weapon")
            GiveWeaponToPed(hobo, weapons[1], 999, false, true)
            SetCurrentPedWeapon(hobo, weapons[1], true)
        end

        SetTimeout(60000, function()
            if DoesEntityExist(hobo) then
                DeleteEntity(hobo)
                print("Cleaned up hobo")
            end
        end)
    end, false)
end
