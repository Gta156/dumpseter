--[[
    Market purchase (rewritten).

    Two problems with the original:

      1. ARGUMENT MISMATCH (functional bug). The client calls
             TriggerCallback("...BuyHoboItem", cb, itemName, quantity, totalPrice)
         but the server declared
             function(source, cb, itemKey, itemName, quantity)
         so `itemName` received the QUANTITY and `quantity` received the total price. The
         server then called AddItem(source, <quantity>, <totalPrice>) -- i.e. it tried to add
         an item literally named "1". Buying from the hobo shop could not work.

      2. NO SERVER PRICING. Cost was taken as 1 cap per unit and the item name came straight
         from the client, so a crafted call could mint any item in the game for a few caps.

    The catalogue in shared config is now the single source of truth: the client sends only
    the item name and a quantity, and the server resolves price and required rank itself.
]]
local MAX_PURCHASE_QUANTITY = 100

--- Find a catalogue entry by item name. Returns entry, requiredLevel.
local function FindCatalogueEntry(itemName)
    if type(itemName) ~= "string" or itemName == "" then
        return nil, nil
    end
    for level, entries in pairs(Config.UnlockCatalogue or {}) do
        for _, entry in ipairs(entries) do
            if entry.name == itemName then
                return entry, level
            end
        end
    end
    return nil, nil
end

Framework.CreateCallback("bl_scav:server:BuyHoboItem", function(source, cb, itemName, quantity)
    local player, src = Security.ResolvePlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    if not Security.RateLimit(src, "market_purchase", 750) then
        return cb(false, Config.Lang.too_fast or Config.Lang.cheater)
    end

    -- Quantity must be a clean positive integer within a sane bound.
    quantity = tonumber(quantity)
    if not quantity or quantity ~= quantity or quantity == math.huge
        or quantity ~= math.floor(quantity) or quantity < 1
        or quantity > MAX_PURCHASE_QUANTITY then
        Security.Flag(src, "market purchase with an invalid quantity")
        return cb(false, Config.Lang.cheater)
    end

    -- The item must exist in the catalogue; this is what stops arbitrary item injection.
    local entry, requiredLevel = FindCatalogueEntry(itemName)
    if not entry then
        Security.Flag(src, "market purchase of an item outside the catalogue")
        return cb(false, Config.Lang.cheater)
    end

    local record = FetchStreetRecord(player.Identifier)
    local playerLevel = (record and record.level) or 1
    if (requiredLevel or 10) > playerLevel then
        return cb(false, Config.Lang.level_too_low)
    end

    -- Price is read from the server-side catalogue, never from the client.
    local unitPrice = tonumber(entry.price) or 0
    if unitPrice < 0 then
        unitPrice = 0
    end
    local totalPrice = math.floor(unitPrice * quantity)

    local bottleCapItem = Config.CapCurrencyItem or "bottle_cap"
    if Framework.GetItemCount(src, bottleCapItem) < totalPrice then
        return cb(false, Config.Lang.not_enough_caps)
    end

    if totalPrice > 0 and not Framework.RemoveItem(src, bottleCapItem, totalPrice) then
        return cb(false, Config.Lang.failed_remove_caps)
    end

    if not Framework.AddItem(src, entry.name, quantity) then
        -- Refund on failure so a full inventory never eats the player's caps.
        if totalPrice > 0 then
            Framework.AddItem(src, bottleCapItem, totalPrice)
        end
        return cb(false, Config.Lang.failed_add_item)
    end

    AwardStreetXP(player.Identifier, quantity)
    -- Message reads "<qty>x <item> for <price> caps"; the original passed the arguments in
    -- the wrong order (item, key, qty) so the line rendered nonsense.
    return cb(true, string.format(Config.Lang.purchased_quantity, quantity, entry.label or entry.name, totalPrice))
end)

function ResolveUnlockRank(itemName)
    for level, items in pairs(Config.UnlockCatalogue) do
        for _, item in ipairs(items) do
            if item.name == itemName then
                return level
            end
        end
    end
    return 10
end

Framework.CreateCallback("bl_scav:server:HasItem", function(source, cb, itemName)
    cb(Framework.HasItem(source, itemName))
end)

-- REMOVED (security): duplicate registration of the unrestricted "RemoveItem" net event.
-- See the note in server/contracts.lua. Registering it twice meant a single client call
-- deleted the named item TWICE over. No client code triggered it.

local panhandleLocked = false
local PANHANDLE_COOLDOWN_MS = 2000

Framework.CreateCallback("bl_scav:server:DoCooldown", function(source, cb, hasSign)
    local player = Framework.GetPlayer(source)

    local reward = math.random(1, Config.PanhandleSettings.MaxBaseReward)
    if hasSign then
        reward = reward * Config.PanhandleSettings.BegWithSignMultiplier
    end

    if player.Job.Name == Config.VagrantJobRole then
        reward = reward * Config.PanhandleSettings.TrueHoboMultiplier
    end

    if reward > Config.PanhandleSettings.MaxTotalReward then
        reward = Config.PanhandleSettings.MaxTotalReward
    end

    if not player then
        return
    end

    if panhandleLocked then
        reward = 1
        return
    end

    player.AddMoney("cash", reward)
    panhandleLocked = true

    local identifier = player.Identifier
    local progression = FetchStreetRecord(identifier)
    if progression.level == 3 then
        local missionData = progression.mission_data[3] or {}
        missionData.money_collected = (missionData.money_collected or 0) + reward
        AdvanceContract(identifier, 3, missionData)

        Framework.Notify(source, string.format(Config.Lang.begging_progress, missionData.money_collected, Config.Contracts[3].RequiredAmount), "info")

        if missionData.money_collected >= Config.Contracts[3].RequiredAmount then
            FinalizeContract(identifier, 3)
            Framework.Notify(source, Config.Lang.collected_enough_money, "success")
        end
    end

    TriggerEvent("bl_scav:server:BeggingReceived", source, reward)

    SetTimeout(PANHANDLE_COOLDOWN_MS, function()
        panhandleLocked = false
    end)

    cb(reward)
end)

Framework.CreateCallback("bl_scav:server:DeliverMedicalPackage", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Config.Lang.player_not_found)
    end

    local hasPackage = Framework.GetItemCount(source, "medical_care_package") > 0
    if not hasPackage then
        return cb(false, Config.Lang.no_medical_package)
    end

    Framework.RemoveItem(source, "medical_care_package", 1)

    local identifier = player.Identifier
    local progression = FetchStreetRecord(identifier)

    if progression.level == 6 then
        local missionData = progression.mission_data[6] or {}
        missionData.package_delivered = true
        AdvanceContract(identifier, 6, missionData)

        if missionData.dumpsters_searched >= 100 then
            if missionData.package_found then
                if missionData.package_delivered then
                    FinalizeContract(identifier, 6)
                    cb(true, Config.Lang.package_delivered_complete)
                end
            end
        else
            cb(true, Config.Lang.package_delivered)
        end
    else
        cb(true, Config.Lang.package_delivered)
    end
end)
