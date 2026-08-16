CreateThread(function()
    for _, weaponData in pairs(Config.ToxinWeapons) do
        Framework.CreateUseableItem(weaponData.antidoteItem, function(source, item)
            Framework.RemoveItem(source, weaponData.antidoteItem, 1)
            TriggerClientEvent("bl_scav:client:PoisonAntidote", source, weaponData.antidoteItem)
        end)
    end
end)
