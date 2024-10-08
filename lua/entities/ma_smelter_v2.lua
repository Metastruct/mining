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
ENT.ClassName = "ma_smelter_v2"
ENT.IconOverride = "entities/ma_smelter_v2.png"
ENT.Description = "The smelter will turn your ores into their corresponding ingots. Ingots have more value than normal ores. The smelter needs both energy and fuel to function."

require("ma_orchestrator")
_G.MA_Orchestrator.RegisterInput(ENT, "ores", "ORE", "Ores", "Standard ore input.")
_G.MA_Orchestrator.RegisterInput(ENT, "power", "ENERGY", "Energy", "Standard energy input.")
_G.MA_Orchestrator.RegisterInput(ENT, "oil", "OIL", "Oil", "Standard oil input.")
_G.MA_Orchestrator.RegisterOutput(ENT, "ingots", "INGOT", "Ingots", "Standard ingot output.")

function ENT:CanWork()
	if not self:GetNWBool("Wiremod_Active", true) then return false end
	return self:GetNW2Int("Fuel", 0) > 0 and self:GetNWBool("IsPowered", false)
end

if SERVER then
	resource.AddFile("materials/entities/ma_smelter_v2.png")

	function ENT:Initialize()
		self:SetModel("models/hunter/blocks/cube075x2x1.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:PhysWake()
		self:SetNWBool("IsPowered", false)
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

		timer.Simple(0, function()
			if not IsValid(self) then return end

			self.SndLoop = self:StartLoopingSound("ambient/machines/machine_whine1.wav")
			self:Activate()
		end)

		self.NextSoundCheck = 0
		self.Ores = {}
		self.IngotQueue = {}

		_G.MA_Orchestrator.EntityTimer("ma_smelter_v2_fuel", self, 5, 0, function()
			if not self:CanWork() then return end

			local cur_fuel = self:GetNW2Int("Fuel", 0)
			local new_fuel = math.max(0, cur_fuel - 1)
			self:SetNW2Int("Fuel", new_fuel)

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Fuel", new_fuel)
			end
		end)

		Ores.Automation.PrepareForDuplication(self)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {
				"Active (If non-zero, activate the smelter.)"
			})

			_G.WireLib.CreateOutputs(self, {
				"Fuel (Outputs the current amount of fuel) [NORMAL]",
				"MaxFuel (Outputs the maximum amount of fuel) [NORMAL]",
				"OreCounts (Outputs an array of the counts of each ore stored in the storage) [ARRAY]",
				"OreNames (Outputs an array of the names of each ore stored in the storage) [ARRAY]",
			})

			_G.WireLib.TriggerOutput(self, "Fuel", 0)
			_G.WireLib.TriggerOutput(self, "MaxFuel", Ores.Automation.BatteryCapacity)
			_G.WireLib.TriggerOutput(self, "OreCounts", {})
			_G.WireLib.TriggerOutput(self, "OreNames", {})
		end
	end

	function ENT:MA_OnLink(output_data, input_data)
		if input_data.Id ~= "power" then return end

		local power_src_ent = output_data.Ent
		if not IsValid(power_src_ent) then return end

		_G.MA_Orchestrator.EntityTimer("ma_smelter_v2", self, 1, 0, function()
			local got_power = _G.MA_Orchestrator.Execute(output_data, input_data)
			self:SetNWBool("IsPowered", got_power or false)
		end)

		-- also executes as soon as its linked
		local got_power = _G.MA_Orchestrator.Execute(output_data, input_data)
		self:SetNWBool("IsPowered", got_power or false)
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if input_data.Id ~= "oil" and input_data.Id ~= "ores" then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if input_data.Id == "ores" then
			if not self:CanWork() then return end
			if not istable(output_data.Ent.OreQueue) then return end
			if #output_data.Ent.OreQueue == 0 then return end

			local rarity = table.remove(output_data.Ent.OreQueue, 1)
			self.Ores[rarity] = (self.Ores[rarity] or 0) + 1
			if self.Ores[rarity] >= Ores.Automation.IngotSize then
				self:ProduceRefinedOre(rarity)
				self.Ores[rarity] = nil
			end

			self:UpdateNetworkOreData()
		elseif input_data.Id == "oil" then
			local replenish = math.ceil(Ores.Automation.BatteryCapacity / table.Count(output_data.Links))
			local cur_fuel = self:GetNW2Int("Fuel", 0)
			local new_fuel = math.min(Ores.Automation.BatteryCapacity, cur_fuel + replenish)
			self:SetNW2Int("Fuel", new_fuel)

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Fuel", new_fuel)
			end
		elseif input_data.Id == "power" then
			return (isfunction(output_data.Ent.GetEnergyLevel) and output_data.Ent:GetEnergyLevel() or 1) > 0
		end
	end

	function ENT:MA_OnUnlink(output_data, input_data)
		if input_data.Id ~= "power" then return end

		_G.MA_Orchestrator.RemoveEntityTimer("ma_smelter_v2", self)
		self:SetNWBool("IsPowered", false)
	end

	function ENT:TriggerInput(port, state)
		if port == "Active" then
			self:SetNWBool("Wiremod_Active", tobool(state))
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

	function ENT:ProduceRefinedOre(rarity)
		table.insert(self.IngotQueue, 1, rarity)

		-- keep an internal storage of the last 50 ores
		if #self.IngotQueue > 50 then
			table.remove(self.IngotQueue, #self.IngotQueue)
		end

		local output_data = _G.MA_Orchestrator.GetOutputData(self, "ingots")
		_G.MA_Orchestrator.SendOutputReadySignal(output_data)
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
		if self.SndLoop and self.SndLoop ~= -1 then
			self:StopLoopingSound(self.SndLoop)
		end
	end

	function ENT:SpawnFunction(ply, tr, class_name)
		if not tr.Hit then return end

		local spawn_pos = tr.HitPos + tr.HitNormal * 30
		local ent = ents.Create(class_name)
		ent:SetPos(spawn_pos)
		ent:Activate()
		ent:Spawn()

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
		end

		return ent
	end
end

if CLIENT then
	local WHEEL_MDL = "models/props_c17/pulleywheels_large01.mdl"
	local function addWheelEntity(self, offset)
		local wheel = ClientsideModel(WHEEL_MDL)
		wheel:SetPos(self:GetPos() + offset)
		wheel:Spawn()
		wheel:SetParent(self)

		local argonite_rarity = Ores.GetOreRarityByName("Argonite")
		wheel.RenderOverride = function()
			local color = Ores.__R[argonite_rarity].PhysicalColor
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

		local has_energy = self:CanWork()
		if has_energy then
			local offset = -10
			for i = 1, 2 do
				local effect_data = EffectData()
				effect_data:SetAngles((-self:GetRight()):Angle())
				effect_data:SetScale(2)
				effect_data:SetOrigin(self:GetPos() + self:GetRight() * -6 + self:GetUp() * math.sin(CurTime()) * offset + self:GetForward() * math.cos(CurTime()) * offset)
				util.Effect("MuzzleEffect", effect_data, true, true)

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

	function ENT:OnDrawEntityInfo()
		local data = {
			{ Type = "State", Value = self:CanWork() },
			{ Type = "Label", Text = self.PrintName:upper(), Border = true },
			{ Type = "Data", Label = "Fuel", Value = self:GetNW2Int("Fuel", 0), MaxValue = self:GetNW2Int("MaxFuel", Ores.Automation.BatteryCapacity) },
		}

		local global_ore_data = self:GetNWString("OreData", ""):Trim()
		if #global_ore_data < 1 then return data end

		for i, data_chunk in ipairs(global_ore_data:Split(";")) do
			local rarity_data = data_chunk:Split("=")
			local ore_data = Ores.__R[tonumber(rarity_data[1])]

			table.insert(data, { Type = "Data", Label = ore_data.Name .. " Ingot", Value = ("%s/%d"):format(rarity_data[2], Ores.Automation.IngotSize), LabelColor = ore_data.HudColor, ValueColor = ore_data.HudColor })
		end

		return data
	end
end