local DETONITE_RARITY = 19

local function explode(ent)
	local effectData = EffectData()
	effectData:SetOrigin(ent:WorldSpaceCenter())

	util.Effect("Explosion", effectData, false, true)
	ent:Ignite(10, 0)

	util.BlastDamage(ent, ent, ent:WorldSpaceCenter(), 50, 10)
end

local rockCount = 0
hook.Add("EntityRemoved", "miningDetonite", function(ent)
	if ent:GetClass() == "mining_rock" and ent:GetRarity() == DETONITE_RARITY then
		explode(ent)

		rockCount = math.max(0, rockCount - 1)
	end
end)

hook.Add("Move", "miningDetonite", function(ply, data)
	local speed = data:GetVelocity():Length()
	local detoniteAmount = ms.Ores.GetPlayerOre(ply, DETONITE_RARITY)
	if speed > 299 and detoniteAmount > 0 then
		explode(ply)
		ms.Ores.TakePlayerOre(ply, DETONITE_RARITY, detoniteAmount)
	end
end)

hook.Add("EntityTakeDamage", "miningDetonite", function(ent)
	if ent:IsPlayer() and not ent.MiningDetoniteIgnore and not ent:IsOnFire() then
		local detoniteAmount = ms.Ores.GetPlayerOre(ent, DETONITE_RARITY)
		if detoniteAmount > 0 then
			ent.MiningDetoniteIgnore = true

			explode(ent)
			ms.Ores.TakePlayerOre(ent, DETONITE_RARITY, detoniteAmount)

			timer.Simple(4, function()
				if not IsValid(ent) then return end

				ent.MiningDetoniteIgnore = nil
			end)
		end
	end
end)

hook.Add("CanPlyTeleport", "miningDetonite", function(ply)
	local detoniteAmount = ms.Ores.GetPlayerOre(ply, DETONITE_RARITY)
	if detoniteAmount > 0 then
		explode(ply)
		ms.Ores.TakePlayerOre(ply, DETONITE_RARITY, detoniteAmount)
	end
end)

hook.Add("CanPlayerTimescale", "miningDetonite", function(ply)
	local detoniteAmount = ms.Ores.GetPlayerOre(ply, DETONITE_RARITY)
	if detoniteAmount > 0 then return false end
end)

hook.Add("PlayerReceivedOre", "miningDetonite", function(ply, amount, rarity)
	if rarity ~= DETONITE_RARITY then return end

	ply:SetLaggedMovementValue(1)

	if ms.Ores.GetPlayerOre(ply, DETONITE_RARITY) >= 5 then return end -- above 5 block re-creating the timer so you can't wait endlessly for detonite

	local timerName = ("mining_detonite_[%d]"):format(ply:EntIndex())
	timer.Create(timerName, 30, 1, function() -- timed just right normally... 30s from a lava lake to the npc
		timer.Create(timerName, 2, 0, function()
			local detoniteAmount = ms.Ores.GetPlayerOre(ply, DETONITE_RARITY)
			if detoniteAmount > 0 then
				ply:EmitSound("common/wpn_denyselect.wav", 100)
				ply:EmitSound("common/warning.wav", 100)
				ms.Ores.TakePlayerOre(ply, DETONITE_RARITY, 1)
				return
			end

			timer.Remove(timerName)
		end)
	end)
end)

local function spawnDetonite(tr)
	local rock = ents.Create("mining_rock")
	rock:SetPos(tr.HitPos + tr.HitNormal * 10)
	rock:SetSize(math.random() < 0.33 and 2 or 1)
	rock:SetRarity(DETONITE_RARITY)
	rock:Spawn()
	rock.OriginalRock = true
	rock.OnTakeDamage = function() SafeRemoveEntity(rock) end

	rock:AddEffects(EF_ITEM_BLINK)

	local snd = CreateSound(rock, ")ambient/levels/labs/teleport_winddown1.wav")
	snd:SetDSP(16)
	snd:SetSoundLevel(80)
	snd:ChangePitch(math.random(150, 180))
	snd:Play()

	timer.Simple(0.5, function()
		if not IsValid(rock) then return end
		rock:RemoveEffects(EF_ITEM_BLINK)
	end)

	local maxs = rock:OBBMaxs() / 2
	local timerName = ("mining_detonite_[%d]"):format(rock:EntIndex())
	timer.Create(timerName, 4, 0, function()
		if not IsValid(rock) then
			timer.Remove(timerName)
			return
		end

		local drop = ents.Create("mining_ore")
		drop:SetRarity(DETONITE_RARITY)
		drop:SetPos(rock:GetPos() - Vector(math.random(-maxs.x, maxs.x), math.random(-maxs.y, maxs.y), maxs.z + 25))
		drop:Spawn()
		drop:PhysWake()

		function drop:PhysicsCollide(data)
			if data.OurOldVelocity:Length2D() > 300 then
				if self:WaterLevel() == 0 then
					explode(self)
				end

				SafeRemoveEntity(self)
			end
		end

		SafeRemoveEntityDelayed(drop, 8)
	end)

	rockCount = rockCount + 1
end

local MAX_TRIES = 5
local MAX_DETONITE_ROCKS = 10
local function generateDetonite()
	if rockCount >= MAX_DETONITE_ROCKS then return end

	local lavaPools = ents.FindByName("*magma_lavapool*")
	local lavaPool = lavaPools[math.random(#lavaPools)]
	local maxs = lavaPool:OBBMaxs() / 2
	local origin = lavaPool:GetPos() + Vector(math.random(-maxs.x, maxs.y), math.random(-maxs.y, maxs.y), 10)
	local trace = util.TraceLine({
		start = origin,
		endpos = origin + Vector(0, 0, 10000),
		mask = MASK_SOLID_BRUSHONLY,
	})

	local tries = 0
	while not util.IsInWorld(trace.HitPos) and tries < MAX_TRIES do
		origin = lavaPool:GetPos() + Vector(math.random(-maxs.x, maxs.y), math.random(-maxs.y, maxs.y), 50)
		trace = util.TraceLine({
			start = origin,
			endpos = origin + Vector(0, 0, 10000),
			mask = MASK_SOLID_BRUSHONLY,
		})

		tries = tries + 1
	end

	if not util.IsInWorld(trace.HitPos) then return end

	spawnDetonite(trace)
end

timer.Create("mining_detonite_spawning", 5, 0, generateDetonite)
