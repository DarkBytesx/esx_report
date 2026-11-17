-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local allowedPermissions = Helpers.getAllowedPermissions()

-- Staff Dashboard: /reports
ESX.RegisterCommand(
	{ "reports" },
	allowedPermissions,
	function(xPlayer)
		if not xPlayer or xPlayer.source == 0 then
			return
		end

		TriggerClientEvent("esx_report:client:open", xPlayer.source)
	end,
	false,
	{ help = "Open the Staff Reports & Analytics Dashboard" }
)

-- Staff Teleport & Spectate Commands for Quick Actions
ESX.RegisterCommand({ "goto" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Goto(xPlayer.source, { id = args.playerId })
	if not result or not result.success then
		showError((result and result.err) or "Action failed.")
	end
end, false, {
	help = "Teleport to player",
	arguments = {
		{ name = "playerId", help = "Player Server ID", type = "number" },
	},
})

ESX.RegisterCommand({ "bring" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Bring(xPlayer.source, { id = args.playerId })
	if not result or not result.success then
		showError((result and result.err) or "Action failed.")
	end
end, false, {
	help = "Teleport player to you",
	arguments = {
		{ name = "playerId", help = "Player Server ID", type = "number" },
	},
})

ESX.RegisterCommand({ "spectate" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.Spectate(xPlayer.source, { id = args.playerId })
	if not result or not result.success then
		showError((result and result.err) or "Action failed.")
		return
	end

	TriggerClientEvent("esx_report:client:spectate", xPlayer.source, args.playerId, result.targetCoords)
end, false, {
	help = "Spectate player",
	arguments = {
		{ name = "playerId", help = "Player Server ID", type = "number" },
	},
})

ESX.RegisterCommand({ "stopspectate" }, allowedPermissions, function(xPlayer, args, showError)
	local result = Actions.StopSpectate(xPlayer.source)
	if not result or not result.success then
		showError((result and result.err) or "Action failed.")
		return
	end

	TriggerClientEvent("esx_report:client:stopSpectate", xPlayer.source)
end, false, {
	help = "Stop spectating",
})
