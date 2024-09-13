module("ms", package.seeall)
Ores = Ores or {}

surface.CreateFont("mining_automation_hud", {
	font = "Arial",
	extended = true,
	weight = 600,
	size = 25
})

surface.CreateFont("mining_automation_hud2", {
	font = "Arial",
	extended = true,
	weight = 500,
	size = 20
})

function Ores.Automation.ShouldDrawText(ent)
	local localPlayer = LocalPlayer()

	if localPlayer:EyePos():DistToSqr(ent:WorldSpaceCenter()) <= Ores.Automation.TextDrawingDistance * Ores.Automation.TextDrawingDistance then return true end
	if localPlayer:GetEyeTrace().Entity == ent then return true end

	return false
end

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

local MINING_INFO_HUD = CreateClientConVar("mining_automation_hud_frames", "1", true, true, "Display info frames for mining automation entities", 0, 1)

local ENTITY_INFO_EXTRAS = { mining_argonite_container = true }
local FONT_HEIGHT = 30
local FRAME_WIDTH = 250
local FRAME_HEIGHT = 100
local COLOR_WHITE = Color(255, 255, 255, 255)
local FRAME_PADDING = 5

local MTX_TRANSLATION = Vector(0, 0)
local MTX_SCALE = Vector(1, 1, 1)
local function drawEntityInfoFrame(ent, data)
	if not MINING_INFO_HUD:GetBool() then return end

	local totalHeight = ent.MiningInfoFrameHeight or (FRAME_HEIGHT + (#data * (FONT_HEIGHT + Ores.Automation.HudPadding)))
	local pos = ent:WorldSpaceCenter():ToScreen()
	if not pos.visible then return end

	local x, y = pos.x - FRAME_WIDTH / 2, pos.y - totalHeight / 2

	MTX_TRANSLATION.x = x
	MTX_TRANSLATION.y = y

	local mtx = Matrix()
	mtx:Translate(MTX_TRANSLATION)
	mtx:Scale(MTX_SCALE * math.max(0.6, ScrW() / 2560))
	mtx:Translate(-MTX_TRANSLATION)

	cam.PushModelMatrix(mtx, true)

	blur_rect(x, y, FRAME_WIDTH, totalHeight, 10, 2)
	surface.SetDrawColor(0, 0, 0, 220)
	surface.DrawRect(x, y, FRAME_WIDTH, totalHeight)

	local offset = Ores.Automation.HudPadding + FRAME_PADDING
	for _, lineData in ipairs(data) do
		if lineData.Type == "Action" then
			surface.SetFont("mining_automation_hud")

			local key = (input.LookupBinding(lineData.Binding, true) or "?"):upper()
			local text = ("[ %s ] %s"):format(key, lineData.Text)
			local tw, th = surface.GetTextSize(text)

			surface.SetTextColor(Ores.Automation.HudActionColor)
			surface.SetTextPos(x + FRAME_WIDTH - (tw + Ores.Automation.HudPadding * 2), y + offset)
			surface.DrawText(text)

			offset =  offset + th + Ores.Automation.HudPadding
		elseif lineData.Type == "Data" then
			surface.SetFont("mining_automation_hud2")

			surface.SetTextColor(lineData.LabelColor or COLOR_WHITE)
			surface.SetTextPos(x + Ores.Automation.HudPadding + FRAME_PADDING, y + offset)
			surface.DrawText(lineData.Label)

			local text = tostring(lineData.Value)
			if lineData.MaxValue then
				local perc = math.Round((lineData.Value / lineData.MaxValue) * 100)
				local r = 255
				local g = 255 / 100 * perc
				local b = 255 / 100 * perc

				surface.SetTextColor(r, g, b, 255)
				text = tostring(perc)
			elseif lineData.ValueColor then
				surface.SetTextColor(lineData.ValueColor)
			end

			local tw, th = surface.GetTextSize(text)
			surface.SetTextPos(x + FRAME_WIDTH - (tw + Ores.Automation.HudPadding * 2), y + offset)
			surface.DrawText(text)

			offset =  offset + th + Ores.Automation.HudPadding
		elseif lineData.Type == "State" then
			local state = tobool(lineData.Value) or false
			surface.SetDrawColor(state and 0 or 255, state and 255 or 0, 0, 255)
			surface.DrawRect(x + FRAME_WIDTH - 25, y + 15, 15, 15)
		else
			if not isstring(lineData.Text) then continue end

			surface.SetFont("mining_automation_hud")

			surface.SetTextColor(lineData.Color or COLOR_WHITE)
			surface.SetTextPos(x + Ores.Automation.HudPadding + FRAME_PADDING, y + offset)
			surface.DrawText(lineData.Text)

			local _, th = surface.GetTextSize(lineData.Text)
			offset = offset + th + Ores.Automation.HudPadding
		end

		if lineData.Border == true then
			surface.SetDrawColor(Ores.Automation.HudSepColor)
			surface.DrawRect(x + Ores.Automation.HudPadding, y + offset, FRAME_WIDTH - Ores.Automation.HudPadding * 2, 2)
			offset = offset + Ores.Automation.HudPadding
		end
	end

	-- more accurate height
	ent.MiningInfoFrameHeight = offset + Ores.Automation.HudPadding + FRAME_PADDING

	cam.PopModelMatrix()
end

local function try_draw_ent(ent)
	local entClass = ent:GetClass()
	if not Ores.Automation.EntityClasses[entClass] and not ENTITY_INFO_EXTRAS[entClass] then return end
	if not Ores.Automation.ShouldDrawText(ent) then return end
	if not isfunction(ent.OnDrawEntityInfo) then return end

	local data = ent:OnDrawEntityInfo()
	if not istable(data) then return end

	drawEntityInfoFrame(ent, data)
end

hook.Add("HUDPaint", "mining_automation_entity_info", function()
	local mining_ents = table.Add(ents.FindByClass("mining_*"), ents.FindByClass("ma_*"))
	table.sort(mining_ents, function(e1, e2)
		local eye_pos = LocalPlayer():EyePos()
		return e1:WorldSpaceCenter():DistToSqr(eye_pos) > e2:WorldSpaceCenter():DistToSqr(eye_pos)
	end)

	for _, ent in ipairs(mining_ents) do
		try_draw_ent(ent)
	end
end)