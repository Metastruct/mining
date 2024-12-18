module("ms",package.seeall)

Ores = Ores or {}

local maxLevel = 50
local maxDist = 16384

local achievementMaxStatId = "mining_maxstat"

util.AddNetworkString("ms.Ores_StartMinerMenu")
hook.Add("KeyPress","ms.Ores_NPCUse",function(pl,key)
	if key ~= IN_USE then return end

	local npc = pl:GetEyeTrace().Entity
	if not npc:IsValid() then return end

	if npc.role == "miner" and Ores.NPCMiners[npc.roleinfo and npc.roleinfo.id]
		and npc:GetPos():DistToSqr(pl:GetPos()) <= maxDist
	then
		if Instances and not Instances.ShouldInteract(pl,npc) then return end

		net.Start("ms.Ores_StartMinerMenu")
		net.WriteEntity(npc)
		net.WriteInt(npc.roleinfo.id, 16)
		net.Send(pl)

		if pl.LookAt then
			pl:LookAt(npc,1,2)
		end
	end
end)

local function animateMiner(npc)
	npc:RemoveAllGestures()
	npc:AddLayeredSequence(npc:LookupSequence("give"),10)
end

local function getCloseMiner(pl)
	local pos = pl:GetPos()

	local npc = NULL
	local dist = maxDist
	for ent,_ in next, NPCS_REGISTERED.miner or {} do
		if not IsValid(ent) then continue end

		local d = pos:DistToSqr(ent:GetPos())
		if d <= dist then
			npc = ent
			dist = d
		end
	end

	return npc
end

concommand.Add("mining_turnin",function(pl,_,args)
	if not pl:IsValid() then return end

	local mode = args[1] and args[1]:upper()
	local tradeFunc = (mode == "O" and Ores.TradeOresForCoins) or (mode == "P" and Ores.TradeOresForPoints)

	if not tradeFunc then return end

	local npc = getCloseMiner(pl)
	if not npc:IsValid() then return end

	if tradeFunc(pl) then
		animateMiner(npc)
	end
end)

concommand.Add("mining_upgrade",function(pl,_,args)
	if not pl:IsValid() then return end

	local k = tonumber(args[1])
	local stat = Ores.__PStats[k]
	if not stat then return end

	local level = pl:GetNWInt(Ores._nwPickaxePrefix .. stat.VarName,0)

	-- Stat is already at max level
	if level >= maxLevel then return end

	level = level + 1

	local points = pl:GetNWInt(Ores._nwPoints,0)
	local cost = Ores.StatPrice(k,level)

	if points < cost then return end

	local npc = getCloseMiner(pl)
	if not npc:IsValid() then return end

	points = math.floor(points-cost)

	Ores.SetSavedPlayerData(pl,"points",points)
	pl:SetNWInt(Ores._nwPoints,points)

	Ores.SetSavedPlayerData(pl,stat.VarName,level)
	pl:SetNWInt(Ores._nwPickaxePrefix .. stat.VarName,level)

	if level == maxLevel and MetAchievements and MetAchievements.UnlockAchievement then
		MetAchievements.UnlockAchievement(pl,achievementMaxStatId)
	end

	local wep = pl:GetActiveWeapon()
	if wep:IsValid() and wep:GetClass() == "mining_pickaxe" then
		wep:RefreshStats()
		wep:CallOnClient("RefreshStats")
	end
end)
