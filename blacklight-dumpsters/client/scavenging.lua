--[[ ==========================================================================
     BlackLight Dumpsters — Core Scavenging Loop (client)
========================================================================== ]]

local random, floor, max = math.random, math.floor, math.max
local insert = table.insert

-- Shared across the resource (read by customisable.lua and other modules)
ScavengerImpaired = false

local searchLocked = false
local companionBusy = false
local districtName = nil
local districtIndex = nil
local watchedDistrictName = nil
local concealed = false
local concealmentOngoing = false
local rustleActive = false
local rustleHandle = nil

--- Console output gated behind Settings.DiagnosticMode.
function LogDiagnostic(message)
    if Settings.DiagnosticMode then
        print(("[^3BlackLight^7] %s"):format(message))
    end
end

-- --------------------------------------------------------------------------
--  SIGNATURE DISTRICT TRACKING
-- --------------------------------------------------------------------------

CreateThread(function()
    for index, district in pairs(Settings.SignatureLootDistricts) do
        Zone.SphereZone({
            coords = district.coords,
            radius = district.radius,
            zoneName = district.name,
            debug = Settings.DiagnosticMode,
            onEnter = function(zoneData)
                LogDiagnostic("Entered signature district: " .. zoneData.zoneName)
                districtName = zoneData.zoneName
                districtIndex = index
                if district.watched then
                    watchedDistrictName = zoneData.zoneName
                end
            end,
            onExit = function()
                LogDiagnostic("Left signature district: " .. tostring(districtName))
                districtName = nil
                districtIndex = nil
                watchedDistrictName = nil
            end,
        })
    end
end)

--- Guarantees an entity is networked and returns its network id.
local function EnsureNetworked(entity)
    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        SetNetworkIdCanMigrate(NetworkGetNetworkIdFromEntity(entity), true)
        Framework.NetworkRequestControlOfEntity(entity)
    end
    return NetworkGetNetworkIdFromEntity(entity)
end

-- --------------------------------------------------------------------------
--  TERRITORIAL VAGRANTS
-- --------------------------------------------------------------------------

--- Nearby street dwellers take offence at you raiding their patch.
---@param searchableSet table|nil The model set being searched (encampments double the radius).
function ProvokeLocalVagrants(searchableSet)
    local playerCoords = GetEntityCoords(cache.ped)
    local radius = Settings.HostileVagrantRadius

    -- Fellow street dwellers are never provoked.
    if Framework.HasJob(Settings.VagrantJobName, Framework.Player) then
        return
    end

    if searchableSet == Settings.EncampmentModels then
        radius = Settings.HostileVagrantRadius * 2
        LogDiagnostic("Encampment prop searched — hostile radius widened to " .. radius .. " units")
    end

    local nearby = Framework.GetNearbyPeds(playerCoords, radius)
    local armaments = Settings.VagrantArmaments

    for _, entry in pairs(nearby) do
        local ped = entry.ped

        if not IsPedAPlayer(ped) then
            local model = GetEntityModel(ped)

            for _, modelName in pairs(Settings.VagrantModels) do
                SetPedFleeAttributes(ped, 0, 0)
                SetPedCombatAttributes(ped, 46, 1)
                SetPedCombatAttributes(ped, 5, 1)

                if model == GetHashKey(modelName) then
                    local roll = random(1, 100)
                    local streetArms = armaments and armaments.StreetArms and armaments.StreetArms.enabled

                    if streetArms then
                        if random(1, 100) <= armaments.StreetArms.chance then
                            local pool = armaments.StreetArms.weapons
                            GiveWeaponToPed(ped, GetHashKey(pool[random(1, #pool)]), 0, false, true)
                        elseif roll > armaments.Thresholds.Rare then
                            GiveWeaponToPed(ped, GetHashKey(armaments.Loadouts.Rare.name), armaments.Loadouts.Rare.ammo, false, true)
                        elseif roll > armaments.Thresholds.Uncommon then
                            GiveWeaponToPed(ped, GetHashKey(armaments.Loadouts.Uncommon.name), armaments.Loadouts.Uncommon.ammo, false, true)
                        elseif roll > armaments.Thresholds.Common then
                            GiveWeaponToPed(ped, GetHashKey(armaments.Loadouts.Common.name), armaments.Loadouts.Common.ammo, false, true)
                        end
                    end

                    TaskCombatPed(ped, cache.ped, 0, 16)
                end
            end
        end
    end
end

-- --------------------------------------------------------------------------
--  BANDIT COMPANION ASSISTED SEARCHING
-- --------------------------------------------------------------------------

local companionEnRoute = false
local companionRummaging = false
local companionReturning = false

--- Sends the tamed bandit companion off to rifle a container on your behalf.
---@return boolean success
local function DispatchCompanion(containerEntity)
    LogDiagnostic("Companion dispatch started for entity: " .. tostring(containerEntity))

    if not (BanditCompanion and DoesEntityExist(BanditCompanion)) then
        LogDiagnostic("No companion present — aborting")
        return false
    end

    local companionCoords = GetEntityCoords(BanditCompanion)
    local playerCoords = GetEntityCoords(cache.ped)
    local containerCoords = GetEntityCoords(containerEntity)

    local companionToPlayer = #(companionCoords - playerCoords)
    LogDiagnostic("Companion distance from player: " .. companionToPlayer)
    if companionToPlayer > 10.0 then
        LogDiagnostic("Companion strayed too far (>10.0) — aborting")
        return false
    end

    local companionToContainer = #(companionCoords - containerCoords)
    LogDiagnostic("Companion distance to container: " .. companionToContainer)
    if companionToContainer > 50.0 then
        LogDiagnostic("Container out of companion range (>50.0) — aborting")
        return false
    end

    companionEnRoute = true
    LogDiagnostic("Companion heading to the container")
    TaskGoToEntity(BanditCompanion, containerEntity, -1, 0.5, 10.0, 0, 0)

    local waited = 0
    while companionEnRoute do
        local distance = #(GetEntityCoords(BanditCompanion) - playerCoords)
        LogDiagnostic("Awaiting companion arrival, distance: " .. distance)
        if distance < 2.0 then
            companionEnRoute = false
            break
        end

        Wait(1000)
        waited = waited + 1
        if waited > 20 then
            LogDiagnostic("Companion timed out after 20 seconds — aborting")
            return false
        end
    end

    companionRummaging = true
    LogDiagnostic("Companion turning to face the container")
    TaskTurnPedToFaceEntity(BanditCompanion, containerEntity, 1000)

    SetTimeout(10000, function()
        LogDiagnostic("Companion rummage window elapsed")
        companionRummaging = false
    end)

    local clipDict = "creatures@cat@move"
    local clipName = "walk_start_180_r"
    Framework.LoadAnimDict(clipDict)

    for _ = 1, 3 do
        TaskPlayAnim(BanditCompanion, clipDict, clipName, 8.0, 8.0, -1, 0, 0, false, false, false)
        Wait(3200)
    end

    while companionRummaging do
        LogDiagnostic("Companion still rummaging...")
        Wait(500)
    end

    companionReturning = true
    LogDiagnostic("Companion returning to owner")
    TaskGoToEntity(BanditCompanion, cache.ped, -1, 0.5, 10.0, 0, 0)

    while companionReturning do
        local distance = #(GetEntityCoords(BanditCompanion) - GetEntityCoords(cache.ped))
        LogDiagnostic("Awaiting companion return, distance: " .. distance)
        if distance < 1.5 then
            companionReturning = false
            break
        end
        Wait(500)
    end

    LogDiagnostic("Companion run complete")

    local mishap = false
    if Settings.Mishaps.Enabled then
        mishap = random(1, 100) <= Settings.Mishaps.MishapChance
    end

    LogDiagnostic("Companion outcome — mishap: " .. tostring(mishap))
    return not mishap
end

-- --------------------------------------------------------------------------
--  RUMMAGE ROUTINE
-- --------------------------------------------------------------------------

--- Resolves the shared mishap branch after a rummage completes.
local function ResolveMishap()
    local sharpsRoll = random(1, 100)
    local verminRoll = random(1, 100)
    local currentHealth = GetEntityHealth(cache.ped)
    local reducedHealth = max(currentHealth - Settings.Mishaps.GenericHealthCost, 1)

    if sharpsRoll <= Settings.Mishaps.SharpsChance then
        if Settings.Mishaps.SharpsEnabled then
            ApplySharpsAffliction()
        end
        return
    end

    if verminRoll <= Settings.Mishaps.VerminChance then
        if Settings.Mishaps.VerminEnabled then
            ApplyVerminAmbush()
        end
        return
    end

    SetEntityHealth(cache.ped, reducedHealth)
    Framework.Notify(Settings.Text.mishap_generic, "error", 5000)
    LogDiagnostic(("Health %s -> %s (-%s)"):format(currentHealth, reducedHealth, Settings.Mishaps.GenericHealthCost))

    local clip = Settings.GenericMishapClip
    Framework.LoadAnimDict(clip.dict)
    TaskPlayAnim(cache.ped, clip.dict, clip.anim, 8.0, 8.0, -1, 49, 0, false, false, false)

    local clipMs = GetAnimDuration(clip.dict, clip.anim) * 1000
    if clipMs < 2000 then
        clipMs = random(2700, 4000)
    end

    Wait(clipMs - 500)
    ClearPedTasks(cache.ped)
end

--- Handles the concealment exit sequence shared by both rummage paths.
local function PerformConcealmentExit(targetEntity, clipDict, clipName, clipFlag)
    TriggerEvent("bl_dumpsters:client:ConcealmentState", false, targetEntity)
    DetachEntity(cache.ped, true, true)
    SetEntityVisible(cache.ped, true)

    local entityCoords = GetEntityCoords(targetEntity)
    Framework.Notify(Settings.Text.climbing_out, "info", 1000)
    TriggerServerEvent("bl_dumpsters:server:FlagSkipOccupied", NetworkGetNetworkIdFromEntity(targetEntity), false)

    local forward = GetEntityForwardVector(cache.ped)
    SetEntityCoords(cache.ped, entityCoords.x - forward.x, entityCoords.y - forward.y, entityCoords.z + Settings.ExitLiftHeight, true, false, true, false)

    if Settings.PlayExitClipOnLeave then
        TaskPlayAnim(cache.ped, clipDict, clipName, 8.0, 8.0, -1, clipFlag, 0, false, false, false)
        while IsEntityPlayingAnim(cache.ped, clipDict, clipName) do
            Wait(0)
        end
    end

    SetEntityCollision(targetEntity, true, true)
    SetEntityCollision(cache.ped, true, true)
end

--- Plays the rummage animation / progress bar and resolves the mishap roll.
---@param clips table Animation set to draw from.
---@param targetEntity number Prop being searched.
---@param sackMode boolean|nil Sacks use animation flag 0 rather than 49.
---@param concealMode string|nil "in" or "out" for the concealment sequences.
---@return boolean success True when the search produced no mishap.
function PerformRummage(clips, targetEntity, sackMode, concealMode)
    local clipFlag = sackMode and 0 or 49

    if IsPedArmed(cache.ped, 7) then
        SetCurrentPedWeapon(cache.ped, -1569615261, true)
        Wait(1500)
    end

    local mishap = false
    if Settings.Mishaps.Enabled then
        mishap = random(1, 100) <= Settings.Mishaps.MishapChance
    end

    local pick = clips[random(1, #clips)]
    local clipDict, clipName = pick.dict, pick.anim

    LogDiagnostic((mishap and "mishap clip: " or "clip: ") .. clipDict .. " " .. clipName)

    -- ---------------- Progress bar variant ----------------
    if Settings.UseProgressBars and not concealMode then
        local finished = nil

        TaskTurnPedToFaceEntity(cache.ped, targetEntity, 1000)
        Wait(500)
        TaskPlayAnim(cache.ped, clipDict, clipName, 8.0, 8.0, -1, clipFlag, 0, false, false, false)

        local clipMs = GetAnimDuration(clipDict, clipName) * 1000
        if clipMs < 2000 then
            clipMs = random(2700, 4000)
        end

        lib.progressBar({
            label = Settings.Text.rummaging,
            duration = clipMs,
            canCancel = false,
            anim = { dict = clipDict, clip = clipName, flag = clipFlag },
            disable = { move = true, combat = true, vehicle = true },
            onFinish = function()
                finished = true
                ClearPedTasks(cache.ped)

                if mishap then
                    ResolveMishap()
                end

                RemoveAnimDict(clipDict)
            end,
        })

        while finished == nil do
            if Framework.IsPlayerDead() then
                break
            end
            Wait(50)
        end

        concealed = false
        return (finished == true) and not mishap
    end

    -- ---------------- Timed animation variant ----------------
    local clipMs = GetAnimDuration(clipDict, clipName) * 1000
    if clipMs < 2000 then
        clipMs = random(2700, 4000)
    end

    TaskTurnPedToFaceEntity(cache.ped, targetEntity, 1000)
    Wait(1000)
    FreezeEntityPosition(cache.ped, true)
    Framework.LoadAnimDict(clipDict)

    if concealMode then
        local playerCoords = GetEntityCoords(cache.ped)
        SetEntityCoords(cache.ped, playerCoords.x, playerCoords.y, playerCoords.z + 0.05)
    else
        TaskPlayAnim(cache.ped, clipDict, clipName, 8.0, 8.0, -1, clipFlag, 0, false, false, false)
    end

    if concealMode == "in" then
        concealed = true
        TaskPlayAnim(cache.ped, clipDict, clipName, 8.0, 8.0, -1, clipFlag, 0, false, false, false)
        Wait(random(1000, 2000))
        AttachEntityToEntity(cache.ped, targetEntity, GetPedBoneIndex(targetEntity, 18905), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        TriggerEvent("bl_dumpsters:client:ConcealmentState", true, targetEntity)
        SetEntityVisible(cache.ped, false)
    elseif concealMode == "out" then
        concealed = false
        PerformConcealmentExit(targetEntity, clipDict, clipName, clipFlag)
    end

    Wait(clipMs - 500)
    ClearPedTasks(cache.ped)
    FreezeEntityPosition(cache.ped, false)

    if mishap then
        ResolveMishap()
    end

    RemoveAnimDict(clipDict)
    concealed = false
    return not mishap
end

-- --------------------------------------------------------------------------
--  CONCEALMENT
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:client:EvictFromSkip", function()
    if not concealmentOngoing then
        return
    end

    concealmentOngoing = false
    PerformRummage(Settings.ClimbOutClips, cache.ped, true, "out")
end)

--- Plays the startled animation on a bandit ped. Shared with customisable.lua.
function PlayBanditStartle(entity)
    local clipDict = "creatures@cat@amb@world_cat_sleeping_ground@exit"
    local clipName = "exit_panic"
    Framework.LoadAnimDict(clipDict)
    TaskPlayAnim(entity, clipDict, clipName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(700)
end

RegisterNetEvent("bl_dumpsters:client:ConcealmentState", function(hiding, targetEntity)
    concealed = hiding
    local netId = NetworkGetNetworkIdFromEntity(targetEntity)

    if concealed then
        Framework.Notify(Settings.Text.skip_exit_prompt, "error", 10000)
        TriggerServerEvent("bl_dumpsters:server:FlagSkipOccupied", netId, true)
    end

    -- Periodic rustling so hidden players can be sniffed out.
    if Settings.ConcealmentNoise and not rustleActive then
        CreateThread(function()
            while concealed do
                rustleHandle = GetSoundId()
                PlaySoundFromEntity(rustleHandle, "Trash_Bag_Land", cache.ped, "DLC_HEIST_SERIES_A_SOUNDS", true, 0)
                rustleActive = true
                Wait(random(15000, 20000))
            end
        end)
    end

    while concealed do
        Wait(0)
        DisableControlAction(0, 23, true)

        if IsEntityAttached(cache.ped) and not IsControlJustReleased(0, Settings.ConcealmentExitKey) then
            goto continue
        end

        concealed = false
        TriggerServerEvent("bl_dumpsters:server:FlagSkipOccupied", netId, false)
        PerformRummage(Settings.ClimbOutClips, cache.ped, true, "out")
        searchLocked = false

        if rustleHandle and rustleActive and Settings.ConcealmentNoise then
            StopSound(rustleHandle)
            ReleaseSoundId(rustleHandle)
            rustleActive = false
        end
        break

        ::continue::
    end
end)

-- --------------------------------------------------------------------------
--  DISTRICT / INFORMANT HELPER
-- --------------------------------------------------------------------------

--- Reports the player if they looted inside a watched district.
local function MaybeTipOffAuthorities(coords)
    if districtName and watchedDistrictName and districtIndex then
        TriggerServerEvent("bl_dumpsters:server:ReportScavenger", coords, districtIndex)
        RelayTheftReport(coords)
    end
end

-- --------------------------------------------------------------------------
--  INTERACTION REGISTRATION
-- --------------------------------------------------------------------------

--- Shared body for the "search" interaction on any container family.
local function RunContainerSearch(models, clips, lootCallback, entity)
    searchLocked = true

    local netId = EnsureNetworked(entity)
    local coords = GetEntityCoords(entity)
    local success = PerformRummage(clips, entity)

    Framework.TriggerCallback("bl_dumpsters:server:IsSkipVacant", function()
        if Settings.HostileVagrantsEnabled then
            ProvokeLocalVagrants(models)
        end

        MaybeTipOffAuthorities(coords)

        if success then
            Framework.TriggerCallback(lootCallback, function() end, netId, coords, districtIndex)
        end
    end, netId)

    searchLocked = false
end

--- Shared body for the "open stash" interaction on any container family.
local function RunContainerStash(models, clips, stashCallback, stashPrefix, entity)
    searchLocked = true

    local netId = EnsureNetworked(entity)
    local coords = GetEntityCoords(entity)
    local success = PerformRummage(clips, entity)

    if Settings.HostileVagrantsEnabled then
        ProvokeLocalVagrants(models)
    end

    Framework.TriggerCallback(stashCallback, function(hash)
        MaybeTipOffAuthorities(coords)

        if success and hash then
            Framework.OpenStash(stashPrefix .. hash)
        end
    end, netId, coords)

    searchLocked = false
end

--- Shared body for the "climb inside" interaction (skips only).
local function RunConcealment(models, clips, vacancyCallback, concealClips, entity)
    searchLocked = true

    local netId = EnsureNetworked(entity)
    local coords = GetEntityCoords(entity)
    local success = PerformRummage(clips, entity)

    if Settings.HostileVagrantsEnabled then
        ProvokeLocalVagrants(models)
    end

    Framework.TriggerCallback(vacancyCallback, function(vacant)
        MaybeTipOffAuthorities(coords)

        if success and vacant then
            FreezeEntityPosition(cache.ped, true)
            concealmentOngoing = PerformRummage(concealClips, entity, true, "in")
            if concealmentOngoing then
                FreezeEntityPosition(cache.ped, false)
            end
        end
    end, netId, coords)

    searchLocked = false
end

--- Shared body for the companion-assisted search option.
local function RunCompanionSearch(lootCallback, entity)
    companionBusy = true

    local netId = EnsureNetworked(entity)
    local coords = GetEntityCoords(entity)
    local companionSucceeded = DispatchCompanion(entity)

    if companionSucceeded and BanditCompanion and DoesEntityExist(BanditCompanion) and not IsEntityDead(BanditCompanion) then
        while searchLocked do
            Wait(500)
        end

        if BanditCompanion and DoesEntityExist(BanditCompanion) and not IsEntityDead(BanditCompanion) then
            TaskTurnPedToFaceEntity(BanditCompanion, cache.ped, 1000)
            Wait(500)
            TaskTurnPedToFaceEntity(cache.ped, BanditCompanion, 1000)
            Wait(1000)
            TaskStartScenarioInPlace(cache.ped, "CODE_HUMAN_MEDIC_KNEEL", 0, true)
            Wait(5000)

            Framework.TriggerCallback(lootCallback, function() end, netId, coords, districtIndex)

            Wait(1000)
            ClearPedTasks(cache.ped)
        end
    end

    if BanditCompanion and DoesEntityExist(BanditCompanion) and not IsEntityDead(BanditCompanion) then
        TaskFollowToOffsetOfEntity(BanditCompanion, cache.ped, 1.0, 1.0, 0.0, 5.0, -1, 1.0, true)
    end

    companionBusy = false
end

--- Whether the standard container options should be offered right now.
local function ContainerOptionAvailable(entity)
    if entity and IsEntityAMissionEntity(entity) then
        return false
    end
    return not (ScavengerImpaired or searchLocked or Framework.IsPlayerDead())
end

--- Whether the companion-assisted option should be offered right now.
local function CompanionOptionAvailable()
    if not BanditCompanion then
        return false
    end
    if companionBusy or ScavengerImpaired then
        return false
    end
    if not DoesEntityExist(BanditCompanion) or IsEntityDead(BanditCompanion) then
        return false
    end
    return true
end

--- Registers every interaction for a family of container models.
local function RegisterContainerFamily(models, searchLabel, lootCallback, clips, openLabel, stashCallback, stashPrefix, concealLabel, vacancyCallback, concealClips)
    if Settings.UseTargetSystem then
        Target.AddModel(models, {
            {
                label = searchLabel,
                icon = "fa-solid fa-trash",
                distance = 3.0,
                job = Settings.RestrictToJobs,
                onSelect = function(data)
                    RunContainerSearch(models, clips, lootCallback, data.entity)
                end,
                canInteract = ContainerOptionAvailable,
            },
            {
                label = Settings.Text.companion_search,
                icon = "fas fa-paw",
                distance = 30.0,
                job = Settings.VagrantJobName,
                onSelect = function(data)
                    RunCompanionSearch(lootCallback, data.entity)
                end,
                canInteract = CompanionOptionAvailable,
            },
        })

        if Settings.ContainerStorageEnabled then
            Target.AddModel(models, {
                {
                    label = openLabel,
                    icon = "fa-solid fa-trash",
                    distance = 3.0,
                    job = Settings.RestrictToJobs,
                    onSelect = function(data)
                        RunContainerStash(models, clips, stashCallback, stashPrefix, data.entity)
                    end,
                    canInteract = ContainerOptionAvailable,
                },
            })
        end

        if concealLabel and vacancyCallback and Settings.ConcealmentEnabled then
            Target.AddModel(models, {
                {
                    label = concealLabel,
                    icon = "fa-solid fa-trash",
                    distance = 3.0,
                    job = Settings.RestrictToJobs,
                    onSelect = function(data)
                        RunConcealment(models, clips, vacancyCallback, concealClips, data.entity)
                    end,
                    canInteract = function()
                        return ContainerOptionAvailable(nil)
                    end,
                },
            })
        end

        return
    end

    -- "Press E" interaction path (blacklight-interact)
    local options = {}

    insert(options, {
        label = "[E] - " .. searchLabel,
        canSee = function()
            return not searchLocked
        end,
        selected = function(data)
            if searchLocked then
                return
            end
            RunContainerSearch(models, clips, lootCallback, data.entity)
        end,
    })

    insert(options, {
        label = "[E] - " .. Settings.Text.companion_search,
        canSee = function()
            if not BanditCompanion or companionBusy then
                return false
            end
            return Framework.Player.Job.Name == Settings.VagrantJobName
        end,
        selected = function(data)
            if companionBusy then
                return
            end
            RunCompanionSearch(lootCallback, data.entity)
        end,
    })

    if Settings.ContainerStorageEnabled then
        insert(options, {
            label = "[E] - " .. openLabel,
            canSee = function()
                return not searchLocked
            end,
            selected = function(data)
                if searchLocked then
                    return
                end
                RunContainerStash(models, clips, stashCallback, stashPrefix, data.entity)
            end,
        })
    end

    if concealLabel and vacancyCallback and Settings.ConcealmentEnabled then
        insert(options, {
            label = "[E] - " .. concealLabel,
            canSee = function()
                return not searchLocked
            end,
            selected = function(data)
                if searchLocked then
                    return
                end
                RunConcealment(models, clips, vacancyCallback, concealClips, data.entity)
            end,
        })
    end

    exports["blacklight-interact"]:InteractionModel(models, {
        {
            name = "bl_container_interaction",
            distance = 1.8,
            radius = 15.0,
            options = options,
        },
    })
end

-- --------------------------------------------------------------------------
--  BESPOKE SEARCHABLES
-- --------------------------------------------------------------------------

--- Shared body for a bespoke searchable prop.
local function RunBespokeSearch(bespoke, bespokeIndex, entity)
    searchLocked = true

    local netId = EnsureNetworked(entity)
    local coords = GetEntityCoords(entity)
    local success = PerformRummage(bespoke.anims, entity)

    if Settings.HostileVagrantsEnabled then
        ProvokeLocalVagrants(bespoke.models)
    end

    if bespoke.illicit then
        RelayTheftReport(coords)
    end

    MaybeTipOffAuthorities(coords)

    if success then
        Framework.TriggerCallback("bl_dumpsters:server:LootBespoke", function() end, netId, coords, districtIndex, bespokeIndex)

        if bespoke.consumeProp then
            Wait(500)
            SetEntityAsMissionEntity(entity, true, true)
            local doomedNetId = EnsureNetworked(entity)
            DeleteEntity(entity)
            if not DoesEntityExist(entity) then
                TriggerServerEvent("bl_dumpsters:server:PurgeEntity", doomedNetId)
            end
        end
    end

    searchLocked = false
end

local function RegisterBespokeSearchables()
    for bespokeIndex, bespoke in pairs(Settings.BespokeSearchables) do
        if Settings.UseTargetSystem then
            Target.AddModel(bespoke.models, {
                {
                    label = bespoke.label,
                    icon = "fa-solid fa-search",
                    distance = 3.0,
                    job = Settings.RestrictToJobs,
                    onSelect = function(data)
                        RunBespokeSearch(bespoke, bespokeIndex, data.entity)
                    end,
                    canInteract = ContainerOptionAvailable,
                },
            })
        else
            exports["blacklight-interact"]:InteractionModel(bespoke.models, {
                {
                    name = "bl_bespoke_interaction_" .. bespokeIndex,
                    distance = 1.8,
                    radius = 5.0,
                    options = {
                        {
                            label = "[E] - " .. bespoke.label,
                            canSee = function()
                                return not searchLocked
                            end,
                            selected = function(data)
                                if searchLocked then
                                    return
                                end
                                RunBespokeSearch(bespoke, bespokeIndex, data.entity)
                            end,
                        },
                    },
                },
            })
        end
    end
end

-- --------------------------------------------------------------------------
--  REFUSE SACKS (smashable)
-- --------------------------------------------------------------------------

local trackedSack = nil
local trackedSackRange = 0.0

--- Watches a punctured refuse sack; loot drops once it bursts nearby.
function WatchRefuseSack(sackEntity)
    if trackedSack then
        LogDiagnostic("Already tracking a sack — ignoring")
        return
    end

    trackedSack = sackEntity

    CreateThread(function()
        while trackedSack do
            Wait(1000)

            local distance = #(GetEntityCoords(trackedSack) - GetEntityCoords(cache.ped))
            if distance < 100 then
                trackedSackRange = distance
            end

            local health = GetEntityHealth(trackedSack)
            LogDiagnostic(("Sack range: %s | HP: %s"):format(distance, health))

            if health <= 0 then
                LogDiagnostic("Sack burst")

                if trackedSackRange <= 5.0 then
                    LogDiagnostic("Player within reach — requesting loot")
                    local sackNetId = NetworkGetNetworkIdFromEntity(trackedSack)

                    Framework.TriggerCallback("bl_dumpsters:server:LootRefuseSack", function(success)
                        if success then
                            LogDiagnostic("Sack loot granted")
                            Framework.Notify(Settings.Text.loot_found, "success", 5000)
                        else
                            LogDiagnostic("Sack loot denied")
                        end
                        trackedSack = nil
                    end, sackNetId, distance, districtIndex)
                else
                    trackedSack = nil
                end
                break
            end

            if trackedSackRange > 10.0 then
                LogDiagnostic("Player wandered off — dropping sack tracking")
                trackedSack = nil
                break
            end
        end
    end)
end

local function RunSackInspection(entity)
    searchLocked = true

    local netId = EnsureNetworked(entity)
    local success = PerformRummage(Settings.RefuseSackClips, entity)

    if Settings.HostileVagrantsEnabled then
        ProvokeLocalVagrants()
    end

    if success and netId then
        Framework.Notify(Settings.Text.sack_prompt, "success")
        SetEntityCanBeTargetedWithoutLos(entity, true)
        WatchRefuseSack(entity)
    end

    searchLocked = false
end

-- --------------------------------------------------------------------------
--  BOOTSTRAP
-- --------------------------------------------------------------------------

CreateThread(function()
    while not Framework.Player.Identifier do
        Wait(1000)
    end

    RegisterContainerFamily(
        Settings.SeasideBinModels, Settings.Text.wastebin_search, "bl_dumpsters:server:LootSeasideBin",
        Settings.SeasideBinClips, Settings.Text.wastebin_open, "bl_dumpsters:server:OpenSeasideBin", "Beach"
    )

    RegisterContainerFamily(
        Settings.SkipModels, Settings.Text.skip_search, "bl_dumpsters:server:LootSkip",
        Settings.SkipClips, Settings.Text.skip_open, "bl_dumpsters:server:OpenSkip", "Dumpster",
        Settings.Text.skip_conceal, "bl_dumpsters:server:IsSkipVacant", Settings.ClimbInClips
    )

    RegisterContainerFamily(
        Settings.WasteBinModels, Settings.Text.wastebin_search, "bl_dumpsters:server:LootWasteBin",
        Settings.WasteBinClips, Settings.Text.wastebin_open, "bl_dumpsters:server:OpenWasteBin", "Garbage"
    )

    RegisterContainerFamily(
        Settings.EncampmentModels, Settings.Text.generic_search, "bl_dumpsters:server:LootEncampment",
        Settings.WasteBinClips, Settings.Text.generic_open, "bl_dumpsters:server:OpenEncampment", "Hobo"
    )

    if Settings.BespokeSearchables and Settings.BespokeSearchables[1] then
        RegisterBespokeSearchables()
    end

    if Settings.UseTargetSystem then
        Target.AddModel(Settings.RefuseSackModels, {
            {
                label = Settings.Text.sack_option,
                icon = "fa-solid fa-trash",
                distance = 3.0,
                job = Settings.RestrictToJobs,
                onSelect = function(data)
                    RunSackInspection(data.entity)
                end,
                canInteract = function()
                    return not (ScavengerImpaired or searchLocked or trackedSack)
                end,
            },
        })
    else
        exports["blacklight-interact"]:InteractionModel(Settings.RefuseSackModels, {
            {
                name = "bl_sack_interaction",
                distance = 1.5,
                radius = 5.0,
                options = {
                    {
                        label = Settings.Text.sack_option,
                        canSee = function()
                            return not (trackedSack or ScavengerImpaired)
                        end,
                        selected = function(data)
                            RunSackInspection(data.entity)
                        end,
                    },
                },
            },
        })
    end
end)

-- --------------------------------------------------------------------------
--  FLASK AUTO-REFILL
-- --------------------------------------------------------------------------

CreateThread(function()
    while not Framework.Player.Identifier do
        LogDiagnostic("Awaiting player load")
        Wait(1000)
    end

    while Framework.Player.Identifier do
        local flasks = Framework.GetItem("hobo_bottle", { uses = 0 })
        local flask = flasks and flasks[1]

        if flask and flask.count and flask.count > 0 and IsEntityInWater(cache.ped) then
            TriggerServerEvent("bl_dumpsters:server:TopUpFlask", flask.slot)
        end

        Wait(5000)
    end
end)
