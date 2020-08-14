include("shared.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

ENT.ExpiryCheckPlayers = true

ENT.ms_nogoto = "No cheating!"
ENT._initialized = false
ENT._screamsNext = 0
ENT._screams = {
	")ambient/voices/f_scream1.wav",
	")vo/npc/female01/gethellout.wav",
	")vo/npc/female01/gordead_ans06.wav",
	")vo/npc/female01/gordead_ans13.wav",
	")vo/npc/female01/gordead_ans19.wav",
	")vo/npc/female01/help01.wav",
	")vo/npc/female01/no02.wav",
	")vo/npc/female01/ohno.wav",
	")vo/npc/female01/ow01.wav",
	")vo/npc/female01/pain04.wav",
	")vo/npc/female01/pain05.wav",
	")vo/npc/female01/runforyourlife02.wav",
	")vo/npc/female01/startle01.wav",
	")vo/npc/female01/startle02.wav",
	")vo/npc/female01/strider_run.wav",
	")vo/npc/female01/uhoh.wav",
	")vo/npc/female01/watchout.wav",
	")vo/npc/female01/wetrustedyou02.wav"
}

function ENT:Initialize()
	self._initialized = true

	self:SetModel("models/props_combine/breenbust_chunk05.mdl")

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
	self:SetTrigger(true)
	self:UseTriggerBounds(true,6)

	self.ms_notouch = true
	self.Expiry = CurTime()+180

	if self.AllowTouch == nil then
		timer.Simple(0.5,function()
			if self:IsValid() and not self._consumed and self.AllowTouch == nil then
				self:SetAllowTouch(true)
			end
		end)
	end

	self:DrawShadow(false)
	self:SetMaterial("models/shiny")
end

function ENT:Touch(ent)
	local now = CurTime()

	if self.AllowTouch
	and not self:IsPlayerHolding()
	and ent:IsPlayer()
	and ent:GetMoveType() != MOVETYPE_NOCLIP
	and now >= (ent._miningCooldown or 0)
	and not (ent.IsAFK and ent:IsAFK())
	and (self.GraceOwner == NULL or (self.GraceOwner == ent or now >= (self.GraceOwnerExpiry or 0))) then
		if banni and banni.isbanned(ent) then
			local phys = self:GetPhysicsObject()
			if phys:IsValid() then
				local dir = (self:GetPos()-ent:GetPos()):GetNormalized()
				dir.z = 0

				phys:Wake()
				phys:AddVelocity(dir*64)

				if now >= self._screamsNext then
					self:EmitSound(self._screams[math.random(#self._screams)],75,130,0.8)
					self._screamsNext = now+1
				end
			end

			return
		end

		self:Consume(ent)
	end
end

function ENT:Consume(pl)
	self:SetAllowTouch(false)
	if self._consumed then return end
	self._consumed = true

	ms.Ores.GivePlayerOre(pl,self:GetRarity(),1)

	self:EmitSound("physics/concrete/concrete_impact_soft3.wav",75,math.random(75,95))
	self:EmitSound("physics/glass/glass_cup_break1.wav",70,math.random(190,210),0.75)
	self:Remove()
end

function ENT:AllowGracePeriod(pl,dur)
	self.GraceOwner = pl or NULL
	self.GraceOwnerExpiry = CurTime()+(dur or 10)
end

function ENT:SetAllowTouch(b)
	self.AllowTouch = tobool(b)
end

function ENT:Think()
	local now = CurTime()

	if self.Expiry and self.Expiry <= now then
		local remove = true

		if self.ExpiryCheckPlayers then
			local pos = self:GetPos()
			local dist = 90000

			for k,v in next,player.GetHumans() do
				if pos:DistToSqr(v:GetPos()) <= dist then
					self.Expiry = now+30

					remove = false
					break
				end
			end
		end

		if remove then
			self:Remove()
		end
	end

	self:NextThink(now+1)
	return true
end