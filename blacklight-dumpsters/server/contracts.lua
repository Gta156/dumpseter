--[[ ==========================================================================
     BlackLight Dumpsters — Corner Grinder Contracts (server)
========================================================================== ]]

LiveContracts = {}
local contractLedger = {}

--- Guarantees both per-player tables exist.
local function EnsureContractTables(identifier)
    LiveContracts[identifier] = LiveContracts[identifier] or {}
    contractLedger[identifier] = contractLedger[identifier] or {}
end

--- Is the given contract currently in progress for this scavenger?
function IsContractLive(identifier, contractType)
    if not identifier or not contractType then
        return false
    end

    EnsureContractTables(identifier)
    return LiveContracts[identifier][contractType] ~= nil
end

--- Looks up a contract definition by its type key.
local function FindContractDefinition(contractType)
    for _, definition in ipairs(Settings.Chapters[10].Contracts) do
        if definition.type == contractType then
            return definition
        end
    end
    return nil
end

-- --------------------------------------------------------------------------
--  LIFECYCLE
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:server:AcceptContract", function(contractType)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    if not GuardRate(playerSource, "accept_contract", 1000) then
        return
    end

    local identifier = player.Identifier
    EnsureContractTables(identifier)

    if IsContractLive(identifier, contractType) then
        Framework.Notify(playerSource, Settings.Text.contract_duplicate, "error")
        return
    end

    local definition = FindContractDefinition(contractType)
    if not definition then
        Framework.Notify(playerSource, Settings.Text.contract_missing, "error")
        return
    end

    -- Rank gate is enforced server-side, not just hidden in the UI.
    local standing = FetchStanding(identifier)
    if definition.rank and standing.level < definition.rank then
        Framework.Notify(playerSource, Settings.Text.grinder_rank_required, "error")
        return
    end

    LiveContracts[identifier][contractType] = {
        progress = 0,
        currencyReward = definition.currencyReward,
        target = definition.target,
        startedAt = os.time(),
    }

    TriggerClientEvent("bl_dumpsters:client:ContractAccepted", playerSource, contractType, definition.target)
    Framework.Notify(playerSource, string.format(Settings.Text.contract_accepted, definition.name), "success")
end)

--- Pays out a fulfilled contract and files it in the ledger.
function FulfilContract(playerSource, contractType)
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    local identifier = player.Identifier
    if not IsContractLive(identifier, contractType) then
        return
    end

    local reward = LiveContracts[identifier][contractType].currencyReward or 0

    if reward > 0 then
        Framework.AddItem(playerSource, Settings.CurrencyItem or "bottle_cap", reward)
    end

    contractLedger[identifier][contractType] = {
        timestamp = os.time(),
        currencyReward = reward,
    }

    LiveContracts[identifier][contractType] = nil
    TriggerClientEvent("bl_dumpsters:client:ContractFulfilled", playerSource, contractType, reward)
end

--- Sets absolute progress on a contract and completes it when the target is met.
function SetContractProgress(playerSource, contractType, progress)
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    local identifier = player.Identifier
    EnsureContractTables(identifier)

    -- Auto-open the contract if progress arrives before it was formally accepted.
    if not IsContractLive(identifier, contractType) then
        local definition = FindContractDefinition(contractType)
        if not definition then
            return
        end

        LiveContracts[identifier][contractType] = {
            progress = 0,
            currencyReward = definition.currencyReward,
            target = definition.target,
            startedAt = os.time(),
        }
    end

    local contract = LiveContracts[identifier][contractType]
    contract.progress = progress

    TriggerClientEvent("bl_dumpsters:client:ContractProgress", playerSource, contractType, progress, contract.target)

    if contract.target and progress >= contract.target then
        FulfilContract(playerSource, contractType)
    end
end

--- Adds an increment to a contract's progress.
local function AddContractProgress(playerSource, contractType, amount)
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    local identifier = player.Identifier
    EnsureContractTables(identifier)

    if not IsContractLive(identifier, contractType) then
        return
    end

    SetContractProgress(playerSource, contractType, LiveContracts[identifier][contractType].progress + amount)
end

RegisterNetEvent("bl_dumpsters:server:AbandonContract", function(contractType)
    local playerSource = source
    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    local identifier = player.Identifier
    if not IsContractLive(identifier, contractType) then
        return
    end

    LiveContracts[identifier][contractType] = nil
    Framework.Notify(playerSource, Settings.Text.contract_dropped, "info")
end)

Framework.CreateCallback("bl_dumpsters:server:GetContractLedger", function(source, cb)
    local player = Framework.GetPlayer(source)
    if not player then
        return cb({})
    end

    EnsureContractTables(player.Identifier)
    cb(contractLedger[player.Identifier])
end)

AddEventHandler("playerDropped", function()
    local player = Framework.GetPlayer(source)
    if player then
        LiveContracts[player.Identifier] = nil
    end
end)

-- --------------------------------------------------------------------------
--  PROGRESS FEEDS
-- --------------------------------------------------------------------------

RegisterNetEvent("bl_dumpsters:server:CurrencyCollected", function(playerSource, amount)
    AddContractProgress(playerSource or source, "currency_haul", amount)
end)

RegisterNetEvent("bl_dumpsters:server:EarningsCollected", function(playerSource, amount)
    AddContractProgress(playerSource or source, "panhandle_trial", amount)
end)

--- A derby cup wrapped up — credit the host if they were running that contract.
RegisterNetEvent("bl_dumpsters:server:CupWrapped", function(cupId, entrants, meta)
    local hostSource = meta and meta.hostSource

    if not hostSource then
        if not (ActiveCups and ActiveCups[cupId]) then
            return
        end

        local hostIdentifier = ActiveCups[cupId].hostIdentifier
        for _, playerId in pairs(GetPlayers()) do
            local candidate = Framework.GetPlayer(playerId)
            if candidate and candidate.Identifier == hostIdentifier then
                hostSource = playerId
                break
            end
        end
    end

    if not hostSource then
        return
    end

    local host = Framework.GetPlayer(hostSource)
    if not host then
        return
    end

    local identifier = host.Identifier
    EnsureContractTables(identifier)

    local entrantCount = 0
    for _ in pairs(entrants or {}) do
        entrantCount = entrantCount + 1
    end

    if IsContractLive(identifier, "derby_cup") then
        if entrantCount >= LiveContracts[identifier].derby_cup.target then
            FulfilContract(hostSource, "derby_cup")
        end
        return
    end

    local definition = FindContractDefinition("derby_cup")
    if not definition then
        return
    end

    LiveContracts[identifier].derby_cup = {
        progress = entrantCount,
        currencyReward = definition.currencyReward,
        target = definition.target,
        startedAt = os.time(),
    }

    if entrantCount >= definition.target then
        FulfilContract(hostSource, "derby_cup")
    end
end)

--- A bowling match wrapped up — credit the host if they were running that contract.
RegisterNetEvent("bl_dumpsters:server:MatchWrapped", function(playerSource, _resultData, entrantCount)
    playerSource = playerSource or source

    local player = Framework.GetPlayer(playerSource)
    if not player then
        return
    end

    local identifier = player.Identifier
    EnsureContractTables(identifier)

    if not IsContractLive(identifier, "alley_bowling") then
        return
    end

    if (entrantCount or 0) >= LiveContracts[identifier].alley_bowling.target then
        FulfilContract(playerSource, "alley_bowling")
    end
end)
