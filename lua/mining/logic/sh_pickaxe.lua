module("ms",package.seeall)

Ores = Ores or {}
Ores.__PStats = {
	-- When creating a new stat, please NEVER change a VarName once you've made it.
	{
		Name = "Hit Speed", -- 0.0096 * 50 (max: 0.12)
		Help = "How quickly you can swing the pickaxe.",
		VarName = "Delay",
		VarBase = 0.6,
		VarStep = -0.0096,
		VarFormat = "%s secs",
		CostStep = 750
	},
	{
		Name = "Range", -- 1.4 * 50 (max: 135)
		Help = "How far the pickaxe can reach when swung.",
		VarName = "Range",
		VarBase = 65,
		VarStep = 1.4,
		VarFormat = "%s hu",
		CostStep = 500
	},
	{
		Name = "Bonus Ore Chance", -- 0.045 * 50 (max: 2.25)
		Help = "The chance of additional ores being found when mining rocks.",
		VarName = "BonusChance",
		VarBase = 0,
		VarStep = 0.045,
		VarFormat = "%p%%",
		CostStep = 1400
	},
	{
		Name = "Precise Cut", -- 0.015 * 50 (max: 0.75)
		Help = "The chance of rocks being split into three when mined.",
		VarName = "FineCutChance",
		VarBase = 0,
		VarStep = 0.015,
		VarFormat = "%p%%",
		CostStep = 1200
	}
}

Ores._nwPrefix = "ms.Ores."
Ores._nwPoints = Ores._nwPrefix.."Points"
Ores._nwPickaxePrefix = Ores._nwPrefix.."Pickaxe."

function Ores.StatFormat(k,level)
	local stat = Ores.__PStats[k]
	if not stat then return "" end

	local var = stat.VarBase+(stat.VarStep*level)

	return stat.VarFormat:gsub("%%p",var*100):format(var)
end

function Ores.StatPrice(k,level)
	local stat = Ores.__PStats[k]
	if not stat then return 0 end

	return stat.CostStep*level
end