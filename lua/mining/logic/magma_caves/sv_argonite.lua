local ARGONITE_RARITY = 18

local MAX_ARGON = 20
local STEPS = 10
local MAX_RETRIES = 5

local GRAPH = {
	[1] = Vector(0, 0, 0),
	[2] = Vector(-195, 877, 0),
	[3] = Vector(-184, 2064, 0),
	[4] = Vector(275, 2591, 0),
	[5] = Vector(1036, 2704, 0),
	[6] = Vector(275, 2591, 0),
	[7] = Vector(-184, 2064, 0),
	[8] = Vector(-1034, 2650, 0),
	[9] = Vector(-2393, 2026, 0),
	[10] = Vector(-2597, 1150, 0),
	[11] = Vector(-2472, 248, 0),
	[12] = Vector(-1069, -387, 0),
	[13] = Vector(-596, -370, 0),
}

local function getArgoniteRockCount()
	local curArgoniteCount = 0

	for _, rock in ipairs(ents.FindByClass("mining_rock")) do
		if rock:GetRarity() == ARGONITE_RARITY and rock.OriginalRock then
			curArgoniteCount = curArgoniteCount + 1
		end
	end

	return curArgoniteCount
end


local function generateArgoniteRocks()
	local count = getArgoniteRockCount()
	if count >= MAX_ARGON then return end

	local trigger = ms and ms.GetTrigger and ms.GetTrigger("volcano")
	if not IsValid(trigger) then return end

	local basePos = trigger:GetPos()
	local i = math.random(#GRAPH)
	local pos = basePos + GRAPH[i]
	local nextPos = basePos + (GRAPH[i + 1] or GRAPH[1])
	local stepDist = pos:Distance(nextPos) / STEPS

	for curStep = 1, STEPS do
		if count >= MAX_ARGON then return end

		if math.random() > 0.6 then continue end

		local localPos = pos + (pos - nextPos):GetNormalized() * (curStep * stepDist)
		local localEndPos = localPos + VectorRand(-1, 1) * 300
		local retries = 0

		while retries < MAX_RETRIES and localEndPos.z > localPos.z + 200 do
			localEndPos = localPos + VectorRand(-1, 1) * 300
			retries = retries + 1
		end

		if localEndPos.z > localPos.z + 200 then continue end

		local tr = util.TraceLine({
			start = localPos,
			endpos = localEndPos,
			mask = MASK_SOLID_BRUSHONLY,
		})

		if tr.Hit and util.IsInWorld(tr.HitPos) then
			local rock = ents.Create("mining_rock")
			rock:SetPos(tr.HitPos + tr.HitNormal * 10)
			rock:SetSize(math.random() > 0.33 and 1 or 2)
			rock:SetRarity(ARGONITE_RARITY)
			rock:Spawn()
			rock:PhysWake()
			rock:DropToFloor()

			if rock:IsStuckEx() then
				SafeRemoveEntity(rock)
				continue
			end

			rock.OriginalRock = true

			count = count + 1

			rock:DropToFloor()
			rock:AddEffects(EF_ITEM_BLINK)

			local snd = CreateSound(rock, ")ambient/levels/labs/teleport_winddown1.wav")
			snd:SetDSP(16)
			snd:SetSoundLevel(80)
			snd:ChangePitch(math.random(150, 180))
			snd:Play()

			timer.Simple(0.5, function()
				if not IsValid(rock) then return end
				rock:DropToFloor()
				rock:RemoveEffects(EF_ITEM_BLINK)
			end)
		end
	end
end

local argoniteEntity
local function getArgoniteEntity()
	if IsValid(argoniteEntity) then return argoniteEntity end

	argoniteEntity = ents.Create("prop_physics")
	argoniteEntity:SetModel("models/props_junk/PopCan01a.mdl")
	argoniteEntity:SetKeyValue("classname", "Argonite")
	argoniteEntity:Spawn()

	return argoniteEntity
end

local skipDeathHook = false
timer.Create("mining_argonite_ore_dmg", 1, 0, function()
	for _, ply in ipairs(player.GetAll()) do
		local count = ms.Ores.GetPlayerOre(ply, ARGONITE_RARITY)
		local drunkFactor = ply.GetDrunkFactor and ply:GetDrunkFactor() or 0
		if count == 0 then
			ply.LastToxicHealth = nil

			if drunkFactor > 0 and ply.IsInZone and ply:IsInZone("volcano") then
				ply:SetDrunkFactor(0)
			end
		end

		if count > 0 and ply:Alive() then
			if isnumber(ply.LastToxicHealth) and ply.LastToxicHealth < ply:Health() then
				ply:SetHealth(ply.LastToxicHealth)
			end

			if ply:Health() > ply:GetMaxHealth() then
				ply:SetHealth(ply:GetMaxHealth())
			end

			local dmg = math.min(25, math.ceil(count / 2))
			dmg = dmg - ((dmg / 100) * ply:GetNWInt("ms.Ores.ToxicResistance", 0)) -- diminishes damage received with toxic resistance

			local preHealth = ply:Health()
			local argonite = getArgoniteEntity()
			local dmgInfo = DamageInfo()
			dmgInfo:SetDamage(dmg)
			dmgInfo:SetDamageType(DMG_RADIATION)
			dmgInfo:SetAttacker(argonite)
			dmgInfo:SetInflictor(argonite)
			ply:TakeDamageInfo(dmgInfo)

			if ply.SetDrunkFactor then
				ply:SetDrunkFactor(dmg * 10)
			end

			if ply:Health() > 0 and preHealth == ply:Health() then
				ply:SetHealth(preHealth - count)

				if ply:Health() <= 0 then
					ply:KillSilent()

					skipDeathHook = true
					hook.Run("PlayerDeath", ply, argonite, argonite)
					skipDeathHook = false
				end
			end

			-- we can't use :Alive here because it won't be accurate just yet
			if ply:Health() > 0 then
				ply.LastToxicHealth = ply:Health()
			end
		end
	end
end)

timer.Create("mining_argonite_ore_spawning", 5, 0, generateArgoniteRocks)

local function reducePlayerArgoniteOreCount(ply, no_toxicity_reset)
	if skipDeathHook then return end

	local count = ms.Ores.GetPlayerOre(ply, ARGONITE_RARITY)
	if count > 0 then
		ms.Ores.TakePlayerOre(ply, ARGONITE_RARITY, math.ceil(count / 2))
	end

	if not no_toxicity_reset then
		ply.LastToxicHealth = nil
	end
end

hook.Add("PlayerDeath", "mining_argonite_ore", reducePlayerArgoniteOreCount)
hook.Add("PlayerSilentDeath", "mining_argonite_ore", reducePlayerArgoniteOreCount)

hook.Add("CanPlyTeleport", "mining_argonite_ore", function(ply) reducePlayerArgoniteOreCount(ply, true) end)
hook.Add("PlayerNoClip", "mining_argonite_ore", function(ply, wants_noclip)
	if wants_noclip and ms.Ores.GetPlayerOre(ply, ARGONITE_RARITY) > 0 then
		reducePlayerArgoniteOreCount(ply, true)

		return false
	end
end)
