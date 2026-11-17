-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

ServerConfig = {
	-- Discord Webhook URL for staff ticket notifications and report logs.
	-- KEPT STRICTLY SERVER-SIDE for security (never exposed to client cache).
	-- You can set this URL here, OR via server.cfg with: set esx_report:webhook "https://discord.com/api/webhooks/..."
	DiscordWebhook = GetConvar("esx_report:webhook", ""),
}
