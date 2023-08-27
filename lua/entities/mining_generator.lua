AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Generator"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_generator"

local function can_work(self)
	if not self:GetNWBool("IsPowered", true) then return false end
	if self:GetNW2Int("Energy", 0) < 1 then return false end

	return true
end

if SERVER then
	ENT.NextSoundCheck = 0
	ENT.NextLinkCheck = 0

	function ENT:Initialize()
		self:SetModel("models/props_wasteland/laundry_washer003.mdl")
		self:SetMaterial("phoenix_storms/future_vents")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self.NextSoundCheck = 0
		self.NextLinkCheck = 0
		self.Linked = {}
		self:SetNWBool("IsPowered", true)

		timer.Simple(0, function()
			if not IsValid(self) then return end
			Ores.Automation.ReplicateOwnership(self, self)

			self.SndLoop = self:StartLoopingSound("ambient/steam_drum.wav")
		end)

		self.EnergySettings = {
			Type = "Energy",
			MaxValue = Ores.Automation.BatteryCapacity * 10,
			ConsumptionRate = 10,
			ConsumptionAmount = 1,
		}

		Ores.Automation.PrepareForDuplication(self)
		Ores.Automation.RegisterEnergyPoweredEntity(self, { self.EnergySettings })

		if _G.WireLib then
			self.Inputs = _G.WireLib.CreateInputs(self, {"Active (If this is non-zero, activate the drill)"})
		end
	end

	function ENT:TriggerInput(port, state)
		if port == "Active" then self:SetNWBool("IsPowered", tobool(state)) end
	end

	function ENT:CheckSoundLoop(time)
		if time < self.NextSoundCheck then return end

		if not can_work(self) then
			if self.SndLoop and self.SndLoop ~= -1 then
				self:StopLoopingSound(self.SndLoop)
			end

			self.SndLoop = nil
			self.NextSoundCheck = time + 5
			return
		end

		if not self.SndLoop or self.SndLoop == -1 then
			self.SndLoop = self:StartLoopingSound("ambient/steam_drum.wav")
		end

		self.NextSoundCheck = time + 5
	end

	function ENT:CheckNearbyEntities(time)
		if time < self.NextLinkCheck then return end

		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		local argoniteColor = Ores.__R[argoniteRarity].PhysicalColor
		local vecZero = Vector(0, 0, 0)
		local perc = self:GetNW2Int("Energy", 0) / self:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity * 6)
		local added = false

		for _, ent in ipairs(ents.FindInSphere(self:WorldSpaceCenter(), 2000)) do
			if not Ores.Automation.IsEnergyPoweredEntity(ent, "Energy") then continue end
			if self.Linked[ent] then continue end
			if IsValid(ent.mining_generator_linked) then continue end
			if ent:GetClas() == self:GetClass() then continue end

			local entOwner = ent.CPPIGetOwner and ent:CPPIGetOwner()
			local owner = self.CPPIGetOwner and self:CPPIGetOwner()

			if entOwner ~= owner then continue end

			local rope = constraint.CreateKeyframeRope(self:WorldSpaceCenter(), 1, "cable/cable2", self, self, vecZero, 0, ent, vecZero, 0, {})
			rope:SetColor(argoniteColor)

			local canConsumeEnergy = ent.CanConsumeEnergy or function() return true end
			function ent:CanConsumeEnergy(...)
				if IsValid(self.mining_generator_linked) then return false end

				return canConsumeEnergy(self, ...)
			end

			local maxEnergy = ent:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity)
			ent:SetNW2Int("Energy", maxEnergy * perc)

			ent.mining_generator_linked = self
			self.Linked[ent] = true
			self.EnergySettings.ConsumptionAmount = self.EnergySettings.ConsumptionAmount + 1
			added = true
		end

		if added then
			self:EmitSound("ambient/energy/weld2.wav")
		end

		self.NextLinkCheck = time + 5
	end

	function ENT:CanConsumeEnergy()
		if not can_work(self) then return false end

		return true
	end

	function ENT:ConsumedEnergy(energyType, oldAmount, newAmount, amountChanged)
		if energyType ~= "Energy" then return end

		local perc = newAmount / self:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity * 6)
		for linkedEnt, _ in pairs(self.Linked) do
			if IsValid(linkedEnt) then
				local maxEnergy = linkedEnt:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity)
				linkedEnt:SetNW2Int("Energy", maxEnergy * perc)
			end
		end
	end

	function ENT:Think()
		local time = CurTime()

		self:CheckSoundLoop(time)
		self:CheckNearbyEntities(time)
	end

	function ENT:OnRemove()
		if self.SndLoop and self.SndLoop ~= -1 then
			self:StopLoopingSound(self.SndLoop)
		end

		for linkedEnt, _ in pairs(self.Linked) do
			if IsValid(linkedEnt) then
				linkedEnt.mining_generator_linked = nil
				linkedEnt:SetNW2Int("Energy", 0)
			end
		end
	end

	hook.Add("EntityRemoved", "mining_generator", function(ent)
		if not Ores.Automation.IsEnergyPoweredEntity(ent, "Energy") then return end

		local generator = ent.mining_generator_linked
		if not IsValid(generator) then return end

		generator.Linked[ent] = nil
		generator.EnergySettings.ConsumptionAmount = math.max(1, generator.EnergySettings.ConsumptionAmount - 1)
	end)
end

if CLIENT then
	local WHEEL_MDL = "models/props_phx/construct/metal_wire_angle360x2.mdl"
	local function addWheelEntity(self, offset)
		local wheel = ClientsideModel(WHEEL_MDL)
		local scale = Vector(0.6, 0.6, 1)
		local mat = Matrix()
		mat:Scale(scale)
		wheel:EnableMatrix("RenderMultiply", mat)
		wheel:SetPos(self:GetPos() + offset)
		wheel:Spawn()
		wheel:SetParent(self)

		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		wheel.RenderOverride = function()
			local color = Ores.__R[argoniteRarity].PhysicalColor
			render.SetColorModulation(color.r / 100, color.g / 100, color.b / 100)
			render.MaterialOverride(Ores.Automation.EnergyMaterial)
			wheel:DrawModel()
			render.MaterialOverride()
			render.SetColorModulation(1, 1, 1)
		end

		return wheel
	end

	function ENT:Initialize()
		self.Wheel = addWheelEntity(self, self:GetForward() * 48 + self:GetRight() * 2)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetForward(), 90)
		self.Wheel:SetAngles(ang)
	end

	function ENT:Draw()
		self:DrawModel()

		if IsValid(self.Wheel) then
			self.Wheel:SetPos(self:GetPos() + self:GetForward() * 48 + self:GetRight() * 2)
			self.Wheel:SetParent(self)

			local ang = self:GetAngles()
			ang:RotateAroundAxis(self:GetRight(), 90)

			if can_work(self) then
				ang:RotateAroundAxis(self:GetForward(), CurTime() * 100 % 360)
			end

			self.Wheel:SetAngles(ang)

			self.Wheel:DrawModel()
		end
	end

	function ENT:OnRemove()
		SafeRemoveEntity(self.Wheel)
	end

	function ENT:OnGraphDraw(x, y)
		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		local argoniteColor = Ores.__R[argoniteRarity].HudColor
		local GU = Ores.Automation.GraphUnit

		surface.SetDrawColor(argoniteColor)
		surface.SetMaterial(Ores.Automation.EnergyMaterial)
		surface.DrawTexturedRect(x - GU / 2, y - GU / 2, GU, GU)

		surface.SetDrawColor(255, 204, 0)
		surface.DrawOutlinedRect(x - GU / 2, y - GU / 2, GU, GU, 2)

		surface.SetTextColor(255, 255, 255, 255)
		local perc = (math.Round((self:GetNW2Int("Energy", 0) / self:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity * 3)) * 100)) .. "%"
		surface.SetFont("DermaDefault")
		local tw, th = surface.GetTextSize(perc)
		surface.SetTextPos(x - tw / 2, y - th / 2)
		surface.DrawText(perc)

		local state = can_work(self, CurTime())
		surface.SetDrawColor(state and 0 or 255, state and 255 or 0, 0, 255)
		surface.DrawOutlinedRect(x - GU / 2 + 2, y - GU / 2 + 2, GU - 4, 2)
	end

	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			self.MiningFrameInfo = {
				{ Type = "Label", Text = "GENERATOR", Border = true },
				{ Type = "Data", Label = "ENERGY", Value = self:GetNW2Int("Energy", 0), MaxValue = self:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity * 3) },
				{ Type = "State", Value = can_work(self) }
			}
		end

		self.MiningFrameInfo[2].Value = self:GetNW2Int("Energy", 0)
		self.MiningFrameInfo[3].Value = can_work(self)
		return self.MiningFrameInfo
	end
end