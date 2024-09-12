AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Generator V2"
ENT.Author = "Earu"
ENT.Category = "Mining V2"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "ma_gen_v2"

local function can_work(self)
	if not self:GetNWBool("IsPowered", true) then return false end
	if self:GetEnergyLevel() == 0 then return false end

	return true
end

function ENT:GetEnergyLevel()
	return self:GetNW2Float("Energy", 0)
end

if SERVER then
	ENT.NextSoundCheck = 0
	ENT.NextLinkCheck = 0

	function ENT:Initialize()
		self:SetModel("models/props_wasteland/laundry_washer003.mdl")
		self:SetMaterial("phoenix_storms/future_vents")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self.NextSoundCheck = 0
		self.NextLinkCheck = 0
		self:SetNWBool("IsPowered", true)

		timer.Simple(0, function()
			if not IsValid(self) then return end

			self.SndLoop = self:StartLoopingSound("ambient/steam_drum.wav")
		end)

		_G.MA_Orchestrator.RegisterInput(self, "battery", "BATTERY", "Battery", "Argonite batteries are given to the generator so that it may store and distribute power!")
		_G.MA_Orchestrator.RegisterOutput(self, "power", "ENERGY", "Energy", "Standard energy output.")

		local timer_name = ("ma_gen_v2_[%d]"):format(self:EntIndex())
		timer.Create(timer_name, 10, 0, function()
			if not IsValid(self) then
				timer.Remove(timer_name)
				return
			end

			local cur_energy = self:GetNW2Float("Energy", 0)
			self:SetNW2Float("Energy", math.max(0, cur_energy - 0.05))
		end)
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if input_data.Id ~= "battery" then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if input_data.Id ~= "battery" then return end

		local cur_energy = self:GetNW2Float("Energy", 0)
		self:SetNW2Float("Energy", math.min(100, cur_energy + 10))
	end

	function ENT:CheckSoundLoop(time)
		if time < self.NextSoundCheck then return end

		if not can_work(self) then
			if self.SndLoop and self.SndLoop ~= -1 then
				self:StopLoopingSound(self.SndLoop)
			end

			self.SndLoop = nil
			self.NextSoundCheck = time + 5
			return
		end

		if not self.SndLoop or self.SndLoop == -1 then
			self.SndLoop = self:StartLoopingSound("ambient/steam_drum.wav")
		end

		self.NextSoundCheck = time + 5
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
end

if CLIENT then
	local WHEEL_MDL = "models/props_phx/construct/metal_wire_angle360x2.mdl"
	local function addWheelEntity(self, offset)
		local wheel = ClientsideModel(WHEEL_MDL)
		local scale = Vector(0.6, 0.6, 1)
		local mat = Matrix()
		mat:Scale(scale)
		wheel:EnableMatrix("RenderMultiply", mat)
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
		_G.MA_Orchestrator.RegisterInput(self, "battery", "BATTERY", "Battery", "Argonite batteries are given to the generator so that it may store and distribute power!")
		_G.MA_Orchestrator.RegisterOutput(self, "power", "ENERGY", "Energy", "Standard energy output.")

		self.Wheel = addWheelEntity(self, self:GetForward() * 48 + self:GetRight() * 2)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetForward(), 90)
		self.Wheel:SetAngles(ang)
	end

	function ENT:Draw()
		self:DrawModel()

		if IsValid(self.Wheel) then
			self.Wheel:SetPos(self:GetPos() + self:GetForward() * 48 + self:GetRight() * 2)
			self.Wheel:SetParent(self)

			local ang = self:GetAngles()
			ang:RotateAroundAxis(self:GetRight(), 90)

			if can_work(self) then
				ang:RotateAroundAxis(self:GetForward(), CurTime() * 100 % 360)
			end

			self.Wheel:SetAngles(ang)

			self.Wheel:DrawModel()
		end
	end

	function ENT:OnRemove()
		SafeRemoveEntity(self.Wheel)
	end
end