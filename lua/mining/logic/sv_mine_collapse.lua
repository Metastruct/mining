local ROCK_MDLS = {
	"models/props_wasteland/rockcliff01b.mdl",
	"models/props_wasteland/rockcliff01c.mdl",
	"models/props_wasteland/rockcliff01e.mdl",
	"models/props_wasteland/rockcliff01f.mdl",
	"models/props_wasteland/rockcliff01g.mdl",
	"models/props_wasteland/rockcliff01j.mdl",
	"models/props_wasteland/rockcliff01k.mdl",
	"models/props_wasteland/rockcliff05a.mdl",
}

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
local CAVE_TRIGGER_NAMES = { "cave1" }
local RUMBLE_DURATION = 5
local TUNNEL_RADIUS = 150
local COLLAPSE_CHANCE = 5
local OK_CLASSES = { mining_rock = true, mining_xen_crystal = true }
local COLLAPSE_DURATION = 3 * 60

local function spawnRockDebris(rocks, pos, ang)
	local rock = ents.Create("prop_physics")
	rock:SetPos(pos + VectorRand(-50, 50))
	rock:SetModel(table.Random(ROCK_MDLS))
	rock:SetModelScale(math.random(0.5, 2))
	rock:SetMaterial(ROCK_MAT)
	rock:SetAngles(ang)
	rock:Spawn()
	rock:Activate()

	rock.ms_notouch = true

	local phys = rock:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	table.insert(rocks, rock)
end

local function spawnFallingRockDebris(pos, originalPos, checkOffset)
	local fallingRock = ents.Create("prop_physics")
	fallingRock:SetPos(pos)
	fallingRock:SetModel(table.Random(FALLING_ROCKS_MDLS))
	fallingRock:SetModelScale(1, 4)
	fallingRock:SetMaterial(ROCK_MAT)
	fallingRock:Spawn()

	local phys = fallingRock:GetPhysicsObject()
	if IsValid(phys) then
		local vel = VectorRand(-1, 1) * 100
		phys:SetVelocity(vel)
		phys:SetAngleVelocity(vel)
	end

	if math.random(0, 100) <= 10 then
		fallingRock:SetNoDraw(true)

		local miningRock = ents.Create("mining_rock")
		miningRock:SetPos(fallingRock:GetPos())
		miningRock:SetAngles(fallingRock:GetAngles())
		miningRock:SetRarity(math.random(0, 100) <= COAL_CHANCE and 0 or 1)
		miningRock:SetSize(math.random() < 0.33 and 1 or 2)
		miningRock:Spawn()
		miningRock:SetParent(fallingRock)

		timer.Simple(2, function()
			if not IsValid(miningRock) then return end

			miningRock:SetParent(NULL)
			miningRock:DropToFloor()

			local physMiningRock = miningRock:GetPhysicsObject()
			if IsValid(physMiningRock) then
				physMiningRock:EnableMotion(true)
				physMiningRock:Wake()
			end

			SafeRemoveEntity(fallingRock)

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

			-- check if the rock is accessible
			local trToOriginalPos = util.TraceLine({ start = miningRock:GetPos() + checkOffset, endpos = originalPos + checkOffset, filter = function() return false end, mask = MASK_SOLID_BRUSHONLY })
			if trToOriginalPos.Fraction <= 0.9 then
				SafeRemoveEntity(miningRock)
				return
			end

			-- remove after a while
			SafeRemoveEntityDelayed(miningRock, COLLAPSE_DURATION * 2)
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

local function mineCollapse(ply, delay)
	local rocks = {}
	local pos = ply:GetPos()
	local plyHeight = ply:OBBMaxs().z

	playSoundForDuration("ambient/atmosphere/terrain_rumble1.wav", RUMBLE_DURATION)
	playSoundForDuration("ambience/rocketrumble1.wav", RUMBLE_DURATION)

	util.ScreenShake(pos, 20, 240, RUMBLE_DURATION * 2, 2000)

	local ceiling_pos = util.TraceLine({ start = pos, endpos = pos + Vector(0, 0, MAX_DIST), filter = function() return false end }).HitPos
	timer.Create("mining_collapse_rumble", 0.25, 0, function()
		for _ = 1, math.random(2, 6) do
			local fallingRockPos = pos + VectorRand(-TUNNEL_RADIUS, TUNNEL_RADIUS)
			fallingRockPos.z = ceiling_pos.z - 10 -- extra offset to spawn the rocks freely

			if not util.IsInWorld(fallingRockPos) then continue end

			spawnFallingRockDebris(fallingRockPos, pos, Vector(0, 0, plyHeight))
		end
	end)

	timer.Simple(RUMBLE_DURATION, function()
		timer.Remove("mining_collapse_rumble")

		playSoundForDuration("ambient/materials/cartrap_explode_impact1.wav", 5)
		playSoundForDuration("physics/concrete/boulder_impact_hard" .. math.random(1, 4) .. ".wav", 5)

		local effectData = EffectData()
		effectData:SetOrigin(pos)
		util.Effect("litesmoke", effectData, true, true)

		for _ = 1, math.random(5, 10) do
			local debrisAng = AngleRand(-45, 45)
			spawnRockDebris(rocks, pos, debrisAng)
			--spawnRockDebris(rocks, pos, -debrisAng)
		end

		for _, ent in ipairs(ents.FindInSphere(pos, 300)) do
			if ent:IsPlayer() and ent:Alive() then
				local dmg = DamageInfo()
				dmg:SetInflictor(game.GetWorld())
				dmg:SetAttacker(game.GetWorld())
				dmg:SetDamage(1000)
				dmg:SetDamageType(DMG_CRUSH)
				ent:TakeDamageInfo(dmg)

				-- fallback
				timer.Simple(0, function()
					if IsValid(ent) and ent:Alive() then
						hook.Run("PlayerDeath", ent, game.GetWorld(), game.GetWorld())
						ent:KillSilent()
					end
				end)

				ent.KilledInMiningIncident = true
			end
		end

		timer.Simple(delay, function()
			for _, rock in pairs(rocks) do
				if IsValid(rock) then
					rock:Remove()
				end
			end
		end)
	end)
end

hook.Add("OnEntityCreated", "mining_collapse", function(ent)
	if not IsValid(ent) then return end
	if not OK_CLASSES[ent:GetClass()] then return end

	timer.Simple(0, function()
		if not IsValid(ent) then return end
		if ent:GetClass() == "mining_rock" and not ent.OriginalRock then return end

		if math.random(0, 100) <= COLLAPSE_CHANCE then
			ent.MiningIncident = true
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

	mineCollapse(ply, COLLAPSE_DURATION)
end)

-- after the core goes off it weakens the cave structures
hook.Add("MGNCoreExploded", "mining_collapse", function()
	for _, rock in ipairs(ents.FindByClass("mining_rock")) do
		if not rock.OriginalRock then continue end

		rock.MiningIncident = true
		rock.PreventSplit = true
	end
end)
