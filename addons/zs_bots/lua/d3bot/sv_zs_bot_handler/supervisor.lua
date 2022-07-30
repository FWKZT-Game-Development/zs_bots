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

--Todo: Setup a system for objective maps to add bots over time at certain intervals.
function D3bot.GetDesiredZombies()
	local humans = #GAMEMODE.HumanPlayers
	local percentage = math_Clamp( WaveZombieMultiplier * GAMEMODE:GetWave(), 0.1, 0.5 )
	
	return math_ceil( humans * percentage )
end

local humans_dead = 0
hook.Add("DoPlayerDeath","D3Bot.AddHumansDied.Supervisor", function(pl, attacker, dmginfo)
	if pl:Team() == TEAM_HUMAN and not pl:IsBot() and GAMEMODE:GetWave() > 2 then
		humans_dead = humans_dead + 1
	end
end)
hook.Add("PostPlayerRedeemed","D3Bot.PostPlayerRedeemed.Supervisor", function(pl, silent, noequip)
	if GAMEMODE:GetWave() > 2 then
		humans_dead = humans_dead - 1
	end
end)

hook.Add("PostEndRound", "D3Bot.ResetHumansDead.Supervisor", function(winnerteam)
	humans_dead = 0
end)

function D3bot.GetDesiredBotCount()
	local allowedTotal = game_MaxPlayers() - 2 --50

	-- Prevent high pop from lagging the shit out of the server.
	--local infl = GAMEMODE:CalculateInfliction()
	if GAMEMODE.ShouldPopBlock --[[or infl >= 0.5]] then
		return 0, 0
	end
	
	local humans = #GAMEMODE.HumanPlayers
	local volunteers = #GAMEMODE.ZombieVolunteers
	local botmod = D3bot.ZombiesCountAddition

	if GAMEMODE:GetWave() <= 1 then
		return volunteers + humans_dead + botmod, allowedTotal
	else
		-- Balance out low pop zombies.
		if humans <= 10 then 
			if GAMEMODE:GetWave() == GAMEMODE:GetNumberOfWaves() then
				return math_max( GAMEMODE:GetWave()+humans, humans + humans_dead) + botmod, allowedTotal
			else
				return math_max( botmod + humans_dead, volunteers + botmod + humans_dead ), allowedTotal
			end
		else
			if GAMEMODE:GetWave() == GAMEMODE:GetNumberOfWaves() then
				return math_max(humans, humans + humans_dead) + botmod, allowedTotal
			else
				return math_max( botmod + humans_dead, volunteers + botmod + humans_dead ), allowedTotal
			end
		end
	end

	return D3bot.GetDesiredZombies() + botmod + humans_dead, allowedTotal
end

local spawnAsTeam
hook.Add("PlayerInitialSpawn", D3bot.BotHooksId, function(pl)
	local wave = GAMEMODE:GetWave()
	if pl:IsBot() and spawnAsTeam == TEAM_UNDEAD then
		GAMEMODE.PreviouslyDied[pl:UniqueID()] = CurTime()
		GAMEMODE:PlayerInitialSpawn(pl)
	end
end)

D3bot.BotZombies = D3bot.BotZombies or {}
function D3bot.MaintainBotRoles()
	if #player_GetHumans() == 0 or GAMEMODE.RoundEnded then return end

	if team.NumPlayers(TEAM_UNDEAD) < D3bot.GetDesiredBotCount() then
		local bot = player.CreateNextBot(D3bot.GetUsername() or "BOT")
		spawnAsTeam = TEAM_UNDEAD
		if IsValid(bot) then
			bot:D3bot_InitializeOrReset()
			table_insert(D3bot.BotZombies,bot)
		end
		if GAMEMODE:GetWave() <= 1 then
			bot:Kill()
		end
		spawnAsTeam = nil
		return
	end
	if team.NumPlayers(TEAM_UNDEAD) > D3bot.GetDesiredBotCount() then
		for i=1, team.NumPlayers(TEAM_UNDEAD)-D3bot.GetDesiredBotCount() do
			if #D3bot.BotZombies > 0 then
				local randomBot = table.remove(D3bot.BotZombies, 1)
				if IsValid(randomBot) then
					randomBot:StripWeapons()
				end
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
	if not game.GetMap() == "gm_construct" then
		if (NextNodeDamage or 0) < CurTime() then
			NextNodeDamage = CurTime() + 2
			D3bot.DoNodeTrigger()
		end
	end
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