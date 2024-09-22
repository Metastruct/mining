AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Resource Depot"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_ore_storage"
ENT.IconOverride = "entities/ma_storage_v2.png"
ENT.Description = "The resource depot is used to store your ores and ingots. Nothing special here."

require("ma_orchestrator")
_G.MA_Orchestrator.RegisterInput(ENT, "ores", "ORE", "Ores", "Standard ore input.")
_G.MA_Orchestrator.RegisterInput(ENT, "ingots", "INGOT", "Ingots", "Standard ingot input.")

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

		Ores.Automation.PrepareForDuplication(self)

		if _G.WireLib then
			_G.WireLib.CreateOutputs(self, {
				"OreCounts (Outputs an array of the counts of each ore stored in the storage) [ARRAY]",
				"OreNames (Outputs an array of the names of each ore stored in the storage) [ARRAY]"
			})

			_G.WireLib.TriggerOutput(self, "OreCounts", {})
			_G.WireLib.TriggerOutput(self, "OreNames", {})
		end
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if input_data.Id ~= "ores" and input_data.Id ~= "ingots" then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if input_data.Id == "ores" and output_data.Type == "ORE" then
			if not istable(output_data.Ent.OreQueue) then return end
			if #output_data.Ent.OreQueue == 0 then return end

			local rarity = table.remove(output_data.Ent.OreQueue, 1)
			if not self.Ores[rarity] then
				self.Ores[rarity] = 0
			end

			self.Ores[rarity] = self.Ores[rarity] + 1
			self:UpdateNetworkOreData()
		elseif input_data.Id == "ingots" and output_data.Type == "INGOT" then
			if not istable(output_data.Ent.IngotQueue) then return end
			if #output_data.Ent.IngotQueue == 0 then return end

			local rarity = table.remove(output_data.Ent.IngotQueue, 1)
			if not self.Ores[rarity] then
				self.Ores[rarity] = 0
			end

			self.Ores[rarity] = self.Ores[rarity] + Ores.Automation.IngotSize
			self:UpdateNetworkOreData()
		end
	end

	function ENT:UpdateNetworkOreData()
		local t = {}
		local wire_counts = {}
		local wire_names = {}
		for rarity, amount in pairs(self.Ores) do
			table.insert(t, ("%s=%s"):format(rarity, amount))

			local ore_data = Ores.__R[rarity]
			if ore_data then
				table.insert(wire_counts, amount)
				table.insert(wire_names, ore_data.Name or "Unknown")
			end
		end

		if _G.WireLib then
			_G.WireLib.TriggerOutput(self, "OreCounts", wire_counts)
			_G.WireLib.TriggerOutput(self, "OreNames", wire_names)
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
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnDrawEntityInfo()
		local global_ore_data = self:GetNWString("OreData", ""):Trim()
		if #global_ore_data < 1 then return end

		local data = {
			{ Type = "Label", Text = self.PrintName:upper(), Border = true },
		}

		for i, data_chunk in ipairs(global_ore_data:Split(";")) do
			local rarity_rata = data_chunk:Split("=")
			local ore_data = Ores.__R[tonumber(rarity_rata[1])]

			table.insert(data, { Type = "Data", Label = ore_data.Name, Value = rarity_rata[2], LabelColor = ore_data.HudColor, ValueColor = ore_data.HudColor })
		end

		if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
			table.insert(data, { Type = "Action", Binding = "+use", Text = "CLAIM" })
		end

		return data
	end
end