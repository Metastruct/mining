AddCSLuaFile()

local TEXT_DIST = 150

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ore Storage"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_ore_storage"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_wasteland/kitchen_fridge001a.mdl")
		self:SetMaterial("phoenix_storms/OfficeWindow_1-1")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetTrigger(true)
		--self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		--self:PhysWake()

		self.Ores = {}
	end

	function ENT:UpdateNetworkOreData()
		local t = {}
		for rarity, amount in pairs(self.Ores) do
			table.insert(t, ("%s=%s"):format(rarity, amount))
		end

		self:SetNWString("OreData", table.concat(t, ";"))
	end

	function ENT:Touch(ent)
		if ent:GetClass() ~= "mining_ore" then return end
		if ent.MiningContainerCollected then return end

		self.Ores[ent:GetRarity()] = (self.Ores[ent:GetRarity()] or 0) + 1
		ent.MiningContainerCollected = true

		self:UpdateNetworkOreData()
		SafeRemoveEntity(ent)
	end

	function ENT:StartTouch() end

	function ENT:Use(activator)
		if not activator:IsPlayer() then return end
		if self.CPPIGetOwner and self:CPPIGetOwner() ~= activator then return end

		for rarity, amount in pairs(self.Ores) do
			if amount > 0 then
				ms.Ores.GivePlayerOre(activator, rarity, amount)
			end

			self.Ores[rarity] = nil
		end

		self:UpdateNetworkOreData()
		self:EmitSound(")physics/surfaces/underwater_impact_bullet3.wav", 75, 70)
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

	hook.Add("HUDPaint", "mining_ore_storage", function()
		for _, storage in ipairs(ents.FindByClass("mining_ore_storage")) do
			if storage:ShouldDrawText() then
				local pos = storage:WorldSpaceCenter():ToScreen()
				surface.SetFont("DermaLarge")

				local global_ore_data = storage:GetNWString("OreData", ""):Trim()
				if #global_ore_data > 0 then
					local data = global_ore_data:Split(";")
					for i, data_chunk in ipairs(data) do
						local rarity_data = data_chunk:Split("=")
						local ore_data = ms.Ores.__R[tonumber(rarity_data[1])]
						local text = ("x%s %s"):format(rarity_data[2], ore_data.Name)

						surface.SetTextColor(ore_data.HudColor)
						surface.SetTextPos(pos.x, pos.y + ((i - 1) * draw.GetFontHeight("DermaLarge")))
						surface.DrawText(text)
					end
				end
			end
		end
	end)
end