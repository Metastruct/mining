module("ms", package.seeall)
Ores = Ores or {}

local NET_TAG = "mining_magma_overheat"

if SERVER then
	local MAX_DIST = 800
	local MAX_RETRIES = 5
	local LOCK_DURATION = 10 * 60
	local MIN_LAVA_LEVEL = -220
	local EVENT_COOLDOWN = 60 * 60 * 2 -- 2 hours
	local EVENT_DURATION = 180 -- 3 mins

	util.AddNetworkString(NET_TAG)

	local on_going = false
	local end_time = -1
	local cur_duration = -1
	function Ores.MagmaOverheat(duration, is_debug)
		if on_going then return end
		if not ms.GetTrigger then return end

		local trigger = ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end

		if not is_debug then
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

		local lava_pools = ents.FindByName("*magma_lavapool*")
		for _, lava_pool in ipairs(lava_pools) do
			local original_pos = lava_pool:GetSaveTable().m_vecPosition1
			for _ = 1, math.random(8, 10) do
				local rock_pos = original_pos + Vector(math.random(-MAX_DIST, MAX_DIST), math.random(-MAX_DIST, MAX_DIST), 0)
				local retries = 0
				while retries < MAX_RETRIES and not util.IsInWorld(rock_pos) do
					rock_pos = original_pos + Vector(math.random(-MAX_DIST, MAX_DIST), math.random(-MAX_DIST, MAX_DIST), 0)
				end

				local rock = ents.Create("mining_rock")
				rock:SetRarity(4) -- platinum
				rock:SetSize(2)
				rock:SetPos(rock_pos)
				rock:Spawn()
				rock:DropToFloor()

				if is_debug then rock.OnTakeDamage = function() end end
				SafeRemoveEntityDelayed(rock, duration)
			end
		end

		cur_duration = duration
		on_going = true
		end_time = CurTime() + duration
		timer.Simple(duration, function()
			on_going = false
			end_time = -1
			cur_duration = -1

			if not IsValid(trigger) then return end

			for ent, _ in pairs(trigger:GetEntities()) do
				if ent:GetClass():match("^mining") then
					SafeRemoveEntity(ent)
				end
			end

			if not is_debug then
				for ply, _ in pairs(trigger:GetPlayers()) do
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

			timer.Simple(is_debug and 0 or LOCK_DURATION, function()
				if not IsValid(trigger) then return end

				trigger:ChangeLavaLevel(0)
				trigger:UnlockCave()
			end)
		end)

		-- raise lava slighty before end of event
		timer.Simple(duration - 5, function()
			local level = MIN_LAVA_LEVEL
			timer.Create("magma_cave_lava_overheat_preparation", 0.1, math.abs(MIN_LAVA_LEVEL), function()
				if not IsValid(trigger) then return end

				level = math.min(500, level + 4)
				trigger:ChangeLavaLevel(level)

				if level == MIN_LAVA_LEVEL then
					timer.Remove("magma_cave_lava_overheat_preparation")
				end
			end)
		end)

		net.Start(NET_TAG)
		net.WriteInt(duration, 32)
		net.Broadcast()
	end

	hook.Add("PlayerFullyConnected", "magma_cave", function(ply)
		if on_going and end_time > -1 then
			net.Start(NET_TAG)
			net.WriteInt(end_time - CurTime(), 32)
			net.Send(ply)
		end
	end)

	local fire_ent
	local function get_fire_ent()
		if IsValid(fire_ent) then return fire_ent end

		fire_ent = ents.Create("env_fire")
		fire_ent:Spawn()

		return fire_ent
	end

	local next_think = 0
	hook.Add("Think", "magma_cave", function()
		if not on_going then return end

		local trigger = ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end

		if CurTime() <= next_think then return end

		next_think = CurTime() + 5

		local perc = 1 - ((end_time - CurTime()) / cur_duration)
		local lava_pools = ents.FindByName("*magma_lavapool*")
		for _, lava_pool in ipairs(lava_pools) do
			local original_pos = lava_pool:GetSaveTable().m_vecPosition1
			util.ScreenShake(original_pos, 5 + 20 * perc, 20, 5 * 3, 2000)
		end

		local fire_atck = get_fire_ent()
		for ply, _ in pairs(trigger:GetPlayers()) do
			if math.random() < 0.05 and ms.Ores.MineCollapse then
				ms.Ores.MineCollapse(ply, end_time - CurTime())
			end

			if perc >= 0.65 then
				ply:Ignite(5, 1000)
			end

			if perc >= 0.9 then
				local dmg_info = DamageInfo()
				dmg_info:SetDamage(5)
				dmg_info:SetDamageType(DMG_BURN)
				dmg_info:SetAttacker(fire_atck)
				dmg_info:SetInflictor(fire_atck)

				ply:TakeDamageInfo(dmg_info)
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

	local activated_valves = {}
	hook.Add("PlayerUse", "magma_cave_valve", function(ply, ent)
		if not ent.VolcanoValve then return end
		if on_going then return end
		if ent.NextUse and CurTime() < ent.NextUse then return end

		ent.NextUse = CurTime() + 1

		if activated_valves[ent] then 
			Ores.SendChatMessage(ply, 1, ("This old valve seems stuck. %s..."):format(VALVE_SENTENCES[math.random(#VALVE_SENTENCES)]))
			return 
		end

		local trigger = ms and ms.GetTrigger and ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end
		if trigger.CaveLocked then return end

		activated_valves[ent] = true

		ent:EmitSound(METAL_STRESS_SOUNDS[math.random(#METAL_STRESS_SOUNDS)], 100)
		ent:EmitSound("ambient/atmosphere/terrain_rumble1.wav")

		local activated_valve_count, total_valve_count = table.Count(activated_valves), #ents.FindByClass("magma_cave_valve")
		Ores.SendChatMessage(ply, 1, ("You've activated an old valve. %s [%d/%d]..."):format(VALVE_SENTENCES[math.random(#VALVE_SENTENCES)], activated_valve_count, total_valve_count))

		if activated_valve_count >= total_valve_count then
			Ores.MagmaOverheat(EVENT_DURATION, false)

			if LuaScreen then
				local screen = LuaScreen.GetScreenEntities("magma_cave")[1]
				if IsValid(screen) then
					screen:SetMagmaCooldowns(LOCK_DURATION, EVENT_COOLDOWN)
				end
			end

			timer.Simple(EVENT_COOLDOWN, function()
				activated_valves = {}
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

	local function spawn_valves()
		for _, existing_vale in ipairs(ents.FindByClass("magma_cave_valve")) do
			SafeRemoveEntity(existing_vale)
		end

		local trigger = ms and ms.GetTrigger and ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end

		local base_pos = trigger:GetPos()
		for _, data in ipairs(VALVE_DATA) do
			local pos = base_pos - data.Position
			local valve = ents.Create("magma_cave_valve")
			valve:SetPos(pos)
			valve:SetAngles(data.Angles)
			valve:Spawn()
		end

		if LuaScreen and #LuaScreen.GetScreenEntities("magma_cave") == 0 then
			local gates = ents.FindByName("*magma_gate*")
			local diff = gates[1]:GetPos() - gates[2]:GetPos()
			local gate_center_pos = (gates[1]:GetPos() - diff / 2) + gates[1]:GetForward() * 25 + gates[1]:GetUp() * 125

			local succ, _ = pcall(LuaScreen.LoadScreen, "magma_cave")
            if succ then
				LuaScreen.Create("magma_cave", gate_center_pos, Angle(0, 0, 0))
			end
		end
	end

	hook.Add("InitPostEntity", "magma_cave_valves", function()
		timer.Simple(5, spawn_valves) -- too early otherwise
	end)
	
	hook.Add("PostCleanupMap", "magma_cave_valves", spawn_valves)
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

	local function get_volcano_music(callback)
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
	local in_volcano = false
	local start_time = -1
	local function draw_hud()
		if not in_volcano then return end

		surface.SetDrawColor(0, 0, 0, 200)
		surface.DrawRect(BASE_POS_X - 10, BASE_POS_Y - 10, WIDTH + 20, HEIGHT + 20, 5)

		local perc = (CurTime() - start_time) / duration
		local y_pos = math.max(BASE_POS_Y, BASE_POS_Y + (HEIGHT - CURSOR_SIZE) - (HEIGHT * perc))
		local temperature = math.ceil(25 + 75 * perc)

		render.SetScissorRect(BASE_POS_X, y_pos + CURSOR_SIZE, WIDTH + BASE_POS_X, HEIGHT + BASE_POS_Y, true)
			surface.SetMaterial(LAVA_MAT)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(BASE_POS_X, BASE_POS_Y, HEIGHT * 1.5, HEIGHT * 1.5)
		render.SetScissorRect(0, 0, 0, 0, false)

		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawOutlinedRect(BASE_POS_X, BASE_POS_Y, WIDTH, HEIGHT, 4)

		surface.SetDrawColor(255, 0, 0,  math.max(0, -50 + 200 * perc))
		surface.DrawRect(BASE_POS_X, BASE_POS_Y + y_pos, WIDTH, HEIGHT - y_pos)

		surface.SetDrawColor(255, math.max(0, 155 * (1 - perc)), 0, 255)
		surface.DrawOutlinedRect(BASE_POS_X + math.random(-5, 5) * perc, y_pos + math.random(-5, 5) * perc, WIDTH, 50, 2)

		surface.SetTextColor(255, math.max(0, 155 * (1 - perc)), 0, 255)
		surface.SetFont("DermaLarge")
		surface.SetTextPos(BASE_POS_X + 5, y_pos + 10)
		surface.DrawText(temperature .. "°")

		if perc >= 0.75 then
			surface.SetMaterial(WARNING_ICON)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(BASE_POS_X - WIDTH + math.random(-5, 5) * perc, y_pos + 10 + math.random(-5, 5) * perc, 32, 32)
		end
	end

	local audio
	net.Receive(NET_TAG, function()
		duration = net.ReadInt(32)
		start_time = CurTime()

		if in_volcano then
			get_volcano_music(function(station)
				if not IsValid(station) then return end

				station:SetTime(CurTime() - start_time)
				station:Play()

				audio = station
			end)
		end

		timer.Simple(duration, function()
			hook.Remove("HUDPaint", "magma_cave")
			start_time = -1
		end)

		hook.Add("HUDPaint", "magma_cave", draw_hud)
	end)

	hook.Add("lua_trigger", "magma_cave", function(trigger_name, is_entering)
		if trigger_name ~= "volcano" then return end
		in_volcano = is_entering

		-- put the music back
		if start_time > -1 then
			if is_entering then
				if not IsValid(audio) then
					get_volcano_music(function(station)
						if not IsValid(station) then return end

						station:SetTime(CurTime() - start_time)
						station:Play()

						audio = station
					end)
				else
					audio:SetTime(CurTime() - start_time)
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
