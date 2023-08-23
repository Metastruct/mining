ms.Ores.__R[666] = {
	AmbientLevel    = 78,
	AmbientPitch    = 65,
	AmbientSound    = "ambient/levels/citadel/field_loop3.wav",
	AmbientVolume   = 0.3,
	Health          = 10,
	Hidden          = true,
	HudColor        = Color(200, 0, 0),
	Name            = "Blood",
	PhysicalColor   = Color(55, 0, 0),
	SparkleInterval = 0.3,
	Worth           = 0,
	Suffix          = "",
}

if SERVER then
	hook.Add("EntityTakeDamage", "blood_ore", function(target, dmg)
		if not IsValid(target) then return end

		local atck = dmg:GetAttacker()
		if not IsValid(atck) then return end
		if not atck:IsPlayer() then return end

		local inflictor = dmg:GetInflictor()
		if not IsValid(inflictor) then return end
		if inflictor:GetClass() ~= "mining_pickaxe" then return end


		if not target:IsPlayer() then return end

		if not target.NextBloodOre then
			target.NextBloodOre = 0
		end

		if target:IsPlayer() and (target:GetInfoNum("cl_dmg_mode", 1) == 1 or target:HasGodMode() or (target.IsInZone and not target:IsInZone("cave"))) then
			return
		end

		if target.NextBloodOre < CurTime() then

			local blood = ents.Create("mining_rock")
			blood:SetRarity(666)
			blood:SetSize(math.random(0.1, 0.33))
			blood:SetPos(target:WorldSpaceCenter())
			blood:Spawn()
			blood:SetCollisionGroup(COLLISION_GROUP_WEAPON)
			blood:SetSize(math.random(0.1, 0.33))

			local phys = blood:GetPhysicsObject()
			if IsValid(phys) then
				phys:EnableMotion(true)
				phys:Wake()

				constraint.NoCollide(blood, target)
				timer.Simple(0, function()
					if not IsValid(phys) then return end
					phys:SetVelocity(VectorRand() * 500)
				end)
			end

			SafeRemoveEntityDelayed(blood, 20)
			target.NextBloodOre = CurTime() + 2
		end
	end)
end
