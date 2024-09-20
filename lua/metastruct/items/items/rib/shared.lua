msitems.StartItem("rib")

ITEM.State = "entity"
ITEM.WorldModel = "models/Gibs/HGIBS_rib.mdl"
ITEM.EquipSound = "ui/item_helmet_pickup.wav"

ITEM.Inventory = {
	name = "Rib Totem",
	info = "Unlocks every mining equipment temporarily. All the equipments are twice as expensive in the shop."
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
		ply:SetNWBool("MA_ShopDeal", true)
		ms.Ores.SendChatMessage(ply, "The deal is on, you have 20 minutes, mortal...")

		timer.Simple(60 * 20, function() -- 20mins
			if not IsValid(ply) then return end

			ply:SetNWBool("MA_ShopDeal", false)
		end)
	end
end

msitems.EndItem()