AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Oil Extractor V2"
ENT.Author = "Earu"
ENT.Category = "Mining V2"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "ma_oil_extractor_v2"
ENT.NextTraceCheck = 0
ENT.IconOverride = "entities/ma_oil_extractor_v2.png"

local function can_work(self, time)
	if not self:GetNWBool("IsPowered", false) then return false end
	if time < self.NextTraceCheck then return self.TraceCheckResult end

	local tr = util.TraceLine({
		start = self:GetPos() + self:GetUp() * -75,
		endpos = self:GetPos() + self:GetUp() * -100,
		mask = MASK_SOLID_BRUSHONLY,
	})

	self.NextTraceCheck = time + 1.5
	self.TraceCheckResult = tr.Hit
	return tr.Hit
end

local BASE_KICKSTART_PRICE = 12500
if SERVER then
	resource.AddFile("materials/entities/ma_oil_extractor_v2.png")
	util.AddNetworkString("mining_kickstart_extractor")

	net.Receive("mining_kickstart_extractor", function(_, ply)
		local extractor = net.ReadEntity()
		if not IsValid(extractor) then return end

		local required_points = math.floor(BASE_KICKSTART_PRICE * math.max(1, Ores.GetPlayerMultiplier(ply) - 2))
		local point_balance = ply:GetNWInt(Ores._nwPoints, 0)
		if required_points > point_balance then return end

		Ores.Print(ply, ("kickstarted a extractor using %d pts"):format(required_points))
		Ores.TakePlayerPoints(ply, required_points)

		extractor:ProduceBarrel()
	end)

	ENT.NextSoundCheck = 0
	ENT.NextTraceCheck = 0
	ENT.ExtractedOil = 0
	ENT.NextOil = 0

	function ENT:Initialize()
		self:SetModel("models/props_wasteland/coolingtank02.mdl")
		self:SetMaterial("phoenix_storms/future_vents")
		self:SetModelScale(0.4)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_OBB)
		self:SetSolid(SOLID_OBB)
		self:PhysWake()
		self:Activate()
		self.NextSoundCheck = 0
		self.NextTraceCheck = 0
		self.ExtractedOil = 0
		self.NextOil = 0
		self:SetNWBool("IsPowered", false)

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x2.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetPos(self:GetPos() + self:GetForward() * 24 + self:GetUp() * -35)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetRight(), 90)

		self.Frame:SetAngles(ang)
		self.Frame:Spawn()
		self.Frame.PhysgunDisabled = true
		self.Frame:SetParent(self)

		timer.Simple(0, function()
			if not IsValid(self) then return end

			self:Activate()
			Ores.Automation.ReplicateOwnership(self, self)
		end)

		_G.MA_Orchestrator.RegisterInput(self, "power", "ENERGY", "Energy", "Standard energyy input. More energy equals more ores!")
		_G.MA_Orchestrator.RegisterOutput(self, "oil", "OIL", "Oil", "Standard oil output.")

		Ores.Automation.PrepareForDuplication(self)
	end

	function ENT:MA_OnLink(output_data, input_data)
		if input_data.Id ~= "power" then return end

		local power_src_ent = output_data.Ent
		if not IsValid(power_src_ent) then return end

		local timer_name = ("ma_oil_extractor_v2_[%d]"):format(self:EntIndex())
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

		return (isfunction(output_data.Ent.GetEnergyLevel) and output_data.Ent:GetEnergyLevel() or 1) > 0
	end

	-- this unpowers the drill if the energy input is unlinked
	function ENT:MA_OnUnlink(output_data, input_data)
		if input_data.Id ~= "power" then return end

		local timer_name = ("ma_oil_extractor_v2_[%d]"):format(self:EntIndex())
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
			self.SndLoop = self:StartLoopingSound("ambient/machines/transformer_loop.wav")
		end

		self.NextSoundCheck = time + 5
	end

	function ENT:CanConsumeEnergy()
		if not can_work(self, CurTime()) then return false end

		return true
	end

	function ENT:ProduceBarrel()
		self.ExtractedOil = 0
		self:SetNWInt("ExtractedOil", self.ExtractedOil)

		local output_data = _G.MA_Orchestrator.GetOutputData(self, "oil")
		_G.MA_Orchestrator.SendOutputReadySignal(output_data)
	end

	function ENT:ExtractOil(time)
		if time < self.NextOil then return end
		if not can_work(self, time) then return end

		self.NextOil = CurTime() + 1
		self.ExtractedOil = self.ExtractedOil + 1

		if self.ExtractedOil >= Ores.Automation.OilExtractionRate then
			self:ProduceBarrel()
		end

		if self.ExtractedOil % 5 == 0 then -- update every 5 seconds because SetNW is slow
			self:SetNWInt("ExtractedOil", self.ExtractedOil)
		end
	end

	function ENT:Think()
		local time = CurTime()
		self:CheckSoundLoop(time)
		self:ExtractOil(time)
	end

	function ENT:OnRemove()
		if self.SndLoop and self.SndLoop ~= -1 then
			self:StopLoopingSound(self.SndLoop)
		end
	end

	function ENT:SpawnFunction(ply, tr, class_name)
		if not tr.Hit then return end

		local spawn_pos = tr.HitPos + tr.HitNormal * 100
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
	local WHEEL_MDL = "models/props_wasteland/wheel01.mdl"
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
		_G.MA_Orchestrator.RegisterInput(self, "power", "ENERGY", "Energy", "Standard energyy input. More energy equals more ores!")
		_G.MA_Orchestrator.RegisterOutput(self, "oil", "OIL", "Oil", "Standard oil output.")

		self.NextTraceCheck = 0
		self.Wheel = addWheelEntity(self, self:GetUp() * -75)
	end

	local EFFECT_NAME = "WheelDust"
	function ENT:Draw()
		self:DrawModel()

		local time = CurTime()
		local has_energy = can_work(self, time)
		if has_energy then
			local effect_data = EffectData()
			effect_data:SetScale(1.5)
			effect_data:SetOrigin(self:GetPos() + self:GetUp() * -75)
			util.Effect(EFFECT_NAME, effect_data)
		end

		if IsValid(self.Wheel) then
			local ang = self:GetAngles()
			ang:RotateAroundAxis(self:GetForward(), 90)

			if has_energy then
				self.Wheel:SetPos(self:GetPos() + self:GetUp() * (-70 + math.abs(math.sin(CurTime() * -1)) * 10))
				ang:RotateAroundAxis(self:GetUp(), CurTime() * 300 % 360)
			else
				self.Wheel:SetPos(self:GetPos() + self:GetUp() * -70)
			end
			self.Wheel:SetParent(self)

			self.Wheel:SetAngles(ang)
		end
	end

	function ENT:OnRemove()
		SafeRemoveEntity(self.Wheel)
	end

	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			self.MiningFrameInfo = {
				{ Type = "Label", Text = self.PrintName:upper(), Border = true },
				{ Type = "Data", Label = "Oil", Value = self:GetNWInt("ExtractedOil", 0), MaxValue = Ores.Automation.OilExtractionRate },
				{ Type = "State", Value = can_work(self, CurTime()) },
			}
		end

		self.MiningFrameInfo[2].Value = self:GetNWInt("ExtractedOil", 0)
		self.MiningFrameInfo[3].Value = can_work(self, CurTime())

		if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
			self.MiningFrameInfo[4] = { Type = "Action", Binding = "+use", Text = "KICKSTART" }
		end

		return self.MiningFrameInfo
	end

	hook.Add("PlayerBindPress", "mining_oil_extractor_kickstart", function(ply, bind, pressed, code)
		if bind == "+use" and pressed then
			local tr = ply:GetEyeTrace()
			if IsValid(tr.Entity) and tr.Entity:GetClass() == "ma_oil_extractor_v2" and tr.Entity:WorldSpaceCenter():Distance(EyePos()) <= 300 then
				local required_points = math.floor(BASE_KICKSTART_PRICE * math.max(1, Ores.GetPlayerMultiplier(ply) - 2))
				local point_balance = ply:GetNWInt(Ores._nwPoints, 0)
				if required_points > point_balance then
					chat.AddText(Color(230, 130, 65), " ♦ [Ores] ", color_white, ("You do not have enough points to kickstart this extractor (required: %s pts | balance: %s pts)"):format(
						string.Comma(required_points),
						string.Comma(point_balance)
					))
					return
				end

				Derma_Query(
					("Kickstarting the extractor will cost you %s pts (current balance: %s pts)"):format(
						string.Comma(required_points),
						string.Comma(point_balance)
					),
					"Kickstart Extractor",
					"Kickstart", function()
						net.Start("mining_kickstart_extractor")
						net.WriteEntity(tr.Entity)
						net.SendToServer()
					end,
					"Cancel", function() end
				)
			end
		end
	end)
end