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
		CostStep = 400
	},
	{
		Name = "Range", -- 1.5 * 50 (max: 140)
		Help = "How far the pickaxe can reach when swung.",
		VarName = "Range",
		VarBase = 65,
		VarStep = 1.5,
		VarFormat = "%s hu",
		CostStep = 300
	},
	{
		Name = "Bonus Ore Chance", -- 0.045 * 50 (max: 2.25)
		Help = "The chance of additional ores being found when mining rocks.",
		VarName = "BonusChance",
		VarBase = 0,
		VarStep = 0.045,
		VarFormat = "%p%%",
		CostStep = 800
	},
	{
		Name = "Precise Cut", -- 0.015 * 50 (max: 0.75)
		Help = "The chance of rocks being split into three when mined.",
		VarName = "FineCutChance",
		VarBase = 0,
		VarStep = 0.015,
		VarFormat = "%p%%",
		CostStep = 650
	},
	{
		Name = "Magic Find", -- 0.005 * 50 (max: 0.25)
		Help = "The chance of a higher rarity ore being found from a rock.",
		VarName = "MagicFindChance",
		VarBase = 0,
		VarStep = 0.005,
		VarFormat = "%p%%",
		CostStep = 700
	},
	{
		Name = "Shockwave", -- 1.9 * 50 (max: 95)
		Help = "The size of the shockwave created when you hit the ground.",
		VarName = "ShockwaveRange",
		VarBase = 0,
		VarStep = 1.9,
		VarFormat = "%s hu",
		CostStep = 600
	}
}

-- How to calculate total spending from Lvls 1-50:
-- n = 50 (max level)
-- total = n * (n + 1) * 0.5
-- perma bonus = (costStep * total) * 0.00000015 (rounded to 3 decs)

Ores._nwPrefix = "ms.Ores."
Ores._nwPoints = Ores._nwPrefix.."Points"
Ores._nwMult = Ores._nwPrefix.."Mult"
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
