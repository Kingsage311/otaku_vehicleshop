fx_version "bodacious"
game "gta5"

author "Sojobo#0001"
description "Otaku Vehicle Shop"
version "1.1.0"

ui_page "html/ui.html"

files {
	"html/ui.html",
	"html/ui.css",
	"html/ui.js",
	"html/header.png",
	"version.json"
}

server_scripts {
	--"locales/*.lua",
    '@oxmysql/lib/MySQL.lua', 
	"config.lua",
    'server/server.lua'
}

client_scripts {
	--"locales/*.lua",
	"config.lua",
	"client/utils.lua",
	"client/main.lua"
}

exports {
	"GeneratePlate",
	"getVehicleData"
}

shared_scripts { 
    'config.lua'
}

dependencies {
	'qb-core'
}