local QBCore = exports['qb-core']:GetCoreObject()

local TestDriveVehicle    = nil
local TestDriveActive     = false
local TestDriveEndTime    = 0
local TestDriveReturnPos  = nil 


-- ==== SHOP PED + TARGET KURULUMU ====

CreateThread(function()
    local pedCfg = Config.ShopPed
    if not pedCfg or not pedCfg.coords then return end

    local model = pedCfg.model or 'cs_siemonyetarian'
    local coords = pedCfg.coords

    local hash = joaat(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end

    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityHeading(ped, coords.w)
    FreezeEntityPosition(ped, true)

    -- Target
    if Config.UseTarget then
        if Config.Target == 'qb-target' then
            exports['qb-target']:AddBoxZone("susi_vehicleshop", vector3(coords.x, coords.y, coords.z), 1.6, 1.6, {
                name = "susi_vehicleshop",
                heading = coords.w,
                debugPoly = false,
                minZ = coords.z - 1.0,
                maxZ = coords.z + 2.0,
            }, {
                options = {
                    {
                        type = "client",
                        event = "susi-vehicleshop:client:openShop",
                        icon = "fas fa-car",
                        label = "Araç Galerisi"
                    }
                },
                distance = 2.0
            })
        elseif Config.Target == 'ox_target' then
            exports.ox_target:addBoxZone({
                coords = vec3(coords.x, coords.y, coords.z),
                size = vec3(2.0, 2.0, 2.0),
                rotation = coords.w,
                debug = false,
                options = {
                    {
                        name  = 'susi_vehicleshop',
                        event = 'susi-vehicleshop:client:openShop',
                        icon  = 'fa-solid fa-car',
                        label = 'Araç Galerisi',
                        type  = 'client'
                    }
                }
            })
        end
    end
end)

-- Komutla açmak istersen
RegisterCommand('susi_vehicleshop', function()
    TriggerEvent('susi-vehicleshop:client:openShop')
end, false)

-- ==== SHOP AÇMA ====

RegisterNetEvent('susi-vehicleshop:client:openShop', function()
    QBCore.Functions.TriggerCallback('susi-vehicleshop:server:getShopData', function(vehicles, money)
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            vehicles = vehicles or {},
            playerMoney = {
                cash = money and money.cash or 0,
                bank = money and money.bank or 0
            }
        })
    end)
end)

-- ==== NUI CALLBACKS ====

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb('ok')
end)

-- NUI -> test sürüşü başlat
RegisterNUICallback('startTestDrive', function(data, cb)
    cb('ok')
    if not data or not data.model then return end
    StartTestDrive(data.model)
end)

-- NUI -> satın alma isteği
RegisterNUICallback('buyVehicle', function(data, cb)
    cb('ok')
    if not data or not data.model then return end

    local paymentMethod = data.paymentMethod or 'bank'

    -- Güvenlik için price server tarafında Config'ten alınacak; buradaki price'a güvenmeyeceğiz
    TriggerServerEvent('susi-vehicleshop:server:buyVehicle', data.model, paymentMethod)

    -- Odak kapansın
    SetNuiFocus(false, false)
end)

-- ==== TEST SÜRÜŞÜ ====

local function EndTestDrive(reason)
    if not TestDriveActive then return end

    local ped = PlayerPedId()

    -- Aracı temizle
    if TestDriveVehicle and DoesEntityExist(TestDriveVehicle) then
        if IsPedInVehicle(ped, TestDriveVehicle, false) then
            TaskLeaveVehicle(ped, TestDriveVehicle, 0)
            Wait(800)
        end

        SetEntityAsMissionEntity(TestDriveVehicle, true, true)
        DeleteVehicle(TestDriveVehicle)
    end

    -- Oyuncuyu test sürüşünden önceki noktasına ışınla
    if TestDriveReturnPos then
        local pos = TestDriveReturnPos
        SetEntityCoords(ped, pos.x, pos.y, pos.z)
        SetEntityHeading(ped, pos.w or pos.heading or GetEntityHeading(ped))
    end

    TestDriveVehicle   = nil
    TestDriveActive    = false
    TestDriveEndTime   = 0
    TestDriveReturnPos = nil

    local msg   = 'Test sürüşü sona erdi.'
    local state = 'end'

    if reason == 'timeout' then
        msg   = 'Test sürüşü süresi doldu.'
        state = 'timeout'
    elseif reason == 'leftVehicle' then
        msg   = 'Araçtan indiğin için test sürüşü sonlandı.'
        state = 'end'
    end

    QBCore.Functions.Notify(msg, 'primary')

    -- Status badge
    SendNUIMessage({
        action = 'testDriveStatus',
        state  = state
    })

    -- Sayaç overlay'ini kapat
    SendNUIMessage({
        action = 'testDriveTimer',
        state  = 'stop'
    })
end


function StartTestDrive(model)
    if not Config.TestDrive or not Config.TestDrive.enabled then
        QBCore.Functions.Notify('Test sürüşü şu an aktif değil.', 'error')
        return
    end

    if TestDriveActive then
        QBCore.Functions.Notify('Zaten bir test sürüşündesin.', 'error')
        return
    end

    local ped = PlayerPedId()
    local coords = Config.TestDrive.spawn

    -- Oyuncunun mevcut konumunu kaydet (test sonrası buraya dönecek)
    local pc = GetEntityCoords(ped)
    local ph = GetEntityHeading(ped)
    TestDriveReturnPos = vector4(pc.x, pc.y, pc.z, ph)

    -- UI'yi kapat
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    -- Ayrı bir "dünya"ya al
    TriggerServerEvent('susi-vehicleshop:server:testDriveEnterInstance')

    QBCore.Functions.SpawnVehicle(model, function(veh)
        if not veh or not DoesEntityExist(veh) then
            QBCore.Functions.Notify('Araç spawn edilemedi.', 'error')
            -- Sorun olursa ana dünyaya geri al
            TriggerServerEvent('susi-vehicleshop:server:testDriveExitInstance')
            return
        end

        TestDriveVehicle = veh
        TestDriveActive  = true
        TestDriveEndTime = GetGameTimer() + ((Config.TestDrive.duration or 60) * 1000)
        
SendNUIMessage({
    action   = 'testDriveTimer',
    state    = 'start',
    duration = Config.TestDrive.duration or 60
})

        
        SetEntityHeading(veh, coords.w)
        SetVehicleDirtLevel(veh, 0.0)
        SetVehicleNumberPlateText(veh, 'TEST' .. math.random(10, 99))
        SetVehicleEngineOn(veh, true, true, false)
        SetVehicleFuelLevel(veh, 100.0)

        -- Aracı da oyuncunun bucketa taşı
        local netId = NetworkGetNetworkIdFromEntity(veh)
        if netId and netId ~= 0 then
            SetNetworkIdCanMigrate(netId, true)
            TriggerServerEvent('susi-vehicleshop:server:testDriveSetVehicleBucket', netId)
        end

        TaskWarpPedIntoVehicle(ped, veh, -1)
        TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(veh))

        QBCore.Functions.Notify(
            ('Test sürüşü başladı. Süre: %d sn'):format(Config.TestDrive.duration or 60),
            'primary'
        )

        SendNUIMessage({
            action = 'testDriveStatus',
            state  = 'start'
        })

        CreateThread(function()
            while TestDriveActive and TestDriveVehicle and DoesEntityExist(TestDriveVehicle) do
                Wait(500)

                local now = GetGameTimer()
                if now >= TestDriveEndTime then
                    EndTestDrive('timeout')
                    break
                end

                local p = PlayerPedId()
                if not IsPedInVehicle(p, TestDriveVehicle, false) then
                    EndTestDrive('leftVehicle')
                    break
                end
            end
        end)
    end, coords, true)
end


-- ==== SATIN ALINAN ARACI SPAWN ETME ====

RegisterNetEvent('susi-vehicleshop:client:spawnBoughtVehicle', function(model, plate)
    local ped = PlayerPedId()
    local coords = Config.BuySpawn or Config.TestDrive.spawn

    QBCore.Functions.SpawnVehicle(model, function(veh)
        if not veh or not DoesEntityExist(veh) then
            QBCore.Functions.Notify('Satın alınan araç spawn edilemedi (garajdan çekebilirsin).', 'error')
            return
        end

        SetEntityHeading(veh, coords.w)
        SetVehicleDirtLevel(veh, 0.0)
        SetVehicleNumberPlateText(veh, plate or ('PDM' .. math.random(10, 99)))
        SetVehicleEngineOn(veh, true, true, false)
        SetVehicleFuelLevel(veh, 100.0)

        TaskWarpPedIntoVehicle(ped, veh, -1)

        -- Araç anahtarı
        TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(veh))

        local netId = VehToNet(veh)
        pcall(function()
            if exports['jg-advancedgarages'] then
                exports['jg-advancedgarages']:registerVehicleOutside(plate, netId)
            end
        end)

        QBCore.Functions.Notify('Araç teslim edildi. Plaka: ' .. plate, 'success')
    end, coords, true)
end)

RegisterCommand('fixview', function()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    RenderScriptCams(false, true, 0, true, true)
    DestroyAllCams(true)

    if IsScreenFadedOut() then
        DoScreenFadeIn(500)
    end

    ClearTimecycleModifier()

    QBCore.Functions.Notify('Görünüm sıfırlandı. (/fixview)', 'success')
end, false)
