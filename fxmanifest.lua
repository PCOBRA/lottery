fx_version 'cerulean'
game 'gta5'

author 'Pin Cobra'
description 'Xổ Số Theo Thời Gian Thực 60 phút'
version '2.0.0'

lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'oxmysql'
}
