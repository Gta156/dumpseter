local containerDepleted = {}
local containerDepletedCoords = {}
local prizeClaimed = {}
local containerOccupied = {}
local containerOccupantSrc = {}
local provisionedStashes = {}

local function QueueContainerReset(netId)
    SetTimeout(Config.ContainerRespawnMinutes * 60000, function()
        containerDepleted[netId] = false
        containerDepletedCoords[netId] = nil
    end)
end

local function QueuePrizeReset(netId)
    SetTimeout(Config.ContainerRespawnMinutes * 60000, function()
        prizeClaimed[netId] = false
    end)
end

local function IsAdjacentToDepletedBin(coords)
    for _, busyCoords in pairs(containerDepletedCoords) do
        if #(coords - busyCoords) < 1.0 then
            return true
        end
    end
    return false
end

local function RollWeightedIndex(items)
    if not (items[1] and items[1].rarity) then
        print("No rarity defined, using random selection")
        return math.random(1, #items)
    end

    local weights = {}
    local totalWeight = 0
    for i, item in ipairs(items) do
        local weight = item.rarity or 50
        weight = 100 - weight
        weights[i] = weight
        totalWeight = totalWeight + weight
    end

    local roll = math.random(1, totalWeight)
    local cumulative = 0
    for i, weight in pairs(weights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            return i
        end
    end

    return math.random(1, #items)
end

local function GrantRummageLoot(source, items, netId, coords)
    local player = Framework.GetPlayer(source)
    if containerDepleted[netId] then
        Framework.Notify(source, Config.Lang.notrash, "error")
        return
    end

    if IsAdjacentToDepletedBin(coords) then
        Framework.Notify(source, Config.Lang.look, "error")
        return
    end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then
        if Config.StrictEntityValidation then
            Framework.Notify(source, Config.Lang.cheater, "error")
            return
        end
    end

    if not player then
        return
    end

    if Config and items then
        if Config.LootDrawSettings then
            local drawnIndexes = {}
            local itemCount = math.random(Config.LootDrawSettings.minDraws, Config.LootDrawSettings.maxDraws)

            for i = 1, itemCount, 1 do
                -- BUGFIX: the original loop read `until usedIndexes[index] or tries > #items`,
                -- which stops only once it rolls an index it has ALREADY taken. On the first
                -- iteration nothing is marked, so it spun until `tries > #items` and the
                -- follow-up `if tries <= #items` was then false — every draw was discarded and
                -- searching a dumpster/bin/encampment yielded nothing at all. The intent is to
                -- reroll while the index is a duplicate, so both tests are negated.
                local index
                local tries = 0
                repeat
                    index = RollWeightedIndex(items)
                    tries = tries + 1
                until not drawnIndexes[index] or tries > #items

                if not drawnIndexes[index] then
                    local item = items[index]
                    if item then
                        local amount = math.random(item.min, item.max)
                        if amount > 0 then
                            Framework.AddItem(source, item.name, amount, item.metadata)
                        end
                        drawnIndexes[index] = true
                        if netId then
                            containerDepleted[netId] = true
                            containerDepletedCoords[netId] = coords
                            QueueContainerReset(netId)
                        end
                    end
                end
            end
        end

        AwardStreetProgressLoot(source, netId, coords)
    end
end

local function GrantPrizeFind(source, items, netId)
    local player = Framework.GetPlayer(source)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(entity) then
        if Config.StrictEntityValidation then
            Framework.Notify(source, Config.Lang.cheater, "error")
            return
        end
    end

    if prizeClaimed[netId] then
        return
    end

    if not player then
        return
    end

    if Config and items then
        local index = RollWeightedIndex(items)
        local item = items[index]
        if item then
            local amount = math.random(item.min, item.max)
            if amount > 0 then
                Framework.AddItem(source, item.name, amount, item.metadata)
            end
            if netId then
                prizeClaimed[netId] = true
                QueuePrizeReset(netId)
            end
        end
    end
end

local function GrantSackLoot(source, items, netId, coords)
    local player = Framework.GetPlayer(source)
    if containerDepleted[netId] then
        Framework.Notify(source, Config.Lang.notrash, "error")
        return
    end

    if IsAdjacentToDepletedBin(coords) then
        Framework.Notify(source, Config.Lang.look_somewhere_else, "error")
        return
    end

    if not player then
        return
    end

    if Config and items then
        if Config.LootDrawSettings then
            local drawnIndexes = {}
            local itemCount = math.random(Config.LootDrawSettings.minDraws, Config.LootDrawSettings.maxDraws)

            for i = 1, itemCount, 1 do
                local index = RollWeightedIndex(items)
                local item = items[index]
                if item then
                    local amount = math.random(item.min, item.max)
                    if amount > 0 then
                        Framework.AddItem(source, item.name, amount, item.metadata)
                    end

                    if netId then
                        containerDepleted[netId] = true
                        containerDepletedCoords[netId] = coords
                        QueueContainerReset(netId)
                    end
                end
            end
        end
    end
end

local function GrantSingleFind(source, items)
    local player = Framework.GetPlayer(source)
    if Config and items then
        local index = RollWeightedIndex(items)
        local item = items[index]
        if item then
            local amount = math.random(item.min, item.max)
            if amount > 0 then
                Framework.AddItem(source, item.name, amount, item.metadata)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
--  Container loot callbacks
-- ---------------------------------------------------------------------------

--- Resolve a Signature Loot Zone from whatever the client sent.
---
--- BUGFIX: the client sends the zone's ARRAY INDEX (`activeLootZoneIndex`), but the
--- original server code compared that value against `zone.name` (a string). A number is
--- never equal to a string in Lua, so the branch never matched: standing inside a
--- Signature Loot Zone silently produced NO loot at all, because the `else` fallback only
--- ran inside the non-matching branch. Both forms are accepted here, so zone loot works
--- whether the caller passes an index or a name.
---@param zoneRef any
---@return table|nil
local function ResolveLootZone(zoneRef)
    if zoneRef == nil then
        return nil
    end

    local index = tonumber(zoneRef)
    if index and Config.SignatureLootZones[index] then
        return Config.SignatureLootZones[index]
    end

    if type(zoneRef) == "string" then
        for _, zone in ipairs(Config.SignatureLootZones) do
            if zone.name == zoneRef then
                return zone
            end
        end
    end

    return nil
end

--- Shared body for every container type.
--- `grant` is the loot-granting strategy (bulk rummage vs. sack) so the six original
--- near-identical callbacks collapse into one audited code path.
local function HandleContainerLoot(source, cb, netId, rawCoords, zoneRef, opts)
    local player, src, coords, id = Security.ValidateContainerAccess(source, netId, rawCoords)
    if not player then
        if cb then cb(false) end
        return
    end

    -- One rummage per container per cooldown, and a global per-player throttle so a
    -- scripted client cannot fire hundreds of loot requests per second.
    if not Security.RateLimit(src, "rummage", 500) then
        if cb then cb(false) end
        return
    end

    if opts.respectDepleted and containerDepleted[id] then
        Framework.Notify(src, Config.Lang.notrash, "error")
        if cb then cb(false) end
        return
    end

    local zone = ResolveLootZone(zoneRef)
    local grant = opts.grant
    local defaultLoot = opts.defaultLoot

    if zone and zone.items and math.random(1, 100) <= (zone.chance or 0) then
        grant(src, zone.items, id, coords)
    else
        grant(src, defaultLoot, id, coords)
    end

    if opts.prizes and math.random(1, 100) <= (opts.prizeChance or 0) then
        opts.grantPrize(src, opts.prizes, id)
    end

    if cb then cb(true) end
end

Framework.CreateCallback("bl_scav:GiveItemsBeach", function(source, cb, netId, coords, zoneRef)
    HandleContainerLoot(source, cb, netId, coords, zoneRef, {
        respectDepleted = true,
        grant = GrantRummageLoot,
        defaultLoot = Config.ShorelineBinLoot,
        prizes = Config.ShorelineBinPrizes,
        prizeChance = Config.ShorelineBinPrizeChance,
        grantPrize = GrantPrizeFind,
    })
end)

Framework.CreateCallback("bl_scav:GiveItemsDumpster", function(source, cb, netId, coords, zoneRef)
    HandleContainerLoot(source, cb, netId, coords, zoneRef, {
        respectDepleted = true,
        grant = GrantRummageLoot,
        defaultLoot = Config.SkipLoot,
        prizes = Config.SkipPrizes,
        prizeChance = Config.SkipPrizeChance,
        grantPrize = GrantPrizeFind,
    })
end)

Framework.CreateCallback("bl_scav:GiveItemsGarbageCans", function(source, cb, netId, coords, zoneRef)
    HandleContainerLoot(source, cb, netId, coords, zoneRef, {
        respectDepleted = true,
        grant = GrantRummageLoot,
        defaultLoot = Config.StreetBinLoot,
        prizes = Config.StreetBinPrizes,
        prizeChance = Config.StreetBinPrizeChance,
        grantPrize = GrantPrizeFind,
    })
end)

Framework.CreateCallback("bl_scav:GiveItemsOther", function(source, cb, netId, coords, zoneRef)
    HandleContainerLoot(source, cb, netId, coords, zoneRef, {
        respectDepleted = true,
        grant = GrantRummageLoot,
        defaultLoot = Config.EncampmentLoot,
        prizes = Config.EncampmentPrizes,
        prizeChance = Config.EncampmentPrizeChance,
        grantPrize = GrantPrizeFind,
    })
end)

Framework.CreateCallback("bl_scav:GiveItemsBags", function(source, cb, netId, coords, zoneRef)
    HandleContainerLoot(source, cb, netId, coords, zoneRef, {
        respectDepleted = false,
        grant = GrantSackLoot,
        defaultLoot = Config.RefuseSackLoot,
        prizes = Config.RefuseSackPrizes,
        prizeChance = Config.RefuseSackPrizeChance,
        -- Sacks award a single bonus item and take no netId.
        grantPrize = function(src, prizes) GrantSingleFind(src, prizes) end,
    })
end)

--- Operator-defined props (luggage, mailboxes, ...).
Framework.CreateCallback("bl_scav:GiveItemsCustom", function(source, cb, netId, coords, zoneRef, customIndex)
    local player, src, validCoords, id = Security.ValidateContainerAccess(source, netId, coords)
    if not player then
        if cb then cb(false) end
        return
    end

    if not Security.RateLimit(src, "rummage", 500) then
        if cb then cb(false) end
        return
    end

    -- SECURITY: customIndex is attacker-controlled; only accept a real catalogue entry.
    local custom = BLScav_OperatorProps[tonumber(customIndex) or customIndex]
    if type(custom) ~= "table" then
        Security.Flag(src, "unknown operator prop index")
        if cb then cb(false) end
        return
    end

    if containerDepleted[id] then
        Framework.Notify(src, Config.Lang.notrash, "error")
        if cb then cb(false) end
        return
    end

    if IsAdjacentToDepletedBin(validCoords) then
        Framework.Notify(src, Config.Lang.look, "error")
        if cb then cb(false) end
        return
    end

    -- Signature zone loot takes precedence when the roll succeeds.
    local zone = ResolveLootZone(zoneRef)
    if zone and zone.items and math.random(1, 100) <= (zone.chance or 0) then
        GrantRummageLoot(src, zone.items, id, validCoords)
        if cb then cb(true) end
        return
    end

    if custom.loot and #custom.loot > 0 and Config.LootDrawSettings then
        local drawnIndexes = {}
        local itemCount = math.random(Config.LootDrawSettings.minDraws, Config.LootDrawSettings.maxDraws)

        for _ = 1, itemCount do
            -- BUGFIX: same inverted duplicate-guard as GrantRummageLoot above; operator-defined
            -- searchable props never dropped any of their configured loot.
            local index
            local tries = 0
            repeat
                index = RollWeightedIndex(custom.loot)
                tries = tries + 1
            until not drawnIndexes[index] or tries > #custom.loot

            if not drawnIndexes[index] then
                local item = custom.loot[index]
                if item then
                    local amount = math.random(item.min, item.max)
                    if amount > 0 then
                        Framework.AddItem(src, item.name, amount, item.metadata)
                    end
                    drawnIndexes[index] = true
                    containerDepleted[id] = true
                    containerDepletedCoords[id] = validCoords
                    QueueContainerReset(id)
                end
            end
        end

        AwardStreetProgressLoot(src, id, validCoords)
    end

    if cb then cb(true) end
end)

function BuildContainerKey(coords)
    return string.format("%.0f", coords.x) .. string.format("%.0f", coords.y) .. string.format("%.0f", coords.z)
end

--- Shared implementation for the four container-stash callbacks.
--- SECURITY: the original trusted the client's `coords` verbatim to build the stash id,
--- so a modified client could open (or create) any stash by sending fabricated
--- coordinates, and could register unlimited stashes to exhaust server memory.
--- Coordinates are now validated against the server's own view of the entity and the
--- player's real position before a stash id is derived.
local function ProvisionContainerStash(source, cb, netId, rawCoords, prefix, slots, weight)
    if not Config.ContainerStorageEnabled then
        return cb(false)
    end

    local player, src, coords = Security.ValidateContainerAccess(source, netId, rawCoords)
    if not player then
        return cb(false)
    end

    if not Security.RateLimit(src, "openStash", 250) then
        return cb(false)
    end

    local hash = BuildContainerKey(coords)
    local stashId = prefix .. hash
    Framework.RegisterStash(stashId, slots, weight)
    provisionedStashes[stashId] = true
    cb(hash)
end

Framework.CreateCallback("bl_scav:OpenBeach", function(source, cb, netId, coords)
    ProvisionContainerStash(source, cb, netId, coords, "Beach", Config.ShorelineBinSlots, Config.ShorelineBinWeight)
end)

Framework.CreateCallback("bl_scav:OpenDumpster", function(source, cb, netId, coords)
    ProvisionContainerStash(source, cb, netId, coords, "Dumpster", Config.SkipSlots, Config.SkipWeight)
end)

Framework.CreateCallback("bl_scav:OpenGarbage", function(source, cb, netId, coords)
    ProvisionContainerStash(source, cb, netId, coords, "Garbage", Config.StreetBinSlots, Config.StreetBinWeight)
end)

Framework.CreateCallback("bl_scav:OpenOther", function(source, cb, netId, coords)
    ProvisionContainerStash(source, cb, netId, coords, "Hobo", Config.EncampmentSlots, Config.EncampmentWeight)
end)

-- SECURITY: the original stored `source` as the occupant on every call without checking
-- that the caller was a real player, and let any client mark any container as occupied
-- or free — including releasing a container another player was hiding in. A player may
-- now only claim a container they are standing next to, and may only release one they
-- personally claimed.
RegisterNetEvent("bl_scav:setDumpsterBusy", function(netId, busy)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end

    local entity, id = Security.ResolveEntity(netId, false)
    if not id then
        Security.Flag(src, "malformed network id for container occupancy")
        return
    end

    if busy then
        if entity and not Security.IsPlayerNear(src, GetEntityCoords(entity)) then
            Security.Flag(src, "claimed an out-of-range container")
            return
        end
        containerOccupied[id] = true
        containerOccupantSrc[id] = src
    else
        -- Only the current occupant (or a stale/empty slot) may clear the flag.
        if containerOccupantSrc[id] and containerOccupantSrc[id] ~= src then
            Security.Flag(src, "attempted to release another player's container")
            return
        end
        containerOccupied[id] = false
        containerOccupantSrc[id] = nil
    end
end)

Framework.CreateCallback("bl_scav:checkDumpsterIsFree", function(source, cb, netId)
    local isBusy = false
    if containerOccupied[netId] then
        isBusy = true
    end

    if isBusy then
        Framework.Notify(source, Config.Lang.dumpster_busy, "error")
        TriggerClientEvent("bl_scav:kickOutOfDumpster", containerOccupantSrc[netId])
        containerOccupantSrc[netId] = nil
        containerOccupied[netId] = false
        cb(false)
    else
        cb(true)
    end
end)

-- BUGFIX + SECURITY.
--
-- Bug: Config.SignatureLootZones is a *sequential array* of zone tables, but the original
-- indexed it with the zone NAME (`Config.SignatureLootZones[zoneName]`). That always
-- returned nil, so the very next line (`zone.jobsToInform`) threw "attempt to index a nil
-- value" and the police were never alerted. The lookup is now done by matching `.name`.
--
-- Security: the event was fully unauthenticated and broadcast to every client (-1) using
-- client-supplied coordinates, so any client could spam fake police alerts anywhere on the
-- map. It is now rate limited, coordinate-validated and range-checked.
RegisterNetEvent("bl_scav:snitch", function(rawCoords, zoneName)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end

    if type(zoneName) ~= "string" or #zoneName > 64 then
        Security.Flag(src, "malformed zone name in snitch report")
        return
    end

    local coords = Security.SanitiseCoords(rawCoords)
    if not coords or not Security.IsPlayerNear(src, coords, 25.0) then
        Security.Flag(src, "snitch report from an implausible position")
        return
    end

    if not Security.RateLimit(src, "snitch", 5000) then
        return
    end

    local zone
    for _, candidate in ipairs(Config.SignatureLootZones) do
        if candidate.name == zoneName then
            zone = candidate
            break
        end
    end

    if not zone or not zone.snitchChance then
        return
    end

    if math.random(1, 100) <= zone.snitchChance then
        TriggerClientEvent("bl_scav:snitchReport", -1, coords, zone.jobsToInform or {})
    end
end)

if Config.WipeContainerStorageOnRestart then
    AddEventHandler("onResourceStop", function(resourceName)
        if GetCurrentResourceName() ~= resourceName then
            return
        end

        for stashId, isRegistered in pairs(provisionedStashes) do
            if isRegistered then
                Framework.ClearInventory(stashId)
            end
        end
    end)
end
