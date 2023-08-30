AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Fuel Tank"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_fuel_tank"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_c17/oildrum001.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:SetBuoyancyRatio(1)
			phys:Wake()
		end

		self:Activate()
		self:SetUseType(SIMPLE_USE)

		Ores.Automation.PrepareForDuplication(self)
		Ores.Automation.RegisterEnergyEntityClass(
			"Fuel",
			self:GetClass(),
			function(ent) return ent:GetNWInt("CoalCount", 0) end,
			function(ent, value) ent:SetNWInt("CoalCount", value) end
		)

		timer.Simple(0, function()
			if not IsValid(self) then return end
			Ores.Automation.ReplicateOwnership(self, self)
		end)

		if _G.WireLib then
			_G.WireLib.CreateOutputs(self, {
				"Amount (Outputs the current amount of coal filled in) [NORMAL]",
				"MaxCapacity (Outputs the maximum coal capacity) [NORMAL]"
			})

			_G.WireLib.TriggerOutput(self, "Amount", 0)
			_G.WireLib.TriggerOutput(self, "MaxCapacity", Ores.Automation.BatteryCapacity)
		end
	end

	function ENT:Use(activator, caller)
		if not activator:IsPlayer() then return end

		local coalRarity = Ores.Automation.GetOreRarityByName("Coal")
		local amount = Ores.GetPlayerOre(activator, coalRarity)
		if amount < 1 then return end

		local curAmount = self:GetNWInt("CoalCount", 0)
		local amountToAdd = math.min(Ores.Automation.BatteryCapacity - curAmount, amount)
		if amountToAdd == 0 then return end

		local newAmount = math.min(Ores.Automation.BatteryCapacity, curAmount + amountToAdd)
		self:SetNWInt("CoalCount", newAmount)

		if _G.WireLib then
			_G.WireLib.TriggerOutput(self, "Amount", newAmount)
		end

		Ores.TakePlayerOre(activator, coalRarity, amountToAdd)
	end

	function ENT:GravGunPickupAllowed(ply)
		if not self.CPPIGetOwner then return end
		return ply == self:CPPIGetOwner()
	end

	function ENT:UpdateTransmitState()
		return TRANSMIT_ALWAYS
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnGraphDraw(x, y)
		local coalRarity = Ores.Automation.GetOreRarityByName("Coal")
		local coalColor = Ores.__R[coalRarity].HudColor
		local GU = Ores.Automation.GraphUnit

		surface.SetDrawColor(coalColor)
		surface.DrawRect(x - GU / 4, y - GU / 4, GU / 2, GU / 2)

		surface.SetDrawColor(125, 125, 125, 255)
		surface.DrawOutlinedRect(x - GU / 4, y - GU / 4, GU / 2, GU / 2, 2)
	end

	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			local data = {
				{ Type = "Label", Text = "TANK", Border = true },
				{ Type = "Data", Label = "FUEL", Value = self:GetNWInt("CoalCount", 0), MaxValue = ms.Ores.Automation.BatteryCapacity },
			}

			if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
				table.insert(data, { Type = "Action", Binding = "+use", Text = "FILL" })
			end

			self.MiningFrameInfo = data
		end

		self.MiningFrameInfo[2].Value = self:GetNWInt("CoalCount", 0)
		if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() and not self.MiningFrameInfo[3] then
			table.insert(self.MiningFrameInfo, { Type = "Action", Binding = "+use", Text = "FILL" })
		end

		return self.MiningFrameInfo
	end
end