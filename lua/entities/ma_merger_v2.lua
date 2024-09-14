AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ore Merger"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "ma_merger_v2"
ENT.IconOverride = "entities/ma_merger_v2.png"

local INPUT_AMOUNT = 6

function ENT:CanWork(time)
	if time < self.NextCanWorkCheck then return self.LastCanWork end

	local inputs = _G.MA_Orchestrator.GetInputs(self)
	for _, input_data in ipairs(inputs) do
		if _G.MA_Orchestrator.IsInputLinked(input_data) then
			self.NextCanWorkCheck = time + 1
			self.LastCanWork = true

			return true
		end
	end

	self.NextCanWorkCheck = time + 1
	self.LastCanWork = false

	return false
end

if SERVER then
	resource.AddFile("materials/entities/ma_merger_v2.png")

	function ENT:Initialize()
		self:SetModel("models/props_lab/powerbox01a.mdl")
		self:SetMaterial("phoenix_storms/OfficeWindow_1-1")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self.OreQueue = {}

		_G.MA_Orchestrator.RegisterOutput(self, "ores", "ORE", "Ores", "Merged ores output.")
		for i = 1, INPUT_AMOUNT do
			_G.MA_Orchestrator.RegisterInput(self, "ores_" .. i, "ORE", "Ores " .. i, "Standard ore input.")
		end

		local timer_name = ("ma_merger_v2_[%d]"):format(self:EntIndex())
		timer.Create(timer_name, 1, 0, function()
			if not IsValid(self) then
				timer.Remove(timer_name)
				return
			end

			if #self.OreQueue > 1 then
				local output_data = _G.MA_Orchestrator.GetOutputData(self, "ores")
				_G.MA_Orchestrator.SendOutputReadySignal(output_data)
			end
		end)

		Ores.Automation.PrepareForDuplication(self)
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if not input_data.Id:match("^ores_") then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if not input_data.Id:match("^ores_") then return end
		if not istable(output_data.Ent.OreQueue) then return end

		-- combines queues
		local rarity = table.remove(output_data.Ent.OreQueue, 1)
		table.insert(self.OreQueue, 1, rarity)

		-- keep an internal storage of the last 50 ores
		if #self.OreQueue > 50 then
			table.remove(self.OreQueue, #self.OreQueue)
		end
	end
end

if CLIENT then
	function ENT:Initialize()
		_G.MA_Orchestrator.RegisterOutput(self, "ores", "ORE", "Ores", "Merged ores output.")
		for i = 1, INPUT_AMOUNT do
			_G.MA_Orchestrator.RegisterInput(self, "ores_" .. i, "ORE", "Ores " .. i, "Standard ore input.")
		end
	end

	function ENT:Draw()
		self:DrawModel()
	end
end