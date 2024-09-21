module("ms", package.seeall)
Ores = Ores or {}

local FALLING_ROCKS_MDLS = {
	"models/props_debris/concrete_chunk04a.mdl",
	"models/props_debris/concrete_chunk05g.mdl",
	"models/props_debris/concrete_chunk03a.mdl",
	"models/props_debris/concrete_spawnchunk001b.mdl",
	"models/props_debris/concrete_spawnchunk001a.mdl",
}

local ROCK_MAT = "models/props_wasteland/rockcliff02c"
local MAX_DIST = 1000 -- for traces
local COAL_CHANCE = 70
local CAVE_TRIGGER_NAMES = { "cave1", "volcano" }
local RUMBLE_DURATION = 5
local TUNNEL_RADIUS = 150
local COLLAPSE_CHANCE = 2.5
local OK_CLASSES = { mining_rock = true, mining_xen_crystal = true }
local COLLAPSE_DURATION = 3 * 60
local COLLAPSE_DMG_RADIUS = 300
local COLLAPSE_MIN_INTERVAL = 5 * 60

local DEFAULT_RARITY_DATA = {
	{ Rarity = 0, Chance = COAL_CHANCE },
	{ Rarity = 1, Chance = 100 - COAL_CHANCE }
}

local function spawnRockDebris(rocks, pos, ang, lifeTime)
	local rock = ents.Create("mining_collapse_rock")
	rock:SetLifeTime(lifeTime)
	rock:SetPos(pos + VectorRand(-50, 50))
	rock:SetAngles(ang)
	rock:Spawn()
	rock:Activate()
	rock:PhysWake()

	rock.ms_notouch = true

	local phys = rock:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	table.insert(rocks, rock)

	return rock
end

local function checkExistence(fallingRock, miningRock, originalPos)
	if IsValid(fallingRock) then
		SafeRemoveEntity(fallingRock)

		if not IsValid(miningRock) then return end

		miningRock:SetParent(NULL)
		miningRock:DropToFloor()

		local physMiningRock = miningRock:GetPhysicsObject()
		if IsValid(physMiningRock) then
			physMiningRock:EnableMotion(true)
			physMiningRock:Wake()
		end

		SafeRemoveEntity(fallingRock)
	end

	if not IsValid(miningRock) then return end

	-- check if we're not under/above the mines
	local trDown = util.TraceLine({ start = miningRock:GetPos(), endpos = miningRock:GetPos() - Vector(0, 0, MAX_DIST), filter = miningRock })
	local trUp = util.TraceLine({ start = miningRock:GetPos(), endpos = miningRock:GetPos() + Vector(0, 0, MAX_DIST), filter = miningRock })
	if (trDown.HitWorld and trDown.HitTexture:match("^TOOLS%/")) or (trUp.HitWorld and trUp.HitTexture:match("^TOOLS%/")) then
		SafeRemoveEntity(miningRock)
		return
	end

	-- check if we're not stuck in the ceiling
	local trigger = ms and ms.GetTrigger and ms.GetTrigger("cave1")
	if IsValid(trigger) then
		local max_z = trigger:GetPos().z + trigger:OBBMaxs().z
		if miningRock:GetPos().z > max_z then
			SafeRemoveEntity(miningRock)
			return
		end
	end

	-- remove after a while
	SafeRemoveEntityDelayed(miningRock, COLLAPSE_DURATION * 2)
end

local function spawnFallingRockDebris(pos, originalPos, rarityData)
	table.sort(rarityData, function(a, b) return a.Chance < b.Chance end)

	local fallingRock = ents.Create("prop_physics")
	fallingRock:SetPos(pos)
	fallingRock:SetModel(table.Random(FALLING_ROCKS_MDLS))
	fallingRock:SetModelScale(1, 4)
	fallingRock:SetMaterial(ROCK_MAT)
	fallingRock:Spawn()
	fallingRock:SetKeyValue("classname", "Rock")

	local phys = fallingRock:GetPhysicsObject()
	if IsValid(phys) then
		local vel = VectorRand(-1, 1) * 100
		phys:SetVelocity(vel)
		phys:SetAngleVelocity(vel)
		phys:Wake()
	end

	if math.random(0, 100) <= 10 then
		local miningRock = ents.Create("mining_rock")
		miningRock:SetPos(fallingRock:GetPos())
		miningRock:SetAngles(fallingRock:GetAngles())

		local chance = math.random(0, 100)
		local rarity = 0
		if #rarityData > 0 then
			rarity = rarityData[1].Rarity or 0
		end

		for _, rarityDataChunk in ipairs(rarityData) do
			if rarityDataChunk.Chance > chance then
				rarity = rarityDataChunk.Rarity
			end
		end

		miningRock:SetRarity(rarity)
		miningRock:SetSize(math.random() < 0.33 and 1 or 2)
		miningRock:Spawn()
		miningRock:SetParent(fallingRock)

		timer.Create(("mining_collapse_check_[%d]"):format(miningRock:EntIndex()), 2, COLLAPSE_DURATION / 2, function()
			checkExistence(fallingRock, miningRock, originalPos)
		end)
	else
		SafeRemoveEntityDelayed(fallingRock, 2)
	end
end

local function caveRecipientFilter()
	if not ms or not ms.GetTrigger then return {} end

	local filter = RecipientFilter()
	for _, triggerName in ipairs(CAVE_TRIGGER_NAMES) do
		local trigger = ms.GetTrigger(triggerName)
		if not trigger then continue end

		for ply, _ in pairs(trigger:GetPlayers() or {}) do
			filter:AddPlayer(ply)
		end
	end

	return filter
end

local function playSoundForDuration(sound_path, delay)
	local snd = CreateSound(game.GetWorld(), sound_path, caveRecipientFilter())
	snd:Stop()
	snd:SetDSP(1)
	snd:ChangeVolume(2)
	snd:SetSoundLevel(0) -- play everywhere
	snd:Play()

	timer.Simple(delay, function()
		snd:FadeOut(0.2)
	end)
end

local function isInCave(pos)
	if not _G.ms then return false end
	if not istable(_G.ms.TRIGGERS_REGISTERED) then return false end

	for name, trigger in pairs(_G.ms.TRIGGERS_REGISTERED) do
		if name:match("^cave") or name == "volcano" then
			local mins, maxs = trigger:OBBMins(), trigger:OBBMaxs()
			local trigger_pos = trigger:GetPos()
			if pos:WithinAABox(trigger_pos + maxs, trigger_pos + mins) then
				return true
			end
		end
	end

	return false
end

function Ores.MineCollapse(pos, delay, rarityData, ply)
	if not isInCave(pos) then return end

	local rocks = {}

	rarityData = rarityData or DEFAULT_RARITY_DATA

	if IsValid(ply) then
		local newRarityData = hook.Run("PlayerTriggeredMineCollapse", ply, pos, delay, rarityData, rarityData == DEFAULT_RARITY_DATA)
		if istable(newRarityData) then
			rarityData = newRarityData
		end
	end

	playSoundForDuration("ambient/atmosphere/terrain_rumble1.wav", RUMBLE_DURATION)
	playSoundForDuration("ambience/rocketrumble1.wav", RUMBLE_DURATION)

	util.ScreenShake(pos, 20, 240, RUMBLE_DURATION * 2, 2000)

	local ceiling_tr = util.TraceLine({
		start = pos,
		endpos = pos + Vector(0, 0, MAX_DIST),
		filter = function() return false end,
		mask = MASK_SOLID_BRUSHONLY,
	})

	local ceiling_pos = ceiling_tr.HitPos
	timer.Create("mining_collapse_rumble", 0.25, 0, function()
		for _ = 1, math.random(2, 6) do
			local fallingRockPos = ceiling_pos + VectorRand(-TUNNEL_RADIUS, TUNNEL_RADIUS)
			fallingRockPos.z = ceiling_pos.z + (ceiling_tr.HitNormal * 10).z -- set the z axes to an appropriate point

			if not util.IsInWorld(fallingRockPos) then continue end

			spawnFallingRockDebris(fallingRockPos, pos, rarityData)
		end
	end)

	timer.Simple(RUMBLE_DURATION, function()
		timer.Remove("mining_collapse_rumble")

		playSoundForDuration("ambient/materials/cartrap_explode_impact1.wav", 5)
		playSoundForDuration("physics/concrete/boulder_impact_hard" .. math.random(1, 4) .. ".wav", 5)

		local effectData = EffectData()
		effectData:SetOrigin(pos)
		util.Effect("litesmoke", effectData, true, true)

		for _, ent in ipairs(ents.FindInSphere(pos, COLLAPSE_DMG_RADIUS)) do
			local rock = spawnRockDebris(rocks, Vector(0, 0, 0), Angle(0, 0, 0), delay - 1)
			local force = Vector(math.random() > 0.5 and 100 or -100, math.random() > 0.5 and 100 or -100, math.random() > 0.5 and 100 or -100) * math.random(4, 8)
			local dmg = DamageInfo()
			dmg:SetInflictor(rock)
			dmg:SetAttacker(rock)
			dmg:SetDamageForce(force)
			dmg:SetDamage(1000)
			dmg:SetDamageType(DMG_CRUSH)
			ent:TakeDamageInfo(dmg)

			-- fallback
			if ent:IsPlayer() then
				timer.Simple(0, function()
					if IsValid(ent) and ent:Alive() then
						if IsValid(rock) then
							hook.Run("PlayerDeath", ent, rock, rock)
						end

						ent:KillSilent()
					end
				end)

				ent.KilledInMiningIncident = true
			end

			rock:Remove()
		end

		timer.Simple(0.25, function()
			for _ = 1, math.random(5, 10) do
				local debrisAng = AngleRand(-45, 45)
				spawnRockDebris(rocks, pos, debrisAng, delay - 1)
			end
		end)

		timer.Simple(delay, function()
			for _, rock in pairs(rocks) do
				if IsValid(rock) then
					rock:Remove()
				end
			end
		end)
	end)
end

local nextIncidentRock = 0
hook.Add("OnEntityCreated", "mining_collapse", function(ent)
	if not IsValid(ent) then return end
	if not OK_CLASSES[ent:GetClass()] then return end

	timer.Simple(0, function()
		if not IsValid(ent) then return end
		if ent:GetClass() == "mining_rock" and not ent.OriginalRock then return end

		if math.random(0, 100) <= COLLAPSE_CHANCE and nextIncidentRock <= CurTime() then
			ent.MiningIncident = true
			nextIncidentRock = CurTime() + COLLAPSE_MIN_INTERVAL
		end
	end)
end)

hook.Add("PlayerSpawn", "mining_collapse", function(ply)
	if not ply.KilledInMiningIncident then return end

	if landmark and landmark.get then
		local cave_pos = landmark.get("land_caves")
		if cave_pos then
			ply:SetPos(cave_pos)
		end
	end

	ply.KilledInMiningIncident = nil
end)

hook.Add("EntityTakeDamage", "mining_collapse", function(ent)
	if not ent.MiningIncident then return end
	if not ent.OriginalRock then return end

	playSoundForDuration("ambient/atmosphere/terrain_rumble1.wav", 4)
	playSoundForDuration("ambience/rocketrumble1.wav", 4)
end)

hook.Add("PlayerDestroyedMiningRock", "mining_collapse", function(ply, rock)
	if not rock.MiningIncident then return end
	if not rock.OriginalRock then return end
	if ply.IsInZone and not ply:IsInZone("cave") then return end

	Ores.MineCollapse(ply:EyePos(), COLLAPSE_DURATION, nil, ply)
end)

-- after the core goes off it weakens the cave structures
--[[hook.Add("MGNCoreExploded", "mining_collapse", function()
	for _, rock in ipairs(ents.FindByClass("mining_rock")) do
		if not rock.OriginalRock then continue end

		rock.MiningIncident = true
	end
end)]]
