module("ms", package.seeall)
Ores = Ores or {}

local function scaleBone(ent, boneName, scale)
	local boneIndex = ent:LookupBone(boneName)
	if not boneIndex then return end

	ent:ManipulateBoneScale(boneIndex, Vector(scale, scale, scale))
end

function Ores.SpawnRockyAntlion(pos, rarity)
	local npc = ents.Create("npc_antlion")
	npc:SetKeyValue("startburrowed", "1")
	npc:SetMaterial("models/props_wasteland/rockcliff02c")
	npc:SetPos(pos + Vector(0, 0, 128))
	npc:Spawn()
	npc:DropToFloor()
	npc:AddRelationship("player D_HT 99")
	npc:SetHealth(100)
	npc:SetKeyValue("classname", "Rocklion")

	npc.MiningRarity = rarity
	npc.NextOreDrop = 0
	npc.OreDropCount = 0

	npc:Input("Unburrow")

	local boneIndex = npc:LookupBone("Antlion.Back_Bone")
	if not boneIndex then return end

	scaleBone(npc, "Antlion.Back_Bone", Vector(0.1, 0.1, 0.1))
	scaleBone(npc, "Antlion.WingL_Bone", Vector(2, 2, 2))
	scaleBone(npc, "Antlion.WingR_Bone", Vector(2, 2, 2))

	local bonePos, boneAng = npc:GetBonePosition(boneIndex)
	local rock = ents.Create("mining_rock")
	rock:SetRarity(rarity)
	rock:SetPos(bonePos + npc:GetUp() * -60 + npc:GetRight() * 150 + npc:GetForward() * 200)
	rock:SetAngles(boneAng + Angle(45, 0, 110))
	rock:Spawn()
	rock:SetModel("models/props_wasteland/rockgranite02c.mdl")
	rock:SetModelScale(0.75)
	rock:FollowBone(npc, boneIndex)

	rock.Think = function()
		if not IsValid(npc) or npc:Health() <= 0 then
			rock:Remove()
		end
	end

	-- remove that
	rock.OnTakeDamage = function(_, dmg)
		if type(dmg) ~= "CTakeDamageInfo" then return end
		npc:TakeDamageInfo(dmg)
	end

	return npc
end

local function createOreDrops(rarity, pos, ent, amount)
	if not ent:IsPlayer() then return end

	for _ = 1, amount do
		Ores.GivePlayerOre(ent, rarity, 1)
	end
end

-- Register the rocklion event
local ANTLION_CHANCE = 10
Ores.RegisterRockEvent({
	Id = "rocklion",
	Chance = ANTLION_CHANCE,
	CheckValid = function(ent)
		if ent:WaterLevel() > 1 then return false end

		local trigger = ms and ms.GetTrigger and ms.GetTrigger("cave1")
		if not trigger then return false end

		local zMax = trigger:GetPos().z + 100
		if ent:GetPos().z > zMax then return false end

		return true
	end,
	OnMarked = function(ent)
		ent.AntlionRock = true
		ent.PreventSplit = true
	end,
	OnDamaged = function(ent, dmg)
		if not ent.AntlionRock then return end

		local rarity = ent:GetRarity()
		local npc = Ores.SpawnRockyAntlion(ent:GetPos(), rarity)

		npc:EmitSound("physics/concrete/boulder_impact_hard" .. math.random(1, 2) .. ".wav", 100)
		npc:EmitSound("physics/concrete/boulder_impact_hard" .. math.random(3, 4) .. ".wav", 100)

		SafeRemoveEntity(ent)
	end
})

-- Keep the NPC damage and kill hooks
hook.Add("EntityTakeDamage", "mining_antlions", function(ent, dmg)
	if ent:IsNPC() and ent:GetClass() == "Rocklion" and ent.MiningRarity then
		if CurTime() >= ent.NextOreDrop and ent.OreDropCount <= 5 then
			local atck = dmg:GetAttacker()
			local oreAmount = math.random(1, 2)

			createOreDrops(ent.MiningRarity, ent:GetPos(), atck, oreAmount)
			ent.NextOreDrop = CurTime() + 1
			ent.OreDropCount = ent.OreDropCount + 1
		end

		ent:EmitSound("physics/metal/metal_grenade_impact_hard2.wav")
	end
end)

hook.Add("OnNPCKilled", "mining_antlions", function(npc, atck)
	if npc:GetClass() == "Rocklion" and npc.MiningRarity then
		createOreDrops(npc.MiningRarity, npc:GetPos(), atck, math.random(1, 4))

		atck:EmitSound("physics/concrete/boulder_impact_hard" .. math.random(1, 2) .. ".wav", 100)
		atck:EmitSound("physics/concrete/boulder_impact_hard" .. math.random(3, 4) .. ".wav", 100)
	end
end)
