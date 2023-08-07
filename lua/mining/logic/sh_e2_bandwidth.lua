local tag = "mining_e2_chip_bandwidth"
local MAX_CUCKAGE = 300

if SERVER then
	local function only_e2_chips(ply)
		for ent, _ in pairs(ply._miningChipsOwned or {}) do
			if ent:GetClass() ~= "gmod_wire_expression2" then return false end
		end

		return true
	end

	local function get_e2data()
		local e2data = {}

		for _, e2 in pairs(ents.FindByClass("gmod_wire_expression2")) do
			local ops = e2.OverlayData.prfbench
			local owner = e2:GetPlayer()

			if not e2data[owner] then
				e2data[owner] = 0
			end

			e2data[owner] = e2data[owner] + ops
		end

		return e2data
	end

	local e2_owners = {}
	E2Lib.registerCallback("construct", function(data)
		if data.player:GetNWInt(tag, 0) <= 0 then
			data.player:SetNWInt(tag, 0)
		end

		e2_owners[data.player] = true

		timer.Simple(1, function()
			if not IsValid(data.player) then return end
			if not IsValid(data.enttity) then return end

			data.player._miningChipsOwned[data.entity] = false

			if only_e2_chips(data.player) and data.player:GetNWInt(tag, 0) > 0 then
				data.player._miningBlocked = false
			end
		end)
	end)

	hook.Add("EntityRemoved", tag, function(ent)
		if ent:GetClass() ~= "gmod_wire_expression2" then return end

		local owner = ent:GetPlayer()
		if not get_e2data()[owner] then
			e2_owners[owner] = nil
			--owner:SetNWInt(tag, -1)
		end
	end)

	hook.Add("PlayerReceivedOre", tag, function(ply, amount, rarity)
		if not e2_owners[ply] then return end

		local detonite_rarity = ms.Ores.Automation.GetOreRarityByName("Detonite")
		if rarity ~= detonite_rarity then return end

		local cur_detonite = ply:GetNWInt(tag, 0)
		if cur_detonite >= MAX_CUCKAGE then return end

		ply:SetNWInt(tag, math.min(cur_detonite + amount, MAX_CUCKAGE))
		ms.Ores.TakePlayerOre(ply, detonite_rarity, amount)
	end)

	hook.Add("OnEntityCreated", tag, function(ent)
		if ent:GetClass() ~= "mining_ore" then return end

		timer.Simple(0, function()
			local detonite_rarity = ms.Ores.Automation.GetOreRarityByName("Detonite")
			local rarity = ent:GetRarity()

			if rarity ~= detonite_rarity then return end

			local old_touch = ent.Touch
			function ent:Touch(e)
				if e:IsPlayer() and e._miningBlocked then
					self:Consume(e)
					return
				end

				old_touch(self, e)
			end
		end)
	end)

	timer.Create(tag, 10, 0, function()
		local data = get_e2data()
		for owner, total_ops in pairs(data) do
			local owned_detonite = owner:GetNWInt(tag, 0)
			local required_detonite = math.max(1, math.ceil(total_ops / 100))
			if owned_detonite >= required_detonite then
				print(owner, owned_detonite, required_detonite)
				owner:SetNWInt(tag, math.max(0, owned_detonite - required_detonite))

				if only_e2_chips(owner) then
					owner._miningBlocked = false
				end
			else
				for ent, _ in pairs(owner._miningChipsOwned or {}) do
					owner._miningChipsOwned[ent] = true
					ent:EmitSound("ambient/machines/thumper_shutdown1.wav")
				end

				if only_e2_chips(owner) then
					owner._miningBlocked = true
				end
			end
		end
	end)
end

if CLIENT then
	hook.Add("HUDPaint", tag, function()
		local ply = LocalPlayer()
		if not ply.IsInZone then return end
		if not ply:IsInZone("cave") then return end

		local owned_detonite = ply:GetNWInt(tag, -1)
		if owned_detonite < 0 then return end

		local X, Y = ScrW() * 3 / 4, ScrH() - 120

		surface.SetMaterial(ms.Ores.Automation.HudFrameMaterial)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(X, Y, 250, 110)

		surface.SetTextColor(255, 0, 0, 255)
		surface.SetFont("mining_automation_hud")

		surface.SetTextPos(X + 25, Y + 15)
		surface.DrawText("Chip Bandwidth")

		surface.SetTextPos(X + 25, Y + 55)
		surface.DrawText(("%d/%d"):format(owned_detonite,MAX_CUCKAGE))
	end)
end