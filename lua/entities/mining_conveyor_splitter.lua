AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu"
ENT.Spawnable = true
ENT.Category = "Mining"
ENT.PrintName = "Conveyor Splitter"
ENT.ClassName = "mining_ore_conveyor_splitter"

local COLOR_BLACK = Color(0, 0, 0, 255)
if SERVER then
	ENT.CurrentOutput = 0
	ENT.ProcessedEnts = {}

	function ENT:SetupInsOuts()
		self.In = ents.Create("prop_physics")
		self.In:SetModel("models/props_phx/construct/metal_wire1x1.mdl")
		self.In:SetMaterial("phoenix_storms/stripes")
		self.In:SetPos(self:WorldSpaceCenter() + self:GetForward() * 30)

		local inAng = self:GetAngles()
		inAng:RotateAroundAxis(self:GetRight(), 90)

		self.In:SetAngles(inAng)
		self.In:Spawn()
		self.In:SetParent(self)

		self.InTrigger = ents.Create("base_anim")
		self.InTrigger:SetModel("models/hunter/blocks/cube075x075x025.mdl")
		self.InTrigger:SetMaterial("models/debug/debugwhite")
		self.InTrigger:SetColor(COLOR_BLACK)
		self.InTrigger:SetSolid(SOLID_BBOX)
		self.InTrigger:SetNotSolid(true)
		self.InTrigger:SetTrigger(true)
		self.InTrigger:SetPos(self:WorldSpaceCenter() + self:GetForward() * 22)
		self.InTrigger:SetAngles(self.In:GetAngles())
		self.InTrigger:SetParent(self)
		self.InTrigger:Spawn()
		self.InTrigger.Touch = function(_, ent) self:OnTouch(ent, "Forward") end
		self.InTrigger:SetSolidFlags(FSOLID_NOT_STANDABLE)

		self.Right = ents.Create("prop_physics")
		self.Right:SetModel("models/props_phx/construct/metal_wire1x1.mdl")
		self.Right:SetMaterial("phoenix_storms/stripes")
		self.Right:SetPos(self:WorldSpaceCenter() + self:GetRight() * -30)

		local rightAng = self:GetAngles()
		rightAng:RotateAroundAxis(self:GetForward(), 90)

		self.Right:SetAngles(rightAng)
		self.Right:Spawn()
		self.Right:SetParent(self)

		self.RightTrigger = ents.Create("base_anim")
		self.RightTrigger:SetModel("models/hunter/blocks/cube075x075x025.mdl")
		self.RightTrigger:SetMaterial("models/debug/debugwhite")
		self.RightTrigger:SetSolid(SOLID_BBOX)
		self.RightTrigger:SetNotSolid(true)
		self.RightTrigger:SetColor(COLOR_BLACK)
		self.RightTrigger:SetPos(self:WorldSpaceCenter() + self:GetRight() * -22)
		self.RightTrigger:SetAngles(self.Right:GetAngles())
		self.RightTrigger:Spawn()
		self.RightTrigger:SetParent(self)
		self.RightTrigger:SetTrigger(true)
		self.RightTrigger:PhysWake()
		self.RightTrigger.Touch = function(_, ent) self:OnTouch(ent, "Right") end
		self.RightTrigger:SetSolidFlags(FSOLID_NOT_STANDABLE)

		self.Left = ents.Create("prop_physics")
		self.Left:SetModel("models/props_phx/construct/metal_wire1x1.mdl")
		self.Left:SetMaterial("phoenix_storms/stripes")
		self.Left:SetPos(self:WorldSpaceCenter() + self:GetRight() * 30)

		local leftAng = self:GetAngles()
		leftAng:RotateAroundAxis(-self:GetForward(), 90)

		self.Left:SetAngles(leftAng)
		self.Left:Spawn()
		self.Left:SetParent(self)

		self.LeftTrigger = ents.Create("base_anim")
		self.LeftTrigger:SetModel("models/hunter/blocks/cube075x075x025.mdl")
		self.LeftTrigger:SetMaterial("models/debug/debugwhite")
		self.LeftTrigger:SetSolid(SOLID_BBOX)
		self.LeftTrigger:SetNotSolid(true)
		self.LeftTrigger:SetColor(COLOR_BLACK)
		self.LeftTrigger:SetPos(self:WorldSpaceCenter() + self:GetRight() * 22)
		self.LeftTrigger:SetAngles(self.Left:GetAngles())
		self.LeftTrigger:Spawn()
		self.LeftTrigger:SetParent(self)
		self.LeftTrigger:SetTrigger(true)
		self.LeftTrigger:PhysWake()
		self.LeftTrigger.Touch = function(_, ent) self:OnTouch(ent, "Left") end
		self.LeftTrigger:SetSolidFlags(FSOLID_NOT_STANDABLE)
	end

	function ENT:Initialize()
		self:SetModel("models/hunter/blocks/cube1x1x1.mdl")
		self:SetMaterial("phoenix_storms/future_vents")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetSaveValue("m_takedamage", 0)
		self:PhysWake()

		self:SetupInsOuts()
		self.ProcessedEnts = {}
		self.Directions = {
			{ Name = "Forward", Function = function() return self.InTrigger:GetUp() end },
			{ Name = "Right", Function = function() return self.RightTrigger:GetUp() end },
			{ Name = "Left", Function = function() return self.LeftTrigger:GetUp() end },
		}

		timer.Simple(0, function()
			if not IsValid(self) then return end
			Ores.Automation.ReplicateOwnership(self, self)
		end)
	end

	function ENT:Think()
		if not self.SndLoop then
			self.SndLoop = CreateSound(self, "ambient/machines/refinery_loop_1.wav")
			self.SndLoop:PlayEx(0.25, 100)

			return
		end

		if not self.SndLoop:IsPlaying() then
			self.SndLoop:Stop()
			self.SndLoop:PlayEx(0.25, 100)
		end
	end

	function ENT:OnRemove()
		if self.SndLoop then
			self.SndLoop:Stop()
		end
	end

	local Z_OFFSET = Vector(0, 0, 10)
	function ENT:OnTouch(ent, directionFrom)
		if ent == self then return end
		if self.ProcessedEnts[ent] then return end
		if Ores.IgnoredClasses[ent:GetClass()] then return end

		local parent = ent:GetParent()
		if IsValid(parent) then return end

		local phys = ent:GetPhysicsObject()
		if not IsValid(phys) then return end

		local availableOutDirections = {}
		for _, existingDirection in ipairs(self.Directions) do
			if existingDirection.Name ~= directionFrom then
				table.insert(availableOutDirections, existingDirection.Function() * -1)
			end
		end

		local maxs = ent:OBBMaxs()
		local basePos = self:WorldSpaceCenter() + Z_OFFSET
		local offset = 40 + math.max(maxs.x, maxs.y, maxs.z)
		local previousSpeed = phys:GetVelocity():Length()
		local dir
		if self.CurrentOutput == 0 then
			dir = availableOutDirections[1]
			self.CurrentOutput = 1
		else
			dir = availableOutDirections[2]
			self.CurrentOutput = 0
		end

		ent:SetPos(basePos + dir * offset)
		phys:SetVelocity(dir * previousSpeed)

		self.ProcessedEnts[ent] = true
		timer.Simple(1, function()
			if not IsValid(self) then return end
			self.ProcessedEnts[ent] = nil
		end)
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
end