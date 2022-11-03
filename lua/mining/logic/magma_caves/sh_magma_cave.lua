module("ms", package.seeall)
Ores = Ores or {}

local NET_TAG = "mining_magma_overheat"

if SERVER then
	local MAX_DIST = 800
	local MAX_RETRIES = 5
	local LOCK_DURATION = 10 * 60
	local MIN_LAVA_LEVEL = -250
	local EVENT_COOLDOWN = 60 * 60 * 2 -- 2 hours
	local EVENT_DURATION = 180 -- 3 mins

	util.AddNetworkString(NET_TAG)

	local function updateLuaScreen(lock_duration, event_cooldown)
		if LuaScreen then
			local screen = LuaScreen.GetScreenEntities("magma_cave")[1]
			if IsValid(screen) then
				screen:SetMagmaCooldowns(lock_duration, event_cooldown)
			end
		end
	end

	local isOnGoing = false
	local endTime = -1
	local currentDuration = -1
	function Ores.MagmaOverheat(duration, isDebug)
		if isOnGoing then return end
		if not ms.GetTrigger then return end

		local trigger = ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end

		if not isDebug then
			Ores.SendChatMessage(player.GetAll(), 2, "Rare ores are now accessible in the magma caves! Be quick as the temperature is rising fast...")
		end

		trigger:ChangeLavaLevel(0)

		do
			local level = 0
			timer.Create("magma_cave_lava_overheat_preparation", 0.1, math.abs(MIN_LAVA_LEVEL), function()
				if not IsValid(trigger) then return end

				level = math.max(MIN_LAVA_LEVEL, level - 2)
				trigger:ChangeLavaLevel(level)

				if level == MIN_LAVA_LEVEL then
					timer.Remove("magma_cave_lava_overheat_preparation")
				end
			end)
		end

		local lavaPools = ents.FindByName("*magma_lavapool*")
		for _, lavaPool in ipairs(lavaPools) do
			local originalPos = lavaPool:GetSaveTable().m_vecPosition1
			for _ = 1, math.random(8, 10) do
				local rockPos = originalPos + Vector(math.random(-MAX_DIST, MAX_DIST), math.random(-MAX_DIST, MAX_DIST), 0)
				local retries = 0
				while retries < MAX_RETRIES and not util.IsInWorld(rockPos) do
					rockPos = originalPos + Vector(math.random(-MAX_DIST, MAX_DIST), math.random(-MAX_DIST, MAX_DIST), 0)
					retries = retries + 1
				end

				local rock = ents.Create("mining_rock")
				rock:SetRarity(4) -- platinum
				rock:SetSize(2)
				rock:SetPos(rockPos)
				rock:Spawn()
				rock:DropToFloor()

				timer.Simple(0.1, function()
					if not IsValid(rock) then return end

					rock:DropToFloor()
				end)

				if isDebug then rock.OnTakeDamage = function() end end
				SafeRemoveEntityDelayed(rock, duration)
			end
		end

		updateLuaScreen(0, EVENT_DURATION)

		currentDuration = duration
		isOnGoing = true
		endTime = CurTime() + duration
		timer.Simple(duration, function()
			isOnGoing = false
			endTime = -1
			currentDuration = -1

			if not IsValid(trigger) then return end

			for ent, _ in pairs(trigger:GetEntities()) do
				if IsValid(ent) and (ent:GetClass() == "mining_ore" or ent:GetClass() == "mining_rock") then
					SafeRemoveEntity(ent)
				end
			end

			if not isDebug then
				for ply, _ in pairs(trigger:GetPlayers()) do
					if not IsValid(ply) then continue end

					for rarity, _ in pairs(Ores.__R) do
						local count = Ores.GetPlayerOre(ply, rarity)
						if count <= 0 then continue end

						Ores.TakePlayerOre(ply, rarity, math.ceil(count / 4 * 3))
					end

					Ores.SendChatMessage(ply, 2, "You didn't manage to get out in time! Some of your ores were melted in the hot magma of the caves...")
				end

				-- respawn people stuck in the volcano cave
				timer.Simple(2, function()
					if not IsValid(trigger) then return end

					for ply, _ in pairs(trigger:GetPlayers()) do
						ply:Spawn()
					end
				end)

				trigger:LockCave()
			end

			timer.Simple(isDebug and 0 or LOCK_DURATION, function()
				if not IsValid(trigger) then return end

				trigger:ChangeLavaLevel(0)
				trigger:UnlockCave()
			end)

			updateLuaScreen(LOCK_DURATION, EVENT_COOLDOWN)
		end)

		-- raise lava slighty before end of event
		timer.Simple(duration - 5, function()
			local level = MIN_LAVA_LEVEL
			timer.Create("magma_cave_lava_overheat_preparation", 0.1, math.abs(MIN_LAVA_LEVEL), function()
				if not IsValid(trigger) then return end

				level = math.min(500, level + 4)
				trigger:ChangeLavaLevel(level)

				if level == 500 then
					timer.Remove("magma_cave_lava_overheat_preparation")
				end
			end)
		end)

		net.Start(NET_TAG)
		net.WriteInt(duration, 32)
		net.Broadcast()
	end

	hook.Add("PlayerFullyConnected", "magma_cave", function(ply)
		if isOnGoing and endTime > -1 then
			net.Start(NET_TAG)
			net.WriteInt(endTime - CurTime(), 32)
			net.Send(ply)
		end
	end)

	local fireEnt
	local function getFireEntity()
		if IsValid(fireEnt) then return fireEnt end

		fireEnt = ents.Create("env_fire")
		fireEnt:Spawn()

		return fireEnt
	end

	local nextThink = 0
	hook.Add("Think", "magma_cave", function()
		if not isOnGoing then return end

		local trigger = ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end

		if CurTime() <= nextThink then return end

		nextThink = CurTime() + 5

		local perc = 1 - ((endTime - CurTime()) / currentDuration)
		local lavaPools = ents.FindByName("*magma_lavapool*")
		for _, lavaPool in ipairs(lavaPools) do
			local originalPos = lavaPool:GetSaveTable().m_vecPosition1
			util.ScreenShake(originalPos, 5 + 20 * perc, 20, 5 * 3, 2000)
		end

		local fireAttacker = getFireEntity()
		for ply, _ in pairs(trigger:GetPlayers()) do
			if math.random() < 0.05 and ms.Ores.MineCollapse then
				ms.Ores.MineCollapse(ply, endTime - CurTime(), {
					{ Rarity = 4, Chance = 30 },
					{ Rarity = 3, Chance = 70 },
				})
			end

			if perc >= 0.65 then
				ply:Ignite(5, 1000)
			end

			if perc >= 0.9 then
				local dmgInfo = DamageInfo()
				dmgInfo:SetDamage(5)
				dmgInfo:SetDamageType(DMG_BURN)
				dmgInfo:SetAttacker(fireAttacker)
				dmgInfo:SetInflictor(fireAttacker)

				ply:TakeDamageInfo(dmgInfo)
			end
		end
	end)

	local METAL_STRESS_SOUNDS = {
		"ambient/materials/metal_stress1.wav",
		"ambient/materials/metal_stress2.wav",
		"ambient/materials/metal_stress4.wav",
		"ambient/materials/metal_stress5.wav",
		"ambient/materials/rustypipes3.wav"
	}

	local VALVE_SENTENCES = {
		"It seems to regulate the lava flow of the caves",
		"It smells like burnt rust inside",
		"Lava seems to be dripping from it",
		"It looks dangerous",
	}

	local activatedValves = {}
	hook.Add("PlayerUse", "magma_cave_valve", function(ply, ent)
		if not ent.VolcanoValve then return end
		if isOnGoing then return end
		if ent.NextUse and CurTime() < ent.NextUse then return end

		ent.NextUse = CurTime() + 1

		if activatedValves[ent] then
			Ores.SendChatMessage(ply, 1, ("This old valve seems stuck. %s..."):format(VALVE_SENTENCES[math.random(#VALVE_SENTENCES)]))
			return
		end

		local trigger = ms and ms.GetTrigger and ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end
		if trigger.CaveLocked then return end

		activatedValves[ent] = true

		ent:EmitSound(METAL_STRESS_SOUNDS[math.random(#METAL_STRESS_SOUNDS)], 100)
		ent:EmitSound("ambient/atmosphere/terrain_rumble1.wav")

		local activatedValveCount, totalValveCount = table.Count(activatedValves), #ents.FindByClass("magma_cave_valve")
		Ores.SendChatMessage(ply, 1, ("You've activated an old valve. %s [%d/%d]..."):format(VALVE_SENTENCES[math.random(#VALVE_SENTENCES)], activatedValveCount, totalValveCount))

		if activatedValveCount >= totalValveCount then
			Ores.MagmaOverheat(EVENT_DURATION, false)

			timer.Simple(EVENT_COOLDOWN, function()
				activatedValves = {}
			end)
		end
	end)

	local VALVE_DATA = {
		{
			Position = Vector (1105, -3187, -38),
			Angles = Angle (90, -20, 180)
		},
		{
			Position = Vector (2247, 879, -64),
			Angles = Angle (90, 180, 180)
		},
		{
			Position = Vector (-1058, -2252, -22),
			Angles = Angle (90, 180, 180),
		}
	}

	local function spawnMagmaCaveEnts()
		for _, existingValve in ipairs(ents.FindByClass("magma_cave_valve")) do
			SafeRemoveEntity(existingValve)
		end

		local trigger = ms and ms.GetTrigger and ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end

		local basePos = trigger:GetPos()
		for _, data in ipairs(VALVE_DATA) do
			local pos = basePos - data.Position
			local valve = ents.Create("magma_cave_valve")
			valve:SetPos(pos)
			valve:SetAngles(data.Angles)
			valve:Spawn()
		end

		if LuaScreen and #LuaScreen.GetScreenEntities("magma_cave") == 0 then
			local gates = ents.FindByName("*magma_gate*")
			if #gates < 2 then return end

			local diff = gates[1]:GetPos() - gates[2]:GetPos()
			local gateCenterPos = (gates[1]:GetPos() - diff / 2) + gates[1]:GetForward() * 25 + gates[1]:GetUp() * 125

			local succ, _ = pcall(LuaScreen.LoadScreen, "magma_cave")
			if succ then
				LuaScreen.Create("magma_cave", gateCenterPos, Angle(0, 0, 0))
			end
		end
	end

	-- this needs to be cached because we are spawning it ourselves
	hook.Add("PopulateLuaScreens", "magma_cave_luascreen", function() LuaScreen.Precache("magma_cave") end)

	hook.Add("InitPostEntity", "magma_cave_valves", function()
		timer.Simple(5, spawnMagmaCaveEnts) -- too early otherwise
	end)

	hook.Add("PostCleanupMap", "magma_cave_valves", spawnMagmaCaveEnts)

	-- delete rocks that are not reachable
	hook.Add("OnEntityWaterLevelChanged", "magma_cave_ore_lava_check", function(ent, oldLevel, newLevel)
		if not ms.GetTrigger then return end
		if newLevel == 0 then return end

		local className = ent:GetClass()
		if className ~= "mining_rock" and className ~= "mining_ore" then return end

		local trigger = ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end
		if not trigger:GetEntities()[ent] then return end

		SafeRemoveEntity(ent)
	end)

	hook.Add("PlayerTriggeredMineCollapse", "magma_cave", function(ply, _, _, isDefaultRarityData)
		if isDefaultRarityData and ply.IsInZone and ply:IsInZone("volcano") then
			return {
				{ Rarity = 0, Chance = 100 },
			}
		end
	end)
end

if CLIENT then
	local COUNTDOWN_URL = "https://dl.dropboxusercontent.com/s/sotoqttc61w9ei2/volcano_countdown.ogg" -- change later
	local WIDTH = 50
	local HEIGHT = 600
	local BASE_POS_X, BASE_POS_Y = ScrW() - 100, 50
	local CURSOR_SIZE = 50

	local LAVA_MAT = Material("metastruct_4/rock_lava01a_water")
	--local FIRE_ICON = Material("icon16/fire.png")
	local WARNING_ICON = Material("icon16/error.png")

	local function playVolcanoMusic(callback)
		if not file.Exists("meta_volcano_countdown.ogg", "DATA") then
			http.Fetch(COUNTDOWN_URL, function(data)
				if not data or #data == 0 then
					callback()
					return
				end

				file.Write("meta_volcano_countdown.ogg", data)
				sound.PlayFile("data/meta_volcano_countdown.ogg", "noblock", callback)
			end, function()
				callback()
			end)
		else
			sound.PlayFile("data/meta_volcano_countdown.ogg", "noblock", callback)
		end
	end

	local duration = 1
	local isInVolcano = false
	local startTime = -1
	local function draw_hud()
		if not isInVolcano then return end

		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(BASE_POS_X - 10, BASE_POS_Y - 10, WIDTH + 20, HEIGHT + 20, 5)

		local perc = (CurTime() - startTime) / duration
		local yPos = math.max(BASE_POS_Y, BASE_POS_Y + (HEIGHT - CURSOR_SIZE) - (HEIGHT * perc))
		local temperature = math.ceil(25 + 75 * perc)

		render.SetScissorRect(BASE_POS_X, yPos + CURSOR_SIZE, WIDTH + BASE_POS_X, HEIGHT + BASE_POS_Y, true)
			surface.SetMaterial(LAVA_MAT)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(BASE_POS_X, BASE_POS_Y, HEIGHT * 1.5, HEIGHT * 1.5)
		render.SetScissorRect(0, 0, 0, 0, false)

		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawOutlinedRect(BASE_POS_X, BASE_POS_Y, WIDTH, HEIGHT, 4)

		surface.SetDrawColor(255, 0, 0,  math.max(0, -50 + 200 * perc))
		surface.DrawRect(BASE_POS_X, BASE_POS_Y + yPos, WIDTH, HEIGHT - yPos)

		surface.SetDrawColor(255, math.max(0, 155 * (1 - perc)), 0, 255)
		surface.DrawOutlinedRect(BASE_POS_X + math.random(-5, 5) * perc, yPos + math.random(-5, 5) * perc, WIDTH, 50, 2)

		surface.SetTextColor(255, math.max(0, 155 * (1 - perc)), 0, 255)
		surface.SetFont("DermaLarge")
		surface.SetTextPos(BASE_POS_X + 5, yPos + 10)
		surface.DrawText(temperature .. "°")

		if perc >= 0.75 then
			surface.SetMaterial(WARNING_ICON)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(BASE_POS_X - WIDTH + math.random(-5, 5) * perc, yPos + 10 + math.random(-5, 5) * perc, 32, 32)
		end
	end

	local audio
	net.Receive(NET_TAG, function()
		duration = net.ReadInt(32)
		startTime = CurTime()

		if isInVolcano then
			playVolcanoMusic(function(station)
				if not IsValid(station) then return end

				station:SetTime(CurTime() - startTime)
				station:Play()

				audio = station
			end)
		end

		timer.Simple(duration, function()
			hook.Remove("HUDPaint", "magma_cave")
			startTime = -1
		end)

		hook.Add("HUDPaint", "magma_cave", draw_hud)
	end)

	hook.Add("lua_trigger", "magma_cave", function(trigger_name, isEntering)
		if trigger_name ~= "volcano" then return end
		isInVolcano = isEntering

		-- put the music back
		if startTime > -1 then
			if isEntering then
				if not IsValid(audio) then
					playVolcanoMusic(function(station)
						if not IsValid(station) then return end

						station:SetTime(CurTime() - startTime)
						station:Play()

						audio = station
					end)
				else
					audio:SetTime(CurTime() - startTime)
					audio:Play()
				end
			else
				if audio then
					audio:Stop()
				end
			end
		end
	end)
end
