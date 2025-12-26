local QBCore = exports['qb-core']:GetCoreObject()

local studioRunning = false
local studioCam     = nil

local function LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then
        return nil
    end

    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(10)
    end

    if not HasModelLoaded(hash) then
        return nil
    end

    return hash
end

local function CleanupVehicle(veh)
    if veh and DoesEntityExist(veh) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end
end

RegisterNetEvent('susi-vehicleshop:studio:startClient', function(list, studioCfg)
    if studioRunning then
        QBCore.Functions.Notify('Zaten fotoğraf alma işlemi çalışıyor.', 'error')
        return
    end
    studioRunning = true

    CreateThread(function()
        local ped = PlayerPedId()
        local originalCoords  = GetEntityCoords(ped)
        local originalHeading = GetEntityHeading(ped)

        local pos = studioCfg.coords or vector4(-42.47, -1093.8, 26.42, 71.0)

        SetEntityCoords(ped, pos.x, pos.y, pos.z)
        SetEntityHeading(ped, pos.w)
        Wait(500)

        if studioCfg.freezePlayer then
            FreezeEntityPosition(ped, true)
        end

        for i, v in ipairs(list) do
            local model = v.model
            if model and model ~= '' then
                QBCore.Functions.Notify(
                    ('[%d/%d] %s için hazırlık...'):format(i, #list, v.name or model),
                    'primary'
                )

                local hash = LoadModel(model)
                if hash then
                    local veh = CreateVehicle(hash, pos.x, pos.y, pos.z, pos.w, false, false)
                    SetVehicleDirtLevel(veh, 0.0)
                    SetVehicleNumberPlateText(veh, 'PHOTO')
                    SetVehicleOnGroundProperly(veh)
                    SetEntityAsMissionEntity(veh, true, true)
                    SetEntityHeading(veh, pos.w)

                    local camOffset = studioCfg.camOffset or vector3(-6.0, 2.0, 2.0)
                    local camFov    = studioCfg.fov or 50.0

                    if not studioCam then
                        studioCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                        RenderScriptCams(true, true, 500, true, true)
                    end

                    local vehPos = GetEntityCoords(veh)
                    SetCamCoord(studioCam, vehPos.x + camOffset.x, vehPos.y + camOffset.y, vehPos.z + camOffset.z)
                    PointCamAtEntity(studioCam, veh, 0.0, 0.0, 0.0, true)
                    SetCamFov(studioCam, camFov)

                    Wait(studioCfg.settleTime or 800)

                    TriggerServerEvent('susi-vehicleshop:studio:capture', model)

                    Wait(studioCfg.perVehicleDelay or 1600)

                    CleanupVehicle(veh)
                    SetModelAsNoLongerNeeded(hash)
                else
                    QBCore.Functions.Notify(('Model yüklenemedi: %s'):format(model), 'error')
                end
            end
        end

        if studioCam then
            RenderScriptCams(false, true, 500, true, true)
            DestroyCam(studioCam, false)
            studioCam = nil
        end

        if studioCfg.freezePlayer then
            FreezeEntityPosition(ped, false)
        end

        SetEntityCoords(ped, originalCoords)
        SetEntityHeading(ped, originalHeading)

        QBCore.Functions.Notify(
            'Tüm araçlar için screenshot isteği gönderildi (server cache klasörünü kontrol et).',
            'success'
        )

        studioRunning = false
    end)
end)

-- KOMUT: /vehphoto_all (bütün Config.Vehicles için foto)
RegisterCommand('vehphoto_all', function()
    if studioRunning then
        QBCore.Functions.Notify('Zaten fotoğraf alma işlemi çalışıyor.', 'error')
        return
    end

    if not Config.PhotoStudio or not Config.PhotoStudio.enabled then
        QBCore.Functions.Notify('Fotoğraf stüdyosu configde kapalı.', 'error')
        return
    end

    TriggerServerEvent('susi-vehicleshop:studio:requestAll')
end, false)
