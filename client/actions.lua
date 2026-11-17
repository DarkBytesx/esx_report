-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework

local spectating = false
local escCooldownUntil = 0
local lastCoords = nil

local function restoreSpectatePed()
	local ped = PlayerPedId()
	FreezeEntityPosition(ped, false)
	SetEntityCollision(ped, true, true)
	SetEntityVisible(ped, true, false)
	NetworkSetEntityInvisibleToNetwork(ped, false)
	SetPlayerInvincible(PlayerId(), false)
	SetEntityInvincible(ped, false)

	if lastCoords then
		SetEntityCoords(ped, lastCoords.x, lastCoords.y, lastCoords.z, false, false, false, false)
		lastCoords = nil
	end
end

local function StopSpectate()
	ToggleNUIFocus(true)
	if not spectating then
		return
	end

	local ped = PlayerPedId()
	NetworkSetInSpectatorMode(false, ped)
	restoreSpectatePed()
	spectating = false

	xLib.nui.send({
		action = "stopSpectate",
		data = true,
	})
end

function Spectate(targetId, targetCoords)
	ToggleNUIFocus(false)

	local spectateConfig = (Config.ReportMenu and Config.ReportMenu.Spectate) or {}
	local spectateHeight = spectateConfig.height or 15.0
	local escCooldown = spectateConfig.escCooldown or 5000
	local streamWait = spectateConfig.streamWait or 500

	if spectating then
		StopSpectate()
		Wait(500)
	end

	local myPed = PlayerPedId()
	lastCoords = GetEntityCoords(myPed)

	FreezeEntityPosition(myPed, true)
	SetEntityVisible(myPed, false, false)
	SetEntityCollision(myPed, false, false)
	SetPlayerInvincible(PlayerId(), true)
	NetworkSetEntityInvisibleToNetwork(myPed, true)

	SetEntityCoordsNoOffset(myPed, targetCoords.x, targetCoords.y, targetCoords.z + spectateHeight, false, false, false)

	Wait(streamWait)
	local targetPlayer = GetPlayerFromServerId(targetId)

	if targetPlayer == -1 then
		print("[esx_report] Spectate failed: player not streamed")
		restoreSpectatePed()
		return
	end

	local targetPed = GetPlayerPed(targetPlayer)

	if not DoesEntityExist(targetPed) then
		print("[esx_report] Spectate failed: ped missing")
		restoreSpectatePed()
		return
	end

	spectating = true
	NetworkSetInSpectatorMode(true, targetPed)

	CreateThread(function()
		while spectating do
			Wait(0)

			local currentTarget = GetPlayerFromServerId(targetId)
			if currentTarget == -1 or not DoesEntityExist(GetPlayerPed(currentTarget)) then
				StopSpectate()
				break
			end

			DisableFrontendThisFrame()

			if IsDisabledControlJustPressed(0, 322) and GetGameTimer() >= escCooldownUntil then
				escCooldownUntil = GetGameTimer() + escCooldown

				xLib.callback("esx_report:server:spectate:stop", false, function(res)
					if not res or res.err then
						print("[esx_report]", res and res.err)
						return
					end

					StopSpectate()
				end)
			end
		end
	end)
end

RegisterNetEvent("esx_report:client:spectate", function(targetId, targetCoords)
	Spectate(targetId, targetCoords)
end)

RegisterNetEvent("esx_report:client:stopSpectate", function()
	StopSpectate()
end)

AddEventHandler("onResourceStop", function(resource)
	if resource ~= GetCurrentResourceName() then
		return
	end

	if spectating then
		StopSpectate()
	end

	xLib.nui.focus(false, false, false)
end)
