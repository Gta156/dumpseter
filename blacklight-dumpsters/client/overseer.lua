--[[ ==========================================================================
     BlackLight Dumpsters — The Overseer, Chapters, Escorts (client)
========================================================================== ]]

local random, floor = math.random, math.floor
local insert, remove = table.insert, table.remove

local overseerPed = nil
local chapterMarkers = {}
local infestedZones = {}
local activeInfestedIndex = nil
local rodentTallies = {}
local tamingBusy = false

-- Shared globals consumed by other modules
BanditCompanion = nil
CommittedScavenger = false

local escorts = {}
local ESCORT_CAP = 3
local holdsThrone = false

local escortRelGroup = nil
local vagrantRelGroup = nil
local playerRelGroup = nil

local cachedStanding = nil
local liveRodents = 0

local INTERACT = "blacklight-interact"

-- --------------------------------------------------------------------------
--  HELPERS
-- --------------------------------------------------------------------------

--- Simple ipairs membership test.
function ListContains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

--- Returns the chapter name mapped to a given rank.
function ChapterNameForRank(rank)
    return Settings.Chapters[rank] and Settings.Chapters[rank].name or nil
end

local function RankForChapterName(name)
    for rank, chapter in pairs(Settings.Chapters) do
        if chapter.name == name then
            return rank
        end
    end
end

function ChapterBriefing(name)
    local rank = RankForChapterName(name)
    return (rank and Settings.Chapters[rank].description) or "What brings you here?"
end

function ChapterDebrief(name)
    local rank = RankForChapterName(name)
    return (rank and Settings.Chapters[rank].descriptionCompleted) or "You've done what needed doing. The community respects that."
end

--- Clears every chapter blip currently on the map.
function ClearChapterMarkers()
    for _, marker in ipairs(chapterMarkers) do
        if DoesBlipExist(marker) then
            RemoveBlip(marker)
        end
    end
    chapterMarkers = {}
end

-- --------------------------------------------------------------------------
--  CONTRACT BOARD
-- --------------------------------------------------------------------------

--- Opens the Corner Grinder contract picker.
local function OpenContractBoard()
    Framework.TriggerCallback("bl_dumpsters:server:GetContractLedger", function()
        local contracts = Settings.Chapters[10].Contracts

        for _ in pairs(exports["blacklight-dumpsters"]:GetLiveContracts() or {}) do
            Framework.Notify(Settings.Text.contract_in_progress, "error")
            return
        end

        local options = {}
        local key = "A"

        for _, contract in ipairs(contracts) do
            insert(options, {
                key = key,
                label = contract.name,
                selected = function()
                    exports[INTERACT]:CloseMenu("bl-contract-menu")
                    TriggerServerEvent("bl_dumpsters:server:AcceptContract", contract.type)

                    if contract.type == "trolley_cab" then
                        Framework.Notify(Settings.Text.cab_run_started, "success")
                        BeginTrolleyCabRun()
                    end
                end,
                canSee = function()
                    return cachedStanding and cachedStanding.level >= contract.rank
                end,
            })
            key = string.char(key:byte() + 1)
        end

        insert(options, {
            key = "X",
            label = Settings.Text.go_back,
            selected = function()
                exports[INTERACT]:CloseMenu("bl-contract-menu")
            end,
        })

        exports[INTERACT]:OpenChoiceMenu({
            title = Settings.Text.contract_board,
            speech = Settings.Text.pick_a_contract,
            menuID = "bl-contract-menu",
            position = "right",
            options = options,
        })
    end)
end

-- --------------------------------------------------------------------------
--  ROOT MENU DEFINITION (reused by the NPC and by the "back" navigation)
-- --------------------------------------------------------------------------

--- Builds the Overseer's root option list. Shared to avoid duplicate definitions.
local function BuildOverseerOptions()
    return {
        {
            key = "E",
            label = Settings.Text.view_standing,
            reaction = "Conversation",
            selected = function(data)
                OpenStandingMenu(data)
            end,
        },
        {
            key = "M",
            label = Settings.Text.active_chapter,
            reaction = "Conversation",
            selected = function(data)
                OpenChapterMenu(data)
            end,
        },
        {
            key = "T",
            label = Settings.Text.contract_board,
            reaction = "Conversation",
            canSee = function()
                local standing = Framework.TriggerCallback.Await("bl_dumpsters:server:GetStanding")
                cachedStanding = standing
                return standing and standing.level >= Settings.Chapters[10].unlockRank
            end,
            selected = OpenContractBoard,
        },
        {
            key = "D",
            label = Settings.Text.tithe_contraband,
            reaction = "Thanks",
            selected = function(data)
                OpenContrabandMenu(data)
            end,
        },
        {
            key = "B",
            label = Settings.Text.tithe_currency,
            reaction = "Thanks",
            stayOpen = true,
            selected = function(data)
                OpenCurrencyTitheMenu(data)
            end,
        },
        {
            key = "S",
            label = Settings.Text.street_market,
            reaction = "Conversation",
            selected = function(data)
                exports[INTERACT]:CloseMenu(data.menuID)
                OpenStreetMarket()
            end,
        },
        {
            key = "X",
            label = Settings.Text.never_mind,
            reaction = "Bye",
            selected = function(data)
                exports[INTERACT]:CloseMenu(data.menuID)
            end,
        },
    }
end

-- --------------------------------------------------------------------------
--  OVERSEER NPC
-- --------------------------------------------------------------------------

CreateThread(function()
    Wait(1000)

    if Settings.SimpleModeOnly then
        return
    end

    local anchor = Settings.Overseer.Anchor

    overseerPed = exports[INTERACT]:CreateNPC({
        name = "bl_overseer",
        model = Settings.Overseer.Model,
        coords = vector3(anchor.x, anchor.y, anchor.z - 0.9),
        heading = anchor.w,
        isFrozen = true,
    }, {
        title = Settings.Text.overseer_title,
        speech = Settings.Text.overseer_greeting,
        menuID = "bl-overseer-menu",
        greeting = "Hello",
        position = "right",
        focusCam = true,
        options = BuildOverseerOptions(),
    })
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() and overseerPed then
        DeleteEntity(overseerPed)
    end
end)

-- --------------------------------------------------------------------------
--  STANDING / RANK MENU
-- --------------------------------------------------------------------------

function OpenStandingMenu(data)
    Framework.TriggerCallback("bl_dumpsters:server:GetStanding", function(standing)
        if not standing then
            exports[INTERACT]:UpdateSpeech(data.menuID, Settings.Text.identity_unknown)
            return
        end

        local nextRank = standing.level + 1
        local xpTarget = Settings.Reputation.RankThresholds[nextRank] or "MAX"

        local percent = 100
        if nextRank <= 10 then
            percent = floor((standing.xp / Settings.Reputation.RankThresholds[nextRank]) * 100)
        end

        exports[INTERACT]:PercentageBar(
            "bl-standing-bar", percent,
            ("Rank %s Progress: %s/%s XP"):format(standing.level, standing.xp, xpTarget),
            "top", "always"
        )

        local speech = string.format(Settings.Text.standing_summary, standing.level, standing.xp)
        if standing.is_king == 1 then
            speech = speech .. Settings.Text.you_hold_throne
        elseif standing.level == 10 then
            speech = speech .. Settings.Text.at_top_rank
        else
            speech = speech .. string.format(Settings.Text.next_rank_hint, nextRank)
        end

        exports[INTERACT]:UpdateSpeech(data.menuID, speech)

        local atTopRank = standing.level == 10
        local options = {
            {
                key = "E",
                label = atTopRank and Settings.Text.contest_throne or Settings.Text.advance_rank,
                selected = function(menuData)
                    AttemptRankUp(standing)
                    exports[INTERACT]:CloseMenu(menuData.menuID)
                    exports[INTERACT]:CloseMenu("bl-standing-bar")
                end,
            },
        }

        if atTopRank then
            insert(options, {
                key = "L",
                label = Settings.Text.purchase_exit,
                selected = function(menuData)
                    exports[INTERACT]:UpdateSpeech(menuData.menuID, Settings.Text.exit_price_intro)

                    local answer = lib.alertDialog({
                        header = Settings.Text.exit_dialog_title,
                        content = string.format(Settings.Text.exit_dialog_body, Settings.Overseer.BuyoutPrice),
                        size = "lg",
                        cancel = true,
                        labels = { cancel = Settings.Text.decline, confirm = Settings.Text.affirm_sure },
                    })

                    if answer == "confirm" then
                        TriggerServerEvent("bl_dumpsters:server:PurchaseExit")
                    end
                end,
            })
        end

        insert(options, {
            key = "X",
            label = Settings.Text.never_mind,
            selected = function()
                exports[INTERACT]:CloseMenu("bl-standing-bar")
                exports[INTERACT]:OpenChoiceMenu({
                    title = Settings.Text.contract_board,
                    speech = Settings.Text.pick_a_contract,
                    menuID = "bl-overseer-return",
                    position = "right",
                    options = BuildOverseerOptions(),
                })
            end,
        })

        exports[INTERACT]:OpenChoiceMenu({
            title = Settings.Text.reputation_screen,
            speech = Settings.Text.what_do_you_want,
            menuID = "bl-standing-menu",
            position = "right",
            options = options,
        })
    end, data)
end

--- Validates all rank-up prerequisites, then asks the server to promote.
function AttemptRankUp(standing)
    local nextRank = standing.level + 1

    if standing.level == 10 then
        local answer = lib.alertDialog({
            header = Settings.Text.gauntlet_title,
            content = Settings.Text.gauntlet_start,
            size = "lg",
            cancel = true,
            labels = { cancel = Settings.Text.decline_soft, confirm = Settings.Text.affirm_ready },
        })

        if answer == "confirm" then
            BeginThroneGauntlet()
        end
        return
    end

    if standing.xp < Settings.Reputation.RankThresholds[nextRank] then
        Framework.Notify(Settings.Text.xp_insufficient, "error")
        return
    end

    local chapterName = ChapterNameForRank(standing.level)
    if chapterName then
        local chapterState = standing.mission_data[standing.level]
        if not (chapterState and chapterState.completed) then
            Framework.Notify(string.format(Settings.Text.chapter_pending, chapterName), "error")
            return
        end
    end

    -- Rank 5 is the point of no return: the player becomes a committed street dweller.
    if nextRank == 5 then
        local answer = lib.alertDialog({
            header = Settings.Text.commitment_title,
            content = Settings.Text.commitment_body,
            size = "xl",
            cancel = true,
            labels = { cancel = Settings.Text.decline_hard, confirm = Settings.Text.affirm_ready },
        })

        if answer ~= "confirm" then
            Framework.Notify(Settings.Text.not_committed, "error")
            return
        end
    end

    TriggerServerEvent("bl_dumpsters:server:AdvanceRank")
end

local jobPollGuardMs = 500
local lastJobPoll = 0

Framework.OnJobUpdate = function()
    local now = GetGameTimer()
    if now - lastJobPoll < jobPollGuardMs then
        return
    end
    lastJobPoll = now

    Framework.TriggerCallback("bl_dumpsters:server:IsCommittedScavenger", function(committed)
        if committed then
            CommittedScavenger = true
        end
    end)
end

--- Prints the market stock unlocked at a given rank into the NPC speech box.
function DescribeRankUnlocks(rank, data)
    local stock = Settings.MarketStock[rank] or {}
    local listing = "None"

    if #stock > 0 then
        listing = ""
        for _, entry in ipairs(stock) do
            listing = listing .. "- " .. (entry.label or entry.name) .. "\n"
        end
    end

    exports[INTERACT]:UpdateSpeech(data.menuID, ("At rank %s you can make use of:\n\n%s"):format(rank, listing))
end

-- --------------------------------------------------------------------------
--  CHAPTER MENU
-- --------------------------------------------------------------------------

function OpenChapterMenu(data)
    Framework.TriggerCallback("bl_dumpsters:server:GetStanding", function(standing)
        if not standing then
            return
        end

        local rank = standing.level
        local chapterName = ChapterNameForRank(rank)

        if not chapterName then
            exports[INTERACT]:UpdateSpeech(data.menuID, Settings.Text.no_active_chapter)
        end

        local chapter = Settings.Chapters[rank]
        local chapterState = standing.mission_data[rank] or {}
        local completed = chapterState.completed or false

        local speech = completed and ChapterDebrief(chapterName) or ChapterBriefing(chapterName)

        local options = {
            {
                key = "S",
                label = completed and Settings.Text.done_marker or Settings.Text.begin_chapter,
                selected = function(menuData)
                    if completed then
                        Framework.Notify(Settings.Text.chapter_already_done, "error")
                        return
                    end
                    BeginChapter(chapterName, chapter)
                    exports[INTERACT]:CloseMenu(menuData.menuID)
                end,
            },
        }

        -- Chapter 6 gains a hand-in option once the parcel has been recovered.
        if chapterName == Settings.Chapters[6].name and chapterState.package_found and not chapterState.package_delivered then
            insert(options, {
                key = "D",
                label = Settings.Text.hand_over_parcel,
                selected = function(menuData)
                    Framework.TriggerCallback("bl_dumpsters:server:HandOverParcel", function(success, message)
                        Framework.Notify(message, success and "success" or "error")
                        exports[INTERACT]:CloseMenu(menuData.menuID)
                    end)
                end,
            })
        end

        insert(options, {
            key = "X",
            label = Settings.Text.go_back,
            selected = function(menuData)
                exports[INTERACT]:CloseMenu(menuData.menuID)
            end,
        })

        exports[INTERACT]:OpenChoiceMenu({
            title = chapterName,
            speech = speech,
            menuID = "bl-chapter-menu",
            position = "right",
            options = options,
        })
    end)
end

--- Kicks off the client-side portion of a chapter.
function BeginChapter(name, chapter)
    ClearChapterMarkers()

    if name == Settings.Chapters[1].name then
        BeginBreakingGround(chapter)
    elseif name == Settings.Chapters[2].name then
        BeginVerminPurge(chapter)
    elseif name == Settings.Chapters[3].name then
        BeginSilverTongue()
    elseif name == Settings.Chapters[4].name then
        BeginDownhillRush()
    elseif name == Settings.Chapters[5].name then
        BeginSalvageRun()
    elseif name == Settings.Chapters[6].name then
        Framework.Notify("Keep rifling skips until a Medical Care Package turns up", "info")
    elseif name == Settings.Chapters[7].name then
        BeginSettlingScores(chapter)
    elseif name == Settings.Chapters[8].name then
        BeginBanditBond()
    elseif name == Settings.Chapters[9].name then
        BeginTrolleyCabRun()
    end

    Framework.Notify(string.format(Settings.Text.chapter_begun, name), "success")
end

-- --------------------------------------------------------------------------
--  CHAPTER 1 — BREAKING GROUND
-- --------------------------------------------------------------------------

function BeginBreakingGround(chapter)
    for index, districtCoords in ipairs(chapter.Districts) do
        local ring = AddBlipForRadius(districtCoords.x, districtCoords.y, districtCoords.z, chapter.DistrictRadius)
        SetBlipColour(ring, 1)
        SetBlipAlpha(ring, 128)

        local pin = AddBlipForCoord(districtCoords.x, districtCoords.y, districtCoords.z)
        SetBlipSprite(pin, 587)
        SetBlipColour(pin, 2)
        SetBlipAsShortRange(pin, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Settings.Text.district_label .. index)
        EndTextCommandSetBlipName(pin)

        insert(chapterMarkers, ring)
        insert(chapterMarkers, pin)

        Zone.SphereZone({
            debug = false,
            coords = districtCoords,
            radius = chapter.DistrictRadius,
            onEnter = function()
                TriggerServerEvent("bl_dumpsters:server:PushChapterProgress", 1, { ["zone_" .. index .. "_visited"] = true })
                RemoveBlip(ring)
                RemoveBlip(pin)
            end,
        })
    end

    Framework.Notify(Settings.Text.visit_the_districts, "info")
end

-- --------------------------------------------------------------------------
--  CHAPTER 2 — VERMIN PURGE
-- --------------------------------------------------------------------------

local function NearestObjectTo(coords, maxDistance)
    local objects = GetGamePool("CObject")
    local nearest, nearestDistance = nil, maxDistance

    for _, object in ipairs(objects) do
        local distance = #(coords - GetEntityCoords(object))
        if distance < nearestDistance then
            nearestDistance = distance
            nearest = object
        end
    end

    return nearest
end

--- Spawns a single rodent near a piece of scenery.
local function SpawnRodentNear(anchorCoords, chaseChance)
    if liveRodents >= 10 then
        return
    end

    if not HasModelLoaded("a_c_rat") then
        Framework.LoadModel("a_c_rat")
    end

    local nearest = NearestObjectTo(anchorCoords, 20.0)
    local spawnCoords = nearest and GetEntityCoords(nearest) or anchorCoords

    local rodent = CreatePed(4, "a_c_rat", spawnCoords.x + random(-5, 5), spawnCoords.y + random(-5, 5), spawnCoords.z, 0.0, true, true)
    liveRodents = liveRodents + 1
    SetEntityAsMissionEntity(rodent, true, true)

    if random(1, 10) <= chaseChance then
        TaskGoToEntity(rodent, cache.ped, 60000, 1.0, 1.0, 0, 0)
    else
        TaskWanderStandard(rodent, 60000, 10)
    end

    SetTimeout(60000, function()
        SetEntityAsNoLongerNeeded(rodent)
        liveRodents = liveRodents - 1
    end)
end

function BeginVerminPurge(chapter)
    local pool = table.clone(chapter.InfestedSites)
    local chosen = {}

    for _ = 1, 3 do
        local index = random(1, #pool)
        insert(chosen, pool[index])
        remove(pool, index)
    end

    for siteIndex, siteCoords in ipairs(chosen) do
        local ring = AddBlipForRadius(siteCoords.x, siteCoords.y, siteCoords.z, chapter.SiteRadius)
        SetBlipColour(ring, 1)
        SetBlipAlpha(ring, 128)

        local pin = AddBlipForCoord(siteCoords.x, siteCoords.y, siteCoords.z)
        SetBlipSprite(pin, 442)
        SetBlipColour(pin, 1)
        SetBlipAsShortRange(pin, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(string.format(Settings.Text.nest_cleared, siteIndex))
        EndTextCommandSetBlipName(pin)

        insert(chapterMarkers, ring)
        insert(chapterMarkers, pin)

        infestedZones[siteIndex] = Zone.SphereZone({
            debug = false,
            coords = siteCoords,
            radius = chapter.SiteRadius,
            onEnter = function()
                activeInfestedIndex = siteIndex
            end,
            onExit = function()
                activeInfestedIndex = nil
            end,
            inside = function()
                Wait(random(2500, 10000))
                SpawnRodentNear(GetEntityCoords(cache.ped), 3)
            end,
        })
    end
end

RegisterNetEvent("bl_dumpsters:client:DeployRodentBait", function()
    local coords = GetEntityCoords(cache.ped)
    local clipDict = "anim@mp_fireworks"
    local clipName = "place_firework_4_cone"

    lib.requestAnimDict(clipDict)
    TaskPlayAnim(cache.ped, clipDict, clipName, 8.0, 8.0, -1, 0, 0, false, false, false)
    Wait(5000)
    RemoveAnimDict(clipDict)

    local baitZone = Zone.SphereZone({
        debug = Settings.DiagnosticMode,
        coords = coords,
        radius = 20.0,
        inside = function()
            Wait(random(2500, 10000))

            if liveRodents >= 10 then
                return
            end

            if not HasModelLoaded("a_c_rat") then
                Framework.LoadModel("a_c_rat")
            end

            local nearest = NearestObjectTo(coords, 20.0)
            local spawnCoords = nearest and GetEntityCoords(nearest) or GetEntityCoords(cache.ped)

            local rodent = CreatePed(4, "a_c_rat", spawnCoords.x + random(-5, 5), spawnCoords.y + random(-5, 5), spawnCoords.z, 0.0, true, true)
            liveRodents = liveRodents + 1
            SetEntityAsMissionEntity(rodent, true, true)

            local roll = random(1, 10)
            if roll <= 2 or roll > 8 then
                TaskGoToEntity(rodent, cache.ped, 60000, 1.0, 1.0, 0, 0)
            else
                TaskGoToCoordAnyMeans(rodent, coords.x + random(-1, 1), coords.y + random(-1, 1), coords.z, 60000, 1.0, 1.0, 0, 0)
            end

            SetTimeout(60000, function()
                SetEntityAsNoLongerNeeded(rodent)
                liveRodents = liveRodents - 1
            end)
        end,
    })

    -- Bait expires and the attraction zone is torn down.
    SetTimeout(Settings.BaitLifetimeSeconds * 1000, function()
        if baitZone and baitZone.remove then
            baitZone.remove()
        end
    end)
end)

local RODENT_MODEL = -1011537562
local RAT_STICK_HASH = -1638292314
local HOBO_STICK_HASH = -1901127961

AddEventHandler("gameEventTriggered", function(eventName, data)
    if eventName ~= "CEventNetworkEntityDamage" then
        return
    end

    local victim, attacker = data[1], data[2]
    local fatal = data[6] == 1
    local weaponHash = tonumber(data[7])

    if not (DoesEntityExist(victim) and IsEntityAPed(victim) and GetEntityModel(victim) == RODENT_MODEL and fatal) then
        return
    end

    -- Rodent culling counts towards the Vermin Purge chapter.
    if activeInfestedIndex and attacker == cache.ped then
        rodentTallies[activeInfestedIndex] = (rodentTallies[activeInfestedIndex] or 0) + 1

        if rodentTallies[activeInfestedIndex] >= 5 then
            local clearedIndex = activeInfestedIndex

            Framework.TriggerCallback("bl_dumpsters:server:GetChapterProgress", function(chapterState)
                local clearedCount = chapterState.cleared_areas or 0
                local clearedList = chapterState.cleared_list or {}
                clearedList[clearedIndex] = true

                TriggerServerEvent("bl_dumpsters:server:PushChapterProgress", 2, {
                    cleared_areas = clearedCount + 1,
                    cleared_list = clearedList,
                })

                Framework.Notify(string.format(Settings.Text.nest_cleared, clearedIndex), "success")

                if infestedZones[clearedIndex] then
                    infestedZones[clearedIndex].remove()
                end
            end, 2)
        end
    end

    -- Culling a rodent with the plain stick upgrades it into the rat stick.
    if attacker == Store.Ped and weaponHash == HOBO_STICK_HASH then
        TriggerServerEvent("bl_dumpsters:server:UpgradeStickToRatStick")
        Framework.Notify("You've culled a rodent with your street stick!", "success")
        Wait(500)
        GiveWeaponToPed(Store.Ped, RAT_STICK_HASH, 0, false, true)
        SetPedCanSwitchWeapon(Store.Ped, true)
        SetCurrentPedWeapon(Store.Ped, RAT_STICK_HASH, true)
    end
end)

-- --------------------------------------------------------------------------
--  CHAPTERS 3 & 5 — HINT ONLY
-- --------------------------------------------------------------------------

function BeginSilverTongue()
    Framework.Notify(Settings.Text.panhandle_hint, "info")
end

function BeginSalvageRun()
    Framework.Notify(Settings.Text.salvage_hint, "info")
end

-- --------------------------------------------------------------------------
--  CHAPTER 7 — SETTLING SCORES
-- --------------------------------------------------------------------------

local rivalPed = nil
local rivalBolting = false

function BeginSettlingScores(chapter)
    local anchor = chapter.RivalAnchor

    local ring = AddBlipForRadius(anchor.x, anchor.y, anchor.z, 70.0)
    SetBlipColour(ring, 1)
    SetBlipAlpha(ring, 128)
    insert(chapterMarkers, ring)

    local pin = AddBlipForCoord(anchor.x, anchor.y, anchor.z)
    SetBlipSprite(pin, 280)
    SetBlipColour(pin, 5)
    SetBlipAsShortRange(pin, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Settings.Text.rival_name)
    EndTextCommandSetBlipName(pin)
    SetBlipRoute(pin, true)

    Zone.SphereZone({
        coords = vec3(anchor.x, anchor.y, anchor.z),
        radius = 70.0,
        debug = Settings.DiagnosticMode,
        onEnter = function()
            RemoveBlip(pin)

            if rivalPed then
                return
            end

            local modelHash = GetHashKey("a_m_m_trampbeac_01")
            Framework.LoadModel(modelHash)

            rivalPed = CreatePed(4, modelHash, anchor.x, anchor.y, anchor.z, 0.0, true, true)
            SetEntityAsMissionEntity(rivalPed, true, true)
            SetEntityHeading(rivalPed, anchor.w)
            TaskUseNearestScenarioChainToCoordWarp(rivalPed, anchor.x, anchor.y, anchor.z, 30.0)
            SetPedCombatAttributes(rivalPed, 46, true)
            SetPedCombatAttributes(rivalPed, 2, true)
            SetPedCombatAttributes(rivalPed, 5, true)
            SetPedCombatAttributes(rivalPed, 0, true)
            SetPedFleeAttributes(rivalPed, 0, false)
            SetPedCombatRange(rivalPed, 2)
            SetPedCombatMovement(rivalPed, 3)
            SetPedAccuracy(rivalPed, 80)
            SetPedArmour(rivalPed, 100)

            local rivalBlip = AddBlipForEntity(rivalPed)
            SetBlipSprite(rivalBlip, 303)
            SetBlipColour(rivalBlip, 1)
            SetBlipScale(rivalBlip, 0.8)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Settings.Text.rival_name)
            EndTextCommandSetBlipName(rivalBlip)
            insert(chapterMarkers, rivalBlip)

            CreateThread(function()
                while not IsEntityDead(rivalPed) do
                    Wait(1500)
                end

                TriggerServerEvent("bl_dumpsters:server:PushChapterProgress", 7, { rival_defeated = true })
                Framework.Notify(Settings.Text.rival_beaten, "success")
                ClearChapterMarkers()
                Wait(60000)
                SetPedAsNoLongerNeeded(rivalPed)
            end)

            Zone.SphereZone({
                coords = vec3(anchor.x, anchor.y, anchor.z),
                radius = 20.0,
                debug = Settings.DiagnosticMode,
                onEnter = function()
                    if DoesEntityExist(rivalPed) and not rivalBolting then
                        Framework.Notify(Settings.Text.rival_bolting, "warning")
                        PlayPain(rivalPed, 7, 100)
                        TaskSmartFleePed(rivalPed, cache.ped, 100.0, -1, false, false)
                        rivalBolting = true
                    end
                end,
            })
        end,
    })
end

-- --------------------------------------------------------------------------
--  CHAPTER 8 — BANDIT BOND
-- --------------------------------------------------------------------------

function BeginBanditBond()
    Framework.TriggerCallback("bl_dumpsters:server:IssueBanditTreats", function(success, message)
        Framework.Notify(message, success and "success" or "error")
        tamingBusy = false
    end)
end

--- Runs the kneel-and-coax sequence to win a bandit over.
local function CoaxBandit(entity)
    tamingBusy = true

    TaskTurnPedToFaceEntity(cache.ped, entity, -1)
    Wait(500)
    TaskTurnPedToFaceEntity(entity, cache.ped, -1)
    Wait(500)
    TaskStartScenarioInPlace(cache.ped, "CODE_HUMAN_MEDIC_KNEEL", 0, true)
    Framework.Notify(Settings.Text.taming_attempt, "info")

    SetTimeout(4000, function()
        ClearPedTasks(cache.ped)

        if IsEntityDead(entity) or not DoesEntityExist(entity) then
            return
        end

        Framework.TriggerCallback("bl_dumpsters:server:CoaxBandit", function(success, message)
            if not success then
                Framework.Notify(message, "error")
                TaskSmartFleePed(entity, cache.ped, 100.0, -1, false, false)
                SetTimeout(30000, function()
                    TaskWanderStandard(entity, 10.0, 10)
                end)
                return
            end

            Framework.Notify(message, "success")
            BanditCompanion = entity
            Entity(entity).state:set("IsTamed", true, true)
            Wait(2500)

            local clipDict = "creatures@cat@player_action@"
            local clipName = "action_a"
            Framework.LoadAnimDict(clipDict)
            TaskPlayAnim(entity, clipDict, clipName, 8.0, 8.0, -1, 0, 0, false, false, false)
            Wait(2500)
            TaskFollowToOffsetOfEntity(entity, cache.ped, 1.0, 1.0, 0.0, 5.0, -1, 1.0, true)

            SetTimeout(Settings.GearBehaviour.racoon_treats.minutes * 60000, function()
                if not DoesEntityExist(entity) then
                    return
                end

                ClearPedTasks(entity)
                Framework.Notify(Settings.Text.companion_departed, "error")
                TaskSmartFleePed(entity, cache.ped, 100.0, -1, false, false)

                SetTimeout(30000, function()
                    ClearPedTasks(entity)
                    TaskWanderStandard(entity, 10.0, 10)
                    if BanditCompanion == entity then
                        BanditCompanion = nil
                    end
                end)
            end)

            ClearChapterMarkers()
        end)
    end)

    tamingBusy = false
end

local BANDIT_MODEL_HASH = -333702667

local function CanCoaxBandit()
    if tamingBusy then
        return false
    end
    if Framework.Player.Job.Name ~= Settings.VagrantJobName then
        return false
    end
    return Framework.HasItem("racoon_treats", 1)
end

if Settings.UseTargetSystem then
    Target.AddModel(BANDIT_MODEL_HASH, {
        {
            label = Settings.Text.tame_bandit,
            icon = "fas fa-paw",
            distance = 2.0,
            canInteract = CanCoaxBandit,
            onSelect = function(data)
                CoaxBandit(data.entity)
            end,
        },
    })
else
    exports[INTERACT]:InteractionModel(BANDIT_MODEL_HASH, {
        {
            name = "bl_bandit_interaction",
            distance = 2.0,
            radius = 5.0,
            options = {
                {
                    label = Settings.Text.tame_bandit,
                    canSee = CanCoaxBandit,
                    selected = function(data)
                        CoaxBandit(data.entity)
                    end,
                },
            },
        },
    })
end

-- --------------------------------------------------------------------------
--  CHAPTER 11 — FINAL GAUNTLET ENTRY
-- --------------------------------------------------------------------------

function BeginFinalGauntlet(chapter)
    Framework.TriggerCallback("bl_dumpsters:server:GetStanding", function(standing)
        if standing.level < 10 then
            Framework.Notify(Settings.Text.rank_ten_required, "error")
            return
        end

        Framework.TriggerCallback("bl_dumpsters:server:ContestThrone", function(success, message, gauntletRequired)
            if not success then
                Framework.Notify(message, "error")
                return
            end

            Framework.Notify(message, "success")

            -- The server tells us explicitly whether the seat was taken outright
            -- or whether the sitting holder has to be fought for it.
            if gauntletRequired then
                BeginThroneGauntlet()
            else
                TriggerServerEvent("bl_dumpsters:server:ClaimThrone")
            end
        end)
    end)
end

-- --------------------------------------------------------------------------
--  TITHING MENUS
-- --------------------------------------------------------------------------

function OpenContrabandMenu(data)
    local options = {}
    local key = "A"

    for contrabandType, contrabandConfig in pairs(Settings.Reputation.ContrabandXP) do
        insert(options, {
            key = key,
            label = Settings.Text.tithe_action .. " " .. contrabandConfig.label,
            reaction = "Conversation",
            selected = function(menuData)
                OpenContrabandQuantity(menuData, contrabandType)
            end,
        })
        key = string.char(key:byte() + 1)
    end

    insert(options, {
        key = "X",
        label = Settings.Text.abort,
        reaction = "Bye",
        selected = function(menuData)
            exports[INTERACT]:CloseMenu(menuData.menuID)
        end,
    })

    exports[INTERACT]:OpenChoiceMenu({
        title = Settings.Text.tithe_contraband,
        speech = Settings.Text.contraband_pitch,
        menuID = "bl-contraband-menu",
        position = "right",
        options = options,
    })
end

function OpenContrabandQuantity(data, contrabandType)
    exports[INTERACT]:UseSlider(data.menuID, {
        title = Settings.Text.choose_quantity,
        min = 1,
        max = 10,
        sliderState = "unlocked",
        sliderValue = 1,
        nextState = "disabled",
        confirm = function(quantity)
            Framework.TriggerCallback("bl_dumpsters:server:TitheContraband", function(success, message)
                Framework.Notify(message, success and "success" or "error")
                exports[INTERACT]:CloseMenu(data.menuID)
            end, contrabandType, quantity)
        end,
    })
end

function OpenCurrencyTitheMenu(data)
    exports[INTERACT]:UseSlider(data.menuID, {
        title = Settings.Text.tithe_for_xp,
        min = 1,
        max = 100,
        sliderState = "unlocked",
        sliderValue = 10,
        nextState = "disabled",
        confirm = function(quantity)
            Framework.TriggerCallback("bl_dumpsters:server:TitheCurrency", function(success, message)
                Framework.Notify(message, success and "success" or "error")
                exports[INTERACT]:CloseMenu(data.menuID)
            end, quantity)
        end,
    })
end

-- --------------------------------------------------------------------------
--  STREET MARKET
-- --------------------------------------------------------------------------

function OpenStreetMarket()
    Framework.TriggerCallback("bl_dumpsters:server:GetStanding", function(standing)
        if not standing then
            return
        end

        local options = {}

        for rank = 1, standing.level do
            for _, entry in ipairs(Settings.MarketStock[rank] or {}) do
                insert(options, {
                    title = entry.label,
                    description = ("%s\n%s: %s %s\n%s %s"):format(
                        entry.description,
                        Settings.Text.price_label, entry.price, Settings.Text.currency_plural_word,
                        Settings.Text.unlock_rank_label, rank
                    ),
                    icon = "shopping-cart",
                    onSelect = function()
                        local input = lib.inputDialog(string.format(Settings.Text.buy_quantity_of, entry.label), {
                            { type = "number", label = "Quantity", default = 1, min = 1, max = 10 },
                        })

                        if input and input[1] and input[1] > 0 then
                            PurchaseMarketStock(entry.name, entry.price, input[1])
                        end
                    end,
                })
            end
        end

        lib.registerContext({ id = "bl_street_market", title = Settings.Text.market_title, options = options })
        lib.showContext("bl_street_market")
    end)
end

function PurchaseMarketStock(itemName, unitPrice, quantity)
    Framework.TriggerCallback("bl_dumpsters:server:PurchaseStock", function(success, message)
        Framework.Notify(message, success and "success" or "error")
    end, itemName, quantity, unitPrice * quantity)
end

-- --------------------------------------------------------------------------
--  RANK-UP NOTIFICATION
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:client:RankGained", function(rank)
    Framework.Notify(string.format(Settings.Text.rank_gained, rank), "success")

    local stock = Settings.MarketStock[rank]
    if stock and #stock > 0 then
        local labels = {}
        for _, entry in ipairs(stock) do
            labels[#labels + 1] = entry.label
        end
        Framework.Notify(string.format(Settings.Text.stock_unlocked, table.concat(labels, ", ")), "info")
    end

    if rank == 10 then
        Framework.Notify(Settings.Text.throne_now_open, "info")
    end
end)

-- --------------------------------------------------------------------------
--  RELATIONSHIP GROUPS & ESCORTS
-- --------------------------------------------------------------------------

function ConfigureRelationshipGroups()
    if not escortRelGroup then
        escortRelGroup = AddRelationshipGroup("BL_STREET_ESCORTS")
    end
    if not vagrantRelGroup then
        vagrantRelGroup = AddRelationshipGroup("BL_STREET_GENERAL")
    end

    playerRelGroup = GetPedRelationshipGroupHash(PlayerPedId())

    SetRelationshipBetweenGroups(0, escortRelGroup, playerRelGroup)
    SetRelationshipBetweenGroups(0, playerRelGroup, escortRelGroup)
    SetRelationshipBetweenGroups(5, escortRelGroup, GetHashKey("HATES_PLAYER"))

    SetRelationshipBetweenGroups(holdsThrone and 0 or 3, vagrantRelGroup, playerRelGroup)

    SetRelationshipBetweenGroups(0, escortRelGroup, vagrantRelGroup)
    SetRelationshipBetweenGroups(0, vagrantRelGroup, escortRelGroup)
end

--- Reassigns ambient street dwellers into the shared relationship group.
local function ReassignAmbientVagrants()
    local peds = GetGamePool("CPed")
    local playerPed = PlayerPedId()

    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) and not IsPedDeadOrDying(ped, true) and ped ~= playerPed then
            local model = GetEntityModel(ped)

            for _, modelName in ipairs(Settings.VagrantModels) do
                if model == GetHashKey(modelName) then
                    if not ListContains(escorts, ped) and GetPedRelationshipGroupHash(ped) ~= escortRelGroup then
                        SetPedRelationshipGroupHash(ped, vagrantRelGroup)
                    end
                    break
                end
            end
        end
    end
end

CreateThread(function()
    Wait(1000)
    while true do
        Wait(10000)
        ReassignAmbientVagrants()
    end
end)

local ESCORT_ARMS = {
    "WEAPON_BAT", "WEAPON_BOTTLE", "WEAPON_CROWBAR", "WEAPON_GOLFCLUB", "WEAPON_HAMMER",
    "WEAPON_KNIFE", "WEAPON_KNUCKLE", "WEAPON_MACHETE", "WEAPON_SWITCHBLADE", "WEAPON_WRENCH",
    "WEAPON_HOBO_REBAR", "WEAPON_HOBO_DUSTER", "WEAPON_HOBO_OLDMACHETE", "WEAPON_HOBO_TOILET",
    "WEAPON_HOBO_PLANK", "WEAPON_HOBO_PIPE",
}

--- Recruits a street dweller into the player's personal guard.
function HireEscort(entity)
    if not DoesEntityExist(entity) or #escorts >= ESCORT_CAP then
        return
    end

    ClearPedTasksImmediately(entity)
    SetEntityAsMissionEntity(entity, true, true)
    SetPedRelationshipGroupHash(entity, escortRelGroup)
    insert(escorts, entity)

    GiveWeaponToPed(entity, GetHashKey(ESCORT_ARMS[random(1, #ESCORT_ARMS)]), 1, false, true)
    SetPedArmour(entity, 50)
    SetPedCombatAbility(entity, 100)
    SetPedCombatAttributes(entity, 46, true)
    SetPedCombatAttributes(entity, 5, true)
    SetPedCombatAttributes(entity, 0, true)
    SetPedCombatAttributes(entity, 2, true)
    SetPedCombatAttributes(entity, 3, true)
    SetPedFleeAttributes(entity, 0, false)
    SetPedCombatMovement(entity, 3)
    SetPedCombatRange(entity, 2)
    SetPedAccuracy(entity, 70)
    SetPedAsGroupMember(entity, GetPedGroupIndex(PlayerPedId()))
    SetGroupFormation(GetPedGroupIndex(PlayerPedId()), 4)
    SetPedAsEnemy(entity, false)
    SetPedKeepTask(entity, true)
    TaskSetBlockingOfNonTemporaryEvents(entity, true)

    CreateThread(function()
        while DoesEntityExist(entity) and ListContains(escorts, entity) do
            Wait(1000)

            local playerPed = PlayerPedId()

            if not IsPedGroupMember(entity, GetPedGroupIndex(playerPed)) then
                SetPedAsGroupMember(entity, GetPedGroupIndex(playerPed))
            end

            local aimTarget, hasTarget = GetPlayerTargetEntity(PlayerId())
            if hasTarget and DoesEntityExist(aimTarget) and IsEntityAPed(aimTarget) then
                TaskCombatPed(entity, aimTarget, 0, 16)
            else
                for _, entry in ipairs(Framework.GetNearbyPeds(GetEntityCoords(playerPed), 5.0)) do
                    if IsPedInCombat(entry.ped, playerPed) then
                        TaskCombatPed(entity, entry.ped, 0, 16)
                        break
                    end
                end
            end

            -- Teleport stragglers back to the player.
            local playerCoords = GetEntityCoords(playerPed)
            if #(GetEntityCoords(entity) - playerCoords) > 50.0 then
                local offsetX = playerCoords.x + random(-5, 5)
                local offsetY = playerCoords.y + random(-5, 5)
                local groundZ = GetGroundZFor_3dCoord(offsetX, offsetY, playerCoords.z, 0)
                SetEntityCoords(entity, offsetX, offsetY, groundZ, false, false, false, false)
            end
        end
    end)

    Framework.Notify(string.format(Settings.Text.escort_hired, #escorts, ESCORT_CAP), "success")
end

--- Returns the closest hostile ped to `entity` within `radius`.
function NearestHostileTo(entity, radius)
    local coords = GetEntityCoords(entity)
    local nearest, nearestDistance = nil, radius

    for _, ped in ipairs(Framework.GetNearbyPeds(coords, radius)) do
        local eligible = IsPedInCombat(ped, entity) or GetRelationshipBetweenPeds(entity, ped) > 3

        if eligible then
            local distance = #(coords - GetEntityCoords(ped))
            if distance < nearestDistance then
                nearestDistance = distance
                nearest = ped
            end
        end
    end

    return nearest
end

--- Releases an escort back into the ambient population.
function ReleaseEscort(entity)
    if not DoesEntityExist(entity) then
        return
    end

    for index, escort in ipairs(escorts) do
        if escort == entity then
            remove(escorts, index)
            break
        end
    end

    RemovePedFromGroup(entity)
    ClearPedTasksImmediately(entity)
    TaskWanderStandard(entity, 10.0, 10)
    SetPedRelationshipGroupHash(entity, vagrantRelGroup)
    SetPedCombatAttributes(entity, 46, false)
    SetPedCombatAttributes(entity, 5, false)

    SetTimeout(60000, function()
        if DoesEntityExist(entity) then
            SetPedAsNoLongerNeeded(entity)
        end
    end)

    Framework.Notify(Settings.Text.escort_released, "info")
end

-- All escorts scatter when the player goes down.
AddEventHandler("gameEventTriggered", function(eventName, data)
    if eventName ~= "CEventNetworkEntityDamage" then
        return
    end

    if data[1] == PlayerPedId() and data[6] == 1 then
        for _, escort in ipairs(escorts) do
            if DoesEntityExist(escort) then
                ReleaseEscort(escort)
            end
        end
        escorts = {}
    end
end)

-- Escorts pile onto whoever the player is brawling with.
CreateThread(function()
    while true do
        -- Idles at 1000ms; only busy while escorts actually exist.
        Wait(#escorts > 0 and 1000 or 1000)

        if #escorts > 0 and IsPedInCombat(PlayerPedId(), nil) then
            local meleeTarget = GetMeleeTargetForPed(PlayerPedId())

            if DoesEntityExist(meleeTarget) and not IsPedDeadOrDying(meleeTarget, true) then
                for _, escort in ipairs(escorts) do
                    if DoesEntityExist(escort) and not IsPedDeadOrDying(escort, true) then
                        SetPedCombatAttributes(escort, 46, true)
                        TaskCombatPed(escort, meleeTarget, 0, 16)
                    end
                end
            end
        end
    end
end)

function RegisterEscortInteractions()
    if Settings.UseTargetSystem then
        Target.AddModel(Settings.VagrantModels, {
            {
                label = Settings.Text.hire_escort,
                icon = "fas fa-user-shield",
                distance = 3.0,
                canInteract = function(entity)
                    return holdsThrone and not ListContains(escorts, entity) and #escorts < ESCORT_CAP
                end,
                onSelect = function(data)
                    HireEscort(data.entity)
                end,
            },
            {
                label = Settings.Text.release_escort,
                icon = "fas fa-user-times",
                distance = 3.0,
                canInteract = function(entity)
                    return holdsThrone and ListContains(escorts, entity)
                end,
                onSelect = function(data)
                    ReleaseEscort(data.entity)
                end,
            },
        })
        return
    end

    for _, modelName in ipairs(Settings.VagrantModels) do
        exports[INTERACT]:InteractionModel(GetHashKey(modelName), {
            {
                name = "bl_escort_interaction",
                distance = 3.0,
                radius = 1.5,
                options = {
                    {
                        label = Settings.Text.hire_escort,
                        canSee = function(data)
                            if type(data) ~= "table" then
                                return false
                            end
                            return holdsThrone and not ListContains(escorts, data.entity) and #escorts < ESCORT_CAP
                        end,
                        selected = function(data)
                            HireEscort(data.entity)
                        end,
                    },
                    {
                        label = Settings.Text.release_escort,
                        canSee = function(data)
                            return holdsThrone and ListContains(escorts, data.entity)
                        end,
                        selected = function(data)
                            ReleaseEscort(data.entity)
                        end,
                    },
                },
            },
        })
    end
end

-- --------------------------------------------------------------------------
--  THRONE STATUS
-- --------------------------------------------------------------------------

function RefreshThroneStatus()
    Framework.TriggerCallback("bl_dumpsters:server:HoldsThrone", function(status)
        holdsThrone = status
        SetRelationshipBetweenGroups(holdsThrone and 0 or 3, vagrantRelGroup, playerRelGroup)
        ReassignAmbientVagrants()
    end)
end

RegisterNetEvent("bl_dumpsters:client:ThroneChanged", function()
    Wait(1000)
    RefreshThroneStatus()
end)

RegisterNetEvent("bl_dumpsters:client:ThroneStatusRefresh", function()
    RefreshThroneStatus()
end)

RegisterNetEvent("bl_dumpsters:client:DisbandRetinue", function()
    for _, escort in ipairs(escorts) do
        ReleaseEscort(escort)
    end
    escorts = {}

    RemovePedFromGroup(PlayerPedId())
    RefreshThroneStatus()
end)

Framework.OnPlayerLoaded = function()
    Wait(2000)
    ConfigureRelationshipGroups()
    RegisterEscortInteractions()

    Framework.TriggerCallback("bl_dumpsters:server:GetStanding", function(standing)
        if standing and standing.level > 1 then
            Framework.Notify(string.format(Settings.Text.returning_scavenger, standing.level), "info")
        end
        RefreshThroneStatus()
    end)
end

-- --------------------------------------------------------------------------
--  DIAGNOSTIC COMMANDS
-- --------------------------------------------------------------------------

if Settings.DiagnosticMode then
    RegisterCommand("bl_tp_overseer", function()
        local anchor = Settings.Overseer.Anchor
        SetEntityCoords(cache.ped, anchor.x + 2, anchor.y, anchor.z)
    end, false)

    RegisterCommand("bl_test_trolley", function()
        if TrolleyHeld then
            return
        end

        local model = TROLLEY_MODELS[3]
        local coords = GetEntityCoords(cache.ped)
        Framework.LoadModel(model)

        HeldTrolley = CreateObject(model, coords.x, coords.y, coords.z, true, true, true)
        GrabTrolley(HeldTrolley)
    end, false)

    RegisterCommand("bl_test_throne", function()
        holdsThrone = not holdsThrone
        Framework.Notify("Throne status set to: " .. tostring(holdsThrone), "info")
        if holdsThrone then
            ConfigureRelationshipGroups()
        end
    end, false)

    RegisterCommand("bl_spawn_escort", function()
        if not holdsThrone or #escorts >= ESCORT_CAP then
            Framework.Notify("You must hold the throne and have fewer than 3 escorts.", "error")
            return
        end

        local coords = GetEntityCoords(cache.ped)
        local offset = random(-3, 3)
        local modelHash = GetHashKey(Settings.VagrantModels[random(#Settings.VagrantModels)])

        RequestModel(modelHash)
        while not HasModelLoaded(modelHash) do
            Wait(10)
        end

        local ped = CreatePed(4, modelHash, coords.x + offset, coords.y + offset, coords.z, 0.0, true, true)
        SetModelAsNoLongerNeeded(modelHash)
        HireEscort(ped)
    end, false)
end
