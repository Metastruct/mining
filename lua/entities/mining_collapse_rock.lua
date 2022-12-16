AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Rock"
ENT.Author = "Earu"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = false
ENT.ClassName = "mining_collapse_rock"

if SERVER then
	local ROCK_MDLS = {
		"models/props_wasteland/rockgranite02a.mdl",
		"models/props_wasteland/rockgranite02c.mdl",
		"models/props_wasteland/rockgranite03a.mdl",
		"models/props_wasteland/rockgranite03b.mdl",
		"models/props_debris/concrete_chunk07a.mdl",
		"models/props_debris/concrete_spawnchunk001f.mdl",
	}

	local ROCK_MAT = "models/props_wasteland/rockcliff02c"
	local SCALE_MIN = 2
	local SCALE_MAX = 4
	local BASE_HEALTH = 135

	function ENT:Initialize()
		local scale = math.random(SCALE_MIN, SCALE_MAX)

		self:SetModel(ROCK_MDLS[math.random(#ROCK_MDLS)])
		self:SetModelScale(scale, 0.0001)
		self:Activate()
		self:SetMaterial(ROCK_MAT)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)
		self:PhysWake()
		self:SetHealth(BASE_HEALTH * scale)
		self.OriginalScale = scale

		timer.Simple(1, function()
			if not IsValid(self) then return end

			self:Activate()
			if not util.IsInWorld(self:WorldSpaceCenter()) then
				SafeRemoveEntity(self)
			end

			if not self.EndTime then
				self:SetLifeTime(60)
			end
		end)
	end

	function ENT:SetLifeTime(duration)
		SafeRemoveEntityDelayed(self, duration)
		self.EndTime = CurTime() + duration
	end

	function ENT:OnTakeDamage(dmg)
		local dmgAmount = dmg:GetDamage()
		self:SetHealth(math.max(0, self:Health() - dmgAmount))

		if self:Health() <= 0 then
			if not self.DoNotBreakInPieces then
				for _ = 1, math.random(3, 4) do
					local rock
					if math.random() <= 0.1 then
						rock = ents.Create("mining_rock")
						rock:SetRarity(ms.Ores.Automation.GetOreRarityByName("Coal"))
						rock:SetSize(math.random() > 0.33 and 1 or 2)
					else
						rock = ents.Create("mining_collapse_rock")
						rock:SetModel("models/props_wasteland/rockgranite02a.mdl")
						rock:SetModelScale(self.OriginalScale / 4)
						rock:Activate()
						rock:SetLifeTime(self.EndTime - CurTime())
						rock.DoNotBreakInPieces = true
					end

					rock:SetPos(self:WorldSpaceCenter() + VectorRand(-100, 100))
					rock:Spawn()
				end
			end

			self:EmitSound(")physics/concrete/boulder_impact_hard" .. math.random(1, 4) .. ".wav", 100)

			local atcker = dmg:GetAttacker()
			if util.RockImpact and IsValid(atcker) and atcker:IsPlayer() then
				util.RockImpact(atcker, self:WorldSpaceCenter(), nil, self.OriginalScale, true)
			end

			self:Remove()
		else
			self:EmitSound("physics/metal/metal_grenade_impact_hard2.wav", 70, math.random(20, 30))
		end
	end
end