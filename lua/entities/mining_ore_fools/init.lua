include("shared.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

ENT._shootNext = math.huge
ENT._shootEnd = math.huge
ENT._shootTable = {
	AmmoType = "pistol",
	Callback = function(self,tr)
		self:EmitSound("^weapons/pistol/pistol_fire3.wav",90,math.random(120,130))

		local target = self:GetTarget()
		local pos,ang = self:GetPistolPosition(target)

		local eff = EffectData()
		eff:SetOrigin(pos+ang:Forward()*-16)
		eff:SetAngles(ang)
		eff:SetScale(0.75)
		util.Effect("MuzzleEffect",eff,true,true)

		if tr.Entity == target then
			target._hitByOre = true
		end
	end,
	Force = 1,
	Num = 1,
	Tracer = 1,
	TracerName = "Tracer",
	Spread = Vector(0.025,0.025,0)
}
ENT._shootTraceTable = {
	mask = MASK_NPCWORLDSTATIC
}

ENT._painSounds = {
	")vo/npc/male01/ow01.wav",
	")vo/npc/male01/pain03.wav",
	")vo/npc/male01/pain04.wav",
	")vo/npc/male01/pain05.wav",
	")vo/npc/male01/pain06.wav",
	")vo/npc/male01/pain08.wav",
	")vo/npc/male01/pain09.wav",
	")vo/npc/female01/ow01.wav",
	")vo/npc/female01/ow02.wav",
	")vo/npc/female01/pain01.wav",
	")vo/npc/female01/pain03.wav",
	")vo/npc/female01/pain04.wav",
	")vo/npc/female01/pain05.wav"
}
ENT._killSounds = {
	")vo/coast/odessa/male01/nlo_cheer03.wav",
	")vo/npc/male01/answer03.wav",
	")vo/npc/male01/answer04.wav",
	")vo/npc/male01/answer35.wav",
	")vo/npc/male01/answer39.wav",
	")vo/npc/male01/pardonme01.wav",
	")vo/npc/male01/sorrydoc02.wav",
	")vo/npc/male01/whoops01.wav",
	")vo/coast/odessa/female01/nlo_cheer02.wav",
	")vo/npc/female01/answer03.wav",
	")vo/npc/female01/answer04.wav",
	")vo/npc/female01/answer36.wav",
	")vo/npc/female01/answer40.wav",
	")vo/npc/female01/yeah02.wav"
}

function ENT:RevertToNormal()
	self:SetAggro(false)
	self:SetTarget(NULL)

	self.Think = nil
	self.OnTakeDamage = nil
end

function ENT:Initialize()
	self.BaseClass.Initialize(self)

	timer.Simple(2,function()
		if self:IsValid() and self:GetAggro() then
			local now = CurTime()

			self._shootNext = now+1
			self._shootEnd = now+60
			self:EmitSound("weapons/pistol/pistol_reload1.wav",75,120,0.8)
		end
	end)
end

function ENT:Touch(ent)
	if not self:GetAggro() then
		self.BaseClass.Touch(self,ent)
	end
end

function ENT:OnTakeDamage(dmg)
	if self:GetAggro() then
		self:RevertToNormal()
		self:EmitSound(self._painSounds[math.random(#self._painSounds)],70,130)
	end
end

function ENT:Think()
	if not self:GetAggro() then return end

	local now = CurTime()
	local pos = self:WorldSpaceCenter()
	local target = self:GetTarget()

	if now < self._shootEnd and target:IsValid() and target:Alive() and target:GetPos():DistToSqr(pos) < 1440000 then	--1200HU
		if now > self._shootNext then
			local eyePos = target:EyePos()

			self._shootTraceTable.start = pos
			self._shootTraceTable.endpos = eyePos
			self._shootTraceTable.filter = {self,target}

			if not util.TraceLine(self._shootTraceTable).Hit then
				self._shootTable.Damage = self:GetRarity()+1
				self._shootTable.Dir = (eyePos-pos):GetNormalized()
				self._shootTable.Src = pos
				self._shootTable.IgnoreEntity = self

				self:FireBullets(self._shootTable)
			end

			self._shootNext = now+math.Rand(0.25,1.25)
		end
	else
		self:RevertToNormal()
		self:EmitSound(self._killSounds[math.random(#self._killSounds)],70,130)
	end
end

hook.Add("PlayerShouldTakeDamage",ENT.ClassName,function(pl,attacker)
	if pl._hitByOre and pl == attacker then
		pl._hitByOre = nil
		return true
	end
end)