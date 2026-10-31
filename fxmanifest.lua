fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bc-banking'
author 'BC-GAMING'
description 'BC-Banking V2 - QBCore personal and business banking, cards and transfers'
version '2.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config/config.lua',
    'shared/main.lua',
    'config/v2.lua'
}

client_scripts {
    'client/main.lua',
    'client/v2.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/v2.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'qb-core',
    'qb-target',
    'oxmysql'
}
