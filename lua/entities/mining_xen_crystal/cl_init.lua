include("shared.lua")

local enableLight

local spriteGlow = Material("particle/fire")
local spriteFleck = Material("effects/fleck_glass2")
local spriteXen1 = Material("particle/particle_glow_02")
local spriteXen2 = Material("particle/particle_glow_03")
local spriteBeam = Material("particle/bendibeam")

local renderBounds = Vector(128,128,128)

local gravityGlow = vector_up*15
local gravityFleck = vector_up*-500

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT.GlowColor = Color(0,255,0)
ENT.GlowColorFaded = ColorAlpha(ENT.GlowColor,100)
ENT.ShineColor = Color(225,255,100)
ENT.CrystalColor = Color(115,30,0)

ENT._nextRefresh = 0
ENT._initialized = false

function ENT:RecreateParticleEmitter()
	if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
		self.ParticleEmitter:Finish()
	end

	self.ParticleEmitter = ParticleEmitter(self:GetPos())
	self._nextRefresh = RealTime()+2
end

function ENT:CreateFleckParticle(pos)
	local p = self.ParticleEmitter:Add(spriteFleck,pos)
	if p then
		p:SetDieTime(2)

		p:SetStartAlpha(255)
		p:SetEndAlpha(0)

		p:SetStartSize(2)
		p:SetEndSize(2)
		p:SetRoll(math.random(-5,5))

		p:SetCollide(true)
		p:SetGravity(gravityFleck)
	end

	return p
end

function ENT:CreateBeamPoints(pos,forced)
	if not forced and self._beamPoints then return end

	self._beamPoints = {}
	for i=1,6 do
		self._beamPoints[i] = util.TraceLine({
			start = pos,
			endpos = pos+(VectorRand()*2048),
			filter = self,
			mask = MASK_SOLID
		}).HitPos
	end
end

function ENT:CreateLight(col,brightness,size)
	enableLight = enableLight or ms.Ores.Settings.RockLights
	if enableLight:GetBool() then
		local l = DynamicLight(self:EntIndex())
		if l then
			local r,g,b = col:Unpack()
			l.pos = self:GetPos()
			l.r = r
			l.g = g
			l.b = b
			l.brightness = brightness
			l.Size = size
			l.Decay = 500
			l.DieTime = CurTime()+0.5
		end
	end
end

function ENT:Initialize()
	self:RecreateParticleEmitter()

	if not self.AmbientSound then
		self.AmbientSettings = {
			Path = "hl1/ambience/labdrone2.wav",
			Pitch = 55,
			Volume = 0.75
		}

		self.AmbientSound = CreateSound(self,self.AmbientSettings.Path)
		self.AmbientSound:PlayEx(self.AmbientSettings.Volume,self.AmbientSettings.Pitch)
	end

	if self:IsEffectActive(EF_ITEM_BLINK) then
		self.FadeTime = RealTime()+0.8
	end

	self._initialized = true
end

function ENT:Draw()
	local now = RealTime()

	if self.FadeTime and self.FadeTime >= now then
		local pos = self:GetPos()

		self:CreateBeamPoints(pos)

		local startCord = 0
		local endCord = 0.3
		local rad = 8

		render.SetMaterial(spriteBeam)

		for k,v in next,self._beamPoints do
			local scroll = math.random()
			render.DrawBeam(pos+((v-pos):GetNormalized()*rad),v,32,startCord+scroll,endCord+scroll,self.GlowColor)
		end

		local shakePos = pos+(VectorRand()*2)

		render.SetMaterial(spriteXen1)
		render.DrawSprite(pos+(shakePos-EyePos()):GetNormalized(),160,160,self.GlowColorFaded)

		render.SetMaterial(spriteXen2)
		render.DrawSprite(pos,80,80,self.ShineColor)

		local p = self.ParticleEmitter:Add(spriteGlow,pos+(VectorRand()*rad))
		if p then
			p:SetDieTime(0.5)

			p:SetColor(self.ShineColor.r,self.ShineColor.g,self.ShineColor.b)

			p:SetStartSize(5)
			p:SetEndSize(0)
			p:SetRoll(math.random(-5,5))

			p:SetCollide(true)
			p:SetGravity(vector_origin)
			p:SetVelocity((pos-p:GetPos()):GetNormalized()*-math.random(32,128))
		end

		self:CreateLight(self.GlowColor,2,2500,5000)
	else
		if self:GetDeparting() then return end

		render.SuppressEngineLighting(true)

		if self:GetUnlodged() then
			local sizesin = ((math.abs(math.sin(now*10))*0.25)+1)*20

			render.SetMaterial(spriteGlow)
			render.DrawSprite(self:GetPos(),sizesin,sizesin,self.GlowColor)

			self:CreateLight(self.GlowColor,-2,500)
		else
			self:CreateLight(self.CrystalColor,-3,500)
		end

		self:DrawModel()

		render.SuppressEngineLighting(false)
		render.SetBlend(1)
	end

	self:SetRenderBounds(-renderBounds,renderBounds)

	if now > self._nextRefresh then
		self:RecreateParticleEmitter()
	end
end

function ENT:OnRemove()
	if self.AmbientSound then
		self.AmbientSound:Stop()
		self.AmbientSound = nil
		self.AmbientSettings = nil
	end

	if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
		if not self:IsDormant() and not self:GetDeparting() then
			local pos = self:GetPos()
			local rad = 6

			local r,g,b = self.CrystalColor.r,self.CrystalColor.g,self.CrystalColor.b

			self.ParticleEmitter:SetPos(pos)

			for i=1,64 do
				local p = self:CreateFleckParticle(pos+(VectorRand()*rad))
				if p then
					p:SetColor(r,g,b)
					p:SetVelocity((pos-p:GetPos()):GetNormalized()*-96)
				end
			end

			for i=1,32 do
				local p = self.ParticleEmitter:Add(spriteGlow,pos+(VectorRand()*rad))
				if p then
					p:SetDieTime(4)

					p:SetColor(r,g,b)

					p:SetStartSize(5)
					p:SetEndSize(0)
					p:SetRoll(math.random(-5,5))

					p:SetCollide(true)
					p:SetGravity(gravityGlow)
					p:SetVelocity((pos-p:GetPos()):GetNormalized()*-32)
				end
			end

			r,g,b = self.ShineColor.r,self.ShineColor.g,self.ShineColor.b

			local p = self.ParticleEmitter:Add(spriteXen2,pos)
			if p then
				p:SetDieTime(6)

				p:SetColor(r,g,b)

				p:SetStartSize(16)
				p:SetEndSize(0)
				p:SetRoll(math.random(-5,5))

				p:SetCollide(true)
				p:SetGravity(gravityGlow)
			end
		end

		self.ParticleEmitter:Finish()
		self.ParticleEmitter = nil
	end

	timer.Simple(0.1,function()
		if self:IsValid() then
			self:Initialize()	-- A fullupdate happened and it's actually still alive! Bring everything back!
		end
	end)
end

function ENT:Think()
	if self:IsDormant() or self:GetDeparting() then
		self:SetNextClientThink(CurTime()+2)
		return true
	end

	if self.AmbientSound then
		self.AmbientSound:Play()
		self.AmbientSound:ChangeVolume(self.AmbientSettings.Volume)
		self.AmbientSound:ChangePitch(self.AmbientSettings.Pitch)
	end

	if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
		local pos = self:GetPos()
		local rad = 6

		local r,g,b = self.CrystalColor.r,self.CrystalColor.g,self.CrystalColor.b

		self.ParticleEmitter:SetPos(pos)

		local p = self.ParticleEmitter:Add(spriteGlow,pos+(VectorRand()*rad))
		if p then
			p:SetDieTime(4)

			p:SetColor(r,g,b)

			p:SetStartSize(5)
			p:SetEndSize(0)
			p:SetRoll(math.random(-5,5))

			p:SetCollide(true)
			p:SetGravity(vector_up*5)
		end

		self:SetNextClientThink(CurTime()+(self:GetVelocity():LengthSqr() > 64 and 0.05 or 0.4))
	else
		self:SetNextClientThink(CurTime()+2)
	end

	return true
end