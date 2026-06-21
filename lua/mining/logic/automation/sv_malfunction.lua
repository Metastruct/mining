module("ms", package.seeall)
Ores = Ores or {}

util.AddNetworkString("MA_Malfunction")

local function MA_StartMalfunctionFX(ent)
	local fire = ents.Create("env_fire")
	if not IsValid(fire) then return end

	fire:SetKeyValue("health", "100000")
	fire:SetKeyValue("firesize", "1")
	fire:SetKeyValue("firetype", "0")
	fire:SetKeyValue("startdisabled", "0")
	fire:SetPos(ent:GetPos() + Vector(0, 0, 30))
	fire:SetParent(ent)
	fire:Spawn()
	fire:Activate()

	ent.MalfunctionFire = fire
end

local function MA_StopMalfunctionFX(ent)
	if IsValid(ent.MalfunctionFire) then
		ent.MalfunctionFire:Remove()
	end
	ent.MalfunctionFire = nil
end

timer.Create("MA_MalfunctionCheck", Ores.Automation.MalfunctionCheckInterval, 0, function()
	for class in pairs(Ores.Automation.EntityClasses) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if ent:GetNWBool("IsMalfunctioning", false) then continue end
			if math.random() >= Ores.Automation.MalfunctionChance then continue end

			ent:SetNWBool("IsMalfunctioning", true)
			MA_StartMalfunctionFX(ent)

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
	MA_StopMalfunctionFX(ent)
	ent:EmitSound("buttons/button17.wav", 100, math.random(90, 110))
end)
