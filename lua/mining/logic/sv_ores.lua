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
		- Number "rarityId" (0-2)

	PlayerLostOre
		Description:
		- Called when a player loses ore. Generally by turning in their ore to the miner (this hook would get called for each rarity).
		Arguments:
		- Player "player"
		- Number "amountLost"
		- Number "rarityId" (0-2)
]]

Ores = Ores or {}

function Ores.Print(...)
	MsgC(Color(230,130,65),"[Ores] ")
	print(...)
end

util.AddNetworkString("ms.Ores_ChatMSG")
function Ores.SendChatMessage(pl,txt)
	net.Start("ms.Ores_ChatMSG")
	net.WriteString(txt)
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

	-- Loading pickaxe values on the same frame as PlayerInitialSpawn doesn't work, so...
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

-- Anti-cheat Hooks
-- Hinder mining bots by setting a cooldown where rocks and ores can't be interacted with, normal players shouldn't notice this
local function applyMiningCooldown(pl)
	pl._miningCooldown = CurTime()+1
end

hook.Add("PlayerNoClip","ms.Ores_MiningCooldown",function(pl,enable)
	if not enable then
		applyMiningCooldown(pl)
	end
end)

if _G.AOWL_SUCCESS then
	hook.Add("CanPlyTeleport","ms.Ores_MiningCooldown",applyMiningCooldown)
	hook.Add("CanPlyGoto","ms.Ores_MiningCooldown",applyMiningCooldown)
end

util.OnInitialize(function()
	if istable(_G.SF) then
		local processorClass = "starfall_processor"

		hook.Add("PlayerLoadedStarfall","ms.Ores_SFChecks",function(pl,ent,mainFile,allFiles)
			ent._miningContainsSetPos = nil

			for k,v in next,allFiles do
				if v:lower():match("[.:]setpos[ \t]*[^a-z]") then
					ent._miningContainsSetPos = true
					pl._miningBlocked = true

					return
				end
			end
		end)

		hook.Add("EntityRemoved","ms.Ores_SFChecks",function(ent)
			if ent:GetClass() != processorClass then return end

			local pl = ent.owner or (ent.CPPIGetOwner and ent:CPPIGetOwner())
			if pl and pl:IsValid() and pl._miningBlocked then
				-- Check the player's other Starfall processors, only remove the _miningBlocked flag if they're all clear
				for k,v in next,ents.FindByClass(processorClass) do
					if (v.owner or (v.CPPIGetOwner and v:CPPIGetOwner())) == pl and v._miningContainsSetPos then return end
				end

				pl._miningBlocked = nil
			end
		end)
	end
end)

-- Tutorials
hook.Add("PlayerReceivedOre","ms.Ores_FirstReceive",function(pl)
	-- _receivedOre will be nil the first time this hook is called for this player
	if pl._receivedOre then return end

	Ores.SendChatMessage(pl,"You've picked up some ore! Hand it in to the miner at the mine outpost! Be aware - disconnecting while holding ore will turn it into coins for you, but without any bonuses!")
	Ores.NotifySpecialDay(pl)
end)