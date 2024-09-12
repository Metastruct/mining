AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu"
ENT.Spawnable = true
ENT.Category = "Mining V2"
ENT.PrintName = "Coin Minter"
ENT.ClassName = "mining_coin_minter"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_wasteland/laundry_dryer002.mdl")
		self:SetMaterial("phoenix_storms/future_vents")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetNWInt("MintedCoins", 0)
		self:SetUseType(SIMPLE_USE)

		_G.MA_Orchestrator.RegisterInput(self, "ores", "ORE", "Ores", "Standard ore input.")
		_G.MA_Orchestrator.RegisterInput(self, "ingots", "INGOT", "Ingots", "Standard ingot input.")
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if input_data.Id ~= "ores" and input_data.Id ~= "ingots" then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if input_data.Id ~= "ores" and input_data.Id ~= "ingots" then return end

		-- use the player multiplier if its higher than the ingot worth
		local ingot_worth = Ores.Automation.IngotWorth
		if self.CPPIGetOwner and IsValid(self:CPPIGetOwner()) then
			ingot_worth = math.max(ingot_worth, Ores.GetPlayerMultiplier(self:CPPIGetOwner()) * 1.5)
		end

		local class_worth = input_data.Id == "ingots" and ingot_worth or 1
		local class_size = input_data.Id == "ingots" and Ores.Automation.IngotSize or 1
		local rarity = input_data.Id == "ingots" and table.remove(output_data.Ent.OreQueue, 1) or table.remove(output_data.Ent.IngotQueue, 1)
		local ore_data = Ores.__R[rarity]
		if ore_data then
			local earnings = ore_data.Worth * class_size * class_worth
			local cur_coins = self:GetNWInt("MintedCoins", 0)
			local new_amount = cur_coins + math.ceil(earnings)
			self:SetNWInt("MintedCoins", new_amount)
		end
	end

	function ENT:Use(activator)
		if not activator:IsPlayer() then return end
		if self.CPPIGetOwner and self:CPPIGetOwner() ~= activator then return end

		if self._nextuse and self._nextuse > CurTime() then
			local time_left = tostring(math.floor(self._nextuse - CurTime())) .. "s"
			activator:ChatPrint("The minter is cooling down! Please wait " .. time_left)

			return
		end

		self._nextuse = CurTime() + 60 * 5

		local cur_coins = self:GetNWInt("MintedCoins", 0)
		if activator.GiveCoins and cur_coins > 0 then
			activator:GiveCoins(cur_coins, "mining automation => minter")
		end

		self:SetNWInt("MintedCoins", 0)
		self:EmitSound(")physics/surfaces/underwater_impact_bullet3.wav", 75, 70)
	end

	function ENT:SpawnFunction(ply, tr, class_name)
		if not tr.Hit then return end

		local spawn_pos = tr.HitPos + tr.HitNormal * 50
		local ent = ents.Create(class_name)
		ent:SetPos(spawn_pos)
		ent:Activate()
		ent:Spawn()

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:EnableMotion(false)
		end

		return ent
	end
end

if CLIENT then
	function ENT:Initialize()
		_G.MA_Orchestrator.RegisterInput(self, "ores", "ORE", "Ores", "Standard ore input.")
		_G.MA_Orchestrator.RegisterInput(self, "ingots", "INGOT", "Ingots", "Standard ingot input.")
	end
end