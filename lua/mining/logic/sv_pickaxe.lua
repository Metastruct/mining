module("ms",package.seeall)

Ores = Ores or {}

function Ores.RefreshPlayerData(pl)
	Ores.GetSavedPlayerData(pl,function(data)
		pl:SetNWInt(Ores._nwPoints,data._points)

		for k,v in next,Ores.__PStats do
			pl:SetNWInt(Ores._nwPickaxePrefix..v.VarName,data[v.VarName])
		end
	end)
end