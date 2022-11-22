AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ore Storage"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_ore_storage"

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_wasteland/kitchen_fridge001a.mdl")
		self:SetMaterial("phoenix_storms/OfficeWindow_1-1")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self:SetTrigger(true)
		--self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
		--self:PhysWake()

		self.BadOreRarities = {}
		self.Ores = {}

		for _, oreName in pairs(Ores.Automation.NonStorableOres) do
			local rarity = Ores.Automation.GetOreRarityByName(oreName)
			if rarity == -1 then continue end

			self.BadOreRarities[rarity] = true
		end
	end

	function ENT:UpdateNetworkOreData()
		local t = {}
		for rarity, amount in pairs(self.Ores) do
			table.insert(t, ("%s=%s"):format(rarity, amount))
		end

		self:SetNWString("OreData", table.concat(t, ";"))
	end

	function ENT:Touch(ent)
		if ent.MiningContainerCollected then return end
		if ent:GetClass() ~= "mining_ore" then return end
		if self.CPPIGetOwner and ent.GraceOwner ~= self:CPPIGetOwner() then return end -- lets not have people highjack each others

		local rarity = ent:GetRarity()
		if not self.BadOreRarities[rarity] then
			self.Ores[rarity] = (self.Ores[rarity] or 0) + 1
			self:UpdateNetworkOreData()
		end

		ent.MiningContainerCollected = true
		SafeRemoveEntity(ent)
	end

	function ENT:Use(activator)
		if not activator:IsPlayer() then return end
		if self.CPPIGetOwner and self:CPPIGetOwner() ~= activator then return end

		for rarity, amount in pairs(self.Ores) do
			if amount > 0 then
				Ores.GivePlayerOre(activator, rarity, amount)
			end

			self.Ores[rarity] = nil
		end

		self:UpdateNetworkOreData()
		self:EmitSound(")physics/surfaces/underwater_impact_bullet3.wav", 75, 70)
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnGraphDraw(x, y)
		local GU = Ores.Automation.GraphUnit

		surface.SetDrawColor(125, 125, 125, 255)
		surface.DrawRect(x - GU / 2, y - GU / 2, GU, GU)

		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawOutlinedRect(x - GU / 2, y - GU / 2, GU, GU, 2)

		local th = draw.GetFontHeight("DermaDefault")
		local globalOreData = self:GetNWString("OreData", ""):Trim()
		if #globalOreData < 1 then continue end

		local data = globalOreData:Split(";")
		for i, dataChunk in ipairs(data) do
			local rarityData = dataChunk:Split("=")
			local oreData = Ores.__R[tonumber(rarityData[1])]
			local text = ("x%s"):format(rarityData[2])

			surface.SetTextColor(oreData.HudColor)
			surface.SetTextPos(x + GU + 5, y + ((i - 1) * th))
			surface.DrawText(text)
		end
	end

	local COLOR_WHITE = Color(255, 255, 255)
	function ENT:OnDrawEntityInfo()
		local key = (input.LookupBinding("+use", true) or "?"):upper()
		local pos = self:WorldSpaceCenter():ToScreen()

		surface.SetFont("DermaLarge")

		local th = draw.GetFontHeight("DermaLarge")
		local globalOreData = self:GetNWString("OreData", ""):Trim()
		if #globalOreData < 1 then continue end

		local data = globalOreData:Split(";")
		for i, dataChunk in ipairs(data) do
			local rarityData = dataChunk:Split("=")
			local oreData = Ores.__R[tonumber(rarityData[1])]
			local text = ("x%s %s"):format(rarityData[2], oreData.Name)

			surface.SetTextColor(oreData.HudColor)
			surface.SetTextPos(pos.x, pos.y + ((i - 1) * th))
			surface.DrawText(text)

			if i >= #data and self.CPPIGetOwner and self:CPPIGetOwner() == LocalPlayer() then
				surface.SetTextColor(COLOR_WHITE)
				surface.SetTextPos(pos.x, pos.y + (i * th))
				surface.DrawText(("[ %s ] Claim ore(s)"):format(key))
			end
		end
	end
end