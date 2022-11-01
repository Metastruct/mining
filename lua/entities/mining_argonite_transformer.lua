AddCSLuaFile()

local ARGONITE_RARITY = 18
local BATTERY_CAPACITY = 150
local TEXT_DIST = 150

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Argonite Transformer"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "mining_argonite_transformer"

if SERVER then
	local teslas = {}
	local function do_zap_effect(pos, ent)
		if #teslas > 4 then
			for k, v in pairs(teslas) do
				if not IsValid(v) then table.remove(teslas, k) continue end

				v:Remove()
				table.remove(teslas, k)
				break
			end
		end

		local tesla = ents.Create("point_tesla")
		tesla:SetPos(pos)
		tesla:SetKeyValue("texture", "trails/electric.vmt")
		tesla:SetKeyValue("m_iszSpriteName", "sprites/physbeam.vmt")
		--tesla:SetKeyValue("m_SourceEntityName", "secret_tesla")
		tesla:SetKeyValue("m_Color", "255 20 50")
		tesla:SetKeyValue("m_flRadius",  "10")
		tesla:SetKeyValue("interval_min", "0.1")
		tesla:SetKeyValue("interval_max", "0.1")
		tesla:SetKeyValue("beamcount_min", "3")
		tesla:SetKeyValue("beamcount_max", "3")
		tesla:SetKeyValue("thick_min", "5")
		tesla:SetKeyValue("thick_max", "6")
		tesla:SetKeyValue("lifetime_min", "0.2")
		tesla:SetKeyValue("lifetime_max", "0.2")
		--tesla:SetKeyValue("m_SoundName", "ambient/levels/labs/electric_explosion"..math.random(1,5)..".wav")
		--tesla:EmitSound("ambient/levels/labs/electric_explosion"..math.random(1,5)..".wav", 75, 100, 0.5)
		tesla:Spawn()
		tesla:Activate()

		--tesla:SetParent(ent)

		timer.Simple(0.3, function()
			if not IsValid(tesla) then return end

			tesla:SetKeyValue("thick_min", "5")
			tesla:SetKeyValue("thick_max", "6")
			tesla:SetKeyValue("m_flRadius",  "20")
			tesla:SetKeyValue("beamcount_min", "3")
			tesla:SetKeyValue("beamcount_max", "3")
		end)

		tesla:Fire("TurnOn", "", 0)
		tesla:Fire("DoSpark", "", 0)

		timer.Simple(0.8, function()
			if not IsValid(tesla) then return end

			tesla:SetKeyValue("thick_min", "5")
			tesla:SetKeyValue("thick_max", "6")
			tesla:SetKeyValue("beamcount_min", "3")
			tesla:SetKeyValue("beamcount_max", "3")
			tesla:SetKeyValue("m_flRadius",  "20")
		end)

		timer.Simple(1.5, function()
			if not IsValid(tesla) then return end

			tesla:SetKeyValue("thick_min", "2")
			tesla:SetKeyValue("thick_max", "3")
			tesla:SetKeyValue("beamcount_min", "3")
			tesla:SetKeyValue("beamcount_max", "3")
			tesla:SetKeyValue("m_flRadius",  "20")
		end)

		local idx = table.insert(teslas, tesla)
		timer.Simple(2, function()
			if IsValid(tesla) then
				tesla:Remove()
			end

			table.remove(teslas, idx)
		end)
	end

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
		local color = ms.Ores.__R[ARGONITE_RARITY].PhysicalColor

		self:SetModel("models/props_phx/construct/metal_tube.mdl")
		self:SetMaterial("effects/tvscreen_noise002a")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetColor(color)
		self.BatteriesToProduce = 0

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x1.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetPos(self:WorldSpaceCenter() + self:GetForward() * 24)
		self.Frame:SetAngles(self:GetAngles())
		self.Frame:Spawn()
		self.Frame:SetParent(self)

		self.Out = ents.Create("prop_physics")
		self.Out:SetModel("models/props_phx/construct/metal_wire1x1.mdl")
		self.Out:SetMaterial("phoenix_storms/stripes")
		self.Out:SetPos(self:WorldSpaceCenter() + self:GetForward() * 30)

		local ang = self:GetAngles()
		ang:RotateAroundAxis(self:GetRight(), 90)

		self.Out:SetAngles(ang)
		self.Out:Spawn()
		self.Out:SetParent(self)

		self.Core = ents.Create("prop_physics")
		self.Core:SetModel("models/hunter/misc/sphere025x025.mdl")
		self.Core:SetModelScale(0.25)
		self.Core:SetMaterial("models/debug/white")
		self.Core:SetPos(self:WorldSpaceCenter())
		self.Core:Spawn()
		self.Core:SetParent(self)
		self.Core:SetColor(Color(0, 0, 0, 255))
		self.Core:Activate()

		local timer_name = ("mining_argonite_transformer_[%d]"):format(self:EntIndex())
		timer.Create(timer_name, 1, 0, function()
			if not IsValid(self) then
				timer.Remove(timer_name)
				return
			end

			do_zap_effect(self:WorldSpaceCenter(), IsValid(self.Core) and self.Core or self)

			if self.BatteriesToProduce > 0 then
				self:CreateBattery()
				self.BatteriesToProduce = math.max(0, self.BatteriesToProduce - 1)
			end
		end)

		timer.Simple(0, function()
			if not IsValid(self) then return end

			apply_ownership(self, self)
		end)
	end

	function ENT:AddArgonite(amount)
		if amount < 1 then return end

		local cur_amount = self:GetNWInt("ArgoniteCount", 0)
		local new_amount = cur_amount + amount
		if new_amount >= BATTERY_CAPACITY then
			local batteries_to_produce = math.floor(new_amount / BATTERY_CAPACITY)
			local remaining = new_amount % BATTERY_CAPACITY

			self:SetNWInt("ArgoniteCount", remaining)
			self.BatteriesToProduce = self.BatteriesToProduce + batteries_to_produce
		else
			self:SetNWInt("ArgoniteCount", new_amount)
		end
	end

	local transformer_idx = 1
	local function check_transformer_to_use(ply, base_transformer)
		local transformers = {}
		for _, t in ipairs(ents.FindByClass("mining_argonite_transformer")) do
			if t:CPPIGetOwner() ~= ply then continue end

			table.insert(transformers, t)
		end

		table.sort(transformers, function(a, b) return a:GetCreationTime() > b:GetCreationTime() end)

		local transformer = transformers[transformer_idx % (#transformers + 1)]
		if not transformer then
			transformer_idx = 1
			return transformers[transformer_idx] == base_transformer
		end

		return base_transformer == transformer
	end

	function ENT:Think()
		if not self.CPPIGetOwner then return end

		local owner = self:CPPIGetOwner()
		if not IsValid(owner) then return end

		local amount = math.min(BATTERY_CAPACITY, ms.Ores.GetPlayerOre(owner, ARGONITE_RARITY))
		if amount > 0 and check_transformer_to_use(owner, self) then
			self:AddArgonite(amount)
			ms.Ores.TakePlayerOre(owner, ARGONITE_RARITY, amount)

			transformer_idx = transformer_idx + 1
		end
	end

	function ENT:CreateBattery()
		local battery = ents.Create("mining_argonite_battery")
		battery:SetPos(self:WorldSpaceCenter() + self:GetForward() * 50)
		battery:SetNWInt("ArgoniteCount", BATTERY_CAPACITY)
		battery:Spawn()

		timer.Simple(0, function()
			if IsValid(self) and IsValid(battery) then
				apply_ownership(battery, self)
			end
		end)

		self:EmitSound(")npc/scanner/scanner_siren1.wav", 100)
	end
end

if CLIENT then
	function ENT:ShouldDrawText()
		if LocalPlayer():EyePos():DistToSqr(self:WorldSpaceCenter()) <= TEXT_DIST * TEXT_DIST then return true end
		if LocalPlayer():GetEyeTrace().Entity == self then return true end

		return false
	end

	function ENT:Draw()
		self:DrawModel()
	end

	hook.Add("HUDPaint", "mining_argonite_transformer", function()
		local color = ms.Ores.__R[ARGONITE_RARITY].PhysicalColor
		for _, battery in ipairs(ents.FindByClass("mining_argonite_transformer")) do
			if battery:ShouldDrawText() then
				local pos = battery:WorldSpaceCenter():ToScreen()
				local text = ("%d%%"):format((battery:GetNWInt("ArgoniteCount", 0) / BATTERY_CAPACITY) * 100)
				surface.SetFont("DermaLarge")
				local tw, th = surface.GetTextSize(text)
				surface.SetTextColor(color)
				surface.SetTextPos(pos.x - tw / 2, pos.y - th / 2)
				surface.DrawText(text)

				text = "Next Battery"
				tw, th = surface.GetTextSize(text)
				surface.SetTextPos(pos.x - tw / 2, pos.y - th * 2)
				surface.DrawText(text)
			end
		end
	end)
end