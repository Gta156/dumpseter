--[[ ==========================================================================
     BlackLight Dumpsters — Corner Grinder Contract Tracking (client)
========================================================================== ]]

local floor = math.floor

local liveContracts = {}

local TRACKER_TEMPLATES = {
    currency_haul    = Settings.Text.tracker_currency_haul,
    derby_cup        = Settings.Text.tracker_derby_cup,
    panhandle_trial  = Settings.Text.tracker_panhandle_trial,
    alley_bowling    = Settings.Text.tracker_alley_bowling,
}

--- Pushes a progress line to the player for the given contract.
function RenderContractTracker(contractType, progress, target)
    local template = TRACKER_TEMPLATES[contractType]
    if not template then
        return
    end

    local percent = target > 0 and floor((progress / target) * 100) or 0
    Framework.Notify(string.format(template, progress, target, percent), "info")
end

RegisterNetEvent("bl_dumpsters:client:ContractAccepted", function(contractType, target)
    liveContracts[contractType] = { progress = 0, target = target }
    RenderContractTracker(contractType, 0, target)
end)

RegisterNetEvent("bl_dumpsters:client:ContractProgress", function(contractType, progress, target)
    liveContracts[contractType] = { progress = progress, target = target }
    RenderContractTracker(contractType, progress, target)
end)

RegisterNetEvent("bl_dumpsters:client:ContractFulfilled", function(contractType, payout)
    Framework.Notify(string.format(Settings.Text.contract_fulfilled, payout), "success")
    PlaySoundFrontend(-1, "COLLECTED", "HUD_AWARDS", true)
    liveContracts[contractType] = nil
end)

--- Is a specific contract currently in progress?
function IsContractLive(contractType)
    return liveContracts[contractType] ~= nil
end

--- Returns the whole live contract table.
function GetLiveContracts()
    return liveContracts
end

exports("IsContractLive", IsContractLive)
exports("GetLiveContracts", GetLiveContracts)
