-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

Helpers = {}

local translations = nil
local allowedGroups = {}
local Spectators = {}
local serverStartedAt = os.time()

for group, allowed in pairs(Config.AllowedGroups or {}) do
	if allowed then
		allowedGroups[#allowedGroups + 1] = group
	end
end

function Helpers.safeQuery(query, params)
	local ok, result = pcall(MySQL.query.await, query, params)
	if not ok then
		print(("[esx_report] Database query error: %s"):format(tostring(result)))
		return nil
	end
	return result
end

function Helpers.safeScalar(query, params)
	local ok, result = pcall(MySQL.scalar.await, query, params)
	if not ok then
		print(("[esx_report] Database scalar error: %s"):format(tostring(result)))
		return nil
	end
	return result
end

function Helpers.safeUpdate(query, params)
	local ok, result = pcall(MySQL.update.await, query, params)
	if not ok then
		print(("[esx_report] Database update error: %s"):format(tostring(result)))
		return nil
	end
	return result
end

function Helpers.isCallable(value)
	return type(value) == "function" or (type(value) == "table" and getmetatable(value) and type(getmetatable(value).__call) == "function")
end

function Helpers.registerCallback(name, handler)
	if xLib and xLib.callback and Helpers.isCallable(xLib.callback.register) then
		xLib.callback.register(name, handler)
		return
	end

	if ESX and Helpers.isCallable(ESX.RegisterServerCallback) then
		ESX.RegisterServerCallback(name, function(source, cb, ...)
			local result = handler(source, ...)
			cb(result)
		end)
	end
end

function Helpers.isOnline(source)
	if not source or source == 0 then
		return false
	end
	return GetPlayerName(source) ~= nil
end

function Helpers.getAllowedPermissions()
	return allowedGroups
end

function Helpers.hasPermission(source)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then
		return false
	end
	return Config.AllowedGroups and Config.AllowedGroups[xPlayer.getGroup()] == true
end

function Helpers.hasFeaturePermission(source, feature)
	local xPlayer = ESX.GetPlayerFromId(source)
	if not xPlayer then
		return false
	end

	local group = xPlayer.getGroup()
	local allowed = Config.FeaturePermissions and Config.FeaturePermissions[feature]
	if type(allowed) == "table" then
		return allowed[group] == true
	end
	return Helpers.hasPermission(source)
end

function Helpers.getServerUptimeSeconds()
	return math.max(0, os.time() - serverStartedAt)
end

function Helpers.formatServerUptime(seconds)
	seconds = math.max(0, tonumber(seconds) or 0)
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local minutes = math.floor((seconds % 3600) / 60)

	if days > 0 then
		return string.format("%dd %dh %dm", days, hours, minutes)
	elseif hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	else
		return string.format("%dm", minutes)
	end
end

function Helpers.getServerData()
	local uptimeSeconds = Helpers.getServerUptimeSeconds()
	local maxPlayers = tonumber(GetConvarInt("sv_maxclients", 48)) or 48
	local currentPlayers = #GetPlayers()

	return {
		uptime = uptimeSeconds,
		uptimeFormatted = Helpers.formatServerUptime(uptimeSeconds),
		currentPlayers = currentPlayers,
		maxPlayers = maxPlayers,
	}
end

function Helpers.startSpectate(adminSrc, targetSrc)
	Spectators[adminSrc] = targetSrc
end

function Helpers.stopSpectate(adminSrc)
	Spectators[adminSrc] = nil
end

function Helpers.getSpectators()
	return Spectators
end

function Helpers.getTranslations()
	if not translations then
		translations = {}
		local english = Locales and Locales["en"] or {}
		local active = Locales and Locales[Config.Locale] or english
		for key in pairs(english) do
			local value = active[key]
			translations[key] = (value ~= nil and value ~= "") and value or english[key]
		end
	end
	return translations
end

function Helpers.getTranslation(key)
	if not key then
		return "missing_key"
	end
	if translations == nil then
		Helpers.getTranslations()
	end
	return translations[key] or key
end
