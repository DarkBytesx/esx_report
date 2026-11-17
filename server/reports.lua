-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local cooldowns = {}

local function resolvePlayerSource(p)
	if type(p) == "number" then return p end
	if type(p) ~= "table" then return nil end
	if type(p.src) == "number" then return p.src end
	if type(p.source) == "number" then return p.source end
	if type(p.playerId) == "number" then return p.playerId end
	if type(p.getSource) == "function" then
		local ok, s = pcall(p.getSource)
		if ok and type(s) == "number" then return s end
	end
	return nil
end

local function resolvePlayerName(p, src)
	if type(p) == "table" then
		if type(p.name) == "string" and p.name ~= "" then return p.name end
		if type(p.getName) == "function" then
			local ok, n = pcall(p.getName)
			if ok and type(n) == "string" and n ~= "" then return n end
		end
	end
	if src then
		local name = GetPlayerName(src)
		if name and name ~= "" then return name end
	end
	return "Player"
end

local function resolvePlayerGroup(p, src)
	if type(p) == "table" and type(p.getGroup) == "function" then
		local ok, g = pcall(p.getGroup)
		if ok and type(g) == "string" then return g end
	end
	if src then
		local xP = ESX.GetPlayerFromId(src)
		if xP and xP.getGroup then
			local ok, g = pcall(xP.getGroup)
			if ok and type(g) == "string" then return g end
		end
	end
	return "user"
end

local function isStaffMember(src, grp)
	if not src then return false end
	if Helpers.hasPermission(src) then return true end
	if Helpers.hasFeaturePermission(src, "reports") then return true end
	if grp and Config.AllowedGroups and Config.AllowedGroups[grp] == true then return true end
	return false
end

local function sendDiscordWebhook(reportId, title, reporterName, reporterId, targetName, targetId, category, reason)
	local webhook = (ServerConfig and ServerConfig.DiscordWebhook ~= "" and ServerConfig.DiscordWebhook)
		or GetConvar("esx_report:webhook", "")
	if not webhook or webhook == "" then
		return
	end

	local embed = {
		{
			title = string.format("New Report #%d: %s", reportId, title or "No Title"),
			color = 16489220, -- #FB9B04
			fields = {
				{ name = "Title", value = tostring(title or "Report #" .. reportId), inline = false },
				{ name = "Reporter", value = string.format("%s (ID: %s)", reporterName, tostring(reporterId or "Offline")), inline = true },
				{ name = "Target Player", value = targetName and string.format("%s (ID: %s)", targetName, tostring(targetId or "Offline")) or "None", inline = true },
				{ name = "Category", value = tostring(category or "General"), inline = true },
				{ name = "Reason", value = tostring(reason or "No reason provided"), inline = false },
			},
			footer = { text = "ESX Admin Menu - Report System" },
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		},
	}

	PerformHttpRequest(webhook, function(err, text, headers) end, "POST", json.encode({
		username = "Admin Reports",
		embeds = embed,
	}), { ["Content-Type"] = "application/json" })
end

local function triggerClientReportEvent(eventName, target, ...)
	TriggerClientEvent("esx_report:client:" .. eventName, target, ...)
	TriggerClientEvent("esx-adminmenu:client:" .. eventName, target, ...)
end

local function broadcastReportUpdate()
	local xPlayers = ESX.ExtendedPlayers()
	for i = 1, #xPlayers do
		local staff = xPlayers[i]
		local sSrc = resolvePlayerSource(staff)
		if sSrc and isStaffMember(sSrc) then
			triggerClientReportEvent("reportUpdated", sSrc)
		end
	end
end

-- Submit a new report (Called from player NUI)
Helpers.registerCallback("esx_report:server:submitReport", function(source, data)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then
		return { success = false, err = "Invalid player." }
	end

	if not data or type(data) ~= "table" then
		return { success = false, err = "Invalid report data." }
	end

	local reason = type(data.reason) == "string" and data.reason:match("^%s*(.-)%s*$") or ""
	if #reason < 5 then
		return { success = false, err = "Please provide a detailed description (at least 5 characters)." }
	end
	if #reason > 500 then
		return { success = false, err = "Description exceeds maximum length of 500 characters." }
	end

	local category = type(data.category) == "string" and data.category:match("^%s*(.-)%s*$") or "Player Report"
	if category == "" then category = "Player Report" end

	local reporterName = resolvePlayerName(xPlayer, source)
	local title = type(data.title) == "string" and data.title:match("^%s*(.-)%s*$") or ""
	if title == "" then
		title = category .. " from " .. reporterName
	end
	if #title > 120 then
		title = title:sub(1, 120)
	end

	-- Check cooldown
	local identifier = xPlayer.getIdentifier()
	local now = os.time()
	local cooldownTime = tonumber(Config.Reports and Config.Reports.Cooldown) or 60

	if cooldowns[identifier] and now < cooldowns[identifier] then
		local remaining = cooldowns[identifier] - now
		return { success = false, err = string.format("Please wait %d seconds before submitting another report.", remaining) }
	end

	-- Check maximum active reports
	local maxOpen = tonumber(Config.Reports and Config.Reports.MaxOpenReportsPerPlayer) or 2
	local openReportsCount = MySQL.scalar.await([[
		SELECT COUNT(*) FROM admin_reports
		WHERE reporter_identifier = ? AND status IN ('open', 'claimed')
	]], { identifier })

	if openReportsCount and tonumber(openReportsCount) >= maxOpen then
		return { success = false, err = "You already have active open reports. Please wait for staff to assist you." }
	end

	-- Optional target player lookup
	local targetId = tonumber(data.targetId)
	local targetIdentifier = nil
	local targetName = nil
	local targetSource = nil

	if targetId and targetId > 0 then
		local targetPlayer = ESX.GetPlayerFromId(targetId)
		if targetPlayer then
			targetIdentifier = targetPlayer.getIdentifier()
			targetName = resolvePlayerName(targetPlayer, targetId)
			targetSource = targetId
		else
			targetName = string.format("Player #%d (Offline)", targetId)
		end
	end

	-- Snapshot nearby players (within 50m / Config.Reports.NearbyPlayerRadius) and all active staff
	local reporterPed = GetPlayerPed(source)
	local reporterCoords = (reporterPed and reporterPed ~= 0) and GetEntityCoords(reporterPed) or nil
	local maxRadius = (Config.Reports and tonumber(Config.Reports.NearbyPlayerRadius))
	if maxRadius == nil then maxRadius = 50.0 end

	local playersSnapshot = {}
	local staffSnapshot = {}
	local xPlayers = ESX.ExtendedPlayers()

	for i = 1, #xPlayers do
		local p = xPlayers[i]
		local pSrc = resolvePlayerSource(p)
		if pSrc then
			local pName = resolvePlayerName(p, pSrc)
			local pGroup = resolvePlayerGroup(p, pSrc)
			local isStaff = isStaffMember(pSrc, pGroup)

			local dist = nil
			if reporterCoords then
				local pPed = GetPlayerPed(pSrc)
				if pPed and pPed ~= 0 then
					local pCoords = GetEntityCoords(pPed)
					dist = #(reporterCoords - pCoords)
				end
			end

			local pData = {
				id = pSrc,
				name = tostring(pName),
				is_staff = isStaff == true,
				group = tostring(pGroup),
				distance = dist and (math.floor(dist * 10) / 10) or (pSrc == source and 0.0 or nil),
			}

			if isStaff then
				staffSnapshot[#staffSnapshot + 1] = pData
			end

			local includeInSnapshot = false
			if pSrc == source then
				includeInSnapshot = true
			elseif targetId and pSrc == targetId then
				includeInSnapshot = true
			elseif maxRadius <= 0 then
				includeInSnapshot = true
			elseif dist and dist <= maxRadius then
				includeInSnapshot = true
			elseif not reporterCoords then
				includeInSnapshot = true
			end

			if includeInSnapshot then
				playersSnapshot[#playersSnapshot + 1] = pData
			end
		end
	end

	table.sort(playersSnapshot, function(a, b)
		if a.id == source then return true end
		if b.id == source then return false end
		if targetId and a.id == targetId then return true end
		if targetId and b.id == targetId then return false end
		local da = a.distance or 99999
		local db = b.distance or 99999
		return da < db
	end)

	local playersJson = "[]"
	local staffJson = "[]"
	pcall(function()
		playersJson = json.encode(playersSnapshot)
	end)
	pcall(function()
		staffJson = json.encode(staffSnapshot)
	end)

	local insertOk, reportId = pcall(function()
		return MySQL.insert.await([[
			INSERT INTO admin_reports (
				title, reporter_identifier, reporter_name, reporter_source,
				target_identifier, target_name, target_source,
				category, reason, status, players_snapshot, staff_snapshot
			) VALUES (
				:title, :reporter_identifier, :reporter_name, :reporter_source,
				:target_identifier, :target_name, :target_source,
				:category, :reason, 'open', :players_snapshot, :staff_snapshot
			)
		]], {
			title = title,
			reporter_identifier = identifier,
			reporter_name = reporterName,
			reporter_source = source,
			target_identifier = targetIdentifier,
			target_name = targetName,
			target_source = targetSource,
			category = category,
			reason = reason,
			players_snapshot = playersJson,
			staff_snapshot = staffJson,
		})
	end)

	if not insertOk or not reportId then
		print(("[esx_report] Failed to save report to database: %s"):format(tostring(reportId)))
		return { success = false, err = "Failed to save report to database." }
	end

	-- Also insert the initial reason as the first chat message in the conversation
	pcall(function()
		MySQL.insert.await([[
			INSERT INTO admin_report_messages (report_id, sender_identifier, sender_name, is_staff, message)
			VALUES (?, ?, ?, 0, ?)
		]], { reportId, identifier, reporterName, reason })
	end)

	cooldowns[identifier] = now + cooldownTime

	-- Alert online staff
	local playSound = Config.Reports and Config.Reports.PlaySound ~= false
	for i = 1, #xPlayers do
		local staff = xPlayers[i]
		local sSrc = resolvePlayerSource(staff)
		if sSrc and Helpers.hasFeaturePermission(sSrc, "reports") then
			triggerClientReportEvent("reportAlert", sSrc, {
				id = reportId,
				title = title,
				reporterName = reporterName,
				reporterId = source,
				category = category,
				reason = reason,
				playSound = playSound,
			})
			triggerClientReportEvent("reportUpdated", sSrc)
		end
	end

	-- Send Discord webhook asynchronously
	pcall(sendDiscordWebhook, reportId, title, reporterName, source, targetName, targetId, category, reason)

	return {
		success = true,
		reportId = reportId,
		message = string.format("Your report #%d has been submitted to online staff.", reportId),
	}
end)

-- Fetch reports (Called from admin menu NUI)
Helpers.registerCallback("esx_report:server:getReports", function(source, data)
	if not isStaffMember(source) then
		return { success = false, err = "You do not have permission to view reports." }
	end

	data = data or {}
	local statusFilter = type(data.status) == "string" and data.status or "all"
	local search = type(data.search) == "string" and data.search:match("^%s*(.-)%s*$") or ""
	local limit = tonumber(data.limit) or 50
	if limit > 100 then limit = 100 end

	local query = "SELECT * FROM admin_reports WHERE 1=1"
	local params = {}

	if statusFilter ~= "all" and (statusFilter == "open" or statusFilter == "claimed" or statusFilter == "resolved") then
		query = query .. " AND status = ?"
		params[#params + 1] = statusFilter
	end

	if search ~= "" then
		query = query .. " AND (title LIKE ? OR reporter_name LIKE ? OR target_name LIKE ? OR reason LIKE ? OR id = ?)"
		local wild = "%" .. search .. "%"
		params[#params + 1] = wild
		params[#params + 1] = wild
		params[#params + 1] = wild
		params[#params + 1] = wild
		params[#params + 1] = tonumber(search) or 0
	end

	query = query .. " ORDER BY id DESC LIMIT ?"
	params[#params + 1] = limit

	local rows = MySQL.query.await(query, params) or {}

	-- Enrich with current real-time online status and decode snapshot JSONs
	for i = 1, #rows do
		local row = rows[i]

		if type(row.players_snapshot) == "string" and row.players_snapshot ~= "" then
			local ok, decoded = pcall(json.decode, row.players_snapshot)
			row.players_snapshot = ok and decoded or {}
		end
		if type(row.staff_snapshot) == "string" and row.staff_snapshot ~= "" then
			local ok, decoded = pcall(json.decode, row.staff_snapshot)
			row.staff_snapshot = ok and decoded or {}
		end

		local repPlayer = ESX.GetPlayerFromIdentifier(row.reporter_identifier)
		if repPlayer then
			row.reporter_online = true
			row.reporter_current_source = repPlayer.source
		else
			row.reporter_online = false
			row.reporter_current_source = nil
		end

		if row.target_identifier and row.target_identifier ~= "" then
			local tgtPlayer = ESX.GetPlayerFromIdentifier(row.target_identifier)
			if tgtPlayer then
				row.target_online = true
				row.target_current_source = tgtPlayer.source
			else
				row.target_online = false
				row.target_current_source = nil
			end
		end
	end

	local openCount = MySQL.scalar.await("SELECT COUNT(*) FROM admin_reports WHERE status = 'open'", {}) or 0

	-- Real-time active staff list
	local onlineStaff = {}
	local xPlayers = ESX.ExtendedPlayers()
	for i = 1, #xPlayers do
		local p = xPlayers[i]
		local pSrc = resolvePlayerSource(p)
		if pSrc then
			local pGroup = resolvePlayerGroup(p, pSrc)
			local isStaff = isStaffMember(pSrc, pGroup)
			if isStaff then
				onlineStaff[#onlineStaff + 1] = {
					id = pSrc,
					name = tostring(resolvePlayerName(p, pSrc)),
					group = tostring(pGroup),
				}
			end
		end
	end

	return {
		success = true,
		reports = rows,
		openCount = tonumber(openCount) or 0,
		onlineStaff = onlineStaff,
	}
end)

-- Claim a report
Helpers.registerCallback("esx_report:server:report:claim", function(source, data)
	if not isStaffMember(source) then
		return { success = false, err = "No permission." }
	end

	local reportId = tonumber(data and data.reportId)
	if not reportId then
		return { success = false, err = "Invalid report ID." }
	end

	local adminPlayer = ESX.GetPlayerFromId(source)
	if not adminPlayer then
		return { success = false, err = "Invalid admin player." }
	end

	local updated = MySQL.update.await([[
		UPDATE admin_reports
		SET status = 'claimed', claimed_by = ?, claimed_name = ?
		WHERE id = ?
	]], { adminPlayer.getIdentifier(), adminPlayer.getName(), reportId })

	if not updated or updated == 0 then
		return { success = false, err = "Failed to claim report." }
	end

	local report = MySQL.single.await("SELECT reporter_identifier FROM admin_reports WHERE id = ?", { reportId })
	if report and report.reporter_identifier then
		local reporter = ESX.GetPlayerFromIdentifier(report.reporter_identifier)
		if reporter then
			TriggerClientEvent("esx:showNotification", reporter.source, string.format("Staff member %s has claimed your report #%d.", adminPlayer.getName(), reportId), "info", 5000, "Report Claimed")
			triggerClientReportEvent("onReportClaimed", reporter.source, {
				reportId = reportId,
				staffName = adminPlayer.getName(),
			})
		end
	end

	if Logs and Logs.record then
		Logs.record({
			actor = adminPlayer.getIdentifier(),
			actorName = adminPlayer.getName(),
			namespace = "reports",
			action = "claim",
			payload = { reportId = reportId },
			success = true,
		})
	end

	broadcastReportUpdate()

	return { success = true }
end)

-- Unclaim a report
Helpers.registerCallback("esx_report:server:report:unclaim", function(source, data)
	if not isStaffMember(source) then
		return { success = false, err = "No permission." }
	end

	local reportId = tonumber(data and data.reportId)
	if not reportId then
		return { success = false, err = "Invalid report ID." }
	end

	MySQL.update.await([[
		UPDATE admin_reports
		SET status = 'open', claimed_by = NULL, claimed_name = NULL
		WHERE id = ?
	]], { reportId })

	broadcastReportUpdate()

	return { success = true }
end)

-- Resolve or close a report (Can be invoked by staff or by the reporter)
Helpers.registerCallback("esx_report:server:report:resolve", function(source, data)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then
		return { success = false, err = "Invalid player." }
	end

	local reportId = tonumber(data and data.reportId)
	if not reportId then
		return { success = false, err = "Invalid report ID." }
	end

	local report = MySQL.single.await("SELECT * FROM admin_reports WHERE id = ?", { reportId })
	if not report then
		return { success = false, err = "Report not found." }
	end

	local isStaff = isStaffMember(source, xPlayer.getGroup())
	local isReporter = (report.reporter_identifier == xPlayer.getIdentifier())

	if not isStaff and not isReporter then
		return { success = false, err = "No permission to close this ticket." }
	end

	local notes = type(data.notes) == "string" and data.notes:match("^%s*(.-)%s*$") or ""
	if notes == "" then
		notes = isReporter and "Closed by player." or "Resolved by staff."
	end

	local staffResolver = isStaff and xPlayer.getName() or nil
	MySQL.update.await([[
		UPDATE admin_reports
		SET status = 'resolved', resolution_notes = ?, claimed_name = IFNULL(?, IFNULL(claimed_name, 'Staff'))
		WHERE id = ?
	]], { notes, staffResolver, reportId })

	-- Notify reporter if staff resolved it
	if isStaff and report.reporter_identifier then
		local reporter = ESX.GetPlayerFromIdentifier(report.reporter_identifier)
		if reporter then
			TriggerClientEvent("esx:showNotification", reporter.source, string.format("Your report #%d has been resolved: %s", reportId, notes), "info", 6000, "Report Resolved")
			triggerClientReportEvent("onReportClosed", reporter.source, { reportId = reportId, notes = notes })
		end
	elseif isReporter then
		TriggerClientEvent("esx:showNotification", source, string.format("You closed report #%d.", reportId), "info", 5000, "Report Closed")
		triggerClientReportEvent("onReportClosed", source, { reportId = reportId, notes = notes })
	end

	if Logs and Logs.record then
		Logs.record({
			actor = xPlayer.getIdentifier(),
			actorName = xPlayer.getName(),
			namespace = "reports",
			action = "resolve",
			payload = { reportId = reportId, notes = notes, closedBy = isStaff and "staff" or "player" },
			success = true,
		})
	end

	broadcastReportUpdate()

	return { success = true }
end)

-- Send a quick reply message to the reporter
Helpers.registerCallback("esx_report:server:report:reply", function(source, data)
	if not isStaffMember(source) then
		return { success = false, err = "No permission." }
	end

	local reportId = tonumber(data and data.reportId)
	local message = type(data.message) == "string" and data.message:match("^%s*(.-)%s*$") or ""

	if not reportId or message == "" then
		return { success = false, err = "Please provide a valid message." }
	end

	local adminPlayer = ESX.GetPlayerFromId(source)
	local staffName = adminPlayer and adminPlayer.getName() or "Staff"

	local report = MySQL.single.await("SELECT reporter_identifier FROM admin_reports WHERE id = ?", { reportId })
	if not report or not report.reporter_identifier then
		return { success = false, err = "Report not found." }
	end

	local reporter = ESX.GetPlayerFromIdentifier(report.reporter_identifier)
	if not reporter then
		return { success = false, err = "The reporter is currently offline." }
	end

	TriggerClientEvent("esx:showNotification", reporter.source, message, "info", 6000, string.format("Staff Reply (%s)", staffName))
	TriggerClientEvent("chat:addMessage", reporter.source, {
		color = { 251, 155, 4 },
		multiline = true,
		args = { string.format("[Report #%d Reply - %s]", reportId, staffName), message }
	})

	return { success = true }
end)

-- Check if player has an active report (open or claimed) and return its details + chat
Helpers.registerCallback("esx_report:server:getPlayerActiveReport", function(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then
		return { success = false, err = "Invalid player." }
	end

	local report = MySQL.single.await([[
		SELECT * FROM admin_reports
		WHERE reporter_identifier = ? AND status IN ('open', 'claimed')
		ORDER BY id DESC LIMIT 1
	]], { xPlayer.getIdentifier() })

	if not report then
		return { success = true, hasActiveReport = false }
	end

	local messages = MySQL.query.await([[
		SELECT * FROM admin_report_messages
		WHERE report_id = ?
		ORDER BY id ASC
	]], { report.id }) or {}

	return {
		success = true,
		hasActiveReport = true,
		report = report,
		messages = messages,
	}
end)

-- Get all messages for a specific report
Helpers.registerCallback("esx_report:server:getReportMessages", function(source, data)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then
		return { success = false, err = "Invalid player." }
	end

	local reportId = tonumber(data and data.reportId)
	if not reportId then
		return { success = false, err = "Invalid report ID." }
	end

	local isStaff = isStaffMember(source, xPlayer.getGroup())
	local report = MySQL.single.await("SELECT * FROM admin_reports WHERE id = ?", { reportId })
	if not report then
		return { success = false, err = "Report not found." }
	end

	if not isStaff and report.reporter_identifier ~= xPlayer.getIdentifier() then
		return { success = false, err = "You do not have permission to view this ticket." }
	end

	local messages = MySQL.query.await([[
		SELECT * FROM admin_report_messages
		WHERE report_id = ?
		ORDER BY id ASC
	]], { reportId }) or {}

	return {
		success = true,
		report = report,
		messages = messages,
	}
end)

-- Send a chat message in a report conversation
Helpers.registerCallback("esx_report:server:sendReportMessage", function(source, data)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then
		return { success = false, err = "Invalid player." }
	end

	local reportId = tonumber(data and data.reportId)
	local message = type(data and data.message) == "string" and data.message:match("^%s*(.-)%s*$") or ""

	if not reportId or message == "" then
		return { success = false, err = "Please provide a valid message." }
	end
	if #message > 500 then
		return { success = false, err = "Message cannot exceed 500 characters." }
	end

	local report = MySQL.single.await("SELECT * FROM admin_reports WHERE id = ?", { reportId })
	if not report then
		return { success = false, err = "Report does not exist." }
	end

	if report.status == "resolved" then
		return { success = false, err = "This ticket has already been closed." }
	end

	local isStaff = isStaffMember(source, xPlayer.getGroup())
	local isReporter = (report.reporter_identifier == xPlayer.getIdentifier())

	if not isStaff and not isReporter then
		return { success = false, err = "You are not authorized to participate in this ticket." }
	end

	local senderName = resolvePlayerName(xPlayer, source)

	-- If staff sends a message on an open ticket, automatically claim it for them
	if isStaff and report.status == "open" then
		MySQL.update.await([[
			UPDATE admin_reports
			SET status = 'claimed', claimed_by = ?, claimed_name = ?
			WHERE id = ?
		]], { xPlayer.getIdentifier(), senderName, reportId })
		report.status = "claimed"
		report.claimed_name = senderName
		report.claimed_by = xPlayer.getIdentifier()
	end

	local insertOk, msgId = pcall(function()
		return MySQL.insert.await([[
			INSERT INTO admin_report_messages (report_id, sender_identifier, sender_name, is_staff, message)
			VALUES (?, ?, ?, ?, ?)
		]], { reportId, xPlayer.getIdentifier(), senderName, isStaff and 1 or 0, message })
	end)

	if not insertOk or not msgId then
		print(("[esx_report] Failed to insert report message: %s"):format(tostring(msgId)))
		return { success = false, err = "Failed to save message to database." }
	end

	local msgData = {
		id = msgId,
		report_id = reportId,
		sender_identifier = xPlayer.getIdentifier(),
		sender_name = senderName,
		is_staff = isStaff and 1 or 0,
		message = message,
		created_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}

	-- Real-time delivery
	if isStaff then
		-- Notify reporter
		local reporter = ESX.GetPlayerFromIdentifier(report.reporter_identifier)
		local repSrc = reporter and resolvePlayerSource(reporter)
		if repSrc then
			triggerClientReportEvent("onReportMessage", repSrc, msgData)
			TriggerClientEvent("esx:showNotification", repSrc, message, "info", 6000, string.format("Staff: %s", senderName))
		end
		-- Also sync to other online staff
		local xPlayers = ESX.ExtendedPlayers()
		for i = 1, #xPlayers do
			local staff = xPlayers[i]
			local sSrc = resolvePlayerSource(staff)
			if sSrc and sSrc ~= source and isStaffMember(sSrc) then
				triggerClientReportEvent("onReportMessage", sSrc, msgData)
			end
		end
	else
		-- Reporter sent message -> Alert online staff
		local xPlayers = ESX.ExtendedPlayers()
		for i = 1, #xPlayers do
			local staff = xPlayers[i]
			local sSrc = resolvePlayerSource(staff)
			if sSrc and isStaffMember(sSrc) then
				triggerClientReportEvent("onReportMessage", sSrc, msgData)
				if sSrc ~= source then
					TriggerClientEvent("esx:showNotification", sSrc, message, "warning", 6000, string.format("Report #%d - %s", reportId, senderName))
				end
			end
		end
	end

	broadcastReportUpdate()

	return {
		success = true,
		message = msgData,
	}
end)

-- Delete a report
Helpers.registerCallback("esx_report:server:report:delete", function(source, data)
	if not isStaffMember(source) then
		return { success = false, err = "No permission." }
	end

	local reportId = tonumber(data and data.reportId)
	if not reportId then
		return { success = false, err = "Invalid report ID." }
	end

	MySQL.update.await("DELETE FROM admin_reports WHERE id = ?", { reportId })
	MySQL.update.await("DELETE FROM admin_report_messages WHERE report_id = ?", { reportId })

	broadcastReportUpdate()

	return { success = true }
end)

-- Ticket & Staff Analytics Callback (Most Active, Most Responses, Most Claims)
Helpers.registerCallback("esx_report:server:report:getAnalytics", function(source)
	if not isStaffMember(source) then
		return { success = false, err = "No permission." }
	end

	local total = MySQL.scalar.await("SELECT COUNT(*) FROM admin_reports") or 0
	local openCount = MySQL.scalar.await("SELECT COUNT(*) FROM admin_reports WHERE status = 'open'") or 0
	local claimedCount = MySQL.scalar.await("SELECT COUNT(*) FROM admin_reports WHERE status = 'claimed'") or 0
	local resolvedCount = MySQL.scalar.await("SELECT COUNT(*) FROM admin_reports WHERE status = 'resolved'") or 0
	local todayCount = MySQL.scalar.await("SELECT COUNT(*) FROM admin_reports WHERE created_at >= CURDATE()") or 0
	local weekCount = MySQL.scalar.await("SELECT COUNT(*) FROM admin_reports WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)") or 0
	local totalMessages = MySQL.scalar.await("SELECT COUNT(*) FROM admin_report_messages") or 0
	local staffMessages = MySQL.scalar.await("SELECT COUNT(*) FROM admin_report_messages WHERE is_staff = 1") or 0

	local resolutionRate = (total > 0) and (math.floor((resolvedCount / total) * 1000) / 10) or 0.0

	-- Top Claimers (Staff who claimed the most reports)
	local topClaimers = MySQL.query.await([[
		SELECT claimed_name AS name, COUNT(*) AS count
		FROM admin_reports
		WHERE claimed_name IS NOT NULL AND claimed_name != ''
		GROUP BY claimed_name
		ORDER BY count DESC
		LIMIT 10
	]]) or {}

	-- Top Responders (Staff who sent the most chat messages to players)
	local topResponders = MySQL.query.await([[
		SELECT sender_name AS name, COUNT(*) AS count
		FROM admin_report_messages
		WHERE is_staff = 1
		GROUP BY sender_name
		ORDER BY count DESC
		LIMIT 10
	]]) or {}

	-- Top Resolvers (Staff who resolved the most tickets)
	local topResolvers = MySQL.query.await([[
		SELECT claimed_name AS name, COUNT(*) AS count
		FROM admin_reports
		WHERE status = 'resolved' AND claimed_name IS NOT NULL AND claimed_name != ''
		GROUP BY claimed_name
		ORDER BY count DESC
		LIMIT 10
	]]) or {}

	-- Category distribution
	local categories = MySQL.query.await([[
		SELECT category, COUNT(*) AS count
		FROM admin_reports
		GROUP BY category
		ORDER BY count DESC
		LIMIT 8
	]]) or {}

	return {
		success = true,
		data = {
			summary = {
				total = total,
				open = openCount,
				claimed = claimedCount,
				resolved = resolvedCount,
				today = todayCount,
				week = weekCount,
				totalMessages = totalMessages,
				staffMessages = staffMessages,
				resolutionRate = resolutionRate,
			},
			topClaimers = topClaimers,
			topResponders = topResponders,
			topResolvers = topResolvers,
			categories = categories,
		}
	}
end)
