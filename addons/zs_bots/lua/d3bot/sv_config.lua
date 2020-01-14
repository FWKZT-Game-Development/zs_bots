D3bot.IsEnabled = engine.ActiveGamemode() == "zombiesurvival" and table.Count(D3bot.MapNavMesh.ItemById) > 0

D3bot.BotSeeTr = {
	mins = Vector(-15, -15, -15),
	maxs = Vector(15, 15, 15),
	mask = MASK_PLAYERSOLID
}
D3bot.NodeBlocking = {
	mins = Vector(-1, -1, -1),
	maxs = Vector(1, 1, 1),
	classes = {func_breakable = true, prop_physics = true, prop_dynamic = true, prop_door_rotating = true, func_door = true, func_physbox = true, func_physbox_multiplayer = true, func_movelinear = true}
}

D3bot.NodeDamageEnts = {"prop_zapper*", "prop_*turret", "prop_arsenalcrate", "prop_resupply", "prop_remantler"}

D3bot.BotAttackDistMin = 100
D3bot.LinkDeathCostRaise = 300
D3bot.BotConsideringDeathCostAntichance = 3
D3bot.BotAngLerpFactor = 0.5
D3bot.BotAttackAngLerpFactor = 0.5--0.5
D3bot.BotAimAngLerpFactor = 0.5
D3bot.BotAimPosVelocityOffshoot = 0.4
D3bot.BotJumpAntichance = 25
D3bot.BotDuckAntichance = 25

-- BotMod, do NOT change this! Must remain 0.
D3bot.ZombiesCountAddition = 0

-- Uncomment the name file you want to use. If you comment out all of the name files, standard names will be used (Bot, Bot(2), Bot(3), ...)
D3bot.BotNameFile = "fwkzt"

D3bot.BotKickReason = "Team Balance"
