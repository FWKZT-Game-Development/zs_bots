local roundStartTime = CurTime()
hook.Add("PreRestartRound", D3bot.BotHooksId.."PreRestartRoundSupervisor", function() roundStartTime, D3bot.NodeZombiesCountAddition = CurTime(), nil end)
hook.Add("PreRestartRound", D3bot.BotHooksId.."ResetHumanZombieCount", function() D3bot.ZombiesCountAddition = 0 end)

local player_GetCount = player.GetCount
local player_GetHumans = player.GetHumans
local game_MaxPlayers = game.MaxPlayers
local M_Player = FindMetaTable("Player")
local P_Team = M_Player.Team

local math_Clamp = math.Clamp
local math_max = math.max
local math_ceil = math.ceil
local table_insert = table.insert
local table_sort = table.sort

local WaveModifiers = {}
local WaveZombieMultiplier = 0.10
local WaveZStackAllowed = 5

hook.Add( "OnPlayerChangedTeam", "D3Bot.OnPlayerChangedTeam.483", function(pl, oldteam, newteam)
	local allowedTotal = game_MaxPlayers() - 2
	if D3bot and D3bot.IsEnabled then
		if not pl:IsBot() then
			if not GAMEMODE.RoundEnded then
				if GAMEMODE:GetWave() > ( not GAMEMODE:IsHvH() and WaveZStackAllowed or 5 ) then
					if newteam == TEAM_HUMAN then
						D3bot.ZombiesCountAddition = math.Clamp( D3bot.ZombiesCountAddition - 1, 0, allowedTotal )
					else
						D3bot.ZombiesCountAddition = math.Clamp( D3bot.ZombiesCountAddition + 1, 0, allowedTotal )
					end
				end
			end
		end
	end
end )

--Todo: Setup a system for objective maps to add bots over time at certain intervals.
function D3bot.GetDesiredStartingZombies(wave)
	local numplayers = #player.GetAllActive()
	local maxplayers = game_MaxPlayers() - #player_GetHumans()
	local humans = #player_GetHumans()
	
	if GAMEMODE.ObjectiveMap or GAMEMODE.ZombieEscape then
		return math.Clamp( math.ceil( numplayers * 0.14, 1, maxplayers ) )
	end
	
	--create our table and populate it with our percentages.
	if table.IsEmpty( WaveModifiers ) then
		for i = 1, GAMEMODE:GetNumberOfWaves() do
			if i == 1 then
				WaveModifiers[i] = WaveZombieMultiplier * GAMEMODE.WaveOneZombies 
			else
				--if humans < 10 then
					--WaveModifiers[i] = i + 1
				--else
					WaveModifiers[i] = WaveZombieMultiplier * i
				--end
			end
		end
	end
	
	--[[if humans < 10 then
		if GAMEMODE:GetWave() == 6 then
			return math.Clamp( math.ceil( WaveModifiers[wave] + 3 ), 1, maxplayers )
		end
		return math.Clamp( math.ceil( WaveModifiers[wave] ), 1, maxplayers )
	end]]
	
	return math.Clamp( math.ceil( numplayers * WaveModifiers[wave] ), 1, maxplayers )
end

local function GetPropZombieCount()
	if #player.GetAllActive() == 0 then return 0 end
	--if #player_GetHumans() > 50 then return 0 end

	return D3bot.GetDesiredStartingZombies( GAMEMODE:GetWave() )
end

function D3bot.GetDesiredBotCount()
	local allowedTotal = game.MaxPlayers() - 2 --50
	local zombiesCount = D3bot.ZombiesCountAddition 
	local human_team = team.GetPlayers( TEAM_HUMAN )
	local wave = GAMEMODE:GetWave()
	local max_wave = GAMEMODE:GetNumberOfWaves()
	local zvols = #GAMEMODE.ZombieVolunteers
	
	--[[if #player.GetAllActive() >= 40 then
		return 0, allowedTotal
	end]]
	
	if #player.GetAllActive() < 10 and wave > 1 then return wave+zombiesCount, allowedTotal end
	
	if wave <= 1 then
		zombiesCount = zombiesCount + ( not GAMEMODE:IsHvH() and zvols or zvols * 2 )
	else
		zombiesCount = zombiesCount + GetPropZombieCount()	
	end
	
	return zombiesCount, allowedTotal
end

local spawnAsTeam
hook.Add("PlayerInitialSpawn", D3bot.BotHooksId, function(pl)
	local wave = GAMEMODE:GetWave()
	if pl:IsBot() and spawnAsTeam == TEAM_UNDEAD then
		GAMEMODE.PreviouslyDied[pl:UniqueID()] = CurTime()
		GAMEMODE:PlayerInitialSpawn(pl)
	elseif not pl:IsBot() and P_Team(pl) == TEAM_UNDEAD and GAMEMODE.StoredUndeadFrags[pl:UniqueID()] then
		if D3bot and D3bot.IsEnabled then
			local allowedTotal = game.MaxPlayers() - 2
			if not GAMEMODE.RoundEnded then
				if wave > WaveZStackAllowed then
					D3bot.ZombiesCountAddition = math.Clamp( D3bot.ZombiesCountAddition - 1, 0, allowedTotal )
				end
			end
		end
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
	local players = D3bot.RemoveObsDeadTgts(player.GetAll())
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