module("ms", package.seeall)
Ores = Ores or {}

local IsValid = _G.IsValid
local isstring = _G.isstring

Ores.Automation = Ores.Automation or {
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
		mining_ore_smelter = true,
		mining_coin_minter = true,
		mining_oil_extractor = true,
		mining_chip_router = true,
		mining_generator = true,
	},
	BaseOreProductionRate = 10, -- 1 per 10 seconds
	EnergyMaterial = Material("models/props_combine/coredx70"),
	EnergyEntities = {},
	NonStorableOres = { "Argonite", "Detonite" },
	EntityClasses = {
		mining_ore_conveyor = true,
		mining_ore_storage = true,
		mining_drill = true,
		mining_conveyor_splitter = true,
		mining_argonite_battery = true,
		mining_fuel_tank = true,
		mining_argonite_transformer = true,
		mining_detonite_bomb = true,
		mining_ore_smelter = true,
		mining_coin_minter = true,
		mining_oil_extractor = true,
		mining_chip_router = true,
		mining_generator = true,
	},
	GraphUnit = 40,
	GraphHeightMargin = 75,
	HudFrameMaterial = Material("mining/automation/hud_frame.png", "smooth noclamp"),
	HudPadding = 10,
	HudSepColor = Color(100, 100, 100, 255),
	HudActionColor = Color(255, 125, 0, 255),
	IngotWorth = 2,
	IngotSize = 5,
	OilExtractionRate = 10 * 60, -- 1 fuel tank per 60 seconds
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

	local MINING_INFO_HUD = CreateClientConVar("mining_automation_hud_frames", "1", true, true, "Display info frames for mining automation entities", 0, 1)

	local ENTITY_INFO_EXTRAS = { mining_argonite_container = true }
	local FONT_HEIGHT = 30
	local FRAME_WIDTH = 250
	local FRAME_HEIGHT = 100
	local COLOR_WHITE = Color(255, 255, 255, 255)
	local FRAME_PADDING = 5

	local MTX_TRANSLATION = Vector(0, 0)
	local MTX_SCALE = Vector(1, 1, 1)
	local function drawEntityInfoFrame(ent, data)
		if not MINING_INFO_HUD:GetBool() then return end

		local totalHeight = ent.MiningInfoFrameHeight or (FRAME_HEIGHT + (#data * (FONT_HEIGHT + Ores.Automation.HudPadding)))
		local pos = ent:WorldSpaceCenter():ToScreen()
		if not pos.visible then return end

		local x, y = pos.x - FRAME_WIDTH / 2, pos.y - totalHeight / 2

		MTX_TRANSLATION.x = x
		MTX_TRANSLATION.y = y

		local mtx = Matrix()
		mtx:Translate(MTX_TRANSLATION)
		mtx:Scale(MTX_SCALE * math.max(0.6, ScrW() / 2560))
		mtx:Translate(-MTX_TRANSLATION)

		cam.PushModelMatrix(mtx, true)

		surface.SetMaterial(Ores.Automation.HudFrameMaterial)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(x, y, FRAME_WIDTH, totalHeight)

		local offset = Ores.Automation.HudPadding + FRAME_PADDING
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
				surface.SetTextPos(x + Ores.Automation.HudPadding + FRAME_PADDING, y + offset)
				surface.DrawText(lineData.Label)

				local text = tostring(lineData.Value)
				if lineData.MaxValue then
					local perc = math.Round((lineData.Value / lineData.MaxValue) * 100)
					local r = 255
					local g = 255 / 100 * perc
					local b = 255 / 100 * perc

					surface.SetTextColor(r, g, b, 255)
					text = tostring(perc)
				elseif lineData.ValueColor then
					surface.SetTextColor(lineData.ValueColor)
				end

				local tw, th = surface.GetTextSize(text)
				surface.SetTextPos(x + FRAME_WIDTH - (tw + Ores.Automation.HudPadding * 2), y + offset)
				surface.DrawText(text)

				offset =  offset + th + Ores.Automation.HudPadding
			elseif lineData.Type == "State" then
				local state = tobool(lineData.Value) or false
				surface.SetDrawColor(state and 0 or 255, state and 255 or 0, 0, 255)
				surface.DrawRect(x + FRAME_WIDTH - 25, y + 15, 15, 15)
			else
				if not isstring(lineData.Text) then continue end

				surface.SetFont("mining_automation_hud")

				surface.SetTextColor(lineData.Color or COLOR_WHITE)
				surface.SetTextPos(x + Ores.Automation.HudPadding + FRAME_PADDING, y + offset)
				surface.DrawText(lineData.Text)

				local _, th = surface.GetTextSize(lineData.Text)
				offset = offset + th + Ores.Automation.HudPadding
			end

			if lineData.Border == true then
				surface.SetDrawColor(Ores.Automation.HudSepColor)
				surface.DrawRect(x + Ores.Automation.HudPadding, y + offset, FRAME_WIDTH - Ores.Automation.HudPadding * 2, 2)
				offset = offset + Ores.Automation.HudPadding
			end
		end

		-- more accurate height
		ent.MiningInfoFrameHeight = offset + Ores.Automation.HudPadding + FRAME_PADDING

		cam.PopModelMatrix()
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

	local function gainEnergy(poweredEnt, ent)
		local className = ent:GetClass()
		local energyAccesors = Ores.Automation.EnergyEntities[className]
		if not energyAccesors then return end

		-- can't put fuel inside energy, etc...
		if not istable(poweredEnt.AcceptedPowerTypes) then return end
		if not poweredEnt.AcceptedPowerTypes[energyAccesors.Type] then return end

		local time = CurTime()
		if time < (poweredEnt.NextEnergyEntity or 0) then return end
		if ent.MiningInvalidPower then return end

		local canReceiveEnergy = true
		if isfunction(poweredEnt.CanReceiveEnergy) then
			local ret = poweredEnt:CanReceiveEnergy(energyAccesors.Type)
			if ret ~= nil then canReceiveEnergy = ret end
		end

		if not canReceiveEnergy then return end

		if ent.CPPIGetOwner and poweredEnt.CPPIGetOwner then
			local p1, p2 = ent:CPPIGetOwner(), poweredEnt:CPPIGetOwner()
			if IsValid(p1) and IsValid(p2) and p1 ~= p2 then
				local areFriends = p1.AreFriends and p1:AreFriends(p2) or false
				if not areFriends then return end
			end
		end

		local energyAmount = energyAccesors.Get(ent)
		local curEnergy = poweredEnt:GetNW2Int(energyAccesors.Type, 0)
		local energyToAdd = math.min(poweredEnt:GetNW2Int("Max" .. energyAccesors.Type, 100) - curEnergy, energyAmount)
		local newAmount = math.min(poweredEnt:GetNW2Int("Max" .. energyAccesors.Type, 100), curEnergy + energyToAdd)

		poweredEnt:SetNW2Int(energyAccesors.Type, newAmount)
		energyAccesors.Set(ent, math.max(0, energyAmount - energyToAdd))

		if _G.WireLib then
			_G.WireLib.TriggerOutput(poweredEnt, energyAccesors.Type, newAmount)
		end

		if energyAmount - energyToAdd < 1 then
			SafeRemoveEntity(ent)
			ent.MiningInvalidPower = true
		else
			ent:PhysWake()
		end

		poweredEnt:EmitSound(")ambient/machines/thumper_top.wav", 75, 70)
		poweredEnt.NextEnergyEntity = time + 2
	end

	local BRUSH_BOUNDS = Vector(100, 100, 100)
	local function makeBrushForPoweredEntity(ent)
		local brush = ents.Create("base_brush")
		brush:SetPos(ent:WorldSpaceCenter())
		brush:SetParent(ent)
		brush:SetTrigger(true)
		brush:SetSolid(SOLID_BBOX)
		brush:SetNotSolid(true)
		brush:SetCollisionBounds(-BRUSH_BOUNDS, BRUSH_BOUNDS)

		function brush:Touch(touchedEnt)
			gainEnergy(ent, touchedEnt)
		end

		function brush:OnRemove()
			timer.Simple(1, function()
				if not IsValid(ent) then return end
				makeBrushForPoweredEntity(ent)
			end)
		end

		return brush
	end

	function Ores.Automation.RegisterEnergyEntityClass(energyType, className, get, set)
		Ores.Automation.EnergyEntities[className] = {
			Type = energyType,
			Get = get,
			Set = set,
		}
	end

	function Ores.Automation.RegisterEnergyPoweredEntity(ent, energyDataSettings, extraOutputs)
		if _G.WireLib then
			local wireOutputs = {}
			for _, energyData in pairs(energyDataSettings) do
				table.insert(wireOutputs, ("%s (Outputs the current %s level) [NORMAL]"):format(energyData.Type, energyData.Type:lower())) -- current level
				table.insert(wireOutputs, ("Max%s (Outputs the max level of %s) [NORMAL]"):format(energyData.Type, energyData.Type:lower())) -- max level
			end

			if istable(extraOutputs) then
				for _, output in pairs(extraOutputs) do
					table.insert(wireOutputs, output.Identifier)
				end
			end

			_G.WireLib.CreateOutputs(ent, wireOutputs)

			if istable(extraOutputs) then
				for _, output in pairs(extraOutputs) do
					local outputName = output.Identifier:Split(" ")[0]
					_G.WireLib.TriggerOutput(ent, outputName, output.StartValue)
				end
			end
		end

		for _, energyData in pairs(energyDataSettings) do
			ent:SetNW2Int(energyData.Type, energyData.StartValue or 0)
			ent:SetNW2Int("Max" .. energyData.Type, energyData.MaxValue)

			ent.AcceptedPowerTypes = ent.AcceptedPowerTypes or {}
			ent.AcceptedPowerTypes[energyData.Type] = true

			if _G.WireLib then
				_G.WireLib.TriggerOutput(ent, energyData.Type, energyData.StartValue)
				_G.WireLib.TriggerOutput(ent, "Max" .. energyData.Type, energyData.MaxValue)
			end

			local brush
			if not energyData.NoBrush then
			 	brush = makeBrushForPoweredEntity(ent)
			end

			local timerName = ("mining_automation_power_[%s]_entity_[%d]"):format(energyData.Type, ent:EntIndex())
			timer.Create(timerName, energyData.ConsumptionRate, 0, function()
				if not IsValid(ent) then
					timer.Remove(timerName)
					SafeRemoveEntity(brush)
					return
				end

				local canConsumeEnergy = true
				if isfunction(ent.CanConsumeEnergy) then
					local ret = ent:CanConsumeEnergy(energyData.Type)
					if ret ~= nil then canConsumeEnergy = ret end
				end

				if canConsumeEnergy then
					local curEnergy = ent:GetNW2Int(energyData.Type, 0)
					local newEnergyValue = math.max(0, curEnergy - (energyData.ConsumptionAmount or 1))
					ent:SetNW2Int(energyData.Type, newEnergyValue)

					if _G.WireLib then
						_G.WireLib.TriggerOutput(ent, energyData.Type, newEnergyValue)
					end

					if isfunction(ent.ConsumedEnergy) then
						ent:ConsumedEnergy(energyData.Type, curEnergy, newEnergyValue, energyData.ConsumptionAmount or 1)
					end
				end
			end)
		end
	end

	function Ores.Automation.IsEnergyPoweredEntity(ent, energyType)
		if not IsValid(ent) then return false end

		local timerName = ("mining_automation_power_[%s]_entity_[%d]"):format(energyType, ent:EntIndex())
		return timer.Exists(timerName)
	end

	hook.Add("PlayerUse", "mining_automation_use_fn_replication", function(ply, ent)
		local parent = ent:GetParent()
		if IsValid(parent) and Ores.Automation.EnergyEntities[ent:GetClass()] then
			parent:Use(ply, ply)
		end
	end)

	CreateConVar("sbox_maxmining_automation", "40", FCVAR_ARCHIVE, "Maximum amount of mining automation entities a player can have", 0, 100)

	hook.Add("OnEntityCreated", "mining_automation", function(ent)
		local className = ent:GetClass()
		if className == "mining_drill" then return end
		if not Ores.Automation.EntityClasses[className] then return end
		if not ent.CPPIGetOwner then return end

		-- if an energy entity collides with something that can receive it, force the transfer to happen
		if Ores.Automation.EnergyEntities[className] then
			local physicsCollide = ent.PhysicsCollide
			function ent:PhysicsCollide(data, ...)
				if IsValid(data.HitEntity) then
					gainEnergy(data.HitEntity, self)

					if self.MiningInvalidPower then return end -- means we have been removed, dont go further
				end

				return physicsCollide(self, data, ...)
			end
		end

		timer.Simple(0, function()
			if not IsValid(ent) then return end

			local ply = ent:CPPIGetOwner()
			if not IsValid(ply) then return end

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
end