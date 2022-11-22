module("ms", package.seeall)
Ores = Ores or {}

Ores.Automation = {
	BatteryCapacity = 150,
	BombCapacity = 5,
	BombDetonationTime = 4,
	TextDrawingDistance = 150,
	IgnoredClasses = {
		player = true,
		mining_ore_conveyor = true,
		mining_ore_storage = true,
		mining_drill = true,
		mining_conveyor_splitter = true,
	},
	BaseOreProductionRate = 10, -- 1 per 10 seconds
	EnergyMaterial = Material("models/props_combine/coredx70"),
	EnergyEntities = {
		mining_argonite_battery = {
			Get = function(ent) return ent:GetNWInt("ArgoniteCount", 0) end,
			Set = function(ent, value) ent:SetNWInt("ArgoniteCount", value) end,
		},
		mining_coal_burner = {
			Get = function(ent) return math.ceil(ent:GetNWInt("CoalCount", 0) / 2) end,
			Set = function(ent, value) ent:SetNWInt("CoalCount", value) end,
		}
	},
	NonStorableOres = { "Argonite", "Detonite" },
	EntityClasses = {
		mining_ore_conveyor = true,
		mining_ore_storage = true,
		mining_drill = true,
		mining_conveyor_splitter = true,
		mining_argonite_battery = true,
		mining_coal_burner = true,
		mining_argonite_transformer = true,
		mining_detonite_bomb = true,
	},
	GraphUnit = 40,
}

if Ores.Automation.EnergyMaterial:IsError() then
	Ores.Automation.EnergyMaterial = Material("effects/tvscreen_noise001a")
end

local cache = {}
function Ores.Automation.GetOreRarityByName(name)
	name = name:lower()

	if cache[name] then return cache[name] end

	for rarity, rarityData in pairs(Ores.__R) do
		if rarityData.Name:lower() == name then
			cache[name] = rarity
			return rarity
		end
	end

	return -1
end

if CLIENT then
	function Ores.Automation.ShouldDrawText(ent)
		local localPlayer = LocalPlayer()

		if localPlayer:EyePos():DistToSqr(ent:WorldSpaceCenter()) <= Ores.Automation.TextDrawingDistance * Ores.Automation.TextDrawingDistance then return true end
		if localPlayer:GetEyeTrace().Entity == ent then return true end

		return false
	end

	local ENTITY_INFO_EXTRAS = { mining_argonite_container = true }
	hook.Add("HUDPaint", "mining_automation_entity_info", function()
		for _, ent in ipairs(ents.FindByClass("mining_*")) do
			local entClass = ent:GetClass()
			if Ores.Automation.EntityClasses[entClass] or ENTITY_INFO_EXTRAS[entClass] then
				if not Ores.Automation.ShouldDrawText(ent) then continue end

				if isfunction(ent.OnDrawEntityInfo) then
					ent:OnDrawEntityInfo()
				end
			end
		end
	end)

	local graphEntities = {}
	local graphMinX, graphMaxX = 2e9, -2e9
	local graphMinY, graphMaxY = 2e9, -2e9
	local graphMinZ, graphMaxZ = 2e9, -2e9

	function Ores.Automation.BuildGraph()
		graphEntities = {}
		graphMinX, graphMaxX = 2e9, -2e9
		graphMinY, graphMaxY = 2e9, -2e9
		graphMinZ, graphMaxZ = 2e9, -2e9

		local has_automation_entities = false
		for _, ent in ipairs(ents.FindByClass("mining_*")) do
			local entClass = ent:GetClass()
			if not Ores.Automation.EntityClasses[entClass] then continue end

			if (ent.CPPIGetOwner and ent:CPPIGetOwner() == LocalPlayer()) or not ent.CPPIGetOwner then
				table.insert(graphEntities, ent)

				if not Ores.Automation.EnergyEntities[entClass] then
					local pos = ent:WorldSpaceCenter()
					graphMinX, graphMinY, graphMinZ = math.min(graphMinX, pos.x), math.min(graphMinY, pos.y), math.min(graphMinZ, pos.z)
					graphMaxX, graphMaxY, graphMaxZ = math.max(graphMaxX, pos.y), math.max(graphMaxY, pos.y), math.max(graphMaxZ, pos.z)
					has_automation_entities = true
				end
			end
		end

		-- reset because we dont care about single batteries or burners
		if not has_automation_entities then
			graphEntities = {}
		end

		-- sort by Z position and add localplayer for the graph
		if #graphEntities > 0 then
			table.insert(graphEntities, LocalPlayer())
			table.sort(graphEntities, function(a, b) return a:WorldSpaceCenter().z < b:WorldSpaceCenter().z end)
		end
	end

	Ores.Automation.BuildGraph() -- in case we re-run it

	local MINING_GRAPH = CreateClientConVar("mining_automation_graph", "1", true, true, "Whether to display a graph of your current automation setup or not", 0, 1)
	local function graphHookCallback(ent)
		if not MINING_GRAPH:GetBool() then return end
		if not Ores.Automation.EntityClasses[ent:GetClass()] then return end

		timer.Simple(1, function()
			Ores.Automation.BuildGraph()
		end)
	end

	hook.Add("OnEntityCreated", "mining_rig_automation_graph_hud", graphHookCallback)

	local GRAPH_ENT_DRAW = {
		player = function(ply, x, y)
			local GU = Ores.Automation.GraphUnit
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawRect(x - GU / 4, y - GU / 4, GU / 2, GU / 2, 3)
		end,
	}

	hook.Add("HUDPaint", "mining_rig_automation_graph_hud", function()
		if not MINING_GRAPH:GetBool() then return end
		if #graphEntities == 0 then return end

		local has_automation_entities = false
		local centerX, centerY = ScrW() / 3 * 2, ScrH() / 2 - (graphMaxY - graphMinY) / 2
		for i, ent in ipairs(graphEntities) do
			if not IsValid(ent) then
				table.remove(graphEntities, i)
				continue
			end

			local drawFunc = isfunction(ent.OnGraphDraw) and ent.OnGraphDraw or GRAPH_ENT_DRAW[ent:GetClass()]
			if not drawFunc then continue end

			local pos = ent:WorldSpaceCenter()
			local x, y = centerX + (pos.x - (graphMinX - 20)), centerY + (pos.y - (graphMinY - 20))
			local alpha = 0.25 + (pos.z - graphMinZ) / (graphMaxZ - graphMinZ)
			local prevAlpha = surface.GetAlphaMultiplier()

			surface.SetAlphaMultiplier(alpha)
			drawFunc(ent, x, y)
			surface.SetAlphaMultiplier(prevAlpha)

			has_automation_entities = true
		end

		-- reset the graph there are no more automation entities
		if not has_automation_entities then
			graphEntities = {}
		end
	end)
end

if SERVER then
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
	end

	hook.Add("PlayerUse", "mining_automation_use_fn_replication", function(ply, ent)
		local parent = ent:GetParent()
		if IsValid(parent) and Ores.Automation.EnergyEntities[ent:GetClass()] then
			parent:Use(ply, ply)
		end
	end)

	CreateConVar("sbox_maxmining_automation", "40", FCVAR_ARCHIVE, "Maximum amount of mining automation graphEntities a player can have", 0, 100)

	hook.Add("PlayerSpawnedSENT", "mining_automation", function(ply, ent)
		if Ores.Automation.EntityClasses[ent:GetClass()] then
			ply:AddCount("mining_automation", ent)
			return true
		end
	end)

	hook.Add("PlayerSpawnSENT", "mining_automation", function(ply, ent)
		if not ply:CheckLimit("mining_automation") then return false end
	end)

	do
		-- this might help with some of the lag
		local ent_GetClass, ent_GetParent = FindMetaTable("Entity").GetClass, FindMetaTable("Entity").GetParent
		local str_match = string.match
		local isValid = _G.IsValid
		local miningClassPattern = "^mining_"
		hook.Add("ShouldCollide", "mining_automation", function(ent1, ent2)
			local entClass1, entClass2 = ent_GetClass(ent1), ent_GetClass(ent2)

			if entClass1 == entClass2 and str_match(entClass1, miningClassPattern) then
				return false
			end

			local parent1 = ent_GetParent(ent1)
			if isValid(parent1) and ent_GetClass(parent1) == entClass2 and str_match(entClass2, miningClassPattern) then
				return false
			end

			local parent2 = ent_GetParent(ent2)
			if isValid(parent2) and ent_GetClass(parent2) == entClass1 and str_match(entClass1, miningClassPattern) then
				return false
			end

			local parentClass = isValid(parent1) and ent_GetClass(parent1)
			if parentClass and isValid(parent2) and parentClass == ent_GetClass(parent2) and str_match(parentClass, miningClassPattern) then
				return false
			end
		end)
	end
end