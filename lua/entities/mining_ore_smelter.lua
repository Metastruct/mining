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

function ENT:CanWork()
	return self:GetNWInt("Energy", 0) > 0 and self:GetNWInt("Fuel", 0) > 0
end

local STACK_SIZE = 5
local MAX_COAL = 50

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
		self:SetNWBool("IsPowered", true)
		self:Activate()

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
			self.SndLoop = self:StartLoopingSound("ambient/machines/machine_whine1.wav")
			self:Activate()

			self:SetNWInt("Energy", 100)
		end)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {
				"Active",
			}, {
				"Whether the smelter is active or not",
			})
		end

		self.NextSoundCheck = 0
		self.BadOreRarities = {}
		self.Ores = {}

		for _, oreName in pairs(Ores.Automation.NonStorableOres) do
			local rarity = Ores.Automation.GetOreRarityByName(oreName)
			if rarity == -1 then continue end

			self.BadOreRarities[rarity] = true
		end

		Ores.Automation.PrepareForDuplication(self)
		Ores.Automation.RegisterEnergyPoweredEntity(self, {
			{
				Type = "Energy",
				MaxValue = Ores.Automation.BatteryCapacity,
				ConsumptionRate = Ores.Automation.BaseOreProductionRate,
			},
			{
				Type = "Fuel",
				MaxValue = MAX_COAL,
				ConsumptionRate = Ores.Automation.BaseOreProductionRate / 2,
			}
		})
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
		local ingot = ents.Create("mining_ore_ingot")
		ingot:SetRarity(rarity)
		ingot:SetPos(self:GetPos() + self:GetUp() * -30 + self:GetRight() * -40)
		ingot:Spawn()
		ingot:PhysWake()

		if self.CPPIGetOwner then
			local owner = self:CPPIGetOwner()
			if IsValid(owner) then
				ingot:CPPISetOwner(owner)
			end
		end

		SafeRemoveEntityDelayed(ingot, 20)
	end

	function ENT:Touch(ent)
		if ent.MiningSmelterCollected then return end
		if ent:GetClass() ~= "mining_ore" then return end

		if self.CPPIGetOwner and ent.GraceOwner ~= self:CPPIGetOwner() then return end -- lets not have people highjack each others

		local rarity = ent:GetRarity()
		if Ores.Automation.GetOreRarityByName("Coal") == rarity then
			local curFuel = self:GetNWInt("Fuel", 0)
			self:SetNWInt("Fuel", math.min(MAX_COAL, curFuel + 1))

			ent.MiningSmelterCollected = true
			SafeRemoveEntity(ent)
			return
		end

		if not self:CanWork() then return end
		if not self:GetNWBool("IsPowered", true) then return end

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

	function ENT:CheckSoundLoop(time)
		if time < self.NextSoundCheck then return end

		if not self:CanWork() then
			if self.SndLoop and self.SndLoop ~= -1 then
				self:StopLoopingSound(self.SndLoop)
			end

			self.SndLoop = nil
			self.NextSoundCheck = time + 2.5
			return
		end

		if not self.SndLoop or self.SndLoop == -1 then
			self.SndLoop = self:StartLoopingSound("ambient/machines/machine_whine1.wav")
		end

		self.NextSoundCheck = time + 2.5
	end

	function ENT:Think()
		local time = CurTime()
		self:CheckSoundLoop(time)
	end

	function ENT:OnRemove()
		SafeRemoveEntity(self.Trigger)

		if self.SndLoop and self.SndLoop ~= -1 then
			self:StopLoopingSound(self.SndLoop)
		end
	end
end

if CLIENT then
	local WHEEL_MDL = "models/props_c17/pulleywheels_large01.mdl"
	local function addWheelEntity(self, offset)
		local wheel = ClientsideModel(WHEEL_MDL)
		wheel:SetPos(self:GetPos() + offset)
		wheel:Spawn()
		wheel:SetParent(self)

		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		wheel.RenderOverride = function()
			local color = Ores.__R[argoniteRarity].PhysicalColor
			render.SetColorModulation(color.r / 100, color.g / 100, color.b / 100)
			render.MaterialOverride(Ores.Automation.EnergyMaterial)
			wheel:DrawModel()
			render.MaterialOverride()
			render.SetColorModulation(1, 1, 1)
		end

		return wheel
	end

	function ENT:Initialize()
		self.Wheel = addWheelEntity(self, self:GetUp() * -15)
	end

	function ENT:Draw()
		self:DrawModel()

		local hasEnergy = self:CanWork()
		if hasEnergy then
			local offset = -10
			for i = 1, 2 do
				local effectData = EffectData()
				effectData:SetAngles((-self:GetUp()):Angle())
				effectData:SetScale(2)
				effectData:SetOrigin(self:GetPos() + self:GetUp() * -20 + self:GetRight() * math.sin(CurTime()) * offset + self:GetForward() * math.cos(CurTime()) * offset)
				util.Effect("MuzzleEffect", effectData, true, true)

				offset = offset + 22
			end
		end

		if IsValid(self.Wheel) then
			self.Wheel:SetPos(self:GetPos() + self:GetUp() * -15)
			self.Wheel:SetParent(self)

			local ang = self:GetAngles()
			ang:RotateAroundAxis(self:GetRight(), 90)

			if hasEnergy then
				ang:RotateAroundAxis(self:GetUp(), CurTime() * -40 % 360)
			end

			self.Wheel:SetAngles(ang)
		end
	end

	function ENT:OnRemove()
		SafeRemoveEntity(self.Wheel)
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
			{ Type = "Data", Label = "ENERGY", Value = self:GetNWInt("Energy", 0), MaxValue = self:GetNWInt("MaxEnergy", 100) },
			{ Type = "Data", Label = "FUEL", Value = self:GetNWInt("Fuel", 0), MaxValue = self:GetNWInt("MaxFuel", MAX_COAL) },
		}

		local globalOreData = self:GetNWString("OreData", ""):Trim()
		if #globalOreData < 1 then return data end

		for i, dataChunk in ipairs(globalOreData:Split(";")) do
			local rarityData = dataChunk:Split("=")
			local oreData = Ores.__R[tonumber(rarityData[1])]

			table.insert(data, { Type = "Data", Label = oreData.Name:upper()[1] .. ". INGOT", Value = tonumber(rarityData[2]) or 0	, MaxValue = STACK_SIZE, LabelColor = oreData.HudColor, ValueColor = oreData.HudColor })
		end

		return data
	end
end