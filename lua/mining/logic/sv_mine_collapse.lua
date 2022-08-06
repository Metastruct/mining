
-- remove if you don't like, this is mostly a test

local ROCK_MDLS = {
	"models/props_canal/rock_riverbed01a.mdl",
	"models/props_canal/rock_riverbed01b.mdl",
	"models/props_canal/rock_riverbed01c.mdl",
	"models/props_canal/rock_riverbed01d.mdl",
}

local ROCK_MAT = "models/props_wasteland/rockcliff02c"
local function spawnRockDebris(rocks, pos, ang)
	local rock = ents.Create("prop_physics")
	rock:SetPos(pos)
	rock:SetModel(table.Random(ROCK_MDLS))
	rock:SetMaterial(ROCK_MAT)
	rock:SetAngles(ang)
	rock:Spawn()
	rock.ms_notouch = true

	local phys = rock:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
	end

	table.insert(rocks, rock)
end

local triggerNames = { "cave1", "cave2", "caveshaft", "cavebunker", "cavesafespot", "epicminecoolthing" }
local function CaveRecipientFilter()
	if not ms or not ms.GetTrigger then return {} end

	local filter = RecipientFilter()
	for _, triggerName in ipairs(triggerNames) do
		local trigger = ms.GetTrigger(triggerName)
		if not trigger then continue end

		for ply, _ in pairs(trigger:GetPlayers() or {}) do
			filter:AddPlayer(ply)
		end
	end

	return filter
end

local function playSoundForDuration(sound_path, delay)
	local snd = CreateSound(game.GetWorld(), sound_path, CaveRecipientFilter())
	snd:Stop()
	snd:SetDSP(1)
	snd:ChangeVolume(2, 0.1)
	snd:SetSoundLevel(0) -- play everywhere
	snd:Play()

	timer.Simple(delay, function()
		snd:FadeOut(0.2)
	end)
end

local RUMBLE_DURATION = 5
local function mineCollapse(pos, delay)
	playSoundForDuration("ambient/atmosphere/terrain_rumble1.wav", RUMBLE_DURATION)
	playSoundForDuration("ambience/rocketrumble1.wav", RUMBLE_DURATION)

	util.ScreenShake(pos, 20, 240, RUMBLE_DURATION * 2, 2000)

	timer.Simple(RUMBLE_DURATION, function()
		playSoundForDuration("ambient/materials/cartrap_explode_impact1.wav", 5)
		playSoundForDuration("physics/concrete/boulder_impact_hard" .. math.random(1, 4) .. ".wav", 5)

		local effectData = EffectData()
		effectData:SetOrigin(pos)
		util.Effect("litesmoke", effectData, true, true)

		local rocks = {}
		for _ = 1, math.random(5, 10) do
			local debrisAng = AngleRand(-45, 45)
			spawnRockDebris(rocks, pos, debrisAng)
			spawnRockDebris(rocks, pos, -debrisAng)
		end

		for _ = 1, math.random(0, 4) do
			local rockPos = pos + VectorRand(-50, 50)
			local miningRock = ents.Create("mining_rock")
			miningRock:SetPos(rockPos)
			miningRock:SetAngles(AngleRand())
			miningRock:SetRarity(math.random(0, 100) <= 70 and 0 or 1)
			miningRock:Spawn()

			table.insert(rocks, miningRock)
		end

		for _, ent in ipairs(ents.FindInSphere(pos, 200)) do
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

local MAX_DIST = 1000
local TUNNEL_HEIGHT = 150
local function getCenterOfTunnel(ply, ent)
	local pos = ent:GetPos()
	if not IsValid(ply) then return pos end

	local dir = (ply:GetPos() - pos):GetNormalized()
	dir.z = 0

	local horizontalTrace = util.TraceLine({
		start = pos,
		endpos = pos +  dir * MAX_DIST,
		filter = function() return false end
	})

	if not horizontalTrace.Hit then return ent:GetPos() end

	local horizontalCenter = pos + dir * (horizontalTrace.HitPos:Distance(pos) / 2)
	local verticalTrace = util.TraceLine({
		start = horizontalCenter,
		endpos = horizontalCenter + Vector(0, 0, MAX_DIST),
		filter = function() return false end
	})

	if not verticalTrace.Hit then return horizontalCenter end

	local verticalDist = (verticalTrace.HitPos:Distance(horizontalCenter) / 2)
	if verticalDist > TUNNEL_HEIGHT then return horizontalCenter end

	return horizontalCenter + (Vector(0, 0, 1) * verticalDist)
end

local OK_CLASSES = { mining_rock = true, mining_xen_crystal = true }
hook.Add("OnEntityCreated", "mining_collapse", function(ent)
	if not OK_CLASSES[ent:GetClass()] then return end
	if ent:GetClass() == "mining_rock" and not ent.OriginalRock then return end

	if math.random(0, 100) <= 5 then
		ent.MiningIncident = true
	end
end)

local COLLAPSE_DURATION = 5 * 60
hook.Add("PlayerDestroyedMiningRock", "mining_collapse", function(ply, rock)
	if not rock.MiningIncident then return end
	if not rock.OriginalRock then return end

	local center = getCenterOfTunnel(ply, rock)
	mineCollapse(center, COLLAPSE_DURATION)
end)
