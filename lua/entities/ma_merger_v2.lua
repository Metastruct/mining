AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Ore Merger V2"
ENT.Author = "Earu"
ENT.Category = "Mining V2"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "ma_merger_v2"

local MAX_DRILLS = 12

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_lab/powerbox01a.mdl")
		self:SetMaterial("phoenix_storms/OfficeWindow_1-1")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self.OreQueue = {}

		_G.MA_Orchestrator.RegisterOutput(self, "ores", "ORE", "Ores", "Merged ores output.")
		for i = 1, MAX_DRILLS do
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
	end

	function ENT:MA_OnOutputReady(output_data, input_data)
		if not input_data.Id:match("^ores_") then return end

		_G.MA_Orchestrator.Execute(output_data, input_data)
	end

	function ENT:MA_Execute(output_data, input_data)
		if not input_data.Id:match("^ores_") then return end

		-- combines queues
		for _, rarity in ipairs(output_data.Ent.OreQueue) do
			table.insert(self.OreQueue, 1, rarity)
		end

		-- get rid of the extra
		while #self.OreQueue > 50 * MAX_DRILLS do
			table.remove(self.OreQueue, #self.OreQueue)
		end
	end
end

if CLIENT then
	function ENT:Initialize()
		_G.MA_Orchestrator.RegisterOutput(self, "ores", "ORE", "Ores", "Merged ores output.")
		for i = 1, MAX_DRILLS do
			_G.MA_Orchestrator.RegisterInput(self, "ores_" .. i, "ORE", "Ores " .. i, "Standard ore input.")
		end
	end

	function ENT:Draw()
		self:DrawModel()
	end
end