AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

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
	local function doZapEffect(pos, ent)
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
			SafeRemoveEntity(tesla)
			table.remove(teslas, idx)
		end)
	end

	function ENT:Initialize()
		local color = Ores.__R[Ores.Automation.GetOreRarityByName("Argonite")].PhysicalColor

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

		local timerName = ("mining_argonite_transformer_[%d]"):format(self:EntIndex())
		timer.Create(timerName, 1, 0, function()
			if not IsValid(self) then
				timer.Remove(timerName)
				return
			end

			doZapEffect(self:WorldSpaceCenter(), IsValid(self.Core) and self.Core or self)

			if self.BatteriesToProduce > 0 then
				self:CreateBattery()
				self.BatteriesToProduce = math.max(0, self.BatteriesToProduce - 1)
			end
		end)

		timer.Simple(0, function()
			if not IsValid(self) then return end

			Ores.Automation.ReplicateOwnership(self, self)
		end)
	end

	function ENT:AddArgonite(amount)
		if amount < 1 then return end

		local curAmount = self:GetNWInt("ArgoniteCount", 0)
		local newAmount = curAmount + amount
		if newAmount >= Ores.Automation.BatteryCapacity then
			local batteriesToProduce = math.floor(newAmount / Ores.Automation.BatteryCapacity)
			local remaining = newAmount % Ores.Automation.BatteryCapacity

			self:SetNWInt("ArgoniteCount", remaining)
			self.BatteriesToProduce = self.BatteriesToProduce + batteriesToProduce
		else
			self:SetNWInt("ArgoniteCount", newAmount)
		end
	end

	local transformerIndex = 1
	local function check_transformer_to_use(ply, baseTransformer)
		local transformers = {}
		for _, t in ipairs(ents.FindByClass("mining_argonite_transformer")) do
			if t:CPPIGetOwner() ~= ply then continue end

			table.insert(transformers, t)
		end

		table.sort(transformers, function(a, b) return a:GetCreationTime() > b:GetCreationTime() end)

		local transformer = transformers[transformerIndex % (#transformers + 1)]
		if not transformer then
			transformerIndex = 1
			return transformers[transformerIndex] == baseTransformer
		end

		return baseTransformer == transformer
	end

	function ENT:Think()
		if not self.CPPIGetOwner then return end

		local owner = self:CPPIGetOwner()
		if not IsValid(owner) then return end

		local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
		local amount = math.min(Ores.Automation.BatteryCapacity, ms.Ores.GetPlayerOre(owner, argoniteRarity))
		if amount < 1 then return end

		if check_transformer_to_use(owner, self) then
			self:AddArgonite(amount)
			ms.Ores.TakePlayerOre(owner, argoniteRarity, amount)

			transformerIndex = transformerIndex + 1
		end
	end

	function ENT:CreateBattery()
		local battery = ents.Create("mining_argonite_battery")
		battery:SetPos(self:WorldSpaceCenter() + self:GetForward() * 50)
		battery:SetNWInt("ArgoniteCount", Ores.Automation.BatteryCapacity)
		battery:Spawn()

		timer.Simple(0, function()
			if IsValid(self) and IsValid(battery) then
				Ores.Automation.ReplicateOwnership(battery, self, true)
			end
		end)

		self:EmitSound(")npc/scanner/scanner_siren1.wav", 100)
	end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	hook.Add("HUDPaint", "mining_argonite_transformer", function()
		local color = ms.Ores.__R[Ores.Automation.GetOreRarityByName("Argonite")].PhysicalColor
		for _, transformer in ipairs(ents.FindByClass("mining_argonite_transformer")) do
			if Ores.Automation.ShouldDrawText(transformer) then
				local pos = transformer:WorldSpaceCenter():ToScreen()
				local text = ("%d%%"):format((transformer:GetNWInt("ArgoniteCount", 0) / Ores.Automation.BatteryCapacity) * 100)
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