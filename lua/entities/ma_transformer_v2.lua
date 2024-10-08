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
ENT.ClassName = "ma_transformer_v2"
ENT.IconOverride = "entities/ma_transformer_v2.png"
ENT.BatteryIndex = 0
ENT.Description = "The argonite transformer is used to turn the argonite you collect into batteries. Batteries are typically used in tandem with a generator."

require("ma_orchestrator")
_G.MA_Orchestrator.RegisterOutput(ENT, "battery", "BATTERY", "Battery", "Outputs batteries created with the argonite stored by the transformer.")

function ENT:CanWork()
	return self:GetNWBool("Wiremod_Active", true)
end

if SERVER then
	resource.AddFile("materials/entities/ma_transformer_v2.png")

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
		self:SetNWBool("Wiremod_Active", true)

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

		local timer_name = ("ma_transformer_v2_[%d]"):format(self:EntIndex())
		timer.Create(timer_name, 1, 0, function()
			if not IsValid(self) then
				timer.Remove(timer_name)
				return
			end

			if self:GetNWBool("Wiremod_Active", true) then
				do_zap_effect(self:WorldSpaceCenter(), IsValid(self.Core) and self.Core or self)
			end

			if self.BatteriesToProduce > 0 then
				self:CreateBattery()
				self.BatteriesToProduce = math.max(0, self.BatteriesToProduce - 1)
			end
		end)

		Ores.Automation.PrepareForDuplication(self)
		timer.Simple(0, function()
			if not IsValid(self) then return end

			Ores.Automation.ReplicateOwnership(self, self)
		end)

		if _G.WireLib then
			_G.WireLib.CreateInputs(self, {"Active (If this is non-zero, activate the transformer)"})

			_G.WireLib.CreateOutputs(self, {
				"Amount (Outputs the current amount of argonite filled in) [NORMAL]",
				"MaxCapacity (Outputs the maximum argonite capacity) [NORMAL]"
			})

			_G.WireLib.TriggerOutput(self, "Amount", 0)
			_G.WireLib.TriggerOutput(self, "MaxCapacity", Ores.Automation.BatteryCapacity)
		end
	end

	function ENT:AddArgonite(amount)
		if amount < 1 then return end

		local cur_amount = self:GetNWInt("ArgoniteCount", 0)
		local new_amount = cur_amount + amount
		if new_amount >= Ores.Automation.BatteryCapacity then
			local batteries_to_produce = math.floor(new_amount / Ores.Automation.BatteryCapacity)
			local remaining = new_amount % Ores.Automation.BatteryCapacity

			self:SetNWInt("ArgoniteCount", remaining)
			self.BatteriesToProduce = self.BatteriesToProduce + batteries_to_produce

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Amount", remaining)
			end
		else
			self:SetNWInt("ArgoniteCount", new_amount)

			if _G.WireLib then
				_G.WireLib.TriggerOutput(self, "Amount", new_amount)
			end
		end
	end

	function ENT:Think()
	end

	function ENT:CreateBattery()
		self.BatteryIndex = self.BatteryIndex + 1

		-- if we got the minter deal, make one battery out of two fail
		local owner = self.CPPIGetOwner and self:CPPIGetOwner()
		if IsValid(owner) and owner:GetNWString("MA_BloodDeal", "") == "MINTER_DEAL" and self.BatteryIndex % 2 == 0 then
			self:EmitSound(")buttons/button11.wav", 100)
			return
		end

		local output_data = _G.MA_Orchestrator.GetOutputData(self, "battery")
		_G.MA_Orchestrator.SendOutputReadySignal(output_data)

		self:EmitSound(")npc/scanner/scanner_siren1.wav", 100)
	end

	function ENT:TriggerInput(port, state)
		if port == "Active" then
			self:SetNWBool("Wiremod_Active", tobool(state))
		end
	end

	local transformer_index = 1
	local function get_transformer_to_use(ply)
		local transformers = {}
		for _, t in ipairs(ents.FindByClass("ma_transformer_v2")) do
			if t:CPPIGetOwner() ~= ply then continue end
			if not t:CanWork() then continue end

			table.insert(transformers, t)
		end

		table.sort(transformers, function(a, b) return a:GetCreationTime() > b:GetCreationTime() end)

		local transformer = transformers[transformer_index % (#transformers + 1)]
		if not transformer then
			transformer_index = 1
			return transformers[transformer_index]
		end

		return transformer
	end

	hook.Add("PlayerReceivedOre", "ma_transformer_v2", function(ply, amount, rarity)
		if Ores.GetOreRarityByName("Argonite") ~= rarity then return end

		amount = math.min(Ores.Automation.BatteryCapacity, amount)
		if amount < 1 then return end

		local transformer = get_transformer_to_use(ply)
		if not IsValid(transformer) then return end

		transformer_index = transformer_index + 1

		transformer:AddArgonite(amount)

		return false
	end)
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	function ENT:OnDrawEntityInfo()
		if not self.MiningFrameInfo then
			self.MiningFrameInfo = {
				{ Type = "Label", Text = self.PrintName:upper(), Border = true },
				{ Type = "Data", Label = "Battery", Value = self:GetNWInt("ArgoniteCount", 0), MaxValue = ms.Ores.Automation.BatteryCapacity },
				{ Type = "State", Value = self:GetNWBool("Wiremod_Active", true) }
			}
		end

		self.MiningFrameInfo[2].Value = self:GetNWInt("ArgoniteCount", 0)
		self.MiningFrameInfo[3].Value = self:GetNWBool("Wiremod_Active", true)
		return self.MiningFrameInfo
	end
end