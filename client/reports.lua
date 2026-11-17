-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

function HandleReportCommand()
	xLib.callback("esx_report:server:getPlayerActiveReport", false, function(res)
		if res and res.hasActiveReport and res.report then
			-- Player has an existing active ticket -> open their live conversation window!
			ToggleNUIFocus(true, "report")
			xLib.nui.send({
				action = "openPlayerTicketChat",
				data = {
					report = res.report,
					messages = res.messages or {},
				},
			})
		else
			-- No active ticket -> open clean report submission dialog
			ToggleNUIFocus(true, "report")
			xLib.nui.send({
				action = "openReportDialog",
				data = {
					categories = Config.Reports and Config.Reports.Categories or {},
				},
			})
		end
	end)
end

-- Player Report Command: /report (Submit a report or open active ticket chat)
RegisterCommand("report", function()
	HandleReportCommand()
end, false)

TriggerEvent("chat:addSuggestion", "/report", "Submit a player report or open your active ticket chat", {})

-- Admin Reports & Analytics Dashboard: /reports
RegisterCommand("reports", function()
	OpenAdminDashboard()
end, false)

TriggerEvent("chat:addSuggestion", "/reports", "Open the Staff Reports & Analytics Dashboard", {})

if Config.Keybinds and Config.Keybinds.Report and Config.Keybinds.Report ~= "" then
	RegisterKeyMapping("report", "Open Player Report Dialog", "keyboard", Config.Keybinds.Report)
end

if Config.Keybinds and Config.Keybinds.Reports and Config.Keybinds.Reports ~= "" then
	RegisterKeyMapping("reports", "Open Staff Reports Dashboard", "keyboard", Config.Keybinds.Reports)
end

-- Alert staff when a report is submitted
local function onReportAlert(data)
	if not data then return end

	if data.playSound then
		PlaySoundFrontend(-1, "Event_Message_Purple", "GTAO_FM_Events_Soundset", true)
	end

	if ESX and ESX.ShowNotification then
		local titlePart = (data.title and data.title ~= "") and (" - " .. tostring(data.title)) or ""
		local msg = string.format("%s (ID: %s): %s", tostring(data.reporterName), tostring(data.reporterId), tostring(data.reason))
		local notifTitle = string.format("Report #%s%s", tostring(data.id), titlePart)
		ESX.ShowNotification(msg, "warning", 8000, notifTitle)
	end
end
RegisterNetEvent("esx_report:client:reportAlert", onReportAlert)
RegisterNetEvent("esx-adminmenu:client:reportAlert", onReportAlert)

-- Live chat message received
local function onReportMessage(msgData)
	if not msgData then return end
	xLib.nui.send({
		action = "reportChatMessage",
		data = msgData,
	})
end
RegisterNetEvent("esx_report:client:onReportMessage", onReportMessage)
RegisterNetEvent("esx-adminmenu:client:onReportMessage", onReportMessage)

-- Live ticket closed event
local function onReportClosed(data)
	if AdminOpen and AdminMode == "report" then
		ToggleNUIFocus(false)
	end
	xLib.nui.send({
		action = "reportClosed",
		data = data,
	})
end
RegisterNetEvent("esx_report:client:onReportClosed", onReportClosed)
RegisterNetEvent("esx-adminmenu:client:onReportClosed", onReportClosed)

-- Live update event for admin dashboard
local function onReportUpdated()
	if AdminOpen and AdminMode == "dashboard" then
		xLib.nui.send({
			action = "reportUpdated",
		})
	end
end
RegisterNetEvent("esx_report:client:reportUpdated", onReportUpdated)
RegisterNetEvent("esx-adminmenu:client:reportUpdated", onReportUpdated)
