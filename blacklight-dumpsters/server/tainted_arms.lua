--[[ ==========================================================================
     BlackLight Dumpsters — Tainted Armament Cures (server)
     Registers every configured cure item as usable.
========================================================================== ]]

CreateThread(function()
    local registered = {}

    for _, armament in pairs(Settings.TaintedArms) do
        local cureItem = armament.cureItem

        -- Two armaments may legitimately share a cure — only register it once.
        if cureItem and not registered[cureItem] then
            registered[cureItem] = true

            Framework.CreateUseableItem(cureItem, function(source)
                if not GuardRate(source, "use_cure", 1000) then
                    return
                end

                if not GuardInventory(source, cureItem, 1) then
                    return
                end

                if Framework.RemoveItem(source, cureItem, 1) then
                    TriggerClientEvent("bl_dumpsters:client:AdministerCure", source, cureItem)
                end
            end)
        end
    end
end)
