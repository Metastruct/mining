AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Argonite Drone Controller"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_argonite_drone_controller"

local function can_work(self)
	if not self:GetNWBool("IsPowered", true) then return false end
	if self:GetNW2Int("Detonite", 0) > 0 then return true end

	return false
end

local MAX_DETONITE = 100
function ENT:GetDroneCount()
	if not can_work(self) then return 0 end

	local amount = self:GetNW2Int("Detonite", 0)
	if amount < 33 then
		return 1
	elseif amount >= 33 and amount < 66 then
		return 2
	else
		return 3
	end
end

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/hunter/blocks/cube075x075x075.mdl")
		self:SetMaterial("models/props_lab/projector_noise")
		self:SetColor(Color(255, 0, 0, 255))

		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetNWBool("IsPowered", true)
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
			self.Inputs = _G.WireLib.CreateInputs(self, {"Active (If this is non-zero, activate the router)"})
		end

		Ores.Automation.PrepareForDuplication(self)
		timer.Simple(0, function()
			if not IsValid(self) then return end

			Ores.Automation.ReplicateOwnership(self, self)
		end)

		self.EnergySettings = {
			Type = "Detonite",
			MaxValue = MAX_DETONITE,
			ConsumptionRate = 10, -- once every 10 seconds,
			ConsumptionAmount = 0,
			NoBrush = true,
		}

		Ores.Automation.RegisterEnergyPoweredEntity(self, { self.EnergySettings }, {
			{
				Identifier = "DroneCount (Outputs the current bandwidth usage) [NORMAL]",
				StartValue = 0,
			},
		})

		local timer_name = ("mining_argonite_drone_hive_[%d]"):format(self:EntIndex())
		timer.Create(timer_name, 1, 0, function()
			if not IsValid(self) then
				timer.Remove(timer_name)
				return
			end

			self:UpdateDrones()
		end)
	end

	function ENT:TriggerInput(port, state)
		if not _G.WireLib then return end
		if not isnumber(state) then return end

		if port == "Active" then
			self:SetNWBool("IsPowered", tobool(state))
			self:UpdateDrones()
		end
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
			if self.CPPIGetOwner and IsValid(self:CPPIGetOwner()) then
				drone:CPPISetOwner(self:CPPIGetOwner())
			end

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

		local detoniteRarity = Ores.Automation.GetOreRarityByName("Detonite")
		local detoniteAmount = Ores.GetPlayerOre(ent, detoniteRarity)
		if detoniteAmount < 1 then return end

		local toGive = math.min(MAX_DETONITE, detoniteAmount)

		self:AddDetonite(toGive)
		Ores.TakePlayerOre(ent, detoniteRarity, toGive)
	end

	function ENT:CanConsumeEnergy()
		if not can_work(self) then return false end

		return true
	end

	function ENT:OnRemove()
		for _, drone in pairs(self.Drones) do
			SafeRemoveEntity(drone)
		end
	end
end

if CLIENT then
	function ENT:OnGraphDraw(x, y)
		local argoniteRarity = Ores.Automation.GetOreRarityByName("Detonite")
		local argoniteColor = Ores.__R[argoniteRarity].HudColor
		local GU = Ores.Automation.GraphUnit

		surface.SetDrawColor(argoniteColor)
		surface.DrawRect(x - GU / 2, y - GU / 2, GU, GU)

		surface.SetDrawColor(125, 125, 125, 255)
		surface.DrawOutlinedRect(x - GU / 2, y - GU / 2, GU, GU, 2)

		surface.SetTextColor(255, 255, 255, 255)
		local perc = (math.Round((self:GetNW2Int("Detonite", 0) / self:GetNW2Int("MaxDetonite", MAX_DETONITE)) * 100)) .. "%"
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
				{ Type = "Label", Text = "CONTROLLER", Border = true },
				{ Type = "Data", Label = "DETONITE", Value = self:GetNW2Int("Detonite", 0), MaxValue = self:GetNW2Int("MaxDetonite", MAX_DETONITE) },
				{ Type = "Data", Label = "DRONES", Value = self:GetDroneCount() },
				{ Type = "State", Value = can_work(self) }
			}
		end

		self.MiningFrameInfo[2].Value = self:GetNW2Int("Detonite", 0)
		self.MiningFrameInfo[3].Value = self:GetDroneCount()
		self.MiningFrameInfo[4].Value = can_work(self, CurTime())
		return self.MiningFrameInfo
	end
end