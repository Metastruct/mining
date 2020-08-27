module("ms",package.seeall)

local str = string.format
local next = next

local enableBonusSpots = CreateConVar("mining_rock_bonusspots",1,0,"Enables bonus spot generation on mining rocks.")

local traceMatWhitelist = {
	[MAT_CONCRETE] = true,
	[MAT_DIRT] = true,
	[MAT_SNOW] = true,
	[MAT_SAND] = true,
	[MAT_GRASS] = true
}

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
Ores.__S = {
	-- Defines which ore rarities can spawn in the mine with defined chances
	{Id = 0, Chance = 0.6},
	{Id = 1, Chance = 0.3},
	{Id = 2, Chance = 0.1}
}

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

-- Rocks for the cave
Ores.SpawnedRocks = setmetatable({},{__mode="k"})

function Ores.SelectRarityFromSpawntable()
	-- Order by descending chance, just in case it isn't already
	table.sort(Ores.__S,function(a,b) return a.Chance > b.Chance end)

	local total = 0
	for k,v in next,Ores.__S do
		total = total + v.Chance
	end

	local rand = math.random()*total

	total = 0
	for i=1,#Ores.__S do
		total = total + Ores.__S[i].Chance

		if i != #Ores.__S then
			if total > rand then return Ores.__S[i].Id end
		else
			return Ores.__S[i].Id
		end
	end
end

function Ores.GenerateMiningRock(startPos,rarity)
	if rarity then
		assert(isnumber(rarity) and Ores.__R and Ores.__R[rarity],"[Ores] Rarity argument is invalid")
	end

	local normal = VectorRand()
	normal.z = -math.abs(normal.z)

	local traceTbl = {
		start = startPos,
		endpos = startPos+(normal*5000),
		mask = MASK_SOLID_BRUSHONLY
	}

	local t = util.TraceLine(traceTbl)

	if t.StartSolid or not t.Hit then return end	-- No ground found?
	if not traceMatWhitelist[t.MatType] then
		local wallNormal = t.HitNormal

		traceTbl.start = t.HitPos
		traceTbl.endpos = t.HitPos+((wallNormal-wallNormal:Angle():Up()*0.75)*5000)
		t = util.TraceLine(traceTbl)

		local mult = 1-(traceTbl.start:DistToSqr(t.HitPos)/16384)
		if mult < 0 then mult = 0 end

		t.HitPos = t.HitPos+(wallNormal*48*mult)
	end

	local dist = 6400
	for k in next,Ores.SpawnedRocks do
		if t.HitPos:DistToSqr(k:GetCorrectedPos()) < dist then return end
	end
	for k,v in next,player.GetAll() do
		if t.HitPos:DistToSqr(v:GetPos()) < dist then return end
	end

	local ent = ents.Create("mining_rock")
	ent:SetPos(t.HitPos+(t.HitNormal*10))
	ent:SetAngles(AngleRand())

	local rand = math.random()
	ent:SetSize(rand < 0.33 and 1 or 2)

	if isnumber(rarity) then
		ent:SetRarity(rarity)
	else
		ent:SetRarity(Ores.SelectRarityFromSpawntable())
	end

	ent:AddEffects(EF_ITEM_BLINK)	-- Shh, I'm setting this so clients know to fade it in without using net
	timer.Simple(0.5,function() if ent:IsValid() then ent:RemoveEffects(EF_ITEM_BLINK) end end)

	if enableBonusSpots:GetBool() then
		ent:SetBonusSpotCount(math.random(0,2))
	end

	ent:Spawn()
	if Ores.SpawnedRocks then
		Ores.SpawnedRocks[ent] = true
	end

	local snd = CreateSound(ent,")ambient/levels/labs/teleport_winddown1.wav")
	snd:SetDSP(16)
	snd:SetSoundLevel(80)
	snd:ChangePitch(math.random(150,180))
	snd:Play()

	return ent
end

local attemptTime = 30
local nextAttempt = attemptTime
local function AdjustTimer(time)
	nextAttempt = time
	timer.Adjust("ms.Ores_Spawn",nextAttempt,0)
end
local noSetupText = "No positions set to spawn mining rocks, or invalid data - please populate the ms.mapdata.minespots table with vectors and run 'mapdata_save' on the server!"
local function SpawnRock(rarity)
	if not (mapdata.minespots and next(mapdata.minespots)) then
		Ores.Print(noSetupText)

		timer.Create("ms.Ores_Spawn",1800,0,function()
			if mapdata.minespots and next(mapdata.minespots) then
				Ores.Print("Detected data in ms.mapdata.minespots - mining rock spawning resumed...")

				timer.Create("ms.Ores_Spawn",90,0,SpawnRock)
				hook.Add("PlayerDestroyedMiningRock","ms.Ores_Spawn",QuickCheckRocks)
				return
			end

			Ores.Print(noSetupText)
		end)

		hook.Remove("PlayerDestroyedMiningRock","ms.Ores_Spawn")
		return
	end

	if table.Count(Ores.SpawnedRocks) >= (mapdata.NUM_ROCKS or 16) then return false end

	-- 4 attempts
	for i=1,4 do
		local id = math.random(1,#mapdata.minespots)
		if not isvector(mapdata.minespots[id]) then
			table.remove(mapdata.minespots,id)

			Ores.Print("Removed non-vector entry from ms.mapdata.minespots (temporary until saved with 'mapdata_save'), please check this table!")
			continue
		end

		if Ores.GenerateMiningRock(mapdata.minespots[id],rarity) then
			AdjustTimer(attemptTime)
			return true
		end
	end

	Ores.Print("Failed to spawn mining rock after 4 retries.")

	AdjustTimer(nextAttempt+attemptTime)
end

local function InitRocks()
	for i=1,math.ceil((mapdata.NUM_ROCKS or 16)*0.5) do
		if SpawnRock() == nil then return end
	end
end

local function QuickCheckRocks(pl,rock)
	-- When the last rock is destroyed, spawn another rock in the next second
	if not next(Ores.SpawnedRocks) then
		timer.Simple(1,function()
			if not next(Ores.SpawnedRocks) then SpawnRock() end
		end)
	end
end

timer.Create("ms.Ores_Spawn",attemptTime,0,SpawnRock)
hook.Add("PlayerDestroyedMiningRock","ms.Ores_Spawn",QuickCheckRocks)
hook.Add("InitPostEntity","ms.Ores_Init",InitRocks)
hook.Add("PostCleanupMap","ms.Ores_Init",InitRocks)

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
		local mult = math.Clamp(Ores.WorthMultiplier or 1,1,5)
		earnings = math.ceil(earnings*mult)

		Ores.Print(pl,str("gave %s ore pieces for %s%s coins",count,earnings,mult > 1 and str(" (x%s for %s)",mult,Ores.SpecialDays.Days[Ores.SpecialDays.ActiveId] and Ores.SpecialDays.Days[Ores.SpecialDays.ActiveId].Name or "some reason") or ""))
	end

	pl:GiveCoins(earnings,"Mining")
	pl:EmitSound(")ambient/levels/labs/coinslot1.wav",100,math.random(90,110))
	return true
end

function Ores.TradeOresForPoints(pl)
	if not pl._receivedOre then return false end

	local earnings,count = tradeOres(pl)
	if earnings <= 0 then return false end

	local mult = math.Clamp(Ores.WorthMultiplier or 1,1,5)
	earnings = math.ceil(earnings*mult)

	Ores.Print(pl,str("gave %s ore pieces for %s%s points",count,earnings,mult > 1 and str(" (x%s for %s)",mult,Ores.SpecialDays.Days[Ores.SpecialDays.ActiveId] and Ores.SpecialDays.Days[Ores.SpecialDays.ActiveId].Name or "some reason") or ""))

	local savaData = Ores.GetSavedPlayerData(pl)
	local points = math.floor(savaData._points+earnings)

	Ores.SetSavedPlayerData(pl,"points",points)
	pl:SetNWInt(Ores._nwPoints,points)
	pl:EmitSound(")physics/surfaces/underwater_impact_bullet3.wav",75,70)
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