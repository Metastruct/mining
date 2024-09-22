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
ENT.NextCanWorkCheck = 0
ENT.Description = "The merger allows you to merge multiple ore outputs into one. It's usually used with drills."

local INPUT_AMOUNT = 6
require("ma_orchestrator")
_G.MA_Orchestrator.RegisterOutput(ENT, "ores", "ORE", "Ores", "Merged ores output.")
for i = 1, INPUT_AMOUNT do
	_G.MA_Orchestrator.RegisterInput(ENT, "ores_" .. i, "ORE", "Ores " .. i, "Standard ore input.")
end

-- TODO: make this less complex to check
local function is_output_working(self, input_data, time)
	if SERVER then
		return IsValid(input_data.Link.Ent) and isfunction(input_data.Link.Ent.CanWork) and input_data.Link.Ent:CanWork(time)
	else
		local data = _G.MA_Orchestrator.LinkData[self:EntIndex()]
		if not data then return false end

		for _, link_data in pairs(data) do
			local target_ent = Entity(link_data.EntIndex)
			if not IsValid(target_ent) then continue end

			if isfunction(target_ent.CanWork) and target_ent:CanWork(time) then
				return true
			end
		end
	end

	return false
end

function ENT:CanWork(time)
	if time < self.NextCanWorkCheck then return self.LastCanWork end

	local inputs = _G.MA_Orchestrator.GetInputs(self)
	for _, input_data in ipairs(inputs) do
		if _G.MA_Orchestrator.IsInputLinked(input_data) and is_output_working(self, input_data, time) then
			self.NextCanWorkCheck = time + 2
			self.LastCanWork = true

			return true
		end
	end

	self.NextCanWorkCheck = time + 2
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

		_G.MA_Orchestrator.EntityTimer("ma_merger_v2", self, 0.5, 0, function()
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
		if #output_data.Ent.OreQueue == 0 then return end

		-- combines queues
		local rarity = table.remove(output_data.Ent.OreQueue, 1)
		table.insert(self.OreQueue, 1, rarity)

		-- keep an internal storage of the last 50 ores
		if #self.OreQueue > 50 then
			table.remove(self.OreQueue, #self.OreQueue)
		end
	end
end