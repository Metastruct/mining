local ARGONITE_RARITY = 18
local ARGONITE_MULTIPLIER = 1000
local ARGONITE_EXTRACTION_COUNT_PER_DAY = 8
local NET_TAG = "ms.Ores.ArgoniteExtractorMenu"

ms.Ores.__R[ARGONITE_RARITY] = {
	Health = 40,
	Hidden = false,
	HudColor = Color(255, 20, 50),
	Name = "Argonite",
	PhysicalColor = Color(255, 20, 50),
	SparkleInterval = 0.3,
	Worth = 1,
}

local function computeMaxArgoniteExtractionCount(ply)
	return ARGONITE_EXTRACTION_COUNT_PER_DAY + math.ceil((ARGONITE_EXTRACTION_COUNT_PER_DAY / 100) * ply:GetNWInt("ms.Ores.ToxicResistance", 0))
end

if CLIENT then
	local BACKGROUND_COLOR = Color(0, 0, 0, 127)
	local DEFAULT_COLOR = Color(205, 205, 205)
	local GREEN_COLOR = Color(127, 192, 127)
	local POINTS_ICON = Material("icon16/contrast_low.png")
	local MSA_MAT = Material("msa/msa_logo_1_unlitgeneric_2")
	MSA_MAT:SetFloat("$color", 1)
	MSA_MAT:SetFloat("$color2", 1)
	MSA_MAT:SetFloat("$alpha", 0.033)
	MSA_MAT:SetInt("$additive", 1)
	MSA_MAT:Recompute()

	local function drawTitleText(txt, x, y, font, shadowColor, color, dist)
		surface.SetTextPos(x + dist, y + dist)
		surface.SetTextColor(shadowColor)
		surface.DrawText(txt)
		surface.SetTextPos(x - dist, y)
		surface.SetTextColor(color)
		surface.DrawText(txt)
	end

	local function drawOutlinedRect(x, y, w, h, outlineColor, color)
		x, y, w, h = math.Round(x), math.Round(y), math.Round(w), math.Round(h)

		surface.SetDrawColor(outlineColor)
		surface.DrawRect(x, y + 1, 1, h - 2) -- left
		surface.DrawRect(x + 1, y, w - 2, 1) -- top
		surface.DrawRect(w - 1, y + 1, 1, h - 2) -- right
		surface.DrawRect(x + 1, y + h - 1, w - 2, 1) -- bottom
		surface.SetDrawColor(color)
		surface.DrawRect(x + 1, y + 1, w - 2, h - 2)
	end

	local function drawButton(self, w, h)
		drawOutlinedRect(0, 0, w, h, Color(0, 0, 0, 127), self:IsDown() and Color(0, 127, 255) or (self:IsHovered() and Color(205, 205, 205) or Color(192, 192, 192)))
		drawOutlinedRect(0, 0 + h * 0.5, w, h, Color(0, 0, 0, 0), Color(0, 0, 0, 32))
	end

	local function drawPanelList(self, w, h)
		drawOutlinedRect(0, 0, w, h, Color(0, 0, 0, 192), Color(0, 0, 0, 127))
	end

	surface.CreateFont("msOresExtractorTitle", {
		font = "Tahoma",
		size = 24,
		weight = 800
	})

	local function showExtractorMenu(npc, remaining)
		local frame = vgui.Create("DFrame")
		frame:SetSize(600, 400)
		frame:SetTitle("Argonite Extractor")
		frame:Center()
		frame:MakePopup()
		frame:SetDraggable(false)
		frame:SetSizable(false)
		frame.btnClose:SetFont("marlett")
		frame.btnClose:SetText("r")
		frame.btnClose:SetSkin("Default")
		frame.lblTitle:Hide()
		frame.btnMaxim:Hide()
		frame.btnMinim:Hide()

		function frame.btnClose:Paint(w, h)
			drawButton(self, w, h)
		end

		function frame:Paint(w, h)
			drawOutlinedRect(0, 0, w, h, Color(24, 24, 24), Color(86, 86, 86))

			surface.SetDrawColor(Color(0, 0, 0, 127))
			surface.DrawRect(1, 1, w - 2, 32)
			surface.SetFont("msOresExtractorTitle")
			local txt = self.lblTitle:GetText()
			local txtW = surface.GetTextSize(txt)
			drawTitleText(txt, w * 0.5 - txtW * 0.5, 4, "msOresExtractorTitle", Color(0, 0, 0, 127), Color(192, 192, 192), 2)
		end

		local topPanel = frame:Add("DPanel")
		topPanel:Dock(TOP)
		topPanel:DockMargin(0, 8, 0, 4)
		topPanel:DockPadding(4, 0, 0, 0)
		topPanel:SetTall(56)

		function topPanel:Paint(w, h)
			drawPanelList(self, w, h)
			surface.SetMaterial(MSA_MAT)
			surface.DrawTexturedRect(w / 2 - 256 / 2, h / 2 - 256 / 2, 256, 256)
		end

		local npcAvatarPanel = topPanel:Add("DModelPanel")
		npcAvatarPanel:Dock(RIGHT)
		npcAvatarPanel:SetSize(56, 56)
		npcAvatarPanel:SetModel(IsValid(npc) and npc:GetModel() or "models/humans/group01/male_07.mdl")

		local oldPaint = npcAvatarPanel.Paint
		function npcAvatarPanel:Paint(w, h)
			drawPanelList(self, w, h)
			oldPaint(self, w, h)
		end

		local boneNumber = npcAvatarPanel.Entity:LookupBone("ValveBiped.Bip01_Head1")
		if boneNumber then
			local headPos = npcAvatarPanel.Entity:GetBonePosition(boneNumber)
			if headPos then
				npcAvatarPanel:SetLookAt(headPos)
				npcAvatarPanel:SetCamPos(headPos - Vector(-13, 0, 0))
			end
		end

		function npcAvatarPanel:LayoutEntity(ent)
			ent:SetSequence(ent:LookupSequence("idle_subtle"))
			self:RunAnimation()
		end

		local introPanel = topPanel:Add("DLabel")
		introPanel:Dock(FILL)
		introPanel:SetWrap(true)
		introPanel:SetText("Hi, I'm an Argonite extractor. If you get me some, I'll give in a good word to the miner. Be warned though, Argonite is very volatile and toxic. We use it to power the energy core in the reactor.")

		local sides = frame:Add("DHorizontalDivider")
		sides:Dock(FILL)
		sides.StartGrab = function() end

		local oresPanel = sides:Add("DPanel")
		oresPanel:SetWide(frame:GetWide() / 2)

		function oresPanel:Paint(w, h)
			drawPanelList(self, w, h)

			local oreData = ms.Ores.__R[ARGONITE_RARITY]
			local amount = ms.Ores.GetPlayerOre(LocalPlayer(), ARGONITE_RARITY)
			local txt = amount .. " " .. oreData.Name .. " Ore(s)"
			surface.SetFont("msOresExtractorTitle")
			local txtW, txtH = surface.GetTextSize(txt)
			local y = 0
			surface.SetDrawColor(BACKGROUND_COLOR)
			surface.DrawRect(0, y, w, h)
			surface.SetTextPos(4, y + 4)
			surface.SetTextColor(amount > 0 and oreData.HudColor or DEFAULT_COLOR)
			surface.DrawText(txt)

			if amount > 0 then
				surface.SetFont("DermaDefault")
				txt = "+ " .. string.Comma(math.ceil((oreData.Worth * amount) * ARGONITE_MULTIPLIER))
				txtW, txtH = surface.GetTextSize(txt)
				surface.SetTextPos(w - 4 - txtW, txtH)
				surface.SetTextColor(GREEN_COLOR)
				surface.DrawText(txt)
			end
		end

		local giveBtn = oresPanel:Add("DButton")
		giveBtn:SetSize(100, 25)
		giveBtn:Dock(BOTTOM)

		local perc = (remaining / computeMaxArgoniteExtractionCount(LocalPlayer())) * 100
		giveBtn:SetText(("Give Ore(s) (%d%% TOXIC RES. remanining today)"):format(perc))
		giveBtn:SetSkin("Default")
		giveBtn:SetEnabled(remaining > 0 and ms.Ores.GetPlayerOre(LocalPlayer(), ARGONITE_RARITY) > 0)

		function giveBtn:Paint(w, h)
			drawButton(self, w, h)
		end

		function giveBtn:DoClick()
			net.Start(NET_TAG)
			net.WriteString("GiveOres")
			net.SendToServer()

			remaining = remaining - 1
			local newPerc = (remaining / computeMaxArgoniteExtractionCount(LocalPlayer())) * 100
			giveBtn:SetText(("Give Ore(s) (%d%% TOXIC RES. remanining today)"):format(newPerc))
			giveBtn:SetEnabled(remaining > 0)
		end

		local upgradePanel = sides:Add("DPanel")

		function upgradePanel:Paint(w, h)
			drawPanelList(self, w, h)

			local center = w / 2
			surface.SetFont("DermaDefault")
			local txt = string.Comma(LocalPlayer():GetNWInt(ms.Ores._nwPoints, 0)) .. " points"
			local txtW, txtH = surface.GetTextSize(txt)
			local y = h - txtH - 8
			surface.SetTextPos((center - txtW * 0.5) + 10, y)
			surface.SetTextColor(GREEN_COLOR)
			surface.DrawText(txt)
			surface.SetDrawColor(DEFAULT_COLOR)
			surface.SetMaterial(POINTS_ICON)
			surface.DrawTexturedRect((center - txtW * 0.5) - 10, y - 1, 16, 16)
		end

		do
			local statLevel = LocalPlayer():GetNWInt("ms.Ores.ToxicResistance", 0)
			local label = upgradePanel:Add("DLabel")
			label:SetText(("TOXIC RES. -  Lvl. %d (+%d%%) - %s"):format(statLevel, statLevel, string.Comma(statLevel * ARGONITE_MULTIPLIER) .. " points"))
			label:Dock(TOP)
			label:DockMargin(4, 4, 4, 4)

			local yPos = 0
			local btn = upgradePanel:Add("DButton")
			btn:SetText("Upgrade")
			btn:SetPos(0, yPos)
			btn:SetWide(60)
			btn:SetSkin("Default")
			btn:Dock(TOP)
			btn:SetTall(25)
			btn.Paint = drawButton
			btn.NextClick = 0

			if statLevel < 50 then
				local curPoints = LocalPlayer():GetNWInt(ms.Ores._nwPoints, 0)
				local curCost = math.floor(math.max(1000, statLevel * ARGONITE_MULTIPLIER))
				btn:SetEnabled(curCost < curPoints)

				function btn:DoClick()
					if self.NextClick > CurTime() then return end

					self.NextClick = CurTime() + 0.525

					local pl = LocalPlayer()
					local level = pl:GetNWInt("ms.Ores.ToxicResistance", 0)
					if level >= 50 then return end

					local points = pl:GetNWInt(ms.Ores._nwPoints, 0)
					local cost = math.floor(math.max(1000, level * ARGONITE_MULTIPLIER))

					-- Check just in case
					if points < cost then
						self:SetEnabled(false)
						return
					end

					RunConsoleCommand("mining_upgrade", k)
					surface.PlaySound("garrysmod/ui_click.wav")
					level = level + 1

					-- "Predict" the changes so we don't get buying lag
					pl:SetNWInt(ms.Ores._nwPoints, points - cost)
					pl:SetNWInt("ms.Ores.ToxicResistance", level)

					net.Start(NET_TAG)
					net.WriteString("Upgrade")
					net.SendToServer()

					label:SetText(("TOXIC RES. -  Lvl. %d (+%d%%) - %s"):format(level, level, string.Comma(level * ARGONITE_MULTIPLIER) .. "points"))

					if level >= 50 then
						self:SetEnabled(false)
						self:SetText("Maxed")
						self.__maxed = true

						local congrats = CreateSound(pl, "music/hl1_song3.mp3")
						congrats:PlayEx(1, 250)

						timer.Simple(5, function()
							if congrats:IsPlaying() then
								congrats:FadeOut(10)
							end
						end)
					end
				end
			else
				btn:SetEnabled(false)
				btn:SetText("Maxed")
				btn.__maxed = true
			end
		end

		sides:SetLeft(oresPanel)
		sides:SetLeftMin(frame:GetWide() / 2)
		sides:SetRight(upgradePanel)
		sides:SetLeftWidth(sides:GetWide() * 0.5 - 4 - 4 - 2)
	end

	net.Receive(NET_TAG, function()
		local op = net.ReadString()
		if op == "OpenMenu" then
			local npc = net.ReadEntity()
			local remanining = computeMaxArgoniteExtractionCount(LocalPlayer()) - net.ReadInt(32)
			showExtractorMenu(npc, remanining)
		end
	end)
end

if SERVER then
	util.AddNetworkString(NET_TAG)

	ms.Ores.PlayerArgonExtractionCounts = ms.Ores.PlayerArgonExtractionCounts or {}

	local MAX_ARGON = 20
	local STEPS = 10
	local MAX_RETRIES = 5

	local GRAPH = {
		[1] = Vector(0, 0, 0),
		[2] = Vector(-195, 877, 0),
		[3] = Vector(-184, 2064, 0),
		[4] = Vector(275, 2591, 0),
		[5] = Vector(1036, 2704, 0),
		[6] = Vector(275, 2591, 0),
		[7] = Vector(-184, 2064, 0),
		[8] = Vector(-1034, 2650, 0),
		[9] = Vector(-2393, 2026, 0),
		[10] = Vector(-2597, 1150, 0),
		[11] = Vector(-2472, 248, 0),
		[12] = Vector(-1069, -387, 0),
		[13] = Vector(-596, -370, 0),
	}

	local function getArgoniteRockCount()
		local curArgoniteCount = 0

		for _, rock in ipairs(ents.FindByClass("mining_rock")) do
			if rock:GetRarity() == ARGONITE_RARITY and rock.OriginalRock then
				curArgoniteCount = curArgoniteCount + 1
			end
		end

		return curArgoniteCount
	end

	local function generateArgoniteRocks()
		local count = getArgoniteRockCount()
		if count >= MAX_ARGON then return end

		local trigger = ms and ms.GetTrigger and ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end

		local basePos = trigger:GetPos()
		local i = math.random(#GRAPH)
		local pos = basePos + GRAPH[i]
		local nextPos = basePos + (GRAPH[i + 1] or GRAPH[1])
		local stepDist = pos:Distance(nextPos) / STEPS

		for curStep = 1, STEPS do
			if count >= MAX_ARGON then return end

			if math.random() > 0.6 then continue end

			local localPos = pos + (pos - nextPos):GetNormalized() * (curStep * stepDist)
			local localEndPos = localPos + VectorRand(-1, 1) * 300
			local retries = 0

			while retries < MAX_RETRIES and localEndPos.z > localPos.z + 200 do
				localEndPos = localPos + VectorRand(-1, 1) * 300
				retries = retries + 1
			end

			if localEndPos.z > localPos.z + 200 then continue end

			local tr = util.TraceLine({
				start = localPos,
				endpos = localEndPos,
				mask = MASK_SOLID_BRUSHONLY,
			})

			if tr.Hit and util.IsInWorld(tr.HitPos) then
				local rock = ents.Create("mining_rock")
				rock:SetPos(tr.HitPos + tr.HitNormal * 10)
				rock:SetSize(math.random() > 0.33 and 1 or 2)
				rock:SetRarity(ARGONITE_RARITY)
				rock:Spawn()
				rock:PhysWake()
				rock:DropToFloor()
				rock.OriginalRock = true

				count = count + 1

				rock:DropToFloor()
				rock:AddEffects(EF_ITEM_BLINK)

				local snd = CreateSound(rock, ")ambient/levels/labs/teleport_winddown1.wav")
				snd:SetDSP(16)
				snd:SetSoundLevel(80)
				snd:ChangePitch(math.random(150, 180))
				snd:Play()

				timer.Simple(0.5, function()
					if not IsValid(rock) then return end
					rock:DropToFloor()
					rock:RemoveEffects(EF_ITEM_BLINK)
				end)
			end
		end
	end

	local argoniteEntity
	local function getArgoniteEntity()
		if IsValid(argoniteEntity) then return argoniteEntity end

		argoniteEntity = ents.Create("prop_physics")
		argoniteEntity:SetModel("models/props_junk/PopCan01a.mdl")
		argoniteEntity:SetKeyValue("classname", "Argonite")
		argoniteEntity:Spawn()

		return argoniteEntity
	end

	local skipDeathHook = false
	timer.Create("mining_argonite_ore_dmg", 1, 0, function()
		for _, ply in ipairs(player.GetAll()) do
			local count = ms.Ores.GetPlayerOre(ply, ARGONITE_RARITY)
			local drunkFactor = ply.GetDrunkFactor and ply:GetDrunkFactor() or 0
			if count == 0 then
				ply.LastToxicHealth = nil

				if drunkFactor > 0 and ply.IsInZone and ply:IsInZone("volcano") then
					ply:SetDrunkFactor(0)
				end
			end

			if count > 0 and ply:Alive() then
				if isnumber(ply.LastToxicHealth) and ply.LastToxicHealth < ply:Health() then
					ply:SetHealth(ply.LastToxicHealth)
				end

				if ply:Health() > ply:GetMaxHealth() then
					ply:SetHealth(ply:GetMaxHealth())
				end

				local dmg = math.min(25, math.ceil(count / 2))
				dmg = dmg - ((dmg / 100) * ply:GetNWInt("ms.Ores.ToxicResistance", 0)) -- diminishes damage received with toxic resistance

				local preHealth = ply:Health()
				local argonite = getArgoniteEntity()
				local dmgInfo = DamageInfo()
				dmgInfo:SetDamage(dmg)
				dmgInfo:SetDamageType(DMG_RADIATION)
				dmgInfo:SetAttacker(argonite)
				dmgInfo:SetInflictor(argonite)
				ply:TakeDamageInfo(dmgInfo)

				if ply.SetDrunkFactor then
					ply:SetDrunkFactor(dmg * 10)
				end

				if ply:Health() > 0 and preHealth == ply:Health() then
					ply:SetHealth(preHealth - count)

					if ply:Health() <= 0 then
						ply:KillSilent()

						skipDeathHook = true
						hook.Run("PlayerDeath", ply, argonite, argonite)
						skipDeathHook = false
					end
				end

				-- we can't use :Alive here because it won't be accurate just yet
				if ply:Health() > 0 then
					ply.LastToxicHealth = ply:Health()
				end
			end
		end
	end)

	timer.Create("mining_argonite_ore_spawning", 5, 0, generateArgoniteRocks)

	local function reducePlayerArgoniteOreCount(ply)
		if skipDeathHook then return end

		local count = ms.Ores.GetPlayerOre(ply, ARGONITE_RARITY)
		if count > 0 then
			ms.Ores.TakePlayerOre(ply, ARGONITE_RARITY, math.ceil(count / 2))
		end

		ply.LastToxicHealth = nil
	end

	hook.Add("PlayerDeath", "mining_argonite_ore", reducePlayerArgoniteOreCount)
	hook.Add("PlayerSilentDeath", "mining_argonite_ore", reducePlayerArgoniteOreCount)

	local MAX_NPC_DIST = 300 * 300
	hook.Add("KeyPress", "mining_argonite_ore", function(ply, key)
		if key ~= IN_USE then return end

		local npc = ply:GetEyeTrace().Entity
		if not npc:IsValid() then return end

		if npc.role == "extractor" and npc:GetPos():DistToSqr(ply:GetPos()) <= MAX_NPC_DIST then
			net.Start(NET_TAG)
			net.WriteString("OpenMenu")
			net.WriteEntity(npc)
			net.WriteInt(ms.Ores.PlayerArgonExtractionCounts[ply:SteamID()] or 0, 32)
			net.Send(ply)

			if ply.LookAt then
				ply:LookAt(npc, 0.1, 0)
			end
		end
	end)

	local function tradeArgoniteForPoints(ply)
		local oreData = ms.Ores.__R[ARGONITE_RARITY]
		local amount = ms.Ores.GetPlayerOre(ply, ARGONITE_RARITY)
		if amount == 0 then return end

		local steamid = ply:SteamID()
		if (ms.Ores.PlayerArgonExtractionCounts[steamid] or 0) >= computeMaxArgoniteExtractionCount(ply) then
			return
		end

		local earnings = math.ceil((oreData.Worth * amount) * ARGONITE_MULTIPLIER)
		ms.Ores.GetSavedPlayerDataAsync(ply, function(data)
			local points = math.floor(data._points + earnings)

			ms.Ores.SetSavedPlayerData(ply, "points", points)
			ply:SetNWInt(ms.Ores._nwPoints, points)
			ply:EmitSound(")physics/surfaces/underwater_impact_bullet3.wav", 75, 70)

			ms.Ores.TakePlayerOre(ply, ARGONITE_RARITY, amount)
			ms.Ores.PlayerArgonExtractionCounts[steamid] = (ms.Ores.PlayerArgonExtractionCounts[steamid] or 0) + 1

			local container = ents.FindByClass("mining_argonite_container")[1]
			if IsValid(container) then
				container:AddArgonite(amount)
			end

			-- reset after a day or when server restarts/crashes
			timer.Simple(60 * 60 * 24, function()
				ms.Ores.PlayerArgonExtractionCounts[steamid] = nil
			end)
		end)
	end

	local function upgradeToxicResistance(ply)
		ms.Ores.GetSavedPlayerDataAsync(ply, function(data)
			local level = data.ToxicResistance
			if level >= 50 then return end

			local points = data._points
			local cost = math.floor(math.max(1000, level * ARGONITE_MULTIPLIER))

			if points < cost then return end

			level = level + 1

			ms.Ores.SetSavedPlayerData(ply, "points", points - cost)
			ms.Ores.SetSavedPlayerData(ply, "toxicresistance", level)

			ply:SetNWInt(ms.Ores._nwPoints, points - cost)
			ply:SetNWInt("ms.Ores.ToxicResistance", level)
		end, { "ToxicResistance" })
	end

	-- we have to do that because its not loaded with the other stats
	hook.Add("PlayerInitialSpawn", "mining_toxic_resistance", function(ply)
		ms.Ores.GetSavedPlayerDataAsync(ply, function(data)
			ply:SetNWInt("ms.Ores.ToxicResistance", data.ToxicResistance)
		end, { "ToxicResistance" })
	end)

	local NPC_OFFSET = Vector (1476, -348, -103)
	local NPC_ANGLE = Angle(0, 90, 0)
	local CONTAINER_OFFSET = Vector(1477, -108, -103)
	local CONTAINER_ANGLE = Angle(0, 90, 0)
	local function spawn_extractor_ents()
		local trigger = ms and ms.GetTrigger and ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end

		local basePos = trigger:GetPos()

		local npc = ents.Create("lua_npc")
		npc:SetPos(basePos + NPC_OFFSET)
		npc:SetAngles(NPC_ANGLE)
		npc.role = "extractor"
		npc:Spawn()
		npc.ms_notouch = true

		local onKilled = npc.OnNPCKilled
		function npc:OnNPCKilled(...)
			onKilled(...)
			timer.Simple(5, function()
				npc = ents.Create("lua_npc")
				npc:SetPos(basePos + NPC_OFFSET)
				npc:SetAngles(NPC_ANGLE)
				npc.role = "extractor"
				npc:Spawn()
				npc.ms_notouch = true
			end)
		end

		local container = ents.Create("mining_argonite_container")
		container:SetPos(basePos + CONTAINER_OFFSET)
		container:SetAngles(CONTAINER_ANGLE)
		container:Spawn()
		container.ms_notouch = true
	end

	hook.Add("InitPostEntity", "mining_argonite_extractor_npc", spawn_extractor_ents)
	hook.Add("PostCleanupMap", "mining_argonite_extractor_npc", spawn_extractor_ents)

	net.Receive(NET_TAG, function(_, ply)
		local isInRange = false
		for _, npc in ipairs(ents.FindByClass("lua_npc")) do
			if npc.role == "extractor" and npc:GetPos():DistToSqr(ply:GetPos()) <= MAX_NPC_DIST then
				isInRange = true
				break
			end
		end

		if not isInRange then return end

		local op = net.ReadString()
		if op == "GiveOres" then
			tradeArgoniteForPoints(ply)
		elseif op == "Upgrade" then
			upgradeToxicResistance(ply)
		end
	end)
end