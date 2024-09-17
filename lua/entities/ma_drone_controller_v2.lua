AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Drone Controller"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.ClassName = "ma_drone_controller_v2"
ENT.IconOverride = "entities/ma_drone_controller_v2.png"

function ENT:CanWork()
	if not self:GetNWBool("Wiremod_Active", true) then return false end
	if self:GetNW2Int("Detonite", 0) > 0 then return true end

	return false
end

local MAX_DETONITE = 60
local MAX_DRONES = 3
function ENT:GetDroneCount()
	if not self:CanWork() then return 0 end

	local amount = self:GetNW2Int("Detonite", 0) / MAX_DETONITE
	if amount > 0 then return MAX_DRONES end

	if amount < 0.33 then
		return MAX_DRONES - 2
	elseif amount >= 0.33 and amount < 0.66 then
		return MAX_DRONES - 1
	elseif amount >= 0.66 then
		return MAX_DRONES
	end
end

if SERVER then
	resource.AddFile("materials/entities/ma_drone_controller_v2.png")

	function ENT:Initialize()
		self:SetModel("models/hunter/blocks/cube075x075x075.mdl")
		self:SetMaterial("models/props_lab/projector_noise")
		self:SetColor(Color(255, 0, 0, 255))

		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetUseType(SIMPLE_USE)
		self.Drones = {}

		self.Core = ents.Create("prop_physics")
		self.Core:SetModel("models/maxofs2d/hover_rings.mdl")
		self.Core:SetColor(Color(255, 0, 0, 255))
		self.Core:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self.Core:SetPos(self:WorldSpaceCenter())
		self.Core:SetModelScale(2)
		self.Core:SetParent(self)
		self.Core:SetTransmitWithParent(true)

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x1.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetCollisionGroup(COLLISION_GROUP_WEAPON)
		self.Frame:SetPos(self:GetPos() + self:GetForward() * 24)
		self.Frame:SetAngles(self:GetAngles())
		self.Frame:Spawn()
		self.Frame.PhysgunDisabled = true
		self.Frame:SetParent(self)
		self.Frame:SetTransmitWithParent(true)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {"Active (If this is non-zero, activate the controller)"})
			_G.WireLib.CreateOutputs(self, {
				"DroneCount (Outputs the current drone count) [NORMAL]",
				"MaxDroneCount (Outputs the max amount of drones at once) [NORMAL]",
				"Detonite (Outputs the current detonite level) [NORMAL]",
				"MaxDetonite (Outputs the max level of detonite) [NORMAL]",
			})

			_G.WireLib.TriggerOutput(self, "DroneCount", 0)
			_G.WireLib.TriggerOutput(self, "MaxDroneCount", MAX_DRONES)
			_G.WireLib.TriggerOutput(self, "Detonite", 0)
			_G.WireLib.TriggerOutput(self, "MaxDetonite", MAX_DETONITE)
		end

		Ores.Automation.PrepareForDuplication(self)
		timer.Simple(0, function()
			if not IsValid(self) then return end

			Ores.Automation.ReplicateOwnership(self, self)
		end)

		_G.MA_Orchestrator.RegisterInput(self, "detonite", "DETONITE", "detonite", "Detonite input required to power the drones.")

		local controller_timer_tick = 0
		_G.MA_Orchestrator.EntityTimer("mining_argonite_drone_hive", self, 1, 0, function()
			self:UpdateDrones()

			controller_timer_tick = controller_timer_tick + 1

			local drone_count = self:GetDroneCount()
			if controller_timer_tick % (MAX_DRONES * 10) == 0 then
				local cur_detonite = self:GetNW2Int("Detonite", 0)
				local new_detonite = math.max(0, cur_detonite - drone_count)
				self:SetNW2Int("Detonite", new_detonite)

				if _G.WireLib then
					_G.WireLib.TriggerOutput(self, "Detonite", new_detonite)
					_G.WireLib.TriggerOutput(self, "DroneCount", drone_count)
				end
			end
		end)
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if input_data.Id ~= "detonite" then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if input_data.Id == "detonite" then
			if not isnumber(output_data.Ent.RejectCount) then return end
			if output_data.Ent.RejectCount < 1 then return end

			self:AddDetonite(1)
			output_data.Ent.RejectCount = math.max(0, output_data.Ent.RejectCount - 1)
		end
	end

	function ENT:UpdateDrones()
		if not self:CanWork() then
			for _, drone in pairs(self.Drones) do
				SafeRemoveEntity(drone)
			end

			self.Drones = {}
			return
		end

		local drone_count = self:GetDroneCount()
		if drone_count > #self.Drones then
			local drone = ents.Create("mining_argonite_drone")
			drone:Spawn()
			drone:Teleport(self:WorldSpaceCenter() + drone.HeightOffset)
			Ores.Automation.ReplicateOwnership(drone, self)

			local old_OnRemove = drone.OnRemove
			local hive = self
			function drone:OnRemove()
				old_OnRemove(self)
				if IsValid(hive) then
					table.RemoveByValue(hive.Drones, self)
				end
			end

			table.insert(self.Drones, drone)
		elseif drone_count < #self.Drones then
			for i = drone_count, #self.Drones do
				SafeRemoveEntity(self.Drones[i])
				self.Drones[i] = nil
			end
		end
	end

	function ENT:AddDetonite(amount)
		if amount < 1 then return end

		local cur_amount = self:GetNW2Int("Detonite", 0)
		local new_amount = math.min(MAX_DETONITE, cur_amount + amount)

		self:SetNW2Int("Detonite", new_amount)

		if _G.WireLib then
			_G.WireLib.TriggerOutput(self, "Detonite", new_amount)
			_G.WireLib.TriggerOutput(self, "DroneCount", self:GetDroneCount())
		end

		self:UpdateDrones()
	end

	function ENT:OnRemove()
		for _, drone in pairs(self.Drones) do
			SafeRemoveEntity(drone)
		end
	end

	function ENT:TriggerInput(port, state)
		if port == "Active" then
			self:SetNWBool("Wiremod_Active", tobool(state))
		end
	end
end

if CLIENT then
	function ENT:Initialize()
		_G.MA_Orchestrator.RegisterInput(self, "detonite", "DETONITE", "detonite", "Detonite input required to power the drones.")
	end

	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			self.MiningFrameInfo = {
				{ Type = "Label", Text = self.PrintName:upper(), Border = true },
				{ Type = "Data", Label = "Detonite", Value = self:GetNW2Int("Detonite", 0), MaxValue = self:GetNW2Int("MaxDetonite", MAX_DETONITE) },
				{ Type = "Data", Label = "Drones", Value = self:GetDroneCount() },
				{ Type = "State", Value = self:CanWork() },
			}
		end

		self.MiningFrameInfo[2].Value = self:GetNW2Int("Detonite", 0)
		self.MiningFrameInfo[3].Value = self:GetDroneCount()
		self.MiningFrameInfo[4].Value = self:CanWork()
		return self.MiningFrameInfo
	end
end