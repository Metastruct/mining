module("ms", package.seeall)
Ores = Ores or {}

resource.AddFile("materials/mining/automation/hud_frame.png")

Ores.Automation = Ores.Automation or {
	BatteryCapacity = 150,
	BombCapacity = 5,
	BombDetonationTime = 4,
	TextDrawingDistance = 150,
	BaseOreProductionRate = 10, -- 1 per 10 seconds
	EnergyMaterial = Material("models/props_combine/coredx70"),
	EntityClasses = {
		ma_storage_v2 = true,
		ma_drill_v2 = true,
		ma_transformer_v2 = true,
		ma_smelter_v2 = true,
		ma_minter_v2 = true,
		ma_oil_extractor_v2 = true,
		ma_gen_v2 = true,
		ma_chip_router_v2 = true,
		ma_drone_controller_v2 = true,
		ma_bomb_v2 = true,
		ma_refinery = true,
	},
	GraphUnit = 40,
	GraphHeightMargin = 75,
	HudPadding = 10,
	HudSepColor = Color(72, 72, 72, 255),
	HudActionColor = Color(255, 125, 0, 255),
	IngotWorth = 1.2,
	IngotSize = 5,
	OilExtractionRate = 10 * 60, -- 1 fuel tank per 60 seconds
}

if Ores.Automation.EnergyMaterial:IsError() then
	Ores.Automation.EnergyMaterial = Material("effects/tvscreen_noise001a")
end