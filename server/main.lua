-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Helpers.registerCallback("esx_report:server:getInitData", function(source)
	return {
		serverData = Helpers.getServerData(),
	}
end)

Helpers.registerCallback("esx_report:server:canOpen", function(source)
	if not Helpers.hasPermission(source) then
		return { success = false, err = "Insufficient Permissions." }
	end

	return {
		success = true,
		serverData = Helpers.getServerData(),
	}
end)

Helpers.registerCallback("esx_report:server:openDashboard", function(source)
	if not Helpers.hasPermission(source) then
		return { success = false, err = "Insufficient Permissions." }
	end

	return {
		success = true,
		serverData = Helpers.getServerData(),
	}
end)
