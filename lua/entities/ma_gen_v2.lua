AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Generator"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "ma_gen_v2"
ENT.IconOverride = "entities/ma_gen_v2.png"

function ENT:CanWork()
	if not self:GetNWBool("Wiremod_Active", true) then return false end
	if not self:GetNWBool("IsPowered", true) then return false end
	if self:GetEnergyLevel() == 0 then return false end

	return true
end

function ENT:GetEnergyLevel()
	return self:GetNW2Float("Energy", 0)
end

local BASE_KICKSTART_PRICE = 350000
if SERVER then
	resource.AddFile("materials/entities/ma_gen_v2.png")
	util.AddNetworkString("mining_kickstart_generator")

	net.Receive("mining_kickstart_generator", function(_, ply)
		local generator = net.ReadEntity()
		if not IsValid(generator) then return end

		local required_points = math.floor(BASE_KICKSTART_PRICE * math.max(1, Ores.GetPlayerMultiplier(ply) - 2))
		local point_balance = ply:GetNWInt(Ores._nwPoints, 0)
		if required_points > point_balance then return end

		Ores.Print(ply, ("kickstarted a generator using %d pts"):format(required_points))
		Ores.TakePlayerPoints(ply, required_points)

		generator:SetNW2Int("Energy", 100)
	end)

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

			Ores.Automation.ReplicateOwnership(self, self)
		end)

		_G.MA_Orchestrator.RegisterInput(self, "battery", "BATTERY", "Battery", "Argonite batteries are given to the generator so that it may store and distribute power!")
		_G.MA_Orchestrator.RegisterOutput(self, "power", "ENERGY", "Energy", "Standard energy output.")

		_G.MA_Orchestrator.EntityTimer("ma_gen_v2", self, 10, 0, function()
			local output_data = _G.MA_Orchestrator.GetOutputData(self, "power")
			local drain = table.Count(output_data.Links) * 0.01
			local cur_energy = self:GetNW2Float("Energy", 0)
			local new_energy = math.max(0, cur_energy - drain)
			self:SetNW2Float("Energy", new_energy)
			_G.WireLib.TriggerOutput(self, "Energy", new_energy)
		end)

		Ores.Automation.PrepareForDuplication(self)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {"Active (If this is non-zero, activate the drill)"})
			_G.WireLib.CreateOutputs(self, {
				"Energy (Outputs the current energy level) [NORMAL]",
				"MaxEnergy (Outputs the max level of energy) [NORMAL]",
			})

			_G.WireLib.TriggerOutput(self, "Energy", 0)
			_G.WireLib.TriggerOutput(self, "MaxEnergy", 100)
		end
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if input_data.Id ~= "battery" then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if input_data.Id ~= "battery" then return end

		local cur_energy = self:GetNW2Float("Energy", 0)
		local new_energy = math.min(100, cur_energy + 10)
		self:SetNW2Float("Energy", new_energy)
		_G.WireLib.TriggerOutput(self, "Energy", new_energy)
	end

	function ENT:TriggerInput(port, state)
		if port == "Active" then
			self:SetNWBool("Wiremod_Active", tobool(state))
		end
	end

	function ENT:CheckSoundLoop(time)
		if time < self.NextSoundCheck then return end

		if not self:CanWork() then
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

			if self:CanWork() then
				ang:RotateAroundAxis(self:GetForward(), CurTime() * 100 % 360)
			end

			self.Wheel:SetAngles(ang)

			self.Wheel:DrawModel()
		end
	end

	function ENT:OnRemove()
		SafeRemoveEntity(self.Wheel)
	end

	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			local data = {
				{ Type = "Label", Text = self.PrintName:upper(), Border = true },
				{ Type = "Data", Label = "Energy", Value = self:GetEnergyLevel(), MaxValue = 100 },
				{ Type = "State", Value = self:CanWork() }
			}

			self.MiningFrameInfo = data
		end

		self.MiningFrameInfo[2].Value = self:GetEnergyLevel()
		self.MiningFrameInfo[3].Value = self:CanWork()

		if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
			self.MiningFrameInfo[4] = { Type = "Action", Binding = "+use", Text = "KICKSTART" }
		end

		return self.MiningFrameInfo
	end

	hook.Add("PlayerBindPress", "mining_generator_kickstart", function(ply, bind, pressed, code)
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:GetClass() == "weapon_physgun" then return end

		if bind == "+use" and pressed then
			local tr = ply:GetEyeTrace()
			if IsValid(tr.Entity) and tr.Entity:GetClass() == "ma_gen_v2" and tr.Entity:WorldSpaceCenter():Distance(EyePos()) <= 300 then
				local required_points = math.floor(BASE_KICKSTART_PRICE * math.max(1, Ores.GetPlayerMultiplier(ply) - 2))
				local point_balance = ply:GetNWInt(Ores._nwPoints, 0)
				if required_points > point_balance then
					chat.AddText(Color(230, 130, 65), " ♦ [Ores] ", color_white, ("You do not have enough points to kickstart this generator (required: %s pts | balance: %s pts)"):format(
						string.Comma(required_points),
						string.Comma(pointBalance)
					))
					return
				end

				Derma_Query(
					("Kickstarting the generator will cost you %s pts (current balance: %s pts)"):format(
						string.Comma(required_points),
						string.Comma(point_balance)
					),
					"Kickstart Generator",
					"Kickstart", function()
						net.Start("mining_kickstart_generator")
						net.WriteEntity(tr.Entity)
						net.SendToServer()
					end,
					"Cancel", function() end
				)
			end
		end
	end)
end