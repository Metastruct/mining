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

			child.OnEntityCopyTableFinish = function(_, data)
				-- this works with the vanilla duplicator but not with the AdvDupe2
				-- see: https://github.com/wiremod/advdupe2/issues/406
				--[[
				for k, v in pairs(data) do
					data[k] = nil
				end]]
			end
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