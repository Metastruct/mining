AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ore Ingot"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = false
ENT.ClassName = "mining_ore_ingot"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/hunter/plates/plate025x05.mdl")
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)
		self:DrawShadow(false)
		self:SetMaterial("models/shiny")
		self:PhysWake()
	end

	function ENT:SetRarity(rarity)
		self:SetNWInt("Rarity", rarity)
	end
end

function ENT:GetRarity()
	return self:GetNWInt("Rarity", 0)
end

if CLIENT then
	local spriteGlow = Material("particle/fire")
	local gravityGlow = vector_up * 5
	local particleColScale = 2
	ENT._nextRefresh = 0
	ENT.SpriteOffset = Vector(-2.8, 0, -0.5)

	function ENT:RecreateParticleEmitter()
		if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
			self.ParticleEmitter:Finish()
		end

		self.ParticleEmitter = ParticleEmitter(self:GetPos())
		self._nextRefresh = RealTime() + 2
	end

	function ENT:GetParticleColor(rarity)
		local rSettings = ms.Ores.__R[rarity]

		if rSettings then
			return rSettings.PhysicalColor.r * particleColScale, rSettings.PhysicalColor.g * particleColScale, rSettings.PhysicalColor.b * particleColScale
		else
			return 255, 255, 255
		end
	end

	function ENT:GetSpritePos()
		local offset = Vector(self.SpriteOffset)
		offset:Rotate(self:GetAngles())

		return self:GetPos() + offset
	end

	function ENT:Initialize()
		self:RecreateParticleEmitter()
	end

	function ENT:Draw()
		local now = RealTime()
		local rSettings = ms.Ores.__R[self:GetRarity()]

		if rSettings then
			local pos = self:GetSpritePos()
			local sin = (math.abs(math.sin(now)) * 0.5) + 2
			local sizesin = ((math.abs(math.sin(now * 10)) * 0.25) + 4) * 16
			local col = ColorAlpha(rSettings.PhysicalColor, 100)
			local colVec = col:ToVector() * sin
			render.SetMaterial(spriteGlow)
			render.SetColorModulation(colVec.x, colVec.y, colVec.z)
			render.DrawSprite(pos, sizesin, sizesin, col)
		end

		render.SuppressEngineLighting(true)
		self:DrawModel()
		render.SuppressEngineLighting(false)

		if now > self._nextRefresh then
			self:RecreateParticleEmitter()
		end
	end

	function ENT:OnRemove()
		if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
			self.ParticleEmitter:Finish()
		end
	end

	function ENT:Think()
		if self.ParticleEmitter and self.ParticleEmitter:IsValid() and not self:IsDormant() then
			local pos = self:GetSpritePos()
			local rarity = self:GetRarity()
			local rSettings = ms.Ores.__R[rarity]
			local r, g, b = self:GetParticleColor(rarity)
			self.ParticleEmitter:SetPos(pos)

			local pPos = VectorRand() * 10
			pPos.z = 0

			local p = self.ParticleEmitter:Add(spriteGlow, pos + pPos)
			if p then
				p:SetDieTime(4)
				p:SetColor(r, g, b)
				p:SetStartSize(15)
				p:SetEndSize(0)
				p:SetRoll(math.random(-5, 5))
				p:SetCollide(true)
				p:SetGravity(gravityGlow)
			end

			self:SetNextClientThink(CurTime() + ((rSettings and rSettings.SparkleInterval or 1) * 1))
		else
			self:SetNextClientThink(CurTime() + 2)
		end

		return true
	end
end