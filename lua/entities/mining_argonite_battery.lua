AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Argonite Battery"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_argonite_battery"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/hunter/blocks/cube075x075x075.mdl")
		self:SetMaterial("phoenix_storms/glass")
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
		self.Frame:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self.Frame:SetPos(self:GetPos() + self:GetForward() * 24 / 2)
		self.Frame:SetAngles(self:GetAngles())
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

		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		local amount = Ores.GetPlayerOre(activator, argoniteRarity)
		if amount < 1 then return end

		local curAmount = self:GetNWInt("ArgoniteCount", 0)
		local amountToAdd = math.min(Ores.Automation.BatteryCapacity - curAmount, amount)
		if amountToAdd == 0 then return end

		local newAmount = math.min(Ores.Automation.BatteryCapacity, curAmount + amountToAdd)
		self:SetNWInt("ArgoniteCount", newAmount)

		Ores.TakePlayerOre(activator, argoniteRarity, amountToAdd)
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
		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		local color = Ores.__R[argoniteRarity].PhysicalColor

		self:DrawModel()

		render.SetColorModulation(color.r / 100, color.g / 100, color.b / 100)
		render.MaterialOverride(Ores.Automation.EnergyMaterial)

		self:DrawModel()

		render.MaterialOverride()
		render.SetColorModulation(1, 1, 1)
	end

	function ENT:OnGraphDraw(x, y)
		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		local argoniteColor = Ores.__R[argoniteRarity].HudColor
		local GU = Ores.Automation.GraphUnit

		surface.SetDrawColor(argoniteColor)
		surface.DrawRect(x - GU / 4, y - GU / 4, GU / 2, GU / 2)

		surface.SetDrawColor(125, 125, 125, 255)
		surface.DrawOutlinedRect(x - GU / 4, y - GU / 4, GU / 2, GU / 2, 2)
	end

	local FRAME_WIDTH = 225
	local FRAME_HEIGHT = 100
	function ENT:OnDrawEntityInfo()
		local owned = self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer()
		local finalHeight = owned and FRAME_HEIGHT + 50 or FRAME_HEIGHT

		local pos = self:WorldSpaceCenter():ToScreen()
		local x, y = pos.x - FRAME_WIDTH / 2, pos.y - finalHeight / 2

		surface.SetMaterial(Ores.Automation.HudFrameMaterial)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(x, y, FRAME_WIDTH, finalHeight)

		surface.SetFont("mining_automation_hud")
		surface.SetTextColor(255, 255, 255, 255)
		surface.SetTextPos(x + Ores.Automation.HudPadding, y + Ores.Automation.HudPadding)
		surface.DrawText("BATTERY")

		surface.SetDrawColor(Ores.Automation.HudSepColor)
		surface.DrawRect(x + Ores.Automation.HudPadding, y + 45, FRAME_WIDTH - Ores.Automation.HudPadding * 2, 2)

		surface.SetTextPos(x + Ores.Automation.HudPadding, y + 55)
		surface.DrawText("CHARGE")

		local perc = (math.Round((self:GetNWInt("ArgoniteCount", 0) / Ores.Automation.BatteryCapacity) * 100))
		local r = 255
		local g = 255 / 100 * perc
		local b = 255 / 100 * perc

		surface.SetTextColor(r, g, b, 255)
		local tw, _ = surface.GetTextSize(perc)
		surface.SetTextPos(x + FRAME_WIDTH - (tw + Ores.Automation.HudPadding * 2), y + 55)
		surface.DrawText(perc)

		if owned then
			local text = ("[ %s ] FILL"):format((input.LookupBinding("+use", true) or "?"):upper())
			surface.SetFont("mining_automation_hud2")
			tw, _ = surface.GetTextSize(text)
			surface.SetTextColor(Ores.Automation.HudActionColor)
			surface.SetTextPos(x + FRAME_WIDTH - (tw + Ores.Automation.HudPadding * 2), y + finalHeight - 50)
			surface.DrawText(text)
		end
	end
end