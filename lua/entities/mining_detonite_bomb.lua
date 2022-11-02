AddCSLuaFile()

local TEXT_DIST = 150
local DETONITE_RARITY = 19
local BOMB_CAPACITY = 5
local TIME_TO_DETONATION = 4

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
		local cur_amount = self:GetNWInt("DetoniteAmount", 0)
		if cur_amount >= BOMB_CAPACITY then return end

		if ent:GetClass() == "mining_ore" and ent:GetRarity() == DETONITE_RARITY then
			if ent.MiningBombRemoved then return end

			ent:Remove()
			ent.MiningBombRemoved = true
			self:SetNWInt("DetoniteAmount", math.min(BOMB_CAPACITY, cur_amount + 1))
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

		local cur_amount = self:GetNWInt("DetoniteAmount", 0)
		if cur_amount < BOMB_CAPACITY then
			local ply_amount = ms.Ores.GetPlayerOre(activator, DETONITE_RARITY)
			if ply_amount > 0 then
				local amount_to_add = math.min(BOMB_CAPACITY - cur_amount, ply_amount)
				ms.Ores.TakePlayerOre(activator, DETONITE_RARITY, amount_to_add)
				self:SetNWInt("DetoniteAmount", cur_amount + amount_to_add)
			end

			return
		end

		self:SetNWBool("Detonating", true)

		local i = 0
		timer.Create(("mining_detonite_bomb_[%d]"):format(self:EntIndex()), 1, TIME_TO_DETONATION, function()
			if not IsValid(self) then return end

			i = i + 1
			self:EmitSound(")buttons/button17.wav", 100, 80 + 20 * i)

			if i >= TIME_TO_DETONATION then
				self:Detonate()

				ms.Ores.MineCollapse(self:WorldSpaceCenter(), 60, {
					[0] = 100,
				})
			end
		end)
	end
end

if CLIENT then
	local MAT = Material("models/props_combine/coredx70")
	if MAT:IsError() then
		MAT = Material("models/props_lab/cornerunit_cloud") -- fallback for people who dont have ep1
	end

	function ENT:ShouldDrawText()
		if LocalPlayer():EyePos():DistToSqr(self:WorldSpaceCenter()) <= TEXT_DIST * TEXT_DIST then return true end
		if LocalPlayer():GetEyeTrace().Entity == self then return true end

		return false
	end

	function ENT:Draw()
		self:DrawModel()
	end

	hook.Add("HUDPaint", "mining_detonite_bomb", function()
		for _, bomb in ipairs(ents.FindByClass("mining_detonite_bomb")) do
			if not bomb:ShouldDrawText() then continue end

			local pos = bomb:WorldSpaceCenter():ToScreen()
			local ready = bomb:GetNWInt("DetoniteAmount", 0) == BOMB_CAPACITY
			local color = ms.Ores.__R[DETONITE_RARITY].HudColor
			local key = (input.LookupBinding("+use", true) or "?"):upper()

			surface.SetFont("DermaLarge")
			surface.SetTextColor(color)

			local text = "Detonite Bomb"
			local tw, th = surface.GetTextSize(text)

			surface.SetTextPos(pos.x - tw / 2, pos.y - th / 2)
			surface.DrawText(text)

			if not ready then
				text = ("%d out of %d detonite ore(s)"):format(bomb:GetNWInt("DetoniteAmount", 0), BOMB_CAPACITY)
				tw, th = surface.GetTextSize(text)

				surface.SetTextPos(pos.x - tw / 2, pos.y + th / 2)
				surface.DrawText(text)

				text = ("[ %s ] Fill"):format(key)
				tw, th = surface.GetTextSize(text)

				surface.SetTextPos(pos.x - tw / 2, pos.y + th * 2)
				surface.DrawText(text)
			elseif bomb:GetNWBool("Detonating", false) then
				text = "DETONATING!!!"
				tw, th = surface.GetTextSize(text)

				surface.SetTextPos(pos.x - tw / 2, pos.y + th / 2)
				surface.DrawText(text)
			else
				text = bomb.CPPIGetOwner and bomb:CPPIGetOwner() == LocalPlayer() and ("[ %s ] Explode"):format(key) or "Ready to explode"
				tw, th = surface.GetTextSize(text)

				surface.SetTextPos(pos.x - tw / 2, pos.y + th / 2)
				surface.DrawText(text)
			end
		end
	end)
end