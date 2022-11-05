AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

local CONTAINER_CAPACITY = 5000

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Argonite Container"
ENT.Author = "Earu"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.CanConstruct = function() return false end
ENT.CanTool = function() return false end
ENT.ms_notouch = true

if SERVER then
	util.PrecacheModel("models/hunter/tubes/tube1x1x4.mdl")

	function ENT:Initialize()
		self:SetModel("models/hunter/tubes/tube1x1x4.mdl")
		self:SetMaterial("phoenix_storms/glass")
		self:SetMoveType(MOVETYPE_NONE)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
			phys:EnableMotion(false)
		end

		local bottom = ents.Create("prop_physics")
		bottom:SetModel("models/props_wasteland/laundry_basket001.mdl")
		bottom:SetPos(self:GetPos() + Vector(0, 0, 15))
		bottom:SetAngles(Angle(0, -180, 0))
		bottom:SetParent(self)
		bottom:Spawn()
		bottom:SetNotSolid(true)
		bottom:SetModelScale(0.95)
		bottom:SetParent(self)
		bottom.ms_notouch = true
		bottom.CanConstruct = function() return false end
		bottom.CanTool = function() return false end

		local top = ents.Create("prop_physics")
		top:SetModel("models/props_wasteland/laundry_basket001.mdl")
		top:SetPos(self:GetPos() + Vector(0, 0, 175))
		top:SetAngles(Angle(0, -180, 180))
		top:SetParent(self)
		top:Spawn()
		top:SetNotSolid(true)
		top:SetModelScale(0.95)
		top:SetParent(self)
		top.ms_notouch = true
		top.CanConstruct = function() return false end
		top.CanTool = function() return false end
	end

	function ENT:AddArgonite(amount)
		if self:GetNWBool("ArgoniteOverload") then return end

		local curAmount = self:GetNWInt("ArgoniteCount", 0)
		local newAmount = math.min(CONTAINER_CAPACITY, curAmount + amount * 10)
		self:SetNWInt("ArgoniteCount", newAmount)

		if newAmount >= CONTAINER_CAPACITY then
			-- proper timing for the meltdown
			self:SetNWBool("ArgoniteOverload", true)
			self.LeakingSound = CreateSound(self, "ambient/gas/steam_loop1.wav")
			self.LeakingSound:Play()
			timer.Create("ArgoniteContainerEmptying", 0.01, CONTAINER_CAPACITY, function()
				if not IsValid(self) then
					timer.Remove("ArgoniteContainerEmptying")
					return
				end

				newAmount = math.max(0, newAmount - 2.15)
				self:SetNWInt("ArgoniteCount", newAmount)

				if newAmount <= 0 then
					self:SetNWBool("ArgoniteOverload", false)
					timer.Remove("ArgoniteContainerEmptying")
					self.LeakingSound:FadeOut(1)
				end
			end)

			if ms and IsValid(ms.core_effect) then
				if ms.core_effect:GetDTBool(3) then
					ms.core_effect:SetDTBool(3, false) -- "re-spawn the core"
					ms.core_effect:SetSize(20)

					if landmark and landmark.get and landmark.get("core_position") then
						ms.core_effect:SetPos(landmark.get("core_position")) -- also put it back to its original position just in case
					end
				else
					ms.core_effect:SetSize(75) -- bik

					-- otherwise trigger meltdown
					if mgn and mgn.IsOverloading and not mgn.IsOverloading() and mgn.InitiateOverload then
						mgn.InitiateOverload()
					end
				end
			end
		end
	end
end

if CLIENT then
	function ENT:Initialize()
		self.LiquidEnt = ClientsideModel("models/hunter/tubes/tube1x1x4.mdl", RENDERGROUP_OPAQUE)
		self.LiquidEnt:SetModelScale(0.95)

		self.LiquidEntTop = ClientsideModel("models/xqm/panel360.mdl", RENDERGROUP_OPAQUE)
		self.LiquidEntTop:SetModelScale(0.8)
	end

	function ENT:Draw()
		if not IsValid(self.LiquidEnt) then
			self.LiquidEnt = ClientsideModel("models/hunter/tubes/tube1x1x4.mdl", RENDERGROUP_OPAQUE)
			self.LiquidEnt:SetModelScale(0.95)
		end

		if not IsValid(self.LiquidEntTop) then
			self.LiquidEntTop = ClientsideModel("models/xqm/panel360.mdl", RENDERGROUP_OPAQUE)
			self.LiquidEntTop:SetModelScale(0.8)
		end

		local color = Ores.__R[Ores.Automation.GetOreRarityByName("Argonite")].PhysicalColor

		render.SetColorModulation(color.r / 100, color.g / 100, color.b / 100)
		render.MaterialOverride(Ores.Automation.EnergyMaterial)

		local perc = math.max(0, 1 - (self:GetNWInt("ArgoniteCount", 0) / CONTAINER_CAPACITY))

		render.Model({
			model = self:GetModel(),
			pos = self:GetPos() - Vector(0, 0, perc * 175),
			angle = self:GetAngles()
		}, self.LiquidEnt)

		render.Model({
			model = "models/xqm/panel360.mdl",
			pos = self.LiquidEnt:GetPos() + Vector(0, 0, 180),
			angle = self:GetAngles() + Angle(90, 0, 0)
		}, self.LiquidEntTop)

		render.MaterialOverride()
		render.SetColorModulation(1, 1, 1)

		self:DrawModel()

		if Ores.Automation.ShouldDrawText(self) then
			cam.IgnoreZ(true)
			cam.Start2D()
				local pos = self:WorldSpaceCenter():ToScreen()
				local text = ("%d%%"):format((self:GetNWInt("ArgoniteCount", 0) / CONTAINER_CAPACITY) * 100)
				surface.SetFont("DermaLarge")
				local tw, th = surface.GetTextSize(text)
				surface.SetTextColor(color)
				surface.SetTextPos(pos.x - tw / 2, pos.y - th / 2)
				surface.DrawText(text)

				tw, th = surface.GetTextSize("Excess Argonite Container")
				surface.SetTextPos(pos.x - tw / 2, pos.y - th * 2)
				surface.DrawText("Excess Argonite Container")

				if self:GetNWBool("ArgoniteOverload", false) then
					surface.SetTextColor(255, 0, 0, 255)
					tw, th = surface.GetTextSize("/!\\ DANGER ARGONITE LEAKAGE /!\\")
					surface.SetTextPos(pos.x - tw / 2, pos.y - th * 4)
					surface.DrawText("/!\\ DANGER ARGONITE LEAKAGE /!\\")
				end
			cam.End2D()
			cam.IgnoreZ(false)
		end
	end

	function ENT:OnRemove()
		if IsValid(self.LiquidEnt) then
			self.LiquidEnt:Remove()
		end

		if IsValid(self.LiquidEntTop) then
			self.LiquidEntTop:Remove()
		end
	end
end