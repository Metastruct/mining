AddCSLuaFile()

module("ms", package.seeall)

Ores = Ores or {}
Ores.Automation = Ores.Automation or {}
Ores.Automation.ChipsRouted = Ores.Automation.ChipsRouted or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Chip Router"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_chip_router"
ENT.MaxBandwidth = 999

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_phx/construct/metal_plate1.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetNWBool("IsPowered", true)
		self:SetUseType(SIMPLE_USE)
		self.NextStateUpdate = 0

		self:SetSubMaterial(0, "phoenix_storms/stripes")
		self:SetSubMaterial(1, "phoenix_storms/stripes")
		self:SetSubMaterial(2, "models/xqm/lightlinesred")

		if _G.WireLib then
			self.Inputs = _G.WireLib.CreateInputs(self, {"Active (If this is non-zero, activate the router)"})
		end

		Ores.Automation.PrepareForDuplication(self)
		timer.Simple(0, function()
			if not IsValid(self) then return end

			Ores.Automation.ReplicateOwnership(self, self)
		end)

		self.EnergySettings = {
			Type = "Bandwidth",
			MaxValue = 999,
			ConsumptionRate = 10, -- once every 10 seconds,
			ConsumptionAmount = 0,
			NoBrush = true,
		}

		Ores.Automation.RegisterEnergyPoweredEntity(self, { self.EnergySettings }, {
			{
				Identifier = "Usage (Outputs the current bandwidth usage) [NORMAL]",
				StartValue = 0,
			}
		})
	end

	function ENT:TriggerInput(port, state)
		if not _G.WireLib then return end
		if not isnumber(state) then return end

		if port == "Active" then
			self:SetNWBool("IsPowered", tobool(state))
			self:SetChipState(tobool(state))
		end
	end

	function ENT:AddDetonite(amount)
		if amount < 1 then return end

		local curAmount = self:GetNW2Int("Bandwidth", 0)
		local newAmount = math.min(self.MaxBandwidth, curAmount + amount)

		self:SetNW2Int("Bandwidth", newAmount)

		if _G.WireLib then
			_G.WireLib.TriggerOutput(self, "Bandwidth", newAmount)
		end
	end

	function ENT:Use(ent)
		if not ent:IsPlayer() then return end
		if self.CPPIGetOwner and self:CPPIGetOwner() ~= ent then return end

		local detoniteRarity = Ores.Automation.GetOreRarityByName("Detonite")
		local detoniteAmount = Ores.GetPlayerOre(ent, detoniteRarity)
		local toGive = math.min(self.MaxBandwidth, detoniteAmount)

		self:AddDetonite(toGive)
		Ores.TakePlayerOre(ent, detoniteRarity, toGive)
	end

	function ENT:Think()
		if not self.CPPIGetOwner then return end
		if not self:GetNWBool("IsPowered", true) then return end

		local owner = self:CPPIGetOwner()
		if not IsValid(owner) then return end

		if CurTime() >= self.NextStateUpdate then
			self.NextStateUpdate = CurTime() + 2

			local totalOps = 0
			local chipCount = 0
			for _, chip in ipairs(self:GetChips()) do
				local ops = chip.OverlayData.prfbench
				totalOps = totalOps + ops
				chipCount = chipCount + 1
			end

			if chipCount < 1 then
				self:SetNWInt("BandwidthUsage", 0)

				if _G.WireLib then
					_G.WireLib.TriggerOutput(self, "Usage", 0)
				end

				return
			end

			local requiredBandwidth = math.max(math.ceil(chipCount / 2), math.ceil(totalOps / 100 / 2))
			self.EnergySettings.ConsumptionAmount = requiredBandwidth

			self:SetNWInt("BandwidthUsage", requiredBandwidth)

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Usage", requiredBandwidth)
			end

			self:SetChipState(requiredBandwidth <= self:GetNW2Int("Bandwidth", 0))
		end
	end

	function ENT:CanConsumeEnergy(energyType)
		return self:GetNW2Int("Bandwidth", 0) >= self:GetNWInt("BandwidthUsage", 0)
	end

	function ENT:GetChips()
		local owner = self.CPPIGetOwner and self:CPPIGetOwner()
		if not IsValid(owner) then return end

		local chips = {}
		for _, ent in pairs(constraint.GetAllConstrainedEntities(self)) do
			if ent:GetClass() ~= "gmod_wire_expression2" then continue end
			if ent.CPPIGetOwner and ent:CPPIGetOwner() ~= owner then continue end

			table.insert(chips, ent)
		end

		return chips
	end

	local function check_blocked_state(ply)
		if not Ores.Automation.ChipsRouted[ply] then return end

		local all_chips_ok = true
		local has_chips = false
		for chip, _ in pairs(ply._miningChipsOwned or {}) do
			has_chips = true

			if not Ores.Automation.ChipsRouted[ply][chip] then -- checks if the chip is on a router and powered and an e2
				all_chips_ok = false
				break
			end
		end

		if not has_chips then return end

		timer.Simple(0, function()
			if not IsValid(ply) then return end

			if ply._miningBlocked and all_chips_ok then
				ply._miningBlocked = nil
				ply._miningCooldown = nil
			elseif not ply._miningBlocked and not all_chips_ok then
				ply._miningBlocked = true
			end
		end)
	end

	function ENT:SetChipState(enabled)
		local owner = self.CPPIGetOwner and self:CPPIGetOwner()
		if not IsValid(owner) then return end

		local should_check = false
		local chips = self:GetChips()
		for _, chip in ipairs(chips) do
			Ores.Automation.ChipsRouted[owner] = Ores.Automation.ChipsRouted[owner] or {}
			Ores.Automation.ChipsRouted[owner][chip] = enabled

			if enabled then
				if chip.error then
					chip:Reset()
					should_check = true
				end
			else
				if chip.error ~= true then
					chip:Error("Unsufficient Bandwidth", "Unsufficient Bandwidth")
					should_check = true
				end
			end
		end

		if should_check then
			check_blocked_state(owner)
		end
	end

	function ENT:OnRemove()
		local owner = self.CPPIGetOwner and self:CPPIGetOwner()
		if not IsValid(owner) then return end

		if Ores.Automation.ChipsRouted[owner] then
			local chips = self:GetChips(owner)
			for _, chip in ipairs(chips) do
				Ores.Automation.ChipsRouted[owner][chip] = nil
			end

			if table.Count(Ores.Automation.ChipsRouted[owner]) < 1 then
				Ores.Automation.ChipsRouted[owner] = nil
			end
		end
	end

	-- makes it possible to collect detonite no matter what
	hook.Add("OnEntityCreated", ENT.ClassName, function(ent)
		if ent:GetClass() ~= "mining_ore" then return end

		timer.Simple(0, function()
			local detoniteRarity = Ores.Automation.GetOreRarityByName("Detonite")
			local rarity = ent:GetRarity()

			if rarity ~= detoniteRarity then return end

			local old_touch = ent.Touch
			function ent:Touch(e)
				if e:IsPlayer() then
					self:Consume(e)
					return
				end

				old_touch(self, e)
			end
		end)
	end)
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	local CHIP_MATERIAL = Material("beer/wiremod/gate_e2")
	function ENT:OnGraphDraw(x, y)
		local detoniteRarity = Ores.Automation.GetOreRarityByName("Detonite")
		local detoniteColor = Ores.__R[detoniteRarity].HudColor
		local GU = Ores.Automation.GraphUnit

		if not CHIP_MATERIAL:IsError() then
			surface.SetDrawColor(255, 255, 255, 255)
			surface.SetMaterial(CHIP_MATERIAL)
			surface.DrawTexturedRect(x - GU / 2, y - GU / 2, GU, GU)
		else
			surface.SetDrawColor(28, 28, 28, 255)
			surface.DrawRect(x - GU / 2, y - GU / 2, GU, GU)
		end

		surface.SetDrawColor(detoniteColor)
		surface.DrawOutlinedRect(x - GU / 2, y - GU / 2, GU, GU, 2)

		surface.SetTextColor(255, 255, 255, 255)
		local perc = (math.Round((self:GetNWInt("Bandwidth", 0) / self.MaxBandwidth) * 100)) .. "%"
		surface.SetFont("DermaDefault")
		local tw, th = surface.GetTextSize(perc)
		surface.SetTextPos(x - tw / 2, y - th / 2)
		surface.DrawText(perc)
	end

	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			self.MiningFrameInfo = {
				{ Type = "Label", Text = "CHIP ROUTER", Border = true },
				{ Type = "Data", Label = "USAGE", Value = self:GetNWInt("BandwidthUsage", 0) },
				{ Type = "Data", Label = "BANDWIDTH", Value = self:GetNW2Int("Bandwidth", 0) },
				{ Type = "State", Value = self:GetNWBool("IsPowered", true) },
				{ Type = "Action", Binding = "+use", Text = "FILL" }
			}
		end

		self.MiningFrameInfo[2].Value = self:GetNWInt("BandwidthUsage", 0)
		self.MiningFrameInfo[3].Value = self:GetNW2Int("Bandwidth", 0)
		self.MiningFrameInfo[4].Value = self:GetNWBool("IsPowered", true)

		return self.MiningFrameInfo
	end
end