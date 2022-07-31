AddCSLuaFile()

SWEP.PrintName = "Mining Pickaxe"

SWEP.DrawCrosshair = true
SWEP.DrawAmmo = false
SWEP.DrawWeaponInfoBox = false
SWEP.BounceWeaponIcon = false

SWEP.ViewModel = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/weapons/w_crowbar.mdl"
SWEP.UseHands = true

SWEP.Slot = 0
SWEP.SlotPos = 1
SWEP.AutoSwitchFrom = false
SWEP.AutoSwitchTo = false

SWEP.Spawnable = true
SWEP.Category = "Mining"

SWEP.HoldType = "melee2"

SWEP.Primary = {}
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Sound = ")physics/concrete/concrete_impact_bullet%s.wav"
SWEP.Primary.SoundRock = ")physics/glass/glass_bottle_impact_hard%s.wav"
SWEP.Primary.SoundRockHealth = ")physics/concrete/concrete_impact_bullet%s.wav"
SWEP.Primary.SoundFlesh = "Weapon_Crowbar.Melee_Hit"
SWEP.Primary.SoundMiss = "Weapon_Knife.Slash"
SWEP.Primary.SoundShockwave = "ambient/machines/thumper_dust.wav"

SWEP.Secondary = {}
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Stats = {}
SWEP.StatsLoaded = false

SWEP.NextVMIdle = nil

-- List of entity classnames that trigger shockwave on hit rather than apply damage
SWEP.IgnoredEnts = {
	mining_ore = true
}

function SWEP:RefreshStats()
	if not _G.ms then return end

	local owner = self:GetOwner()
	if not (owner:IsValid() and owner:IsPlayer()) then return end

	for k,v in next,ms.Ores.__PStats do
		self.Stats[v.VarName] = v.VarBase+(v.VarStep*owner:GetNWInt(ms.Ores._nwPickaxePrefix..v.VarName,0))
	end

	self.StatsLoaded = true
end

function SWEP:DoHitEffect(tr,soundSource)
	if not (soundSource and soundSource:IsValid()) then
		soundSource = self
	end

	if tr.MatType == MAT_BLOODYFLESH or tr.MatType == MAT_FLESH or tr.MatType == MAT_ALIENFLESH then
		soundSource:EmitSound(self.Primary.SoundFlesh)
	else
		local isRock = tr.Entity:IsValid() and tr.Entity:GetClass() == "mining_rock"

		soundSource:EmitSound(self.Primary.Sound:format(math.random(1,4)),70,math.random(126,134),isRock and 0.225 or 0.5)

		if isRock then
			local rock = tr.Entity

			soundSource:EmitSound(self.Primary.SoundRock:format(math.random(2,3)),85,math.random(95,105),1,CHAN_BODY)

			-- It's somehow possible that these two DT funcs don't exist yet, check before using them...
			if rock.GetHealthEx and rock.GetMaxHealthEx then
				soundSource:EmitSound(self.Primary.SoundRockHealth:format(math.random(1,3)),75,40+(60*(1-(rock:GetHealthEx()/rock:GetMaxHealthEx()))),0.15,CHAN_VOICE)
			end

			if CLIENT and rock.ParticleEmitter and rock.ParticleEmitter:IsValid() then
				local pos = tr.HitPos+tr.HitNormal
				local r,g,b = rock:GetParticleColor(rock:GetRarity())

				for i=1,8 do
					local p = rock:CreateRockParticle(pos+VectorRand())
					if p then
						p:SetColor(r,g,b)
						p:SetVelocity((tr.HitNormal+(VectorRand()*0.3))*math.random(32,128))
					end
				end
			end
		else
			if CLIENT then
				self:CreateFleckEffect(tr.HitPos+tr.HitNormal*2.5)
			end
		end
	end
end

if CLIENT then
	local spriteFleck = Material("effects/fleck_cement2")
	local spriteWave = Material("particle/particle_noisesphere")
	local gravityFleck = vector_up*-500

	function SWEP:DrawWeaponSelection(x,y,w,h,alpha)
		surface.SetDrawColor(color_transparent)
		surface.SetTextColor(0,220,255,alpha)

		surface.SetFont("creditslogo")
		local logoW,logoH = surface.GetTextSize("c")

		surface.SetTextPos(x+(w*0.5)-(logoW*0.5),y+(h*0.5)-(logoH*0.5))
		surface.DrawText("c")
	end

	function SWEP:CreateFleckEffect(pos,amount)
		if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
			self.ParticleEmitter:SetPos(self:GetPos())
		else
			self.ParticleEmitter = ParticleEmitter(self:GetPos())
		end

		for i=1,(amount or 12) do
			local p = self.ParticleEmitter:Add(spriteFleck,pos)
			if p then
				p:SetDieTime(2)

				p:SetLighting(true)
				p:SetStartAlpha(255)
				p:SetEndAlpha(0)

				p:SetStartSize(2)
				p:SetEndSize(2)
				p:SetRoll(math.random(-5,5))

				p:SetCollide(true)
				p:SetGravity(gravityFleck)
				p:SetVelocity(VectorRand()*128)
			end
		end
	end

	function SWEP:CreateShockwaveEffect(pos,amount,range,normalRight,normalUp,effectStrength)
		if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
			self.ParticleEmitter:SetPos(self:GetPos())
		else
			self.ParticleEmitter = ParticleEmitter(self:GetPos())
		end

		local circleStep = 360/amount
		for i=1,amount do
			local p = self.ParticleEmitter:Add(spriteWave,pos)
			if p then
				p:SetDieTime(1)

				p:SetLighting(true)
				p:SetStartAlpha(150)
				p:SetEndAlpha(0)

				p:SetStartSize(32*effectStrength)
				p:SetEndSize(12*effectStrength)
				p:SetRoll(math.random(-5,5))

				p:SetCollide(false)
				p:SetGravity(vector_origin)

				local circleDir = ((i*circleStep)/360)*math.pi*2
				p:SetVelocity(((normalRight*math.sin(circleDir))+(normalUp*math.cos(circleDir)))*(range*6))
				p:SetAirResistance(256)
			end
		end
	end

	function SWEP:OnRemove()
		if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
			self.ParticleEmitter:Finish()
			self.ParticleEmitter = nil
		end
	end
else
	function SWEP:DoDamage(tr,dmgScale,isShockwave)
		local dmgType = isShockwave and bit.bor(DMG_CLUB,DMG_NEVERGIB) or DMG_CLUB

		local dmg = DamageInfo()
		dmg:SetAttacker(self:GetOwner())
		dmg:SetInflictor(self)
		dmg:SetDamage(math.ceil(20*(dmgScale or 1)))
		dmg:SetDamageType(dmgType)
		dmg:SetDamagePosition(tr.HitPos)
		dmg:SetDamageForce(tr.Normal*32)

		tr.Entity:TakeDamageInfo(dmg)
	end
end

function SWEP:Initialize()
	self:SetHoldType(self.HoldType)
	self:RefreshStats()
end

function SWEP:Deploy()
	if not (ms and ms.Ores) then
		if SERVER then
			self.Owner:ChatPrint("Mining is not available on this server.")
			self:Remove()
		end
		return
	end

	self:SendWeaponAnim(ACT_VM_DRAW)
	self.NextVMIdle = CurTime()+0.6

	self:RefreshStats()

	return true
end

function SWEP:PrimaryAttack()
	local owner = self:GetOwner()
	if not (owner:IsValid() and owner:IsPlayer()) then return end

	if not self.StatsLoaded then
		self:RefreshStats()
	end

	self:SetNextPrimaryFire(CurTime()+self.Stats.Delay)

	owner:SetAnimation(PLAYER_ATTACK1)

	owner:LagCompensation(true)

	local pos = owner:GetShootPos()
	local tr = util.TraceLine({
		start = pos,
		endpos = pos+(owner:GetAimVector()*self.Stats.Range),
		filter = owner
	})

	owner:LagCompensation(false)

	if tr.Hit then
		self:DoHitEffect(tr)

		owner:ViewPunch(Angle(-2,0,0))
		self:SendWeaponAnim(ACT_VM_HITCENTER)
		self.NextVMIdle = CurTime()+0.6

		if tr.Entity:IsValid() and !self.IgnoredEnts[tr.Entity:GetClass()] then
			if SERVER then
				self:DoDamage(tr)
			end
		elseif self.Stats.ShockwaveRange and self.Stats.ShockwaveRange > 0 then
			if IsFirstTimePredicted() then
				local waveStrength = self.Stats.ShockwaveRange/95

				if CLIENT then
					local norAng = tr.HitNormal:Angle()
					local norRight,norUp = norAng:Right(),norAng:Up()

					for i=1,math.ceil(self.Stats.ShockwaveRange*0.4) do
						local norRotRand = math.Rand(-1,1)*math.pi
						local norRand = math.random()

						self:CreateFleckEffect(tr.HitPos+(tr.HitNormal*4)+((norRight*math.sin(norRotRand)*norRand)+(norUp*math.cos(norRotRand)*norRand))*self.Stats.ShockwaveRange,3)
					end

					self:CreateShockwaveEffect(tr.HitPos,18,self.Stats.ShockwaveRange,norRight,norUp,math.Clamp(waveStrength*1.5,0.25,1))
				end

				self:EmitSound(self.Primary.SoundShockwave,70,math.random(150,165),math.max(waveStrength,0.25)*0.5,CHAN_VOICE2)

				local allRocks = ents.FindByClass("mining_rock")

				for k,v in next,allRocks do
					local rockPos = v.GetCorrectedPos and v:GetCorrectedPos() or v:GetPos()
					local rockTr = util.TraceLine({
						start = tr.HitPos,
						endpos = tr.HitPos+((rockPos-tr.HitPos):GetNormalized()*self.Stats.ShockwaveRange),
						filter = function(e) return e == v end,
						ignoreworld = true
					})

					if rockTr.Hit then
						-- Edit the HitPos to prevent ores from spawning in the ground
						rockTr.HitPos = v.GetCorrectedPos and rockPos or rockTr.HitPos+(vector_up*4)

						self:DoHitEffect(rockTr,v)

						if SERVER then
							self:DoDamage(rockTr,math.min((1-rockTr.Fraction)*1.5,1)*0.5,true)
						end
					end
				end

				-- Coal spawn
				if SERVER and math.random() <= 0.00075 then
					local ore = ents.Create("mining_ore")
					ore:SetRarity(0)
					ore:AllowGracePeriod(owner,5)
					ore:SetPos(tr.HitPos+(tr.HitNormal*4))
					ore:SetAngles(AngleRand())

					ore:Spawn()

					local ophys = ore:GetPhysicsObject()
					if ophys:IsValid() then
						local vec = VectorRand()*math.random(64,128)
						vec.z = math.abs(vec.z)

						ophys:AddVelocity(vec)
					end

					ore:EmitSound(")physics/surfaces/sand_impact_bullet"..math.random(1,4)..".wav",70,math.random(58,66))
				end
			end
		end
	else
		self:EmitSound(self.Primary.SoundMiss)

		self:SendWeaponAnim(ACT_VM_MISSCENTER)
		self.NextVMIdle = CurTime()+0.45
	end
end

function SWEP:Think()
	if self.NextVMIdle and CurTime() >= self.NextVMIdle then
		self:SendWeaponAnim(ACT_VM_IDLE)
		self.NextVMIdle = nil
	end
end

function SWEP:SecondaryAttack() end
function SWEP:CanSecondaryAttack() return false end
function SWEP:Reload() end