module("ms", package.seeall)
Ores = Ores or {}

local TELEPORT_INTERVAL_MIN = 3  -- Minimum seconds between teleports
local TELEPORT_INTERVAL_MAX = 8  -- Maximum seconds between teleports
local TELEPORT_RANGE = 500      -- Maximum teleport distance
local QUANTUM_CHANCE = 2        -- 2% chance for a rock to be quantum

-- Helper function to find a valid teleport position
local function findTeleportPosition(rock)
	local originalPos = rock:GetPos()
	local attempts = 0
	local maxAttempts = 10

	while attempts < maxAttempts do
		-- Generate random position within range
		local randomOffset = VectorRand() * TELEPORT_RANGE
		randomOffset.z = randomOffset.z * 0.5 -- Reduce vertical variation
		local targetPos = originalPos + randomOffset

		-- Trace to check if position is valid
		local tr = util.TraceLine({
			start = targetPos + Vector(0, 0, 50),
			endpos = targetPos - Vector(0, 0, 100),
			mask = MASK_SOLID_BRUSHONLY
		})

		if tr.Hit and not tr.StartSolid and util.IsInWorld(tr.HitPos) then
			return tr.HitPos + (tr.HitNormal * 10)
		end

		attempts = attempts + 1
	end

	return nil
end

-- Helper function for teleport effects
local tp_effects = {}
local function doTeleportEffects(pos, ent)
	if #tp_effects > 4 then
		for k, v in pairs(tp_effects) do
			if not IsValid(v) then
				table.remove(tp_effects, k)
				continue
			end

			v:Remove()
			table.remove(tp_effects, k)
			break
		end
	end

	local tesla = ents.Create("point_tesla")
	tesla:SetPos( pos )
	tesla:SetKeyValue("texture", "trails/electric.vmt")
	tesla:SetKeyValue("m_iszSpriteName", "sprites/physbeam.vmt")
	--tesla:SetKeyValue("m_SourceEntityName", "secret_tesla")
	tesla:SetKeyValue("m_Color", "0 255 0")
	tesla:SetKeyValue("m_flRadius",  "60")
	tesla:SetKeyValue("interval_min", "0.1")
	tesla:SetKeyValue("interval_max", "0.1")
	tesla:SetKeyValue("beamcount_min", "5")
	tesla:SetKeyValue("beamcount_max", "10")
	tesla:SetKeyValue("thick_min", "5")
	tesla:SetKeyValue("thick_max", "10")
	tesla:SetKeyValue("lifetime_min", "0.2")
	tesla:SetKeyValue("lifetime_max", "0.2")
	--tesla:SetKeyValue("m_SoundName", "ambient/levels/labs/electric_explosion"..math.random(1,5)..".wav")
	tesla:EmitSound("ambient/levels/labs/electric_explosion" .. math.random(1,5) .. ".wav", 75, 100, 0.5)
	tesla:Spawn()
	tesla:Activate()

	--tesla:SetParent(ent)

	timer.Simple(0.3, function()
		if not IsValid(tesla) then return end
		tesla:SetKeyValue("thick_min", "15")
		tesla:SetKeyValue("thick_max", "25")
		tesla:SetKeyValue("m_flRadius",  "80")
		tesla:SetKeyValue("beamcount_min", "20")
		tesla:SetKeyValue("beamcount_max", "35")
	end)

	tesla:Fire("TurnOn", "", 0)
	tesla:Fire("DoSpark", "", 0)

	timer.Simple(0.8, function()
		if not IsValid(tesla) then return end
		tesla:SetKeyValue("thick_min", "5")
		tesla:SetKeyValue("thick_max", "10")
		tesla:SetKeyValue("beamcount_min", "5")
		tesla:SetKeyValue("beamcount_max", "10")
		tesla:SetKeyValue("m_flRadius",  "60")
	end)

	timer.Simple(1.5, function()
		if not IsValid(tesla) then return end

		tesla:SetKeyValue("thick_min", "2")
		tesla:SetKeyValue("thick_max", "5")
		tesla:SetKeyValue("beamcount_min", "2")
		tesla:SetKeyValue("beamcount_max", "5")
		tesla:SetKeyValue("m_flRadius",  "40")
	end)

	local idx = table.insert(tp_effects, tesla)
	timer.Simple(2, function()
		if IsValid(tesla) then
			tesla:Remove()
		end
		table.remove(tp_effects, idx)
	end)
end

local function teleportRock(ent)
	local newPos = findTeleportPosition(ent)
	if not newPos then return end

	local oldPos = ent:GetPos()

	-- Pre-teleport effects
	doTeleportEffects(oldPos, ent)
	timer.Simple(0, function()
		if not IsValid(ent) then return end

		ent:EmitSound("ambient/machines/teleport3.wav", 75, 100, 1)

		-- Teleport the rock
		ent:SetPos(newPos)
		ent:SetAngles(AngleRand()) -- Set random angles

		-- Post-teleport effects
		doTeleportEffects(newPos, ent)
		ent:EmitSound("ambient/machines/teleport1.wav", 75, 100, 1)
	end)
end

-- Register the quantum rock event
Ores.RegisterRockEvent({
	Id = "quantum",
	Chance = QUANTUM_CHANCE,
	CheckValid = function(ent)
		local rarity = ent.GetRarity and ent:GetRarity() or -1
		if not Ores.__R[rarity] then return false end
		if rarity > 5 then return false end

		local trigger = ms and ms.GetTrigger and ms.GetTrigger("cave1")
		if not trigger then return false end

		-- Don't allow quantum rocks too high in the cave
		local zMax = trigger:GetPos().z + trigger:OBBMaxs().z - 200
		if ent:GetPos().z > zMax then return false end

		return true
	end,

	OnMarked = function(ent)
		-- Add visual identifier
		util.SpriteTrail(ent, 0, Color(0, 255, 0, 255), false, 30, 1, 3, 1 / (15 + 1) * 0.5, "trails/laser.vmt")

		-- Create timer for random teleportation
		local timerName = "quantum_rock_" .. ent:EntIndex()
		timer.Create(timerName, math.random(TELEPORT_INTERVAL_MIN, TELEPORT_INTERVAL_MAX), 0, function()
			if not IsValid(ent) then
				timer.Remove(timerName)
				return
			end

			-- Check for nearby players before teleporting
			local nearbyPlayers = false
			for _, ply in ipairs(player.GetAll()) do
				if ent:GetPos():DistToSqr(ply:GetPos()) <= 300 * 300 then
					nearbyPlayers = true
					break
				end
			end

			if nearbyPlayers then
				teleportRock(ent)
			end
		end)
	end,

	OnDamaged = function(ent, dmg)
		-- Teleport when damaged
		teleportRock(ent)
	end,

	OnDestroyed = function(ply, rock, inflictor)
		-- Cleanup timer
		timer.Remove("quantum_rock_" .. rock:EntIndex())
	end
})