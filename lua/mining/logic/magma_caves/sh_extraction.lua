local ARGONITE_RARITY = 18
local RARITY_DATA = {
	[18] = 1000, -- argonite
	[19] = 2000, -- detonite
}

local EXTRACTION_COUNT_PER_DAY = 8
local NET_TAG = "ms.Ores.ExtractorMenu"

local function computeMaxExtractionCount(ply)
	return EXTRACTION_COUNT_PER_DAY + math.ceil((EXTRACTION_COUNT_PER_DAY / 100) * ply:GetNWInt("ms.Ores.ToxicResistance", 0))
end

local function playerHasOres(ply)
	local total_count = 0
	for rarity, _ in pairs(RARITY_DATA) do
		total_count = total_count + ms.Ores.GetPlayerOre(ply, rarity)
	end

	return total_count > 0
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
		frame:SetTitle("Extractor")
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
		introPanel:SetText("Hi, I'm an extractor, I extract argonite and detonite. If you get me some, I'll give in a good word to the miner. Be warned though, both are very volatile and toxic. We use them to power the energy core in the reactor.")

		local sides = frame:Add("DHorizontalDivider")
		sides:Dock(FILL)
		sides.StartGrab = function() end

		local oresPanel = sides:Add("DPanel")
		oresPanel:SetWide(frame:GetWide() / 2)

		function oresPanel:Paint(w, h)
			drawPanelList(self, w, h)

			local y = 0
			surface.SetDrawColor(BACKGROUND_COLOR)
			surface.DrawRect(0, y, w, h)

			for rarity, rarity_mult in pairs(RARITY_DATA) do
				local oreData = ms.Ores.__R[rarity]
				local amount = ms.Ores.GetPlayerOre(LocalPlayer(), rarity)
				local txt = amount .. " " .. oreData.Name .. " Ore(s)"
				surface.SetFont("msOresExtractorTitle")
				local txtW, txtH = surface.GetTextSize(txt)

				surface.SetTextPos(4, y + 4)
				surface.SetTextColor(amount > 0 and oreData.HudColor or DEFAULT_COLOR)
				surface.DrawText(txt)

				if amount > 0 then
					surface.SetFont("DermaDefault")
					txt = "+ " .. string.Comma(math.ceil((oreData.Worth * amount) * rarity_mult))
					txtW, txtH = surface.GetTextSize(txt)
					surface.SetTextPos(w - 4 - txtW, y + txtH)
					surface.SetTextColor(GREEN_COLOR)
					surface.DrawText(txt)
				end

				y = y + draw.GetFontHeight("msOresExtractorTitle") + 5
			end
		end

		local giveBtn = oresPanel:Add("DButton")
		giveBtn:SetSize(100, 25)
		giveBtn:Dock(BOTTOM)

		local perc = (remaining / computeMaxExtractionCount(LocalPlayer())) * 100
		giveBtn:SetText(("Give Ore(s) (%d%% TOXIC RES. remanining today)"):format(perc))
		giveBtn:SetSkin("Default")
		giveBtn:SetEnabled(remaining > 0 and playerHasOres(LocalPlayer()))

		function giveBtn:Paint(w, h)
			drawButton(self, w, h)
		end

		function giveBtn:DoClick()
			net.Start(NET_TAG)
			net.WriteString("GiveOres")
			net.SendToServer()

			remaining = remaining - 1
			local newPerc = (remaining / computeMaxExtractionCount(LocalPlayer())) * 100
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
			label:SetText(("TOXIC RES. -  Lvl. %d (+%d%%) - %s"):format(statLevel, statLevel, string.Comma(statLevel * RARITY_DATA[ARGONITE_RARITY]) .. " points"))
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
				local curCost = math.floor(math.max(1000, statLevel * RARITY_DATA[ARGONITE_RARITY]))
				btn:SetEnabled(curCost < curPoints)

				function btn:DoClick()
					if self.NextClick > CurTime() then return end

					self.NextClick = CurTime() + 0.525

					local pl = LocalPlayer()
					local level = pl:GetNWInt("ms.Ores.ToxicResistance", 0)
					if level >= 50 then return end

					local points = pl:GetNWInt(ms.Ores._nwPoints, 0)
					local cost = math.floor(math.max(1000, level * RARITY_DATA[ARGONITE_RARITY]))

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

					label:SetText(("TOXIC RES. -  Lvl. %d (+%d%%) - %s"):format(level, level, string.Comma(level * RARITY_DATA[ARGONITE_RARITY]) .. "points"))

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
			local remanining = computeMaxExtractionCount(LocalPlayer()) - net.ReadInt(32)
			showExtractorMenu(npc, remanining)
		end
	end)
end

if SERVER then
	util.AddNetworkString(NET_TAG)

	ms.Ores.PlayerExtractionCounts = ms.Ores.PlayerExtractionCounts or {}

	local MAX_NPC_DIST = 300 * 300
	hook.Add("KeyPress", "mining_extraction_npc", function(ply, key)
		if key ~= IN_USE then return end

		local npc = ply:GetEyeTrace().Entity
		if not npc:IsValid() then return end

		if npc.role == "extractor" and npc:GetPos():DistToSqr(ply:GetPos()) <= MAX_NPC_DIST then
			net.Start(NET_TAG)
			net.WriteString("OpenMenu")
			net.WriteEntity(npc)
			net.WriteInt(ms.Ores.PlayerExtractionCounts[ply:SteamID()] or 0, 32)
			net.Send(ply)

			if ply.LookAt then
				ply:LookAt(npc, 0.1, 0)
			end
		end
	end)

	local function tradeForPoints(ply)
		if not playerHasOres(ply) then return end

		local steamid = ply:SteamID()
		if (ms.Ores.PlayerExtractionCounts[steamid] or 0) >= computeMaxExtractionCount(ply) then
			return
		end

		local earnings = 0
		for rarity, rarity_mult in pairs(RARITY_DATA) do
			local oreData = ms.Ores.__R[rarity]
			local amount = ms.Ores.GetPlayerOre(ply, rarity)
			earnings = earnings + math.ceil((oreData.Worth * amount) * rarity_mult)
		end

		ms.Ores.GetSavedPlayerDataAsync(ply, function(data)
			local points = math.floor(data._points + earnings)

			ms.Ores.SetSavedPlayerData(ply, "points", points)
			ply:SetNWInt(ms.Ores._nwPoints, points)
			ply:EmitSound(")physics/surfaces/underwater_impact_bullet3.wav", 75, 70)

			local argonite_amount = ms.Ores.GetPlayerOre(ply, ARGONITE_RARITY)
			local container = ents.FindByClass("mining_argonite_container")[1]
			if IsValid(container) and argonite_amount > 0 then
				container:AddArgonite(argonite_amount)
			end

			for rarity, _ in pairs(RARITY_DATA) do
				local amount = ms.Ores.GetPlayerOre(ply, rarity)
				if amount > 0 then
					ms.Ores.TakePlayerOre(ply, rarity, amount)
				end
			end

			ms.Ores.PlayerExtractionCounts[steamid] = (ms.Ores.PlayerExtractionCounts[steamid] or 0) + 1

			-- reset after a day or when server restarts/crashes
			timer.Simple(60 * 60 * 24, function()
				ms.Ores.PlayerExtractionCounts[steamid] = nil
			end)
		end)
	end

	local function upgradeToxicResistance(ply)
		ms.Ores.GetSavedPlayerDataAsync(ply, function(data)
			local level = data.ToxicResistance
			if level >= 50 then return end

			local points = data._points
			local cost = math.floor(math.max(1000, level * RARITY_DATA[ARGONITE_RARITY]))

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
	local function spawn_extractor_ents(ignore_npc)
		local trigger = ms and ms.GetTrigger and ms.GetTrigger("volcano")
		if not IsValid(trigger) then return end

		local basePos = trigger:GetPos()

		if not ignore_npc then
			local npc = ents.Create("lua_npc")
			npc:SetPos(basePos + NPC_OFFSET)
			npc:SetAngles(NPC_ANGLE)
			npc.role = "extractor"
			npc:Spawn()
			npc.ms_notouch = true
			npc:SetPermanent(true)
		end

		local container = ents.Create("mining_argonite_container")
		container:SetPos(basePos + CONTAINER_OFFSET)
		container:SetAngles(CONTAINER_ANGLE)
		container:Spawn()
		container.ms_notouch = true
	end

	hook.Add("InitPostEntity", "mining_extractor_npc", function() spawn_extractor_ents() end)
	hook.Add("PostCleanupMap", "mining_extractor_npc", function() spawn_extractor_ents(true) end)

	net.Receive(NET_TAG, function(_, ply)
		local isInRange = false
		for _, npc in ipairs(ents.FindByClass("lua_npc")) do
			if npc.role == "extractor" and npc:GetPos():DistToSqr(ply:GetPos()) <= MAX_NPC_DIST then
				isInRange = true
				break
			end
		end

		if not isInRange then return end

		-- based on sv_anticheat.lua things, deny if chips, teleport, etc...
		if isnumber(ply._miningCooldown) and ply._miningCooldown > CurTime() then return end
		if ply._miningBlocked then return end

		local op = net.ReadString()
		if op == "GiveOres" then
			tradeForPoints(ply)
		elseif op == "Upgrade" then
			upgradeToxicResistance(ply)
		end
	end)
end
