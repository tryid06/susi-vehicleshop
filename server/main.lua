local QBCore = exports['qb-core']:GetCoreObject()
local TestDriveBuckets = {}

local function GetVehicleFromConfig(model)
    if not model then return nil end
    for _, v in ipairs(Config.Vehicles or {}) do
        if v.model == model then
            return v
        end
    end
    return nil
end

local function GeneratePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''

    for i = 1, 8 do
        local rand = math.random(1, #chars)
        plate = plate .. chars:sub(rand, rand)
    end

    return plate
end

-- Shop verisi (araç listesi + oyuncu parası)
QBCore.Functions.CreateCallback('susi-vehicleshop:server:getShopData', function(src, cb)
    local Player = QBCore.Functions.GetPlayer(src)
    local money = { cash = 0, bank = 0 }

    if Player then
        money.cash = Player.Functions.GetMoney('cash')
        money.bank = Player.Functions.GetMoney('bank')
    end

    cb(Config.Vehicles or {}, money)
end)
RegisterNetEvent('susi-vehicleshop:server:testDriveEnterInstance', function()
    local src = source
    local bucket = src -- her oyuncu için kendine özel bucket
    TestDriveBuckets[src] = bucket

    SetPlayerRoutingBucket(src, bucket)
    -- Bu dünyada NPC ve trafik olmasın istiyorsan:
    SetRoutingBucketPopulationEnabled(bucket, false)
end)

-- Oyuncuyu yine ana dünyaya (bucket 0) döndür
RegisterNetEvent('susi-vehicleshop:server:testDriveExitInstance', function()
    local src = source
    local bucket = TestDriveBuckets[src]

    if bucket then
        TestDriveBuckets[src] = nil
    end

    SetPlayerRoutingBucket(src, 0)
end)

-- Test aracı da oyuncu ile aynı bucketa alınsın
RegisterNetEvent('susi-vehicleshop:server:testDriveSetVehicleBucket', function(netId)
    local src = source
    local bucket = TestDriveBuckets[src]
    if not bucket then return end

    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 then
        SetEntityRoutingBucket(veh, bucket)
    end
end)

-- Oyuncu çıkarsa temizlik
AddEventHandler('playerDropped', function()
    local src = source
    if TestDriveBuckets[src] then
        TestDriveBuckets[src] = nil
    end
end)
-- Araç satın alma
RegisterNetEvent('susi-vehicleshop:server:buyVehicle', function(model, paymentMethod)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local vehData = GetVehicleFromConfig(model)
    if not vehData then
        TriggerClientEvent('QBCore:Notify', src, 'Bu araç satışta değil.', 'error')
        return
    end

    local price = vehData.price or 0
    if price <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Araç fiyatı hatalı.', 'error')
        return
    end

    local method = (paymentMethod == 'cash') and 'cash' or 'bank'
    local balance = Player.Functions.GetMoney(method)

    if balance < price then
        TriggerClientEvent('QBCore:Notify', src, 'Yetersiz bakiye.', 'error')
        return
    end

    Player.Functions.RemoveMoney(method, price, 'susi-vehicleshop purchase')

    local plate     = GeneratePlate()
    local citizenid = Player.PlayerData.citizenid
    local license   = Player.PlayerData.license
    local hash      = joaat(vehData.model)
    local garage    = Config.DefaultGarage or 'pillboxgarage'

    -- DB kaydı (QBCore standart player_vehicles şeması)
    MySQL.insert('INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, fuel, engine, body, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        license,
        citizenid,
        vehData.model,
        hash,
        json.encode({}), -- boş mods
        plate,
        garage,
        100,
        1000,
        1000,
        0 -- 0 = dışarıda (jg-advancedgarages ile uyumlu)
    })

    TriggerClientEvent('QBCore:Notify', src, ('Araç satın alındı! Plaka: %s'):format(plate), 'success')

    -- İstersen direkt spawn et, istemezsen bu satırı silebilir ve sadece garajdan çektirebilirsin
    TriggerClientEvent('susi-vehicleshop:client:spawnBoughtVehicle', src, vehData.model, plate)
end)
