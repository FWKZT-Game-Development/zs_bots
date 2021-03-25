local roundStartTime = CurTime()
hook.Add("PreRestartRound", D3bot.BotHooksId.."PreRestartRoundSupervisor", function()
	roundStartTime, D3bot.NodeZombiesCountAddition = CurTime(), nil 
	D3bot.ZombiesCountAddition = 0
	ShouldPopBlock = false
	
	--Clean up for various entities that get dropped by the bots.
	--[[for _, ent in ipairs( ents.FindByClass('prop_weapon') ) do 
		if ent:GetWeaponType() == 'weapon_zs_crow' then ent:Remove() end 
		if ent:GetWeaponType() == 'weapon_fists' then ent:Remove() end 
	end]]
end)

local player_GetAll = player.GetAll
local player_GetCount = player.GetCount
local player_GetHumans = player.GetHumans
local game_MaxPlayers = game.MaxPlayers
local M_Player = FindMetaTable("Player")
local P_Team = M_Player.Team

local math_Clamp = math.Clamp
local math_max = math.max
local math_min = math.min
local math_ceil = math.ceil
local table_insert = table.insert
local table_sort = table.sort

local WaveZombieMultiplier = 0.10
local WaveZStackAllowed = 5
local ShouldPopBlock = false

--[[hook.Add( "OnPlayerChangedTeam", "D3Bot.OnPlayerChangedTeam.483", function(pl, oldteam, newteam)
	local allowedTotal = game_MaxPlayers() - 2
	if D3bot and D3bot.IsEnabled then
		if not pl:IsBot() then
			if not GAMEMODE.RoundEnded then
				if GAMEMODE:GetWave() > ( not GAMEMODE:IsHvH() and WaveZStackAllowed or 5 ) then
					if newteam == TEAM_HUMAN then
						D3bot.ZombiesCountAddition = math_Clamp( D3bot.ZombiesCountAddition - 1, 0, allowedTotal )
					else
						D3bot.ZombiesCountAddition = math_Clamp( D3bot.ZombiesCountAddition + 1, 0, allowedTotal )
					end
				end
			end
		end
	end
end )]]

--Todo: Setup a system for objective maps to add bots over time at certain intervals.
function D3bot.GetDesiredZombies()
	local humans = #GAMEMODE.HumanPlayers
	local percentage = math.Clamp( WaveZombieMultiplier * GAMEMODE:GetWave(), 0.1, 0.5 )
	
	return math_ceil( humans * percentage )
end

function D3bot.GetDesiredBotCount()
	local allowedTotal = game_MaxPlayers() - 2 --50

	-- Prevent high pop from lagging the shit out of the server.
	--local infl = GAMEMODE:CalculateInfliction()
	if GAMEMODE.ShouldPopBlock --[[or infl >= 0.5]] then
		return 0, 0
	end
	
	-- Balance out low pop zombies.
	if #GAMEMODE.HumanPlayers < 10 and GAMEMODE:GetWave() > 1 then 
		return #GAMEMODE.ZombieVolunteers+D3bot.ZombiesCountAddition, allowedTotal
	end

	if GAMEMODE:GetWave() <= 1 then
		return #GAMEMODE.ZombieVolunteers+D3bot.ZombiesCountAddition, allowedTotal
	else
		if GAMEMODE.ObjectiveMap or GAMEMODE.ZombieEscape then
			return #GAMEMODE.ZombieVolunteers+D3bot.ZombiesCountAddition, allowedTotal
		else
			return D3bot.GetDesiredZombies()+D3bot.ZombiesCountAddition, allowedTotal
		end
	end
	
	return 0, allowedTotal
end

local spawnAsTeam
hook.Add("PlayerInitialSpawn", D3bot.BotHooksId, function(pl)
	local wave = GAMEMODE:GetWave()
	if pl:IsBot() and spawnAsTeam == TEAM_UNDEAD then
		GAMEMODE.PreviouslyDied[pl:UniqueID()] = CurTime()
		GAMEMODE:PlayerInitialSpawn(pl)
	--[[elseif not pl:IsBot() and P_Team(pl) == TEAM_UNDEAD and GAMEMODE.StoredUndeadFrags[pl:UniqueID()] then
		if D3bot and D3bot.IsEnabled then
			local allowedTotal = game_MaxPlayers() - 2
			if not GAMEMODE.RoundEnded then
				if wave > WaveZStackAllowed then
					D3bot.ZombiesCountAddition = math_Clamp( D3bot.ZombiesCountAddition - 1, 0, allowedTotal )
				end
			end
		end]]
	end
end)

function D3bot.MaintainBotRoles()
	if #player_GetHumans() == 0 then return end

	local desiredCountByTeam = {}
	local allowedTotal

	desiredCountByTeam[TEAM_UNDEAD], allowedTotal = D3bot.GetDesiredBotCount()

	local bots = player.GetBots()
	local botsByTeam = {}
	for k, v in ipairs(bots) do
		local team = P_Team(v)
		botsByTeam[team] = botsByTeam[team] or {}
		table_insert(botsByTeam[team], v)
	end

	local players = player.GetAll()
	local playersByTeam = {}
	for k, v in ipairs(players) do
		local team = P_Team(v)
		playersByTeam[team] = playersByTeam[team] or {}
		table_insert(playersByTeam[team], v)
	end

	-- Sort by frags and being boss zombie
	if botsByTeam[TEAM_UNDEAD] then
		table_sort(botsByTeam[TEAM_UNDEAD], function(a, b) return (a:GetZombieClassTable().Boss and 1 or 0) > (b:GetZombieClassTable().Boss and 1 or 0) end)
	end

	for team, botByTeam in pairs(botsByTeam) do
		table_sort(botByTeam, function(a, b) return a:Frags() < b:Frags() end)
	end
	
	-- Add bots out of managed teams to maintain desired counts
	if player_GetCount() < allowedTotal then
		for team, desiredCount in pairs(desiredCountByTeam) do
			if #(playersByTeam[team] or {}) < desiredCount then
				--RunConsoleCommand("bot")
				spawnAsTeam = team
				local bot = player.CreateNextBot(D3bot.GetUsername())
				spawnAsTeam = nil
				if IsValid(bot) then
					bot:D3bot_InitializeOrReset()
				end
				return
			end
		end
	end
	-- Remove bots out of managed teams to maintain desired counts
	for team, desiredCount in pairs(desiredCountByTeam) do
		if #(playersByTeam[team] or {}) > desiredCount and botsByTeam[team] then
			local randomBot = table.remove(botsByTeam[team], 1)
			randomBot:StripWeapons()
			return randomBot and randomBot:Kick(D3bot.BotKickReason)
		end
	end
		
	-- Remove bots out of non managed teams if the server is getting too full
	if player_GetCount() > allowedTotal then
		for team, desiredCount in pairs(desiredCountByTeam) do
			if not desiredCountByTeam[team] and botsByTeam[team] then
				local randomBot = table.remove(botsByTeam[team], 1)
				randomBot:StripWeapons()
				return randomBot and randomBot:Kick(D3bot.BotKickReason)
			end
		end
	end
end

local NextNodeDamage = CurTime()
local NextMaintainBotRoles = CurTime()
function D3bot.SupervisorThinkFunction()
	if NextMaintainBotRoles < CurTime() then
		NextMaintainBotRoles = CurTime() + 1
		D3bot.MaintainBotRoles()
	end
	--if not GAMEMODE:IsHvH() --[[and not game.GetMap() == "gm_construct"]] then
		if (NextNodeDamage or 0) < CurTime() then
			NextNodeDamage = CurTime() + 2
			D3bot.DoNodeTrigger()
		end
	--end
end

function D3bot.DoNodeTrigger()
	local players = D3bot.RemoveObsDeadTgts(player_GetAll())
	players = D3bot.From(players):Where(function(k, v) return P_Team(v) ~= TEAM_UNDEAD end).R
	local ents = table.Add(players, D3bot.GetEntsOfClss(D3bot.NodeDamageEnts))
	for i, ent in pairs(ents) do
		local nodeOrNil = D3bot.MapNavMesh:GetNearestNodeOrNil(ent:GetPos()) -- TODO: Don't call GetNearestNodeOrNil that often
		if nodeOrNil then
			if type(nodeOrNil.Params.DMGPerSecond) == "number" and nodeOrNil.Params.DMGPerSecond > 0 then
				ent:TakeDamage(nodeOrNil.Params.DMGPerSecond*2, game.GetWorld(), game.GetWorld())
			end
			if ent:IsPlayer() and not ent.D3bot_Mem and nodeOrNil.Params.BotMod then
				D3bot.NodeZombiesCountAddition = nodeOrNil.Params.BotMod
			end
		end
	end
end
-- TODO: Detect situations and coordinate bots accordingly (Attacking cades, hunt down runners, spawncamping prevention)
-- TODO: If needed force one bot to flesh creeper and let him build a nest at a good place