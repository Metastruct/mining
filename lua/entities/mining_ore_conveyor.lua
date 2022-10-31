AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu"
ENT.Spawnable = true
ENT.Category = "Mining"
ENT.PrintName = "Mining Conveyor"
ENT.ClassName = "ore_conveyor"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_phx/construct/wood/wood_panel1x2.mdl")
		self:SetMaterial("models/weapons/v_stunbaton/w_shaft01a")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetSaveValue("m_takedamage", 0)
		self:PhysWake()

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetPos(self:GetPos() - Vector(0, 0, 10))

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetUp(), 90)

		self.Frame:SetAngles(ang)
		self.Frame:SetModel("models/props_phx/construct/wood/wood_wire1x1x2.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetSaveValue("m_takedamage", 0)
		self.Frame:Spawn()
		self.Frame:SetParent(self)

		self.Trigger = ents.Create("base_anim")
		self.Trigger:SetModel("models/hunter/blocks/cube1x2x1.mdl")
		self.Trigger:SetPos(self:GetPos() + self:GetRight() * -24 + self:GetUp() * 10)
		self.Trigger:SetAngles(self:GetAngles())
		self.Trigger:SetParent(self)
		self.Trigger:SetTrigger(true)
		self.Trigger:SetNotSolid(true)
		self.Trigger:SetNoDraw(true)

		self.Trigger.Touch = function(_, ent)
			self:Touch(ent)
		end

		timer.Simple(0, function()
			if not IsValid(self) then return end

			self.SndLoop = CreateSound(self, "ambient/machines/refinery_loop_1.wav")
			self.SndLoop:PlayEx(0.25, 100)
		end)
	end

	function ENT:OnRemove()
		if self.SndLoop then
			self.SndLoop:Stop()
		end
	end

	local VECTOR_ZERO = Vector(0, 0, 0)
	local BAD_CLASSES = {
		--player = true,
		ore_conveyor = true,
	}
	function ENT:Touch(ent)
		if self.Frame == ent then return end
		if BAD_CLASSES[ent:GetClass()] then return end
		--if ent:GetClass() ~= "mining_rock" then return end

		local phys = ent:GetPhysicsObject()
		if not IsValid(phys) then return end

		local coef = -200---0.1 * phys:GetMass() * 200
		local forward_force = coef * self:GetRight()

		local local_pos = -self:WorldToLocal(ent:GetPos())
		local_pos.z = 0
		local_pos.y = 0

		local pull_force = 10 * self:GetPhysicsObject():LocalToWorldVector(local_pos)
		local force = forward_force + pull_force
		force.z = 0

		if ent:IsPlayer() or ent:IsNPC() then
			ent:SetGroundEntity(self)
			ent:SetVelocity(force)
			return
		end

		phys:SetVelocity(force + self:GetUp() * -phys:GetMass())
		phys:SetAngleVelocity(VECTOR_ZERO)
	end
end

if CLIENT then
	local MAT = Material("models/weapons/v_stunbaton/w_shaft01a")
	local MTX = Matrix()
	local TRANSLATION = Vector(0, 0, 0)
	function ENT:Draw()
		TRANSLATION.x = -CurTime() * 5

		MTX:SetTranslation(TRANSLATION)
		MAT:SetMatrix("$basetexturetransform", MTX)

		render.SetMaterial(MAT)
		self:DrawModel()
	end
end