include("shared.lua")
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")

ENT.ms_nogoto = "No cheating!"
ENT._initialized = false
ENT._nextDamaged = 0

local function getOreRarity(baseRarity,magicFindChance)
	if magicFindChance and math.random() <= magicFindChance then
		local rSettings = ms.Ores.__R[baseRarity]

		if rSettings.NextRarityId and ms.Ores.__R[rSettings.NextRarityId] then
			return rSettings.NextRarityId
		end
	end

	return baseRarity
end

local function createOre(pos,owner,rarity,magicFindChance,foolsDay)
	local oreRarity = getOreRarity(rarity,magicFindChance)
	local foolsTime = foolsDay and math.random() <= 0.2

	local ore = ents.Create(foolsTime and "mining_ore_fools" or "mining_ore")
	ore:SetRarity(oreRarity)
	ore:AllowGracePeriod(owner,20)
	ore:SetPos(pos)
	ore:SetAngles(AngleRand())

	if foolsTime then
		ore:SetTarget(owner)
		ore:SetAggro(true)
	end

	ore:Spawn()

	local ophys = ore:GetPhysicsObject()
	if ophys:IsValid() then
		local vec = VectorRand()*math.random(64,128)
		vec.z = math.abs(vec.z)

		ophys:AddVelocity(vec)
	end

	if rarity != oreRarity then
		-- Sound for Magic Find
		ore:EmitSound(")ambient/levels/citadel/portal_beam_shoot1.wav",68,math.random(185,195),0.75)
	end

	return ore
end

function ENT:Initialize()
	local rSettings = ms.Ores.__R[self:GetRarity()]
	if not rSettings then
		-- This isn't a registered rarity, clean it up!
		SafeRemoveEntity(self)
		return
	end

	self._initialized = true

	local size = math.Clamp(self:GetSize(),0,2)
	local modelTable = self.Models[self:GetSizeName(size)] or self.Models.Small
	local model = modelTable[math.random(1,#modelTable)]

	self:SetModel(model.Mdl)

	self:SetOffsetPos(model.Offset)
	self:SetPos(self:GetPos()+self:GetRotatedOffset())

	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)

	self.PhysObject = self:GetPhysicsObject()
	if self.PhysObject:IsValid() then
		self.PhysObject:EnableMotion(false)
	else
		self.PhysObject = nil
	end

	self:DrawShadow(false)
	self:SetMaterial("models/shadertest/shader2")

	self.ms_notouch = true

	self:SetMaxHealthEx(math.ceil(rSettings.Health*(1+(size*0.5))))
	self:SetHealthEx(self:GetMaxHealthEx())

	if (self:GetBonusSpotCount() or 0) > 0 then
		self:SetBonusSpotSeed(math.random(0,1000))
		self.BonusSpots = {Confirmed = {},Raw = {}}
	end

	timer.Simple(1.25,function()
		if self:IsValid() then self:CheckExistence() end
	end)
end

function ENT:OnTakeDamage(dmg)
	local now = CurTime()

	if self._nextDamaged > now then return end
	self._nextDamaged = now+0.015

	local attacker = dmg:GetAttacker()
	if not (attacker:IsValid() and attacker:IsPlayer()) then return end
	if attacker:GetMoveType() == MOVETYPE_NOCLIP then
		self:EmitSound("player/suit_denydevice.wav",70)
		return
	end
	if attacker._miningCooldown and attacker._miningCooldown > now then return end
	if attacker:GetShootPos():DistToSqr(dmg:GetDamagePosition()) > 16384 then return end
	if attacker.IsAFK and attacker:IsAFK() then return end

	local isPickaxe = false

	local wep = attacker:GetActiveWeapon()
	if not wep:IsValid() then return end
	if wep:GetClass() == "weapon_crowbar" then
		-- Allowed, crowbar penalty
		dmg:SetDamage(math.floor(dmg:GetDamage()*0.6))

		if ms.Ores.SendChatMessage and (not attacker._miningCrowbarMsgNext or now > attacker._miningCrowbarMsgNext) then
			ms.Ores.SendChatMessage(attacker,"Psst! You should use the Mining Pickaxe to get the most out of mining! Look in the Weapons tab!")
			attacker._miningCrowbarMsgNext = now+120
		end
	elseif wep:GetClass() == "mining_pickaxe" then
		-- Allowed
		isPickaxe = true
	else
		return
	end

	local inflictor = dmg:GetInflictor()	-- Inflictor is either yourself (because inflictor w/ crowbar = yourself??) or the crowbar
	if inflictor != attacker and inflictor != wep then return end

	local hp = self:GetHealthEx()-dmg:GetDamage()
	self:SetHealthEx(hp)

	local rarity = self:GetRarity()
	local magicFindChance = wep.Stats and wep.Stats.MagicFindChance

	local foolsDay = ms.Ores.SpecialDays and ms.Ores.SpecialDays.ActiveId and ms.Ores.SpecialDays.Days[ms.Ores.SpecialDays.ActiveId].Name == "April Fools"

	local dmgPos = dmg:GetDamagePosition()
	if self:GetBonusSpotCount() > 0 then
		local pos = self:GetPos()

		for k,v in next,self.BonusSpots.Confirmed do
			if v.Hit then continue end

			local spotOffset = Vector(v.Pos)
			spotOffset:Rotate(self:GetAngles())

			if dmgPos:DistToSqr(pos+spotOffset) <= 10 then
				v.Hit = true
				self:SetBonusSpotHit(bit.bor(2^k,self:GetBonusSpotHit()))

				self:EmitSound("physics/metal/metal_grenade_impact_hard2.wav",70,math.random(20,30))

				createOre(dmgPos,attacker,rarity,magicFindChance,foolsDay)
			end
		end
	end

	if hp > 0 then return end

	-- Update _miningCooldown to allow checking when they last mined
	attacker._miningCooldown = now

	local size = math.Clamp(self:GetSize(),0,2)

	self:EmitSound(")physics/concrete/boulder_impact_hard"..math.random(1,4)..".wav",70,105+(math.random(25,50)*(3-size)))
	self:EmitSound(")physics/glass/glass_impact_bullet"..math.random(1,3)..".wav",75,math.random(160,200))

	local bonusAmount = 0
	if isPickaxe then
		local bonusChance = wep.Stats and wep.Stats.BonusChance or 0
		bonusAmount = math.floor(bonusChance)+(math.random() <= bonusChance%1 and 1 or 0)
	end

	for i=1,1+bonusAmount do
		if i > 1 then
			timer.Simple(i*0.175,function()
				local ore = createOre(dmgPos,attacker,rarity,magicFindChance,foolsDay)
				ore:EmitSound(")garrysmod/save_load4.wav",70,152+(i*12))
			end)
		else
			createOre(dmgPos,attacker,rarity,magicFindChance,foolsDay)
		end
	end

	if size > 0 then
		local pos = self:GetCorrectedPos()
		local force = dmg:GetDamageForce():Angle():Right()

		local rocks = {}
		local numRocks = (math.random() <= (wep.Stats and wep.Stats.FineCutChance or 0)) and 3 or 2

		for i=0,numRocks-1 do
			local r = ents.Create(self:GetClass())
			r:SetSize(size-1)
			r:SetRarity(rarity)

			r:SetPos(pos)
			r:SetAngles(AngleRand())

			r:Spawn()
			if ms.Ores.SpawnedRocks and ms.Ores.SpawnedRocks[self] then
				ms.Ores.SpawnedRocks[r] = true
			end

			local phys = r:GetPhysicsObject()
			if phys:IsValid() then
				phys:SetMass(255)
				phys:EnableMotion(true)
				phys:Wake()
				phys:AddVelocity((force*48*math.cos(i/(numRocks-1)*math.pi))+(vector_up*16)+(VectorRand()*64))
			end

			rocks[#rocks+1] = r
		end

		-- Sound for Precise Cut
		if numRocks > 2 then
			self:EmitSound(")ambient/machines/slicer3.wav",70,math.random(40,60))
		end

		-- Briefly nocollide all the rocks that spawn
		for k,v in next,rocks do
			for _,x in next,rocks do
				if v == x then continue end

				local nocollide = constraint.NoCollide(v,x,0,0)
				if nocollide then SafeRemoveEntityDelayed(nocollide,0.75) end
			end
		end
	end

	hook.Run("PlayerDestroyedMiningRock",attacker,self)

	SafeRemoveEntity(self)	-- Possible some naughty hook removes self for us
end

function ENT:OnRemove()
	if ms.Ores.SpawnedRocks then
		ms.Ores.SpawnedRocks[self] = nil
	end
end

function ENT:Think()
	if self.PhysObject and self.PhysObject:IsMotionEnabled() and self.PhysObject:IsAsleep() then
		self.PhysObject:EnableMotion(false)
	end

	self:NextThink(CurTime()+1)
	return true
end

function ENT:CheckExistence()
	if not self._initialized then
		-- Hasn't initialized properly
		SafeRemoveEntity(self)
	else
		local pos = self:GetCorrectedPos()

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

-- We're doing it like this because physics meshes suck, we want the spot to actually be on the model
-- Hitting spots will be verified on the server of course (the malicious client would have to try quite hard to cheat it)
util.AddNetworkString("mining_rock.BonusSpot")
net.Receive("mining_rock.BonusSpot",function(_,pl)
	if not pl:IsValid() then return end

	local ent = net.ReadEntity()
	if not (ent and ent:IsValid() and ent:GetClass() == "mining_rock") then return end

	local maxSpots = ent.GetBonusSpotCount and ent:GetBonusSpotCount()
	if not maxSpots or maxSpots <= (ent.BonusSpots.Raw[pl] and #ent.BonusSpots.Raw[pl] or 0) then return end

	ent.BonusSpots.Raw[pl] = ent.BonusSpots.Raw[pl] or {}

	for i=1,maxSpots do
		local pos = net.ReadVector()
		local id = #ent.BonusSpots.Raw[pl]+1

		ent.BonusSpots.Raw[pl][id] = pos

		if ent.BonusSpots.Confirmed[id] and ent.BonusSpots.Confirmed[id].Hit then continue end

		local best,bestK,bestV = {},nil,0
		for k,v in next,ent.BonusSpots.Raw do
			local rawPos = v[id]
			local strPos = tostring(rawPos)
			best[strPos] = (best[strPos] or 0)+1

			if best[strPos] >= bestV then
				bestK,bestV = rawPos,best[strPos]
			end
		end

		if ent.BonusSpots.Confirmed[id] then
			ent.BonusSpots.Confirmed[id].Pos = bestK
		else
			ent.BonusSpots.Confirmed[id] = {Pos = bestK,Hit = false}
		end
	end
end)