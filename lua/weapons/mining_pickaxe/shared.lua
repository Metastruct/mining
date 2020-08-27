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

SWEP.Secondary = {}
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Stats = {}
SWEP.StatsLoaded = false

SWEP.NextVMIdle = nil

function SWEP:RefreshStats()
	if not _G.ms then return end

	local owner = self:GetOwner()
	if not (owner:IsValid() and owner:IsPlayer()) then return end

	for k,v in next,ms.Ores.__PStats do
		self.Stats[v.VarName] = v.VarBase+(v.VarStep*owner:GetNWInt(ms.Ores._nwPickaxePrefix..v.VarName,0))
	end

	self.StatsLoaded = true
end

if CLIENT then
	local spriteFleck = Material("effects/fleck_cement2")
	local gravityFleck = vector_up*-500

	function SWEP:CreateFleckEffect(pos)
		if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
			self.ParticleEmitter:SetPos(self:GetPos())
		else
			self.ParticleEmitter = ParticleEmitter(self:GetPos())
		end

		for i=1,12 do
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

	function SWEP:OnRemove()
		if self.ParticleEmitter and self.ParticleEmitter:IsValid() then
			self.ParticleEmitter:Finish()
			self.ParticleEmitter = nil
		end
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
		local entValid = tr.Entity:IsValid()

		if tr.MatType == MAT_BLOODYFLESH or tr.MatType == MAT_FLESH or tr.MatType == MAT_ALIENFLESH then
			self:EmitSound(self.Primary.SoundFlesh)
		else
			local isRock = entValid and tr.Entity:GetClass() == "mining_rock"

			self:EmitSound(self.Primary.Sound:format(math.random(1,4)),70,math.random(126,134),isRock and 0.225 or 0.5)

			if isRock then
				local rock = tr.Entity

				self:EmitSound(self.Primary.SoundRock:format(math.random(2,3)),85,math.random(95,105),1,CHAN_BODY)

				-- It's somehow possible that these two DT funcs don't exist yet, check before using them...
				if rock.GetHealthEx and rock.GetMaxHealthEx then
					self:EmitSound(self.Primary.SoundRockHealth:format(math.random(1,3)),75,40+(60*(1-(rock:GetHealthEx()/rock:GetMaxHealthEx()))),0.15,CHAN_VOICE)
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

		owner:ViewPunch(Angle(-2,0,0))
		self:SendWeaponAnim(ACT_VM_HITCENTER)
		self.NextVMIdle = CurTime()+0.6

		if SERVER and entValid then
			local dmg = DamageInfo()
			dmg:SetAttacker(owner)
			dmg:SetInflictor(self)
			dmg:SetDamage(20)
			dmg:SetDamageType(DMG_CLUB)
			dmg:SetDamagePosition(tr.HitPos)
			dmg:SetDamageForce(tr.Normal*32)

			tr.Entity:TakeDamageInfo(dmg)
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