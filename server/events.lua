-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

AddEventHandler("playerDropped", function()
	local src = source
	if Helpers and Helpers.stopSpectate then
		Helpers.stopSpectate(src)
		local spectators = (Helpers.getSpectators and Helpers.getSpectators()) or {}
		for adminSrc, targetSrc in pairs(spectators) do
			if targetSrc == src then
				TriggerClientEvent("esx_report:client:stopSpectate", adminSrc)
				Helpers.stopSpectate(adminSrc)
			end
		end
	end
end)

AddEventHandler("onResourceStop", function(resource)
	if resource == GetCurrentResourceName() then
		local spectators = (Helpers and Helpers.getSpectators and Helpers.getSpectators()) or {}
		for adminSrc in pairs(spectators) do
			TriggerClientEvent("esx_report:client:stopSpectate", adminSrc)
		end
	end
end)
