module("ms",package.seeall)

Ores = Ores or {}

local maxLevel = 50

local achievementMaxStatId = "mining_maxstat"

function Ores.RefreshPlayerData(pl)
	Ores.GetSavedPlayerDataAsync(pl,function(data)
		pl:SetNWInt(Ores._nwPoints,data._points)
		pl:SetNWFloat(Ores._nwMult,data._mult)

		local hasMaxedStat = false
		for k,v in next,Ores.__PStats do
			pl:SetNWInt(Ores._nwPickaxePrefix .. v.VarName,data[v.VarName])

			hasMaxedStat = hasMaxedStat or data[v.VarName] >= maxLevel
		end

		if hasMaxedStat and MetAchievements and MetAchievements.UnlockAchievement then
			MetAchievements.UnlockAchievement(pl,achievementMaxStatId)
		end
	end)
end