
--Use this for HVH later.
--[[if engine.ActiveGamemode() == "zombiesurvival" then
	hook.Add("PlayerSpawn", "!human info", function(pl)
		if not D3bot.IsEnabled or not D3bot.IsSelfRedeemEnabled or pl:Team() ~= TEAM_UNDEAD or LASTHUMAN or GAMEMODE.ZombieEscape or GAMEMODE:GetWave() > D3bot.SelfRedeemWaveMax then return end
		local hint = translate.ClientFormat(pl, "D3bot_redeemwave", D3bot.SelfRedeemWaveMax + 1)
		pl:PrintMessage(HUD_PRINTCENTER, hint)
		pl:ChatPrint(hint)
	end)

	function ulx.giveHumanLoadout(pl)
		pl:Give("weapon_zs_fists")
		pl:Give("weapon_zs_peashooter")
		pl:GiveAmmo(50, "pistol")
	end

	function ulx.tryBringToHumans(pl)
		local potSpawnTgts = team.GetPlayers(TEAM_HUMAN)
		for i = 1, 5 do
			local potSpawnTgtOrNil = table.Random(potSpawnTgts)
			if IsValid(potSpawnTgtOrNil) and not util.TraceHull{
				start = potSpawnTgtOrNil:GetPos(),
				endpos = potSpawnTgtOrNil:GetPos(),
				mins = pl:OBBMins(),
				maxs = pl:OBBMaxs(),
				filter = potSpawnTgts,
				mask = MASK_PLAYERSOLID }.Hit then
				pl:SetPos(potSpawnTgtOrNil:GetPos())
				break
			end
		end
	end

	local nextByPl = {}
	local tierByPl = {}
	function ulx.human(pl)
		if not D3bot.IsEnabled then
			local response = translate.ClientGet(pl, "D3bot_botmapsonly")
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if not D3bot.IsSelfRedeemEnabled then
			local response = translate.ClientGet(pl, "D3bot_selfredeemdisabled")
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if GAMEMODE:GetWave() > D3bot.SelfRedeemWaveMax then
			local response = translate.ClientFormat(pl, "D3bot_toolate", D3bot.SelfRedeemWaveMax + 1)
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if pl:Team() == TEAM_HUMAN then
			local response = translate.ClientGet(pl, "D3bot_alreadyhum")
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		local remainingTime = (nextByPl[pl] or 0) - CurTime()
		if remainingTime > 0 then
			local response = translate.ClientFormat(pl, "D3bot_selfredeemrecenty", math.ceil(remainingTime))
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if LASTHUMAN and not GAMEMODE.RoundEnded then
			local response = translate.ClientGet(pl, "D3bot_noredeemlasthuman")
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		if GAMEMODE.ZombieEscape then
			local response = translate.ClientGet(pl, "D3bot_noredeemzombieescape")
			pl:ChatPrint(response)
			pl:PrintMessage(HUD_PRINTCENTER, response)
			return
		end
		local nextTier = (tierByPl[pl] or 0) + 1
		tierByPl[pl] = nextTier
		local cooldown = nextTier * 30
		nextByPl[pl] = CurTime() + cooldown
		local response = translate.ClientFormat(pl, "D3bot_selfredeemcooldown", math.ceil(cooldown))
		pl:ChatPrint(response)
		pl:PrintMessage(HUD_PRINTCENTER, response)
		pl:ChangeTeam(TEAM_HUMAN)
		pl:SetDeaths(0)
		pl:SetPoints(0)
		pl:DoHulls()
		pl:UnSpectateAndSpawn()
		pl:StripWeapons()
		pl:StripAmmo()
		ulx.giveHumanLoadout(pl)
		ulx.tryBringToHumans(pl)
	end
	local cmd = ulx.command("Zombie Survival", "ulx human", ulx.human, "!human", true)
	cmd:defaultAccess(ULib.ACCESS_ALL)
	cmd:help("If you're a zombie, you can use this command to instantly respawn as a human with a default loadout.")
end]]

local function registerCmd(camelCaseName, access, ...)
	local func
	local params = {}
	for idx, arg in ipairs{ ... } do
		if istable(arg) then
			table.insert(params, arg)
		elseif isfunction(arg) then
			func = arg
			break
		else
			break
		end
	end
	ulx["d3bot" .. camelCaseName] = func
	local cmdStr = (access == ULib.ACCESS_SUPERADMIN and "d3bot " or "") .. camelCaseName:lower()
	local chatStr = (access == ULib.ACCESS_SUPERADMIN and "bot " or "") .. camelCaseName:lower()
	local cmd = ulx.command("D3bot", cmdStr, func, "!" .. chatStr)
	for k, param in pairs(params) do cmd:addParam(param) end
	cmd:defaultAccess(access)
end
local function registerSuperadminCmd(camelCaseName, ...) registerCmd(camelCaseName, ULib.ACCESS_SUPERADMIN, ...) end
local function registerAdminCmd(camelCaseName, ...) registerCmd(camelCaseName, ULib.ACCESS_ADMIN, ...) end

local plsParam = { type = ULib.cmds.PlayersArg }
local numParam = { type = ULib.cmds.NumArg }
local strParam = { type = ULib.cmds.StringArg }
local strRestParam = { type = ULib.cmds.StringArg, ULib.cmds.takeRestOfLine }
local optionalStrParam = { type = ULib.cmds.StringArg, ULib.cmds.optional }

registerAdminCmd("BotMod", numParam, function(caller, num)
	local formerZombiesCountAddition = D3bot.ZombiesCountAddition
	D3bot.ZombiesCountAddition = math.Round(num)
	local function format(num) return "[formula + (" .. num .. ")]" end
	caller:ChatPrint("Zombies count changed from " .. format(formerZombiesCountAddition) .. " to " .. format(D3bot.ZombiesCountAddition) .. ".")
end)

registerSuperadminCmd("ViewMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do D3bot.SetMapNavMeshUiSubscription(pl, "view") end end)
registerSuperadminCmd("EditMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do D3bot.SetMapNavMeshUiSubscription(pl, "edit") end end)
registerSuperadminCmd("HideMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do D3bot.SetMapNavMeshUiSubscription(pl, nil) end end)

registerSuperadminCmd("SaveMesh", function(caller)
	D3bot.SaveMapNavMesh()
	caller:ChatPrint("Saved.")
end)
registerSuperadminCmd("ReloadMesh", function(caller)
	D3bot.LoadMapNavMesh()
	D3bot.UpdateMapNavMeshUiSubscribers()
	caller:ChatPrint("Reloaded.")
end)
registerSuperadminCmd("RefreshMeshView", function(caller)
	D3bot.UpdateMapNavMeshUiSubscribers()
	caller:ChatPrint("Refreshed.")
end)

registerSuperadminCmd("SetParam", strParam, strParam, optionalStrParam, function(caller, id, name, serializedNumOrStrOrEmpty)
	D3bot.TryCatch(function()
		D3bot.MapNavMesh.ItemById[D3bot.DeserializeNavMeshItemId(id)]:SetParam(name, serializedNumOrStrOrEmpty)
		D3bot.lastParamKey = name
		D3bot.lastParamValue = serializedNumOrStrOrEmpty
		D3bot.UpdateMapNavMeshUiSubscribers()
	end, function(errorMsg)
		caller:ChatPrint("Error. Re-check your parameters.")
	end)
end)

registerSuperadminCmd("SetMapParam", strParam, optionalStrParam, function(caller, name, serializedNumOrStrOrEmpty)
	D3bot.TryCatch(function()
		D3bot.MapNavMesh:SetParam(name, serializedNumOrStrOrEmpty)
		D3bot.SaveMapNavMeshParams()
	end, function(errorMsg)
		caller:ChatPrint("Error. Re-check your parameters.")
	end)
end)

registerSuperadminCmd("ViewPath", plsParam, strParam, strParam, function(caller, pls, startNodeId, endNodeId)
	local nodeById = D3bot.MapNavMesh.NodeById
	local startNode = nodeById[D3bot.DeserializeNavMeshItemId(startNodeId)]
	local endNode = nodeById[D3bot.DeserializeNavMeshItemId(endNodeId)]
	if not startNode or not endNode then
		caller:ChatPrint("Not all specified nodes exist.")
		return
	end
	local path = D3bot.GetBestMeshPathOrNil(startNode, endNode)
	if not path then
		caller:ChatPrint("Couldn't find any path for the two specified nodes.")
		return
	end
	for k, pl in pairs(pls) do D3bot.ShowMapNavMeshPath(pl, path) end
end)
registerSuperadminCmd("DebugPath", plsParam, optionalStrParam, function(caller, pls, serializedEntIdxOrEmpty)
	local ent = serializedEntIdxOrEmpty == "" and caller:GetEyeTrace().Entity or Entity(tonumber(serializedEntIdxOrEmpty) or -1)
	if not IsValid(ent) then
		caller:ChatPrint("No entity cursored or invalid entity index specified.")
		return
	end
	caller:ChatPrint("Debugging path from player to " .. tostring(ent) .. ".")
	for k, pl in pairs(pls) do D3bot.ShowMapNavMeshPath(pl, pl, ent) end
end)
registerSuperadminCmd("ResetPath", plsParam, function(caller, pls) for k, pl in pairs(pls) do D3bot.HideMapNavMeshPath(pl) end end)

if engine.ActiveGamemode() == "zombiesurvival" then
	registerAdminCmd("ForceClass", strRestParam, function(caller, className)
		for classKey, class in ipairs(GAMEMODE.ZombieClasses) do
			if class.Name:lower() == className:lower() then
				for _, bot in ipairs(player.GetBots()) do
					if bot:Team() == TEAM_UNDEAD and bot:GetZombieClassTable().Index ~= class.Index then
						bot:Kill()
						bot.DeathClass = class.Index
					end
				end
				break
			end
		end
	end)

	registerSuperadminCmd("Control", plsParam, function(caller, pls) for k, pl in pairs(pls) do pl:D3bot_InitializeOrReset() end end)
	registerSuperadminCmd("SoftControl", plsParam, function(caller, pls) for k, pl in pairs(pls) do pl:D3bot_InitializeOrReset(true) end end)
	registerSuperadminCmd("Uncontrol", plsParam, function(caller, pls) for k, pl in pairs(pls) do pl:D3bot_Deinitialize() end end)
end

-- TODO: Add user command to check the version of D3bot

-- Credits for the ULX fix to C0nw0nk https://github.com/C0nw0nk/Garrys-Mod-Fake-Players/blob/f9561c3f8c3dc06dddedac92dfaf437af21a9d83/addons/fakeplayers/lua/autorun/server/sv_fakeplayers.lua#L217
if (ULib and ULib.bans) then
	--ULX has some strange bug / issue with NextBot's and Player Authentication.
	--[[
	[ERROR] Unauthed player
	  1. query - [C]:-1
	   2. fn - addons/ulx-v3_70/lua/ulx/modules/slots.lua:44
		3. unknown - addons/ulib-v2_60/lua/ulib/shared/hook.lua:110
	]]
	--Fix above error by adding acception for bots to the ulxSlotsDisconnect hook.
	hook.Add("PlayerDisconnected", "ulxSlotsDisconnect", function(ply)
		--If player is bot.
		if ply:IsBot() then
			--Do nothing.
			return
		end
	end)
end
