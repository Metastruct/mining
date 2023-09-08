msitems.StartItem("rib")

ITEM.State = "entity"
ITEM.WorldModel = "models/Gibs/HGIBS_rib.mdl"
ITEM.EquipSound = "ui/item_helmet_pickup.wav"

ITEM.Inventory = {
	name = "Rib",
	info = "A piece of a rib cage, its origin is unknown but somehow even if you could know, you wouldnt want to know."
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