AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu"
ENT.Spawnable = true
ENT.Category = "Mining"
ENT.PrintName = "Conveyor"
ENT.ClassName = "mining_ore_conveyor"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_phx/construct/wood/wood_panel1x2.mdl")
		self:SetMaterial("models/weapons/v_stunbaton/w_shaft01a") -- set that by default just in case
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetSaveValue("m_takedamage", 0)
		self:PhysWake()
		self:SetNWBool("IsPowered", true)
		self:SetNWInt("Direction", -1)

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetPos(self:GetPos() - Vector(0, 0, 10))

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetUp(), 90)

		self.Frame:SetAngles(ang)
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x2.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:Spawn()
		self.Frame:SetParent(self)

		Ores.Automation.PrepareForDuplication(self)

		timer.Simple(0, function()
			if not IsValid(self) then return end

			Ores.Automation.ReplicateOwnership(self, self)
			self.SndLoop = self:StartLoopingSound("ambient/machines/refinery_loop_1.wav")

			if self.CPPIGetOwner then
				local owner = self:CPPIGetOwner()
				if IsValid(owner) and owner:GetInfoNum("mining_automation_entity_frames", 1) < 1 then
					SafeRemoveEntity(self.Frame)
				end
			end
		end)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {
				"Active",
				"Direction"
			}, {
				"Whether the conveyor is active or not",
				"The direction the conveyor should transport things to",
			})
		end
	end

	function ENT:TriggerInput(port, state)
		if not _G.WireLib then return end
		if not isnumber(state) then return end

		if port == "Active" then
			local isPowered = tobool(state)
			self:SetNWBool("IsPowered", isPowered)
			if isPowered then
				if IsValid(self.Frame) then
					local mins, maxs = self.Frame:OBBMins(), self.Frame:OBBMaxs()
					local pos = self.Frame:WorldSpaceCenter()
					for _, ent in ipairs(ents.FindInBox(pos + mins, pos + maxs)) do
						ent:PhysWake()
					end
				end

				if isnumber(self.SndLoop) and self.SndLoop ~= -1 then return end

				self.SndLoop = self:StartLoopingSound("ambient/machines/refinery_loop_1.wav")
			else
				if isnumber(self.SndLoop) and self.SndLoop ~= -1 then
					self:StopLoopingSound(self.SndLoop)
					self.SndLoop = nil
				end
			end
		elseif port == "Direction" then
			self:SetNWInt("Direction", state == 0 and -1 or 1)
		end
	end

	function ENT:OnRemove()
		if isnumber(self.SndLoop) and self.SndLoop ~= -1 then
			self:StopLoopingSound(self.SndLoop)
		end
	end

	local VECTOR_ZERO = Vector(0, 0, 0)
	function ENT:Touch(ent)
		if not self:GetNWBool("IsPowered", true) then return end
		if self.Frame == ent then return end
		if Ores.Automation.IgnoredClasses[ent:GetClass()] then return end

		local phys = ent:GetPhysicsObject()
		if not IsValid(phys) then return end

		local coef = 200 * self:GetNWInt("Direction", -1)
		local forwardForce = coef * self:GetRight()

		local localPos = -self:WorldToLocal(ent:GetPos())
		localPos.z = 0
		localPos.y = 0

		local oldForce = phys:GetVelocity()
		local pullForce = 10 * self:GetPhysicsObject():LocalToWorldVector(localPos)
		local force = forwardForce + pullForce
		force.z = oldForce.z

		if ent:IsPlayer() or ent:IsNPC() then
			ent:SetGroundEntity(self)
			ent:SetVelocity(force)
			return
		end

		phys:SetVelocity(force)
		phys:SetAngleVelocity(VECTOR_ZERO)
	end
end

if CLIENT then
	local BASE_MAT = Material("models/weapons/v_stunbaton/w_shaft01a")
	function ENT:Initialize()
		self:CreateConveyorMaterial()
	end

	function ENT:CreateConveyorMaterial()
		local realMatName = FrameNumber() .. "_mining_conveyor"
		self.Material = CreateMaterial(realMatName, "VertexLitGeneric", {
			["$basetexture"] = BASE_MAT:GetTexture("$basetexture"):GetName(),
			["$model"] = "1",
		})

		self.MaterialName = "!" .. realMatName
	end

	local MTX = Matrix()
	local TRANSLATION = Vector(0, 0, 0)
	function ENT:Draw()
		if not self.Material or not self.MaterialName then
			self:CreateConveyorMaterial()
		end

		if self:GetNWBool("IsPowered", true) then
			TRANSLATION.x = CurTime() * 5 * self:GetNWInt("Direction", -1)

			MTX:SetTranslation(TRANSLATION)
			self.Material:SetMatrix("$basetexturetransform", MTX)
		end

		self:SetMaterial(self.MaterialName)
		self:DrawModel()
	end

	function ENT:OnGraphDraw(x, y)
		draw.NoTexture()

		if ent:GetNWBool("IsPowered", true) then
			surface.SetDrawColor(30, 30, 30, 255)
		else
			surface.SetDrawColor(60, 0, 0, 255)
		end

		local GU = Ores.Automation.GraphUnit

		surface.DrawTexturedRectRotated(x, y, GU, GU * 2, -ent:GetAngles().y)

		if ent:GetNWBool("IsPowered", true) then
			surface.SetDrawColor(200, 200, 200, 255)

			local dir = ent:GetRight()
			local dir_side = ent:GetForward()
			surface.DrawLine(x + dir.x * -GU, y + dir.y * -GU, x + dir.x * GU, y + dir.y * GU)

			if ent:GetNWInt("Direction", -1) == -1 then
				surface.DrawLine(x + dir.x * -GU, y + dir.y * -GU, x + dir.x * -GU / 2 + dir_side.x * -GU / 2, y + dir.y * -GU / 2 + dir_side.y * -GU / 2)
				surface.DrawLine(x + dir.x * -GU, y + dir.y * -GU, x + dir.x * -GU / 2 + dir_side.x * GU / 2, y + dir.y * -GU / 2 + dir_side.y * GU / 2)
			else
				surface.DrawLine(x + dir.x * GU, y + dir.y * GU, x + dir.x * GU / 2 + dir_side.x * -GU / 2, y + dir.y * GU / 2 + dir_side.y * -GU / 2)
				surface.DrawLine(x + dir.x * GU, y + dir.y * GU, x + dir.x * GU / 2 + dir_side.x * GU / 2, y + dir.y * GU / 2 + dir_side.y * GU / 2)
			end
		end
	end
end
