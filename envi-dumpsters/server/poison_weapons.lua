CreateThread(function()
    for _, weaponData in pairs(Config.PoisonWeapons) do
        Framework.CreateUseableItem(weaponData.antidoteItem, function(source, item)
            Framework.RemoveItem(source, weaponData.antidoteItem, 1)
            TriggerClientEvent("envi-dumpsters:client:PoisonAntidote", source, weaponData.antidoteItem)
        end)
    end
end)
