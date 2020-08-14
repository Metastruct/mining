module("ms", package.seeall)

Ores = Ores or {}

local maxDist = 16384

hook.Add("KeyPress", "ms.Ores_NPCUse", function(pl, key)
	if key ~= IN_USE then return end

	local npc = pl:GetEyeTrace().Entity
	if not npc:IsValid() then return end

	if npc.role == "miner" and Ores.NPCMiners[npc.roleinfo and npc.roleinfo.id]
		and npc:GetPos():DistToSqr(pl:GetPos()) <= maxDist
	then
		if Instances and not Instances.ShouldInteract(pl, npc) then return end

		SendUserMessage("ms.Ores_StartMinerMenu", pl, npc, npc.roleinfo.id)

		if pl.LookAt then
			pl:LookAt(npc, 1, 2)
		end
	end
end)

local nwPoints = "ms.Ores.Points"
local nwPickaxe = "ms.Ores.Pickaxe."
local function animateMiner(npc)
	npc:RemoveAllGestures()
	npc:AddLayeredSequence(npc:LookupSequence("give"), 10)
end

local function getCloseMiner(pl)
	local pos = pl:GetPos()

	local npc = NULL
	local dist = maxDist
	for ent, _ in next, (NPCS_REGISTERED.miner or {}) do
		if not IsValid(ent) then continue end

		local d = pos:DistToSqr(ent:GetPos())
		if d <= dist then
			npc = ent
			dist = d
		end
	end

	return npc
end

concommand.Add("mining_turnin", function(pl, _, args)
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

concommand.Add("mining_upgrade", function(pl, _, args)
	if not pl:IsValid() then return end

	local k = tonumber(args[1])
	local stat = Ores.__PStats[k]
	if not stat then return end

	local level = pl:GetNWInt(nwPickaxe .. stat.VarName, 0)

	-- Stat is already at max level
	if level >= 50 then return end

	local points = pl:GetNWInt(nwPoints, 0)
	local cost = Ores.StatPrice(k, level + 1)

	if points < cost then return end

	local npc = getCloseMiner(pl)
	if not npc:IsValid() then return end

	points = math.floor(points - cost)

	local nwStat = nwPickaxe .. stat.VarName
	local sID = pl:AccountID()

	pl:SetPData(nwPoints .. sID, points)
	pl:SetNWInt(nwPoints, points)
	pl:SetPData(nwStat .. sID, level + 1)
	pl:SetNWInt(nwStat, level + 1)

	local wep = pl:GetActiveWeapon()
	if wep:IsValid() and wep:GetClass() == "mining_pickaxe" then
		wep:RefreshStats()
		wep:CallOnClient("RefreshStats")
	end
end)