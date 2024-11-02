AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Argonite Drone"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.ClassName = "mining_argonite_drone"
ENT.LaserDistance = 150 * 150
ENT.HeightOffset = Vector(0, 0, 50)

local NODES = {
	Vector(7290.3662109375, -394.54165649414, -15312.8359375),
	Vector(6858.1372070312, -374.09796142578, -15304.220703125),
	Vector(6451.595703125, -300.64538574219, -15303.966796875),
	Vector(6133.2563476562, -204.45785522461, -15306.864257812),
	Vector(5854.9643554688, -96.933898925781, -15309.14453125),
	Vector(5782.0483398438, 299.78552246094, -15303.693359375),
	Vector(5713.9702148438, 758.13116455078, -15303.631835938),
	Vector(5715.3579101562, 1104.60546875, -15304.112304688),
	Vector(5714.8017578125, 1722.1441650391, -15309.151367188),
	Vector(5349.484375, 2195.7849121094, -15304.33984375),
	Vector(4863.5874023438, 2510.130859375, -15307.955078125),
	Vector(4459.8598632812, 2271.1901855469, -15316.14453125),
	Vector(3976.6962890625, 2022.6401367188, -15316.016601562),
	Vector(3387.6232910156, 1859.7194824219, -15311.369140625),
	Vector(3365.2770996094, 1382.443359375, -15304.256835938),
	Vector(3330.1713867188, 992.31695556641, -15304.190429688),
	Vector(3366.5329589844, 361.68695068359, -15304.235351562),
	Vector(3438.1975097656, -121.42636871338, -15315.672851562),
	Vector(3678.9865722656, -735.61853027344, -15334.471679688),
	Vector(4043.5646972656, -639.06231689453, -15331.96875),
	Vector(4617.5756835938, -633.54693603516, -15331.122070312),
	Vector(4878.7543945312, -610.96575927734, -15308.881835938),
	Vector(5234.1884765625, -517.06597900391, -15303.989257812),
	Vector(5528.2338867188, -395.98141479492, -15303.629882812),
	Vector(5833.2241210938, -220.76287841797, -15310.05078125),
	Vector (6074.9877929688, 2380.0256347656, -15303.126953125),
	Vector (6726.7534179688, 2552.9794921875, -15315.967773438),
}

function ENT:TraceToGround()
	local pos = self:WorldSpaceCenter()
	return util.TraceLine({
		start = pos,
		endpos = pos + Vector(0, 0, -2e6),
		mask = bit.bor(MASK_SOLID_BRUSHONLY, MASK_WATER),
	})
end

function ENT:HasTarget() return IsValid(self:GetNWEntity("Target")) end
function ENT:GetTarget() return self:GetNWEntity("Target") end

function ENT:InTargetRange()
	local target = self:GetTarget()
	if IsValid(target) and self:WorldSpaceCenter():DistToSqr(target:WorldSpaceCenter()) < self.LaserDistance then
		return true
	end

	return false
end

local RED_COLOR = Color(255, 0, 0, 255)
if SERVER then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:SetModel("models/maxofs2d/hover_rings.mdl")
		self:SetNotSolid(true)
		self:SetColor(RED_COLOR)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:PhysWake()

		self:SetCollisionGroup(COLLISION_GROUP_WORLD)

		self:StartMotionController()
		self.ShadowParams = {}
		self.NextTargetCheck = 0

		timer.Simple(0, function()
			if not IsValid(self) then return end
			util.SpriteTrail(self, 0, RED_COLOR, false, 15, 1, 1, 1 / (15 + 1) * 0.5, "trails/laser.vmt")
		end)
	end

	function ENT:FindClosestNode(pos)
		local min_dist = math.huge
		local min_node = pos
		for _, node in ipairs(NODES) do
			local sqrt_dist = node:DistToSqr(pos)
			if sqrt_dist < min_dist then
				min_dist = sqrt_dist
				min_node = node
			end
		end

		return min_node
	end

	function ENT:CanReach(ent)
		local tr = util.TraceLine({
			start = self:WorldSpaceCenter(),
			endpos = ent:WorldSpaceCenter(),
			filter = self,
			mask = MASK_SOLID_BRUSHONLY,
		})

		return tr.Fraction > 0.75
	end

	function ENT:Teleport(pos)
		self:SetPos(pos)
		self:EmitSound("npc/waste_scanner/grenade_fire.wav")
	end

	function ENT:SetTarget(target)
		if self:HasTarget() then
			local old_target = self:GetNWEntity("Target")
			if IsValid(old_target) then
				old_target.ArgoniteDrone = nil
				self:SetNWEntity("Target", nil)
			end
		end

		if not IsValid(target) then return end

		target.ArgoniteDrone = self
		self:SetNWEntity("Target", target)

		if not self:CanReach(target) then
			self:Teleport(self:FindClosestNode(target:WorldSpaceCenter()) + self.HeightOffset)
		end
	end

	function ENT:SetRarity(rarity)
		self.RarityOverride = rarity
	end

	function ENT:GetClosestRock()
		local target = NULL
		local mindist = math.huge
		local argonite_rarity = self.RarityOverride or ms.Ores.GetOreRarityByName("argonite")
		for _, ent in ipairs(ents.FindByClass("mining_rock")) do
			if ent:GetRarity() ~= argonite_rarity then continue end
			if IsValid(ent.ArgoniteDrone) then continue end

			local dist = ent:WorldSpaceCenter():DistToSqr(self:WorldSpaceCenter())
			if dist < mindist then
				mindist = dist
				target = ent
			end
		end

		return target
	end

	function ENT:MoveOn(exception)
		local rocks = {}
		local argonite_rarity = self.RarityOverride or ms.Ores.GetOreRarityByName("argonite")
		for _, ent in ipairs(ents.FindByClass("mining_rock")) do
			if ent:GetRarity() ~= argonite_rarity then continue end
			if IsValid(ent.ArgoniteDrone) then continue end
			if ent == exception then continue end

			table.insert(rocks, ent)
		end

		if #rocks < 1 then return end

		local new_rock = rocks[math.random(#rocks)]
		self:SetTarget(new_rock)
	end

	local ANG_ZERO = Angle(0, 0, 0)
	function ENT:PhysicsSimulate(phys, delta)
		phys:Wake()

		local pos
		local target = self:GetTarget()
		if IsValid(target) then
			pos = target:WorldSpaceCenter() + self.HeightOffset
		else
			local tr = self:TraceToGround()
			pos = tr.HitPos + self.HeightOffset

			if self.NextTargetCheck < CurTime() then
				self:SetTarget(self:GetClosestRock())
				self.NextTargetCheck = CurTime() + 2
			end
		end

		self.ShadowParams.secondstoarrive = 4
		self.ShadowParams.pos = pos
		self.ShadowParams.angle = ANG_ZERO
		self.ShadowParams.maxangular = 5000
		self.ShadowParams.maxangulardamp = 10000
		self.ShadowParams.maxspeed = 1000000
		self.ShadowParams.maxspeeddamp = 10000
		self.ShadowParams.dampfactor = 0.8
		self.ShadowParams.teleportdistance = 0
		self.ShadowParams.deltatime = delta

		phys:ComputeShadowControl(self.ShadowParams)
	end

	local function try_damage_target(self)
		if not self.CPPIGetOwner then return end
		if not self:HasTarget() then return end

		local owner = self:CPPIGetOwner()
		if not IsValid(owner) then return end

		local target = self:GetTarget()
		if not IsValid(target) then return end

		local timer_name = ("mining_argonite_drone_[%d]_target_[%d]"):format(self:EntIndex(), target:EntIndex())
		if not timer.Exists(timer_name) then
			timer.Create(timer_name, 40, 1, function()
				if not IsValid(self) then return end
				if target == self:GetTarget() then
					self:MoveOn(target)
				end
			end)
		end

		if self:InTargetRange() then
			local dmg = DamageInfo()
			dmg:SetAttacker(owner)
			dmg:SetInflictor(self)
			dmg:SetDamage(3)
			dmg:SetDamageType(DMG_ENERGYBEAM)

			local effect_data = EffectData()
			effect_data:SetOrigin(target:WorldSpaceCenter())
			effect_data:SetNormal(Vector(0, 0, 1))
			effect_data:SetScale(4)
			util.Effect("GunshipImpact", effect_data)

			target:TakeDamageInfo(dmg)

			return true
		end
	end

	function ENT:Think()
		local success = try_damage_target(self)
		if success then
			if not self.LaserSound then
				self.LaserSound = CreateSound(self, "ambient/energy/force_field_loop1.wav")
				self.LaserSound:Stop()
				self.LaserSound:Play()
			elseif not self.LaserSound:IsPlaying() then
				self.LaserSound:Stop()
				self.LaserSound:Play()
			end

			self.LaserSound:ChangePitch(85, 0)
			self.LaserSound:ChangeVolume(0.4)
		else
			if self.LaserSound then
				self.LaserSound:Stop()
			end
		end

		self:NextThink(CurTime() + 1)
		return true
	end

	function ENT:OnRemove()
		if self.LaserSound then
			self.LaserSound:Stop()
		end
	end
end

if CLIENT then
	local BEAM_MAT = Material("trails/physbeam")
	function ENT:Draw()
		self:DrawModel()

		local target = self:GetTarget()
		if self:InTargetRange() then
			render.SetMaterial(BEAM_MAT)
			render.DrawBeam(self:WorldSpaceCenter(), target:WorldSpaceCenter(), 5, 1, 1, RED_COLOR)
		end

		if MTA and self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
			cam.Start2D()
			MTA.HighlightPosition(self:WorldSpaceCenter(), ("Drone [%d]"):format(self:EntIndex()), RED_COLOR, false)
			cam.End2D()
		end
	end
end