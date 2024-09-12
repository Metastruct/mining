AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Argonite Transformer V2"
ENT.Author = "Earu"
ENT.Category = "Mining V2"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "ma_transformer_v2"

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
		local color = Ores.__R[Ores.GetOreRarityByName("Argonite")].PhysicalColor

		self:SetModel("models/props_phx/construct/metal_tube.mdl")
		self:SetMaterial("effects/tvscreen_noise002a")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetColor(color)
		self.BatteriesToProduce = 0
		self:SetNWBool("IsPowered", true)

		self.Frame = ents.Create("prop_physics")
		self.Frame:SetModel("models/props_phx/construct/metal_wire1x1x1.mdl")
		self.Frame:SetMaterial("phoenix_storms/future_vents")
		self.Frame:SetPos(self:WorldSpaceCenter() + self:GetForward() * 24)
		self.Frame:SetAngles(self:GetAngles())
		self.Frame:Spawn()
		self.Frame.PhysgunDisabled = true
		self.Frame:SetParent(self)

		self.Core = ents.Create("prop_physics")
		self.Core:SetModel("models/hunter/misc/sphere025x025.mdl")
		self.Core:SetModelScale(0.25)
		self.Core:SetMaterial("models/debug/white")
		self.Core:SetPos(self:WorldSpaceCenter())
		self.Core:Spawn()
		self.Core.PhysgunDisabled = true
		self.Core:SetParent(self)
		self.Core:SetColor(Color(0, 0, 0, 255))
		self.Core:Activate()

		local timerName = ("ma_transformer_v2_[%d]"):format(self:EntIndex())
		timer.Create(timerName, 1, 0, function()
			if not IsValid(self) then
				timer.Remove(timerName)
				return
			end

			if self:GetNWBool("IsPowered", true) then
				doZapEffect(self:WorldSpaceCenter(), IsValid(self.Core) and self.Core or self)
			end

			if self.BatteriesToProduce > 0 then
				self:CreateBattery()
				self.BatteriesToProduce = math.max(0, self.BatteriesToProduce - 1)
			end
		end)

		_G.MA_Orchestrator.RegisterOutput(self, "battery", "BATTERY", "Battery", "Outputs batteries created with the argonite stored by the transformer.")
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

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Amount", remaining)
			end
		else
			self:SetNWInt("ArgoniteCount", newAmount)

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Amount", newAmount)
			end
		end
	end

	local transformerIndex = 1
	local function check_transformer_to_use(ply, baseTransformer)
		local transformers = {}
		for _, t in ipairs(ents.FindByClass("ma_transformer_v2")) do
			if t:CPPIGetOwner() ~= ply then continue end
			if not t:GetNWBool("IsPowered", true) then continue end

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
		if not self:GetNWBool("IsPowered", true) then return end

		local owner = self:CPPIGetOwner()
		if not IsValid(owner) then return end

		local argoniteRarity = Ores.GetOreRarityByName("Argonite")
		local amount = math.min(Ores.Automation.BatteryCapacity, ms.Ores.GetPlayerOre(owner, argoniteRarity))
		if amount < 1 then return end

		if check_transformer_to_use(owner, self) then
			self:AddArgonite(amount)
			ms.Ores.TakePlayerOre(owner, argoniteRarity, amount)

			transformerIndex = transformerIndex + 1
		end
	end

	function ENT:CreateBattery()
		local output_data = _G.MA_Orchestrator.GetOutputData(self, "battery")
		_G.MA_Orchestrator.SendOutputReadySignal(output_data)
		PrintTable(output_data)

		self:EmitSound(")npc/scanner/scanner_siren1.wav", 100)
	end
end

if CLIENT then
	function ENT:Initialize()
		_G.MA_Orchestrator.RegisterOutput(self, "battery", "BATTERY", "Battery", "Outputs batteries created with the argonite stored by the transformer.")
	end

	function ENT:Draw()
		self:DrawModel()
	end
end