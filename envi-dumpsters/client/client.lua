drugged = false
local interactionLocked = false
local raccoonOptionBusy = false
local currentZoneName = nil
local currentZoneIndex = nil
local currentRestrictedZoneName = nil
local isHidingInDumpster = false
local hideSessionActive = false
local rustleSoundPlaying = false
local rustleSoundId = nil

function DebugPrint(message)
    if Config.DebugMode then
        print(message)
    end
end

CreateThread(function()
    for zoneIndex, zone in pairs(Config.ExclusiveItemZones) do
        Zone.SphereZone({
            coords = zone.coords,
            radius = zone.radius,
            zoneName = zone.name,
            debug = Config.DebugMode,
            onEnter = function(zoneData)
                if Config.DebugMode then
                    DebugPrint("Entered Dumpster Zone: " .. zoneData.zoneName)
                end
                currentZoneName = zoneData.zoneName
                currentZoneIndex = zoneIndex
                if zone.restrictedZone then
                    currentRestrictedZoneName = zoneData.zoneName
                end
            end,
            onExit = function()
                if Config.DebugMode then
                    DebugPrint("Exited Dumpster Zone: " .. currentZoneName)
                end
                currentZoneName = nil
                currentZoneIndex = nil
                currentRestrictedZoneName = nil
            end,
        })
    end
end)

local function NetworkGetOrRegisterEntity(entity)
    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(entity), true)
        Framework.NetworkRequestControlOfEntity(entity)
    end
    return NetworkGetNetworkIdFromEntity(entity)
end

function MakeHobosHateYou(searchableGroup)
    local playerCoords = GetEntityCoords(cache.ped)
    local aggroDistance = Config.AggressivePedDistance

    if Framework.HasJob(Config.HoboJobRole, Framework.Player) then
        return
    end

    if searchableGroup == OtherSearchables then
        DebugPrint("Searching from 'OtherSearchables' (Homeless Props) - doubling AggressivePedDistance to " .. (Config.AggressivePedDistance * 2) .. " units")
        aggroDistance = Config.AggressivePedDistance * 2
    end

    local nearbyPeds = Framework.GetNearbyPeds(playerCoords, aggroDistance)

    for _, pedData in pairs(nearbyPeds) do
        DebugPrint(pedData.ped)

        if not IsPedAPlayer(pedData.ped) then
            local model = GetEntityModel(pedData.ped)

            for _, modelName in pairs(Config.AggressivePeds) do
                SetPedFleeAttributes(pedData.ped, 0, 0)
                SetPedCombatAttributes(pedData.ped, 46, 1)
                SetPedCombatAttributes(pedData.ped, 5, 1)

                if model == GetHashKey(modelName) then
                    local roll = math.random(1, 100)

                    local giveWeapon = Config and Config.AggressivePedWeapons and Config.AggressivePedWeapons.GiveHoboWeapon
                    if giveWeapon then
                        giveWeapon = giveWeapon.enabled
                    end

                    if giveWeapon then
                        local chanceRoll = math.random(1, 100)
                        local chance = Config.AggressivePedWeapons.GiveHoboWeapon.chance

                        if chanceRoll <= chance then
                            local weapons = Config.AggressivePedWeapons.GiveHoboWeapon.weapons
                            local weapon = weapons[math.random(1, #weapons)]
                            GiveWeaponToPed(pedData.ped, GetHashKey(weapon), 0, false, true)
                        else
                            local rareThreshold = Config.AggressivePedWeapons.ChanceThresholds.Rare
                            if roll > rareThreshold then
                                GiveWeaponToPed(pedData.ped, GetHashKey(Config.AggressivePedWeapons.Weapons.Rare.name), Config.AggressivePedWeapons.Weapons.Rare.ammo, false, true)
                            else
                                local uncommonThreshold = Config.AggressivePedWeapons.ChanceThresholds.Uncommon
                                if roll > uncommonThreshold then
                                    GiveWeaponToPed(pedData.ped, GetHashKey(Config.AggressivePedWeapons.Weapons.Uncommon.name), Config.AggressivePedWeapons.Weapons.Uncommon.ammo, false, true)
                                else
                                    local commonThreshold = Config.AggressivePedWeapons.ChanceThresholds.Common
                                    if roll > commonThreshold then
                                        GiveWeaponToPed(pedData.ped, GetHashKey(Config.AggressivePedWeapons.Weapons.Common.name), Config.AggressivePedWeapons.Weapons.Common.ammo, false, true)
                                    end
                                end
                            end
                        end
                    end

                    TaskCombatPed(pedData.ped, cache.ped, 0, 16)
                end
            end
        end
    end
end

local raccoonSearching = false
local raccoonAtDumpster = false
local raccoonSearchComplete = false

local function RacoonSearch(dumpsterEntity)
    DebugPrint("RacoonSearch function started for entity: " .. tostring(dumpsterEntity))

    if not (RacoonPal and DoesEntityExist(RacoonPal)) then
        DebugPrint("RacoonPal doesn't exist, returning false")
        return false
    end

    local racoonCoords = GetEntityCoords(RacoonPal)
    local playerCoords = GetEntityCoords(cache.ped)
    local dumpsterCoords = GetEntityCoords(dumpsterEntity)

    local racoonToPlayer = #(racoonCoords - playerCoords)
    DebugPrint("Racoon distance from player: " .. racoonToPlayer)
    if racoonToPlayer > 10.0 then
        DebugPrint("Racoon too far from player (>10.0), returning false")
        return false
    end

    local racoonToDumpster = #(racoonCoords - dumpsterCoords)
    DebugPrint("Racoon distance to dumpster: " .. racoonToDumpster)
    if racoonToDumpster > 50.0 then
        DebugPrint("Dumpster too far from racoon (>50.0), returning false")
        return false
    end

    raccoonSearching = true
    DebugPrint("Racoon going to search, heading to player first")
    TaskGoToEntity(RacoonPal, dumpsterEntity, -1, 0.5, 10.0, 0, 0)

    local waitedSeconds = 0
    while raccoonSearching do
        local distance = #(GetEntityCoords(RacoonPal) - playerCoords)
        DebugPrint("Waiting for racoon to reach dumpster, current distance: " .. distance)
        if distance < 2.0 then
            raccoonSearching = false
            break
        end

        Wait(1000)
        waitedSeconds = waitedSeconds + 1
        if waitedSeconds > 20 then
            DebugPrint("Racoon search timed out after 20 seconds, returning false")
            return false
        end
    end

    raccoonAtDumpster = true
    DebugPrint("Racoon turning to face dumpster")
    TaskTurnPedToFaceEntity(RacoonPal, dumpsterEntity, 1000)

    SetTimeout(10000, function()
        DebugPrint("Racoon search timeout reached, setting racoonSearching to false")
        raccoonAtDumpster = false
    end)

    local animDict = "creatures@cat@move"
    local animName = "walk_start_180_r"
    Framework.LoadAnimDict(animDict)
    TaskPlayAnim(RacoonPal, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(3200)
    TaskPlayAnim(RacoonPal, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(3200)
    TaskPlayAnim(RacoonPal, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(3200)

    while raccoonAtDumpster do
        DebugPrint("Racoon is searching...")
        Wait(500)
    end

    raccoonSearchComplete = true
    DebugPrint("Racoon returning to player")
    TaskGoToEntity(RacoonPal, cache.ped, -1, 0.5, 10.0, 0, 0)

    while raccoonSearchComplete do
        local distance = #(GetEntityCoords(RacoonPal) - GetEntityCoords(cache.ped))
        DebugPrint("Waiting for racoon to return to player, current distance: " .. distance)
        if distance < 1.5 then
            raccoonSearchComplete = false
            break
        end
        Wait(500)
    end

    DebugPrint("Racoon has completed search and return")

    local shouldFail = false
    if Config.Fails.EnableFail then
        shouldFail = math.random(1, 100) <= Config.Fails.FailChancePercent
    end

    DebugPrint("Search result calculation - shouldFail: " .. tostring(shouldFail))
    return not shouldFail
end

local function TriggerDumpsterSearch(anims, targetEntity, isBagMode, hideMode)
    if Config.ProgressBars and not hideMode then
        local finished = nil
        local animFlag = 49
        if isBagMode then
            animFlag = 0
        end

        if IsPedArmed(cache.ped, 7) then
            SetCurrentPedWeapon(cache.ped, -1569615261, true)
            Wait(1500)
        end

        local shouldFail = false
        if Config.Fails.EnableFail then
            shouldFail = math.random(1, 100) <= Config.Fails.FailChancePercent
        end

        local dicts = {}
        local clips = {}
        for _, anim in ipairs(anims) do
            table.insert(dicts, anim.dict)
            table.insert(clips, anim.anim)
        end

        local pick = math.random(1, #dicts)
        local animDict = dicts[pick]
        local animName = clips[pick]

        TaskTurnPedToFaceEntity(cache.ped, targetEntity, 1000)
        Wait(500)

        if hideMode then
            local playerCoords = GetEntityCoords(cache.ped)
            SetEntityCoords(cache.ped, playerCoords.x, playerCoords.y, playerCoords.z + 0.05)
        else
            TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
        end

        local logLabel = shouldFail and "fail anim: " or "anim: "
        DebugPrint(logLabel .. animDict .. " " .. animName)

        local animTime = GetAnimDuration(animDict, animName) * 1000
        if animTime < 2000 then
            animTime = math.random(2700, 4000)
        end

        lib.progressBar({
            label = Config.Lang.progress_searching,
            duration = animTime,
            canCancel = false,
            anim = { dict = animDict, clip = animName, flag = animFlag },
            disable = { move = true, combat = true, vehicle = true },
            onFinish = function()
                finished = true
                ClearPedTasks(cache.ped)

                if hideMode == "in" then
                    TriggerEvent("envi-dumpsters:inDumpster", true, targetEntity)
                    TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
                    Wait(math.random(1000, 2000))
                    AttachEntityToEntity(cache.ped, targetEntity, GetPedBoneIndex(targetEntity, 18905), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                    SetEntityVisible(cache.ped, false)
                elseif hideMode == "out" then
                    TriggerEvent("envi-dumpsters:inDumpster", false, targetEntity)
                    DetachEntity(cache.ped, true, true)
                    SetEntityVisible(cache.ped, true)

                    local entityCoords = GetEntityCoords(targetEntity)
                    Framework.Notify(Config.Lang.leaving_dumpster, "info", 1000)
                    TriggerServerEvent("envi-dumpsters:setDumpsterBusy", NetworkGetNetworkIdFromEntity(targetEntity), false)

                    local forward = GetEntityForwardVector(cache.ped)
                    SetEntityCoords(cache.ped, entityCoords.x + (-forward.x), entityCoords.y + (-forward.y), entityCoords.z + Config.LeaveDumpsterHeight, true, false, true, false)

                    if Config.LeaveDumpsterAnim then
                        TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
                        while IsEntityPlayingAnim(cache.ped, animDict, animName) do
                            Wait(0)
                        end
                    end

                    SetEntityCollision(targetEntity, true, true)
                    SetEntityCollision(cache.ped, true, true)
                end

                if shouldFail then
                    local dirtyNeedleRoll = math.random(1, 100)
                    local ratRoll = math.random(1, 100)
                    local currentHealth = GetEntityHealth(cache.ped)
                    local newHealth = math.max(currentHealth - Config.Fails.HealthLoss, 1)

                    if dirtyNeedleRoll <= Config.Fails.DirtyNeedlesChancePercent then
                        if Config.Fails.EnableNeedleEvent then
                            TriggerDirtyNeedlesEffect()
                        end
                    elseif ratRoll <= Config.Fails.RatChancePercent then
                        if Config.Fails.EnableRatEvent then
                            TriggerRatEffect()
                        end
                    else
                        SetEntityHealth(cache.ped, newHealth)
                        Framework.Notify(Config.Lang.fail, "error", 5000)
                        DebugPrint("Current Health: " .. currentHealth .. ", Health Lost: " .. Config.Fails.HealthLoss .. ", New Health: " .. newHealth)

                        Framework.LoadAnimDict(Config.FailAnim.dict)
                        TaskPlayAnim(cache.ped, Config.FailAnim.dict, Config.FailAnim.anim, 8.0, 8.0, -1, 49, 0, false, false, false)

                        local failAnimTime = GetAnimDuration(Config.FailAnim.dict, Config.FailAnim.anim) * 1000
                        if failAnimTime < 2000 then
                            failAnimTime = math.random(2700, 4000)
                        end

                        Wait(failAnimTime - 500)
                        ClearPedTasks(cache.ped)
                    end
                end

                RemoveAnimDict(animDict)
            end,
        })

        while finished == nil do
            if Framework.IsPlayerDead() then
                break
            end
            Wait(50)
        end

        isHidingInDumpster = false
        finished = finished or false
        if finished then
            finished = not shouldFail
        end
        return finished
    end

    local animFlag = 49
    if isBagMode then
        animFlag = 0
    end

    if IsPedArmed(cache.ped, 7) then
        SetCurrentPedWeapon(cache.ped, -1569615261, true)
        Wait(1500)
    end

    local shouldFail = false
    if Config.Fails.EnableFail then
        shouldFail = math.random(1, 100) <= Config.Fails.FailChancePercent
    end

    local dicts = {}
    local clips = {}
    for _, anim in ipairs(anims) do
        table.insert(dicts, anim.dict)
        table.insert(clips, anim.anim)
    end

    local pick = math.random(1, #dicts)
    local animDict = dicts[pick]
    local animName = clips[pick]

    local animTime = GetAnimDuration(animDict, animName) * 1000
    if animTime < 2000 then
        animTime = math.random(2700, 4000)
    end

    TaskTurnPedToFaceEntity(cache.ped, targetEntity, 1000)
    Wait(1000)
    FreezeEntityPosition(cache.ped, true)
    Framework.LoadAnimDict(animDict)

    if hideMode then
        local playerCoords = GetEntityCoords(cache.ped)
        SetEntityCoords(cache.ped, playerCoords.x, playerCoords.y, playerCoords.z + 0.05)
    else
        TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
    end

    if hideMode == "in" then
        isHidingInDumpster = true
        TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
        Wait(math.random(1000, 2000))
        AttachEntityToEntity(cache.ped, targetEntity, GetPedBoneIndex(targetEntity, 18905), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        TriggerEvent("envi-dumpsters:inDumpster", true, targetEntity)
        SetEntityVisible(cache.ped, false)
    elseif hideMode == "out" then
        isHidingInDumpster = false
        TriggerEvent("envi-dumpsters:inDumpster", false, targetEntity)
        DetachEntity(cache.ped, true, true)
        SetEntityVisible(cache.ped, true)

        local entityCoords = GetEntityCoords(targetEntity)
        Framework.Notify(Config.Lang.leaving_dumpster, "info", 1000)
        TriggerServerEvent("envi-dumpsters:setDumpsterBusy", NetworkGetNetworkIdFromEntity(targetEntity), false)

        local forward = GetEntityForwardVector(cache.ped)
        SetEntityCoords(cache.ped, entityCoords.x + (-forward.x), entityCoords.y + (-forward.y), entityCoords.z + Config.LeaveDumpsterHeight, true, false, true, false)

        if Config.LeaveDumpsterAnim then
            TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
            while IsEntityPlayingAnim(cache.ped, animDict, animName) do
                Wait(0)
            end
        end

        SetEntityCollision(targetEntity, true, true)
        SetEntityCollision(cache.ped, true, true)
    end

    local logLabel = shouldFail and "fail anim: " or "anim: "
    DebugPrint(logLabel .. animDict .. " " .. animName)

    Wait(animTime - 500)
    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)

    if shouldFail then
        local dirtyNeedleRoll = math.random(1, 100)
        local ratRoll = math.random(1, 100)
        local currentHealth = GetEntityHealth(cache.ped)
        local newHealth = math.max(currentHealth - Config.Fails.HealthLoss, 1)

        if dirtyNeedleRoll <= Config.Fails.DirtyNeedlesChancePercent then
            if Config.Fails.EnableNeedleEvent then
                TriggerDirtyNeedlesEffect()
            end
        elseif ratRoll <= Config.Fails.RatChancePercent then
            if Config.Fails.EnableRatEvent then
                TriggerRatEffect()
            end
        else
            SetEntityHealth(cache.ped, newHealth)
            Framework.Notify(Config.Lang.fail, "error", 5000)
            DebugPrint("Current Health: " .. currentHealth .. ", Health Lost: " .. Config.Fails.HealthLoss .. ", New Health: " .. newHealth)

            Framework.LoadAnimDict(Config.FailAnim.dict)
            TaskPlayAnim(cache.ped, Config.FailAnim.dict, Config.FailAnim.anim, 8.0, 8.0, -1, 49, 0, false, false, false)

            local failAnimTime = GetAnimDuration(Config.FailAnim.dict, Config.FailAnim.anim) * 1000
            if failAnimTime < 2000 then
                failAnimTime = math.random(2700, 4000)
            end

            Wait(failAnimTime - 500)
            ClearPedTasks(cache.ped)
        end
    end

    RemoveAnimDict(animDict)
    isHidingInDumpster = false
    return not shouldFail
end

RegisterNetEvent("envi-dumpsters:kickOutOfDumpster", function()
    if not hideSessionActive then
        return
    end

    hideSessionActive = false
    TriggerDumpsterSearch(KickedOutDumpsterAnims, cache.ped, true, "out")
end)

function RacoonExit(entity)
    local animDict = "creatures@cat@amb@world_cat_sleeping_ground@exit"
    local animName = "exit_panic"
    Framework.LoadAnimDict(animDict)
    TaskPlayAnim(entity, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(700)
end

RegisterNetEvent("envi-dumpsters:inDumpster", function(isHiding, targetEntity)
    isHidingInDumpster = isHiding
    local netId = NetworkGetNetworkIdFromEntity(targetEntity)

    if isHidingInDumpster then
        Framework.Notify(Config.Lang.get_out_dumpster, "error", 10000)
        TriggerServerEvent("envi-dumpsters:setDumpsterBusy", netId, true)
    end

    if not rustleSoundPlaying then
        if Config.RustleSoundWhenHiding then
            CreateThread(function()
                while isHidingInDumpster do
                    rustleSoundId = GetSoundId()
                    PlaySoundFromEntity(rustleSoundId, "Trash_Bag_Land", cache.ped, "DLC_HEIST_SERIES_A_SOUNDS", true, 0)
                    rustleSoundPlaying = true
                    Wait(math.random(15000, 20000))
                end
            end)
        end
    end

    while isHidingInDumpster do
        if isHidingInDumpster then
            DisableControlAction(0, 23, true)

            if IsEntityAttached(cache.ped) then
                if not IsControlJustReleased(0, Config.GetOutKey) then
                    Wait(0)
                    goto continueLoop
                end
            end

            isHidingInDumpster = false
            TriggerServerEvent("envi-dumpsters:setDumpsterBusy", netId, false)
            TriggerDumpsterSearch(KickedOutDumpsterAnims, cache.ped, true, "out")
            interactionLocked = false

            if rustleSoundId then
                if rustleSoundPlaying then
                    if Config.RustleSoundWhenHiding then
                        StopSound(rustleSoundId)
                        ReleaseSoundId(rustleSoundId)
                        rustleSoundPlaying = false
                    end
                end
            end
            break
        end
        ::continueLoop::
        Wait(0)
    end
end)

local function RegisterSearchableModel(models, searchLabel, giveItemsEvent, searchAnims, openLabel, openEvent, stashPrefix, hideLabel, checkFreeEvent, hideAnims)
    if Config.Target then
        Target.AddModel(models, {
            {
                label = searchLabel,
                icon = "fa-solid fa-trash",
                distance = 3.0,
                job = Config.JobLocked,
                onSelect = function(data)
                    interactionLocked = true
                    local entity = data.entity
                    local netId = NetworkGetOrRegisterEntity(entity)
                    local coords = GetEntityCoords(entity)
                    local success = TriggerDumpsterSearch(searchAnims, entity)

                    Framework.TriggerCallback("envi-dumpsters:checkDumpsterIsFree", function()
                        if Config.AggressivePedsAttack then
                            MakeHobosHateYou(models)
                        end

                        if currentZoneName then
                            if currentRestrictedZoneName then
                                if currentZoneIndex then
                                    TriggerServerEvent("envi-dumpsters:snitch", coords, currentZoneIndex)
                                    CustomDispatch(coords)
                                end
                            end
                        end

                        if success then
                            Framework.TriggerCallback(giveItemsEvent, function(itemsGiven) end, netId, coords, currentZoneIndex)
                        end
                    end, netId)

                    interactionLocked = false
                end,
                canInteract = function(entity)
                    if IsEntityAMissionEntity(entity) then
                        return false
                    end

                    local isDead = Framework.IsPlayerDead()
                    if not (drugged or interactionLocked or isDead) then
                        return true
                    end
                    return false
                end,
            },
            {
                label = Config.Lang.raccoon_search,
                icon = "fas fa-paw",
                distance = 30.0,
                job = Config.HoboJobRole,
                onSelect = function(data)
                    raccoonOptionBusy = true
                    local entity = data.entity
                    local netId = NetworkGetOrRegisterEntity(entity)
                    local coords = GetEntityCoords(entity)
                    local racoonAvailable = RacoonSearch(entity)

                    if racoonAvailable then
                        if RacoonPal and DoesEntityExist(RacoonPal) and not IsEntityDead(RacoonPal) then
                            while interactionLocked do
                                Wait(500)
                            end

                            if RacoonPal and DoesEntityExist(RacoonPal) and not IsEntityDead(RacoonPal) then
                                TaskTurnPedToFaceEntity(RacoonPal, cache.ped, 1000)
                                Wait(500)
                                TaskTurnPedToFaceEntity(cache.ped, RacoonPal, 1000)
                                Wait(1000)
                                TaskStartScenarioInPlace(cache.ped, "CODE_HUMAN_MEDIC_KNEEL", 0, true)
                                Wait(5000)

                                Framework.TriggerCallback(giveItemsEvent, function() end, netId, coords, currentZoneIndex)

                                Wait(1000)
                                ClearPedTasks(cache.ped)
                            end
                        end
                    end

                    if RacoonPal and DoesEntityExist(RacoonPal) and not IsEntityDead(RacoonPal) then
                        TaskFollowToOffsetOfEntity(RacoonPal, cache.ped, 1.0, 1.0, 0.0, 5.0, -1, 1.0, true)
                    end

                    raccoonOptionBusy = false
                end,
                canInteract = function()
                    if not RacoonPal then
                        return false
                    end

                    local racoonUsable = not IsEntityDead(RacoonPal)
                    if racoonUsable then
                        racoonUsable = not DoesEntityExist(RacoonPal) == false
                    end

                    if not (drugged or raccoonOptionBusy or racoonUsable) then
                        return true
                    end
                    return false
                end,
            },
        })

        if Config.StashesEnabled then
            Target.AddModel(models, {
                {
                    label = openLabel,
                    icon = "fa-solid fa-trash",
                    distance = 3.0,
                    job = Config.JobLocked,
                    onSelect = function(data)
                        interactionLocked = true
                        local entity = data.entity
                        local netId = NetworkGetOrRegisterEntity(entity)
                        local coords = GetEntityCoords(entity)
                        local success = TriggerDumpsterSearch(searchAnims, entity)

                        if Config.AggressivePedsAttack then
                            MakeHobosHateYou(models)
                        end

                        Framework.TriggerCallback(openEvent, function(hash)
                            if currentZoneName then
                                if currentRestrictedZoneName then
                                    if currentZoneIndex then
                                        TriggerServerEvent("envi-dumpsters:snitch", coords, currentZoneIndex)
                                        CustomDispatch(coords)
                                    end
                                end
                            end

                            if success and hash then
                                Framework.OpenStash(stashPrefix .. hash)
                            end
                        end, netId, coords)

                        interactionLocked = false
                    end,
                    canInteract = function(entity)
                        if IsEntityAMissionEntity(entity) then
                            return false
                        end

                        local isDead = Framework.IsPlayerDead()
                        if not (drugged or interactionLocked or isDead) then
                            return true
                        end
                        return false
                    end,
                },
            })
        end

        if hideLabel and checkFreeEvent then
            if Config.HideInDumpstersEnabled then
                Target.AddModel(models, {
                    {
                        label = hideLabel,
                        icon = "fa-solid fa-trash",
                        distance = 3.0,
                        job = Config.JobLocked,
                        onSelect = function(data)
                            interactionLocked = true
                            local entity = data.entity
                            local netId = NetworkGetOrRegisterEntity(entity)
                            local coords = GetEntityCoords(entity)
                            local success = TriggerDumpsterSearch(searchAnims, entity)

                            if Config.AggressivePedsAttack then
                                MakeHobosHateYou(models)
                            end

                            Framework.TriggerCallback(checkFreeEvent, function(isFree)
                                if currentZoneName then
                                    if currentRestrictedZoneName then
                                        if currentZoneIndex then
                                            TriggerServerEvent("envi-dumpsters:snitch", coords, currentZoneIndex)
                                            CustomDispatch(coords)
                                        end
                                    end
                                end

                                if success and isFree then
                                    FreezeEntityPosition(cache.ped, true)
                                    hideSessionActive = TriggerDumpsterSearch(hideAnims, entity, true, "in")
                                    if hideSessionActive then
                                        FreezeEntityPosition(cache.ped, false)
                                    end
                                end
                            end, netId, coords)

                            interactionLocked = false
                        end,
                        canInteract = function()
                            local isDead = Framework.IsPlayerDead()
                            if not (drugged or interactionLocked or isDead) then
                                return true
                            end
                            return false
                        end,
                    },
                })
            end
        end
    else
        local options = {}

        table.insert(options, {
            label = "[E] - " .. searchLabel,
            canSee = function()
                return not interactionLocked
            end,
            selected = function(data)
                if interactionLocked then
                    return
                end
                interactionLocked = true

                local entity = data.entity
                local netId = NetworkGetOrRegisterEntity(entity)
                local coords = GetEntityCoords(entity)
                local success = TriggerDumpsterSearch(searchAnims, entity)

                Framework.TriggerCallback("envi-dumpsters:checkDumpsterIsFree", function()
                    if Config.AggressivePedsAttack then
                        MakeHobosHateYou(models)
                    end

                    if currentZoneName then
                        if currentRestrictedZoneName then
                            if currentZoneIndex then
                                TriggerServerEvent("envi-dumpsters:snitch", coords, currentZoneIndex)
                                CustomDispatch(coords)
                            end
                        end
                    end

                    if success then
                        Framework.TriggerCallback(giveItemsEvent, function() end, netId, coords, currentZoneIndex)
                    end
                end, netId)

                interactionLocked = false
            end,
        })

        table.insert(options, {
            label = "[E] - " .. Config.Lang.raccoon_search,
            canSee = function()
                local isHobo = Framework.Player.Job.Name == Config.HoboJobRole
                if RacoonPal then
                    if not raccoonOptionBusy then
                        return isHobo
                    end
                end
                return false
            end,
            selected = function(data)
                if RacoonPal then
                    if raccoonOptionBusy then
                        return
                    end
                end

                raccoonOptionBusy = true
                local entity = data.entity
                local netId = NetworkGetOrRegisterEntity(entity)
                local coords = GetEntityCoords(entity)
                local racoonAvailable = RacoonSearch(entity)

                if racoonAvailable then
                    if RacoonPal and DoesEntityExist(RacoonPal) and not IsEntityDead(RacoonPal) then
                        while interactionLocked do
                            Wait(500)
                        end

                        if RacoonPal and DoesEntityExist(RacoonPal) and not IsEntityDead(RacoonPal) then
                            TaskTurnPedToFaceEntity(RacoonPal, cache.ped, 1000)
                            Wait(500)
                            TaskTurnPedToFaceEntity(cache.ped, RacoonPal, 1000)
                            Wait(1000)
                            TaskStartScenarioInPlace(cache.ped, "CODE_HUMAN_MEDIC_KNEEL", 0, true)
                            Wait(5000)

                            Framework.TriggerCallback(giveItemsEvent, function() end, netId, coords, currentZoneIndex)

                            Wait(1000)
                            ClearPedTasks(cache.ped)
                        end
                    end
                end

                if RacoonPal and DoesEntityExist(RacoonPal) and not IsEntityDead(RacoonPal) then
                    TaskFollowToOffsetOfEntity(RacoonPal, cache.ped, 1.0, 1.0, 0.0, 5.0, -1, 1.0, true)
                end

                raccoonOptionBusy = false
            end,
        })

        if Config.StashesEnabled then
            table.insert(options, {
                label = "[E] - " .. openLabel,
                canSee = function()
                    return not interactionLocked
                end,
                selected = function(data)
                    if interactionLocked then
                        return
                    end
                    interactionLocked = true

                    local entity = data.entity
                    local netId = NetworkGetOrRegisterEntity(entity)
                    local coords = GetEntityCoords(entity)
                    local success = TriggerDumpsterSearch(searchAnims, entity)

                    if Config.AggressivePedsAttack then
                        MakeHobosHateYou(models)
                    end

                    Framework.TriggerCallback(openEvent, function(hash)
                        if currentZoneName then
                            if currentRestrictedZoneName then
                                if currentZoneIndex then
                                    TriggerServerEvent("envi-dumpsters:snitch", coords, currentZoneIndex)
                                    CustomDispatch(coords)
                                end
                            end
                        end

                        if success and hash then
                            Framework.OpenStash(stashPrefix .. hash)
                        end
                    end, netId, coords)

                    interactionLocked = false
                end,
            })
        end

        if hideLabel and checkFreeEvent then
            if Config.HideInDumpstersEnabled then
                table.insert(options, {
                    label = "[E] -" .. hideLabel,
                    canSee = function()
                        return not interactionLocked
                    end,
                    selected = function(data)
                        if interactionLocked then
                            return
                        end
                        interactionLocked = true

                        local entity = data.entity
                        local netId = NetworkGetOrRegisterEntity(entity)
                        local coords = GetEntityCoords(entity)
                        local success = TriggerDumpsterSearch(searchAnims, entity)

                        if Config.AggressivePedsAttack then
                            MakeHobosHateYou(models)
                        end

                        Framework.TriggerCallback(checkFreeEvent, function(isFree)
                            if currentZoneName then
                                if currentRestrictedZoneName then
                                    if currentZoneIndex then
                                        TriggerServerEvent("envi-dumpsters:snitch", coords, currentZoneIndex)
                                        CustomDispatch(coords)
                                    end
                                end
                            end

                            if success and isFree then
                                FreezeEntityPosition(cache.ped, true)
                                hideSessionActive = TriggerDumpsterSearch(hideAnims, entity, true, "in")
                                if hideSessionActive then
                                    FreezeEntityPosition(cache.ped, false)
                                end
                            end
                        end, netId, coords)

                        interactionLocked = false
                    end,
                })
            end
        end

        exports["envi-interact"]:InteractionModel(models, {
            {
                name = "dumpster_interaction",
                distance = 1.8,
                radius = 15.0,
                options = options,
            },
        })
    end
end

local function RegisterCustomSearchables()
    for customIndex, custom in pairs(CustomSearchables) do
        if Config.Target then
            Target.AddModel(custom.models, {
                {
                    label = custom.label,
                    icon = "fa-solid fa-search",
                    distance = 3.0,
                    job = Config.JobLocked,
                    onSelect = function(data)
                        interactionLocked = true
                        local entity = data.entity
                        local netId = NetworkGetOrRegisterEntity(entity)
                        local coords = GetEntityCoords(entity)
                        local success = TriggerDumpsterSearch(custom.anims, entity)

                        if Config.AggressivePedsAttack then
                            MakeHobosHateYou(custom.models)
                        end

                        if custom.isStealing then
                            CustomDispatch(coords)
                        end

                        if currentZoneName then
                            if currentRestrictedZoneName then
                                if currentZoneIndex then
                                    TriggerServerEvent("envi-dumpsters:snitch", coords, currentZoneIndex)
                                    CustomDispatch(coords)
                                end
                            end
                        end

                        if success then
                            Framework.TriggerCallback("envi-dumpsters:GiveItemsCustom", function() end, netId, coords, currentZoneIndex, customIndex)

                            if custom.deleteProp then
                                Wait(500)
                                SetEntityAsMissionEntity(entity, true, true)
                                local deleteNetId = NetworkGetOrRegisterEntity(entity)
                                DeleteEntity(entity)
                                if not DoesEntityExist(entity) then
                                    TriggerServerEvent("envi-dumpsters:server:deleteEntity", deleteNetId)
                                end
                                interactionLocked = false
                            end
                        end

                        interactionLocked = false
                    end,
                    canInteract = function(entity)
                        if IsEntityAMissionEntity(entity) then
                            return false
                        end

                        local isDead = Framework.IsPlayerDead()
                        if not (drugged or interactionLocked or isDead) then
                            return true
                        end
                        return false
                    end,
                },
            })
        else
            exports["envi-interact"]:InteractionModel(custom.models, {
                {
                    name = "custom_searchable_interaction_" .. customIndex,
                    distance = 1.8,
                    radius = 5.0,
                    options = {
                        {
                            label = "[E] - " .. custom.label,
                            canSee = function()
                                return not interactionLocked
                            end,
                            selected = function(data)
                                if interactionLocked then
                                    return
                                end
                                interactionLocked = true

                                local entity = data.entity
                                local netId = NetworkGetOrRegisterEntity(entity)
                                local coords = GetEntityCoords(entity)
                                local success = TriggerDumpsterSearch(custom.anims, entity)

                                if Config.AggressivePedsAttack then
                                    MakeHobosHateYou(custom.models)
                                end

                                if custom.isStealing then
                                    CustomDispatch(coords)
                                end

                                if currentZoneName then
                                    if currentRestrictedZoneName then
                                        if currentZoneIndex then
                                            TriggerServerEvent("envi-dumpsters:snitch", coords, currentZoneIndex)
                                            CustomDispatch(coords)
                                        end
                                    end
                                end

                                if success then
                                    Framework.TriggerCallback("envi-dumpsters:GiveItemsCustom", function() end, netId, coords, currentZoneIndex, customIndex)

                                    if custom.deleteProp then
                                        Wait(500)
                                        SetEntityAsMissionEntity(entity, true, true)
                                        local deleteNetId = NetworkGetOrRegisterEntity(entity)
                                        DeleteEntity(entity)
                                        if DoesEntityExist(entity) then
                                            TriggerServerEvent("envi-dumpsters:server:deleteEntity", deleteNetId)
                                        end
                                    end

                                    interactionLocked = false
                                end

                                interactionLocked = false
                            end,
                        },
                    },
                },
            })
        end
    end
end

CreateThread(function()
    while not Framework.Player.Identifier do
        Wait(1000)
    end

    RegisterSearchableModel(BeachCans, Config.Lang.search_garbage, "envi-dumpsters:GiveItemsBeach", BeachCanAnims, Config.Lang.open_garbage, "envi-dumpsters:OpenBeach", "Beach")
    RegisterSearchableModel(Dumpsters, Config.Lang.search_dumpster, "envi-dumpsters:GiveItemsDumpster", DumpsterAnims, Config.Lang.open_dumpster, "envi-dumpsters:OpenDumpster", "Dumpster", Config.Lang.hide_in_dumpster, "envi-dumpsters:checkDumpsterIsFree", HideInDumpsterAnims)
    RegisterSearchableModel(GarbageCans, Config.Lang.search_garbage, "envi-dumpsters:GiveItemsGarbageCans", GarbageCanAnims, Config.Lang.open_garbage, "envi-dumpsters:OpenGarbage", "Garbage")
    RegisterSearchableModel(OtherSearchables, Config.Lang.search, "envi-dumpsters:GiveItemsOther", GarbageCanAnims, Config.Lang.open, "envi-dumpsters:OpenOther", "Hobo")

    if CustomSearchables then
        if CustomSearchables[1] then
            RegisterCustomSearchables()
        end
    end

    if Config.Target then
        Target.AddModel(TrashBagModels, {
            {
                label = Config.Lang.inspect,
                icon = "fa-solid fa-trash",
                distance = 3.0,
                job = Config.JobLocked,
                onSelect = function(data)
                    interactionLocked = true
                    local entity = data.entity
                    local netId = NetworkGetOrRegisterEntity(entity)
                    local success = TriggerDumpsterSearch(TrashBagAnims, entity)

                    if Config.AggressivePedsAttack then
                        MakeHobosHateYou()
                    end

                    if success and netId then
                        Framework.Notify(Config.Lang.garbagebag, "success")
                        SetEntityCanBeTargetedWithoutLos(entity, true)
                        KeepTrackOfBag(entity)
                    end

                    interactionLocked = false
                end,
                canInteract = function()
                    if not (drugged or interactionLocked or checkedBag) then
                        return true
                    end
                    return false
                end,
            },
        })
    else
        exports["envi-interact"]:InteractionModel(TrashBagModels, {
            {
                name = "dumpster_interaction",
                distance = 1.5,
                radius = 5.0,
                options = {
                    {
                        label = Config.Lang.inspect,
                        canSee = function()
                            return not (checkedBag or drugged)
                        end,
                        selected = function(data)
                            interactionLocked = true
                            local entity = data.entity
                            local netId = NetworkGetOrRegisterEntity(entity)
                            local success = TriggerDumpsterSearch(TrashBagAnims, entity)

                            if Config.AggressivePedsAttack then
                                MakeHobosHateYou()
                            end

                            if success and netId then
                                Framework.Notify(Config.Lang.garbagebag, "success")
                                SetEntityCanBeTargetedWithoutLos(entity, true)
                                KeepTrackOfBag(entity)
                            end

                            interactionLocked = false
                        end,
                    },
                },
            },
        })
    end
end)

CreateThread(function()
    while not Framework.Player.Identifier do
        Wait(1000)
        if Config.DebugMode then
            print("Waiting for player to load")
        end
    end

    while Framework.Player.Identifier do
        local bottles = Framework.GetItem("hobo_bottle", { uses = 0 })
        if bottles[1] then
            if bottles[1].count then
                if bottles[1].count > 0 then
                    if IsEntityInWater(cache.ped) then
                        TriggerServerEvent("envi-dumpsters:server:RefillBottle", bottles[1].slot)
                    end
                end
            end
        end
        Wait(5000)
    end
end)

local trackedBagEntity = nil
local trackedBagDistance = 0.0

function KeepTrackOfBag(bagEntity)
    if trackedBagEntity then
        DebugPrint("Already tracking a bag, returning")
        return
    end

    trackedBagEntity = bagEntity

    CreateThread(function()
        while trackedBagEntity do
            Wait(1000)

            local distance = #(GetEntityCoords(trackedBagEntity) - GetEntityCoords(cache.ped))
            if distance < 100 then
                trackedBagDistance = distance
            end

            local health = GetEntityHealth(trackedBagEntity)
            DebugPrint("Bag distance: " .. tostring(distance) .. ", HP: " .. tostring(health))

            if health <= 0 then
                DebugPrint("Bag destroyed")

                if trackedBagDistance <= 5.0 then
                    DebugPrint("Player close enough, triggering callback")

                    Framework.TriggerCallback("envi-dumpsters:GiveItemsBags", function(success)
                        if success then
                            DebugPrint("Successfully got items from bag")
                            Framework.Notify(Config.Lang.success, "success", 5000)
                            trackedBagEntity = nil
                        else
                            DebugPrint("Failed to get items from bag")
                            trackedBagEntity = nil
                        end
                    end, netId, distance, currentZoneIndex)
                    break
                else
                    trackedBagEntity = nil
                    break
                end
            else
                if trackedBagDistance > 10.0 then
                    DebugPrint("Player too far away, stopping tracking")
                    trackedBagEntity = nil
                    break
                end
            end
        end
    end)
end
