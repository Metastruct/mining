module("ms", package.seeall)
Ores = Ores or {}

resource.AddFile("resource/fonts/Sevastopol-Interface.ttf")
resource.AddFile("resource/fonts/Ghastly-Panic.ttf")

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
		ma_drone_controller_v2 = true,
		ma_bomb_v2 = true,
		ma_refinery = true,
		ma_merger_v2 = true,
	},
	GraphUnit = 40,
	GraphHeightMargin = 75,
	HudPadding = 10,
	HudSepColor = Color(72, 72, 72, 255),
	HudActionColor = Color(255, 125, 0, 255),
	IngotWorth = 1.2,
	IngotSize = 5,
	OilExtractionRate = 10 * 60, -- 1 fuel tank per 60 seconds
	UnlockData = { -- indexes in this table are multiplied by 10
		[1] = { "ma_drill_v2", "ma_gen_v2", "ma_transformer_v2", "ma_storage_v2" },
		[2] = { "ma_merger_v2"  },
		[3] = { "ma_oil_extractor_v2", "ma_smelter_v2" },
		[4] = { "ma_minter_v2", "ma_refinery" },
		[5] = { "ma_drone_controller_v2" },
	},
	PurchaseData = {
		ma_drill_v2 = 10000,
		ma_gen_v2 = 40000,
		ma_transformer_v2 = 20000,
		ma_storage_v2 = 5000,
		ma_merger_v2 = 1000,
		ma_oil_extractor_v2 = 25000,
		ma_smelter_v2 = 60000,
		ma_minter_v2 = 10000,
		ma_refinery = 80000,
		ma_drone_controller_v2 = 90000,
	}
}

if Ores.Automation.EnergyMaterial:IsError() then
	Ores.Automation.EnergyMaterial = Material("effects/tvscreen_noise001a")
end