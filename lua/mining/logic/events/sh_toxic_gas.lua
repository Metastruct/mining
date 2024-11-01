module("ms", package.seeall)
Ores = Ores or {}

if SERVER then
	local TOXIC_GAS_CHANCE = 3 -- 3% chance
	local TOXIC_GAS_DAMAGE = 10
	local TOXIC_GAS_INTERVAL = 1
	local TOXIC_GAS_DURATION = 60
	local TOXIC_GAS_RADIUS = 300

	util.AddNetworkString("ToxicGasEffect")

	local function createToxicGas(pos, ang)
		local gasCloud = ents.Create("env_smokestack")
		if not IsValid(gasCloud) then return end

		gasCloud:SetPos(pos)
		gasCloud:SetAngles(ang)
		gasCloud:SetKeyValue("InitialState", "1")
		gasCloud:SetKeyValue("WindAngle", "0 " .. ang.y .. " 0") -- Only use yaw for wind direction
		gasCloud:SetKeyValue("WindSpeed", "50") -- Reduced wind speed for better control
		gasCloud:SetKeyValue("rendercolor", "120 180 70")
		gasCloud:SetKeyValue("renderamt", "100")
		gasCloud:SetKeyValue("SmokeMaterial", "particle/particle_smokegrenade")
		gasCloud:SetKeyValue("BaseSpread", tostring(TOXIC_GAS_RADIUS / 2))
		gasCloud:SetKeyValue("SpreadSpeed", "10")
		gasCloud:SetKeyValue("Speed", "100")
		gasCloud:SetKeyValue("StartSize", "100")
		gasCloud:SetKeyValue("EndSize", "200")
		gasCloud:SetKeyValue("Rate", "15")
		gasCloud:SetKeyValue("JetLength", tostring(TOXIC_GAS_RADIUS))
		gasCloud:Spawn()
		gasCloud:Activate()
		gasCloud:EmitSound("ambient/gas/steam2.wav", 75, 100)
		gasCloud:SetKeyValue("classname", "Toxic Gas Cloud")

		local endTime = CurTime() + TOXIC_GAS_DURATION
		local nextDamage = CurTime()

		hook.Add("Think", "ToxicGasThink_" .. gasCloud:EntIndex(), function()
			if CurTime() > endTime then
				if IsValid(gasCloud) then
					gasCloud:StopSound("ambient/gas/steam2.wav")
					gasCloud:Remove()
				end

				hook.Remove("Think", "ToxicGasThink_" .. gasCloud:EntIndex())
				return
			end

			if CurTime() >= nextDamage then
				for _, ply in ipairs(ents.FindInSphere(pos, TOXIC_GAS_RADIUS)) do
					if ply:IsPlayer() then
						-- Apply resistance based on player's toxic resistance level
						local resistance = ply:GetNWInt("ms.Ores.ToxicResistance", 0)
						local damage = TOXIC_GAS_DAMAGE * (1 - (resistance / 50))

						if damage > 0 then
							local dmg = DamageInfo()
							dmg:SetDamage(damage)
							dmg:SetDamageType(DMG_POISON)
							dmg:SetAttacker(gasCloud)
							dmg:SetInflictor(gasCloud)

							local takeDamageInfo = ply.ForceTakeDamageInfo or ply.TakeDamageInfo
							takeDamageInfo(ply, dmg)

							ply:EmitSound("player/pl_pain" .. math.random(5, 7) .. ".wav")

							net.Start("ToxicGasEffect")
							net.Send(ply)
						end
					end

				end
				nextDamage = CurTime() + TOXIC_GAS_INTERVAL
			end
		end)

		timer.Simple(TOXIC_GAS_DURATION, function()
			if IsValid(gasCloud) then
				gasCloud:StopSound("ambient/gas/steam2.wav")
				gasCloud:Remove()
			end
		end)
	end

	-- Hook into rock creation similar to mine collapse
	hook.Add("OnEntityCreated", "mining_toxic_gas", function(ent)
		if not IsValid(ent) then return end
		if ent:GetClass() ~= "mining_rock" then return end

		timer.Simple(0, function()
			if not IsValid(ent) then return end
			if ent:GetClass() == "mining_rock" and not ent.OriginalRock then return end

			if math.random(0, 100) <= TOXIC_GAS_CHANCE then
				ent.GasIncident = true
			end
		end)
	end)

	hook.Add("EntityTakeDamage", "mining_toxic_gas", function(ent)
		if not ent.GasIncident then return end
		if not ent.OriginalRock then return end

		ent:EmitSound("ambient/gas/steam_loop1.wav", 60, math.random(90, 110))
		timer.Simple(math.Rand(0.1, 0.3), function()
			if IsValid(ent) then
				ent:StopSound("ambient/gas/steam_loop1.wav")
			end
		end)

		local effectdata = EffectData()
		effectdata:SetOrigin(ent:GetPos())
		effectdata:SetScale(10)
		util.Effect("GlassImpact", effectdata, true, true)
	end)

	hook.Add("PlayerDestroyedMiningRock", "mining_toxic_gas", function(ply, rock, inflictor)
		if not rock.GasIncident then return end
		if not rock.OriginalRock then return end
		if ply.IsInZone and not ply:IsInZone("cave") then return end
		if IsValid(inflictor) and not inflictor:IsWeapon() then return end

		rock:StopSound("ambient/gas/steam_loop1.wav")
		local direction = (rock:WorldSpaceCenter() - ply:EyePos()):Angle()
		createToxicGas(rock:WorldSpaceCenter(), direction)
	end)
end

if CLIENT then
	net.Receive("ToxicGasEffect", function()
		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local startTime = CurTime()
		local effectDuration = 1.5

		hook.Add("RenderScreenspaceEffects", "ToxicGasOverlay", function()
			local progress = math.Clamp((CurTime() - startTime) / effectDuration, 0, 1)
			local intensity = math.sin(progress * math.pi) * 0.15

			DrawColorModify({
				["$pp_colour_addr"] = 0,
				["$pp_colour_addg"] = 0.1,
				["$pp_colour_addb"] = 0,
				["$pp_colour_brightness"] = -intensity * 0.5,
				["$pp_colour_contrast"] = 1 + intensity,
				["$pp_colour_colour"] = 1 - intensity * 0.5,
			})

			DrawMaterialOverlay("effects/water_warp01", intensity)
			DrawMotionBlur(0.1, 0.8, 0.01)

			if progress >= 1 then
				hook.Remove("RenderScreenspaceEffects", "ToxicGasOverlay")
			end
		end)
	end)
end