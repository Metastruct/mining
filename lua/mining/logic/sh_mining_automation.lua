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
	}
}

if Ores.Automation.EnergyMaterial:IsError() then
	Ores.Automation.EnergyMaterial = Material("models/props_lab/cornerunit_cloud")
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

	local POWER_ENTITIES = { mining_argonite_battery = true, mining_coal_burner = true }
	local GRAPH_UNIT = 40

	local entities = {}
	local minX, maxX = 2e9, -2e9
	local minY, maxY = 2e9, -2e9
	local minZ, maxZ = 2e9, -2e9

	function Ores.Automation.BuildGraph()
		entities = {}
		minX, maxX = 2e9, -2e9
		minY, maxY = 2e9, -2e9
		minZ, maxZ = 2e9, -2e9

		local has_automation_entity = false
		for _, ent in ipairs(ents.FindByClass("mining_*")) do
			local entClass = ent:GetClass()
			if not Ores.Automation.EntityClasses[entClass] then continue end

			if (ent.CPPIGetOwner and ent:CPPIGetOwner() == LocalPlayer()) or not ent.CPPIGetOwner then
				table.insert(entities, ent)

				if not POWER_ENTITIES[entClass] then
					local pos = ent:WorldSpaceCenter()
					minX, minY, minZ = math.min(minX, pos.x), math.min(minY, pos.y), math.min(minZ, pos.z)
					maxX, maxY, maxZ = math.max(maxX, pos.y), math.max(maxY, pos.y), math.max(maxZ, pos.z)
					has_automation_entity = true
				end
			end
		end

		-- reset because we dont care about single batteries or burners
		if not has_automation_entity then
			entities = {}
		end

		-- sort by Z position and add localplayer for the graph
		if #entities > 0 then
			table.insert(entities, LocalPlayer())
			table.sort(entities, function(a, b) return a:WorldSpaceCenter().z < b:WorldSpaceCenter().z end)
		end
	end

	local MINING_GRAPH = CreateClientConVar("mining_automation_graph", "1", true, true, "Whether to display a graph of your current automation setup or not", 0, 1)
	local function graphHookCallback(ent)
		if not MINING_GRAPH:GetBool() then return end
		if not Ores.Automation.EntityClasses[ent:GetClass()] then return end

		timer.Simple(1, function()
			Ores.Automation.BuildGraph()
		end)
	end

	hook.Add("OnEntityCreated", "mining_rig_automation_graph_hud", graphHookCallback)
	hook.Add("EntityRemoved", "mining_rig_automation_graph_hud", graphHookCallback)

	local GRAPH_ENT_DRAW = {
		player = function(ply, x, y)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawRect(x - GRAPH_UNIT / 4, y - GRAPH_UNIT / 4, GRAPH_UNIT / 2, GRAPH_UNIT / 2, 3)
		end,

		mining_argonite_transformer = function(ent, x, y)
			local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
			local argoniteColor = Ores.__R[argoniteRarity].HudColor

			surface.SetDrawColor(argoniteColor)
			surface.SetMaterial(Ores.Automation.EnergyMaterial)
			surface.DrawTexturedRect(x - GRAPH_UNIT / 2, y - GRAPH_UNIT / 2, GRAPH_UNIT, GRAPH_UNIT)

			surface.SetDrawColor(argoniteColor)
			surface.DrawOutlinedRect(x - GRAPH_UNIT / 2, y - GRAPH_UNIT / 2, GRAPH_UNIT, GRAPH_UNIT, 2)

			surface.SetTextColor(argoniteColor)
			local perc = (math.Round((ent:GetNWInt("ArgoniteCount", 0) / Ores.Automation.BatteryCapacity) * 100)) .. "%"
			surface.SetFont("DermaDefault")
			local tw, th = surface.GetTextSize(perc)
			surface.SetTextPos(x - tw / 2, y - th / 2)
			surface.DrawText(perc)
		end,

		mining_drill = function(ent, x, y)
			local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
			local argoniteColor = Ores.__R[argoniteRarity].HudColor

			surface.SetDrawColor(argoniteColor)
			surface.SetMaterial(Ores.Automation.EnergyMaterial)
			surface.DrawTexturedRect(x - GRAPH_UNIT / 2, y - GRAPH_UNIT / 2, GRAPH_UNIT, GRAPH_UNIT)

			surface.SetDrawColor(125, 125, 125, 255)
			surface.DrawOutlinedRect(x - GRAPH_UNIT / 2, y - GRAPH_UNIT / 2, GRAPH_UNIT, GRAPH_UNIT, 2)

			surface.SetTextColor(255, 255, 255, 255)
			local perc = (math.Round((ent:GetNWInt("Energy", 0) / (Ores.Automation.BatteryCapacity * 3)) * 100)) .. "%"
			surface.SetFont("DermaDefault")
			local tw, th = surface.GetTextSize(perc)
			surface.SetTextPos(x - tw / 2, y - th / 2)
			surface.DrawText(perc)
		end,

		mining_ore_conveyor = function(ent, x, y)
			--surface.SetMaterial(METAL_MAT)
			draw.NoTexture()
			if ent:GetNWBool("IsPowered", true) then
				surface.SetDrawColor(30, 30, 30, 255)
			else
				surface.SetDrawColor(60, 0, 0, 255)
			end
			--surface.DrawRect(x, y, GRAPH_UNIT, GRAPH_UNIT, 2)
			surface.DrawTexturedRectRotated(x, y, GRAPH_UNIT, GRAPH_UNIT * 2, ent:GetAngles().y)

			if ent:GetNWBool("IsPowered", true) then
				surface.SetDrawColor(200, 200, 200, 255)

				local dir = ent:GetRight()
				local dir_side = ent:GetForward()
				surface.DrawLine(x + dir.x * -GRAPH_UNIT, y + dir.y * -GRAPH_UNIT, x + dir.x * GRAPH_UNIT, y + dir.y * GRAPH_UNIT)

				if ent:GetNWInt("Direction", -1) == -1 then
					surface.DrawLine(x + dir.x * -GRAPH_UNIT, y + dir.y * -GRAPH_UNIT, x + dir.x * -GRAPH_UNIT / 2 + dir_side.x * -GRAPH_UNIT / 2, y + dir.y * -GRAPH_UNIT / 2 + dir_side.y * -GRAPH_UNIT / 2)
					surface.DrawLine(x + dir.x * -GRAPH_UNIT, y + dir.y * -GRAPH_UNIT, x + dir.x * -GRAPH_UNIT / 2 + dir_side.x * GRAPH_UNIT / 2, y + dir.y * -GRAPH_UNIT / 2 + dir_side.y * GRAPH_UNIT / 2)
				else
					surface.DrawLine(x + dir.x * GRAPH_UNIT, y + dir.y * GRAPH_UNIT, x + dir.x * GRAPH_UNIT / 2 + dir_side.x * -GRAPH_UNIT / 2, y + dir.y * GRAPH_UNIT / 2 + dir_side.y * -GRAPH_UNIT / 2)
					surface.DrawLine(x + dir.x * GRAPH_UNIT, y + dir.y * GRAPH_UNIT, x + dir.x * GRAPH_UNIT / 2 + dir_side.x * GRAPH_UNIT / 2, y + dir.y * GRAPH_UNIT / 2 + dir_side.y * GRAPH_UNIT / 2)
				end
			end
		end,

		mining_ore_storage = function(ent, x, y)
			surface.SetDrawColor(125, 125, 125, 255)
			surface.DrawRect(x - GRAPH_UNIT / 2, y - GRAPH_UNIT / 2, GRAPH_UNIT, GRAPH_UNIT)

			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawOutlinedRect(x - GRAPH_UNIT / 2, y - GRAPH_UNIT / 2, GRAPH_UNIT, GRAPH_UNIT, 2)
		end,

		mining_argonite_battery = function(ent, x, y)
			local argoniteRarity = Ores.Automation.GetOreRarityByName("Argonite")
			local argoniteColor = Ores.__R[argoniteRarity].HudColor
			surface.SetDrawColor(argoniteColor)
			surface.DrawRect(x - GRAPH_UNIT / 4, y - GRAPH_UNIT / 4, GRAPH_UNIT / 2, GRAPH_UNIT / 2)

			surface.SetDrawColor(125, 125, 125, 255)
			surface.DrawOutlinedRect(x - GRAPH_UNIT / 4, y - GRAPH_UNIT / 4, GRAPH_UNIT / 2, GRAPH_UNIT / 2, 2)
		end,
	}

	hook.Add("HUDPaint", "mining_rig_automation_graph_hud", function()
		if not MINING_GRAPH:GetBool() then return end
		if #entities == 0 then return end

		local centerX, centerY = ScrW() / 3 * 2, ScrH() / 2 - (maxY - minY) / 2
		for i, ent in ipairs(entities) do
			if not IsValid(ent) then
				table.remove(entites, i)
				continue
			end

			local entClass = ent:GetClass()
			if not GRAPH_ENT_DRAW[entClass] then continue end

			local pos = ent:WorldSpaceCenter()
			local x, y = centerX + (pos.x - (minX - 20)), centerY + (pos.y - (minY - 20))
			local alpha = 0.25 + (pos.z - minZ) / (maxZ - minZ)
			local prevAlpha = surface.GetAlphaMultiplier()

			surface.SetAlphaMultiplier(alpha)
			GRAPH_ENT_DRAW[entClass](ent, x, y)
			surface.SetAlphaMultiplier(prevAlpha)
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

	CreateConVar("sbox_maxmining_automation", "40", FCVAR_ARCHIVE, "Maximum amount of mining automation entities a player can have", 0, 100)

	hook.Add("PlayerSpawnedSENT", "mining_automation", function(ply, ent)
		if Ores.Automation.EntityClasses[ent:GetClass()] then
			ply:AddCount("mining_automation", ent)
			return true
		end
	end)

	hook.Add("PlayerSpawnSENT", "mining_automation", function(ply, ent)
		if not ply:CheckLimit("mining_automation") then return false end
	end)
end