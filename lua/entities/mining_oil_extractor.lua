AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Oil Extractor"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_oil_extractor"
ENT.NextTraceCheck = 0

local function can_work(self, time)
	if not self:GetNWBool("IsPowered", true) then return false end
	if time < self.NextTraceCheck then return self.TraceCheckResult end

	if self:GetNW2Int("Energy", 0) > 0 then
		local tr = util.TraceLine({
			start = self:GetPos() + self:GetUp() * -75,
			endpos = self:GetPos() + self:GetUp() * -100,
			mask = MASK_SOLID_BRUSHONLY,
		})

		self.NextTraceCheck = time + 1.5
		self.TraceCheckResult = tr.Hit
		return tr.Hit
	end

	self.NextTraceCheck = time + 1.5
	self.TraceCheckResult = false
	return false
end

local BASE_KICKSTART_PRICE = 12500

if SERVER then
	util.AddNetworkString("mining_kickstart_extractor")

	net.Receive("mining_kickstart_extractor", function(_, ply)
		local extractor = net.ReadEntity()
		if not IsValid(extractor) then return end

		local requiredPoints = math.floor(BASE_KICKSTART_PRICE * math.max(1, Ores.GetPlayerMultiplier(ply) - 2))
		local pointBalance = ply:GetNWInt(Ores._nwPoints, 0)
		if requiredPoints > pointBalance then return end

		Ores.Print(ply, ("kickstarted a extractor using %d pts"):format(amount))
		Ores.TakePlayerPoints(ply, amount)

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
		self:SetNWBool("IsPowered", true)

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
		self.Frame:SetTrigger(true)

		self.Out = ents.Create("prop_physics")
		self.Out:SetModel("models/props_phx/construct/metal_wire1x1.mdl")
		self.Out:SetMaterial("phoenix_storms/stripes")
		self.Out:SetPos(self:GetPos() + self:GetRight() * 24 + self:GetUp() * -35)

		ang = self:GetAngles()
		--ang:RotateAroundAxis(self:GetRight(), 90)
		ang:RotateAroundAxis(self:GetForward(), 90)

		self.Out:SetAngles(ang)
		self.Out:Spawn()
		self.Out:SetParent(self)
		self.Out:SetNotSolid(true)

		timer.Simple(0, function()
			if not IsValid(self) then return end

			self:Activate()
			Ores.Automation.ReplicateOwnership(self, self)
			self.SndLoop = self:StartLoopingSound("ambient/machines/transformer_loop.wav")
		end)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {
				"Active",
			}, {
				"Whether the extractor is active or not",
			})
		end

		Ores.Automation.PrepareForDuplication(self)
		Ores.Automation.RegisterEnergyPoweredEntity(self, {
			{
				Type = "Energy",
				MaxValue = Ores.Automation.BatteryCapacity * 3,
				ConsumptionRate = 5, -- 1 unit every 5 seconds
			}
		}, {
			{
				Identifier = "Oil (Outputs the current amount of extracted oil) [NORMAL]",
				StartValue = 0,
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

		local fuelTank = ents.Create("mining_fuel_tank")
		fuelTank:SetPos(self:GetPos() + self:GetRight() * 50 + self:GetUp() * -45)
		fuelTank:SetNWInt("CoalCount", 150)
		fuelTank:Spawn()
		fuelTank:PhysWake()

		if _G.WireLib then
			_G.WireLib.TriggerOutput(fuelTank, "Amount", 150)
		end

		SafeRemoveEntityDelayed(fuelTank, Ores.Automation.OilExtractionRate)

		timer.Simple(0, function()
			if IsValid(self) and IsValid(fuelTank) then
				Ores.Automation.ReplicateOwnership(fuelTank, self, true)
			end
		end)
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

		if _G.WireLib then
			local curOil = (self.ExtractedOil / Ores.Automation.OilExtractionRate) * 100
			_G.WireLib.TriggerOutput(self, "Oil", curOil)
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

	function ENT:SpawnFunction(ply, tr, className)
		if not tr.Hit then return end

		local spawnPos = tr.HitPos + tr.HitNormal * 100
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
end

if CLIENT then
	local WHEEL_MDL = "models/props_wasteland/wheel01.mdl"
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
		self.NextTraceCheck = 0
		self.Wheel = addWheelEntity(self, self:GetUp() * -75)
	end

	local EFFECT_NAME = "WheelDust"
	function ENT:Draw()
		self:DrawModel()

		local time = CurTime()
		local hasEnergy = can_work(self, time)
		if hasEnergy then
			local effectData = EffectData()
			effectData:SetScale(1.5)
			effectData:SetOrigin(self:GetPos() + self:GetUp() * -75)
			util.Effect(EFFECT_NAME, effectData)
		end

		if IsValid(self.Wheel) then
			local ang = self:GetAngles()
			ang:RotateAroundAxis(self:GetForward(), 90)

			if hasEnergy then
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

	local OIL_MAT = Material("models/shadertest/shader4")
	function ENT:OnGraphDraw(x, y)
		local GU = Ores.Automation.GraphUnit

		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(OIL_MAT)
		surface.DrawTexturedRect(x - GU / 2, y - GU / 2, GU, GU)

		surface.SetDrawColor(125, 125, 125, 255)
		surface.DrawOutlinedRect(x - GU / 2, y - GU / 2, GU, GU, 2)

		surface.SetTextColor(255, 255, 255, 255)
		local perc = (math.Round((self:GetNW2Int("Energy", 0) / self:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity * 3)) * 100)) .. "%"
		surface.SetFont("DermaDefault")
		local tw, th = surface.GetTextSize(perc)
		surface.SetTextPos(x - tw / 2, y - th / 2)
		surface.DrawText(perc)

		local state = can_work(self, CurTime())
		surface.SetDrawColor(state and 0 or 255, state and 255 or 0, 0, 255)
		surface.DrawOutlinedRect(x - GU / 2 + 2, y - GU / 2 + 2, GU - 4, 2)
	end

	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			self.MiningFrameInfo = {
				{ Type = "Label", Text = "EXTRACTOR", Border = true },
				{ Type = "Data", Label = "ENERGY", Value = self:GetNW2Int("Energy", 0), MaxValue = self:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity * 3), Border = true },
				{ Type = "Data", Label = "OIL", Value = self:GetNWInt("ExtractedOil", 0), MaxValue = Ores.Automation.OilExtractionRate },
				{ Type = "State", Value = can_work(self, CurTime()) },
			}
		end

		self.MiningFrameInfo[2].Value = self:GetNW2Int("Energy", 0)
		self.MiningFrameInfo[3].Value = self:GetNWInt("ExtractedOil", 0)
		self.MiningFrameInfo[4].Value = can_work(self, CurTime())

		if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
			self.MiningFrameInfo[5] = { Type = "Action", Binding = "+use", Text = "KICKSTART" }
		end

		return self.MiningFrameInfo
	end

	hook.Add("PlayerBindPress", "mining_oil_extractor_kickstart", function(ply, bind, pressed, code)
		if bind == "+use" and pressed then
			local tr = ply:GetEyeTrace()
			if IsValid(tr.Entity) and tr.Entity:GetClass() == "mining_oil_extractor" and tr.Entity:WorldSpaceCenter():Distance(EyePos()) <= 300 then
				local requiredPoints = math.floor(BASE_KICKSTART_PRICE * math.max(1, Ores.GetPlayerMultiplier(ply) - 2))
				local pointBalance = ply:GetNWInt(Ores._nwPoints, 0)
				if requiredPoints > pointBalance then
					chat.AddText(Color(230, 130, 65), " ♦ [Ores] ", color_white, ("You do not have enough points to kickstart this extractor (required: %s pts | balance: %s pts)"):format(
						string.Comma(requiredPoints),
						string.Comma(pointBalance)
					))
					return
				end

				Derma_Query(
					("Kickstarting the extractor will cost you %s pts (current balance: %s pts)"):format(
						string.Comma(requiredPoints),
						string.Comma(pointBalance)
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
