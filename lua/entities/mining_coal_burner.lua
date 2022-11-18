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
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	local COLOR_WHITE = Color(255, 255, 255)
	hook.Add("HUDPaint", "mining_coal_burner", function()
		local color = COLOR_WHITE
		for _, burner in ipairs(ents.FindByClass("mining_coal_burner")) do
			if Ores.Automation.ShouldDrawText(burner) then
				local pos = burner:WorldSpaceCenter():ToScreen()
				local text = ("%d%%"):format((burner:GetNWInt("CoalCount", 0) / Ores.Automation.BatteryCapacity) * 100)
				surface.SetFont("DermaLarge")
				local tw, th = surface.GetTextSize(text)
				surface.SetTextColor(color)
				surface.SetTextPos(pos.x - tw / 2, pos.y - th / 2)
				surface.DrawText(text)

				text = "Coal Burner"
				tw, th = surface.GetTextSize(text)
				surface.SetTextPos(pos.x - tw / 2, pos.y - th * 2)
				surface.DrawText(text)

				local key = input.LookupBinding("+use", true) or "?"
				text = ("[ %s ] Fill"):format(key:upper())
				tw, th = surface.GetTextSize(text)
				surface.SetTextPos(pos.x - tw / 2, pos.y + th)
				surface.DrawText(text)
			end
		end
	end)
end