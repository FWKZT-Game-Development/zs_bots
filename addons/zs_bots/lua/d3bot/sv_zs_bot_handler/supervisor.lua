local roundStartTime = CurTime()
hook.Add("PreRestartRound", D3bot.BotHooksId.."PreRestartRoundSupervisor", function() roundStartTime, D3bot.NodeZombiesCountAddition = CurTime(), nil end)

local math_Clamp = math.Clamp
local math_max = math.max
local math_ceil = math.ceil
local table_insert = table.insert
local table_sort = table.sort

hook.Add( "OnPlayerChangedTeam", "D3Bot.OnPlayerChangedTeam.483", function(pl, oldteam, newteam)
	if newteam == TEAM_UNDEAD then
		if D3bot and D3bot.IsEnabled then
			local allowedTotal = game.MaxPlayers() - 2
			if not pl:IsBot() then
				if not GAMEMODE.RoundEnded then
					if GAMEMODE:GetWave() > 0 then
						D3bot.ZombiesCountAddition = math.Clamp( D3bot.ZombiesCountAddition + 1, 0, allowedTotal )
					end
				end
			end
		end
	elseif newteam == TEAM_HUMAN then
		if D3bot and D3bot.IsEnabled then
			local allowedTotal = game.MaxPlayers() - 2
			if not pl:IsBot() then
				if not GAMEMODE.RoundEnded then
					if GAMEMODE:GetWave() > 0 then
						D3bot.ZombiesCountAddition = math.Clamp( D3bot.ZombiesCountAddition - 1, 0, allowedTotal )
					end
				end
			end
		end
	end
end )

local WaveZombieMultiplier = 0.09
local WaveModifiers = {}

--Todo: Setup a system for objective maps to add bots over time at certain intervals.
--local ObjectiveZombieMultiplier = 0.09
--local ObjectiveModifiers = {}

function D3bot.GetDesiredStartingZombies(wave)
	
	if not GAMEMODE.Objective and not GAMEMODE.ZombieEscape then
		--create our table and populate it with our percentages.
		if table.IsEmpty( WaveModifiers ) then
			for i = 1, GAMEMODE:GetNumberOfWaves() do
				if i == 1 then
					WaveModifiers[i] = WaveZombieMultiplier * GAMEMODE.WaveOneZombies
				else
					WaveModifiers[i] = WaveZombieMultiplier * i
				end
			end
		end
	--[[elseif GAMEMODE.Objective then
		if table.IsEmpty( ObjectiveModifiers ) then
			for i = 1, GAMEMODE:GetNumberOfWaves() do
				ObjectiveModifiers[i] = ObjectiveZombieMultiplier * i
			end
		end]]
	end
	
	local numplayers = #player.GetAllActive()
	local maxplayers = game.MaxPlayers() - #player.GetHumans()
	
	return math.Clamp( math.ceil( numplayers * WaveModifiers[wave] ), 1, maxplayers )
end

local function GetPropZombieCount()
	if #player.GetAllActive() <= 1 then return 0 end
	
	return D3bot.GetDesiredStartingZombies( GAMEMODE:GetWave() )
end

function D3bot.GetDesiredBotCount()
	local allowedTotal = game.MaxPlayers() - 2
	local zombiesCount = D3bot.ZombiesCountAddition 
	local human_team = team.GetPlayers( TEAM_HUMAN )
	local wave = GAMEMODE:GetWave()
	local max_wave = GAMEMODE:GetNumberOfWaves()
	
	if wave < 2 then
		zombiesCount = zombiesCount + #GAMEMODE.ZombieVolunteers
	else
		zombiesCount = zombiesCount + GetPropZombieCount()
	end
	
	return zombiesCount, allowedTotal
end

local spawnAsTeam
hook.Add("PlayerInitialSpawn", D3bot.BotHooksId, function(pl)
	if pl:IsBot() and spawnAsTeam == TEAM_UNDEAD then
		GAMEMODE.PreviouslyDied[pl:UniqueID()] = CurTime()
		GAMEMODE:PlayerInitialSpawn(pl)
	elseif not pl:IsBot() and pl:Team() == TEAM_UNDEAD and GAMEMODE.StoredUndeadFrags[pl:UniqueID()] then
		if D3bot and D3bot.IsEnabled then
			local allowedTotal = game.MaxPlayers() - 2
			if not GAMEMODE.RoundEnded then
				if GAMEMODE:GetWave() > 0 then
					D3bot.ZombiesCountAddition = math.Clamp( D3bot.ZombiesCountAddition - 1, 0, allowedTotal )
				end
			end
		end
	end
end)

function D3bot.MaintainBotRoles()
	if #player.GetHumans() == 0 then return end

	local desiredCountByTeam = {}
	local allowedTotal

	desiredCountByTeam[TEAM_UNDEAD], allowedTotal = D3bot.GetDesiredBotCount()

	local bots = player.GetBots()
	local botsByTeam = {}
	for k, v in ipairs(bots) do
		local team = v:Team()
		botsByTeam[team] = botsByTeam[team] or {}
		table_insert(botsByTeam[team], v)
	end

	local players = player.GetAll()
	local playersByTeam = {}
	for k, v in ipairs(players) do
		local team = v:Team()
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
	if player.GetCount() < allowedTotal then
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
	if player.GetCount() > allowedTotal then
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
	if not GAMEMODE.HvH then
		if (NextNodeDamage or 0) < CurTime() then
			NextNodeDamage = CurTime() + 2
			D3bot.DoNodeTrigger()
		end
	end
end

function D3bot.DoNodeTrigger()
	local players = D3bot.RemoveObsDeadTgts(player.GetAll())
	players = D3bot.From(players):Where(function(k, v) return v:Team() ~= TEAM_UNDEAD end).R
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