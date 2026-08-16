BLScav_Sedated = false
local rummageLocked = false
local critterOptionBusy = false
local activeLootZoneName = nil
local activeLootZoneIndex = nil
local activeWatchedZoneName = nil
local isConcealedInBin = false
local concealmentActive = false
local rustleAudioActive = false
local rustleAudioId = nil

function TraceLog(message)
    if Config.DiagnosticsEnabled then
        print(message)
    end
end

CreateThread(function()
    for zoneIndex, zone in pairs(Config.SignatureLootZones) do
        Zone.SphereZone({
            coords = zone.coords,
            radius = zone.radius,
            zoneName = zone.name,
            debug = Config.DiagnosticsEnabled,
            onEnter = function(zoneData)
                if Config.DiagnosticsEnabled then
                    TraceLog("Entered Dumpster Zone: " .. zoneData.zoneName)
                end
                activeLootZoneName = zoneData.zoneName
                activeLootZoneIndex = zoneIndex
                if zone.restrictedZone then
                    activeWatchedZoneName = zoneData.zoneName
                end
            end,
            onExit = function()
                if Config.DiagnosticsEnabled then
                    TraceLog("Exited Dumpster Zone: " .. currentZoneName)
                end
                activeLootZoneName = nil
                activeLootZoneIndex = nil
                activeWatchedZoneName = nil
            end,
        })
    end
end)

local function EnsureEntityNetworked(entity)
    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(entity), true)
        Framework.NetworkRequestControlOfEntity(entity)
    end
    return NetworkGetNetworkIdFromEntity(entity)
end

function ProvokeVagrantCrowd(searchableGroup)
    local playerCoords = GetEntityCoords(cache.ped)
    local hostileRange = Config.HostileVagrantRange

    if Framework.HasJob(Config.VagrantJobRole, Framework.Player) then
        return
    end

    if searchableGroup == BLScav_EncampmentModels then
        TraceLog("Searching from 'OtherSearchables' (Homeless Props) - doubling AggressivePedDistance to " .. (Config.HostileVagrantRange * 2) .. " units")
        hostileRange = Config.HostileVagrantRange * 2
    end

    local nearbyPeds = Framework.GetNearbyPeds(playerCoords, hostileRange)

    for _, pedData in pairs(nearbyPeds) do
        TraceLog(pedData.ped)

        if not IsPedAPlayer(pedData.ped) then
            local model = GetEntityModel(pedData.ped)

            for _, modelName in pairs(Config.HostileVagrantModels) do
                SetPedFleeAttributes(pedData.ped, 0, 0)
                SetPedCombatAttributes(pedData.ped, 46, 1)
                SetPedCombatAttributes(pedData.ped, 5, 1)

                if model == GetHashKey(modelName) then
                    local roll = math.random(1, 100)

                    local giveWeapon = Config and Config.HostileVagrantArmoury and Config.HostileVagrantArmoury.StreetWeaponRoll
                    if giveWeapon then
                        giveWeapon = giveWeapon.enabled
                    end

                    if giveWeapon then
                        local chanceRoll = math.random(1, 100)
                        local chance = Config.HostileVagrantArmoury.StreetWeaponRoll.chance

                        if chanceRoll <= chance then
                            local weapons = Config.HostileVagrantArmoury.StreetWeaponRoll.weapons
                            local weapon = weapons[math.random(1, #weapons)]
                            GiveWeaponToPed(pedData.ped, GetHashKey(weapon), 0, false, true)
                        else
                            local rareThreshold = Config.HostileVagrantArmoury.RarityThresholds.Rare
                            if roll > rareThreshold then
                                GiveWeaponToPed(pedData.ped, GetHashKey(Config.HostileVagrantArmoury.Weapons.Rare.name), Config.HostileVagrantArmoury.Weapons.Rare.ammo, false, true)
                            else
                                local uncommonThreshold = Config.HostileVagrantArmoury.RarityThresholds.Uncommon
                                if roll > uncommonThreshold then
                                    GiveWeaponToPed(pedData.ped, GetHashKey(Config.HostileVagrantArmoury.Weapons.Uncommon.name), Config.HostileVagrantArmoury.Weapons.Uncommon.ammo, false, true)
                                else
                                    local commonThreshold = Config.HostileVagrantArmoury.RarityThresholds.Common
                                    if roll > commonThreshold then
                                        GiveWeaponToPed(pedData.ped, GetHashKey(Config.HostileVagrantArmoury.Weapons.Common.name), Config.HostileVagrantArmoury.Weapons.Common.ammo, false, true)
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

local critterForaging = false
local critterAtContainer = false
local critterForageDone = false

local function DispatchCritterForage(dumpsterEntity)
    TraceLog("RacoonSearch function started for entity: " .. tostring(dumpsterEntity))

    if not (BLScav_CritterCompanion and DoesEntityExist(BLScav_CritterCompanion)) then
        TraceLog("RacoonPal doesn't exist, returning false")
        return false
    end

    local racoonCoords = GetEntityCoords(BLScav_CritterCompanion)
    local playerCoords = GetEntityCoords(cache.ped)
    local dumpsterCoords = GetEntityCoords(dumpsterEntity)

    local racoonToPlayer = #(racoonCoords - playerCoords)
    TraceLog("Racoon distance from player: " .. racoonToPlayer)
    if racoonToPlayer > 10.0 then
        TraceLog("Racoon too far from player (>10.0), returning false")
        return false
    end

    local racoonToDumpster = #(racoonCoords - dumpsterCoords)
    TraceLog("Racoon distance to dumpster: " .. racoonToDumpster)
    if racoonToDumpster > 50.0 then
        TraceLog("Dumpster too far from racoon (>50.0), returning false")
        return false
    end

    critterForaging = true
    TraceLog("Racoon going to search, heading to player first")
    TaskGoToEntity(BLScav_CritterCompanion, dumpsterEntity, -1, 0.5, 10.0, 0, 0)

    local waitedSeconds = 0
    while critterForaging do
        local distance = #(GetEntityCoords(BLScav_CritterCompanion) - playerCoords)
        TraceLog("Waiting for racoon to reach dumpster, current distance: " .. distance)
        if distance < 2.0 then
            critterForaging = false
            break
        end

        Wait(1000)
        waitedSeconds = waitedSeconds + 1
        if waitedSeconds > 20 then
            TraceLog("Racoon search timed out after 20 seconds, returning false")
            return false
        end
    end

    critterAtContainer = true
    TraceLog("Racoon turning to face dumpster")
    TaskTurnPedToFaceEntity(BLScav_CritterCompanion, dumpsterEntity, 1000)

    SetTimeout(10000, function()
        TraceLog("Racoon search timeout reached, setting racoonSearching to false")
        critterAtContainer = false
    end)

    local animDict = "creatures@cat@move"
    local animName = "walk_start_180_r"
    Framework.LoadAnimDict(animDict)
    TaskPlayAnim(BLScav_CritterCompanion, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(3200)
    TaskPlayAnim(BLScav_CritterCompanion, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(3200)
    TaskPlayAnim(BLScav_CritterCompanion, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(3200)

    while critterAtContainer do
        TraceLog("Racoon is searching...")
        Wait(500)
    end

    critterForageDone = true
    TraceLog("Racoon returning to player")
    TaskGoToEntity(BLScav_CritterCompanion, cache.ped, -1, 0.5, 10.0, 0, 0)

    while critterForageDone do
        local distance = #(GetEntityCoords(BLScav_CritterCompanion) - GetEntityCoords(cache.ped))
        TraceLog("Waiting for racoon to return to player, current distance: " .. distance)
        if distance < 1.5 then
            critterForageDone = false
            break
        end
        Wait(500)
    end

    TraceLog("Racoon has completed search and return")

    local mishapTriggered = false
    if Config.MishapSettings.Enabled then
        mishapTriggered = math.random(1, 100) <= Config.MishapSettings.MishapChance
    end

    TraceLog("Search result calculation - shouldFail: " .. tostring(mishapTriggered))
    return not mishapTriggered
end

local function BeginContainerRummage(anims, targetEntity, isBagMode, hideMode)
    if Config.UseProgressBars and not hideMode then
        local finished = nil
        local animFlag = 49
        if isBagMode then
            animFlag = 0
        end

        if IsPedArmed(cache.ped, 7) then
            SetCurrentPedWeapon(cache.ped, -1569615261, true)
            Wait(1500)
        end

        local mishapTriggered = false
        if Config.MishapSettings.Enabled then
            mishapTriggered = math.random(1, 100) <= Config.MishapSettings.MishapChance
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

        local logLabel = mishapTriggered and "fail anim: " or "anim: "
        TraceLog(logLabel .. animDict .. " " .. animName)

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
                    TriggerEvent("bl_scav:inDumpster", true, targetEntity)
                    TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
                    Wait(math.random(1000, 2000))
                    AttachEntityToEntity(cache.ped, targetEntity, GetPedBoneIndex(targetEntity, 18905), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                    SetEntityVisible(cache.ped, false)
                elseif hideMode == "out" then
                    TriggerEvent("bl_scav:inDumpster", false, targetEntity)
                    DetachEntity(cache.ped, true, true)
                    SetEntityVisible(cache.ped, true)

                    local entityCoords = GetEntityCoords(targetEntity)
                    Framework.Notify(Config.Lang.leaving_dumpster, "info", 1000)
                    TriggerServerEvent("bl_scav:setDumpsterBusy", NetworkGetNetworkIdFromEntity(targetEntity), false)

                    local forward = GetEntityForwardVector(cache.ped)
                    SetEntityCoords(cache.ped, entityCoords.x + (-forward.x), entityCoords.y + (-forward.y), entityCoords.z + Config.ExitConcealmentZOffset, true, false, true, false)

                    if Config.ExitConcealmentAnim then
                        TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
                        while IsEntityPlayingAnim(cache.ped, animDict, animName) do
                            Wait(0)
                        end
                    end

                    SetEntityCollision(targetEntity, true, true)
                    SetEntityCollision(cache.ped, true, true)
                end

                if mishapTriggered then
                    local sharpsRoll = math.random(1, 100)
                    local verminRoll = math.random(1, 100)
                    local currentHealth = GetEntityHealth(cache.ped)
                    local newHealth = math.max(currentHealth - Config.MishapSettings.GenericHealthLoss, 1)

                    if sharpsRoll <= Config.MishapSettings.SharpsChance then
                        if Config.MishapSettings.SharpsEventsEnabled then
                            ApplySharpsInjury()
                        end
                    elseif verminRoll <= Config.MishapSettings.VerminChance then
                        if Config.MishapSettings.VerminEventsEnabled then
                            ApplyVerminBite()
                        end
                    else
                        SetEntityHealth(cache.ped, newHealth)
                        Framework.Notify(Config.Lang.fail, "error", 5000)
                        TraceLog("Current Health: " .. currentHealth .. ", Health Lost: " .. Config.MishapSettings.GenericHealthLoss .. ", New Health: " .. newHealth)

                        Framework.LoadAnimDict(Config.GenericMishapAnim.dict)
                        TaskPlayAnim(cache.ped, Config.GenericMishapAnim.dict, Config.GenericMishapAnim.anim, 8.0, 8.0, -1, 49, 0, false, false, false)

                        local mishapAnimTime = GetAnimDuration(Config.GenericMishapAnim.dict, Config.GenericMishapAnim.anim) * 1000
                        if mishapAnimTime < 2000 then
                            mishapAnimTime = math.random(2700, 4000)
                        end

                        Wait(mishapAnimTime - 500)
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

        isConcealedInBin = false
        finished = finished or false
        if finished then
            finished = not mishapTriggered
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

    local mishapTriggered = false
    if Config.MishapSettings.Enabled then
        mishapTriggered = math.random(1, 100) <= Config.MishapSettings.MishapChance
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
        isConcealedInBin = true
        TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
        Wait(math.random(1000, 2000))
        AttachEntityToEntity(cache.ped, targetEntity, GetPedBoneIndex(targetEntity, 18905), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        TriggerEvent("bl_scav:inDumpster", true, targetEntity)
        SetEntityVisible(cache.ped, false)
    elseif hideMode == "out" then
        isConcealedInBin = false
        TriggerEvent("bl_scav:inDumpster", false, targetEntity)
        DetachEntity(cache.ped, true, true)
        SetEntityVisible(cache.ped, true)

        local entityCoords = GetEntityCoords(targetEntity)
        Framework.Notify(Config.Lang.leaving_dumpster, "info", 1000)
        TriggerServerEvent("bl_scav:setDumpsterBusy", NetworkGetNetworkIdFromEntity(targetEntity), false)

        local forward = GetEntityForwardVector(cache.ped)
        SetEntityCoords(cache.ped, entityCoords.x + (-forward.x), entityCoords.y + (-forward.y), entityCoords.z + Config.ExitConcealmentZOffset, true, false, true, false)

        if Config.ExitConcealmentAnim then
            TaskPlayAnim(cache.ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
            while IsEntityPlayingAnim(cache.ped, animDict, animName) do
                Wait(0)
            end
        end

        SetEntityCollision(targetEntity, true, true)
        SetEntityCollision(cache.ped, true, true)
    end

    local logLabel = mishapTriggered and "fail anim: " or "anim: "
    TraceLog(logLabel .. animDict .. " " .. animName)

    Wait(animTime - 500)
    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)

    if mishapTriggered then
        local sharpsRoll = math.random(1, 100)
        local verminRoll = math.random(1, 100)
        local currentHealth = GetEntityHealth(cache.ped)
        local newHealth = math.max(currentHealth - Config.MishapSettings.GenericHealthLoss, 1)

        if sharpsRoll <= Config.MishapSettings.SharpsChance then
            if Config.MishapSettings.SharpsEventsEnabled then
                ApplySharpsInjury()
            end
        elseif verminRoll <= Config.MishapSettings.VerminChance then
            if Config.MishapSettings.VerminEventsEnabled then
                ApplyVerminBite()
            end
        else
            SetEntityHealth(cache.ped, newHealth)
            Framework.Notify(Config.Lang.fail, "error", 5000)
            TraceLog("Current Health: " .. currentHealth .. ", Health Lost: " .. Config.MishapSettings.GenericHealthLoss .. ", New Health: " .. newHealth)

            Framework.LoadAnimDict(Config.GenericMishapAnim.dict)
            TaskPlayAnim(cache.ped, Config.GenericMishapAnim.dict, Config.GenericMishapAnim.anim, 8.0, 8.0, -1, 49, 0, false, false, false)

            local mishapAnimTime = GetAnimDuration(Config.GenericMishapAnim.dict, Config.GenericMishapAnim.anim) * 1000
            if mishapAnimTime < 2000 then
                mishapAnimTime = math.random(2700, 4000)
            end

            Wait(mishapAnimTime - 500)
            ClearPedTasks(cache.ped)
        end
    end

    RemoveAnimDict(animDict)
    isConcealedInBin = false
    return not mishapTriggered
end

RegisterNetEvent("bl_scav:kickOutOfDumpster", function()
    if not concealmentActive then
        return
    end

    concealmentActive = false
    BeginContainerRummage(BLScav_EvictedAnims, cache.ped, true, "out")
end)

function ReleaseCritterCompanion(entity)
    local animDict = "creatures@cat@amb@world_cat_sleeping_ground@exit"
    local animName = "exit_panic"
    Framework.LoadAnimDict(animDict)
    TaskPlayAnim(entity, animDict, animName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(700)
end

RegisterNetEvent("bl_scav:inDumpster", function(isHiding, targetEntity)
    isConcealedInBin = isHiding
    local netId = NetworkGetNetworkIdFromEntity(targetEntity)

    if isConcealedInBin then
        Framework.Notify(Config.Lang.get_out_dumpster, "error", 10000)
        TriggerServerEvent("bl_scav:setDumpsterBusy", netId, true)
    end

    if not rustleAudioActive then
        if Config.ConcealmentRustleAudio then
            CreateThread(function()
                while isConcealedInBin do
                    rustleAudioId = GetSoundId()
                    PlaySoundFromEntity(rustleAudioId, "Trash_Bag_Land", cache.ped, "DLC_HEIST_SERIES_A_SOUNDS", true, 0)
                    rustleAudioActive = true
                    Wait(math.random(15000, 20000))
                end
            end)
        end
    end

    while isConcealedInBin do
        if isConcealedInBin then
            DisableControlAction(0, 23, true)

            if IsEntityAttached(cache.ped) then
                if not IsControlJustReleased(0, Config.ExitConcealmentKey) then
                    Wait(0)
                    goto continueLoop
                end
            end

            isConcealedInBin = false
            TriggerServerEvent("bl_scav:setDumpsterBusy", netId, false)
            BeginContainerRummage(BLScav_EvictedAnims, cache.ped, true, "out")
            rummageLocked = false

            if rustleAudioId then
                if rustleAudioActive then
                    if Config.ConcealmentRustleAudio then
                        StopSound(rustleAudioId)
                        ReleaseSoundId(rustleAudioId)
                        rustleAudioActive = false
                    end
                end
            end
            break
        end
        ::continueLoop::
        Wait(0)
    end
end)

local function BindRummageProp(models, searchLabel, giveItemsEvent, searchAnims, openLabel, openEvent, stashPrefix, hideLabel, checkFreeEvent, hideAnims)
    if Config.Target then
        Target.AddModel(models, {
            {
                label = searchLabel,
                icon = "fa-solid fa-trash",
                distance = 3.0,
                job = Config.RestrictToJobs,
                onSelect = function(data)
                    rummageLocked = true
                    local entity = data.entity
                    local netId = EnsureEntityNetworked(entity)
                    local coords = GetEntityCoords(entity)
                    local success = BeginContainerRummage(searchAnims, entity)

                    Framework.TriggerCallback("bl_scav:checkDumpsterIsFree", function()
                        if Config.HostileVagrantsEnabled then
                            ProvokeVagrantCrowd(models)
                        end

                        if activeLootZoneName then
                            if activeWatchedZoneName then
                                if activeLootZoneIndex then
                                    TriggerServerEvent("bl_scav:snitch", coords, activeLootZoneIndex)
                                    CustomDispatch(coords)
                                end
                            end
                        end

                        if success then
                            Framework.TriggerCallback(giveItemsEvent, function(itemsGiven) end, netId, coords, activeLootZoneIndex)
                        end
                    end, netId)

                    rummageLocked = false
                end,
                canInteract = function(entity)
                    if IsEntityAMissionEntity(entity) then
                        return false
                    end

                    local isDead = Framework.IsPlayerDead()
                    if not (BLScav_Sedated or rummageLocked or isDead) then
                        return true
                    end
                    return false
                end,
            },
            {
                label = Config.Lang.raccoon_search,
                icon = "fas fa-paw",
                distance = 30.0,
                job = Config.VagrantJobRole,
                onSelect = function(data)
                    critterOptionBusy = true
                    local entity = data.entity
                    local netId = EnsureEntityNetworked(entity)
                    local coords = GetEntityCoords(entity)
                    local critterReady = DispatchCritterForage(entity)

                    if critterReady then
                        if BLScav_CritterCompanion and DoesEntityExist(BLScav_CritterCompanion) and not IsEntityDead(BLScav_CritterCompanion) then
                            while rummageLocked do
                                Wait(500)
                            end

                            if BLScav_CritterCompanion and DoesEntityExist(BLScav_CritterCompanion) and not IsEntityDead(BLScav_CritterCompanion) then
                                TaskTurnPedToFaceEntity(BLScav_CritterCompanion, cache.ped, 1000)
                                Wait(500)
                                TaskTurnPedToFaceEntity(cache.ped, BLScav_CritterCompanion, 1000)
                                Wait(1000)
                                TaskStartScenarioInPlace(cache.ped, "CODE_HUMAN_MEDIC_KNEEL", 0, true)
                                Wait(5000)

                                Framework.TriggerCallback(giveItemsEvent, function() end, netId, coords, activeLootZoneIndex)

                                Wait(1000)
                                ClearPedTasks(cache.ped)
                            end
                        end
                    end

                    if BLScav_CritterCompanion and DoesEntityExist(BLScav_CritterCompanion) and not IsEntityDead(BLScav_CritterCompanion) then
                        TaskFollowToOffsetOfEntity(BLScav_CritterCompanion, cache.ped, 1.0, 1.0, 0.0, 5.0, -1, 1.0, true)
                    end

                    critterOptionBusy = false
                end,
                canInteract = function()
                    if not BLScav_CritterCompanion then
                        return false
                    end

                    local critterActionable = not IsEntityDead(BLScav_CritterCompanion)
                    if critterActionable then
                        critterActionable = not DoesEntityExist(BLScav_CritterCompanion) == false
                    end

                    if not (BLScav_Sedated or critterOptionBusy or critterActionable) then
                        return true
                    end
                    return false
                end,
            },
        })

        if Config.ContainerStorageEnabled then
            Target.AddModel(models, {
                {
                    label = openLabel,
                    icon = "fa-solid fa-trash",
                    distance = 3.0,
                    job = Config.RestrictToJobs,
                    onSelect = function(data)
                        rummageLocked = true
                        local entity = data.entity
                        local netId = EnsureEntityNetworked(entity)
                        local coords = GetEntityCoords(entity)
                        local success = BeginContainerRummage(searchAnims, entity)

                        if Config.HostileVagrantsEnabled then
                            ProvokeVagrantCrowd(models)
                        end

                        Framework.TriggerCallback(openEvent, function(hash)
                            if activeLootZoneName then
                                if activeWatchedZoneName then
                                    if activeLootZoneIndex then
                                        TriggerServerEvent("bl_scav:snitch", coords, activeLootZoneIndex)
                                        CustomDispatch(coords)
                                    end
                                end
                            end

                            if success and hash then
                                Framework.OpenStash(stashPrefix .. hash)
                            end
                        end, netId, coords)

                        rummageLocked = false
                    end,
                    canInteract = function(entity)
                        if IsEntityAMissionEntity(entity) then
                            return false
                        end

                        local isDead = Framework.IsPlayerDead()
                        if not (BLScav_Sedated or rummageLocked or isDead) then
                            return true
                        end
                        return false
                    end,
                },
            })
        end

        if hideLabel and checkFreeEvent then
            if Config.ConcealmentEnabled then
                Target.AddModel(models, {
                    {
                        label = hideLabel,
                        icon = "fa-solid fa-trash",
                        distance = 3.0,
                        job = Config.RestrictToJobs,
                        onSelect = function(data)
                            rummageLocked = true
                            local entity = data.entity
                            local netId = EnsureEntityNetworked(entity)
                            local coords = GetEntityCoords(entity)
                            local success = BeginContainerRummage(searchAnims, entity)

                            if Config.HostileVagrantsEnabled then
                                ProvokeVagrantCrowd(models)
                            end

                            Framework.TriggerCallback(checkFreeEvent, function(isFree)
                                if activeLootZoneName then
                                    if activeWatchedZoneName then
                                        if activeLootZoneIndex then
                                            TriggerServerEvent("bl_scav:snitch", coords, activeLootZoneIndex)
                                            CustomDispatch(coords)
                                        end
                                    end
                                end

                                if success and isFree then
                                    FreezeEntityPosition(cache.ped, true)
                                    concealmentActive = BeginContainerRummage(hideAnims, entity, true, "in")
                                    if concealmentActive then
                                        FreezeEntityPosition(cache.ped, false)
                                    end
                                end
                            end, netId, coords)

                            rummageLocked = false
                        end,
                        canInteract = function()
                            local isDead = Framework.IsPlayerDead()
                            if not (BLScav_Sedated or rummageLocked or isDead) then
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
                return not rummageLocked
            end,
            selected = function(data)
                if rummageLocked then
                    return
                end
                rummageLocked = true

                local entity = data.entity
                local netId = EnsureEntityNetworked(entity)
                local coords = GetEntityCoords(entity)
                local success = BeginContainerRummage(searchAnims, entity)

                Framework.TriggerCallback("bl_scav:checkDumpsterIsFree", function()
                    if Config.HostileVagrantsEnabled then
                        ProvokeVagrantCrowd(models)
                    end

                    if activeLootZoneName then
                        if activeWatchedZoneName then
                            if activeLootZoneIndex then
                                TriggerServerEvent("bl_scav:snitch", coords, activeLootZoneIndex)
                                CustomDispatch(coords)
                            end
                        end
                    end

                    if success then
                        Framework.TriggerCallback(giveItemsEvent, function() end, netId, coords, activeLootZoneIndex)
                    end
                end, netId)

                rummageLocked = false
            end,
        })

        table.insert(options, {
            label = "[E] - " .. Config.Lang.raccoon_search,
            canSee = function()
                local isHobo = Framework.Player.Job.Name == Config.VagrantJobRole
                if BLScav_CritterCompanion then
                    if not critterOptionBusy then
                        return isHobo
                    end
                end
                return false
            end,
            selected = function(data)
                if BLScav_CritterCompanion then
                    if critterOptionBusy then
                        return
                    end
                end

                critterOptionBusy = true
                local entity = data.entity
                local netId = EnsureEntityNetworked(entity)
                local coords = GetEntityCoords(entity)
                local critterReady = DispatchCritterForage(entity)

                if critterReady then
                    if BLScav_CritterCompanion and DoesEntityExist(BLScav_CritterCompanion) and not IsEntityDead(BLScav_CritterCompanion) then
                        while rummageLocked do
                            Wait(500)
                        end

                        if BLScav_CritterCompanion and DoesEntityExist(BLScav_CritterCompanion) and not IsEntityDead(BLScav_CritterCompanion) then
                            TaskTurnPedToFaceEntity(BLScav_CritterCompanion, cache.ped, 1000)
                            Wait(500)
                            TaskTurnPedToFaceEntity(cache.ped, BLScav_CritterCompanion, 1000)
                            Wait(1000)
                            TaskStartScenarioInPlace(cache.ped, "CODE_HUMAN_MEDIC_KNEEL", 0, true)
                            Wait(5000)

                            Framework.TriggerCallback(giveItemsEvent, function() end, netId, coords, activeLootZoneIndex)

                            Wait(1000)
                            ClearPedTasks(cache.ped)
                        end
                    end
                end

                if BLScav_CritterCompanion and DoesEntityExist(BLScav_CritterCompanion) and not IsEntityDead(BLScav_CritterCompanion) then
                    TaskFollowToOffsetOfEntity(BLScav_CritterCompanion, cache.ped, 1.0, 1.0, 0.0, 5.0, -1, 1.0, true)
                end

                critterOptionBusy = false
            end,
        })

        if Config.ContainerStorageEnabled then
            table.insert(options, {
                label = "[E] - " .. openLabel,
                canSee = function()
                    return not rummageLocked
                end,
                selected = function(data)
                    if rummageLocked then
                        return
                    end
                    rummageLocked = true

                    local entity = data.entity
                    local netId = EnsureEntityNetworked(entity)
                    local coords = GetEntityCoords(entity)
                    local success = BeginContainerRummage(searchAnims, entity)

                    if Config.HostileVagrantsEnabled then
                        ProvokeVagrantCrowd(models)
                    end

                    Framework.TriggerCallback(openEvent, function(hash)
                        if activeLootZoneName then
                            if activeWatchedZoneName then
                                if activeLootZoneIndex then
                                    TriggerServerEvent("bl_scav:snitch", coords, activeLootZoneIndex)
                                    CustomDispatch(coords)
                                end
                            end
                        end

                        if success and hash then
                            Framework.OpenStash(stashPrefix .. hash)
                        end
                    end, netId, coords)

                    rummageLocked = false
                end,
            })
        end

        if hideLabel and checkFreeEvent then
            if Config.ConcealmentEnabled then
                table.insert(options, {
                    label = "[E] -" .. hideLabel,
                    canSee = function()
                        return not rummageLocked
                    end,
                    selected = function(data)
                        if rummageLocked then
                            return
                        end
                        rummageLocked = true

                        local entity = data.entity
                        local netId = EnsureEntityNetworked(entity)
                        local coords = GetEntityCoords(entity)
                        local success = BeginContainerRummage(searchAnims, entity)

                        if Config.HostileVagrantsEnabled then
                            ProvokeVagrantCrowd(models)
                        end

                        Framework.TriggerCallback(checkFreeEvent, function(isFree)
                            if activeLootZoneName then
                                if activeWatchedZoneName then
                                    if activeLootZoneIndex then
                                        TriggerServerEvent("bl_scav:snitch", coords, activeLootZoneIndex)
                                        CustomDispatch(coords)
                                    end
                                end
                            end

                            if success and isFree then
                                FreezeEntityPosition(cache.ped, true)
                                concealmentActive = BeginContainerRummage(hideAnims, entity, true, "in")
                                if concealmentActive then
                                    FreezeEntityPosition(cache.ped, false)
                                end
                            end
                        end, netId, coords)

                        rummageLocked = false
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

local function BindOperatorProps()
    for customIndex, custom in pairs(BLScav_OperatorProps) do
        if Config.Target then
            Target.AddModel(custom.models, {
                {
                    label = custom.label,
                    icon = "fa-solid fa-search",
                    distance = 3.0,
                    job = Config.RestrictToJobs,
                    onSelect = function(data)
                        rummageLocked = true
                        local entity = data.entity
                        local netId = EnsureEntityNetworked(entity)
                        local coords = GetEntityCoords(entity)
                        local success = BeginContainerRummage(custom.anims, entity)

                        if Config.HostileVagrantsEnabled then
                            ProvokeVagrantCrowd(custom.models)
                        end

                        if custom.isStealing then
                            CustomDispatch(coords)
                        end

                        if activeLootZoneName then
                            if activeWatchedZoneName then
                                if activeLootZoneIndex then
                                    TriggerServerEvent("bl_scav:snitch", coords, activeLootZoneIndex)
                                    CustomDispatch(coords)
                                end
                            end
                        end

                        if success then
                            Framework.TriggerCallback("bl_scav:GiveItemsCustom", function() end, netId, coords, activeLootZoneIndex, customIndex)

                            if custom.deleteProp then
                                Wait(500)
                                SetEntityAsMissionEntity(entity, true, true)
                                local deleteNetId = EnsureEntityNetworked(entity)
                                DeleteEntity(entity)
                                if not DoesEntityExist(entity) then
                                    TriggerServerEvent("bl_scav:server:deleteEntity", deleteNetId)
                                end
                                rummageLocked = false
                            end
                        end

                        rummageLocked = false
                    end,
                    canInteract = function(entity)
                        if IsEntityAMissionEntity(entity) then
                            return false
                        end

                        local isDead = Framework.IsPlayerDead()
                        if not (BLScav_Sedated or rummageLocked or isDead) then
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
                                return not rummageLocked
                            end,
                            selected = function(data)
                                if rummageLocked then
                                    return
                                end
                                rummageLocked = true

                                local entity = data.entity
                                local netId = EnsureEntityNetworked(entity)
                                local coords = GetEntityCoords(entity)
                                local success = BeginContainerRummage(custom.anims, entity)

                                if Config.HostileVagrantsEnabled then
                                    ProvokeVagrantCrowd(custom.models)
                                end

                                if custom.isStealing then
                                    CustomDispatch(coords)
                                end

                                if activeLootZoneName then
                                    if activeWatchedZoneName then
                                        if activeLootZoneIndex then
                                            TriggerServerEvent("bl_scav:snitch", coords, activeLootZoneIndex)
                                            CustomDispatch(coords)
                                        end
                                    end
                                end

                                if success then
                                    Framework.TriggerCallback("bl_scav:GiveItemsCustom", function() end, netId, coords, activeLootZoneIndex, customIndex)

                                    if custom.deleteProp then
                                        Wait(500)
                                        SetEntityAsMissionEntity(entity, true, true)
                                        local deleteNetId = EnsureEntityNetworked(entity)
                                        DeleteEntity(entity)
                                        if DoesEntityExist(entity) then
                                            TriggerServerEvent("bl_scav:server:deleteEntity", deleteNetId)
                                        end
                                    end

                                    rummageLocked = false
                                end

                                rummageLocked = false
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

    BindRummageProp(BLScav_ShorelineBinModels, Config.Lang.search_garbage, "bl_scav:GiveItemsBeach", BLScav_ShorelineBinAnims, Config.Lang.open_garbage, "bl_scav:OpenBeach", "Beach")
    BindRummageProp(BLScav_SkipModels, Config.Lang.search_dumpster, "bl_scav:GiveItemsDumpster", BLScav_SkipAnims, Config.Lang.open_dumpster, "bl_scav:OpenDumpster", "Dumpster", Config.Lang.hide_in_dumpster, "bl_scav:checkDumpsterIsFree", BLScav_ConcealAnims)
    BindRummageProp(BLScav_StreetBinModels, Config.Lang.search_garbage, "bl_scav:GiveItemsGarbageCans", BLScav_StreetBinAnims, Config.Lang.open_garbage, "bl_scav:OpenGarbage", "Garbage")
    BindRummageProp(BLScav_EncampmentModels, Config.Lang.search, "bl_scav:GiveItemsOther", BLScav_StreetBinAnims, Config.Lang.open, "bl_scav:OpenOther", "Hobo")

    if BLScav_OperatorProps then
        if BLScav_OperatorProps[1] then
            BindOperatorProps()
        end
    end

    if Config.Target then
        Target.AddModel(BLScav_RefuseSackModels, {
            {
                label = Config.Lang.inspect,
                icon = "fa-solid fa-trash",
                distance = 3.0,
                job = Config.RestrictToJobs,
                onSelect = function(data)
                    rummageLocked = true
                    local entity = data.entity
                    local netId = EnsureEntityNetworked(entity)
                    local success = BeginContainerRummage(BLScav_RefuseSackAnims, entity)

                    if Config.HostileVagrantsEnabled then
                        ProvokeVagrantCrowd()
                    end

                    if success and netId then
                        Framework.Notify(Config.Lang.garbagebag, "success")
                        SetEntityCanBeTargetedWithoutLos(entity, true)
                        TrackSackProp(entity)
                    end

                    rummageLocked = false
                end,
                canInteract = function()
                    if not (BLScav_Sedated or rummageLocked or checkedBag) then
                        return true
                    end
                    return false
                end,
            },
        })
    else
        exports["envi-interact"]:InteractionModel(BLScav_RefuseSackModels, {
            {
                name = "dumpster_interaction",
                distance = 1.5,
                radius = 5.0,
                options = {
                    {
                        label = Config.Lang.inspect,
                        canSee = function()
                            return not (checkedBag or BLScav_Sedated)
                        end,
                        selected = function(data)
                            rummageLocked = true
                            local entity = data.entity
                            local netId = EnsureEntityNetworked(entity)
                            local success = BeginContainerRummage(BLScav_RefuseSackAnims, entity)

                            if Config.HostileVagrantsEnabled then
                                ProvokeVagrantCrowd()
                            end

                            if success and netId then
                                Framework.Notify(Config.Lang.garbagebag, "success")
                                SetEntityCanBeTargetedWithoutLos(entity, true)
                                TrackSackProp(entity)
                            end

                            rummageLocked = false
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
        if Config.DiagnosticsEnabled then
            print("Waiting for player to load")
        end
    end

    while Framework.Player.Identifier do
        local bottles = Framework.GetItem("hobo_bottle", { uses = 0 })
        if bottles[1] then
            if bottles[1].count then
                if bottles[1].count > 0 then
                    if IsEntityInWater(cache.ped) then
                        TriggerServerEvent("bl_scav:server:RefillBottle", bottles[1].slot)
                    end
                end
            end
        end
        Wait(5000)
    end
end)

local trackedSackEntity = nil
local trackedSackDistance = 0.0

function TrackSackProp(bagEntity)
    if trackedSackEntity then
        TraceLog("Already tracking a bag, returning")
        return
    end

    trackedSackEntity = bagEntity

    CreateThread(function()
        while trackedSackEntity do
            Wait(1000)

            local distance = #(GetEntityCoords(trackedSackEntity) - GetEntityCoords(cache.ped))
            if distance < 100 then
                trackedSackDistance = distance
            end

            local health = GetEntityHealth(trackedSackEntity)
            TraceLog("Bag distance: " .. tostring(distance) .. ", HP: " .. tostring(health))

            if health <= 0 then
                TraceLog("Bag destroyed")

                if trackedSackDistance <= 5.0 then
                    TraceLog("Player close enough, triggering callback")

                    Framework.TriggerCallback("bl_scav:GiveItemsBags", function(success)
                        if success then
                            TraceLog("Successfully got items from bag")
                            Framework.Notify(Config.Lang.success, "success", 5000)
                            trackedSackEntity = nil
                        else
                            TraceLog("Failed to get items from bag")
                            trackedSackEntity = nil
                        end
                    end, netId, distance, activeLootZoneIndex)
                    break
                else
                    trackedSackEntity = nil
                    break
                end
            else
                if trackedSackDistance > 10.0 then
                    TraceLog("Player too far away, stopping tracking")
                    trackedSackEntity = nil
                    break
                end
            end
        end
    end)
end
