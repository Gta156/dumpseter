CreateThread(function()
    Framework.LoadModel(-333702667)
end)

AddEventHandler("populationPedCreating", function(x, y, z, model, _)
    if cache.vehicle then
        return
    end

    if not IsEntityVisible(cache.ped) then
        return
    end

    if model == 1462895032 then
        if math.random(1, 100) <= 50 then
            if not HasModelLoaded(-333702667) then
                return
            end

            local ped = CreatePed(0, -333702667, x + 0.2, y, z, 0.0, true, true)
            TaskWanderStandard(ped, 10.0, 10)
            SetPedFleeAttributes(ped, 1, true)

            SetTimeout(120000, function()
                SetPedAsNoLongerNeeded(ped)
            end)

            CancelEvent()
        end
    end
end)
