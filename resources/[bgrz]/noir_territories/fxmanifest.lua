fx_version 'cerulean'
game 'gta5'

name 'noir_territories'
author 'Noir State'
description 'Áreas de gang: alertas por zona do Zone Manager e domínio por influência'
version '1.5.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    -- A influência carrega antes das áreas: é ela que decide o domínio, e `shared/claims.lua`
    -- só junta o resultado com as tags na resposta.
    'shared/influence.lua',
    -- Depois da influência, antes das áreas: a placa se decide a partir dos pontos, e
    -- `shared/claims.lua` junta as duas coisas na resposta.
    'shared/ownership.lua',
    'shared/claims.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client/main.lua',
    'client/claims.lua',
    'client/influence.lua',
    'client/ownership.lua',
    'client/admin.lua',
    'client/zones.lua',
    'client/map.lua',
}

ui_page 'web/map.html'

files {
    'web/map.html',
    'web/leaflet.js',
    'web/leaflet.css',
    'web/tiles/**/*.png',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    -- Antes das áreas: o graffiti concede influência assim que uma tag nasce, e quem concede
    -- precisa estar de pé antes de quem chama.
    'server/influence.lua',
    'server/ownership.lua',
    'server/claims.lua',
    'server/zones.lua',
    -- Por último: os comandos de administração usam todo o resto.
    'server/admin.lua',
}

-- `oxmysql` entra como dependência dura porque a influência é persistida: sem banco o
-- resource subiria, aceitaria pontos e os perderia no restart seguinte, em silêncio. Falhar no
-- start é melhor do que descobrir isso no fim da semana.
dependencies {
    'qbx_core',
    'bgrz_core',
    'ox_lib',
    'oxmysql',
    'zonemanager',
}
