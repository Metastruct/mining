module("ms", package.seeall)
Ores = Ores or {}

function Ores.Automation.ReplicateOwnership(ent, parent, add_to_undo)
	if ent ~= parent then
		ent:SetCreator(parent:GetCreator())
		ent:SetOwner(parent:GetOwner())

		if ent.CPPISetOwner then
			local owner = parent:CPPIGetOwner()
			if IsValid(owner) then
				ent:CPPISetOwner(owner)

				if add_to_undo then
					undo.Create(ent:GetClass())
						undo.SetPlayer(owner)
						undo.AddEntity(ent)
					undo.Finish()
				end
			end
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

duplicator.RegisterEntityModifier("MA_Interfaces", function(_, ent, data)
	ent.MA_DupedLinks = data
end)

function Ores.Automation.PrepareForDuplication(ent)
	function ent:PreEntityCopy()
		local inputs = _G.MA_Orchestrator.GetInputs(self)
		if #inputs == 0 then return end

		local data = {}
		for _, input_data in ipairs(inputs) do
			if not _G.MA_Orchestrator.IsInputLinked(input_data) then continue end
			data[input_data.Id] = { OutputEntIndex = input_data.Link.Ent:EntIndex(), OutputId = input_data.Link.Id }
		end

		duplicator.StoreEntityModifier(self, "MA_Interfaces", data)
	end

	function ent:PostEntityPaste(_, _, created_entities)
		if istable(self.MA_DupedLinks) then
			for input_id, link_data in pairs(self.MA_DupedLinks) do
				local input_data = _G.MA_Orchestrator.GetInputData(self, input_id)
				if not input_data then continue end

				local output_ent = created_entities[link_data.OutputEntIndex]
				if not IsValid(output_ent) then continue end

				local output_data = _G.MA_Orchestrator.GetOutputData(output_ent, link_data.OutputId)
				if not output_data then continue end

				_G.MA_Orchestrator.Link(output_data, input_data)
			end

			self.MA_DupedLinks = nil
		end

		for _, e in pairs(created_entities) do
			if not IsValid(e) then continue end
			if not e.GetParent then continue end

			local parent = e:GetParent()
			if IsValid(parent) and parent == ent then
				SafeRemoveEntity(e)
			end
		end
	end

	for _, child in pairs(ent:GetChildren()) do
		if not IsValid(child) then continue end

		child.DoNotDuplicate = true -- flag for advdupe2 and dupe
	end

	-- this ensures duped mining equipment will be spawned back with wirelinks
	local base_wire_ent = scripted_ents.Get("base_wire_entity")
	if base_wire_ent and _G.WireLib then
		-- Helper function for entities that can be linked
		ent.LINK_STATUS_UNLINKED = 1
		ent.LINK_STATUS_LINKED = 2
		ent.LINK_STATUS_INACTIVE = 2 -- alias
		ent.LINK_STATUS_DEACTIVATED = 2 -- alias
		ent.LINK_STATUS_ACTIVE = 3
		ent.LINK_STATUS_ACTIVATED = 3 -- alias
		ent.WireDebugName = ent:GetClass()

		local wire_functions = {
			"OnRemove",
			"OnRestore",
			"BuildDupeInfo",
			"ApplyDupeInfo",
			"PreEntityCopy",
			"OnEntityCopyTableFinish",
			"OnDuplicated",
			"PostEntityPaste",
			"ColorByLinkStatus",
			"SetPlayer", -- required for re-duping
		}

		local base_ent = scripted_ents.Get("base_entity")
		for _, function_name in ipairs(wire_functions) do
			local wire_function = base_wire_ent[function_name]
			if not type(wire_function) then continue end

			local old_function = ent[function_name]
			local has_actual_function = old_function and old_function ~= wire_function
			if base_ent then
				has_actual_function = has_actual_function and old_function ~= base_ent[function_name]
			end

			if has_actual_function then
				ent[function_name] = function(...)
					old_function(...)
					return wire_function(...)
				end
			else
				ent[function_name] = wire_function
			end
		end
	end
end


CreateConVar("sbox_maxmining_automation", "40", FCVAR_ARCHIVE, "Maximum amount of mining automation entities a player can have", 0, 100)

hook.Add("OnEntityCreated", "mining_automation", function(ent)
	local class_name = ent:GetClass()
	if class_name == "ma_drill_v2" then return end
	if not Ores.Automation.EntityClasses[class_name] then return end
	if not ent.CPPIGetOwner then return end

	timer.Simple(1, function()
		if not IsValid(ent) then return end

		local ply = ent:CPPIGetOwner()
		if not IsValid(ply) then
			SafeRemoveEntity(ent)
			return
		end

		if ply:CheckLimit("mining_automation") then
			ply:AddCount("mining_automation", ent)
		else
			SafeRemoveEntity(ent)
		end
	end)
end)

hook.Add("PlayerSpawnSENT", "mining_automation", function(ply, class_name)
	if not class_name then return end

	if Ores.Automation.EntityClasses[class_name] and not ply:CheckLimit("mining_automation") then
		return false
	end
end)

hook.Add("InitPostEntity", "mining_automation", function()
	if not _G.WireLib then return end

	-- required for re-duping, ps: I hate wiremod
	for class_name, _ in pairs(Ores.Automation.EntityClasses) do
		duplicator.RegisterEntityClass(class_name, function(ply, data, ...)
			local duped_ent = ents.Create(data.Class)
			if not IsValid(duped_ent) then return false end

			duplicator.DoGeneric(duped_ent, data)
			duped_ent:Spawn()
			duped_ent:Activate()
			duplicator.DoGenericPhysics(duped_ent, ply, data) -- Is deprecated, but is the only way to access duplicator.EntityPhysics.Load (its local)

			duped_ent:SetPlayer(ply)
			if duped_ent.Setup then duped_ent:Setup(...) end

			local phys = duped_ent:GetPhysicsObject()
			if IsValid(phys) then
				if data.frozen then phys:EnableMotion(false) end
				if data.nocollide then phys:EnableCollisions(false) end
			end

			return duped_ent
		end, "Data")
	end
end)