fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'susi-vehicleshop'
author 'Susi'
description 'Galeri'
version '1.0.0'

shared_scripts {
    'config.lua',
    'cars.lua'
}

client_scripts {
    'client/main.lua',
    'client/studio.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- OxMySQL kullanıyorsan açık kalsın
    'server/main.lua',
    'server/studio.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/images/*.png',
    'html/images/*.jpg'
}
