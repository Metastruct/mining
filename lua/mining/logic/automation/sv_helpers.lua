module("ms", package.seeall)
Ores = Ores or {}

resource.AddFile("materials/mining/automation/hud_frame.png")

function Ores.Automation.ReplicateOwnership(ent, parent, addToUndo)
	if ent ~= parent then
		ent:SetCreator(parent:GetCreator())
		ent:SetOwner(parent:GetOwner())

		if ent.CPPISetOwner then
			local owner = parent:CPPIGetOwner()
			if IsValid(owner) then
				ent:CPPISetOwner(owner)

				if addToUndo then
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

function Ores.Automation.PrepareForDuplication(ent)
	function ent:PostEntityPaste(_, _, createdEntities)
		for _, e in pairs(createdEntities) do
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
	local baseWireEnt = scripted_ents.Get("base_wire_entity")
	if baseWireEnt and _G.WireLib then
		-- Helper function for entities that can be linked
		ent.LINK_STATUS_UNLINKED = 1
		ent.LINK_STATUS_LINKED = 2
		ent.LINK_STATUS_INACTIVE = 2 -- alias
		ent.LINK_STATUS_DEACTIVATED = 2 -- alias
		ent.LINK_STATUS_ACTIVE = 3
		ent.LINK_STATUS_ACTIVATED = 3 -- alias
		ent.WireDebugName = ent:GetClass()

		local wireFunctions = {
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

		local baseEnt = scripted_ents.Get("base_entity")
		for _, functionName in ipairs(wireFunctions) do
			local wireFunction = baseWireEnt[functionName]
			if not type(wireFunction) then continue end

			local oldFunction = ent[functionName]
			local hasActualFunction = oldFunction and oldFunction ~= wireFunction
			if baseEnt then
				hasActualFunction = hasActualFunction and oldFunction ~= baseEnt[functionName]
			end

			if hasActualFunction then
				ent[functionName] = function(...)
					oldFunction(...)
					return wireFunction(...)
				end
			else
				ent[functionName] = wireFunction
			end
		end
	end
end


CreateConVar("sbox_maxmining_automation", "40", FCVAR_ARCHIVE, "Maximum amount of mining automation entities a player can have", 0, 100)

hook.Add("OnEntityCreated", "mining_automation", function(ent)
	local className = ent:GetClass()
	if className == "mining_drill" then return end
	if not Ores.Automation.EntityClasses[className] then return end
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

hook.Add("PlayerSpawnSENT", "mining_automation", function(ply, className)
	if not className then return end

	if Ores.Automation.EntityClasses[className] and not ply:CheckLimit("mining_automation") then
		return false
	end
end)

hook.Add("InitPostEntity", "mining_automation", function()
	if not _G.WireLib then return end

	-- required for re-duping, ps: I hate wiremod
	for className, _ in pairs(Ores.Automation.EntityClasses) do
		duplicator.RegisterEntityClass(className, function(ply, data, ...)
			local dupedEnt = ents.Create(data.Class)
			if not IsValid(dupedEnt) then return false end

			duplicator.DoGeneric(dupedEnt, data)
			dupedEnt:Spawn()
			dupedEnt:Activate()
			duplicator.DoGenericPhysics(dupedEnt, ply, data) -- Is deprecated, but is the only way to access duplicator.EntityPhysics.Load (its local)

			dupedEnt:SetPlayer(ply)
			if dupedEnt.Setup then dupedEnt:Setup(...) end

			local phys = dupedEnt:GetPhysicsObject()
			if IsValid(phys) then
				if data.frozen then phys:EnableMotion(false) end
				if data.nocollide then phys:EnableCollisions(false) end
			end

			return dupedEnt
		end, "Data")
	end
end)