msitems.StartItem("skull")

ITEM.State = "entity"
ITEM.WorldModel = "models/Gibs/HGIBS.mdl"
ITEM.EquipSound = "ui/item_helmet_pickup.wav"

ITEM.Inventory = {
	name = "Skull",
	info = "Looks like a humanoid skull, there are still some muscle tissues left indicating its owner perished not too long ago..."
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