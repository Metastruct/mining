module("ms", package.seeall)
Ores = Ores or {}

local scale = math.max(0.6, ScrW() / 2560)
surface.CreateFont("mining_power_hud", {
	font = "Sevastopol Interface",
	extended = true,
	weight = 600,
	size = math.max(18, 25 * scale)
})

surface.CreateFont("mining_power_hud_small", {
	font = "Sevastopol Interface",
	extended = true,
	weight = 500,
	size = math.max(16, 20 * scale)
})

local POWER_HUD = CreateClientConVar("mining_power_hud", "1", true, true, "Display power status HUD", 0, 1)
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

local function drawPowerStatus()
	if not POWER_HUD:GetBool() then return end

	local ply = LocalPlayer()
	if not IsValid(ply) then return end

	-- Find all generators and transformers owned by player
	local generators = {}
	local transformers = {}

	for _, ent in ipairs(ents.FindByClass("ma_gen_v2")) do
		if ent:CPPIGetOwner() == ply then
			table.insert(generators, ent)
		end
	end

	for _, ent in ipairs(ents.FindByClass("ma_transformer_v2")) do
		if ent:CPPIGetOwner() == ply then
			table.insert(transformers, ent)
		end
	end

	if #generators == 0 and #transformers == 0 then return end

	local padding = 10
	local baseX = ScrW() - 250 - padding
	local baseY = ScrH() * 0.3
	local width = 250
	local itemHeight = 50
	local totalHeight = (#generators + #transformers) * (itemHeight + padding) + padding

	-- Background
	blur_rect(baseX, baseY, width, totalHeight, 10, 2)
	surface.SetDrawColor(0, 0, 0, 220)
	surface.DrawRect(baseX, baseY, width, totalHeight)

	local currentY = baseY + padding

	-- Draw Generators
	for _, gen in ipairs(generators) do
		local energy = gen:GetEnergyLevel()
		local canWork = gen:CanWork()

		-- Box background
		surface.SetDrawColor(24, 48, 26, 255)
		surface.DrawRect(baseX + padding, currentY, width - padding * 2, itemHeight)

		-- Status indicator
		surface.SetDrawColor(canWork and 0 or 255, canWork and 255 or 0, 0, 255)
		surface.DrawRect(baseX + width - 30, currentY + itemHeight / 2 - 7, 15, 15)

		-- Text
		surface.SetFont("mining_power_hud")
		surface.SetTextColor(255, 255, 255)
		surface.SetTextPos(baseX + padding + 5, currentY + 5)
		surface.DrawText("Generator")

		-- Energy bar
		local barWidth = width - padding * 4 - 30
		surface.SetDrawColor(40, 40, 40)
		surface.DrawRect(baseX + padding + 5, currentY + 30, barWidth, 10)

		surface.SetDrawColor(52, 141, 97)
		surface.DrawRect(baseX + padding + 5, currentY + 30, barWidth * (energy / 100), 10)

		currentY = currentY + itemHeight + padding
	end

	-- Draw Transformers
	for _, transformer in ipairs(transformers) do
		local argonite = transformer:GetNWInt("ArgoniteCount", 0)
		local maxArgonite = Ores.Automation.BatteryCapacity

		-- Box background
		surface.SetDrawColor(24, 48, 26, 255)
		surface.DrawRect(baseX + padding, currentY, width - padding * 2, itemHeight)

		-- Text
		surface.SetFont("mining_power_hud")
		surface.SetTextColor(255, 255, 255)
		surface.SetTextPos(baseX + padding + 5, currentY + 5)
		surface.DrawText("Transformer")

		-- Argonite bar
		local barWidth = width - padding * 4
		surface.SetDrawColor(40, 40, 40)
		surface.DrawRect(baseX + padding + 5, currentY + 30, barWidth, 10)

		surface.SetDrawColor(180, 139, 255)
		surface.DrawRect(baseX + padding + 5, currentY + 30, barWidth * (argonite / maxArgonite), 10)

		currentY = currentY + itemHeight + padding
	end
end

hook.Add("HUDPaint", "mining_power_status", drawPowerStatus)