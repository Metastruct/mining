AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Drill"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_drill"

if SERVER then
	ENT.NextEnergyEnt = 0
	ENT.NextDrilledOre = 0
	ENT.NextEnergyConsumption = 0
	ENT.NextTraceCheck = 0

	local function addSawEntity(self, offset)
		local saw = ents.Create("prop_physics")
		saw:SetModel("models/props_junk/sawblade001a.mdl")
		saw:SetModelScale(2)
		saw:SetPos(self:GetPos() + offset)
		saw:Spawn()
		saw:SetParent(self)
		saw:SetKeyValue("classname", "mining_drill_saw")
		saw.OnEntityCopyTableFinish = function(data) table.Empty(data) end

		return saw
	end

	function ENT:Initialize()
		self:SetModel("models/props_combine/headcrabcannister01a.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self.NextEnergyConsumption = 0
		self.NextDrilledOre = 0
		self.NextEnergyEnt = 0
		self.NextTraceCheck = 0
		self.MaxEnergy = Ores.Automation.BatteryCapacity * 3
		self.WireActive = true

		-- we use this so that its easy for drills to accept power entities
		self.Trigger = ents.Create("base_brush")
		self.Trigger:SetPos(self:WorldSpaceCenter())
		self.Trigger:SetParent(self)
		self.Trigger:SetTrigger(true)
		self.Trigger:SetSolid(SOLID_BBOX)
		self.Trigger:SetNotSolid(true)
		self.Trigger:SetCollisionBounds(Vector(-100, -100, -100), Vector(100, 100, 100))
		self.Trigger.Touch = function(_, ent)
			self:Touch(ent)
		end

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x2.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetPos(self:GetPos() + self:GetForward() * -25 + self:GetRight() * -24)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetForward(), 90)

		self.Frame:SetAngles(ang)
		self.Frame:Spawn()
		self.Frame:SetParent(self)

		addSawEntity(self, self:GetForward() * -40 + self:GetRight() * 10)
		addSawEntity(self, self:GetForward() * -40)
		addSawEntity(self, self:GetForward() * -40 + self:GetRight() * -10)

		timer.Simple(0, function()
			if not IsValid(self) then return end
			Ores.Automation.ReplicateOwnership(self, self)
			self.SndLoop = self:StartLoopingSound("ambient/spacebase/spacebase_drill.wav")
		end)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {
				"Active",
			}, {
				"Whether the drill is active or not",
			})
		end

		Ores.Automation.PrepareForDuplication(self)
	end

	function ENT:TriggerInput(port, state)
		if not _G.WireLib then return end
		if not isnumber(state) then return end

		if port == "Active" then
			self.WireActive = tobool(state)
		end
	end

	function ENT:Touch(ent)
		if ent.MiningInvalidPower then return end
		if CurTime() < self.NextEnergyEnt then return end

		local className = ent:GetClass()
		if not Ores.Automation.EnergyEntities[className] then return end

		local fns = Ores.Automation.EnergyEntities[className]
		local energyAmount = fns.Get(ent)
		local curEnergy = self:GetNWInt("Energy", 0)
		local energyToAdd = math.min(self.MaxEnergy - curEnergy, energyAmount)

		self:SetNWInt("Energy", math.min(self.MaxEnergy, curEnergy + energyToAdd))
		fns.Set(ent, math.max(0, energyAmount - energyToAdd))

		if energyAmount - energyToAdd < 1 then
			SafeRemoveEntity(ent)
			ent.MiningInvalidPower = true
		end

		self:EmitSound(")ambient/machines/thumper_top.wav", 75, 70)
		self.NextEnergyEnt = CurTime() + 2
	end

	local function can_work(self)
		if not self.WireActive and _G.WireLib then return false end
		if CurTime() < self.NextTraceCheck then return self.TraceCheckResult end

		if self:GetNWInt("Energy", 0) > 0 then
			local tr = util.TraceLine({
				start = self:GetPos() + self:GetForward() * -20,
				endpos = self:GetPos() + self:GetForward() * -75,
				mask = MASK_SOLID_BRUSHONLY,
			})

			self.NextTraceCheck = CurTime() + 1.5
			self.TraceCheckResult = tr.Hit
			return tr.Hit
		end

		self.NextTraceCheck = CurTime() + 1.5
		self.TraceCheckResult = false
		return false
	end

	function ENT:CheckSoundLoop()
		if not can_work(self) then
			if self.SndLoop and self.SndLoop ~= -1 then
				self:StopLoopingSound(self.SndLoop)
			end

			self.SndLoop = nil
			return
		end

		if not self.SndLoop or self.SndLoop == -1 then
			self.SndLoop = self:StartLoopingSound("ambient/spacebase/spacebase_drill.wav")
		end
	end

	function ENT:ProcessEnergy()
		if CurTime() >= self.NextEnergyConsumption and can_work(self) then
			local curEnergy = self:GetNWInt("Energy", 0)
			self:SetNWInt("Energy", math.max(0, curEnergy - 1))
			self.NextEnergyConsumption = CurTime() + Ores.Automation.BaseOreProductionRate
		end
	end

	function ENT:RotateSaws()
		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetForward(), 90)

		if can_work(self) then
			ang:RotateAroundAxis(self:GetRight(), CurTime() * 400 % 360)
		end

		for _, saw in ipairs(self:GetChildren()) do
			if IsValid(saw) and saw:GetModel() == "models/props_junk/sawblade001a.mdl" then
				saw:SetAngles(ang)
			end
		end
	end

	function ENT:DrillOres()
		if CurTime() < self.NextDrilledOre then return end
		if not can_work(self) then return end

		local oreRarity = Ores.SelectRarityFromSpawntable()
		local ore = ents.Create("mining_ore")
		ore:SetPos(self:GetPos() + self:GetForward() * 75)
		ore:SetRarity(oreRarity)
		ore:Spawn()
		ore:PhysWake()
		ore:SetNWBool("SpawnedByDrill", true)

		if self.CPPIGetOwner then
			ore.GraceOwner = self:CPPIGetOwner()
			ore.GraceOwnerExpiry = CurTime() + (60 * 60)
			ore:SetCPPIOwner(ore.GraceOwner)
			SafeRemoveEntityDelayed(ore, 2 * 60)
		end

		constraint.NoCollide(ore, self, 0, 0)

		-- efficiency goes up the more its powered:
		-- at less than 33% -> 10s,
		-- less than 66% -> 8s
		-- less than 100% -> 6s
		local effiencyRateIncrease = (math.ceil(self:GetNWInt("Energy", 0) / Ores.Automation.BatteryCapacity) - 1) * 2
		self.NextDrilledOre = CurTime() + (Ores.Automation.BaseOreProductionRate - effiencyRateIncrease)
	end

	function ENT:Think()
		self:CheckSoundLoop()
		self:ProcessEnergy()
		self:RotateSaws()
		self:DrillOres()
	end

	function ENT:OnRemove()
		if self.SndLoop and self.SndLoop ~= -1 then
			self:StopLoopingSound(self.SndLoop)
		end
	end
end

if CLIENT then
	function ENT:Initialize()
		self.MaxEnergy = Ores.Automation.BatteryCapacity * 3
	end

	hook.Add("OnEntityCreated", "mining_drill_saw_mat", function(ent)
		if ent:GetModel() ~= "models/props_junk/sawblade001a.mdl" then return end
		if isfunction(ent.RenderOverride) then return end

		local parent = ent:GetParent()
		if IsValid(parent) and parent:GetClass() == "mining_drill" then
			local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
			ent.RenderOverride = function(self)
				local color = Ores.__R[argoniteRarity].PhysicalColor
				render.SetColorModulation(color.r / 100, color.g / 100, color.b / 100)
				render.MaterialOverride(Ores.Automation.EnergyMaterial)
				self:DrawModel()
				render.MaterialOverride()
				render.SetColorModulation(1, 1, 1)
			end
		end
	end)

	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnGraphDraw(x, y)
		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		local argoniteColor = Ores.__R[argoniteRarity].HudColor
		local GU = Ores.Automation.GraphUnit

		surface.SetDrawColor(argoniteColor)
		surface.SetMaterial(Ores.Automation.EnergyMaterial)
		surface.DrawTexturedRect(x - GU / 2, y - GU / 2, GU, GU)

		surface.SetDrawColor(125, 125, 125, 255)
		surface.DrawOutlinedRect(x - GU / 2, y - GU / 2, GU, GU, 2)

		surface.SetTextColor(255, 255, 255, 255)
		local perc = (math.Round((self:GetNWInt("Energy", 0) / (Ores.Automation.BatteryCapacity * 3)) * 100)) .. "%"
		surface.SetFont("DermaDefault")
		local tw, th = surface.GetTextSize(perc)
		surface.SetTextPos(x - tw / 2, y - th / 2)
		surface.DrawText(perc)
	end

	local WHITE_COLOR = Color(255, 255, 255)
	function ENT:OnDrawEntityInfo()
		local pos = self:WorldSpaceCenter():ToScreen()
		local text = ("%d%%"):format((self:GetNWInt("Energy", 0) / self.MaxEnergy) * 100)
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
