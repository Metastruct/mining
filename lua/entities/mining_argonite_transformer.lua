--[[
	UNFINISHED, DIDNT FEEL RIGHT, AUTOMATING BATTERIES RUINS PLAYER INVOLVMENT, AND ALLOWS INFINITE AFK
	KEEPING IT AS ADMIN ONLY FOR FUN ETC
]]


AddCSLuaFile()

local CONTAINER_CAPACITY = 150
local TEXT_DIST = 150
local ARGONITE_RARITY = 18
local ARGONITE_EXTRACTION_RATE = 5 -- 1 every 5s

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Argonite Transformer"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.ClassName = "mining_argonite_transformer"

if SERVER then
	local function apply_ownership(ent, parent)
		if ent ~= parent then
			ent:SetCreator(parent:GetCreator())
			ent:SetOwner(parent:GetOwner())

			if ent.CPPISetOwner then
				ent:CPPISetOwner(parent:CPPIGetOwner())
			end
		end

		for _, child in pairs(ent:GetChildren()) do
			child:SetOwner(parent:GetOwner())
			child:SetCreator(parent:GetCreator())

			if child.CPPISetOwner then
				child:CPPISetOwner(parent:CPPIGetOwner())
			end
		end
	end

	function ENT:Initialize()
		self:SetModel("models/props_wasteland/kitchen_stove002a.mdl")
		self:SetMaterial("Models/Weapons/W_stunbaton/stunbaton")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetUseType(SIMPLE_USE)
		self.NextArgoniteExtraction = 0

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x2.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetPos(self:GetPos() + self:GetForward() * 24 + self:GetUp() * 24)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetRight(), 90)

		self.Frame:SetAngles(ang)
		self.Frame:Spawn()
		self.Frame:SetParent(self)

		self.Saw = ents.Create("prop_physics")
		self.Saw:SetModel("models/props_junk/sawblade001a.mdl")
		self.Saw:SetModelScale(3)
		self.Saw:SetPos(self:WorldSpaceCenter() + self:GetUp() * 25)
		self.Saw:Spawn()
		self.Saw:SetParent(self)
		self.Saw:SetKeyValue("classname", "mining_drill_saw")

		timer.Simple(0, function()
			if not IsValid(self) then return end
			apply_ownership(self, self)
		end)
	end

	function ENT:RotateSaw()
		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetForward(), 90)

		if self:CanWork() then
			ang:RotateAroundAxis(self:GetRight(), CurTime() * 400 % 360)
		end

		for _, saw in pairs(self:GetChildren()) do
			if saw:GetModel() == "models/props_junk/sawblade001a.mdl" then
				saw:SetAngles(ang)
			end
		end
	end

	function ENT:CanWork()
		local tr = util.TraceLine({
			start = self:WorldSpaceCenter(),
			endpos = self:WorldSpaceCenter() + self:GetUp() * 75,
			mask = MASK_SOLID_BRUSHONLY,
		})

		if not tr.Hit then return false end

		return true
	end

	function ENT:CheckSoundLoop()
		if not self:CanWork() then
			if self.SndLoop then
				self.SndLoop:Stop()
			end

			return
		end

		if not self.SndLoop then
			self.SndLoop = CreateSound(self, "ambient/spacebase/spacebase_drill.wav")
			self.SndLoop:PlayEx(0.75, 100)
		elseif self.SndLoop and not self.SndLoop:IsPlaying() then
			self.SndLoop:Stop()
			self.SndLoop:PlayEx(0.75, 100)
		end
	end

	function ENT:ExtractArgonite()
		if CurTime() < self.NextArgoniteExtraction then return end
		if not self:CanWork() then return end

		local new_count = self:GetNWInt("ArgoniteCount", 0) + 1
		if new_count >= CONTAINER_CAPACITY then
			local target_pos = self:WorldSpaceCenter() + self:GetUp() * -75
			if util.IsInWorld(target_pos) then
				local battery = ents.Create("mining_argonite_battery")
				battery:SetPos(target_pos)
				battery:Spawn()
				battery:SetNWInt("ArgoniteCount", CONTAINER_CAPACITY)

				timer.Simple(0, function()
					if not IsValid(battery) then return end
					if not IsValid(self) then return end

					apply_ownership(battery, self)
				end)

				SafeRemoveEntityDelayed(battery, 2 * 60)
			end

			self:SetNWInt("ArgoniteCount", 0)
			return
		end

		self:SetNWInt("ArgoniteCount", new_count)
		self.NextArgoniteExtraction = CurTime() + ARGONITE_EXTRACTION_RATE
	end

	function ENT:Think()
		self:CheckSoundLoop()
		self:RotateSaw()
		self:ExtractArgonite()

		self:NextThink(CurTime())
		return true
	end

	function ENT:OnRemove()
		if self.SndLoop then
			self.SndLoop:Stop()
		end
	end
end

if CLIENT then
	local MAT = Material("models/props_combine/coredx70")
	if MAT:IsError() then
		MAT = Material("models/props_lab/cornerunit_cloud") -- fallback for people who dont have ep1
	end

	hook.Add("OnEntityCreated", "mining_transformer_drill_saw_mat", function(ent)
		if ent:GetModel() ~= "models/props_junk/sawblade001a.mdl" then return end
		if isfunction(ent.RenderOverride) then return end

		local parent = ent:GetParent()
		if IsValid(parent) and parent:GetClass() == "mining_argonite_transformer" then
			ent.RenderOverride = function(self)
				local color = ms.Ores.__R[ARGONITE_RARITY].PhysicalColor
				render.SetColorModulation(color.r / 100, color.g / 100, color.b / 100)
				render.MaterialOverride(MAT)
				self:DrawModel()
				render.MaterialOverride()
				render.SetColorModulation(1, 1, 1)
			end
		end
	end)

	function ENT:ShouldDrawText()
		if LocalPlayer():EyePos():DistToSqr(self:WorldSpaceCenter()) <= TEXT_DIST * TEXT_DIST then return true end
		if LocalPlayer():GetEyeTrace().Entity == self then return true end

		return false
	end

	function ENT:Draw()
		self:DrawModel()
	end

	hook.Add("HUDPaint", "mining_argonite_transformer", function()
		for _, transformer in ipairs(ents.FindByClass("mining_argonite_transformer")) do
			if not transformer:ShouldDrawText() then continue end

			surface.SetFont("DermaLarge")

			local pos = transformer:WorldSpaceCenter():ToScreen()
			local text = ("Creating Battery: %d%%"):format((transformer:GetNWInt("ArgoniteCount", 0) / CONTAINER_CAPACITY) * 100)
			local color = ms.Ores.__R[ARGONITE_RARITY].HudColor
			local tw, th = surface.GetTextSize(text)

			surface.SetTextColor(color)
			surface.SetTextPos(pos.x - tw / 2, pos.y - th / 2)
			surface.DrawText(text)
		end
	end)
end