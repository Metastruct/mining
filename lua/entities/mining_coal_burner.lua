AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Coal Burner"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_coal_burner"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_c17/TrapPropeller_Engine.mdl")
		self:SetModelScale(0.5)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self:PhysWake()
		self:Activate()
		self:SetUseType(SIMPLE_USE)

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x1.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetModelScale(0.5)
		self.Frame:SetPos(self:GetPos() + self:GetForward() * 24 / 2)
		self.Frame:SetAngles(self:GetAngles())
		self.Frame:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self.Frame:Spawn()
		self.Frame:SetParent(self)
		self.Frame:SetTransmitWithParent(true)

		Ores.Automation.PrepareForDuplication(self)

		timer.Simple(0, function()
			if not IsValid(self) then return end
			Ores.Automation.ReplicateOwnership(self, self)
		end)
	end

	function ENT:Use(activator, caller)
		if not activator:IsPlayer() then return end

		local coalRarity = Ores.Automation.GetOreRarityByName("Coal")
		local amount = ms.Ores.GetPlayerOre(activator, coalRarity)
		if amount < 1 then return end

		local curAmount = self:GetNWInt("CoalCount", 0)
		local amountToAdd = math.min(Ores.Automation.BatteryCapacity - curAmount, amount)
		if amountToAdd == 0 then return end

		local newAmount = math.min(Ores.Automation.BatteryCapacity, curAmount + amountToAdd)
		self:SetNWInt("CoalCount", newAmount)

		ms.Ores.TakePlayerOre(activator, coalRarity, amountToAdd)
		self:Fire("ignite")
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
				{ Type = "Label", Text = "BURNER", Border = true },
				{ Type = "Data", Label = "FUEL", Value = self:GetNWInt("CoalCount", 0), MaxValue = ms.Ores.Automation.BatteryCapacity },
			}

			if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
				table.insert(data, { Type = "Action", Binding = "+use", Text = "FILL" })
			end

			self.MiningFrameInfo = data
		end

		self.MiningFrameInfo[2].Value = self:GetNWInt("CoalCount", 0)
		if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() and not self.MiningFrameInfo[3] then
			table.insert(data, { Type = "Action", Binding = "+use", Text = "FILL" })
		end

		return self.MiningFrameInfo
	end
end