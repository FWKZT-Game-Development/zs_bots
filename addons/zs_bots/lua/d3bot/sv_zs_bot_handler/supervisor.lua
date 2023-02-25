local roundStartTime = CurTime()
local D3bot = D3bot

hook.Add("PreRestartRound", D3bot.BotHooksId.."PreRestartRoundSupervisor", function()
	roundStartTime, D3bot.NodeZombiesCountAddition = CurTime(), nil 
	D3bot.ZombiesCountAddition = 0
	GAMEMODE.ShouldPopBlock = false
end)

local game_GetWorld = game.GetWorld
local game_MaxPlayers = game.MaxPlayers
local player_CreateNextBot = player.CreateNextBot
local player_GetAll = player.GetAll
local player_GetCount = player.GetCount
local player_GetAllActive = player.GetAllActive
local player_GetHumans = player.GetHumans
local team_NumPlayers = team.NumPlayers

local M_Player = FindMetaTable("Player")
local P_Team = M_Player.Team

local math_Clamp = math.Clamp
local math_max = math.max
local math_min = math.min
local math_ceil = math.ceil

local table_insert = table.insert
local table_sort = table.sort
local table_remove = table.remove
local table_add = table.Add

local TEAM_UNDEAD = TEAM_UNDEAD
local TEAM_HUMAN = TEAM_HUMAN

--[[local humans_dead = 0
hook.Add("DoPlayerDeath","D3Bot.AddHumansDied.Supervisor", function(pl, attacker, dmginfo)
	if pl:Team() ~= TEAM_HUMAN or pl:IsBot() or GAMEMODE.RoundEnded or GAMEMODE:GetWave() <= 1 then return end

	humans_dead = humans_dead + 1
end)

hook.Add("PostPlayerRedeemed","D3Bot.PostPlayerRedeemed.Supervisor", function(pl, silent, noequip)
	if GAMEMODE.RoundEnded or GAMEMODE:GetWave() <= 1 then return end

	humans_dead = math.max(humans_dead - 1, 0)
end)

hook.Add("PostEndRound", "D3Bot.ResetHumansDead.Supervisor", function(winnerteam)
	humans_dead = 0
end)]]

function D3bot.GetDesiredBotCount()
	local allowedTotal = game_MaxPlayers() -2
	local volunteers = GAMEMODE:GetDesiredStartingZombies() --* 1.11
	local botmod = D3bot.ZombiesCountAddition

	--Override if wanted for events or extreme lag.
	if GAMEMODE.ShouldPopBlock then
		return botmod, allowedTotal
	end

	-- One bot per wave unless volunteers is higher (for low pop)
	--return math.max(GAMEMODE:GetWave(), 1) - 1 + volunteers + humans_dead + botmod, allowedTotal
	return volunteers + botmod, allowedTotal
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

	if team_NumPlayers(TEAM_UNDEAD) < D3bot.GetDesiredBotCount() then
		local bot = player_CreateNextBot(D3bot.GetUsername() or "BOT")
		
		spawnAsTeam = TEAM_UNDEAD

		if IsValid(bot) then
			bot:D3bot_InitializeOrReset()

			table_insert(D3bot.BotZombies, bot)

			if GAMEMODE:GetWave() <= 1 then
				bot:Kill()
			end
		end

		spawnAsTeam = nil
		
		return
	end
	if team_NumPlayers(TEAM_UNDEAD) > D3bot.GetDesiredBotCount() then
		for i=1, team_NumPlayers(TEAM_UNDEAD)-D3bot.GetDesiredBotCount() do
			if #D3bot.BotZombies > 0 then
				local randomBot = table_remove(D3bot.BotZombies, 1)
				if IsValid(randomBot) then
					randomBot:StripWeapons()
				end
				return randomBot and ( randomBot:IsValid() and randomBot:Kick(D3bot.BotKickReason) )
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
	--[[if game.GetMap() == "gm_construct" then return end
	if (NextNodeDamage or 0) < CurTime() then
		NextNodeDamage = CurTime() + 2
		D3bot.DoNodeTrigger()
	end]]
end

function D3bot.DoNodeTrigger()
	local players = D3bot.RemoveObsDeadTgts(player_GetAll())
	players = D3bot.From(players):Where(function(k, v) return P_Team(v) ~= TEAM_UNDEAD end).R
	local ents = table_add(players, D3bot.GetEntsOfClss(D3bot.NodeDamageEnts))
	for i, ent in pairs(ents) do
		local nodeOrNil = D3bot.MapNavMesh:GetNearestNodeOrNil(ent:GetPos()) -- TODO: Don't call GetNearestNodeOrNil that often
		if nodeOrNil then
			if type(nodeOrNil.Params.DMGPerSecond) == "number" and nodeOrNil.Params.DMGPerSecond > 0 then
				ent:TakeDamage(nodeOrNil.Params.DMGPerSecond*2, game_GetWorld(), game_GetWorld())
			end
			if ent:IsPlayer() and not ent.D3bot_Mem and nodeOrNil.Params.BotMod then
				D3bot.NodeZombiesCountAddition = nodeOrNil.Params.BotMod
			end
		end
	end
end
-- TODO: Detect situations and coordinate bots accordingly (Attacking cades, hunt down runners, spawncamping prevention)
-- TODO: If needed force one bot to flesh creeper and let him build a nest at a good place
