module("ms", package.seeall)
Ores = Ores or {}

local scale = math.max(0.6, ScrW() / 2560)
surface.CreateFont("mining_automation_hud", {
	font = "Sevastopol Interface",
	extended = true,
	weight = 600,
	size = math.max(18, 25 * scale)
})

surface.CreateFont("mining_automation_hud2", {
	font = "Sevastopol Interface",
	extended = true,
	weight = 500,
	size = math.max(16, 20 * scale)
})

function Ores.Automation.ShouldDrawText(ent)
	local ply = LocalPlayer()

	if ply:EyePos():DistToSqr(ent:WorldSpaceCenter()) <= Ores.Automation.TextDrawingDistance * Ores.Automation.TextDrawingDistance then return true end
	if ply:GetEyeTrace().Entity == ent then return true end

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
local FONT_HEIGHT = 25 * scale
local FRAME_WIDTH = 200
local FRAME_HEIGHT = 100
local COLOR_WHITE = Color(255, 255, 255, 255)
local FRAME_PADDING = 5

local function drawEntityInfoFrame(ent, data)
	if not MINING_INFO_HUD:GetBool() then return end

	local total_height = ent.MiningInfoFrameHeight or (FRAME_HEIGHT + (#data * (FONT_HEIGHT + Ores.Automation.HudPadding)))
	local total_width = ent.MiningInfoFrameWidth or FRAME_WIDTH
	local pos = ent:WorldSpaceCenter():ToScreen()
	if not pos.visible then return end

	local x, y = pos.x - total_width / 2, pos.y - total_height / 2

	if ent:GetNWBool("IsMalfunctioning", false) then
		local warn_text = "⚠  Equipment is malfunctioning"
		surface.SetFont("mining_automation_hud")
		local tw, th = surface.GetTextSize(warn_text)
		local warn_w = math.max(total_width, tw + Ores.Automation.HudPadding * 4)
		local warn_h = th + Ores.Automation.HudPadding * 2
		local warn_x = pos.x - warn_w / 2
		local warn_y = y - warn_h - 4

		blur_rect(warn_x, warn_y, warn_w, warn_h, 10, 2)
		surface.SetDrawColor(180, 140, 0, 160)
		surface.DrawRect(warn_x, warn_y, warn_w, warn_h)
		surface.SetTextColor(255, 230, 50, 255)
		surface.SetTextPos(warn_x + Ores.Automation.HudPadding * 2, warn_y + Ores.Automation.HudPadding)
		surface.DrawText(warn_text)
	end

	blur_rect(x, y, total_width, total_height, 10, 2)

	surface.SetDrawColor(0, 0, 0, 200)
	surface.DrawRect(x, y, total_width, total_height)

	local offset = Ores.Automation.HudPadding + FRAME_PADDING
	for _, line_data in ipairs(data) do
		if line_data.Type == "Action" then
			surface.SetFont("mining_automation_hud")

			local key = (input.LookupBinding(line_data.Binding) or "?"):upper()
			local text = ("[ %s ] %s"):format(key, line_data.Text)
			local tw, th = surface.GetTextSize(text)

			if tw + 100 > total_width then
				total_width = tw + Ores.Automation.HudPadding * 2 + 100
			end

			surface.SetTextColor(Ores.Automation.HudActionColor)
			surface.SetTextPos(x + total_width - (tw + Ores.Automation.HudPadding * 2), y + offset)
			surface.DrawText(text)

			offset =  offset + th + Ores.Automation.HudPadding
		elseif line_data.Type == "Data" then
			surface.SetFont("mining_automation_hud2")

			surface.SetTextColor(line_data.LabelColor or COLOR_WHITE)
			surface.SetTextPos(x + Ores.Automation.HudPadding + FRAME_PADDING, y + offset)
			surface.DrawText(line_data.Label)

			local text = tostring(line_data.Value)
			if line_data.MaxValue then
				local perc = math.Round((line_data.Value / line_data.MaxValue) * 100)
				local r = 255
				local g = 255 / 100 * perc
				local b = 255 / 100 * perc

				surface.SetTextColor(r, g, b, 255)
				text = tostring(perc)
			elseif line_data.ValueColor then
				surface.SetTextColor(line_data.ValueColor)
			end

			local tw, th = surface.GetTextSize(text)
			surface.SetTextPos(x + total_width - (tw + Ores.Automation.HudPadding * 2), y + offset)
			surface.DrawText(text)

			if tw + 100 > total_width then
				total_width = tw + Ores.Automation.HudPadding * 2 + 100
			end

			offset =  offset + th + Ores.Automation.HudPadding
		elseif line_data.Type == "State" then
			local state = tobool(line_data.Value) or false
			surface.SetDrawColor(state and 0 or 255, state and 255 or 0, 0, 255)
			surface.DrawRect(x + total_width - 25, y + 15, 15, 15)
		else
			if not isstring(line_data.Text) then continue end

			surface.SetFont("mining_automation_hud")

			surface.SetTextColor(line_data.Color or COLOR_WHITE)
			surface.SetTextPos(x + Ores.Automation.HudPadding + FRAME_PADDING, y + offset)
			surface.DrawText(line_data.Text)

			local tw, th = surface.GetTextSize(line_data.Text)
			if tw + 100 > total_width then
				total_width = tw + Ores.Automation.HudPadding * 2 + 100
			end
			offset = offset + th + Ores.Automation.HudPadding
		end

		if line_data.Border == true then
			--surface.SetDrawColor(Ores.Automation.HudSepColor)
			--surface.DrawRect(x, y + offset, total_width, 2)
			offset = offset + Ores.Automation.HudPadding
		end
	end

	-- more accurate height
	ent.MiningInfoFrameHeight = offset + Ores.Automation.HudPadding + FRAME_PADDING
	ent.MiningInfoFrameWidth = total_width
end

local function try_draw_ent(ent)
	local class_name = ent:GetClass()
	if not class_name:match("^ma_") and not ENTITY_INFO_EXTRAS[class_name] then return end
	if not Ores.Automation.ShouldDrawText(ent) then return end
	if not isfunction(ent.OnDrawEntityInfo) then return end

	local data = ent:OnDrawEntityInfo()
	if not istable(data) then return end

	drawEntityInfoFrame(ent, data)
end

hook.Add("HUDPaint", "mining_automation_entity_info", function()
	local tr = LocalPlayer():GetEyeTrace()
	if not IsValid(tr.Entity) then return end

	try_draw_ent(tr.Entity)
end)

net.Receive("MA_Malfunction", function()
	chat.AddText(Color(255, 200, 0), " ♦ [Ores] ", color_white, "A machine is malfunctioning! Whack it into shape!")
end)

local malfunction_fx_ents = {}
timer.Create("MA_MalfunctionTrack", 1, 0, function()
	malfunction_fx_ents = {}
	for class in pairs(Ores.Automation.EntityClasses) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if ent:GetNWBool("IsMalfunctioning", false) then
				malfunction_fx_ents[#malfunction_fx_ents + 1] = ent
			end
		end
	end
end)

timer.Create("MA_MalfunctionFX", 0.35, 0, function()
	for _, ent in ipairs(malfunction_fx_ents) do
		if not IsValid(ent) then continue end
		ParticleEffect("ExplosionCore_wall", ent:GetPos() + Vector(0, 0, 30), Angle(-90, 0, 0))
	end
end)