AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ore Smelter"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = false
ENT.ClassName = "mining_ore_smelter"

local STACK_SIZE = 5
if SERVER then
	function ENT:Initialize()
		self:SetModel("models/xqm/podremake.mdl")
		self:SetMaterial("phoenix_storms/future_vents")
		self:SetModelScale(0.4)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_BBOX)
		self:SetSolid(SOLID_BBOX)
		self:SetUseType(SIMPLE_USE)
		self:SetTrigger(true)
		self:UseTriggerBounds(true, 32)
		self:PhysWake()
		self:SetNWInt("Energy", 0)
		self:SetNWBool("IsPowered", true)
		self:Activate()
		self.NextEnergyEnt = 0
		self.NextEnergyConsumption = 0
		self.MaxEnergy = Ores.Automation.BatteryCapacity

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x2.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetPos(self:GetPos() + self:GetUp() * -35 + self:GetRight() * -24)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetForward(), 90)
		ang:RotateAroundAxis(self:GetRight(), 90)

		self.Frame:SetAngles(ang)
		self.Frame:Spawn()
		self.Frame:SetParent(self)

		self.Frame2 = ents.Create("prop_physics")
		self.Frame2:SetModel("models/props_phx/construct/metal_tube.mdl")
		self.Frame2:SetMaterial("models/mspropp/metalgrate014a")
		self.Frame2:SetModelScale(0.9)
		self.Frame2:SetPos(self:GetPos() + self:GetUp() * -35 + self:GetRight() * -24)
		self.Frame2:SetAngles(ang)
		self.Frame2:Spawn()
		self.Frame2:SetParent(self)

		timer.Simple(0, function()
			if not IsValid(self) then return end
			Ores.Automation.ReplicateOwnership(self, self)
			self.SndLoop = self:StartLoopingSound("ambient/spacebase/spacebase_drill.wav")
			self:Activate()
		end)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {
				"Active",
			}, {
				"Whether the smelter is active or not",
			})
		end

		self.BadOreRarities = {}
		self.Ores = {}

		for _, oreName in pairs(Ores.Automation.NonStorableOres) do
			local rarity = Ores.Automation.GetOreRarityByName(oreName)
			if rarity == -1 then continue end

			self.BadOreRarities[rarity] = true
		end

		Ores.Automation.PrepareForDuplication(self)
	end

	function ENT:TriggerInput(port, state)
		if not _G.WireLib then return end
		if not isnumber(state) then return end

		if port == "Active" then
			self:SetNWBool("IsPowered", tobool(state))
		end
	end

	function ENT:UpdateNetworkOreData()
		local t = {}
		for rarity, amount in pairs(self.Ores) do
			table.insert(t, ("%s=%s"):format(rarity, amount))
		end

		self:SetNWString("OreData", table.concat(t, ";"))
	end

	function ENT:ProduceRefinedOre(rarity)
	end

	function ENT:SmeltOre(ent)
		if ent.MiningSmelterCollected then return end
		if ent:GetClass() ~= "mining_ore" then return end

		if self.CPPIGetOwner and ent.GraceOwner ~= self:CPPIGetOwner() then return end -- lets not have people highjack each others
		if self:GetNWInt("Energy", 0) <= 0 then return end
		if not self:GetNWBool("IsPowered", true) then return end

		local rarity = ent:GetRarity()
		if not self.BadOreRarities[rarity] then
			local newValue = (self.Ores[rarity] or 0) + 1
			self.Ores[rarity] = newValue
			if newValue >= STACK_SIZE then
				self:ProduceRefinedOre(rarity)
				self.Ores[rarity] = nil
			end

			self:UpdateNetworkOreData()
		end

		ent.MiningSmelterCollected = true
		SafeRemoveEntity(ent)
	end

	function ENT:GainEnergy(ent)
		local className = ent:GetClass()
		local energyAccesors = Ores.Automation.EnergyEntities[className]
		if not energyAccesors then return end

		local time = CurTime()
		if time < self.NextEnergyEnt then return end
		if ent.MiningInvalidPower then return end

		local energyAmount = energyAccesors.Get(ent)
		local curEnergy = self:GetNWInt("Energy", 0)
		local energyToAdd = math.min(self.MaxEnergy - curEnergy, energyAmount)

		self:SetNWInt("Energy", math.min(self.MaxEnergy, curEnergy + energyToAdd))
		energyAccesors.Set(ent, math.max(0, energyAmount - energyToAdd))

		if energyAmount - energyToAdd < 1 then
			SafeRemoveEntity(ent)
			ent.MiningInvalidPower = true
		end

		self:EmitSound(")ambient/machines/thumper_top.wav", 75, 70)
		self.NextEnergyEnt = time + 2
	end

	function ENT:Touch(ent)
		self:SmeltOre(ent)
		self:GainEnergy(ent)
	end

	function ENT:ProcessEnergy(time)
		if time < self.NextEnergyConsumption then return end

		local curEnergy = self:GetNWInt("Energy", 0)
		self:SetNWInt("Energy", math.max(0, curEnergy - 1))
		self.NextEnergyConsumption = time + Ores.Automation.BaseOreProductionRate
	end

	function ENT:Think()
		self:ProcessEnergy(CurTime())
	end

	function ENT:OnRemove()
		SafeRemoveEntity(self.Trigger)
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnGraphDraw(x, y)
		--[[local GU = Ores.Automation.GraphUnit

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
		end]]
	end

	function ENT:OnDrawEntityInfo()
		local data = {
			{ Type = "Label", Text = "SMELTER", Border = true },
			{ Type = "Data", Label = "ENERGY", Value = self:GetNWInt("Energy", 0), MaxValue = Ores.Automation.BatteryCapacity }
		}

		local globalOreData = self:GetNWString("OreData", ""):Trim()
		if #globalOreData < 1 then return data end

		for i, dataChunk in ipairs(globalOreData:Split(";")) do
			local rarityData = dataChunk:Split("=")
			local oreData = Ores.__R[tonumber(rarityData[1])]

			table.insert(data, { Type = "Data", Label = oreData.Name:upper(), Value = ("%s/%d"):format(rarityData[2], STACK_SIZE), LabelColor = oreData.HudColor, ValueColor = oreData.HudColor })
		end

		return data
	end
end