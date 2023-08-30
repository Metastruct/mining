AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ore Smelter"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_ore_smelter"

function ENT:CanWork()
	return self:GetNW2Int("Energy", 0) > 0 and self:GetNW2Int("Fuel", 0) > 0 and self:GetNWBool("IsPowered", true)
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/hunter/blocks/cube075x2x1.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetTrigger(true)
		self:UseTriggerBounds(true, 16)
		self:PhysWake()
		self:SetNWBool("IsPowered", true)
		self:Activate()

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x2.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetPos(self:GetPos() + self:GetUp() * -24 + self:GetRight() * 24 + self:GetForward() * -6)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetUp(), 90)

		self.Frame:SetAngles(ang)
		self.Frame:Spawn()
		self.Frame.PhysgunDisabled = true
		self.Frame:SetParent(self)
		self.Frame:SetNotSolid(true)
		self.Frame:SetTrigger(true)

		self.Frame2 = ents.Create("prop_physics")
		self.Frame2:SetModel("models/props_phx/construct/metal_tube.mdl")
		self.Frame2:SetMaterial("models/mspropp/metalgrate014a")
		self.Frame2:SetPos(self:GetPos() + self:GetRight() * -23 + self:GetForward() * 17)

		ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetRight(), 90)
		ang:RotateAroundAxis(self:GetForward(), 90)

		self.Frame2:SetAngles(ang)
		self.Frame2:Spawn()
		self.Frame2.PhysgunDisabled = true
		self.Frame2:SetParent(self)
		self.Frame2:SetNotSolid(true)
		self.Frame2:SetTrigger(true)

		self.Machine = ents.Create("prop_physics")
		self.Machine:SetModel("models/xqm/podremake.mdl")
		self.Machine:SetMaterial("phoenix_storms/future_vents")
		self.Machine:SetModelScale(0.4)

		ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetRight(), 90)
		ang:RotateAroundAxis(self:GetUp(), 90)

		self.Machine:SetAngles(ang)
		self.Machine:SetPos(self:GetPos() + self:GetRight() * 12 + self:GetForward() * -6 + self:GetUp() * -3)
		self.Machine:Spawn()
		self.Machine:SetParent(self)
		self.Machine:SetNotSolid(true)
		self.Machine:SetTrigger(true)

		self.Out = ents.Create("prop_physics")
		self.Out:SetModel("models/props_phx/construct/metal_wire1x1.mdl")
		self.Out:SetMaterial("phoenix_storms/stripes")
		self.Out:SetPos(self:GetPos() + self:GetRight() * -23 + self:GetForward() * 24)

		ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetRight(), 90)
		ang:RotateAroundAxis(self:GetForward(), 90)

		self.Out:SetAngles(ang)
		self.Out:Spawn()
		self.Out:SetParent(self)
		self.Out:SetNotSolid(true)
		self.Out:SetTrigger(true)

		timer.Simple(0, function()
			if not IsValid(self) then return end
			Ores.Automation.ReplicateOwnership(self, self)
			self.SndLoop = self:StartLoopingSound("ambient/machines/machine_whine1.wav")
			self:Activate()
		end)

		if _G.WireLib then
			self.Inputs = _G.WireLib.CreateInputs(self, {
				"Active (If non-zero, activate the smelter.)"
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
				ConsumptionRate = 10, -- 1 unit every 10 seconds
			},
			{
				Type = "Fuel",
				MaxValue = Ores.Automation.BatteryCapacity,
				ConsumptionRate = 5, -- 1 unit every 5 seconds => MAX is 50, FUEL TANK is 150, so 1 fuel tank => 15 minutes
			}
		})
	end

	function ENT:TriggerInput(port, state)
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
		ingot:SetPos(self:GetPos() + self:GetRight() * -24 + self:GetForward() * 40 + self:GetUp() * 5)
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
			ent.MiningSmelterCollected = true
			SafeRemoveEntity(ent)
			return
		end

		if not self:CanWork() then return end

		if not self.BadOreRarities[rarity] then
			local newValue = (self.Ores[rarity] or 0) + 1
			self.Ores[rarity] = newValue
			if newValue >= Ores.Automation.IngotSize then
				self:ProduceRefinedOre(rarity)
				self.Ores[rarity] = nil
			end

			self:UpdateNetworkOreData()
		end

		ent.MiningSmelterCollected = true
		SafeRemoveEntity(ent)
	end

	-- fallback in case trigger stops working
	function ENT:PhysicsCollide(data)
		if not IsValid(data.HitEntity) then return end

		self:Touch(data.HitEntity)
	end

	function ENT:AllowPassThrough(allow)
		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableCollisions(not allow)
		end
	end

	function ENT:CheckSoundLoop(time)
		if time < self.NextSoundCheck then return end

		if not self:CanWork() then
			if self.SndLoop and self.SndLoop ~= -1 then
				self:StopLoopingSound(self.SndLoop)
			end

			self.SndLoop = nil
			self.NextSoundCheck = time + 2.5
			self:AllowPassThrough(true)
			return
		end

		if not self.SndLoop or self.SndLoop == -1 then
			self.SndLoop = self:StartLoopingSound("ambient/machines/machine_whine1.wav")
		end

		self.NextSoundCheck = time + 2.5
		self:AllowPassThrough(false)
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

	function ENT:SpawnFunction(ply, tr, className)
		if not tr.Hit then return end

		local spawnPos = tr.HitPos + tr.HitNormal * 30
		local ent = ents.Create(className)
		ent:SetPos(spawnPos)
		ent:Activate()
		ent:Spawn()

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
		end

		return ent
	end

	function ENT:CanConsumeEnergy()
		return self:CanWork()
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
		self.Wheel = addWheelEntity(self, self:GetRight() * -4 + self:GetForward() * -6)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetUp(), 90)
		self.Wheel:SetAngles(ang)
	end

	function ENT:Draw()
		--self:DrawModel()

		local hasEnergy = self:CanWork()
		if hasEnergy then
			local offset = -10
			for i = 1, 2 do
				local effectData = EffectData()
				effectData:SetAngles((-self:GetRight()):Angle())
				effectData:SetScale(2)
				effectData:SetOrigin(self:GetPos() + self:GetRight() * -6 + self:GetUp() * math.sin(CurTime()) * offset + self:GetForward() * math.cos(CurTime()) * offset)
				util.Effect("MuzzleEffect", effectData, true, true)

				offset = offset + 22
			end
		end

		if IsValid(self.Wheel) then
			self.Wheel:SetPos(self:GetPos() + self:GetRight() * -4 + self:GetForward() * -6)
			self.Wheel:SetParent(self)

			local ang = self:GetAngles()
			ang:RotateAroundAxis(self:GetUp(), 90)

			if hasEnergy then
				ang:RotateAroundAxis(self:GetRight(), CurTime() * 45 % 360)
			end

			self.Wheel:SetAngles(ang)
		end
	end

	function ENT:OnRemove()
		SafeRemoveEntity(self.Wheel)
	end

	function ENT:OnGraphDraw(x, y)
		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		local argoniteColor = Ores.__R[argoniteRarity].HudColor
		local GU = Ores.Automation.GraphUnit

		surface.SetDrawColor(125, 125, 125, 255)
		surface.DrawRect(x - GU, y - GU / 2, GU * 2, GU)

		surface.SetDrawColor(argoniteColor)
		surface.DrawOutlinedRect(x - GU, y - GU / 2, GU * 2, GU, 2)

		surface.SetTextColor(255, 255, 255, 255)
		local percEnergy = (math.Round((self:GetNW2Int("Energy", 0) / self:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity)) * 100))
		local percFuel = (math.Round((self:GetNW2Int("Fuel", 0) / self:GetNW2Int("MaxFuel", Ores.Automation.BatteryCapacity)) * 100))
		local perc = ("%d%% / %d%%"):format(percEnergy, percFuel)
		surface.SetFont("DermaDefault")
		local tw, th = surface.GetTextSize(perc)
		surface.SetTextPos(x - tw / 2, y - th / 2)
		surface.DrawText(perc)

		local state = self:CanWork()
		surface.SetDrawColor(state and 0 or 255, state and 255 or 0, 0, 255)
		surface.DrawOutlinedRect(x - GU / 2 + 2, y - GU / 2 + 2, GU - 4, 2)
	end

	function ENT:OnDrawEntityInfo()
		local data = {
			{ Type = "State", Value = self:CanWork() },
			{ Type = "Label", Text = "SMELTER", Border = true },
			{ Type = "Data", Label = "ENERGY", Value = self:GetNW2Int("Energy", 0), MaxValue = self:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity) },
			{ Type = "Data", Label = "FUEL", Value = self:GetNW2Int("Fuel", 0), MaxValue = self:GetNW2Int("MaxFuel", Ores.Automation.BatteryCapacity), Border = true },
		}

		local globalOreData = self:GetNWString("OreData", ""):Trim()
		if #globalOreData < 1 then return data end

		for i, dataChunk in ipairs(globalOreData:Split(";")) do
			local rarityData = dataChunk:Split("=")
			local oreData = Ores.__R[tonumber(rarityData[1])]

			table.insert(data, { Type = "Data", Label = oreData.Name:upper()[1] .. ". INGOT", Value = ("%s/%d"):format(rarityData[2], Ores.Automation.IngotSize), LabelColor = oreData.HudColor, ValueColor = oreData.HudColor })
		end

		return data
	end
end