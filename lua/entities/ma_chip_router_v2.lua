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
ENT.ClassName = "ma_chip_router_v2"
ENT.MaxBandwidth = 999
ENT.IconOverride = "entities/ma_chip_router_v2.png"

function ENT:CanWork()
	return self:GetNWBool("Wiremod_Active", true)
end

if SERVER then
	resource.AddFile("materials/entities/ma_chip_router_v2.png")

	function ENT:Initialize()
		self:SetModel("models/props_phx/construct/metal_plate1.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetNWBool("Wiremod_Active", true)
		self:SetUseType(SIMPLE_USE)
		self.NextStateUpdate = 0
		self.ConsumptionAmount = 0

		self:SetSubMaterial(0, "phoenix_storms/stripes")
		self:SetSubMaterial(1, "phoenix_storms/stripes")
		self:SetSubMaterial(2, "models/xqm/lightlinesred")

		_G.MA_Orchestrator.RegisterInput(self, "bandwidth", "DETONITE", "Bandwidth", "Detonite input required to power the chips.")

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {"Active (If this is non-zero, activate the router)"})
			_G.WireLib.CreateOutputs(self, {
				"Usage (Outputs the current bandwidth usage) [NORMAL]",
				"Bandwidth (Outputs the current bandwidth level) [NORMAL]",
				"MaxBandwidth (Outputs the max level of bandwidth) [NORMAL]",
			})

			_G.WireLib.TriggerOutput(self, "MaxBandwidth", self.MaxBandwidth)
		end

		Ores.Automation.PrepareForDuplication(self)
		timer.Simple(0, function()
			if not IsValid(self) then return end

			Ores.Automation.ReplicateOwnership(self, self)
		end)

		_G.MA_Orchestrator.EntityTimer("ma_chip_router_v2", self, 10, 0, function()
			local bandwidth = self:GetNW2Int("Bandwidth", 0)
			local new_bandwidth = bandwidth - self:GetNWInt("BandwidthUsage", 0)
			self:SetNW2Int("Bandwidth", new_bandwidth)

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Bandwidth", new_bandwidth)
			end
		end)
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if input_data.Id ~= "bandwidth" then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if input_data.Id == "bandwidth" then
			if not isnumber(output_data.Ent.RejectCount) then return end
			if output_data.Ent.RejectCount < 1 then return end

			self:AddDetonite(1)
			output_data.Ent.RejectCount = math.max(0, output_data.Ent.RejectCount - 1)
		end
	end

	function ENT:TriggerInput(port, state)
		if not _G.WireLib then return end
		if not isnumber(state) then return end

		if port == "Active" then
			self:SetNWBool("Wiremod_Active", tobool(state))
			self:SetChipState(tobool(state))
		end
	end

	function ENT:AddDetonite(amount)
		if amount < 1 then return end

		local cur_amount = self:GetNW2Int("Bandwidth", 0)
		local new_amount = math.min(self.MaxBandwidth, cur_amount + amount)

		self:SetNW2Int("Bandwidth", new_amount)

		if _G.WireLib then
			_G.WireLib.TriggerOutput(self, "Bandwidth", new_amount)
		end
	end

	function ENT:Think()
		if not self.CPPIGetOwner then return end
		if not self:GetNWBool("Wiremod_Active", true) then return end

		local owner = self:CPPIGetOwner()
		if not IsValid(owner) then return end

		if CurTime() >= self.NextStateUpdate then
			self.NextStateUpdate = CurTime() + 2

			local total_ops = 0
			local chip_count = 0
			for _, chip in pairs(self:GetChips()) do
				local chip_class = chip:GetClass()
				if chip_class == "gmod_wire_expression2" then
					local ops = chip.OverlayData.prfbench
					total_ops = total_ops + ops
				elseif chip_class == "starfall_processor" then
					if chip.instance then
						local ops = (chip.instance.cpu_average / chip.instance.cpuQuota) * 1000
						total_ops = total_ops + ops
					end
				end

				chip_count = chip_count + 1
			end

			if chip_count < 1 then
				self:SetNWInt("BandwidthUsage", 0)

				if _G.WireLib then
					_G.WireLib.TriggerOutput(self, "Usage", 0)
				end

				return
			end

			local required_bandwidth = math.max(math.ceil(chip_count / 2), math.ceil(total_ops / 100 / 2))
			self.ConsumptionAmount = required_bandwidth

			self:SetNWInt("BandwidthUsage", required_bandwidth)

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Usage", required_bandwidth)
			end

			self:SetChipState(required_bandwidth <= self:GetNW2Int("Bandwidth", 0))
		end
	end

	function ENT:GetChips()
		local owner = self.CPPIGetOwner and self:CPPIGetOwner()
		if not IsValid(owner) then return end

		local chips = {}
		for _, ent in pairs(constraint.GetAllConstrainedEntities(self)) do
			if ent:GetClass() ~= "gmod_wire_expression2" and ent:GetClass() ~= "starfall_processor" then continue end
			if ent.CPPIGetOwner and ent:CPPIGetOwner() ~= owner then continue end

			chips[ent] = ent
		end

		for _, ent in ipairs(self:GetChildren()) do
			if ent:GetClass() ~= "gmod_wire_expression2" and ent:GetClass() ~= "starfall_processor" then continue end
			if ent.CPPIGetOwner and ent:CPPIGetOwner() ~= owner then continue end

			chips[ent] = ent
		end

		return chips
	end

	local function check_blocked_state(ply)
		timer.Simple(0, function()
			if not IsValid(ply) then return end
			if not Ores.Automation.ChipsRouted[ply] then return end

			local chips = {}
			local e2s = ents.FindByClass("gmod_wire_expression2")
			for _, e2 in ipairs(e2s) do
				if e2:GetPlayer() ~= ply then continue end

				table.insert(chips, e2)
			end

			local sfs = ents.FindByClass("starfall_processor")
			for _, sf in ipairs(sfs) do
				if sf.owner ~= ply then continue end

				table.insert(chips, sf)
			end

			local all_chips_ok = true
			local has_chips = false
			for _, chip in ipairs(chips) do
				has_chips = true

				if not Ores.Automation.ChipsRouted[ply][chip] then -- checks if the chip is on a router and powered and an e2
					all_chips_ok = false
					break
				end
			end

			if not has_chips then return end

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
		for _, chip in pairs(chips) do
			Ores.Automation.ChipsRouted[owner] = Ores.Automation.ChipsRouted[owner] or {}

			local chipClass = chip:GetClass()
			if enabled then
				if chipClass == "starfall_processor" then
					if Ores.Automation.ChipsRouted[owner][chip] ~= true or istable(chip.error) then
						chip:Compile()
						BroadcastLua(([[local c = Entity(%d) if IsValid(c) then c:Compile() end]]):format(chip:EntIndex()))
						should_check = true
					end
				elseif chipClass == "gmod_wire_expression2" or chip.error ~= false then
					if Ores.Automation.ChipsRouted[owner][chip] ~= true then
						chip:Reset()
						should_check = true
					end
				end
			else
				if chipClass == "starfall_processor" then
					if Ores.Automation.ChipsRouted[owner][chip] ~= false or not istable(chip.error) then
						chip:Destroy()
						chip:Error({ message = "Unsufficient Bandwidth", traceback = "" })
						BroadcastLua(([[local c = Entity(%d) if IsValid(c) then c:Destroy() c:Error({message="Unsufficient Bandwidth",traceback=""}) end]]):format(chip:EntIndex()))
						should_check = true
					end
				elseif chipClass == "gmod_wire_expression2" then
					if Ores.Automation.ChipsRouted[owner][chip] ~= false or chip.error ~= true then
						chip:Error("Unsufficient Bandwidth", "Unsufficient Bandwidth")
						should_check = true
					end
				end
			end

			Ores.Automation.ChipsRouted[owner][chip] = enabled
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
			for _, chip in pairs(chips) do
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
			local detoniteRarity = Ores.GetOreRarityByName("Detonite")
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
	function ENT:Initialize()
		_G.MA_Orchestrator.RegisterInput(self, "bandwidth", "DETONITE", "Bandwidth", "Detonite input required to power the chips.")
	end

	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			self.MiningFrameInfo = {
				{ Type = "Label", Text = self.PrintName:upper(), Border = true },
				{ Type = "Data", Label = "Usage", Value = self:GetNWInt("BandwidthUsage", 0) },
				{ Type = "Data", Label = "Bandwidth", Value = self:GetNW2Int("Bandwidth", 0) },
				{ Type = "State", Value = self:GetNWBool("Wiremod_Active", true) },
			}
		end

		self.MiningFrameInfo[2].Value = self:GetNWInt("BandwidthUsage", 0)
		self.MiningFrameInfo[3].Value = self:GetNW2Int("Bandwidth", 0)
		self.MiningFrameInfo[4].Value = self:GetNWBool("Wiremod_Active", true)

		return self.MiningFrameInfo
	end
end