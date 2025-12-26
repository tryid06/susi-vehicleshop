Config = Config or {}

Config.UseTarget = true                  -- target istemiyorsan false
Config.Target = 'ox_target'              -- 'qb-target' veya 'ox_target'

Config.DefaultGarage = 'pillboxgarage'   -- jg-advancedgarages ile uyumlu bir garaj ismi seç

Config.ShopPed = {
    model = 'cs_siemonyetarian',
    coords = vector4(-56.95, -1096.6, 26.42, 71.0)
}

Config.TestDrive = {
    enabled  = true,
    duration = 60, -- saniye
    spawn    = vector4(-42.47, -1093.8, 26.42, 71.0)
}

Config.BuySpawn = vector4(-42.47, -1093.8, 26.42, 71.0)

Config.PhotoStudio = {
    enabled         = false,                                      -- kapatmak istersen false
    coords          = vector4(-42.47, -1093.8, 26.42, 71.0),
    camOffset       = vector3(-6.0, 2.0, 2.0),
    fov             = 50.0,
    settleTime      = 800,
    perVehicleDelay = 1600,
    freezePlayer    = true,
    quality         = 0.85
}
Config.Vehicles = Config.Vehicles or {}
