ENT.Type = "anim"
ENT.Base = "mining_ore"

ENT.ClassName = "mining_ore_fools"

ENT.WeaponUp = Vector(0,0,3)
ENT.WeaponRotatedOffset = Vector(0,-4.25,0)

function ENT:SetupDataTables()
	self.BaseClass.SetupDataTables(self)

	self:NetworkVar("Entity",0,"Target")
	self:NetworkVar("Bool",0,"Aggro")
end

function ENT:GetPistolPosition(target)
	local origin = self:WorldSpaceCenter()
	local eyePos = target:EyePos()

	local rotatedOffset = Vector(self.WeaponRotatedOffset)
	rotatedOffset:Rotate(Angle(0,(eyePos-origin):Angle().y,0))

	local pos = origin+self.WeaponUp+rotatedOffset
	local ang = (eyePos-pos):Angle()
	ang:RotateAroundAxis(ang:Up(),180)

	return pos,ang
end