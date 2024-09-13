AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ore Storage V2"
ENT.Author = "Earu"
ENT.Category = "Mining V2"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_ore_storage"
ENT.IconOverride = "entities/ma_storage_v2.png"

if SERVER then
	resource.AddFile("materials/entities/ma_storage_v2.png")

	function ENT:Initialize()
		self:SetModel("models/props_wasteland/kitchen_fridge001a.mdl")
		self:SetMaterial("phoenix_storms/OfficeWindow_1-1")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysWake()
		self.Ores = {}

		_G.MA_Orchestrator.RegisterInput(self, "ores", "ORE", "Ores", "Standard ore input.")
		_G.MA_Orchestrator.RegisterInput(self, "ingots", "INGOT", "Ingots", "Standard ingot input.")

		Ores.Automation.PrepareForDuplication(self)
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if input_data.Id ~= "ores" and input_data.Id ~= "ingots" then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if input_data.Id ~= "ores" and input_data.Id ~= "ingots" then return end
		if input_data.Id == "ores" and not istable(output_data.Ent.OreQueue) then return end
		if input_data.Id == "ingots" and not istable(output_data.Ent.IngotQueue) then return end

		local rarity = input_data.Id == "ingots" and table.remove(output_data.Ent.IngotQueue, 1) or table.remove(output_data.Ent.OreQueue, 1)
		if not self.Ores[rarity] then
			self.Ores[rarity] = 0
		end

		self.Ores[rarity] = self.Ores[rarity] + (input_data.Id == "ingots" and Ores.Automation.IngotSize or 1)
		self:UpdateNetworkOreData()
	end

	function ENT:UpdateNetworkOreData()
		local t = {}
		for rarity, amount in pairs(self.Ores) do
			table.insert(t, ("%s=%s"):format(rarity, amount))
		end

		self:SetNWString("OreData", table.concat(t, ";"))
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
	function ENT:Initialize()
		_G.MA_Orchestrator.RegisterInput(self, "ores", "ORE", "Ores", "Standard ore input.")
		_G.MA_Orchestrator.RegisterInput(self, "ingots", "INGOT", "Ingots", "Standard ingot input.")
	end

	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnDrawEntityInfo()
		local globalOreData = self:GetNWString("OreData", ""):Trim()
		if #globalOreData < 1 then return end

		local data = {
			{ Type = "Label", Text = self.PrintName:upper(), Border = true },
		}

		for i, dataChunk in ipairs(globalOreData:Split(";")) do
			local rarityData = dataChunk:Split("=")
			local oreData = Ores.__R[tonumber(rarityData[1])]

			table.insert(data, { Type = "Data", Label = oreData.Name, Value = rarityData[2], LabelColor = oreData.HudColor, ValueColor = oreData.HudColor })
		end

		if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
			table.insert(data, { Type = "Action", Binding = "+use", Text = "CLAIM" })
		end

		return data
	end
end