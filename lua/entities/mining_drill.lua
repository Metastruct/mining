AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Drill"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_drill"
ENT.NextTraceCheck = 0

local function can_work(self, time)
	if not self:GetNWBool("IsPowered", true) then return false end
	if time < self.NextTraceCheck then return self.TraceCheckResult end

	if self:GetNW2Int("Energy", 0) > 0 then
		local tr = util.TraceLine({
			start = self:GetPos() + self:GetForward() * -20,
			endpos = self:GetPos() + self:GetForward() * -75,
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

if SERVER then
	ENT.NextDrilledOre = 0
	ENT.NextSoundCheck = 0

	function ENT:Initialize()
		self:SetModel("models/props_combine/headcrabcannister01a.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self.NextSoundCheck = 0
		self.NextDrilledOre = 0
		self.NextTraceCheck = 0
		self:SetNWBool("IsPowered", true)

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

		timer.Simple(0, function()
			if not IsValid(self) then return end
			Ores.Automation.ReplicateOwnership(self, self)
			self.SndLoop = self:StartLoopingSound("ambient/spacebase/spacebase_drill.wav")
		end)

		Ores.Automation.PrepareForDuplication(self)
		Ores.Automation.RegisterEnergyPoweredEntity(self, {
			{
				Type = "Energy",
				MaxValue = Ores.Automation.BatteryCapacity * 3,
				ConsumptionRate = 10, -- 1 unit every 10 seconds
			}
		})

		if _G.WireLib then
			self.Inputs = _G.WireLib.CreateInputs(self, {"Active (If this is non-zero, activate the drill)"})
		end
	end

	function ENT:TriggerInput(port, state)
		if port == "Active" then self:SetNWBool("IsPowered", tobool(state)) end
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

	function ENT:CanConsumeEnergy()
		if not can_work(self, CurTime()) then return false end

		return true
	end

	local EMPTY_FN = function() end
	function ENT:DrillOres(time)
		if time < self.NextDrilledOre then return end
		if not can_work(self, time) then return end

		local oreRarity = Ores.SelectRarityFromSpawntable()
		local ore = ents.Create("mining_ore")
		ore:SetPos(self:GetPos() + self:GetForward() * 75)
		ore:SetRarity(oreRarity)
		ore:Spawn()
		ore:PhysWake()
		--ore:SetNWBool("SpawnedByDrill", true)

		-- optimization hopefully
		do
			SafeRemoveEntityDelayed(ore, 20)
			ore:SetTrigger(false)
			ore:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS) -- so they dont collide between each others
			ore.Think = EMPTY_FN
			ore.Touch = EMPTY_FN
		end

		if self.CPPIGetOwner then
			ore.GraceOwner = self:CPPIGetOwner()
			ore.GraceOwnerExpiry = time + (60 * 60)
			--ore:CPPISetOwner(ore.GraceOwner)
		end

		-- constraint.NoCollide(ore, self, 0, 0)

		-- efficiency goes up the more its powered:
		-- at less than 33% -> 10s,
		-- less than 66% -> 8s
		-- less than 100% -> 6s
		local effiencyRateIncrease = (math.ceil(self:GetNW2Int("Energy", 0) / Ores.Automation.BatteryCapacity) - 1) * 2
		self.NextDrilledOre = time + (Ores.Automation.BaseOreProductionRate - effiencyRateIncrease)
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

	CreateConVar("sbox_maxmining_drill", "12", FCVAR_ARCHIVE, "Maximum amount of mining drills entities a player can have", 0, 100)

	hook.Add("PlayerSpawnedSENT", "mining_drill", function(ply, ent)
		if ent:GetClass() == "mining_drill" then
			ply:AddCount("mining_drill", ent)
			return true
		end
	end)

	hook.Add("PlayerSpawnSENT", "mining_drill", function(ply, className)
		if not className then return end

		if className == "mining_drill" and not ply:CheckLimit("mining_drill") then
			return false
		end
	end)
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

	function ENT:OnGraphDraw(x, y)
		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		local argoniteColor = Ores.__R[argoniteRarity].HudColor
		local GU = Ores.Automation.GraphUnit

		surface.SetDrawColor(argoniteColor)
		surface.SetMaterial(Ores.Automation.EnergyMaterial)
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
				{ Type = "Label", Text = "DRILL", Border = true },
				{ Type = "Data", Label = "ENERGY", Value = self:GetNW2Int("Energy", 0), MaxValue = self:GetNW2Int("MaxEnergy", Ores.Automation.BatteryCapacity * 3) },
				{ Type = "State", Value = can_work(self, CurTime()) }
			}
		end

		self.MiningFrameInfo[2].Value = self:GetNW2Int("Energy", 0)
		self.MiningFrameInfo[3].Value = can_work(self, CurTime())
		return self.MiningFrameInfo
	end
end