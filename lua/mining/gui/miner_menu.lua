pcall(include, "autorun/translation.lua")
local L = translation and translation.L or function(s) return s end

if IsValid(g_MinerMenu) then
	g_MinerMenu:Remove()
end

local tag = "msOresMinerMenu"

surface.CreateFont(tag .. "Title", {
	font = "Roboto",
	size = 24,
	weight = 800
})

surface.CreateFont(tag .. "ItemName", {
	font = "Roboto",
	size = 18,
	weight = 1
})

local function DrawTitleText(txt, x, y, font, shadowColor, color, dist)
	surface.SetTextPos(x + dist, y + dist)
	surface.SetTextColor(shadowColor)
	surface.DrawText(txt)

	surface.SetTextPos(x - dist, y)
	surface.SetTextColor(color)
	surface.DrawText(txt)
end

local function DrawOutlinedRect(x, y, w, h, outlineColor, color)
	surface.SetDrawColor(color)
	surface.DrawRect(x, y, w, h)

	surface.SetDrawColor(outlineColor)
	surface.DrawOutlinedRect(x, y, w, h)
end

local PANEL = {}
local coinsIcon = Material("icon16/coins.png")
local pointsIcon = Material("icon16/contrast_low.png")

local BLUR = Material("pp/blurscreen")
local function blur_rect(x, y, w, h, layers, quality)
	surface.SetMaterial(BLUR)
	surface.SetDrawColor(255, 255, 255)

	render.SetScissorRect(x, y, x + w, y + h, true)
		for i = 1, layers do
			BLUR:SetFloat("$blur", (i / layers) * quality)
			BLUR:Recompute()

			render.UpdateScreenEffectTexture()
			surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		end
	render.SetScissorRect(0, 0, 0, 0, false)
end

PANEL.PaintFunctions = {
	DFrame = function(self, w, h)
		DrawOutlinedRect(0, 0, w, h, Color(0, 0, 0, 255), Color(0, 0, 0, 240))

		surface.SetDrawColor(Color(0, 0, 0, 200))
		surface.DrawRect(1, 1, w - 2, 32)

		surface.SetFont(tag .. "Title")
		local txt = self.lblTitle:GetText()
		local txtW = surface.GetTextSize(txt)
		DrawTitleText(txt, w * 0.5 - txtW * 0.5, 4, tag, Color(0, 0, 0, 127), Color(192, 192, 192), 2)

		if IsValid(self.ModelPanel) then
			surface.SetFont("DermaDefault")
			local txt = string.Comma(LocalPlayer():GetCoins())
			local txtW = surface.GetTextSize(txt)
			surface.SetDrawColor(Color(192, 192, 192))
			surface.SetMaterial(coinsIcon)
			surface.DrawTexturedRect(self.ModelPanel:GetWide() * 0.5 - txtW * 0.5 - 16 * 0.5 + 4 - 2, 32 * 0.5 - 16 * 0.5 + 2, 16, 16)
			surface.SetTextPos(self.ModelPanel:GetWide() * 0.5 - txtW * 0.5 + 16 * 0.5 + 4 + 2, 32 * 0.5 - 16 * 0.5 + 3)
			surface.SetTextColor(Color(127, 192, 127))
			surface.DrawText(txt)
		end
	end,
	PanelList = function(self, w, h)
		DrawOutlinedRect(0, 0, w, h, Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	end,
	DButton = function(self, w, h)
		if self:IsHovered() then
			self:SetColor(Color(0, 0, 0, 255))
		else
			self:SetColor(Color(255, 255, 255, 255))
		end

		DrawOutlinedRect(0, 0, w, h,
			Color(255, 255, 255, 0),
			self:IsHovered() and Color(255,255,255,255) or Color(36, 36, 36, 220)
		)
	end
}

local Paint = PANEL.PaintFunctions
PANEL.shown = false
PANEL.transitionSpeed = 0.33

function PANEL:Init()
	self:SetSize(768, ScrH() / 1.7)
	self:SetPos(ScrW() * 0.5 - self:GetWide() * 0.5, ScrH() * 0.5 - self:GetTall() * 0.5)
	self:SetDraggable(false)
	self:SetSizable(false)

	hook.Add("HUDPaint", self, function()
		if not self:IsVisible() then return end

		local x, y = self:LocalToScreen()
		local w, h = self:GetSize()
		blur_rect(x, y, w, h, 10, 2)
	end)

	self.Close = function(self)
		self:MakeMove()
	end

	self:SetTitle("MINER")
	self:SetAlpha(0)
	self.Paint = Paint.DFrame
	self.btnClose:SetFont("marlett")
	self.btnClose:SetText("r")
	self.btnClose:SetSkin("Default")
	self.btnClose.Paint = function() end
	self.Sides = vgui.Create("DHorizontalDivider", self)
	self.Sides:Dock(FILL)
	self.Sides.StartGrab = function() end
	self.OresPanel = vgui.Create("DPanel", self)

	self.OresPanel.Paint = function(_, w, h)
		Paint.PanelList(_, w, h)
		local pl = LocalPlayer()
		local bgCol1 = Color(0, 0, 0, 127)
		local bgCol2 = Color(0, 0, 0, 96)
		local defaultCol = Color(205, 205, 205)
		local greenCol = Color(127, 192, 127)
		local width = _:GetWide()
		local center = width * 0.5
		local titlefont = tag .. "Title"
		local multiplier = math.Round(ms.Ores.GetPlayerMultiplier(pl), 3)
		surface.SetFont(titlefont)
		local txt = "YOUR ORES"
		local txtW, txtH = surface.GetTextSize(txt)
		surface.SetTextPos(center - txtW * 0.5, 4)
		surface.SetTextColor(defaultCol)
		surface.DrawText(txt)
		local i = 0
		local yBase, y, h = txtH + 8, 0, txtH + 8

		for k, v in next, ms.Ores.__R do
			local amount = ms.Ores.GetPlayerOre(pl, k)
			if v.Hidden and amount <= 0 then continue end
			txt = amount .. " " .. v.Name .. " Ore"
			surface.SetFont(titlefont)
			txtW, txtH = surface.GetTextSize(txt)
			y = yBase + h * i
			surface.SetDrawColor(i % 2 == 0 and bgCol1 or bgCol2)
			surface.DrawRect(0, y, width, h)
			surface.SetTextPos(4, y + 4)
			surface.SetTextColor(amount > 0 and v.HudColor or defaultCol)
			surface.DrawText(txt)

			if amount > 0 then
				surface.SetFont("DermaDefault")
				txt = "+ " .. string.Comma(math.ceil((v.Worth * amount) * multiplier))
				txtW, txtH = surface.GetTextSize(txt)
				surface.SetTextPos(width - txtW - 4, y + h * 0.5 - txtH * 0.5)
				surface.SetTextColor(greenCol)
				surface.DrawText(txt)
			end

			i = i + 1
		end

		y = _:GetTall() - _.TurnInCoinsBtn:GetTall() - h - 8
		local yh = y + h * 0.5
		local multTxtCol

		if ms.Ores.SpecialDay then
			surface.SetDrawColor(220, 175 + math.sin(RealTime() * 4) * 15, 0)
			surface.DrawRect(0, y, width, h)
			surface.SetFont("DermaDefault")
			txt = ("It's %s! (+%d%%)"):format(ms.Ores.SpecialDay.Name, (math.Clamp(ms.Ores.SpecialDay.WorthMultiplier, 1, 5) - 1) * 100)
			txtW, txtH = surface.GetTextSize(txt)
			multTxtCol = Color(40, 40, 40)
			surface.SetTextPos(4, yh - txtH * 0.5)
			surface.SetTextColor(multTxtCol)
			surface.DrawText(txt)
		else
			surface.SetDrawColor(bgCol1)
			surface.DrawRect(0, y, width, h)
			multTxtCol = defaultCol
		end

		txt = "x" .. tostring(multiplier)
		surface.SetFont(titlefont)
		txtW, txtH = surface.GetTextSize(txt)
		surface.SetTextPos(width - txtW - 4, y + 4)
		surface.SetTextColor(multTxtCol)
		surface.DrawText(txt)
	end

	self.OresPanel.TurnInCoinsBtn = vgui.Create("DButton", self.OresPanel)
	self.OresPanel.TurnInCoinsBtn:SetText("Turn in for Coins")
	self.OresPanel.TurnInCoinsBtn:SetSkin("Default")
	self.OresPanel.TurnInCoinsBtn.Paint = Paint.DButton

	self.OresPanel.TurnInCoinsBtn.DoClick = function(_)
		RunConsoleCommand("mining_turnin", "O")
	end

	self.OresPanel.TurnInPointsBtn = vgui.Create("DButton", self.OresPanel)
	self.OresPanel.TurnInPointsBtn:SetText("Turn in for Points")
	self.OresPanel.TurnInPointsBtn:SetSkin("Default")
	self.OresPanel.TurnInPointsBtn.Paint = Paint.DButton

	self.OresPanel.TurnInPointsBtn.DoClick = function(_)
		RunConsoleCommand("mining_turnin", "P")
	end

	self.PickaxePanel = vgui.Create("DPanel", self)
	self.PickaxePanel.TooltipAreas = {}
	self.PickaxePanel.Buttons = {}

	self.PickaxePanel.Paint = function(_, w, h)
		Paint.PanelList(_, w, h)
		local pl = LocalPlayer()
		local bgCol1 = Color(0, 0, 0, 127)
		local bgCol2 = Color(0, 0, 0, 96)
		local defaultCol = Color(205, 205, 205)
		local greenCol = Color(127, 192, 127)
		local yellowCol = Color(225, 192, 64)
		local width = _:GetWide()
		local center = width * 0.5
		surface.SetFont(tag .. "Title")
		local txt = "PICKAXE UPGRADES"
		local txtW, txtH = surface.GetTextSize(txt)
		surface.SetTextPos(center - txtW * 0.5, 4)
		surface.SetTextColor(defaultCol)
		surface.DrawText(txt)
		local i = 0
		local yBase, y, h = txtH + 8, 0, txtH + 8

		for k, v in next, ms.Ores.__PStats do
			surface.SetFont("DermaDefault")
			txtW, txtH = surface.GetTextSize(v.Name)
			y = yBase + h * i
			surface.SetDrawColor(i % 2 == 0 and bgCol1 or bgCol2)
			surface.DrawRect(0, y, width, h)
			surface.SetTextPos(4, y + h * 0.5 - txtH * 0.5)
			surface.SetTextColor(defaultCol)
			surface.DrawText(v.Name)
			local level = pl:GetNWInt(ms.Ores._nwPickaxePrefix .. v.VarName, 0)
			txt = ms.Ores.StatFormat(k, level) .. "   -   Lvl " .. level
			txtW, txtH = surface.GetTextSize(txt)
			surface.SetTextPos(width - txtW - 68, y + 4)
			surface.SetTextColor(defaultCol)
			surface.DrawText(txt)

			if level < 50 then
				txt = "⇧ " .. string.Comma(ms.Ores.StatPrice(k, level + 1)) .. " points"
				txtW, txtH = surface.GetTextSize(txt)
				surface.SetTextPos(width - txtW - 68, y + h - txtH - 4)
				surface.SetTextColor(yellowCol)
				surface.DrawText(txt)
			end

			i = i + 1
		end

		surface.SetFont("DermaDefault")
		txt = string.Comma(pl:GetNWInt(ms.Ores._nwPoints, 0)) .. " points"
		txtW, txtH = surface.GetTextSize(txt)
		y = _:GetTall() - txtH - 8
		surface.SetTextPos((center - txtW * 0.5) + 10, y)
		surface.SetTextColor(greenCol)
		surface.DrawText(txt)
		surface.SetDrawColor(Color(192, 192, 192))
		surface.SetMaterial(pointsIcon)
		surface.DrawTexturedRect((center - txtW * 0.5) - 10, y - 1, 16, 16)
	end

	self.Sides:SetLeft(self.OresPanel)
	self.Sides:SetRight(self.PickaxePanel)
	self.Sides:SetLeftWidth(self:GetWide() * 0.5 - 4 - 4 - 2)
	self.TopPanel = vgui.Create("DPanel", self)
	self.TopPanel:Dock(TOP)
	self.TopPanel:DockMargin(24, 8, 24, 4)
	self.TopPanel:SetTall(56)

	self.TopPanel.Paint = function(_, w, h)
		Paint.PanelList(_, w, h)
		surface.DrawRect(0, 0, w, h)

		w = 256


		surface.SetFont(tag .. "Title")
		DrawTitleText(self.npcname, self.TopPanel:GetTall() + 4 + 2, 4 + 2, tag .. "Title", Color(0, 0, 0, 127), Color(225, 192, 64), 1)
		surface.SetFont("DermaDefault")

		local txt = self.say or "Hi!"
		local txtW, txtH = surface.GetTextSize(txt)
		surface.SetTextPos(self.TopPanel:GetTall() + 4 + 2, self.TopPanel:GetTall() - txtH - 4 - 2)
		surface.SetTextColor(Color(205, 205, 205))
		surface.DrawText(txt)
		surface.SetFont(tag .. "Title")

		txt = LocalPlayer():GetNick()
		txtW = surface.GetTextSize(txt)
		DrawTitleText(txt, self.TopPanel:GetWide() - self.TopPanel:GetTall() - txtW - 4 - 2, 4 + 2, tag .. "ItemName", Color(0, 0, 0, 127), Color(225, 192, 64), 1)
		surface.SetFont("DermaDefault")

		txt = string.Comma(LocalPlayer():GetCoins())
		txtW, txtH = surface.GetTextSize(txt)
		surface.SetDrawColor(Color(192, 192, 192))
		surface.SetMaterial(coinsIcon)
		surface.DrawTexturedRect(self.TopPanel:GetWide() - self.TopPanel:GetTall() - 16 - txtW - 4 - 4 - 2, self.TopPanel:GetTall() - 16 - 4, 16, 16)
		surface.SetTextPos(self.TopPanel:GetWide() - self.TopPanel:GetTall() - txtW - 4 - 2, self.TopPanel:GetTall() - 16 * 0.5 - txtH * 0.5 - 4)
		surface.SetTextColor(Color(127, 192, 127))
		surface.DrawText(txt)
	end

	self.NPCModelPanel = vgui.Create("DModelPanel", self.TopPanel)
	self.NPCModelPanel:Dock(LEFT)
	self.NPCModelPanel:SetWide(self.TopPanel:GetTall())

	self.NPCModelPanel.LayoutEntity = function(self, ent)
		ent:SetFlexWeight(math.random(ent:GetFlexNum()), math.random(100))
		ent:SetFlexScale(math.Rand(1, 2.25))
	end

	self.NPCModelPanel.Paint = function(self, w, h)
		DModelPanel.Paint(self, w, h)
		--Paint.PanelList(self, w, h)
	end

	self.PlyModelPanel = vgui.Create("DModelPanel", self.TopPanel)
	self.PlyModelPanel:Dock(RIGHT)
	self.PlyModelPanel:SetWide(self.TopPanel:GetTall())
	self.PlyModelPanel:SetModel(LocalPlayer():GetModel())

	self.PlyModelPanel.LayoutEntity = function(self, ent)
		ent:SetFlexWeight(math.random(ent:GetFlexNum()), math.random(100))
		ent:SetFlexScale(math.Rand(1, 2.25))
	end

	local eyes = self.PlyModelPanel:GetEntity():GetAttachment(self.PlyModelPanel:GetEntity():LookupAttachment("eyes"))
	self.PlyModelPanel:SetLookAt(Vector(0, 0, (eyes and eyes.Pos) and eyes.Pos.z or 64))
	self.PlyModelPanel:SetCamPos(Vector(1, 0.3, 0.3) * 200)
	self.PlyModelPanel:SetFOV(4)

	self.PlyModelPanel.Paint = function(self, w, h)
		DModelPanel.Paint(self, w, h)
		--Paint.PanelList(self, w, h)
	end
end

function PANEL:PerformLayout()
	self.lblTitle:SetVisible(false)
	self.btnMinim:SetVisible(false)
	self.btnMaxim:SetVisible(false)
	self.btnClose:SetSize(18, 32 + 1)
	self.btnClose:SetPos(self:GetWide() - self.btnClose:GetWide() - 4 - 1, 32 * 0.5 - self.btnClose:GetTall() * 0.5)
	local w, y = self.OresPanel:GetWide() * 0.5 - 6, self.OresPanel:GetTall() - 4
	self.OresPanel.TurnInCoinsBtn:SetPos(4, y - self.OresPanel.TurnInCoinsBtn:GetTall())
	self.OresPanel.TurnInCoinsBtn:SetWide(w)
	self.OresPanel.TurnInPointsBtn:SetPos(8 + w, y - self.OresPanel.TurnInPointsBtn:GetTall())
	self.OresPanel.TurnInPointsBtn:SetWide(w)

	-- Delay by a frame because :GetWide() updates late
	timer.Simple(0, function()
		local width = self.PickaxePanel:GetWide()
		local i, y = 0, 37

		if not next(self.PickaxePanel.Buttons) then
			local btnText = "Upgrade"
			local x = width - 64

			for k, v in next, ms.Ores.__PStats do
				local yPos = y + 32 * i
				local btn = vgui.Create("DButton", self.PickaxePanel)
				btn:SetText(btnText)
				btn:SetPos(x, yPos)
				btn:SetWide(60)
				btn:SetSkin("Default")
				btn.Paint = Paint.DButton
				btn.NextClick = 0
				-- The only way I can add reliable tooltips...
				local tooltipArea = vgui.Create("DButton", self.PickaxePanel)
				tooltipArea:SetPos(0, yPos)
				tooltipArea:SetSize(x - 4, btn:GetTall())
				tooltipArea:SetText("")
				tooltipArea:SetCursor("arrow")
				tooltipArea:SetTooltip(v.Help)
				tooltipArea.Paint = function() end
				tooltipArea.Click = function() end
				self.PickaxePanel.TooltipAreas[i] = tooltipArea
				local statLevel = LocalPlayer():GetNWInt(ms.Ores._nwPickaxePrefix .. v.VarName, 0)

				if statLevel < 50 then
					btn:SetTooltip(ms.Ores.StatFormat(k, statLevel) .. "  ->  " .. ms.Ores.StatFormat(k, statLevel + 1))

					btn.DoClick = function(_)
						if _.NextClick > CurTime() then return end
						_.NextClick = CurTime() + 0.525
						local pl = LocalPlayer()
						local level = pl:GetNWInt(ms.Ores._nwPickaxePrefix .. v.VarName, 0)
						local points = pl:GetNWInt(ms.Ores._nwPoints, 0)
						local cost = ms.Ores.StatPrice(k, level + 1)
						-- Check just in case
						if points < cost then return end
						RunConsoleCommand("mining_upgrade", k)
						surface.PlaySound("garrysmod/ui_click.wav")
						level = level + 1
						-- "Predict" the changes so we don't get buying lag
						pl:SetNWInt(ms.Ores._nwPoints, points - cost)
						pl:SetNWInt(ms.Ores._nwPickaxePrefix .. v.VarName, level)

						if level >= 50 then
							_:SetEnabled(false)
							_:SetText("Maxed")
							_:SetTooltip(false)
							_.__maxed = true
							local congrats = CreateSound(pl, "music/hl1_song3.mp3")
							congrats:PlayEx(1, 250)

							timer.Simple(5, function()
								if congrats:IsPlaying() then
									congrats:FadeOut(10)
								end
							end)
						else
							_:SetTooltip(ms.Ores.StatFormat(k, level) .. "  ->  " .. ms.Ores.StatFormat(k, level + 1))
						end
					end
				else
					btn:SetEnabled(false)
					btn:SetText("Maxed")
					btn.__maxed = true
				end

				self.PickaxePanel.Buttons[k] = btn
				i = i + 1
			end
		end

		if not IsValid(self.PickaxePanel.GiveBtn) then
			self.PickaxePanel.GiveBtn = vgui.Create("DButton", self.PickaxePanel)
			self.PickaxePanel.GiveBtn:SetText("Give me a Pickaxe!")
			self.PickaxePanel.GiveBtn:SetPos(4, y + 32 * i)
			self.PickaxePanel.GiveBtn:SetWide(width - 8)
			self.PickaxePanel.GiveBtn:SetSkin("Default")
			self.PickaxePanel.GiveBtn.Paint = Paint.DButton

			self.PickaxePanel.GiveBtn.DoClick = function(_)
				RunConsoleCommand("gm_giveswep", "mining_pickaxe")
				surface.PlaySound("garrysmod/ui_click.wav")
			end
		end
	end)
end

function PANEL:MakeMove()
	self:SetVisible(true)

	if not self.shown then
		self:AlphaTo(255, self.transitionSpeed, 0, function()
			gui.EnableScreenClicker(true)
		end)
	else
		self:AlphaTo(0, self.transitionSpeed, 0, function()
			self:SetVisible(false)
			gui.EnableScreenClicker(false)
		end)
	end

	self.shown = not self.shown
end

function PANEL:SetupShop(npc, id)
	self.NPCModelPanel:SetModel(npc:GetModel())
	local attachment = self.NPCModelPanel:GetEntity():LookupAttachment("eyes")

	if attachment ~= 0 then
		self.NPCModelPanel:SetLookAt(Vector(0, 0, self.NPCModelPanel:GetEntity():GetAttachment(attachment).Pos.z))
	end

	self.NPCModelPanel:SetCamPos(Vector(1, -0.3, 0.3) * 200)
	self.NPCModelPanel:SetFOV(4)
	local minerSettings = ms.Ores.NPCMiners[id]
	self.npc = npc
	self.npcname = minerSettings.name
	self.say = L(table.Random(minerSettings.sentences))
end

function PANEL:Think()
	if self.shown then
		local pl = LocalPlayer()

		if IsValid(self.npc) and self.npc:GetPos():DistToSqr(pl:GetPos()) > 16384 then
			self:MakeMove()

			return
		end

		local total = 0

		for k, v in next, ms.Ores.__R do
			local count = ms.Ores.GetPlayerOre(pl, k)

			if count > 0 then
				total = total + (v.Worth * count)
			end
		end

		if total > 0 then
			total = math.ceil(total * math.Round(ms.Ores.GetPlayerMultiplier(pl), 3))
			self.OresPanel.TurnInCoinsBtn:SetEnabled(true)
			self.OresPanel.TurnInPointsBtn:SetEnabled(true)
			local tip = "You'll receive " .. string.Comma(total)
			self.OresPanel.TurnInCoinsBtn:SetTooltip(tip .. " coins!")
			self.OresPanel.TurnInPointsBtn:SetTooltip(tip .. " points for pickaxe upgrades!")
		else
			self.OresPanel.TurnInCoinsBtn:SetEnabled(false)
			self.OresPanel.TurnInPointsBtn:SetEnabled(false)
			self.OresPanel.TurnInCoinsBtn:SetTooltip(false)
			self.OresPanel.TurnInPointsBtn:SetTooltip(false)
		end

		for k, v in next, self.PickaxePanel.Buttons do
			if v.__maxed then continue end
			local stat = ms.Ores.__PStats[k]
			if not stat then continue end
			local level = pl:GetNWInt(ms.Ores._nwPickaxePrefix .. stat.VarName, 0)
			local points = pl:GetNWInt(ms.Ores._nwPoints, 0)
			local cost = ms.Ores.StatPrice(k, level + 1)
			v:SetEnabled(points >= cost)
		end
	end
end

local function TransformPanel(self, panel)
	panel:SetTall(panel:GetTall() + 8)
	panel.Paint = Paint.DFrame
	panel.PerformLayout = self.PerformLayout

	for _, pnl in next, panel:GetChildren() do
		if pnl.ThisClass == "DPanel" or pnl.ThisClass == "EditablePanel" then
			for _, pnl2 in next, pnl:GetChildren() do
				if pnl2.ThisClass == "DButton" then
					pnl2:GetParent():AlignBottom(8)
					pnl2:SetSkin("Default")
					pnl2.Paint = Paint.DButton
				elseif pnl2.ThisClass == "DLabel" then
					pnl2:GetParent():AlignTop(32 + 4)
					pnl2:SetColor(Color(205, 205, 205))
				elseif pnl2.ThisClass == "DTextEntry" then
					pnl2:SetSkin("Default")
				end
			end
		end
	end
end

local function DermaPopup(func)
	return function(self, ...)
		local msgBox = func(...)
		if not IsValid(msgBox) then return end
		TransformPanel(self, msgBox)

		return msgBox
	end
end

PANEL.Message = DermaPopup(Derma_Message)
PANEL.StringRequest = DermaPopup(Derma_StringRequest)
PANEL.Query = DermaPopup(Derma_Query)
derma.DefineControl(tag, "The miner menu.", PANEL, "DFrame")
PANEL = nil

usermessage.Hook("ms.Ores_StartMinerMenu", function(umsg)
	local npc = umsg:ReadEntity()
	local id = umsg:ReadShort()

	if not IsValid(g_MinerMenu) then
		g_MinerMenu = vgui.Create(tag)
	end

	if not g_MinerMenu.shown then
		g_MinerMenu:SetupShop(npc, id)
	end

	g_MinerMenu:SetVisible(true)
	g_MinerMenu:MakeMove()
end)