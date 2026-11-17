-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

fx_version("cerulean")
game("gta5")
lua54("yes")

author("ESX Framework")
name("esx_report")
description("ESX Report System & Staff Analytics")
version("1.4.0")
legacyversion("1.16.0")

shared_scripts({
	"@esx_lib/imports.lua",
	"@es_extended/imports.lua",
	"@es_extended/locale.lua",
	"locales/*.lua",
	"shared/*.lua",
})

client_scripts({
	"client/actions.lua",
	"client/nui.lua",
	"client/reports.lua",
	"client/init.lua",
})

server_scripts({
	"@oxmysql/lib/MySQL.lua",
	"server/helpers.lua",
	"server/database.lua",
	"server/reports.lua",
	"server/actions.lua",
	"server/commands.lua",
	"server/events.lua",
	"server/main.lua",
})

ui_page("web/dist/index.html")

files({
	"web/dist/index.html",
	"web/dist/**/*",
})

dependencies({
	"esx_lib",
	"es_extended",
	"oxmysql",
})
