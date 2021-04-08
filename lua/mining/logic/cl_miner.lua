module("ms",package.seeall)

Ores = Ores or {}
Ores.MinerHats = Ores.MinerHats or {}

Ores.MinerHatInfo = {
	RequiresGame = "tf",
	Model = Model("models/props_2fort/hardhat001.mdl"),
	Bone = "ValveBiped.Bip01_Head1",
	Pos = Vector(2.25,-1.75,0),
	Ang = Angle(0,115,90),
	Scale = Vector(0.7,0.7,0.7)
}

local tag = "ms.Ores_NPCHat"

function Ores.MinerHatCreate(npc)
	assert(npc and npc:IsValid() and npc:IsNPC(),"target is not a valid NPC")

	if IsValid(Ores.MinerHats[npc]) then
		Ores.MinerHats[npc]:Remove()
		Ores.MinerHats[npc] = nil
	end

	local boneId = npc:LookupBone(Ores.MinerHatInfo.Bone)

	local hat = ClientsideModel(Ores.MinerHatInfo.Model,RENDERGROUP_OPAQUE)
	hat:SetPos(npc:GetPos())
	hat:Spawn()

	hat:FollowBone(npc,boneId)
	hat:SetLocalPos(Ores.MinerHatInfo.Pos)
	hat:SetLocalAngles(Ores.MinerHatInfo.Ang)
	hat:SetTransmitWithParent(false)

	local m = Matrix()
	m:SetScale(Ores.MinerHatInfo.Scale)

	hat:EnableMatrix("RenderMultiply",m)

	Ores.MinerHats[npc] = hat

	return hat
end

if IsMounted(Ores.MinerHatInfo.RequiresGame) then
	hook.Add("PlayerEnteredZone",tag,function(pl,zone)
		if zone != "cave" then return end

		hook.Add("EntityRemoved",tag,function(ent)
			if IsValid(Ores.MinerHats[ent]) then
				Ores.MinerHats[ent]:Remove()
				Ores.MinerHats[ent] = nil
			end
		end)

		for k,v in next,ents.FindByClass("lua_npc") do
			if v:GetNWString("Role") == "miner" then
				Ores.MinerHatCreate(v)
			end
		end
	end)

	hook.Add("PlayerExitedZone",tag,function(pl,zone)
		if zone != "cave" then return end

		hook.Remove("EntityRemoved",tag)

		for k,v in next,Ores.MinerHats do
			if IsValid(v) then
				v:Remove()
			end
		end

		Ores.MinerHats = {}
	end)
end