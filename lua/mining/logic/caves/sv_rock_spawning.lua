module("ms", package.seeall)
local next = next

local traceMatWhitelist = {
	[MAT_CONCRETE] = true,
	[MAT_DIRT] = true,
	[MAT_SNOW] = true,
	[MAT_SAND] = true,
	[MAT_GRASS] = true
}

Ores = Ores or {}

----------------------------
--- Mining Rock Spawning ---
----------------------------
Ores.__S = {
	-- Defines which ore rarities can spawn in the mine using weighted chance
	{
		Id = 1,
		Chance = 25
	},
	{
		Id = 2,
		Chance = 12
	},
	{
		Id = 3,
		Chance = 3
	}
}

-- Rocks spawned for the cave
Ores.SpawnedRocks = setmetatable({}, {
	__mode = "k"
})

-- Functions for mining rocks
function Ores.SelectRarityFromSpawntable()
	-- Order by descending chance, just in case it isn't already
	table.sort(Ores.__S, function(a, b) return a.Chance > b.Chance end)
	local total = 0

	for k, v in next, Ores.__S do
		total = total + v.Chance
	end

	local rand = math.random() * total
	total = 0

	for i = 1, #Ores.__S do
		total = total + Ores.__S[i].Chance

		if i ~= #Ores.__S then
			if total > rand then return Ores.__S[i].Id end
		else
			return Ores.__S[i].Id
		end
	end
end

-- Add to top of file
Ores.SPAWN_TYPES = {
	NORMAL = 1,
	ARGONITE = 2,
}

-- Configuration for different spawn types
Ores.SPAWN_CONFIG = {
	[Ores.SPAWN_TYPES.NORMAL] = {
		trace_dist = 5000,
		offset = 10,
		min_size = 1,
		max_size = 2,
		effects = true,
		sound = true
	},
	[Ores.SPAWN_TYPES.ARGONITE] = {
		trace_dist = 300,
		offset = 10,
		min_size = 1,
		max_size = 2,
		effects = true,
		sound = true,
		texture_check = "**displacement**"
	},
}

-- Unified rock spawning function
function Ores.SpawnRock(spawnType, startPos, options)
	options = options or {}
	local config = Ores.SPAWN_CONFIG[spawnType]

	-- Validate config
	if not config then return end

	-- Setup trace
	local traceTbl = {
		start = startPos,
		endpos = startPos + (options.direction or VectorRand()) * config.trace_dist,
		mask = MASK_SOLID_BRUSHONLY
	}

	local t = util.TraceLine(traceTbl)
	if t.StartSolid or not t.Hit then return end -- No ground found?

	if not traceMatWhitelist[t.MatType] or (config.texture_check and t.HitTexture ~= config.texture_check) then
		local wallNormal = t.HitNormal
		traceTbl.start = t.HitPos
		traceTbl.endpos = t.HitPos + ((wallNormal - wallNormal:Angle():Up() * 0.75) * 5000)
		t = util.TraceLine(traceTbl)
		local mult = 1 - (traceTbl.start:DistToSqr(t.HitPos) / 16384)

		if mult < 0 then
			mult = 0
		end
	end

	-- Distance checks
	local dist = 6400
	for k in next, Ores.SpawnedRocks do
		if t.HitPos:DistToSqr(k:GetCorrectedPos()) < dist then return end
	end

	for _, v in next, player.GetAll() do
		if t.HitPos:DistToSqr(v:GetPos()) < dist then return end
	end

	-- Create rock entity
	local rock = ents.Create("mining_rock")
	rock:SetPos(t.HitPos + (t.HitNormal * config.offset))
	rock:SetAngles(options.angles or AngleRand())
	rock.OriginalRock = true

	-- Set size
	local size = options.size or (math.random() < 0.33 and config.min_size or config.max_size)
	rock:SetSize(size)

	-- Set rarity
	rock:SetRarity(options.rarity or Ores.SelectRarityFromSpawntable())

	-- Apply effects if enabled
	if config.effects then
		rock:AddEffects(EF_ITEM_BLINK)
		timer.Simple(0.5, function()
			if rock:IsValid() then
				rock:RemoveEffects(EF_ITEM_BLINK)
			end
		end)
	end

	-- Set bonus spots
	if Ores.Settings.BonusSpots:GetBool() then
		rock:SetBonusSpotCount(math.random(0, 2))
	end

	rock:Spawn()

	-- Track spawned rock
	if Ores.SpawnedRocks then
		Ores.SpawnedRocks[rock] = true
	end

	-- Play spawn sound if enabled
	if config.sound then
		local snd = CreateSound(rock, ")ambient/levels/labs/teleport_winddown1.wav")
		snd:SetDSP(16)
		snd:SetSoundLevel(80)
		snd:ChangePitch(math.random(150, 180))
		snd:Play()
	end

	return rock
end

function Ores.GenerateMiningRock(startPos, rarity)
	return Ores.SpawnRock(Ores.SPAWN_TYPES.NORMAL, startPos, {
		rarity = rarity,
		direction = Vector(0, 0, -1)  -- Spawn downwards for normal rocks
	})
end

-- Utility function for getting the cave trigger
local mineTrigger
function Ores.GetMineTrigger()
	if not GetTrigger then return NULL end

	if not (mineTrigger and mineTrigger:IsValid()) then
		mineTrigger = GetTrigger("cave1")
	end

	return mineTrigger or NULL
end

-- Fair mining rock spawning logic
local attemptTimeBase = 30
local nextAttempt = attemptTimeBase

local function AdjustTimer(time)
	nextAttempt = time
	timer.Adjust("ms.Ores_Spawn", nextAttempt, 0)
end

local noSetupText = "No positions set to spawn mining rocks, or invalid data - please populate the ms.mapdata.minespots table with vectors and run 'mapdata_save' on the server!"
local removedPosText = "Removed non-vector entry from ms.mapdata.minespots (temporary until saved with 'mapdata_save'), please check this table!"

local function SpawnRock(rarity)
	if not (mapdata and mapdata.minespots and next(mapdata.minespots)) then
		Ores.Print(noSetupText)

		timer.Create("ms.Ores_Spawn", 1800, 0, function()
			if mapdata and mapdata.minespots and next(mapdata.minespots) then
				Ores.Print("Detected data in ms.mapdata.minespots - mining rock spawning resumed...")
				timer.Create("ms.Ores_Spawn", 5, 0, SpawnRock)

				return
			end

			Ores.Print(noSetupText)
		end)

		return
	end

	if table.Count(Ores.SpawnedRocks) >= (mapdata.NUM_ROCKS or 16) then return false end

	-- 4 attempts
	for i = 1, 4 do
		local id = math.random(1, #mapdata.minespots)

		if not isvector(mapdata.minespots[id]) then
			table.remove(mapdata.minespots, id)
			Ores.Print(removedPosText)
			continue
		end

		if Ores.GenerateMiningRock(mapdata.minespots[id], rarity) then
			local spawnedRocks = table.Count(Ores.SpawnedRocks)
			local spawnRate = attemptTimeBase / (6 - math.Clamp(spawnedRocks - 3, 0, 5))
			-- Scale spawning time by number of rocks left in the mine
			AdjustTimer(spawnRate)
			Ores.PrintVerbose(string.format("%s mining rocks now in the mine - next rock spawning in %s seconds...", spawnedRocks, spawnRate))

			return true
		end
	end

	Ores.Print("Failed to spawn mining rock after 4 retries.")
	AdjustTimer(nextAttempt + attemptTimeBase)
end

local function InitRocks()
	for i = 1, math.ceil((mapdata and mapdata.NUM_ROCKS or 16) * 0.5) do
		if SpawnRock() == nil then return end
	end
end

-- Hook up the rock spawning logic
timer.Create("ms.Ores_Spawn", attemptTimeBase, 0, SpawnRock)
hook.Add("InitPostEntity", "ms.Ores_Init", InitRocks)
hook.Add("PostCleanupMap", "ms.Ores_Init", InitRocks)
-----------------------------
---  Xen Crystal Spawning ---
-----------------------------
resource.AddSingleFile("sound/mining/xen_despawn.mp3")
resource.AddSingleFile("sound/mining/xen_despawning.mp3")
resource.AddSingleFile("sound/mining/xen_spawn.mp3")

function Ores.GenerateXenCrystal(startPos)
	local normal = VectorRand()
	normal.z = -0.025

	local traceTbl = {
		start = startPos,
		endpos = startPos + (normal * 5000),
		mask = MASK_SOLID_BRUSHONLY
	}

	local t = util.TraceLine(traceTbl)
	if t.StartSolid or not t.Hit then return end
	local dist = 6400

	for k in next, Ores.SpawnedRocks do
		if t.HitPos:DistToSqr(k:GetCorrectedPos()) < dist then return end
	end

	for k, v in next, player.GetAll() do
		if t.HitPos:DistToSqr(v:GetPos()) < dist then return end
	end

	local ent = ents.Create("mining_xen_crystal")
	ent:SetPos(t.HitPos + (t.HitNormal * 6))
	ent:SetAngles(AngleRand())
	ent.WallNormal = t.HitNormal
	ent:AddEffects(EF_ITEM_BLINK)

	timer.Simple(0.5, function()
		if ent:IsValid() then
			ent:RemoveEffects(EF_ITEM_BLINK)
		end
	end)

	ent:Spawn()
	ent:EmitSound(")mining/xen_spawn.mp3", 98, math.random(97, 103))
	local timeLimit = 180 - 3

	timer.Simple(timeLimit, function()
		if not ent:IsValid() or ent:GetUnlodged() then return end
		ent:Depart()
	end)

	return ent
end

-- Xen crystal spawning functions
local function TrySpawnCrystal()
	if not (mapdata and mapdata.minespots and next(mapdata.minespots)) then return end
	-- 5% chance to spawn in every minute
	if math.random() > 0.05 then return end

	-- 4 attempts
	for i = 1, 4 do
		local id = math.random(1, #mapdata.minespots)

		if not isvector(mapdata.minespots[id]) then
			table.remove(mapdata.minespots, id)
			Ores.Print(removedPosText)
			continue
		end

		local ent = Ores.GenerateXenCrystal(mapdata.minespots[id])

		if ent then
			Ores.PrintVerbose(string.format("Generated Xen crystal at [%s]", ent:GetPos()))

			return true
		end
	end

	Ores.Print("Failed to spawn xen crystal after 4 retries. How unfortunate... :(")
end

-- Hook up the xen crystal spawning logic
timer.Create("ms.Ores_SpawnXen", 60, 0, TrySpawnCrystal)