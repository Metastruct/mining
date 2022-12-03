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
	GraphHeightMargin = 75,
	HudFrameMaterial = Material("mining/automation/hud_frame.png", "smooth noclamp"),
	HudPadding = 10,
	HudSepColor = Color(100, 100, 100, 255),
	HudActionColor = Color(255, 125, 0, 255),
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
	surface.CreateFont("mining_automation_hud", {
		font = "Tahoma",
		extended = true,
		weight = 1000,
		size = 30
	})

	surface.CreateFont("mining_automation_hud2", {
		font = "Tahoma",
		extended = true,
		weight = 1000,
		size = 25
	})

	function Ores.Automation.ShouldDrawText(ent)
		local localPlayer = LocalPlayer()

		if localPlayer:EyePos():DistToSqr(ent:WorldSpaceCenter()) <= Ores.Automation.TextDrawingDistance * Ores.Automation.TextDrawingDistance then return true end
		if localPlayer:GetEyeTrace().Entity == ent then return true end

		return false
	end

	local ENTITY_INFO_EXTRAS = { mining_argonite_container = true }
	local FONT_HEIGHT = 30
	local FRAME_WIDTH = 225
	local FRAME_HEIGHT = 100
	local COLOR_WHITE = Color(255, 255, 255, 255)
	local function drawEntityInfoFrame(ent, data)
		local totalHeight = ent.MiningInfoFrameHeight or (FRAME_HEIGHT + (#data * (FONT_HEIGHT + Ores.Automation.HudPadding)))
		local pos = ent:WorldSpaceCenter():ToScreen()
		local x, y = pos.x - FRAME_WIDTH / 2, pos.y - totalHeight / 2

		surface.SetMaterial(Ores.Automation.HudFrameMaterial)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(x, y, FRAME_WIDTH, totalHeight)

		local offset = Ores.Automation.HudPadding
		for _, lineData in ipairs(data) do
			if lineData.Type == "Action" then
				surface.SetFont("mining_automation_hud2")

				local key = (input.LookupBinding(lineData.Binding, true) or "?"):upper()
				local text = ("[ %s ] %s"):format(key, lineData.Text)
				local tw, th = surface.GetTextSize(text)

				surface.SetTextColor(Ores.Automation.HudActionColor)
				surface.SetTextPos(x + FRAME_WIDTH - (tw + Ores.Automation.HudPadding * 2), y + offset)
				surface.DrawText(text)

				offset =  offset + th + Ores.Automation.HudPadding
			elseif lineData.Type == "Data" then
				surface.SetFont("mining_automation_hud")

				surface.SetTextColor(lineData.LabelColor or COLOR_WHITE)
				surface.SetTextPos(x + Ores.Automation.HudPadding, y + offset)
				surface.DrawText(lineData.Label)

				if lineData.MaxValue then
					local perc = (math.Round((lineData.Value / lineData.MaxValue) * 100))
					local r = 255
					local g = 255 / 100 * perc
					local b = 255 / 100 * perc

					surface.SetTextColor(r, g, b, 255)
				elseif lineData.ValueColor then
					surface.SetTextColor(lineData.ValueColor)
				end

				local tw, th = surface.GetTextSize(perc)
				surface.SetTextPos(x + FRAME_WIDTH - (tw + Ores.Automation.HudPadding * 2), y + offset)
				surface.DrawText(lineData.Value)

				offset =  offset + th + Ores.Automation.HudPadding
			else
				if not isstring(lineData.Text) then continue end

				surface.SetFont("mining_automation_hud")

				surface.SetTextColor(lineData.Color or COLOR_WHITE)
				surface.SetTextPos(x + Ores.Automation.HudPadding, y + offset)
				surface.DrawText(lineData.Text)

				local _, th = surface.GetTextSize(lineData.Text)
				offset = offset + th + Ores.Automation.HudPadding

				if lineData.Border == true then
					surface.SetDrawColor(Ores.Automation.HudSepColor)
					surface.DrawRect(x + Ores.Automation.HudPadding, y + offset, FRAME_WIDTH - Ores.Automation.HudPadding * 2, 2)
					offset = offset + Ores.Automation.HudPadding
				end
			end
		end

		-- more accurate height
		ent.MiningInfoFrameHeight = offset + Ores.Automation.HudPadding
	end

	hook.Add("HUDPaint", "mining_automation_entity_info", function()
		for _, ent in ipairs(ents.FindByClass("mining_*")) do
			local entClass = ent:GetClass()
			if not Ores.Automation.EntityClasses[entClass] and not ENTITY_INFO_EXTRAS[entClass] then continue end
			if not Ores.Automation.ShouldDrawText(ent) then continue end
			if not isfunction(ent.OnDrawEntityInfo) then continue end

			local data = ent:OnDrawEntityInfo()
			if not istable(data) then continue end

			drawEntityInfoFrame(ent, data)
		end
	end)

	local graphEntities = {}
	local graphMinX, graphMaxX = 2e9, -2e9
	local graphMinY, graphMaxY = 2e9, -2e9
	local graphMinZ, graphMaxZ = 2e9, -2e9

	local function compare_ent_owner(ent, ply)
		return (ent.CPPIGetOwner and ent:CPPIGetOwner() == ply) or false
	end

	function Ores.Automation.BuildGraph(ply)
		ply = ply or LocalPlayer()

		graphEntities = {}
		graphMinX, graphMaxX = 2e9, -2e9
		graphMinY, graphMaxY = 2e9, -2e9
		graphMinZ, graphMaxZ = 2e9, -2e9

		local hasAutomationEntities = false
		for _, ent in ipairs(ents.FindByClass("mining_*")) do
			local entClass = ent:GetClass()

			--[[if entClass == "mining_ore" and ent:GetNWBool("SpawnedByDrill", false) and compare_ent_owner(ent, ply) then
				table.insert(graphEntities, ent)
				continue
			end]]

			if not Ores.Automation.EntityClasses[entClass] then continue end

			if compare_ent_owner(ent, ply) then
				table.insert(graphEntities, ent)

				if not Ores.Automation.EnergyEntities[entClass] then
					local pos = ent:WorldSpaceCenter()
					graphMinX, graphMinY, graphMinZ = math.min(graphMinX, pos.x), math.min(graphMinY, pos.y), math.min(graphMinZ, pos.z)
					graphMaxX, graphMaxY, graphMaxZ = math.max(graphMaxX, pos.y), math.max(graphMaxY, pos.y), math.max(graphMaxZ, pos.z)
					hasAutomationEntities = true
				end
			end
		end

		-- reset because we dont care about single batteries or burners
		if not hasAutomationEntities then
			graphEntities = {}
		end

		-- sort by Z position and add localplayer for the graph
		if #graphEntities > 0 then
			table.insert(graphEntities, ply)
			table.sort(graphEntities, function(a, b) return a:WorldSpaceCenter().z < b:WorldSpaceCenter().z end)

			graphMinZ, graphMaxZ = graphMinZ - Ores.Automation.GraphHeightMargin, graphMaxZ + Ores.Automation.GraphHeightMargin
		end
	end

	local MINING_GRAPH = CreateClientConVar("mining_automation_graph", "1", true, true, "Whether to display a graph of your current automation setup or not", 0, 1)
	local function graphHookCallback(ent)
		if not MINING_GRAPH:GetBool() then return end
		if IsValid(ent) and not Ores.Automation.EntityClasses[ent:GetClass()] then return end

		Ores.Automation.BuildGraph()
	end

	hook.Add("OnEntityCreated", "mining_rig_automation_graph_hud", graphHookCallback)
	hook.Add("NetworkEntityCreated", "mining_rig_automation_graph_hud", graphHookCallback)
	timer.Create("mining_rig_automation_graph_hud", 1, 0, graphHookCallback)

	local GRAPH_ENT_DRAW = {
		player = function(ply, x, y)
			local size = Ores.Automation.GraphUnit / 4

			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawRect(x - size / 2, y - size / 2, size, size)
		end,
		--[[mining_ore = function(ore, x, y)
			local color = Ores.__R[ore:GetRarity()].HudColor
			local size = Ores.Automation.GraphUnit / 4

			surface.SetDrawColor(color)
			surface.DrawRect(x - size / 2, y - size / 2, size, size)
		end]]
	}

	hook.Add("HUDPaint", "mining_rig_automation_graph_hud", function()
		if not MINING_GRAPH:GetBool() then return end
		if #graphEntities == 0 then return end

		local hasAutomationEntities = false
		local centerX, centerY = ScrW() / 3 * 2, ScrH() / 2 - (graphMaxY - graphMinY) / 2
		local totalGraphHeight = graphMaxZ - graphMinZ
		for i, ent in ipairs(graphEntities) do
			if not IsValid(ent) then
				table.remove(graphEntities, i)
				continue
			end

			local drawFunc = isfunction(ent.OnGraphDraw) and ent.OnGraphDraw or GRAPH_ENT_DRAW[ent:GetClass()]
			if not drawFunc then continue end

			local pos = ent:WorldSpaceCenter()
			local x, y = centerX + (pos.x - (graphMinX - 20)), centerY + (pos.y - (graphMinY - 20))
			local alpha = totalGraphHeight <= 0 and 1 or 0.25 + ((pos.z - graphMinZ) / totalGraphHeight)
			local prevAlpha = surface.GetAlphaMultiplier()

			surface.SetAlphaMultiplier(alpha)
			drawFunc(ent, x, y)
			surface.SetAlphaMultiplier(prevAlpha)

			hasAutomationEntities = true
		end

		-- reset the graph there are no more automation entities
		if not hasAutomationEntities then
			graphEntities = {}
		end
	end)
end

if SERVER then
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

	hook.Add("PlayerSpawnSENT", "mining_automation", function(ply, className)
		if not className then return end

		if Ores.Automation.EntityClasses[className] and not ply:CheckLimit("mining_automation") then
			return false
		end
	end)

--[[do
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
	end]]
end