include("shared.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

ENT.ExpiryCheckPlayers = true
ENT.Unlodged = false

ENT.ms_nogoto = "No cheating!"
ENT._initialized = false
ENT._nextDamaged = 0

function ENT:Initialize()
	self._initialized = true

	self:SetModel("models/props_junk/rock001a.mdl")

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	self.PhysObject = self:GetPhysicsObject()
	if self.PhysObject:IsValid() then
		self.PhysObject:SetMass(3)
		self.PhysObject:SetBuoyancyRatio(0.245)
		self.PhysObject:EnableMotion(false)
	else
		self.PhysObject = nil
	end

	self:DrawShadow(false)
	self:SetMaterial("models/props_lab/xencrystal_sheet")

	self.ms_notouch = true

	timer.Simple(1.25,function()
		if self:IsValid() then self:CheckExistence() end
	end)
end

function ENT:OnTakeDamage(dmg)
	if self:GetUnlodged() then return end

	local now = CurTime()

	if self._nextDamaged > now then return end
	self._nextDamaged = now+0.015

	local attacker = dmg:GetAttacker()
	if not (attacker:IsValid() and attacker:IsPlayer()) then return end
	if attacker._miningBlocked or (attacker._miningCooldown and attacker._miningCooldown > now) then return end
	if attacker.IsAFK and attacker:IsAFK() then return end
	if attacker:GetShootPos():DistToSqr(dmg:GetDamagePosition()) > 16384 then return end

	local isPickaxe = false

	local wep = attacker:GetActiveWeapon()
	if not wep:IsValid() then return end
	if wep:GetClass() != "weapon_crowbar" and wep:GetClass() != "mining_pickaxe" then
		return
	end

	local inflictor = dmg:GetInflictor()	-- Inflictor is either yourself (because inflictor w/ crowbar = yourself??) or the crowbar
	if inflictor != attacker and inflictor != wep then return end

	if attacker:GetMoveType() == MOVETYPE_NOCLIP then
		self:EmitSound("player/suit_denydevice.wav",70)
		return
	end

	-- Update _miningCooldown to allow checking when they last mined
	attacker._miningCooldown = now

	self:SetUnlodged(true)
	self:AllowGracePeriod(attacker,60)

	self.Expiry = now+180

	self:EmitSound(")physics/concrete/concrete_break"..math.random(2,3)..".wav",70,math.random(130,145),0.75)
	self:EmitSound(")ambient/atmosphere/cave_hit2.wav",80,86)

	if self.PhysObject then
		self.PhysObject:EnableMotion(true)
		self.PhysObject:Wake()

		if self.WallNormal then
			self.PhysObject:SetVelocity((self.WallNormal*128)+(attacker:GetAimVector()*16))
		end
	end
end

function ENT:Use(pl)
	if not self:GetUnlodged() or self:GetDeparting() then return end
	if self:IsPlayerHolding() or not pl:IsPlayer() then return end
	if pl:GetMoveType() == MOVETYPE_NOCLIP then
		self:EmitSound("player/suit_denydevice.wav",70)
		return
	end

	local now = CurTime()
	if pl._miningBlocked or (pl._miningCooldown and pl._miningCooldown > now) then return end
	if pl.IsAFK and pl:IsAFK() then return end

	if self.GraceOwner == NULL or (self.GraceOwner == pl or now >= (self.GraceOwnerExpiry or 0)) then
		pl:EmitSound(")ambient/atmosphere/hole_hit5.wav",70,math.random(75,85))
		pl:ScreenFade(SCREENFADE.IN,Color(0,255,0,25),2.5,0)

		self:EmitSound("ambient/explosions/exp3.wav",70,math.random(100,110),0.8)
		self:EmitSound("physics/glass/glass_cup_break1.wav",70,math.random(75,90),0.5)
		SafeRemoveEntity(self)

		local newMult = math.Round(pl:GetNWFloat(ms.Ores._nwMult,0)+0.02,3)

		pl:SetNWFloat(ms.Ores._nwMult,newMult)
		ms.Ores.SetSavedPlayerData(pl,"mult",newMult)

		ms.Ores.SendChatMessage(pl,2,("The Xen Crystal's energy was taken - your multiplier is now x%s!"):format(1+newMult))
	else
		self:EmitSound("ambient/atmosphere/hole_hit4.wav",70,105)
	end
end

function ENT:AllowGracePeriod(pl,dur)
	self.GraceOwner = pl or NULL
	self.GraceOwnerExpiry = CurTime()+(dur or 10)
end

function ENT:Depart(force)
	if not force and self:GetUnlodged() then return end

	local soundLevel = 98
	self:EmitSound(")mining/xen_despawning.mp3",soundLevel)

    timer.Simple(3,function()
        if not self:IsValid() or (not force and self:GetUnlodged()) then return end

        self:EmitSound(")mining/xen_despawn.mp3",soundLevel)

        self:SetDeparting(true)
        self:SetSolid(SOLID_NONE)

        self.PhysObject = nil
        self:PhysicsDestroy()

        SafeRemoveEntityDelayed(self,1.25)
    end)
end

function ENT:Think()
	if self.PhysObject and self.PhysObject:IsMotionEnabled() and self.PhysObject:IsAsleep() then
		self.PhysObject:EnableMotion(false)
	end

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

function ENT:GravGunPickupAllowed(pl)
	if self:GetUnlodged()
	and (self.GraceOwner == NULL or (self.GraceOwner == pl or CurTime() >= (self.GraceOwnerExpiry or 0)))
	and self.PhysObject and not self.PhysObject:IsMotionEnabled() then
		self.PhysObject:EnableMotion(true)
		return true
	end
end

function ENT:CheckExistence()
	if not self._initialized then
		-- Hasn't initialized properly
		SafeRemoveEntity(self)
	else
		local pos = self:GetPos()

		if not util.IsInWorld(pos) or util.TraceLine({
			start = pos,
			endpos = pos-(vector_up*128),
			mask = MASK_SOLID_BRUSHONLY
		}).HitNoDraw then
			-- Outside the world or believed to be if there is nodraw underneath it
			SafeRemoveEntity(self)
		end
	end
end