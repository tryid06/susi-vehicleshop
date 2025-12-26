local QBCore = exports['qb-core']:GetCoreObject()

local function BuildPhotoList()
    local list = {}

    if Config.Vehicles then
        for _, v in ipairs(Config.Vehicles) do
            if v.model then
                list[#list + 1] = {
                    model = v.model,
                    name  = v.name or v.model
                }
            end
        end
    end

    return list
end

RegisterNetEvent('susi-vehicleshop:studio:requestAll', function()
    local src = source

    if not Config.PhotoStudio or not Config.PhotoStudio.enabled then
        TriggerClientEvent('QBCore:Notify', src, 'Fotoğraf stüdyosu devre dışı.', 'error')
        return
    end

    local list = BuildPhotoList()
    if #list == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Config.Vehicles boş, foto alınamadı.', 'error')
        return
    end

    if GetResourceState('screenshot-basic') ~= 'started' then
        TriggerClientEvent('QBCore:Notify', src, 'screenshot-basic yüklü değil.', 'error')
        return
    end

    TriggerClientEvent('susi-vehicleshop:studio:startClient', src, list, Config.PhotoStudio)
end)

RegisterNetEvent('susi-vehicleshop:studio:capture', function(model)
    local src = source
    if not Config.PhotoStudio or not Config.PhotoStudio.enabled then return end
    if not model or model == '' then return end

    if GetResourceState('screenshot-basic') ~= 'started' then
        return
    end

    local fileName = string.format('cache/susi-veh-%s.jpg', model)

    exports['screenshot-basic']:requestClientScreenshot(src, {
        fileName = fileName,
        encoding = 'jpg',
        quality  = Config.PhotoStudio.quality or 0.85
    }, function(err, data)
        if err then
            print(('[susi-vehicleshop] Screenshot error for %s: %s'):format(model, err))
        else
            print(('[susi-vehicleshop] Screenshot saved for %s at %s'):format(model, data))
        end
    end)
end)
