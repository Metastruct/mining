AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Refinery"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "ma_refinery"
ENT.IconOverride = "entities/ma_refinery.png"
ENT.Description = "The refinery can make your ores more precious (ex: copper -> silver). It also has a chance to produce rejects in the form of detonite. It needs both energy and fuel to function."

require("ma_orchestrator")
_G.MA_Orchestrator.RegisterInput(ENT, "oil", "OIL", "Oil", "Standard oil input. More oil equals better chance at refined ores!")
_G.MA_Orchestrator.RegisterInput(ENT, "power", "ENERGY", "Energy", "Standard energy input. More energy equals better chance at refined ores!")
_G.MA_Orchestrator.RegisterInput(ENT, "ores", "ORE", "Ores", "Standard ores input.")

_G.MA_Orchestrator.RegisterOutput(ENT, "ores", "ORE", "Ores", "Refined ores output.")
_G.MA_Orchestrator.RegisterOutput(ENT, "rejects", "DETONITE", "Rejects", "The rejects in the refinement process.")

function ENT:CanWork()
	if not self:GetNWBool("Wiremod_Active", true) then return false end
	return self:GetNW2Int("Fuel", 0) > 0 and self:GetNWBool("IsPowered", false)
end

if SERVER then
	resource.AddFile("materials/entities/ma_refinery.png")

	local function get_stat(stat_name)
		for _, v in pairs(Ores.__PStats) do
			if v.VarName == stat_name then
				return v
			end
		end
	end

	function ENT:Initialize()
		self:SetModel("models/xqm/afterburner1huge.mdl")
		self:SetMaterial("phoenix_storms/OfficeWindow_1-1")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetNWBool("IsPowered", false)
		self.OreQueue = {}
		self.RejectCount = 0
		self.NextSoundCheck = 0

		local raw_max_chance = 20
		local max_chance = raw_max_chance
		if self.CPPIGetOwner then
			local owner = self:CPPIGetOwner()
			if IsValid(owner) then
				local stat = get_stat("MagicFindChance")
				local stat_value = stat.VarBase + (stat.VarStep * owner:GetNWInt(ms.Ores._nwPickaxePrefix .. stat.VarName, 0))
				max_chance = stat_value * 100
			end
		end

		local refinery_timer_tick = 0
		_G.MA_Orchestrator.EntityTimer("ma_refinery", self, 0.5, 0, function()
			if not self:CanWork() then return end

			refinery_timer_tick = refinery_timer_tick + 0.5
			if refinery_timer_tick % 5 == 0 then
				local cur_fuel = self:GetNW2Int("Fuel", 0)
				local new_fuel = math.max(0, cur_fuel - 1)
				self:SetNW2Int("Fuel", new_fuel)

				if _G.WireLib then
					_G.WireLib.TriggerOutput(self, "Fuel", new_fuel)
				end
			end

			if #self.OreQueue > 1 then
				local efficiency = self:GetNW2Int("Energy", 0) / 100
				local refined = math.random(0, 100) < (max_chance * efficiency)
				local rejected = math.random(0, 100) < (raw_max_chance + 10)

				if refined then
					local ore_data = Ores.__R[self.OreQueue[1]]
					if ore_data and isnumber(ore_data.NextRarityId) then
						self.OreQueue[1] = ore_data.NextRarityId
					end
				elseif rejected then
					table.remove(self.OreQueue, 1)
					self.RejectCount = self.RejectCount + 2
				end

				if not rejected then
					local output_data = _G.MA_Orchestrator.GetOutputData(self, "ores")
					_G.MA_Orchestrator.SendOutputReadySignal(output_data)
				end
			end

			if self.RejectCount > 0 then
				local output_data = _G.MA_Orchestrator.GetOutputData(self, "rejects")
				_G.MA_Orchestrator.SendOutputReadySignal(output_data)
			end
		end)

		Ores.Automation.PrepareForDuplication(self)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {"Active (If this is non-zero, activate the refinery)"})
			_G.WireLib.CreateOutputs(self, {
				"Efficiency (Outputs the current efficiency level) [NORMAL]",
				"MaxEfficiency (Outputs the max level of efficiency) [NORMAL]",
				"Fuel (Outputs the current amount of fuel) [NORMAL]",
				"MaxFuel (Outputs the maximum amount of fuel) [NORMAL]",
			})

			_G.WireLib.TriggerOutput(self, "Efficiency", 0)
			_G.WireLib.TriggerOutput(self, "MaxEfficiency", 100)
			_G.WireLib.TriggerOutput(self, "Fuel", 0)
			_G.WireLib.TriggerOutput(self, "MaxFuel", Ores.Automation.BatteryCapacity)
		end
	end

	function ENT:MA_OnLink(output_data, input_data)
		if input_data.Id ~= "power" then return end

		local power_src_ent = output_data.Ent
		if not IsValid(power_src_ent) then return end

		_G.MA_Orchestrator.EntityTimer("ma_refinery_power", self, 1, 0, function()
			local got_power = _G.MA_Orchestrator.Execute(output_data, input_data)
			self:SetNWBool("IsPowered", got_power or false)
		end)

		-- also executes as soon as its linked
		local got_power = _G.MA_Orchestrator.Execute(output_data, input_data)
		self:SetNWBool("IsPowered", got_power or false)
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if input_data.Id ~= "ores" and input_data.Id ~= "oil" then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if input_data.Id == "ores" then
			if not istable(output_data.Ent.OreQueue) then return end
			if #output_data.Ent.OreQueue == 0 then return end

			-- combines queues
			local rarity = table.remove(output_data.Ent.OreQueue, 1)
			table.insert(self.OreQueue, 1, rarity)

			-- keep an internal storage of the last 50 ores
			if #self.OreQueue > 50 then
				table.remove(self.OreQueue, #self.OreQueue)
			end
		elseif input_data.Id == "oil" then
			local replenish = math.ceil(Ores.Automation.BatteryCapacity / table.Count(output_data.Links))
			local cur_fuel = self:GetNW2Int("Fuel", 0)
			local new_fuel = math.min(Ores.Automation.BatteryCapacity, cur_fuel + replenish)
			self:SetNW2Int("Fuel", new_fuel)

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Fuel", new_fuel)
			end
		elseif input_data.Id == "power" then
			local energy_lvl = isfunction(output_data.Ent.GetEnergyLevel) and output_data.Ent:GetEnergyLevel() or 1
			self:SetNW2Int("Energy", energy_lvl)

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Efficiency", energy_lvl)
			end

			return energy_lvl > 0
		end
	end

	function ENT:MA_OnUnlink(output_data, input_data)
		if input_data.Id ~= "power" then return end

		_G.MA_Orchestrator.RemoveEntityTimer("ma_refinery_power", self)
		self:SetNWBool("IsPowered", false)
		self:SetNW2Int("Energy", 0)

		if _G.WireLib then
			_G.WireLib.TriggerOutput(self, "Efficiency", 0)
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
			return
		end

		if not self.SndLoop or self.SndLoop == -1 then
			self.SndLoop = self:StartLoopingSound("ambient/machines/machine6.wav")
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

	function ENT:TriggerInput(port, state)
		if port == "Active" then self:SetNWBool("Wiremod_Active", tobool(state)) end
	end
end

if CLIENT then
	local WHEEL_MDL = "models/props_wasteland/wheel01.mdl"
	local function addWheelEntity(self, offset)
		local wheel = ClientsideModel(WHEEL_MDL)
		wheel:SetModelScale(1.75)
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
		self.Wheel = addWheelEntity(self, self:GetUp() * -30)
	end

	function ENT:Draw()
		self:DrawModel()

		local has_energy = self:CanWork()
		if has_energy then
			local effect_data = EffectData()
			effect_data:SetAngles((self:GetUp()):Angle())
			effect_data:SetScale(6)
			effect_data:SetOrigin(self:GetPos())
			util.Effect("MuzzleEffect", effect_data, true, true)
		end

		if IsValid(self.Wheel) then
			local ang = self:GetAngles()
			ang:RotateAroundAxis(self:GetForward(), 90)

			if has_energy then
				ang:RotateAroundAxis(self:GetUp(), CurTime() * 300 % 360)
			end

			self.Wheel:SetPos(self:GetPos() + self:GetUp() * -30)
			self.Wheel:SetParent(self)
			self.Wheel:SetAngles(ang)
		end
	end

	function ENT:OnRemove()
		SafeRemoveEntity(self.Wheel)
	end

	function ENT:OnDrawEntityInfo()
		return {
			{ Type = "State", Value = self:CanWork() },
			{ Type = "Label", Text = self.PrintName:upper(), Border = true },
			{ Type = "Data", Label = "Fuel", Value = self:GetNW2Int("Fuel", 0), MaxValue = Ores.Automation.BatteryCapacity },
			{ Type = "Data", Label = "Efficiency", Value = self:GetNW2Int("Energy", 0) }
		}
	end
end