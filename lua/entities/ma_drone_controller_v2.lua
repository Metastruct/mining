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
ENT.ClassName = "ma_drone_controller_v2"
ENT.IconOverride = "entities/ma_drone_controller_v2.png"

local function can_work(self)
	if not self:GetNWBool("Wiremod_Active", true) then return false end
	if self:GetNW2Int("Detonite", 0) > 0 then return true end

	return false
end

local MAX_DETONITE = 300
function ENT:GetDroneCount()
	if not can_work(self) then return 0 end

	local amount = self:GetNW2Int("Detonite", 0) / MAX_DETONITE
	if amount < 0.33 then
		return 0
	elseif amount >= 0.33 and amount < 0.66 then
		return 1
	elseif amount >= 0.66 and amount < 1 then
		return 2
	elseif amount == 1 then
		return 3
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
			_G.WireLib.CreateInputs(self, {"Active (If this is non-zero, activate the router)"})
		end

		Ores.Automation.PrepareForDuplication(self)
		timer.Simple(0, function()
			if not IsValid(self) then return end

			Ores.Automation.ReplicateOwnership(self, self)
		end)

		local timer_name = ("mining_argonite_drone_hive_[%d]"):format(self:EntIndex())
		timer.Create(timer_name, 1, 0, function()
			if not IsValid(self) then
				timer.Remove(timer_name)
				return
			end

			self:UpdateDrones()
		end)
	end

	function ENT:UpdateDrones()
		if not can_work(self) then
			for _, drone in pairs(self.Drones) do
				SafeRemoveEntity(drone)
			end

			self.Drones = {}
			return
		end

		local droneCount = self:GetDroneCount()
		if droneCount > #self.Drones then
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
		elseif droneCount < #self.Drones then
			for i = droneCount, #self.Drones do
				SafeRemoveEntity(self.Drones[i])
				self.Drones[i] = nil
			end
		end
	end

	function ENT:AddDetonite(amount)
		if amount < 1 then return end

		local curAmount = self:GetNW2Int("Detonite", 0)
		local newAmount = math.min(MAX_DETONITE, curAmount + amount)

		self:SetNW2Int("Detonite", newAmount)

		if _G.WireLib then
			_G.WireLib.TriggerOutput(self, "Detonite", newAmount)
			_G.WireLib.TriggerOutput(self, "DroneCount", self:GetDroneCount())
		end

		self:UpdateDrones()
	end

	function ENT:Use(ent)
		if not ent:IsPlayer() then return end
		if self.CPPIGetOwner and self:CPPIGetOwner() ~= ent then return end

		local detoniteRarity = Ores.GetOreRarityByName("Detonite")
		local detoniteAmount = Ores.GetPlayerOre(ent, detoniteRarity)
		if detoniteAmount < 1 then return end

		local toGive = math.min(MAX_DETONITE, detoniteAmount)

		self:AddDetonite(toGive)
		Ores.TakePlayerOre(ent, detoniteRarity, toGive)
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

	CreateConVar("sbox_maxmining_argonite_drone_controller", "1", FCVAR_ARCHIVE, "Maximum amount of argonite drone controller entities a player can have", 0, 100)

	hook.Add("OnEntityCreated", "mining_argonite_drone_controller", function(ent)
		if ent:GetClass() ~= "mining_argonite_drone_controller" then return end
		if not ent.CPPIGetOwner then return end

		timer.Simple(0, function()
			if not IsValid(ent) then return end

			local ply = ent:CPPIGetOwner()
			if not IsValid(ply) then
				SafeRemoveEntity(ent)
				return
			end

			if ply:CheckLimit("mining_argonite_drone_controller") then
				ply:AddCount("mining_argonite_drone_controller", ent)
			else
				SafeRemoveEntity(ent)
			end
		end)
	end)

	hook.Add("PlayerSpawnSENT", "mining_argonite_drone_controller", function(ply, className)
		if not className then return end

		if className == "mining_argonite_drone_controller" and not ply:CheckLimit("mining_argonite_drone_controller") then
			return false
		end
	end)
end

if CLIENT then
	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			self.MiningFrameInfo = {
				{ Type = "Label", Text = self.PrintName:upper(), Border = true },
				{ Type = "Data", Label = "Detonite", Value = self:GetNW2Int("Detonite", 0), MaxValue = self:GetNW2Int("MaxDetonite", MAX_DETONITE) },
				{ Type = "Data", Label = "Drones", Value = self:GetDroneCount() },
				{ Type = "State", Value = can_work(self) },
				{ Type = "Action", Binding = "+use", Text = "FILL" }
			}
		end

		self.MiningFrameInfo[2].Value = self:GetNW2Int("Detonite", 0)
		self.MiningFrameInfo[3].Value = self:GetDroneCount()
		self.MiningFrameInfo[4].Value = can_work(self, CurTime())
		return self.MiningFrameInfo
	end
end