-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

-- Initiate / migrate the report database schema automatically.

local dbInitialized = false

local function columnExists(tableName, columnName)
	local count = Helpers.safeScalar(
		[[SELECT COUNT(*)
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_SCHEMA = DATABASE()
			AND TABLE_NAME = ?
			AND COLUMN_NAME = ?]],
		{ tableName, columnName }
	)

	return tonumber(count) and tonumber(count) > 0
end

local function ensureReportColumns()
	if not columnExists("admin_reports", "title") then
		Helpers.safeQuery("ALTER TABLE admin_reports ADD COLUMN title VARCHAR(128) NULL", {})
	end

	if not columnExists("admin_reports", "players_snapshot") then
		Helpers.safeQuery("ALTER TABLE admin_reports ADD COLUMN players_snapshot LONGTEXT NULL", {})
	end

	if not columnExists("admin_reports", "staff_snapshot") then
		Helpers.safeQuery("ALTER TABLE admin_reports ADD COLUMN staff_snapshot TEXT NULL", {})
	end
end

local function initDB()
	-- ADMIN REPORTS / TICKETS
	Helpers.safeQuery([[
		CREATE TABLE IF NOT EXISTS admin_reports (
			id INT AUTO_INCREMENT PRIMARY KEY,
			title VARCHAR(128) NULL,
			reporter_identifier VARCHAR(64) NOT NULL,
			reporter_name VARCHAR(64) NOT NULL,
			reporter_source INT NULL,
			target_identifier VARCHAR(64) NULL,
			target_name VARCHAR(64) NULL,
			target_source INT NULL,
			category VARCHAR(32) NOT NULL DEFAULT 'player',
			reason TEXT NOT NULL,
			status VARCHAR(20) NOT NULL DEFAULT 'open',
			claimed_by VARCHAR(64) NULL,
			claimed_name VARCHAR(64) NULL,
			resolution_notes TEXT NULL,
			players_snapshot LONGTEXT NULL,
			staff_snapshot TEXT NULL,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

			INDEX idx_reports_status (status),
			INDEX idx_reports_created (created_at),
			INDEX idx_reports_reporter (reporter_identifier)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
	]])

	-- ADMIN REPORT CHAT MESSAGES
	Helpers.safeQuery([[
		CREATE TABLE IF NOT EXISTS admin_report_messages (
			id INT AUTO_INCREMENT PRIMARY KEY,
			report_id INT NOT NULL,
			sender_identifier VARCHAR(64) NOT NULL,
			sender_name VARCHAR(64) NOT NULL,
			is_staff TINYINT(1) NOT NULL DEFAULT 0,
			message TEXT NOT NULL,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

			INDEX idx_report_msg_report (report_id),
			INDEX idx_report_msg_created (created_at)
		) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
	]])

	ensureReportColumns()
	print("[esx_report] Report database tables/indexes auto-injected & verified!")
end

local function runInit()
	if dbInitialized then
		return
	end

	local ok, err = pcall(initDB)
	if ok then
		dbInitialized = true
	else
		print(("[esx_report] Database initialization error: %s"):format(tostring(err)))
	end
end

-- oxmysql connection ready hook
MySQL.ready(runInit)

-- Resource restart hook
AddEventHandler("onResourceStart", function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end

	runInit()
end)
