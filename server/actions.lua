-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Actions = Actions or {}

local function getTargetId(data)
	if type(data) == "table" then
		return tonumber(data.id or data.playerId or data.targetId)
	end
	return tonumber(data)
end

function Actions.Goto(src, data)
	data = data or {}

	if not Helpers.hasFeaturePermission(src, "playerTeleport") then
		return { success = false, err = "Insufficient Permissions", playerOnline = true }
	end

	local targetId = getTargetId(data)
	if not targetId or not Helpers.isOnline(targetId) then
		return { success = false, playerOnline = false, err = "Player is not online." }
	end

	local admin = ESX.GetPlayerFromId(src)
	local target = ESX.GetPlayerFromId(targetId)

	if not admin or not target then
		return { success = false, playerOnline = target ~= nil, err = "Player data unavailable." }
	end

	admin.setCoords(target.getCoords(true))
	return { success = true, playerOnline = true }
end

Helpers.registerCallback("esx_report:server:goto", function(source, data)
	return Actions.Goto(source, data)
end)

function Actions.Bring(src, data)
	data = data or {}

	if not Helpers.hasFeaturePermission(src, "playerTeleport") then
		return { success = false, err = "Insufficient Permissions", playerOnline = true }
	end

	local targetId = getTargetId(data)
	if not targetId or not Helpers.isOnline(targetId) then
		return { success = false, playerOnline = false, err = "Player is not online." }
	end

	local admin = ESX.GetPlayerFromId(src)
	local target = ESX.GetPlayerFromId(targetId)

	if not admin or not target then
		return { success = false, playerOnline = target ~= nil, err = "Player data unavailable." }
	end

	target.setCoords(admin.getCoords(true))
	return { success = true, playerOnline = true }
end

Helpers.registerCallback("esx_report:server:bring", function(source, data)
	return Actions.Bring(source, data)
end)

function Actions.Spectate(src, data)
	data = data or {}

	if not Helpers.hasFeaturePermission(src, "spectate") then
		return { success = false, err = "Insufficient Permissions", playerOnline = true, isAdmin = false }
	end

	local targetId = getTargetId(data)
	if not targetId or not Helpers.isOnline(targetId) then
		return { success = false, err = "Player Not Online", playerOnline = false, isAdmin = true }
	end

	if targetId == src then
		return { success = false, err = "You cannot spectate yourself.", playerOnline = true, isAdmin = true }
	end

	local targetPed = GetPlayerPed(targetId)
	local targetCoords = GetEntityCoords(targetPed)

	Helpers.stopSpectate(src)
	Helpers.startSpectate(src, targetId)

	return { success = true, playerOnline = true, targetCoords = targetCoords, isAdmin = true }
end

Helpers.registerCallback("esx_report:server:spectate", function(source, data)
	return Actions.Spectate(source, data)
end)

function Actions.StopSpectate(src)
	if not Helpers.hasFeaturePermission(src, "spectate") then
		return { success = false, err = "Insufficient Permissions" }
	end

	Helpers.stopSpectate(src)
	return { success = true }
end

Helpers.registerCallback("esx_report:server:spectate:stop", function(source)
	return Actions.StopSpectate(source)
end)
