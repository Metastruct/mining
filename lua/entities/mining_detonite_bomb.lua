AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Detonite Bomb"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_detonite_bomb"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/maxofs2d/hover_classic.mdl")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetUseType(SIMPLE_USE)
		self:SetTrigger(true)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {
				"Detonate",
			}, {
				"Detonates the bomb if its ready",
			})

			_G.WireLib.CreateOutputs(self, {
				"Amount (Outputs the current amount of detonite filled in) [NORMAL]",
				"MaxCapacity (Outputs the maximum detonite capacity) [NORMAL]"
			})

			_G.WireLib.TriggerOutput(self, "Amount", 0)
			_G.WireLib.TriggerOutput(self, "MaxCapacity", Ores.Automation.BombCapacity)
		end

		Ores.Automation.PrepareForDuplication(self)
	end

	function ENT:TriggerInput(port, state)
		if not _G.WireLib then return end
		if not isnumber(state) then return end

		local shouldDetonate = tobool(state)
		if port == "Detonate" and shouldDetonate then
			self:TriggerDetonation(self.CPPIGetOwner and self:CPPIGetOwner())
		end
	end

	function ENT:StartTouch(ent)
		local curAmount = self:GetNWInt("DetoniteAmount", 0)
		if curAmount >= Ores.Automation.BombCapacity then return end

		if ent:GetClass() == "mining_ore" and ent:GetRarity() == Ores.Automation.GetOreRarityByName("Detonite") then
			if ent.MiningBombRemoved then return end

			ent:Remove()
			ent.MiningBombRemoved = true
			self:SetNWInt("DetoniteAmount", math.min(Ores.Automation.BombCapacity, curAmount + 1))

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Amount", curAmount + 1)
			end
		end
	end

	function ENT:Detonate()
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

	function ENT:TriggerDetonation(activator)
		local curAmount = self:GetNWInt("DetoniteAmount", 0)
		if curAmount < Ores.Automation.BombCapacity then return end
		if self:GetNWBool("Detonating", false) then return end
		if IsValid(activator) and not activator:IsInZone("cave") then return end -- lets not annoy people in build

		self:SetNWBool("Detonating", true)

		local i = 0
		timer.Create(("mining_detonite_bomb_[%d]"):format(self:EntIndex()), 1, Ores.Automation.BombDetonationTime, function()
			if not IsValid(self) then return end

			i = i + 1
			self:EmitSound(")buttons/button17.wav", 100, 80 + 20 * i)

			if i >= Ores.Automation.BombDetonationTime then
				self:Detonate()

				Ores.MineCollapse(self:WorldSpaceCenter(), 60, {
					[0] = 100,
				}, activator)
			end
		end)
	end

	function ENT:Use(activator)
		if not activator:IsPlayer() then return end
		if self.CPPIGetOwner and self:CPPIGetOwner() ~= activator then return end

		local curAmount = self:GetNWInt("DetoniteAmount", 0)
		if curAmount < Ores.Automation.BombCapacity then
			local detoniteRarity = Ores.Automation.GetOreRarityByName("Detonite")
			local plyAmount = Ores.GetPlayerOre(activator, detoniteRarity)
			if plyAmount > 0 then
				local amountToAdd = math.min(Ores.Automation.BombCapacity - curAmount, plyAmount)
				Ores.TakePlayerOre(activator, detoniteRarity, amountToAdd)
				self:SetNWInt("DetoniteAmount", curAmount + amountToAdd)

				if _G.WireLib then
					_G.WireLib.TriggerOutput(self, "Amount", curAmount + amountToAdd)
				end
			end

			return
		end

		self:TriggerDetonation(activator)
	end

	function ENT:GravGunPickupAllowed(ply)
		if not self.CPPIGetOwner then return end
		return ply == self:CPPIGetOwner()
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	local COLOR_RED = Color(255, 0, 0)
	function ENT:OnDrawEntityInfo()
		local ready = self:GetNWInt("DetoniteAmount", 0) == Ores.Automation.BombCapacity
		local owned = self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer()

		local data = {
			{ Type = "Label", Text = "BOMB", Border = true },
			{ Type = "Data", Label = "CHARGES", Value = ("%d/%d"):format(self:GetNWInt("DetoniteAmount", 0), Ores.Automation.BombCapacity) },
		}

		if self:GetNWBool("Detonating", false) then
			table.insert(data, { Type = "Label", Text = "DETONATING!!!", Color = COLOR_RED })
		elseif ready then
			if owned then
				table.insert(data, { Type = "Action", Binding = "+use", Text = "DETONATE" })
			else
				table.insert(data, { Type = "Label", Text = "READY", Color = COLOR_RED })
			end
		elseif owned then
			table.insert(data, { Type = "Action", Binding = "+use", Text = "FILL" })
		end

		return data
	end
end