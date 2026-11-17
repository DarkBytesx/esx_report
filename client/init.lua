-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local function activeTranslations()
	local locale = Locales[Config.Locale]
	if type(locale) ~= "table" then
		locale = Locales["en"]
	end
	return locale or {}
end

local function requestInitData()
	xLib.callback("esx_report:server:getInitData", false, function(data)
		if not data then
			return
		end

		data.translations = activeTranslations()
		xLib.nui.send({
			action = "initResource",
			data = data,
		})
	end)
end

function RefreshAdminInitData()
	requestInitData()
end

requestInitData()
