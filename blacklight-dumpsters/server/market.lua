--[[ ==========================================================================
     BlackLight Dumpsters — Street Market, Panhandling Payouts & Parcel Hand-in
========================================================================== ]]

local random, floor = math.random, math.floor

--- Which rank unlocks a given market item?
function RankForStockItem(itemName)
    for rank, stock in pairs(Settings.MarketStock) do
        for _, entry in ipairs(stock) do
            if entry.name == itemName then
                return rank
            end
        end
    end
    return 10
end

--- Recomputes an item's price from config so a spoofed client cost is ignored.
local function TrustedUnitPrice(itemName)
    for _, stock in pairs(Settings.MarketStock) do
        for _, entry in ipairs(stock) do
            if entry.name == itemName then
                return entry.price
            end
        end
    end
    return nil
end

-- --------------------------------------------------------------------------
--  MARKET PURCHASES
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:PurchaseStock", function(source, cb, itemName, quantity, _clientTotal)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Settings.Text.profile_not_found)
    end

    if not GuardRate(source, "market_purchase", 1000) then
        return cb(false, Settings.Text.currency_short)
    end

    quantity = GuardNumber(quantity, 1, 10)
    if not quantity then
        return cb(false, Settings.Text.currency_short)
    end

    -- Never trust the client's arithmetic — recompute the total from config.
    local unitPrice = TrustedUnitPrice(itemName)
    if not unitPrice then
        return cb(false, Settings.Text.rank_too_low)
    end

    local totalPrice = unitPrice * quantity
    local currencyItem = Settings.CurrencyItem or "bottle_cap"
    local identifier = player.Identifier

    if RankForStockItem(itemName) > FetchStanding(identifier).level then
        return cb(false, Settings.Text.rank_too_low)
    end

    if not GuardInventory(source, currencyItem, totalPrice) then
        return cb(false, Settings.Text.currency_short)
    end

    if not Framework.RemoveItem(source, currencyItem, totalPrice) then
        return cb(false, Settings.Text.currency_removal_failed)
    end

    if not Framework.AddItem(source, itemName, quantity) then
        -- Roll the transaction back so the player is never left out of pocket.
        Framework.AddItem(source, currencyItem, totalPrice)
        return cb(false, Settings.Text.item_grant_failed)
    end

    GrantReputationXP(identifier, totalPrice)

    cb(true, string.format(Settings.Text.purchase_bulk_done, quantity, itemName, totalPrice))
end)

Framework.CreateCallback("bl_dumpsters:server:HasStockItem", function(source, cb, itemName)
    cb(Framework.HasItem(source, itemName))
end)

RegisterNetEvent("bl_dumpsters:server:DiscardItem", function(itemName, quantity)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "discard_item", 500) then
        return
    end

    quantity = GuardNumber(quantity, 1, 100)
    if not quantity or type(itemName) ~= "string" then
        return
    end

    Framework.RemoveItem(playerSource, itemName, quantity)
end)

-- --------------------------------------------------------------------------
--  PANHANDLING / WINDSCREEN WASHING PAYOUTS
-- --------------------------------------------------------------------------

local payoutLocks = {}
local PAYOUT_LOCK_MS = 2000

Framework.CreateCallback("bl_dumpsters:server:ClaimStreetEarnings", function(source, cb, holdingPlacard)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return cb(0)
    end

    -- Per-player lock (the original used a single global lock, which let one
    -- player's payout block everybody else's).
    if payoutLocks[playerSource] then
        return cb(1)
    end

    if not GuardRate(playerSource, "street_earnings", PAYOUT_LOCK_MS) then
        return cb(1)
    end

    payoutLocks[playerSource] = true

    local settings = Settings.Panhandling
    local payout = random(1, settings.MaxBasePayout)

    -- The placard bonus only applies if the item is genuinely held, verified server-side.
    if holdingPlacard and GuardInventory(playerSource, "begging_sign", 1) then
        payout = payout * settings.SignBonus
    end

    if player.Job.Name == Settings.VagrantJobName then
        payout = payout * settings.CommittedBonus
    end

    payout = floor(math.min(payout, settings.MaxFinalPayout))

    -- Framework contract — AddMoney is a core API.
    player.AddMoney("cash", payout)

    -- Chapter 3 counts panhandled earnings.
    local identifier = player.Identifier
    local standing = FetchStanding(identifier)

    if standing.level == 3 then
        local chapterState = standing.mission_data[3] or {}
        chapterState.money_collected = (chapterState.money_collected or 0) + payout

        PushChapterProgress(identifier, 3, chapterState)
        Framework.Notify(playerSource, string.format(Settings.Text.panhandle_tracker, chapterState.money_collected, Settings.Chapters[3].TargetEarnings), "info")

        if chapterState.money_collected >= Settings.Chapters[3].TargetEarnings then
            CloseChapter(identifier, 3)
            Framework.Notify(playerSource, Settings.Text.earnings_quota_met, "success")
        end
    end

    TriggerEvent("bl_dumpsters:server:EarningsCollected", playerSource, payout)

    SetTimeout(PAYOUT_LOCK_MS, function()
        payoutLocks[playerSource] = nil
    end)

    cb(payout)
end)

AddEventHandler("playerDropped", function()
    payoutLocks[source] = nil
end)

-- --------------------------------------------------------------------------
--  CHAPTER 6 — PARCEL HAND-IN
-- --------------------------------------------------------------------------

Framework.CreateCallback("bl_dumpsters:server:HandOverParcel", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb(false, Settings.Text.profile_not_found)
    end

    if not GuardRate(source, "hand_parcel", 2000) then
        return cb(false, Settings.Text.no_parcel_carried)
    end

    if not GuardInventory(source, "medical_care_package", 1) then
        return cb(false, Settings.Text.no_parcel_carried)
    end

    Framework.RemoveItem(source, "medical_care_package", 1)

    local identifier = player.Identifier
    local standing = FetchStanding(identifier)

    if standing.level ~= 6 then
        return cb(true, Settings.Text.parcel_delivered)
    end

    local chapterState = standing.mission_data[6] or {}
    chapterState.package_delivered = true
    PushChapterProgress(identifier, 6, chapterState)

    local searched = chapterState.dumpsters_searched or 0

    if searched >= Settings.Chapters[6].TargetContainers and chapterState.package_found then
        CloseChapter(identifier, 6)
        return cb(true, Settings.Text.parcel_delivered_final)
    end

    cb(true, Settings.Text.parcel_delivered)
end)
