msitems.StartItem("spine")

ITEM.State = "entity"
ITEM.WorldModel = "models/Gibs/HGIBS_spine.mdl"
ITEM.EquipSound = "ui/item_helmet_pickup.wav"

ITEM.Inventory = {
	name = "Spine Totem",
	info = "Ores mined by drills have 50% chance to be of better quality for 1h. Drills have a chance to break-down and explode."
}

if SERVER then
	function ITEM:Initialize()
		self:SetModel(self.WorldModel)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
	end

	local function explode_drill(self)
		for _ = 1, math.random(8, 16) do
			local pos = self:WorldSpaceCenter() + VectorRand() * 300
			local expl = ents.Create("env_explosion")
			expl:SetPos(pos)
			expl:Spawn()
			expl:Fire("explode")

			util.BlastDamage(expl, expl, pos, 300, 100)
			self:EmitSound(")ambient/explosions/explode_" .. math.random(1, 9) .. ".wav")
		end

		for _, ent in ipairs(ents.FindInSphere(self:WorldSpaceCenter(), 300)) do
			if ent:IsPlayer() then
				net.Start("gib_explode_command")
					net.WriteEntity(ent)
				net.SendPVS(ent:GetPos())

				ent:Kill()
			elseif ent:GetClass() == "mining_detonite_bomb" then
				SafeRemoveEntity(ent)
			end
		end

		SafeRemoveEntity(self)
	end

	local function trigger_explode_drill(self)
		if self.MA_Exploding then return end

		self.MA_Exploding = true

		self:SetNWBool("IsPowered", false)
		self:SetColor(Color(255, 0, 0))

		local i = 0
		timer.Create(("ma_drill_exploding_[%d]"):format(self:EntIndex()), 0.5, 4, function()
			if not IsValid(self) then return end

			i = i + 1
			self:EmitSound(")buttons/button17.wav", 100, 80 + 20 * i)

			if i >= 4 then
				explode_drill(self)

				ms.Ores.MineCollapse(self:WorldSpaceCenter(), 60, {
					[0] = 100,
				}, activator)
			end
		end)
	end

	function ITEM:OnEquip(ply)
		ply:SetNWBool("MA_BloodDeal", "DRILL_DEAL")
		ms.Ores.SendChatMessage(ply, "The deal is on, you have 1h, mortal...")

		local timer_name = ("ma_drill_deal_[%d]"):format(ply:EntIndex())
		timer.Create(timer_name, 60, 60, function()
			if not IsValid(ply) then
				timer.Remove(timer_name)
				return
			end

			if ply:GetNWBool("MA_BloodDeal", "") ~= "DRILL_DEAL" then
				timer.Remove(timer_name)
				return
			end

			for _, drill in ipairs(ents.FindByClass("ma_drill_v2")) do
				if not drill.CPPIGetOwner then continue end

				local owner = drill:CPPIGetOwner()
				if not IsValid(owner) then continue end
				if owner ~= ply then continue end

				if math.random(0, 100) <= 1.5 then
					trigger_explode_drill(drill)
				end
			end
		end)

		timer.Create(60 * 60, function() -- 20mins
			if not IsValid(ply) then return end

			local cur_deal = ply:GetNWString("MA_BloodDeal", "")
			if cur_deal == "DRILL_DEAL" then
				ply:SetNWString("MA_BloodDeal", "")
			end
		end)

		self:Remove()
	end
end

msitems.EndItem()