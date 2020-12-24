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
util.AddNetworkString("ms.Ores_UpdateSpecialDay")
function Ores.SendChatMessage(pl,txt)
	net.Start("ms.Ores_ChatMSG")
	net.WriteString(txt)
	net.Send(pl)
end
function Ores.SendSpecialDayInfo(pl)
	net.Start("ms.Ores_UpdateSpecialDay")
	if Ores.SpecialDays.ActiveId then
		net.WriteString(Ores.SpecialDays.Days[Ores.SpecialDays.ActiveId].Name)
		net.WriteFloat(Ores.WorthMultiplier)
	end
	net.Send(pl)
end

-- Miner NPC related variables
local function BuildSpecialDay(name,from,to,mult)
	return table.insert(Ores.SpecialDays.Days,{
		Name = name,
		Date = {
			From = {
				Month = from[1],
				Day = from[2],
				Hour = from[3]
			},
			To = {
				Month = to[1],
				Day = to[2],
				Hour = to[3]
			}
		},
		Multiplier = mult
	})
end

Ores.WorthMultiplier = Ores.WorthMultiplier or 1
Ores.SpecialDays = {Days = {}}

BuildSpecialDay("Meta Construct's Birthday",{1,23,0},{1,24,0},3)
BuildSpecialDay("Anniversary of Mining 2.0",{1,25,0},{1,26,0},1.5)
BuildSpecialDay("Valentine's Day",{2,14,0},{2,15,0},2)
BuildSpecialDay("April Fools",{4,1,0},{4,2,0},1.5)
BuildSpecialDay("Halloween",{10,31,0},{11,1,0},1.5)
BuildSpecialDay("GMod's Birthday",{11,29,0},{11,30,0},1.5)
BuildSpecialDay("Christmas",{12,24,0},{12,27,0},2)	-- Christmas Period, 24-26

local function NotifySpecialDay(pl)
	if pl == nil or (istable(pl) and #pl == 0) then return end
	if not Ores.SpecialDays.ActiveId then return end

	local day = Ores.SpecialDays.Days[Ores.SpecialDays.ActiveId]
	local toTime = os.date("!*t")
	toTime.month = day.Date.To.Month
	toTime.day = day.Date.To.Day
	toTime.hour = day.Date.To.Hour
	toTime.min = 0
	toTime.sec = 1

	Ores.SendChatMessage(pl,str("In celebration of %s, get x%s payout when turning in your ores! Celebration ends in %s!",day.Name,day.Multiplier,string.NiceTime(os.time(toTime)-os.time())))
end
function Ores.CheckForSpecialDay()
	local year = os.date("!*t").year
	local unix = os.time()
	for k,v in next,Ores.SpecialDays.Days do
		if os.time({
			year = year,
			month = v.Date.From.Month,
			day = v.Date.From.Day,
			hour = v.Date.From.Hour,
			min = 0,
			sec = 0}) <= unix
		and os.time({
			year = year+(v.Date.From.Month > v.Date.To.Month and 1 or 0),
			month = v.Date.To.Month,
			day = v.Date.To.Day,
			hour = v.Date.To.Hour,
			min = 0,
			sec = 0}) >= unix
		then
			local activatingDay = not Ores.SpecialDays.ActiveId

			Ores.SpecialDays.ActiveId = k
			Ores.WorthMultiplier = v.Multiplier

			if activatingDay then
				local pls = player.GetHumans()

				Ores.Print(str("Activating special day \"%s\" with x%s payout mutliplier, until %s-%s-%s %s:00...",v.Name,v.Multiplier,year,v.Date.To.Month,v.Date.To.Day,v.Date.To.Hour))
				Ores.SendSpecialDayInfo(pls)
				NotifySpecialDay(pls)
			end
			return
		end
	end

	if Ores.SpecialDays.ActiveId then
		local pls = player.GetHumans()
		local dayName = Ores.SpecialDays.Days[Ores.SpecialDays.ActiveId].Name

		Ores.Print(str("Deactivating special day \"%s\"...",dayName))
		Ores.SendSpecialDayInfo(pls)
		Ores.SendChatMessage(pls,str("The celebration of %s has ended! Thank you for taking part!",dayName))
	end

	Ores.SpecialDays.ActiveId = nil
	Ores.WorthMultiplier = 1
end

local date,sdTag = os.date("!*t"),"ms.Ores_SpecialDays"
local function specialDayTimer()
	-- Recalculate time or we slowly start going out of sync
	date = os.date("!*t")
	timer.Adjust(sdTag,((60-date.min)*60)-date.sec+10,0,specialDayTimer)

	Ores.CheckForSpecialDay()
end

timer.Create(sdTag,((60-date.min)*60)-date.sec+10,0,specialDayTimer)

hook.Add("PlayerInitialSpawn","ms.Ores",function(pl)
	if Ores.SpecialDays.ActiveId then
		Ores.SendSpecialDayInfo(pl)

		timer.Simple(60,function()
			if pl:IsValid() then
				NotifySpecialDay(pl)
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

if AOWL_SUCCESS then
	hook.Add("CanPlyTeleport","ms.Ores_MiningCooldown",applyMiningCooldown)
	hook.Add("CanPlyGoto","ms.Ores_MiningCooldown",applyMiningCooldown)
end

-- Tutorials
hook.Add("PlayerReceivedOre","ms.Ores_FirstReceive",function(pl)
	-- _receivedOre will be nil the first time this hook is called for this player
	if pl._receivedOre then return end

	Ores.SendChatMessage(pl,"You've picked up some ore! Hand it in to the miner at the mine outpost!\nBe aware - disconnecting while holding ore will turn it into coins for you, but without any bonuses!")
	NotifySpecialDay(pl)
end)