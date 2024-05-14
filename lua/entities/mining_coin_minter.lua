AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu"
ENT.Spawnable = true
ENT.Category = "Mining"
ENT.PrintName = "Coin Minter"
ENT.ClassName = "mining_coin_minter"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_wasteland/laundry_dryer002.mdl")
		self:SetMaterial("phoenix_storms/future_vents")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetTrigger(true)
		self:PhysWake()
		self:SetNWInt("MintedCoins", 0)
		self:SetUseType(SIMPLE_USE)

		Ores.Automation.PrepareForDuplication(self)

		timer.Simple(0, function()
			if not IsValid(self) then return end

			Ores.Automation.ReplicateOwnership(self, self)
		end)

		if _G.WireLib then
			_G.WireLib.CreateOutputs(self, {"Amount (Outputs the current amount of coins minted) [NORMAL]" })
		end
	end

	function ENT:Touch(ent)
		if ent.InvalidOre then return end

		local className = ent:GetClass()
		if className ~= "mining_ore_ingot" and className ~= "mining_ore" then return end

		-- use the player multiplier if its higher than the ingot worth
		local ingotWorth = Ores.Automation.IngotWorth
		if self.CPPIGetOwner and IsValid(self:CPPIGetOwner()) then
			ingotWorth = math.max(ingotWorth, Ores.GetPlayerMultiplier(self:CPPIGetOwner()) * 1.5)
		end

		local classWorth = className == "mining_ore_ingot" and ingotWorth or 1
		local classSize = className == "mining_ore_ingot" and Ores.Automation.IngotSize or 1
		local rarity = ent:GetRarity()
		local oreData = Ores.__R[rarity]
		if oreData then
			local earnings = oreData.Worth * classSize * classWorth
			local curCoins = self:GetNWInt("MintedCoins", 0)
			local newAmount = curCoins + math.ceil(earnings)
			self:SetNWInt("MintedCoins", newAmount)

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Amount", newAmount)
			end
		end

		SafeRemoveEntity(ent)
		ent.InvalidOre = true
	end

	-- fallback in case trigger stops working
	function ENT:PhysicsCollide(data)
		if not IsValid(data.HitEntity) then return end

		self:Touch(data.HitEntity)
	end

	function ENT:Use(activator)
		if not activator:IsPlayer() then return end
		if self.CPPIGetOwner and self:CPPIGetOwner() ~= activator then return end

		if self._nextuse and self._nextuse > CurTime() then
			local time_left = tostring(math.floor(self._nextuse - CurTime())) .. "s"
			activator:ChatPrint("The minter is cooling down! Please wait" .. time_left)

			return
		end

		self._nextuse = CurTime() + 60 * 5

		local curCoins = self:GetNWInt("MintedCoins", 0)
		if activator.GiveCoins and curCoins > 0 then
			activator:GiveCoins(curCoins, "mining automation => minter")
		end

		self:SetNWInt("MintedCoins", 0)
		self:EmitSound(")physics/surfaces/underwater_impact_bullet3.wav", 75, 70)

		if _G.WireLib then
			_G.WireLib.TriggerOutput(self, "Amount", 0)
		end
	end

	function ENT:SpawnFunction(ply, tr, className)
		if not tr.Hit then return end

		local spawnPos = tr.HitPos + tr.HitNormal * 50
		local ent = ents.Create(className)
		ent:SetPos(spawnPos)
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
	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			local data = {
				{ Type = "Label", Text = "MINTER", Border = true },
				{ Type = "Data", Label = "COINS", Value = self:GetNWInt("MintedCoins", 0) },
			}

			if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
				table.insert(data, { Type = "Action", Binding = "+use", Text = "CLAIM" })
			end

			self.MiningFrameInfo = data
		end

		self.MiningFrameInfo[2].Value = self:GetNWInt("MintedCoins", 0)
		if self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() and not self.MiningFrameInfo[3] then
			table.insert(self.MiningFrameInfo, { Type = "Action", Binding = "+use", Text = "CLAIM" })
		end

		return self.MiningFrameInfo
	end
end