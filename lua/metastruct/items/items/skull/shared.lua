msitems.StartItem("skull")

ITEM.State = "entity"
ITEM.WorldModel = "models/Gibs/HGIBS.mdl"
ITEM.EquipSound = "ui/item_helmet_pickup.wav"

ITEM.Inventory = {
	name = "Skull Totem",
	info = "25% Increase in Coin Minter output. Batteries are 2 times slower to complete."
}

if SERVER then
	function ITEM:Initialize()
		self:SetModel(self.WorldModel)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
	end

	function ITEM:OnUse(ply)
		ply:SetNWBool("MA_BloodDeal", "MINTER_DEAL")
		ms.Ores.SendChatMessage(ply, "The deal is on, mortal...")

		self:Remove()
	end
end

msitems.EndItem()