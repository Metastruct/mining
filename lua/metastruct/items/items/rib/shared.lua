msitems.StartItem("rib")

ITEM.State = "entity"
ITEM.WorldModel = "models/Gibs/HGIBS_rib.mdl"
ITEM.EquipSound = "ui/item_helmet_pickup.wav"
ITEM.DontReturnToInventory = true

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

	function ITEM:OnEquip(ply)
		ply:SetNWBool("MA_BloodDeal", "SHOP_DEAL")
		ms.Ores.SendChatMessage(ply, "The deal is on, you have 20 minutes, mortal...")

		timer.Simple(60 * 20, function() -- 20mins
			if not IsValid(ply) then return end

			local cur_deal = ply:GetNWString("MA_BloodDeal", "")
			if cur_deal == "SHOP_DEAL" then
				ply:SetNWString("MA_BloodDeal", "")
			end
		end)

		self:Remove()
		return false
	end
end

msitems.EndItem()