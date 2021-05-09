module("ms",package.seeall)

local str = string.format
local next = next

--[[
Available mining hooks:

	PlayerDestroyedMiningRock
		Description:
		- Called when a mining rock is destroyed. The rock is removed directly after this hook is called!
		Arguments:
		- Player "destroyer"
		- Entity "rock"

	PlayerReceivedOre
		Description:
		- Called when a player receives ore. Generally by picking a piece up.
		Arguments:
		- Player "player"
		- Number "amountGained"
		- Number "rarityId"

	PlayerLostOre
		Description:
		- Called when a player loses ore. Generally by turning in their ore to the miner (this hook would get called for each rarity).
		Arguments:
		- Player "player"
		- Number "amountLost"
		- Number "rarityId"
]]

Ores = Ores or {}

function Ores.Print(...)
	MsgC(Color(230,130,65),"[Ores] ")
	print(...)
end
function Ores.PrintVerbose(...)
	if not Ores.Settings.VerbosePrint:GetBool() then return end

	Ores.Print("[Verbose] ",...)
end

util.AddNetworkString("ms.Ores_ChatMSG")
function Ores.SendChatMessage(pl,importanceLvl,txt)
	-- Importance Level lets clients determine if they should see the message
	-- 0 = info (eg. tutorials)
	-- 1 = warnings (eg. warnings about noclipping)
	-- 2 = alerts (eg. messages about events)

	if txt then
		importanceLvl = math.Clamp(importanceLvl,0,7)
	else
		-- If txt is missing, assume importanceLvl is txt
		txt = importanceLvl
		importanceLvl = 0
	end

	net.Start("ms.Ores_ChatMSG")
	net.WriteString(txt)
	net.WriteUInt(importanceLvl,3)
	net.Send(pl)
end

hook.Add("PlayerInitialSpawn","ms.Ores",function(pl)
	if Ores.SpecialDays and Ores.SpecialDays.ActiveId then
		Ores.SendSpecialDayInfo(pl)

		timer.Simple(60,function()
			if pl:IsValid() then
				Ores.NotifySpecialDay(pl)
			end
		end)
	end

	-- Loading pickaxe values on the same frame as PlayerInitialSpawn doesn't work, do it a second later
	timer.Simple(1,function()
		if pl:IsValid() then
			Ores.RefreshPlayerData(pl)
		end
	end)
end)

-- Ore Functions
local function tradeOres(pl)
	local earnings = 0
	local count = 0
	for k,v in next,Ores.__R do
		local n = Ores.GetPlayerOre(pl,k)
		if n <= 0 then continue end

		count = count+n
		Ores.TakePlayerOre(pl,k,n)

		earnings = earnings+(n*v.Worth)
	end

	return earnings,count
end

function Ores.TradeOresForCoins(pl,leaving)
	if not pl._receivedOre then return false end	-- This player has never picked up ore, don't bother

	local earnings,count = tradeOres(pl)
	if earnings <= 0 then return false end

	if leaving then
		Ores.Print(pl,str("disconnected with %s ore pieces and received %s coins (no bonuses)",count,earnings))
	else
		local mult = Ores.GetPlayerMultiplier(pl)
		earnings = math.ceil(earnings*mult)

		Ores.Print(pl,str("gave %s ore pieces for %s coins (x%s)",count,earnings,mult))
	end

	pl:GiveCoins(earnings,"Mining")
	pl:EmitSound(")ambient/levels/labs/coinslot1.wav",100,math.random(90,110))
	return true
end

function Ores.TradeOresForPoints(pl)
	if not pl._receivedOre then return false end

	local earnings,count = tradeOres(pl)
	if earnings <= 0 then return false end

	local mult = Ores.GetPlayerMultiplier(pl)
	earnings = math.ceil(earnings*mult)

	Ores.Print(pl,str("gave %s ore pieces for %s points (x%s)",count,earnings,mult))

	local loadingSound = "ambient/levels/canals/headcrab_canister_ambient5.wav"
	pl:EmitSound(loadingSound,45,120,0.6)

	Ores.GetSavedPlayerDataAsync(pl,function(data)
		local points = math.floor(data._points+earnings)

		Ores.SetSavedPlayerData(pl,"points",points)
		pl:SetNWInt(Ores._nwPoints,points)

		pl:StopSound(loadingSound)
		pl:EmitSound(")physics/surfaces/underwater_impact_bullet3.wav",75,70)
	end)

	return true
end

hook.Add("PlayerDisconnected","ms.Ores_AutoHandIn",function(pl)
	Ores.TradeOresForCoins(pl,true)
end)

hook.Add("ShutDown","ms.Ores_AutoHandIn",function()
	for _,pl in next,player.GetHumans() do
		Ores.TradeOresForCoins(pl,true)
	end
end)

-- function Ores.GetPlayerOre is in sh_ores.lua
function Ores.GivePlayerOre(pl,rarity,amount)
	assert(pl and pl:IsPlayer(),"[Ores] First argument is not a player")
	assert(isnumber(rarity) and Ores.__R[rarity],"[Ores] Rarity argument is invalid")
	assert(isnumber(amount) and amount > 0,"[Ores] Amount argument is invalid, it must be a positive number")

	amount = math.floor(amount)

	local nw = Ores._nwPrefix..Ores.__R[rarity].Name
	pl:SetNWInt(nw,pl:GetNWInt(nw,0)+amount)

	hook.Run("PlayerReceivedOre",pl,amount,rarity)
	pl._receivedOre = true
end
function Ores.TakePlayerOre(pl,rarity,amount)
	assert(pl and pl:IsPlayer(),"[Ores] First argument is not a player")
	assert(isnumber(rarity) and Ores.__R[rarity],"[Ores] Rarity argument is invalid")
	assert(isnumber(amount) and amount > 0,"[Ores] Amount argument is invalid, it must be a positive number")

	amount = math.floor(amount)

	local nw = Ores._nwPrefix..Ores.__R[rarity].Name
	local current = pl:GetNWInt(nw,0)
	pl:SetNWInt(nw,math.max(current-amount,0))

	hook.Run("PlayerLostOre",pl,math.min(amount,current),rarity)
end

-- Tutorials
hook.Add("PlayerReceivedOre","ms.Ores_FirstReceive",function(pl)
	-- _receivedOre will be nil the first time this hook is called for this player
	if pl._receivedOre then return end

	Ores.SendChatMessage(pl,0,"You've picked up some ore! Hand it in to the miner at the mine outpost! Be aware - disconnecting while holding ore will turn it into coins for you, but without any bonuses!")
	Ores.NotifySpecialDay(pl)
end)
