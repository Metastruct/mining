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
	end

	function ENT:Touch(ent)
		local curAmount = self:GetNWInt("DetoniteAmount", 0)
		if curAmount >= Ores.Automation.BombCapacity then return end

		if ent:GetClass() == "mining_ore" and ent:GetRarity() == Ores.Automation.GetOreRarityByName("Detonite") then
			if ent.MiningBombRemoved then return end

			ent:Remove()
			ent.MiningBombRemoved = true
			self:SetNWInt("DetoniteAmount", math.min(Ores.Automation.BombCapacity, curAmount + 1))
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

	function ENT:Use(activator)
		if not activator:IsPlayer() then return end
		if self.CPPIGetOwner and self:CPPIGetOwner() ~= activator then return end
		if not activator:IsInZone("cave") then return end -- lets not annoy people in build

		local curAmount = self:GetNWInt("DetoniteAmount", 0)
		if curAmount < Ores.Automation.BombCapacity then
			local detoniteRarity = Ores.Automation.GetOreRarityByName("Detonite")
			local plyAmount = Ores.GetPlayerOre(activator, detoniteRarity)
			if plyAmount > 0 then
				local amountToAdd = math.min(Ores.Automation.BombCapacity - curAmount, plyAmount)
				Ores.TakePlayerOre(activator, detoniteRarity, amountToAdd)
				self:SetNWInt("DetoniteAmount", curAmount + amountToAdd)
			end

			return
		end

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

	function ENT:GravGunPickupAllowed(ply)
		if not self.CPPIGetOwner then return end
		return ply == self:CPPIGetOwner()
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnDrawEntityInfo()
		local color = Ores.__R[Ores.Automation.GetOreRarityByName("Detonite")].HudColor
		local key = (input.LookupBinding("+use", true) or "?"):upper()
		local pos = self:WorldSpaceCenter():ToScreen()
		local ready = self:GetNWInt("DetoniteAmount", 0) == Ores.Automation.BombCapacity

		surface.SetFont("DermaLarge")
		surface.SetTextColor(color)

		local text = "Detonite Bomb"
		local tw, th = surface.GetTextSize(text)

		surface.SetTextPos(pos.x - tw / 2, pos.y - th / 2)
		surface.DrawText(text)

		if not ready then
			text = ("%d out of %d detonite ore(s)"):format(self:GetNWInt("DetoniteAmount", 0), Ores.Automation.BombCapacity)
			tw, th = surface.GetTextSize(text)

			surface.SetTextPos(pos.x - tw / 2, pos.y + th / 2)
			surface.DrawText(text)

			text = ("[ %s ] Fill"):format(key)
			tw, th = surface.GetTextSize(text)

			surface.SetTextPos(pos.x - tw / 2, pos.y + th * 2)
			surface.DrawText(text)
		elseif self:GetNWBool("Detonating", false) then
			text = "DETONATING!!!"
			tw, th = surface.GetTextSize(text)

			surface.SetTextPos(pos.x - tw / 2, pos.y + th / 2)
			surface.DrawText(text)
		else
			text = self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() and ("[ %s ] Explode"):format(key) or "Ready to explode"
			tw, th = surface.GetTextSize(text)

			surface.SetTextPos(pos.x - tw / 2, pos.y + th / 2)
			surface.DrawText(text)
		end
	end
end