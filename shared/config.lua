-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Config = {}

-- Enables extra debug prints
Config.Debug = false

-- Locale language file
Config.Locale = "en"

-- ESX permission groups allowed to access the Staff Support & Reports Dashboard (/reports)
Config.AllowedGroups = {
	admin = true,
	-- superadmin = true,
	-- mod = true,
}

-- Granular feature permissions for staff actions within reports
Config.FeaturePermissions = {
	reports = {
		admin = true,
	},
	spectate = {
		admin = true,
	},
	playerTeleport = {
		admin = true,
	},
	playerNotify = {
		admin = true,
	},
}

-- Action-to-feature permission mappings for staff buttons (Goto, Bring, Spectate)
Config.PlayerActions = {
	ActionPermissions = {
		["goto"] = "playerTeleport",
		bring = "playerTeleport",
		spectate = "spectate",
	},
}

-- Optional keyboard keymappings (leave nil to disable, or set to e.g. "F9")
Config.Keybinds = {
	Reports = nil, -- Keybind to open Staff Reports & Analytics Dashboard (e.g. "F9")
	Report = nil, -- Keybind to open Player Report Dialog (e.g. "F10")
}

-- Player Reports & Ticket Management Configuration
Config.Reports = {
	Command = "report", -- Player command: /report
	StaffCommand = "reports", -- Staff command: /reports
	Cooldown = 60, -- Seconds between reports from the same player
	MaxOpenReportsPerPlayer = 2, -- Maximum active open tickets a player can hold simultaneously
	NearbyPlayerRadius = 50.0, -- Distance in GTA units (meters) to snapshot nearby players when a report is filed (0 for unlimited)
	PlaySound = true, -- Play audible alert sound when staff receives a report
	Categories = {
		{ id = "player", label = "Player Report" },
		{ id = "rule_break", label = "Rule Break / Griefing" },
		{ id = "bug", label = "Bug / Glitch" },
		{ id = "question", label = "Question / Help" },
		{ id = "other", label = "Other" },
	},
	DiscordWebhook = "", -- Optional Discord webhook URL for report logs
}

-- Camera Spectator Settings (used by Spectate button in ticket header)
Config.ReportMenu = {
	Spectate = {
		height = 15.0,
		escCooldown = 5000,
		streamWait = 500,
	},
}
Config.AdminMenu = Config.ReportMenu
