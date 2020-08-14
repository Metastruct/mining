include("shared.lua")

ENT.WeaponPath = "models/weapons/w_pistol.mdl"
ENT.WeaponDropped = false

util.PrecacheModel(ENT.WeaponPath)

function ENT:Initialize()
	if self.WeaponModel and self.WeaponModel:IsValid() then
		self.WeaponModel:Remove()
	end

	self._pistolTime = CurTime()+2

	self.BaseClass.Initialize(self)
end

function ENT:Draw()
	self.BaseClass.Draw(self)

	if not self:GetAggro() then
		if not self.WeaponDropped then
			if self.WeaponModel and self.WeaponModel:IsValid() then
				self.WeaponModel:SetNoDraw(false)
				self.WeaponModel:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
				self.WeaponModel:PhysicsInit(SOLID_VPHYSICS)

				local phys = self.WeaponModel:GetPhysicsObject()
				if phys:IsValid() then
					phys:SetMaterial("weapon")
					phys:Wake()
				end

				SafeRemoveEntityDelayed(self.WeaponModel,10)
			end

			self.WeaponDropped = true
		end

		return
	elseif self._pistolTime > CurTime() then
		return
	end

	if not (self.WeaponModel and self.WeaponModel:IsValid()) then
		self.WeaponModel = ClientsideModel(self.WeaponPath)
		self.WeaponModel:SetNoDraw(true)
	end

	local target = self:GetTarget()
	if target:IsValid() and target:Alive() then
		local pos,ang = self:GetPistolPosition(target)

		self.WeaponModel:SetPos(pos)
		self.WeaponModel:SetAngles(ang)

		render.SetColorModulation(1,1,1)
		self.WeaponModel:DrawModel()
	else
		self:SetAggro(false)
	end
end

function ENT:OnRemove()
	if self.WeaponModel and self.WeaponModel:IsValid() then
		self.WeaponModel:Remove()
	end

	self.BaseClass.OnRemove(self)
end