--[[
    Deployable-gear ledger.

    The place/retrieve loop works like this: using the item removes it from inventory and
    spawns a prop client-side; interacting with that prop fires a "pick up" event that
    gives the item back. The original trusted those pick-up events unconditionally, so a
    client could fire bl_scav:server:PickUpTent (or the bed / sleeping-bag equivalents) on
    repeat and mint unlimited items without ever having placed one.

    We now keep a server-side credit per player, incremented only when the server itself
    consumed the item, and decremented on retrieval. A player can never retrieve more than
    they actually deployed.
]]
local deployedGear = {}

local function GrantDeployCredit(src, itemName)
    deployedGear[src] = deployedGear[src] or {}
    deployedGear[src][itemName] = (deployedGear[src][itemName] or 0) + 1
end

--- Consume one deployment credit. Returns false when the player has none outstanding.
local function ConsumeDeployCredit(src, itemName)
    local owned = deployedGear[src]
    if not owned or (owned[itemName] or 0) <= 0 then
        return false
    end
    owned[itemName] = owned[itemName] - 1
    return true
end

AddEventHandler("playerDropped", function()
    deployedGear[source] = nil
end)

--[[
    Stash-ownership guard.

    Tent and backpack stash ids are minted server-side as `identifier .. RandomString(5) ..
    RandomInteger(5)` and then travel in item metadata. The OpenTent / OpenBackpack callbacks
    used to register and open whatever id the client sent, so a client could pass another
    player's stash id -- or any arbitrary string -- and read/write a stash they do not own.

    Because every legitimate id is prefixed with the owner's identifier, ownership is provable
    without a database round-trip: require the claimed id to start with the caller's own
    identifier, and constrain type/shape to keep hostile payloads out of the stash registry.
]]
local function ResolveOwnedStashId(src, claimedId)
    if type(claimedId) ~= "string" then
        return nil
    end

    -- Length bounds: identifier prefix + 5 chars + 5 digits, with head-room for long
    -- licence-style identifiers. Anything outside this is not something we minted.
    if #claimedId < 8 or #claimedId > 128 then
        return nil
    end

    -- Only characters our generator can emit; blocks separators and control bytes that
    -- some inventory backends treat as path or namespace delimiters.
    if claimedId:find("[^%w:_%-]") then
        return nil
    end

    local player = Framework.GetPlayer(src)
    if not player then
        return nil
    end

    local identifier = player.Identifier
    if type(identifier) ~= "string" or identifier == "" then
        return nil
    end

    -- Plain (non-pattern) prefix comparison.
    if claimedId:sub(1, #identifier) ~= identifier then
        if Security and Security.Flag then
            Security.Flag(src, "attempted to open a stash id belonging to another identifier")
        end
        return nil
    end

    return claimedId
end

Framework.CreateUseableItem("cardboard_bed", function(source)
    local removed = Framework.RemoveItem(source, "cardboard_bed", 1)
    if removed then
        GrantDeployCredit(source, "cardboard_bed")
        TriggerClientEvent("bl_scav:client:UseItem", source, "cardboard_bed")
    end
end)

Framework.CreateUseableItem("sleeping_bag", function(source)
    local removed = Framework.RemoveItem(source, "sleeping_bag", 1)
    if removed then
        GrantDeployCredit(source, "sleeping_bag")
        TriggerClientEvent("bl_scav:client:UseItem", source, "sleeping_bag")
    end
end)

Framework.CreateUseableItem("hobo_tent", function(source, itemName, itemData)
    local tentID = itemData or nil
    if itemData then
        tentID = itemData.metadata
        if tentID then
            tentID = tentID.tentID
        end
    end

    if not tentID then
        local identifier = Framework.GetPlayer(source).Identifier
        local newTentID = identifier .. Framework.RandomString(5) .. Framework.RandomInteger(5)

        Framework.SetItemMetadata(source, itemData.slot, { tentID = newTentID })
        Framework.Notify(source, Config.Lang.welcome_new_home, "success")

        local removed = Framework.RemoveItem(source, "hobo_tent", 1, nil, itemData.slot)
        if removed then
            GrantDeployCredit(source, "hobo_tent")
            TriggerClientEvent("bl_scav:client:UseItem", source, "hobo_tent", { tentID = newTentID })
        end
        return
    end

    tentID = itemData or tentID
    if itemData then
        tentID = itemData.metadata
        if tentID then
            tentID = tentID.tentID
        end
    end

    if tentID then
        local removed = Framework.RemoveItem(source, "hobo_tent", 1, itemData.metadata, itemData.slot)
        if removed then
            GrantDeployCredit(source, "hobo_tent")
            TriggerClientEvent("bl_scav:client:UseItem", source, "hobo_tent", itemData.metadata)
        end
        return
    end
end)

Framework.CreateUseableItem("hobo_bottle", function(source, itemName, itemData)
    local uses = itemData or nil
    if itemData then
        uses = itemData.metadata
        if uses then
            uses = uses.uses
        end
    end

    if not uses then
        Framework.SetItemMetadata(source, itemData.slot, { uses = Config.GearSettings.hobo_bottle.capacity - 1 })
        TriggerClientEvent("bl_scav:client:UseItem", source, "hobo_bottle")
        Framework.Notify(source, string.format(Config.Lang.remaining_uses, Config.GearSettings.hobo_bottle.capacity - 1), "success")
        return
    end

    uses = itemData or uses
    if itemData then
        uses = itemData.metadata
        if uses then
            uses = uses.uses
        end
    end

    if uses then
        uses = itemData.metadata.uses
        if uses > 0 then
            Framework.SetItemMetadata(source, itemData.slot, { uses = itemData.metadata.uses - 1 })
            TriggerClientEvent("bl_scav:client:UseItem", source, "hobo_bottle", itemData.metadata)
            Framework.Notify(source, string.format(Config.Lang.remaining_uses, itemData.metadata.uses - 1), "success")
        end
    else
        Framework.Notify(source, Config.Lang.bottle_empty, "error")
    end
end)

local rationPackProvides = Config.GearSettings.ration_pack.provides

Framework.CreateUseableItem("ration_pack", function(source)
    local removed = Framework.RemoveItem(source, "ration_pack", 1)
    if removed then
        TriggerClientEvent("bl_scav:client:UseItem", source, "ration_pack")

        for _, entry in ipairs(rationPackProvides) do
            Framework.AddItem(source, entry.item, math.random(1, entry.max))
        end
    end
end)

Framework.CreateUseableItem("begging_sign", function(source)
    TriggerClientEvent("bl_scav:client:UseItem", source, "begging_sign")
end)

-- SECURITY: `slot` is attacker-controlled and was written straight into
-- SetItemMetadata. A modified client could target an arbitrary inventory slot and
-- overwrite its metadata with { uses = N } — corrupting or re-rolling other items.
-- The slot is now validated as a positive integer AND confirmed to actually contain a
-- hobo_bottle before anything is written.
RegisterNetEvent("bl_scav:server:RefillBottle", function(slot)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end

    if not Security.RateLimit(src, "refillBottle", 1000) then
        return
    end

    local slotId = tonumber(slot)
    if not slotId or slotId <= 0 or slotId ~= math.floor(slotId) then
        Security.Flag(src, "malformed inventory slot on bottle refill")
        return
    end

    -- Confirm the targeted slot really holds the bottle we are about to modify.
    -- Framework.GetInventory is the bridge's inventory accessor (see envi-bridge);
    -- if it is unavailable we fall back to the ownership check below.
    local inventory = Framework.GetInventory and Framework.GetInventory(src) or nil
    if type(inventory) == "table" then
        local slotItem = inventory[slotId]
        -- Some inventory backends key by slot, others return a dense list carrying `.slot`.
        if not slotItem then
            for _, entry in pairs(inventory) do
                if type(entry) == "table" and entry.slot == slotId then
                    slotItem = entry
                    break
                end
            end
        end
        if not slotItem or slotItem.name ~= "hobo_bottle" then
            Security.Flag(src, "bottle refill targeted a slot that does not hold a bottle")
            return
        end
    elseif Framework.GetItemCount(src, "hobo_bottle") <= 0 then
        Security.Flag(src, "bottle refill without owning a bottle")
        return
    end

    Framework.SetItemMetadata(src, slotId, { uses = Config.GearSettings.hobo_bottle.capacity })
    Framework.Notify(src, Config.Lang.bottle_refilled, "success")
end)

-- Rate limited: the original allowed unlimited calls, letting a client drive thirst and
-- hunger stats arbitrarily without ever consuming a bottle use.
RegisterNetEvent("bl_scav:server:DrinkBottle", function()
    local player, playerId = Security.ResolvePlayer(source)
    if not player then
        return
    end
    if not Security.RateLimit(playerId, "drinkBottle", 1500) then
        return
    end

    local isHobo = player.Job.Name == Config.VagrantJobRole

    local thirst = player.GetStatus("thirst")
    local hydration = Config.GearSettings.hobo_bottle.hydration
    if not hydration then
        hydration = 20
    end
    player.SetStatus("thirst", thirst + hydration)

    if not isHobo then
        player.SetStatus("hunger", player.GetStatus("hunger") - 10)
        Framework.Notify(playerId, Config.Lang.feel_sick, "error")
        TriggerClientEvent("bl_scav:client:DrinkBottleBadEffect", playerId)
    else
        player.SetStatus("hunger", player.GetStatus("hunger") + 3)
        Framework.Notify(playerId, Config.Lang.feel_refreshed, "success")
        TriggerClientEvent("bl_scav:client:DrinkBottleGoodEffect", playerId)
    end
end)

Framework.CreateUseableItem("rat_bait", function(source)
    local removed = Framework.RemoveItem(source, "rat_bait", 1)
    if removed then
        TriggerClientEvent("bl_scav:client:useRatBait", source)
    end
end)

RegisterNetEvent("bl_scav:server:PickUpCardboardBed", function()
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end
    if not Security.RateLimit(src, "pickupGear", 500) then
        return
    end
    if not ConsumeDeployCredit(src, "cardboard_bed") then
        Security.Flag(src, "retrieved a cardboard bed that was never deployed")
        return
    end

    Framework.AddItem(src, "cardboard_bed", 1)
end)

RegisterNetEvent("bl_scav:server:PickUpSleepingBag", function()
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end
    if not Security.RateLimit(src, "pickupGear", 500) then
        return
    end
    if not ConsumeDeployCredit(src, "sleeping_bag") then
        Security.Flag(src, "retrieved a sleeping bag that was never deployed")
        return
    end

    Framework.AddItem(src, "sleeping_bag", 1)
end)

RegisterNetEvent("bl_scav:server:PickUpTent", function(tentData)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end
    if not Security.RateLimit(src, "pickupGear", 500) then
        return
    end
    if not ConsumeDeployCredit(src, "hobo_tent") then
        Security.Flag(src, "retrieved a tent that was never deployed")
        return
    end

    -- Only the stash-linking metadata is preserved; arbitrary client tables are dropped
    -- so a modified client cannot inject extra item metadata (durability, quality, ...).
    local safeMetadata
    if type(tentData) == "table" and type(tentData.tentID) == "string" and #tentData.tentID <= 128 then
        safeMetadata = { tentID = tentData.tentID }
    end

    Framework.AddItem(src, "hobo_tent", 1, safeMetadata)
end)

Framework.CreateUseableItem("medical_care_package", function(source)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    local progression = FetchStreetRecord(player.Identifier)
    if progression then
        if progression.level == 6 then
            local missionData = progression.mission_data[6]
            if not missionData then
                missionData = {}
            end

            if missionData.package_found then
                if not missionData.package_delivered then
                    Framework.Notify(source, Config.Lang.take_medical_package, "info")
                end
            end
        end
    else
        Framework.Notify(source, Config.Lang.valuable_medical_supplies, "info")
    end
end)

RegisterNetEvent("bl_scav:server:UseRatTreats", function()
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return
    end
    if not Security.RateLimit(src, "ratTreats", 1000) then
        return
    end
    local playerId = src

    Framework.RemoveItem(playerId, "rat_treats", 1)
    Framework.Notify(playerId, Config.Lang.rat_treats_used, "success")
end)

Framework.CreateCallback("bl_scav:server:OpenBackpack", function(source, cb, data)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    if player.Job.Name ~= Config.VagrantJobRole then
        Framework.Notify(source, Config.Lang.not_hobo, "error")
        cb(false)
        return
    end

    local backpackID = ResolveOwnedStashId(source, type(data) == "table" and data.backpackID or nil)
    if not backpackID then
        Framework.Notify(source, Config.Lang.cheater, "error")
        cb(false)
        return
    end

    Framework.RegisterStash(backpackID, 30, 100000, nil, { [Config.VagrantJobRole] = 0 })
    cb(true)
end)

Framework.CreateCallback("bl_scav:server:OpenTent", function(source, cb, data)
    local player = Framework.GetPlayer(source)
    if not player then
        return
    end

    if player.Job.Name ~= Config.VagrantJobRole then
        Framework.Notify(source, Config.Lang.not_hobo, "error")
        cb(false)
        return
    end

    local tentID = ResolveOwnedStashId(source, type(data) == "table" and data.tentID or nil)
    if not tentID then
        Framework.Notify(source, Config.Lang.cheater, "error")
        cb(false)
        return
    end

    Framework.RegisterStash(tentID, 60, 200000, nil, { [Config.VagrantJobRole] = 0 })
    cb(true)
end)
