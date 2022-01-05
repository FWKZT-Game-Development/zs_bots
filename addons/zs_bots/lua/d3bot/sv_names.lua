D3bot.Names = {}

if D3bot.BotNameFile then
	include("names/"..D3bot.BotNameFile..".lua")
end

local function getUsernames()
	local usernames = {}
	for k, v in pairs(player.GetAll()) do
		if v and v:IsValid() and v:IsPlayer() then
			usernames[v:Nick()] = v
		end
	end
	return usernames
end

local function GetRandomSteamID()
	return "7656119"..tostring(7960265728+math.random(1, 200000000))
end

function D3bot.RegisterRandomName()
	local frmat = string.format( "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=0A50351F1710D5B8363B1F7D3B156613&steamids=%s", GetRandomSteamID() )
	http.Fetch( frmat,
		function( body, length, headers, code )
			local tab = util.JSONToTable(body)
			if #tab['response']['players'] > 0 then
				D3bot.Names[#D3bot.Names+1] = tab['response']['players'][1].personaname
			else
				print("error, invalid name, retrying!")
				D3bot.RegisterRandomName()
			end
		end,
		function( message )
			print(message)
			print('Unable to find alias, try again or contact developer!')
		end,

		{}
	)
end

function D3bot.GenerateFakeNames()
	D3bot.Names = { [1] = "Bot" }
	for i=1, 100 do
		D3bot.RegisterRandomName()
	end
end
hook.Add("InitPostEntity","D3Bot.Init.RNGNames", function()
	D3bot.GenerateFakeNames()
end)

local names = {}
function D3bot.GetUsername()
	local usernames = getUsernames()
	
	if #names == 0 then names = table.Copy(D3bot.Names) end
	local name = table.remove(names, math.random(#names))
	
	if usernames[name] then
		name = table.Random(names)
	end
	return name
end