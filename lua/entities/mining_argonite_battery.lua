AddCSLuaFile()

local CONTAINER_CAPACITY = 150
local ARGONITE_RARITY = 18
local TEXT_DIST = 150

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

		local amount = ms.Ores.GetPlayerOre(activator, ARGONITE_RARITY)
		if amount < 1 then return end

		local curAmount = self:GetNWInt("ArgoniteCount", 0)
		local amountToAdd = math.min(CONTAINER_CAPACITY - curAmount, amount)
		local newAmount = math.min(CONTAINER_CAPACITY, curAmount + amountToAdd)
		self:SetNWInt("ArgoniteCount", newAmount)

		ms.Ores.TakePlayerOre(activator, ARGONITE_RARITY, amountToAdd)
	end
end

if CLIENT then
	local MAT = Material("models/props_combine/coredx70")
	if MAT:IsError() then
		MAT = Material("models/props_lab/cornerunit_cloud") -- fallback for people who dont have ep1
	end

	function ENT:ShouldDrawText()
		if LocalPlayer():EyePos():DistToSqr(self:WorldSpaceCenter()) <= TEXT_DIST * TEXT_DIST then return true end
		if LocalPlayer():GetEyeTrace().Entity == self then return true end

		return false
	end

	function ENT:Draw()
		local color = ms.Ores.__R[ARGONITE_RARITY].PhysicalColor

		self:DrawModel()

		render.SetColorModulation(color.r / 100, color.g / 100, color.b / 100)
		render.MaterialOverride(MAT)

		self:DrawModel()

		render.MaterialOverride()
		render.SetColorModulation(1, 1, 1)
	end

	hook.Add("HUDPaint", "mining_argonite_battery", function()
		local color = ms.Ores.__R[ARGONITE_RARITY].PhysicalColor
		for _, battery in ipairs(ents.FindByClass("mining_argonite_battery")) do
			if battery:ShouldDrawText() then
				local pos = battery:WorldSpaceCenter():ToScreen()
				local text = ("%d%%"):format((battery:GetNWInt("ArgoniteCount", 0) / CONTAINER_CAPACITY) * 100)
				surface.SetFont("DermaLarge")
				local tw, th = surface.GetTextSize(text)
				surface.SetTextColor(color)
				surface.SetTextPos(pos.x - tw / 2, pos.y - th / 2)
				surface.DrawText(text)

				text = "Argonite Battery"
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