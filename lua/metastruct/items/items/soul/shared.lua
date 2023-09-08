msitems.StartItem("soul")

ITEM.State = "entity"
ITEM.WorldModel = "models/props_lab/huladoll.mdl"
ITEM.EquipSound = "ambient/atmosphere/cave_hit2.wav"

ITEM.Inventory = {
	name = "Soul",
	info = "Your soul, reclaimed from some weird powerful entity. Keep it preciously!"
}

if SERVER then
	function ITEM:Initialize()
		self:SetModel(self.WorldModel)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
	end
end

msitems.EndItem()