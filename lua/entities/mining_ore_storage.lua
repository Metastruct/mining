AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

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
		self:UseTriggerBounds(true, 16)
		self:PhysWake()

		self.BadOreRarities = {}
		self.Ores = {}

		for _, oreName in pairs(Ores.Automation.NonStorableOres) do
			local rarity = Ores.Automation.GetOreRarityByName(oreName)
			if rarity == -1 then continue end

			self.BadOreRarities[rarity] = true
		end

		Ores.Automation.PrepareForDuplication(self)
	end

	function ENT:UpdateNetworkOreData()
		local t = {}
		for rarity, amount in pairs(self.Ores) do
			table.insert(t, ("%s=%s"):format(rarity, amount))
		end

		self:SetNWString("OreData", table.concat(t, ";"))
	end

	function ENT:Touch(ent)
		if ent.MiningContainerCollected then return end

		local className = ent:GetClass()
		if className ~= "mining_ore_ingot" and className ~= "mining_ore" then return end

		if self.CPPIGetOwner and ent.GraceOwner ~= self:CPPIGetOwner() then return end -- lets not have people highjack each others

		local rarity = ent:GetRarity()
		if not self.BadOreRarities[rarity] then
			local value = className == "mining_ore_ingot" and Ores.Automation.IngotSize or 1
			self.Ores[rarity] = (self.Ores[rarity] or 0) + value
			self:UpdateNetworkOreData()
		end

		ent.MiningContainerCollected = true
		SafeRemoveEntity(ent)
	end

	-- fallback in case trigger stops working
	function ENT:PhysicsCollide(data)
		if not IsValid(data.HitEntity) then return end

		self:Touch(data.HitEntity)
	end

	function ENT:Use(activator)
		if not activator:IsPlayer() then return end
		if self.CPPIGetOwner and self:CPPIGetOwner() ~= activator then return end

		for rarity, amount in pairs(self.Ores) do
			if amount > 0 then
				Ores.GivePlayerOre(activator, rarity, amount)
			end

			self.Ores[rarity] = nil
		end

		self:UpdateNetworkOreData()
		self:EmitSound(")physics/surfaces/underwater_impact_bullet3.wav", 75, 70)
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnGraphDraw(x, y)
		local GU = Ores.Automation.GraphUnit

		surface.SetFont("DermaDefaultBold")
		local th = draw.GetFontHeight("DermaDefaultBold")
		local globalOreData = self:GetNWString("OreData", ""):Trim()
		if #globalOreData < 1 then
			surface.SetDrawColor(125, 125, 125, 255)
			surface.DrawRect(x - GU / 2, y - GU / 2, GU, GU)

			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawOutlinedRect(x - GU / 2, y - GU / 2, GU, GU, 2)
			return
		end

		local data = globalOreData:Split(";")
		if #data < 1 then return end

		surface.SetDrawColor(125, 125, 125, 255)
		surface.DrawRect(x - GU / 2, y - GU / 2, GU + 10, #data * th + 10)

		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawOutlinedRect(x - GU / 2, y - GU / 2, GU + 10, #data * th + 10, 2)

		for i, dataChunk in ipairs(data) do
			local rarityData = dataChunk:Split("=")
			local oreData = Ores.__R[tonumber(rarityData[1])]
			local text = ("x%s"):format(rarityData[2])

			surface.SetTextColor(oreData.HudColor)
			surface.SetTextPos(x - 15, y - GU / #data - #data + ((i - 1) * th))
			surface.DrawText(text)
		end
	end

	function ENT:OnDrawEntityInfo()
		local globalOreData = self:GetNWString("OreData", ""):Trim()
		if #globalOreData < 1 then return end

		local data = {
			{ Type = "Label", Text = "STORAGE", Border = true },
		}

		for i, dataChunk in ipairs(globalOreData:Split(";")) do
			local rarityData = dataChunk:Split("=")
			local oreData = Ores.__R[tonumber(rarityData[1])]

			table.insert(data, { Type = "Data", Label = oreData.Name:upper(), Value = rarityData[2], LabelColor = oreData.HudColor, ValueColor = oreData.HudColor })
		end

		if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
			table.insert(data, { Type = "Action", Binding = "+use", Text = "CLAIM" })
		end

		return data
	end
end