module("ms",package.seeall)

Ores = Ores or {}

local nwPrefix = "ms.Ores.Pickaxe."

function Ores.RefreshPickaxeValues(pl)
	local sID = pl:AccountID()

	for k,v in next,Ores.__PStats do
		local nw = nwPrefix..v.VarName
		pl:SetNWInt(nw,tonumber(pl:GetPData(nw..sID,0)))
	end
end