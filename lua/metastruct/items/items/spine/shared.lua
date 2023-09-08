msitems.StartItem("spine")

ITEM.State = "entity"
ITEM.WorldModel = "models/Gibs/HGIBS_spine.mdl"
ITEM.EquipSound = "ui/item_helmet_pickup.wav"

ITEM.Inventory = {
	name = "Spine",
	info = "Old remains of what looks like a human spine, you don't even dare to imagine how it was obtained."
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