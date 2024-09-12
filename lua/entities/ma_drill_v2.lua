AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Drill V2"
ENT.Author = "Earu"
ENT.Category = "Mining V2"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "ma_drill_v2"
ENT.NextTraceCheck = 0

local function can_work(self, time)
	if not self:GetNWBool("IsPowered", false) then return false end
	if time < self.NextTraceCheck then return self.TraceCheckResult end

	local tr = util.TraceLine({
		start = self:GetPos() + self:GetForward() * -20,
		endpos = self:GetPos() + self:GetForward() * -75,
		mask = MASK_SOLID_BRUSHONLY,
	})

	self.NextTraceCheck = time + 1.5
	self.TraceCheckResult = tr.Hit
	return tr.Hit
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_combine/headcrabcannister01a.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self.NextSoundCheck = 0
		self.NextDrilledOre = 0
		self.NextTraceCheck = 0
		self.EnergyLevel = 0
		self.OreQueue = {}
		self:SetNWBool("IsPowered", false)

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x2.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetPos(self:GetPos() + self:GetForward() * -25 + self:GetRight() * -24)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetForward(), 90)

		self.Frame:SetAngles(ang)
		self.Frame:Spawn()
		self.Frame.PhysgunDisabled = true
		self.Frame:SetParent(self)
		self.Frame:SetTrigger(true)

		_G.MA_Orchestrator.RegisterInput(self, "power", "ENERGY", "Energy", "Standard energyy input. More energy equals more ores!")
		_G.MA_Orchestrator.RegisterOutput(self, "ores", "ORE", "Ores", "Standard ore output.")
	end

	function ENT:MA_OnLink(output_data, input_data)
		if input_data.Id ~= "power" then return end

		local power_src_ent = output_data.Ent
		if not IsValid(power_src_ent) then return end

		local timer_name = ("ma_drill_v2_[%d]"):format(self:EntIndex())
		timer.Create(timer_name, 1, 0, function()
			if not IsValid(self) then
				timer.Remove(timer_name)
				return
			end

			local got_power = _G.MA_Orchestrator.Execute(output_data, input_data)
			self:SetNWBool("IsPowered", got_power or false)
		end)

		-- also executes as soon as its linked
		local got_power = _G.MA_Orchestrator.Execute(output_data, input_data)
		self:SetNWBool("IsPowered", got_power or false)
	end

	-- we just return true here, if we receive true when the orchestrator executes the link
	-- then that means everything was approved by both entities output and input
	function ENT:MA_Execute(output_data, input_data)
		if input_data.Id ~= "power" then return end

		self.EnergyLevel = isfunction(output_data.Ent.GetEnergyLevel) and output_data.Ent:GetEnergyLevel() or 1
		return self.EnergyLevel > 0
	end

	-- this unpowers the drill if the energy input is unlinked
	function ENT:MA_OnUnlink(output_data, input_data)
		if input_data.Id ~= "power" then return end

		local timer_name = ("ma_drill_v2_[%d]"):format(self:EntIndex())
		timer.Remove(timer_name)

		self:SetNWBool("IsPowered", false)
	end

	function ENT:CheckSoundLoop(time)
		if time < self.NextSoundCheck then return end

		if not can_work(self, time) then
			if self.SndLoop and self.SndLoop ~= -1 then
				self:StopLoopingSound(self.SndLoop)
			end

			self.SndLoop = nil
			self.NextSoundCheck = time + 5
			return
		end

		if not self.SndLoop or self.SndLoop == -1 then
			self.SndLoop = self:StartLoopingSound("ambient/spacebase/spacebase_drill.wav")
		end

		self.NextSoundCheck = time + 5
	end

	function ENT:DrillOres(time)
		if time < self.NextDrilledOre then return end
		if not can_work(self, time) then return end

		local oreRarity = Ores.SelectRarityFromSpawntable()
		table.insert(self.OreQueue, 1, oreRarity)

		-- keep an internal storage of the last 50 ores
		if #self.OreQueue > 50 then
			table.remove(self.OreQueue, #self.OreQueue)
		end

		local output_data = _G.MA_Orchestrator.GetOutputData(self, "ores")
		_G.MA_Orchestrator.SendOutputReadySignal(output_data)

		-- efficiency goes up the more its powered:
		-- at less than 33% -> 10s,
		-- less than 66% -> 8s
		-- less than 100% -> 6s
		local effiencyRateIncrease = 0
		if self.EnergyLevel > 33 then
			effiencyRateIncrease = effiencyRateIncrease + 2
		end

		if self.EnergyLevel > 66 then
			effiencyRateIncrease = effiencyRateIncrease + 2
		end

		self.NextDrilledOre = time + (10 - effiencyRateIncrease)
	end

	function ENT:Think()
		local time = CurTime()
		self:CheckSoundLoop(time)
		self:DrillOres(time)
	end

	function ENT:OnRemove()
		if self.SndLoop and self.SndLoop ~= -1 then
			self:StopLoopingSound(self.SndLoop)
		end
	end
end

if CLIENT then
	local SAW_MDL = "models/props_junk/sawblade001a.mdl"
	local function addSawEntity(self, offset)
		local saw = ClientsideModel(SAW_MDL)
		saw:SetModelScale(2)
		saw:SetPos(self:GetPos() + offset)
		saw:Spawn()
		saw:SetParent(self)

		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		saw.RenderOverride = function()
			local color = Ores.__R[argoniteRarity].PhysicalColor
			render.SetColorModulation(color.r / 100, color.g / 100, color.b / 100)
			render.MaterialOverride(Ores.Automation.EnergyMaterial)
			saw:DrawModel()
			render.MaterialOverride()
			render.SetColorModulation(1, 1, 1)
		end

		return saw
	end

	function ENT:Initialize()
		_G.MA_Orchestrator.RegisterInput(self, "power", "ENERGY", "Energy", "Standard energyy input. More energy equals more ores!")
		_G.MA_Orchestrator.RegisterOutput(self, "ores", "ORE", "Ores", "The mined ores, you can link this to several entities like the Ore Storage.")

		self.NextTraceCheck = 0
		self.Saws = {
			addSawEntity(self, self:GetForward() * -40 + self:GetRight() * 10),
			addSawEntity(self, self:GetForward() * -40),
			addSawEntity(self, self:GetForward() * -40 + self:GetRight() * -10),
		}
	end

	local EFFECT_NAME = "WheelDust"
	function ENT:Draw()
		self:DrawModel()

		local time = CurTime()
		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetForward(), 90)

		if can_work(self, time) then
			ang:RotateAroundAxis(self:GetRight(), time * 400 % 360)

			local effectData = EffectData()
			effectData:SetScale(1.5)
			effectData:SetOrigin(self:GetPos() + self:GetForward() * -40)
			util.Effect(EFFECT_NAME, effectData)
		end

		for k, saw in ipairs(self.Saws) do
			if IsValid(saw) and saw:GetModel() == SAW_MDL then
				if not IsValid(saw:GetParent()) then
					saw:SetPos(self:GetPos() + self:GetForward() * -40 + self:GetRight() * (-10 + (10 * (k - 1))))
					saw:SetParent(self)
				end
				saw:SetAngles(ang)
			end
		end
	end

	function ENT:OnRemove()
		for _, saw in ipairs(self.Saws) do
			SafeRemoveEntity(saw)
		end
	end
end