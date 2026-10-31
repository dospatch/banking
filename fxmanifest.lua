fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'bc-banking'
author 'BC-GAMING'
description 'BC-Banking V1 - QBCore ATM banking with modern NUI and transaction history'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config/config.lua',
    'shared/main.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
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
