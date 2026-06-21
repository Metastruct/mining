module("ms", package.seeall)
Ores = Ores or {}

util.AddNetworkString("MA_Malfunction")

timer.Create("MA_MalfunctionCheck", Ores.Automation.MalfunctionCheckInterval, 0, function()
	for class in pairs(Ores.Automation.EntityClasses) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if ent:GetNWBool("IsMalfunctioning", false) then continue end
			if math.random() >= Ores.Automation.MalfunctionChance then continue end

			ent:SetNWBool("IsMalfunctioning", true)

			local owner = ent.CPPIGetOwner and ent:CPPIGetOwner()
			if IsValid(owner) then
				net.Start("MA_Malfunction")
				net.Send(owner)
			end
		end
	end
end)

hook.Add("EntityTakeDamage", "MA_MalfunctionRepair", function(ent, dmginfo)
	if not Ores.Automation.EntityClasses[ent:GetClass()] then return end
	if not ent:GetNWBool("IsMalfunctioning", false) then return end
	if bit.band(dmginfo:GetDamageType(), DMG_CLUB + DMG_SLASH) == 0 then return end

	ent:SetNWBool("IsMalfunctioning", false)
	ent:EmitSound("buttons/button17.wav", 100, math.random(90, 110))
end)
