AddCSLuaFile()

local TEXT_DIST = 150
local MAX_ENERGY = 450
local ARGONITE_RARITY = 18
local NORMAL_ORE_PRODUCTION_RATE = 10 -- 1 every 10s
local ARGONITE_ORE_PRODUCTION_RATE = 3 -- 1 every 3s

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Drill"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_drill"

if SERVER then
	local ACCEPTED_ENERGY_ENTS = {
		mining_argonite_battery = function(ent) return ent:GetNWInt("ArgoniteCount", 0) end,
		mining_coal_burner = function(ent) return ent:GetNWInt("CoalCount", 0) end,
	}

	local function add_saw(self, offset)
		local saw = ents.Create("prop_physics")
		saw:SetModel("models/props_junk/sawblade001a.mdl")
		saw:SetModelScale(2)
		saw:SetPos(self:GetPos() + offset)
		saw:Spawn()
		saw:SetParent(self)
		saw:SetKeyValue("classname", "mining_drill_saw")

		return saw
	end

	function ENT:Initialize()
		self:SetModel("models/props_combine/headcrabcannister01a.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetTrigger(true)
		self.NextEnergyConsumption = 0
		self.NextDrilledOre = 0

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x2.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetPos(self:GetPos() + self:GetForward() * -25 + self:GetRight() * -24)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetForward(), 90)

		self.Frame:SetAngles(ang)
		self.Frame:Spawn()
		self.Frame:SetParent(self)

		add_saw(self, self:GetForward() * -40 + self:GetRight() * 10)
		add_saw(self, self:GetForward() * -40)
		add_saw(self, self:GetForward() * -40 + self:GetRight() * -10)

		timer.Simple(0, function()
			if not IsValid(self) then return end

			for _, child in pairs(self:GetChildren()) do
				child:SetOwner(self:GetOwner())
				child:SetCreator(self:GetCreator())

				if child.CPPISetOwner then
					child:CPPISetOwner(self:CPPIGetOwner())
				end
			end
		end)
	end

	function ENT:StartTouch(ent)
		if ACCEPTED_ENERGY_ENTS[ent:GetClass()] then
			local energy_amount = ACCEPTED_ENERGY_ENTS[ent:GetClass()](ent)
			local cur_energy = self:GetNWInt("Energy", 0)
			self:SetNWInt("Energy", math.min(MAX_ENERGY, cur_energy + energy_amount))

			SafeRemoveEntity(ent)

			self:EmitSound(")physics/surfaces/underwater_impact_bullet3.wav", 75, 70)
		end
	end

	function ENT:CanWork()
		if self:GetNWInt("Energy", 0) > 0 then
			local tr = util.TraceLine({
				start = self:GetPos() + self:GetForward() * -20,
				endpos = self:GetPos() + self:GetForward() * -75,
				mask = MASK_SOLID_BRUSHONLY,
			})

			if not tr.Hit then return false end

			return true
		end

		return false
	end

	function ENT:CheckSoundLoop()
		if not self:CanWork() then
			if self.SndLoop then
				self.SndLoop:Stop()
			end

			return
		end

		if not self.SndLoop then
			self.SndLoop = CreateSound(self, "ambient/spacebase/spacebase_drill.wav")
			self.SndLoop:PlayEx(0.75, 75)
		elseif self.SndLoop and not self.SndLoop:IsPlaying() then
			self.SndLoop:Stop()
			self.SndLoop:PlayEx(0.75, 75)
		end
	end

	function ENT:ProcessEnergy()
		if CurTime() >= self.NextEnergyConsumption then
			local cur_energy = self:GetNWInt("Energy", 0)
			self:SetNWInt("Energy", math.max(0, cur_energy - 1))
			self.NextEnergyConsumption = CurTime() + NORMAL_ORE_PRODUCTION_RATE
		end
	end

	function ENT:RotateSaws()
		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetForward(), 90)

		if self:CanWork() then
			ang:RotateAroundAxis(self:GetRight(), CurTime() * 400 % 360)
		end

		for _, saw in ipairs(self:GetChildren()) do
			if IsValid(saw) and saw:GetModel() == "models/props_junk/sawblade001a.mdl" then
				saw:SetAngles(ang)
			end
		end
	end

	function ENT:DrillOres()
		if not self:CanWork() then return end
		if CurTime() < self.NextDrilledOre then return end

		local in_volcano = false
		local ore_rarity = ms.Ores.SelectRarityFromSpawntable()
		local trigger = ms and ms.GetTrigger and ms.GetTrigger("volcano")
		if IsValid(trigger) then
			local mins, maxs = trigger:GetCollisionBounds()
			if self:GetPos():WithinAABox(trigger:GetPos() + mins, trigger:GetPos() + maxs) then
				-- disable that for now
				--in_volcano = true
			end
		end

		local ore = ents.Create("mining_ore")
		ore:SetPos(self:GetPos() + self:GetForward() * 75)
		ore:SetRarity(in_volcano and ARGONITE_RARITY or ore_rarity)
		ore:Spawn()
		ore:PhysWake()

		if self.CPPIGetOwner then
			ore.GraceOwner = self:CPPIGetOwner()
			ore.GraceOwnerExpiry = CurTime() + (60 * 60)
			SafeRemoveEntityDelayed(ore, 2 * 60)
		end

		constraint.NoCollide(ore, self, 0, 0)

		self.NextDrilledOre = CurTime() + (in_volcano and ARGONITE_ORE_PRODUCTION_RATE or NORMAL_ORE_PRODUCTION_RATE)
	end

	function ENT:Think()
		self:CheckSoundLoop()
		self:ProcessEnergy()
		self:RotateSaws()
		self:DrillOres()

		self:NextThink(CurTime())
		return true
	end

	function ENT:OnRemove()
		if self.SndLoop then
			self.SndLoop:Stop()
		end
	end
end

if CLIENT then
	local MAT = Material("models/props_combine/coredx70")
	if MAT:IsError() then
		MAT = Material("models/props_lab/cornerunit_cloud") -- fallback for people who dont have ep1
	end

	hook.Add("OnEntityCreated", "mining_drill_saw_mat", function(ent)
		if ent:GetModel() ~= "models/props_junk/sawblade001a.mdl" then return end
		if isfunction(ent.RenderOverride) then return end

		local parent = ent:GetParent()
		if IsValid(parent) and parent:GetClass() == "mining_drill" then
			ent.RenderOverride = function(self)
				local color = ms.Ores.__R[ARGONITE_RARITY].PhysicalColor
				render.SetColorModulation(color.r / 100, color.g / 100, color.b / 100)
				render.MaterialOverride(MAT)
				self:DrawModel()
				render.MaterialOverride()
				render.SetColorModulation(1, 1, 1)
			end
		end
	end)

	function ENT:ShouldDrawText()
		if LocalPlayer():EyePos():DistToSqr(self:WorldSpaceCenter()) <= TEXT_DIST * TEXT_DIST then return true end
		if LocalPlayer():GetEyeTrace().Entity == self then return true end

		return false
	end

	local WHITE_COLOR = Color(255, 255, 255)
	function ENT:Draw()
		self:DrawModel()
	end

	hook.Add("HUDPaint", "mining_drill", function()
		for _, drill in ipairs(ents.FindByClass("mining_drill")) do
			if drill:ShouldDrawText() then
				local pos = drill:WorldSpaceCenter():ToScreen()
				local text = ("%d%%"):format((drill:GetNWInt("Energy", 0) / MAX_ENERGY) * 100)
				surface.SetFont("DermaLarge")
				local tw, th = surface.GetTextSize(text)
				surface.SetTextColor(WHITE_COLOR)
				surface.SetTextPos(pos.x - tw / 2, pos.y - th / 2)
				surface.DrawText(text)

				text = "Energy"
				tw, th = surface.GetTextSize(text)
				surface.SetTextPos(pos.x - tw / 2, pos.y - th * 2)
				surface.DrawText(text)
			end
		end
	end)
end