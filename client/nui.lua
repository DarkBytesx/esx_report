-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

AdminOpen = false
AdminMode = nil

local function closeAdminUi()
	xLib.nui.focus(false, false, false)
	AdminOpen = false
	AdminMode = nil
	xLib.nui.send({ action = "closeAdmin" })

	CreateThread(function()
		Wait(0)
		xLib.nui.focus(false, false, false)
	end)
end

local function applyAdminFocus(mode)
	AdminOpen = true
	AdminMode = mode
	xLib.nui.focus(true, true, false)
end

function ToggleNUIFocus(bool, mode)
	if not bool then
		closeAdminUi()
		return
	end

	applyAdminFocus(mode or "dashboard")
end

local function refreshInitData()
	if type(RefreshAdminInitData) == "function" then
		RefreshAdminInitData()
	end
end

local function openDashboard(cb)
	xLib.callback("esx_report:server:openDashboard", false, function(res)
		if not res or not res.success then
			local err = (res and res.err) or "You do not have permission to open the dashboard."
			if ESX and ESX.ShowNotification then
				ESX.ShowNotification(err, "error")
			end
			if cb then
				cb({ success = false, err = err })
			end
			return
		end

		refreshInitData()
		ToggleNUIFocus(true, "dashboard")
		xLib.nui.send({
			action = "openAdminDashboard",
			data = {
				serverData = res.serverData,
			},
		})

		if cb then
			cb({ success = true })
		end
	end)

	return xLib.nui.defer
end

function OpenAdminDashboard()
	openDashboard()
end

RegisterNetEvent("esx_report:client:open", function()
	openDashboard()
end)

-- NUI Core Callbacks

xLib.nui.register("openDashboard", function(data, cb)
	return openDashboard(cb)
end)

xLib.nui.register("releaseFocus", function(data, cb)
	ToggleNUIFocus(false)
	return { success = true }
end)

xLib.nui.register("submitReport", function(data, cb)
	xLib.callback("esx_report:server:submitReport", false, function(res)
		cb(res or { success = false, err = "No response from server." })
	end, data)
	return xLib.nui.defer
end)

-- Report Staff Actions
xLib.nui.register("goto", function(data, cb)
	xLib.callback("esx_report:server:goto", false, function(res)
		cb(res or { success = false, err = "Action failed." })
	end, data)
	return xLib.nui.defer
end)

xLib.nui.register("bring", function(data, cb)
	xLib.callback("esx_report:server:bring", false, function(res)
		cb(res or { success = false, err = "Action failed." })
	end, data)
	return xLib.nui.defer
end)

xLib.nui.register("spectate", function(data, cb)
	xLib.callback("esx_report:server:spectate", false, function(res)
		if not res or not res.success or not res.playerOnline then
			cb(res or { success = false, err = "Player not online." })
			return
		end

		cb({ success = true, playerOnline = true })
		Spectate(data.id, res.targetCoords)
	end, data)
	return xLib.nui.defer
end)

-- Report Ticket Management Endpoints
xLib.nui.register("getReports", function(data, cb)
	xLib.callback("esx_report:server:getReports", false, function(res)
		if not res or not res.success then
			cb({ success = false, reports = {}, openCount = 0, onlineStaff = [] })
			return
		end
		cb(res)
	end, data)
	return xLib.nui.defer
end)

xLib.nui.register("report:claim", function(data, cb)
	xLib.callback("esx_report:server:report:claim", false, function(res)
		cb(res or { success = false, err = "Failed to claim report." })
	end, data)
	return xLib.nui.defer
end)

xLib.nui.register("report:unclaim", function(data, cb)
	xLib.callback("esx_report:server:report:unclaim", false, function(res)
		cb(res or { success = false, err = "Failed to unclaim report." })
	end, data)
	return xLib.nui.defer
end)

xLib.nui.register("report:resolve", function(data, cb)
	xLib.callback("esx_report:server:report:resolve", false, function(res)
		cb(res or { success = false, err = "Failed to resolve report." })
	end, data)
	return xLib.nui.defer
end)

xLib.nui.register("report:reply", function(data, cb)
	xLib.callback("esx_report:server:report:reply", false, function(res)
		cb(res or { success = false, err = "Failed to reply to report." })
	end, data)
	return xLib.nui.defer
end)

xLib.nui.register("report:delete", function(data, cb)
	xLib.callback("esx_report:server:report:delete", false, function(res)
		cb(res or { success = false, err = "Failed to delete report." })
	end, data)
	return xLib.nui.defer
end)

xLib.nui.register("getReportMessages", function(data, cb)
	xLib.callback("esx_report:server:getReportMessages", false, function(res)
		cb(res or { success = false, messages = {} })
	end, data)
	return xLib.nui.defer
end)

xLib.nui.register("sendReportMessage", function(data, cb)
	xLib.callback("esx_report:server:sendReportMessage", false, function(res)
		cb(res or { success = false, err = "Failed to send message." })
	end, data)
	return xLib.nui.defer
end)

xLib.nui.register("getReportAnalytics", function(data, cb)
	xLib.callback("esx_report:server:report:getAnalytics", false, function(res)
		cb(res or { success = false, err = "Failed to fetch analytics." })
	end)
	return xLib.nui.defer
end)
