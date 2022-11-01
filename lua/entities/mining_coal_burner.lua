AddCSLuaFile()

local CONTAINER_CAPACITY = 150
local COAL_RARITY = 0
local TEXT_DIST = 150

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
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetUseType(SIMPLE_USE)

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x1.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetPos(self:GetPos() + self:GetForward() * 24)
		self.Frame:SetAngles(self:GetAngles())
		self.Frame:Spawn()
		self.Frame:SetParent(self)

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

	function ENT:Use(activator, caller)
		if not activator:IsPlayer() then return end

		local amount = ms.Ores.GetPlayerOre(activator, COAL_RARITY)
		if amount < 1 then return end

		local curAmount = self:GetNWInt("CoalCount", 0)
		local amountToAdd = math.min(CONTAINER_CAPACITY - curAmount, amount)
		local newAmount = math.min(CONTAINER_CAPACITY, curAmount + amountToAdd)
		self:SetNWInt("CoalCount", newAmount)

		ms.Ores.TakePlayerOre(activator, COAL_RARITY, amountToAdd)
		self:Fire("ignite")
	end
end

if CLIENT then
	function ENT:ShouldDrawText()
		if LocalPlayer():EyePos():DistToSqr(self:WorldSpaceCenter()) <= TEXT_DIST * TEXT_DIST then return true end
		if LocalPlayer():GetEyeTrace().Entity == self then return true end

		return false
	end

	function ENT:Draw()
		self:DrawModel()
	end

	local COLOR_WHITE = Color(255, 255, 255)
	hook.Add("HUDPaint", "mining_coal_burner", function()
		local color = COLOR_WHITE--ms.Ores.__R[COAL_RARITY].PhysicalColor
		for _, battery in ipairs(ents.FindByClass("mining_coal_burner")) do
			if battery:ShouldDrawText() then
				local pos = battery:WorldSpaceCenter():ToScreen()
				local text = ("%d%%"):format((battery:GetNWInt("CoalCount", 0) / CONTAINER_CAPACITY) * 100)
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