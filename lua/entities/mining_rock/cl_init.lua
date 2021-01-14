include("shared.lua")

local enableLight

local spriteGlow = Material("particle/fire")
local spriteRock = Material("effects/fleck_cement2")
local spriteBonusBack = Material("particle/particle_glow_04")
local spriteBonusOuter = Material("sprites/glow04_noz")
local spriteBonusInner = Material("sprites/physg_glow1")
local particleColScale = 2
local renderBounds = Vector(128,128,128)

local gravityGlow = vector_up*15
local gravityRock = vector_up*-500

ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT._nextRefresh = 0
ENT._initialized = false
ENT._drawn = false

local function RandomModelMeshPos(self)
	local modelMesh = util.GetModelMeshes(self:GetModel())[1]
	if not modelMesh then
		return {
			Pos = Vector(0, 0, 20),
			Normal = Vector(0, 0, 1),
			Hit = false
		}
	end

	local verts = modelMesh.triangles
	local startId = 1+(math.floor(math.random(#verts)/3)*3)
	if startId > #verts-3 then
		startId = startId-3
	end

	local v1,v2,v3 = verts[startId].pos,verts[startId+1].pos,verts[startId+2].pos
	local midPos = Vector(
		(v1.x+v2.x+v3.x)/3,
		(v1.y+v2.y+v3.y)/3,
		(v1.z+v2.z+v3.z)/3
	)+(verts[startId].normal*0.25)

	return {
		Pos = midPos,
		Normal = verts[startId].normal,
		Hit = false
	}
end
local function SendBonusSpots(self)
	self.BonusSpots = {}

	math.randomseed(self:GetBonusSpotSeed())
	for i=1,self:GetBonusSpotCount() do
		self.BonusSpots[#self.BonusSpots+1] = RandomModelMeshPos(self)
	end

	net.Start("mining_rock.BonusSpot")
	net.WriteEntity(self)
	for k,v in next,self.BonusSpots do
		net.WriteVector(v.Pos)
	end
	net.SendToServer()
end

function ENT:RecreateParticleEmitter()
	if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
		self.ParticleEmitter:Finish()
	end

	self.ParticleEmitter = ParticleEmitter(self:GetCorrectedPos())
	self._nextRefresh = RealTime()+2
end

function ENT:GetParticleColor(rarity)
	local rSettings = ms.Ores.__R[rarity]
	if rSettings then
		return rSettings.PhysicalColor.r*particleColScale,rSettings.PhysicalColor.g*particleColScale,rSettings.PhysicalColor.b*particleColScale
	else
		return 255,255,255
	end
end

function ENT:CreateRockParticle(pos)
	local p = self.ParticleEmitter:Add(spriteRock,pos)
	if p then
		p:SetDieTime(2)

		p:SetStartAlpha(255)
		p:SetEndAlpha(0)

		p:SetStartSize(2)
		p:SetEndSize(2)
		p:SetRoll(math.random(-5,5))

		p:SetCollide(true)
		p:SetGravity(gravityRock)
	end

	return p
end

function ENT:Initialize()
	self:RecreateParticleEmitter()

	local rSettings = ms.Ores.__R[self:GetRarity()]

	if rSettings and rSettings.AmbientSound and not self.AmbientSound then
		self.AmbientSettings = {
			Path = rSettings.AmbientSound,
			Pitch = rSettings.AmbientPitch or 100,
			Volume = (rSettings.AmbientVolume or 0.2)*math.Clamp(self:GetSize()+1,1,3)
		}

		self.AmbientSound = CreateSound(self,self.AmbientSettings.Path)
		self.AmbientSound:PlayEx(self.AmbientSettings.Volume,self.AmbientSettings.Pitch)
	end

	if self:IsEffectActive(EF_ITEM_BLINK) then
		self.FadeTime = RealTime()+8
	end

	self._initialized = true
end

function ENT:Draw()
	if not self._drawn then
		if self:GetBonusSpotCount() > 0 and not self.BonusSpots then
			SendBonusSpots(self)
		end

		self._drawn = true
	end

	local now = RealTime()
	local rCol = color_white

	local rarity = self:GetRarity()
	local rSettings = ms.Ores.__R[rarity]
	if rSettings then
		rCol = rSettings.PhysicalColor

		local colVec = rCol:ToVector()*((math.abs(math.sin(now))*0.5)+2)
		render.SetColorModulation(colVec.x,colVec.y,colVec.z)
	end

	-- Spawn Fading
	if self.FadeTime then
		render.SetBlend(1-((self.FadeTime-now)*0.125))

		if self.FadeTime < now then
			self.FadeTime = nil
		end
	end

	-- Damage Wiggle
	if self:GetHealthEx() != self._lastHealthEx then
		self._lastHealthEx = self:GetHealthEx()
		self._hitWiggle = now+0.35
	end

	local wiggle
	if self._hitWiggle then
		if self._hitWiggle > now then
			wiggle = VectorRand()*(self._hitWiggle-now)*1.5
		else
			self._hitWiggle = nil
		end
	end
	--

	render.SuppressEngineLighting(true)

	if wiggle then
		cam.Start3D(EyePos()+wiggle)
			self:DrawModel()
		cam.End3D()
	else
		self:DrawModel()
	end

	-- Bonus Spots
	if self.BonusSpots and #self.BonusSpots > 0 then
		local eAng = EyeAngles()
		eAng:RotateAroundAxis(eAng:Up(),-90)
		eAng:RotateAroundAxis(eAng:Forward(),90)

		local rot = (now*720)%360
		local size = 10+math.sin(now*4)*2

		for k,v in next,self.BonusSpots do
			if v.Hit then continue end

			local nAng = Vector(v.Normal)
			nAng:Rotate(self:GetAngles())

			local pos = Vector(v.Pos+(wiggle or vector_origin))
			pos:Rotate(self:GetAngles())

			local wPos = self:GetPos()+pos

			if bit.band(self:GetBonusSpotHit(),2^k) != 0 then
				v.Hit = true

				if self.ParticleEmitter and self.ParticleEmitter:IsValid() and not self:IsDormant() then
					local r,g,b = self:GetParticleColor(self:GetRarity())

					for i=1,24 do
						local p = self.ParticleEmitter:Add(spriteGlow,wPos)
						if p then
							p:SetDieTime(4)

							p:SetColor(r,g,b)

							p:SetStartSize(5)
							p:SetEndSize(0)
							p:SetRoll(math.random(-5,5))

							p:SetCollide(true)
							p:SetGravity(gravityGlow)
							p:SetVelocity((nAng+(VectorRand()*0.4))*math.random(32,64))
						end
					end
				end

				continue
			end

			cam.Start3D2D(wPos,eAng,1)
				surface.SetDrawColor(0,0,0)
				surface.SetMaterial(spriteBonusBack)
				surface.DrawTexturedRectRotated(0,0,size*1.75,size*1.75,0)

				surface.SetDrawColor(rCol.r,rCol.g,rCol.b,120)
				surface.SetMaterial(spriteBonusOuter)
				surface.DrawTexturedRectRotated(0,0,size*2.5,size*2.5,-rot)

				surface.SetDrawColor(rCol.r,rCol.g,rCol.b)
				surface.SetMaterial(spriteBonusInner)
				surface.DrawTexturedRectRotated(0,0,size,size,rot)
			cam.End3D2D()

			nAng = nAng:Angle()

			wPos = wPos+nAng:Forward()*4
			cam.Start3D2D(wPos,nAng,1)
				surface.DrawTexturedRectRotated(0,0,64,3,0)
			cam.End3D2D()

			nAng:RotateAroundAxis(nAng:Forward(),90)
			cam.Start3D2D(wPos,nAng,1)
				surface.DrawTexturedRectRotated(0,0,64,3,0)
			cam.End3D2D()
		end
	end

	render.SuppressEngineLighting(false)
	render.SetBlend(1)

	self:SetRenderBounds(-renderBounds,renderBounds)

	-- Lights
	enableLight = enableLight or ms.Ores.Settings.RockLights
	if rSettings and enableLight:GetBool() then
		local l = DynamicLight(self:EntIndex())
		if l then
			local r,g,b = rSettings.PhysicalColor:Unpack()
			l.pos = self:GetCorrectedPos()
			l.r = r
			l.g = g
			l.b = b
			l.brightness = 0
			l.Size = self.FadeTime and 1000-((self.FadeTime-now)*125) or 333*math.Clamp(self:GetSize()+1,1,3)
			l.Decay = 500
			l.DieTime = CurTime()+0.5
		end
	end

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
		if not self:IsDormant() then
			local pos = self:GetCorrectedPos()
			local rad = 8*math.Clamp(self:GetSize()+1,1,3)

			local r,g,b = self:GetParticleColor(self:GetRarity())

			self.ParticleEmitter:SetPos(pos)

			for i=1,64 do
				local p = self:CreateRockParticle(pos+(VectorRand()*rad))
				if p then
					p:SetColor(r,g,b)
					p:SetVelocity((pos-p:GetPos()):GetNormalized()*-64)
				end
			end

			for i=1,16 do
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
		end

		self.ParticleEmitter:Finish()
		self.ParticleEmitter = nil
	end

	timer.Simple(0.1,function()
		if self:IsValid() and self:GetHealthEx() > 0 then
			self:Initialize()	-- A fullupdate happened and it's actually still alive! Bring everything back!
		end
	end)
end

function ENT:Think()
	if self:IsDormant() then
		self:SetNextClientThink(CurTime()+2)
		return true
	end

	if self.AmbientSound then
		self.AmbientSound:Play()
		self.AmbientSound:ChangeVolume(self.AmbientSettings.Volume)
		self.AmbientSound:ChangePitch(self.AmbientSettings.Pitch)
	end

	if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
		local pos = self:GetCorrectedPos()
		local rad = 8*math.Clamp(self:GetSize()+1,1,3)

		local rarity = self:GetRarity()
		local rSettings = ms.Ores.__R[rarity]
		local r,g,b = self:GetParticleColor(rarity)

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

		self:SetNextClientThink(CurTime()+(rSettings and rSettings.SparkleInterval or 1))
	else
		self:SetNextClientThink(CurTime()+2)
	end

	return true
end