module("ms", package.seeall)
Ores = Ores or {}

local TELEPORT_INTERVAL_MIN = 3  -- Minimum seconds between teleports
local TELEPORT_INTERVAL_MAX = 8  -- Maximum seconds between teleports
local TELEPORT_RANGE = 500      -- Maximum teleport distance
local QUANTUM_CHANCE = 2        -- 2% chance for a rock to be quantum

local function createTeslaBurst(pos, scale)
	local tesla = ents.Create("point_tesla")
	tesla:SetPos(pos)
	tesla:SetKeyValue("texture", "trails/electric.vmt")
	tesla:SetKeyValue("m_Color", "0 255 0")
	tesla:SetKeyValue("m_flRadius", tostring(60 * scale))
	tesla:SetKeyValue("interval_min", "0.1")
	tesla:SetKeyValue("interval_max", "0.2")
	tesla:SetKeyValue("beamcount_min", tostring(3 * scale))
	tesla:SetKeyValue("beamcount_max", tostring(6 * scale))
	tesla:SetKeyValue("thick_min", tostring(2 * scale))
	tesla:SetKeyValue("thick_max", tostring(4 * scale))
	tesla:SetKeyValue("lifetime_min", "0.1")
	tesla:SetKeyValue("lifetime_max", "0.2")
	tesla:Spawn()
	tesla:Activate()
	tesla:Fire("TurnOn", "", 0)
	tesla:Fire("DoSpark", "", 0)

	timer.Simple(0.3, function()
		if IsValid(tesla) then tesla:Remove() end
	end)
end

-- Helper function to find a valid teleport position
local function findTeleportPosition(rock)
	local originalPos = rock:WorldSpaceCenter()
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

		if tr.Hit and not tr.StartSolid and util.IsInWorld(tr.HitPos) and not tr.HitTexture:match("^TOOLS%/") then
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

	local oldPos = ent:WorldSpaceCenter()

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
		local detoniteRarity = Ores.GetOreRarityByName("Detonite")
		local rarity = ent.GetRarity and ent:GetRarity() or -1
		if detoniteRarity and rarity == detoniteRarity then return false end

		return true
	end,
	OnMarked = function(ent)
		if CLIENT then
			local startTime = CurTime()
			local heatwave = Material("sprites/heatwave")
			hook.Add("HUDPaint", ent, function()
				local center = ent:WorldSpaceCenter()
				local pos = center:ToScreen()
				if not pos.visible then return end

				local tr = LocalPlayer():GetEyeTrace()
				if tr.Entity ~= ent then return end

				local time = CurTime() - startTime
				local distortScale = math.sin(time * 2) * 0.4 + 1.25
				local mins, maxs = ent:GetModelBounds()
				local width = math.abs(maxs.x - mins.x)
				local height = math.abs(maxs.z - mins.z)
				local screenScale = math.max(0, 1000 / center:Distance(EyePos()))  -- Scale based on distance from camera
				local size = math.max(width, height) * screenScale * distortScale
				if size <= 0 then return end

				surface.SetDrawColor(0, 255, 255, 50)
				surface.SetMaterial(heatwave)
				surface.DrawTexturedRect(pos.x - size / 2, pos.y - size / 2, size, size)
			end)

			return
		end

		-- Keep existing trail with adjusted values
		util.SpriteTrail(ent, 0, Color(0, 255, 0, 150), false, 15, 0.5, 2, 1 / (15 + 1) * 0.5, "trails/laser.vmt")

		-- Add occasional energy burst effect
		timer.Create("quantum_burst_" .. ent:EntIndex(), math.random(2, 4), 0, function()
			if not IsValid(ent) then return end

			-- Add multiple tesla arcs at slightly offset positions
			for i = 1, 3 do
				local offset = VectorRand() * 50
				createTeslaBurst(ent:WorldSpaceCenter() + offset, math.Rand(1, 2))
			end

			-- Randomized energy sounds
			local sounds = {
				"ambient/energy/spark" .. math.random(1, 6) .. ".wav",
				"ambient/energy/zap" .. math.random(1, 3) .. ".wav"
			}

			ent:EmitSound(table.Random(sounds), 75, math.random(90, 110), 0.3)
		end)

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
				if ent:WorldSpaceCenter():DistToSqr(ply:GetPos()) <= 300 * 300 then
					nearbyPlayers = true
					break
				end
			end

			if nearbyPlayers then
				teleportRock(ent)
			end
		end)

		createQuantumDistortion(ent)
	end,

	OnDamaged = function(ent, dmg)
		if CLIENT then return end

		-- Teleport when damaged
		teleportRock(ent)
	end,

	OnDestroyed = function(ply, rock, inflictor)
		if CLIENT then return end

		-- Clean up timers
		timer.Remove("quantum_burst_" .. rock:EntIndex())
		timer.Remove("quantum_rock_" .. rock:EntIndex())

		-- Add destruction effect
		local effectdata = EffectData()
		effectdata:SetOrigin(rock:WorldSpaceCenter())
		effectdata:SetScale(2)
		util.Effect("cball_explode", effectdata)
	end
})