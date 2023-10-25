local Tag = "mining_blood_ore"

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

local ITEMS = {
	skull = {
		name = "Skull",
		model = "models/Gibs/HGIBS.mdl",
		price = 10,
		description = "Looks like a humanoid skull, there are still some muscle tissues left indicating its owner perished not too long ago..."
	},
	spine = {
		name = "Spine",
		model = "models/Gibs/HGIBS_spine.mdl",
		price = 20,
		description = "Old remains of what looks like a human spine, you don't even dare to imagine how it was obtained."
	},
	rib = {
		name = "Rib",
		model = "models/Gibs/HGIBS_rib.mdl",
		price = 5,
		description = "A piece of a rib cage, its origin is unknown but somehow even if you could know, you wouldnt want to know."
	},
	soul = {
		name = "Your Soul",
		model = "models/props_lab/huladoll.mdl",
		price = 9999,
		description = "WAIT, WHAT?!"
	}
}

if SERVER then
	util.AddNetworkString(Tag)
	util.AddNetworkString(Tag .. "_npc")

	net.Receive(Tag, function(_, ply)
		local itemId = net.ReadString()
		local npc = net.ReadEntity()

		if not ITEMS[itemId] then return end
		if not IsValid(npc) then return end
		if npc:GetClass() ~= "lua_npc" and npc:GetClass() ~= "player" then return end

		local item = ITEMS[itemId]
		local curBlood = ms.Ores.GetPlayerOre(ply, 666)
		if item.price > curBlood then
			ply:Kill()
			SafeRemoveEntity(npc)
			return
		end

		local inv = ply.GetInventory and ply:GetInventory()
		if itemId == "soul" and inv and inv.soul and inv.soul > 0 then return end

		if itemId == "soul" then
			hook.Run("SoulGottenBack", ply)
		end

		ms.Ores.TakePlayerOre(ply, 666, item.price)

		if ply.GiveItem then
			ply:GiveItem(itemId, 1, "bloodgod")
		end

		SafeRemoveEntity(npc)
	end)

	local maxDist = 300 * 300
	hook.Add("KeyPress", Tag, function(ply,key)
		if key ~= IN_USE then return end

		local npc = ply:GetEyeTrace().Entity
		if not npc:IsValid() then return end

		if npc.role == "bloodgod" and npc:GetPos():DistToSqr(ply:GetPos()) <= maxDist then
			net.Start(Tag)
			net.WriteEntity(npc)
			net.Send(ply)

			if ply.LookAt then
				ply:LookAt(npc, 1, 2)
			end
		end
	end)

	hook.Add("EntityTakeDamage", Tag, function(target, dmg)
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

		if target:IsPlayer() and (target:GetInfoNum("cl_dmg_mode", 1) == 1 or target:HasGodMode()) then return end

		if target.NextBloodOre < CurTime() then
			local blood = ents.Create("mining_rock")
			blood:SetRarity(666)
			blood:SetSize(math.random(0.1, 0.33))
			blood:SetPos(target:WorldSpaceCenter())
			blood:Spawn()
			blood:SetCollisionGroup(COLLISION_GROUP_WEAPON)
			blood:SetSize(math.random(0.1, 0.33))
			blood:SetMaterial("models/flesh")
			blood:EmitSound(")physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav")

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

	local nextBloodGod = 0
	local BLOOD_GOD_NPC
	hook.Add("PlayerReceivedOre", Tag, function(ply, _, rarity)
		if rarity ~= 666 then return end

		local count = ms.Ores.GetPlayerOre(ply, 666)
		if count >= 66 and nextBloodGod >= CurTime() and not IsValid(BLOOD_GOD_NPC) then
			local pos = ply:GetPos() + ply:GetForward() * 200 + Vector(0, 0, 50)
			if util.IsInWorld(pos) then
				BLOOD_GOD_NPC = ents.Create("lua_npc")
				BLOOD_GOD_NPC:SetMaterial("models/debug/debugwhite")
				BLOOD_GOD_NPC:SetColor(Color(0, 0, 0, 255))
				BLOOD_GOD_NPC:SetPos(pos)
				BLOOD_GOD_NPC:Spawn()
				BLOOD_GOD_NPC:DropToFloor()

				BLOOD_GOD_NPC.role = "bloodgod"

				function BLOOD_GOD_NPC:OnTakeDamage(dmg)
					local atck = dmg:GetAttacker()
					if IsValid(atck) then
						if atck.ForceTakeDamageInfo then
							atck:ForceTakeDamageInfo(dmg)
						else
							atck:TakeDamageInfo(dmg)
						end
					end
				end

				if ply.LookAt then
					ply:LookAt(BLOOD_GOD_NPC, 3)
				end
			end
		end

		if not IsValid(BLOOD_GOD_NPC) then return end

		nextBloodGod = CurTime() + (60 * 60) -- in an hour

		for _, rock in ipairs(ents.FindByClass("mining_rock")) do
			rock:SetRarity(666)
		end

		ms.Ores.SendChatMessage(player.GetAll(), "An otherwordly creature appeared... Best be careful.")

		net.Start(Tag .. "_npc")
		net.WriteInt(BLOOD_GOD_NPC:EntIndex(), 32)
		net.Broadcast(ply)
	end)

	hook.Add("OnEntityCreated", Tag, function(ent)
		if not IsValid(BLOOD_GOD_NPC) then return end

		if ent:GetClass() == "mining_rock" then
			timer.Simple(0, function()
				if not IsValid(ent) then return end

				ent:SetRarity(666)
			end)
		end
	end)
end

if CLIENT then
	local worldMat = CreateMaterial("world_flesh_" .. FrameNumber(), "LightmappedGeneric", {
		["$basetexture"] = "models/flesh",
	})

	local atmosSound = "sound/ambient/atmosphere/corridor.wav"
	local colorSettings = {
		["$pp_colour_addr"] = 0.04,
		["$pp_colour_addg"] = 0,
		["$pp_colour_addb"] = 0,
		["$pp_colour_brightness"] = 0,
		["$pp_colour_contrast"] = 1,
		["$pp_colour_colour"] = 3,
		["$pp_colour_mulr"] = 0,
		["$pp_colour_mulg"] = 0,
		["$pp_colour_mulb"] = 0
	}

	local atmosStation
	local function start_flesh_world()
		sound.PlayFile(atmosSound, "noplay", function(station, err_code, err_str)
			if IsValid(station) then
				station:EnableLooping(true)
				station:Play()
				atmosStation = station
			end
		end)

		hook.Add("RenderScene", Tag, function()
			render.WorldMaterialOverride(worldMat)
			local dlight = DynamicLight(LocalPlayer():EntIndex())

			if dlight then
				dlight.pos = LocalPlayer():EyePos()
				dlight.r = 255
				dlight.g = 0
				dlight.b = 0
				dlight.brightness = 5
				dlight.decay = 1000
				dlight.size = 400
				dlight.dietime = CurTime() + 1
			end
		end)

		hook.Add("RenderScreenspaceEffects", Tag, function()
			DrawColorModify(colorSettings)
			DrawBloom(0.65, 2, 9, 9, 1, 1, 1, 1, 1)
			DrawToyTown(2, ScrH() / 2)
			DrawMotionBlur(0.4, 0.8, 0.01)
		end)

		hook.Add("PlayerFootstep", Tag, function(ply, _, _, _, _, _)
			ply:EmitSound("npc/antlion_grub/squashed.wav", 20, math.random(50, 75))

			return true
		end)
	end

	local function stop_flesh_world()
		hook.Remove("RenderScene", Tag)
		hook.Remove("RenderScreenspaceEffects", Tag)
		hook.Remove("PlayerFootstep", Tag)
		hook.Remove("Think", Tag)
		hook.Remove("HUDPaint", Tag)

		if IsValid(atmosStation) then
			atmosStation:Stop()
		end
	end

	surface.CreateFont(Tag .. "_big", {
		font = "Arial",
		extended = true,
		size = 100,
	})

	surface.CreateFont(Tag, {
		font = "Roboto",
		extended = true,
		size = 30,
	})

	local function trigger_menu(npc)
		local hoveringSoulBtn = false
		local bloodTexts = {}
		local nextBloodText = 0

		local function draw_soul_btn_background(offsetx, offsety)
			local time = CurTime()

			if hoveringSoulBtn and time >= nextBloodText then
				local count = math.random(2, 8)

				for _ = 1, count do
					local lifetime = math.random(1, 3)

					table.insert(bloodTexts, {
						x = math.random(10, ScrW() - 10) - offsetx,
						y = math.random(10, ScrH() - 10) - offsety,
						endtime = CurTime() + lifetime,
						lifetime = lifetime,
						red = math.random() * 255,
					})
				end

				surface.PlaySound("ambient/hallow0" .. math.random(4, 8) .. ".wav")
				nextBloodText = time + 0.5
			end

			for i, textData in ipairs(bloodTexts) do
				local diff = textData.endtime - CurTime()
				local unit = 255 / textData.lifetime
				local alpha = (diff * unit)

				if alpha <= 0 then
					table.remove(bloodTexts, i)
					continue
				end

				surface.SetFont(Tag .. "_big")
				surface.SetTextPos(textData.x, textData.y)
				surface.SetTextColor(textData.red, 0, 0, alpha)
				surface.DrawText("BLOOD")
			end
		end

		local title = ""
		for _, code in utf8.codes("blood god") do
			title = title .. "/" .. tostring(code)
		end

		local frame = vgui.Create("DFrame")
		frame:SetSize(800, 600)
		frame:Center()
		frame:SetTitle(title)
		frame:MakePopup()

		function frame:Paint(w, h)
			surface.SetDrawColor(55, 0, 0, 225)
			surface.DrawRect(0, 0, w, h)
			surface.SetDrawColor(155, 0, 0, 155)
			surface.DrawRect(0, 0, w, 25)
		end

		local sentences = {"Dⲟ ⲩⲟu ⲧⲁsⲧⲉ ⲧⲏⲉ sⲥꞅⲉⲁⲙs ⲟf ⲧⲏⲉ ⲥꞅⲓⲙsⲟⲛ sⲏⲁdⲟⲱs ⲱⲓⲧⲏⲓⲛ ⲩⲟuꞅ drⲉⲁⲙs, mⲟrⲧⲁl?", "Ⲱⲏⲓsⲣⲉꞅ ⲧⲟ ⲧⲏⲉ ⲙⲟⲟⲛlⲉss vⲟid ⲧⲏⲉ sⲉⲥꞅⲉⲧs ⲟf ⲩⲟuꞅ ⲙⲟsⲧ ⲥⲏⲉꞅⲓsⲏⲉd dⲉsⲣⲁⲓꞅ.",}

		local header = frame:Add("DLabel")
		header:Dock(TOP)
		header:SetWrap(true)
		header:SetTall(50)
		header:SetContentAlignment(5)
		header:SetText("")

		local text = sentences[math.random(#sentences)]
		function header:Paint(w, h)
			surface.SetDrawColor(0, 0, 0, 155)
			surface.DrawRect(0, 0, w, h)
			surface.SetFont(Tag)
			surface.SetTextColor(255, 255, 255, 255)
			local tw, th = surface.GetTextSize(text)
			surface.SetTextPos(w / 2 - tw / 2, h / 2 - th / 2)
			surface.DrawText(text)
		end

		local itemsContainer = frame:Add("DPanel")
		itemsContainer:DockMargin(0, 10, 0, 0)
		itemsContainer:Dock(FILL)

		function itemsContainer:Paint(w, h)
			surface.SetDrawColor(0, 0, 0, 155)
			surface.DrawRect(0, 0, w, h)
		end

		local inv = LocalPlayer().GetInventory and LocalPlayer():GetInventory()
		for itemId, item in pairs(ITEMS) do
			if itemId == "soul" and inv and inv.soul and inv.soul and inv.soul.count > 0 then continue end

			local itemRow = itemsContainer:Add("DPanel")
			itemRow:DockMargin(0, 0, 0, 10)
			itemRow:DockPadding(0, 0, 5, 0)
			itemRow:Dock(TOP)
			itemRow:SetTall(100)

			function itemRow:Paint(w, h)
				surface.SetDrawColor(0, 0, 0, 155)
				surface.DrawRect(0, 0, w, h)
				surface.SetDrawColor(155, 0, 0, 255)
				surface.DrawOutlinedRect(0, 0, w, h)
			end

			local purchaseBtn = itemRow:Add("DButton")
			purchaseBtn:Dock(RIGHT)
			purchaseBtn:DockMargin(5, 20, 5, 20)
			purchaseBtn:SetWide(150)
			purchaseBtn:SetText(("Exchange (x%d blood)"):format(item.price))
			purchaseBtn:SetTextColor(color_white)

			local black_color = Color(0, 0, 0, 255)
			function purchaseBtn:Paint(w, h)
				if item.name == "Your Soul" then
					hoveringSoulBtn = self:IsHovered()

					if self:IsHovered() then
						self:SetFont(Tag)
						self:SetTextColor(black_color)
						self:SetText("SACRIFICE")

						Derma_DrawBackgroundBlur(self, 0)

						local x, y = self:GetPos()
						x, y = self:LocalToScreen(x, y)

						surface.DisableClipping(true)
							draw_soul_btn_background(x, y)
							surface.SetDrawColor(255, 0, 0, 255)
							local baseMovement = math.sin(CurTime() * 100)
							surface.DrawRect(baseMovement * 5 - 15, baseMovement * 5 - 15, w + 30, h + 30)
						surface.DisableClipping(false)

						return
					else
						self:SetFont("DermaDefault")
						self:SetTextColor(color_white)
						self:SetText(("Exchange (x%d blood)"):format(item.price))
					end
				end

				surface.SetDrawColor(155, 0, 0, self:IsHovered() and 255 or 155)
				surface.DrawRect(0, 0, w, h)
			end

			function purchaseBtn:DoClick()
				net.Start(Tag)
				net.WriteString(itemId)
				net.WriteEntity(npc)
				net.SendToServer()

				frame:Remove()
				surface.PlaySound("ambient/voices/squeal1.wav")
				surface.PlaySound("ambient/atmosphere/cave_hit2.wav")
			end

			local itemView = itemRow:Add("DModelPanel")
			itemView:Dock(LEFT)
			itemView:SetModel(item.model)
			itemView:SetWide(100)
			--function itemView:LayoutEntity(ent) return end
			local ent = itemView:GetEntity()
			local pos = ent:GetPos()
			local ang = ent:GetAngles()
			local tab = PositionSpawnIcon(ent, pos, true)
			ent:SetAngles(ang)

			if tab then
				itemView:SetCamPos(tab.origin)
				itemView:SetFOV(tab.fov)
				itemView:SetLookAng(tab.angles)
			end

			function itemView:PaintOver(w, h)
				surface.SetDrawColor(155, 0, 0, 255)
				surface.DrawOutlinedRect(0, 0, w, h)
			end

			local itemName = itemRow:Add("DLabel")
			itemName:Dock(TOP)
			itemName:DockMargin(10, 10, 0, 0)
			itemName:SetFont(Tag)
			itemName:SetText(item.name:upper())
			itemName:SetTextColor(Color(255, 0, 0))

			local itemDesc = itemRow:Add("DLabel")
			itemDesc:Dock(FILL)
			itemDesc:DockMargin(10, 10, 0, 0)
			itemDesc:SetFont("Trebuchet18")
			itemDesc:SetText(item.description)
			itemDesc:SetTextColor(color_white)
			itemDesc:SetWrap(true)
		end

		local function exitMenu()
			hoveringSoulBtn = false
			surface.PlaySound("ambient/atmosphere/cave_hit2.wav")
		end

		function frame:OnRemove()
			exitMenu()
		end
	end

	net.Receive(Tag, function()
		local npc = net.ReadEntity()
		trigger_menu(npc)
	end)

	local DEMON_OUTFIT = {
		[1] = {
			["children"] = {
				[1] = {
					["children"] = {
					},
					["self"] = {
						["Skin"] = 0,
						["UniqueID"] = "2770783759",
						["NoLighting"] = false,
						["BlendMode"] = "",
						["AimPartUID"] = "",
						["Materials"] = "",
						["Name"] = "",
						["LevelOfDetail"] = -1,
						["NoTextureFiltering"] = false,
						["InverseKinematics"] = false,
						["PositionOffset"] = Vector(0, 0, 0),
						["NoCulling"] = false,
						["Brightness"] = 1,
						["DrawOrder"] = 0,
						["TargetEntityUID"] = "",
						["DrawShadow"] = false,
						["Alpha"] = 1,
						["Material"] = "",
						["CrouchingHullHeight"] = 36,
						["Model"] = "models/humans/group01/male_06.mdl",
						["ModelModifiers"] = "",
						["NoDraw"] = false,
						["IgnoreZ"] = false,
						["HullWidth"] = 32,
						["Translucent"] = false,
						["Position"] = Vector(0, 0, 0),
						["LegacyTransform"] = false,
						["ClassName"] = "entity2",
						["Hide"] = false,
						["IsDisturbing"] = false,
						["Scale"] = Vector(1, 1, 1),
						["Color"] = Vector(0, 0, 0),
						["EditorExpand"] = true,
						["Size"] = 0.9,
						["Invert"] = false,
						["Angles"] = Angle(0, 0, 0),
						["AngleOffset"] = Angle(0, 0, 0),
						["EyeTargetUID"] = "",
						["StandingHullHeight"] = 72,
					},
				},
				[2] = {
					["children"] = {
						[1] = {
							["children"] = {
								[1] = {
									["children"] = {
										[1] = {
											["children"] = {
											},
											["self"] = {
												["DrawOrder"] = 0,
												["UniqueID"] = "2134076114",
												["TargetEntityUID"] = "",
												["AimPartName"] = "",
												["Bone"] = "head",
												["BlendMode"] = "",
												["Position"] = Vector(3.8330078125, -4.22998046875, -0.0001220703125),
												["AimPartUID"] = "",
												["NoTextureFiltering"] = false,
												["Hide"] = false,
												["Name"] = "",
												["Translucent"] = false,
												["IgnoreZ"] = false,
												["Angles"] = Angle(-0.00025783968158066, -63.714435577393, -2.2625004930887e-05),
												["AngleOffset"] = Angle(0, 0, 0),
												["PositionOffset"] = Vector(0, 0, 0),
												["IsDisturbing"] = false,
												["ClassName"] = "clip2",
												["EyeAngles"] = false,
												["EditorExpand"] = false,
											},
										},
									},
									["self"] = {
										["Skin"] = 0,
										["UniqueID"] = "3524632983",
										["NoLighting"] = false,
										["AimPartName"] = "",
										["IgnoreZ"] = false,
										["AimPartUID"] = "",
										["Materials"] = "",
										["Name"] = "",
										["LevelOfDetail"] = 0,
										["NoTextureFiltering"] = false,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["EyeAngles"] = false,
										["DrawOrder"] = 0,
										["TargetEntityUID"] = "",
										["Alpha"] = 1,
										["Material"] = "models/debug/debugwhite",
										["Invert"] = false,
										["ForceObjUrl"] = false,
										["Bone"] = "head",
										["Angles"] = Angle(16.392793655396, -7.5645798460755e-06, 90.000015258789),
										["AngleOffset"] = Angle(0, 0, 0),
										["BoneMerge"] = false,
										["Color"] = Vector(0, 0, 0),
										["Position"] = Vector(-2.5955810546875, 3.710693359375, 2.99609375),
										["ClassName"] = "model2",
										["Brightness"] = 1,
										["Hide"] = false,
										["NoCulling"] = false,
										["Scale"] = Vector(1.6000000238419, 1.1000000238419, 1.1000000238419),
										["LegacyTransform"] = false,
										["EditorExpand"] = false,
										["Size"] = 0.75,
										["ModelModifiers"] = "",
										["Translucent"] = true,
										["BlendMode"] = "",
										["EyeTargetUID"] = "",
										["Model"] = "models/player/items/soldier/skull_horns_b3.mdl",
									},
								},
								[2] = {
									["children"] = {
										[1] = {
											["children"] = {
											},
											["self"] = {
												["DrawOrder"] = 0,
												["UniqueID"] = "3663974720",
												["TargetEntityUID"] = "",
												["AimPartName"] = "",
												["Bone"] = "head",
												["BlendMode"] = "",
												["Position"] = Vector(6.6962890625, 3.434326171875, -0.000732421875),
												["AimPartUID"] = "",
												["NoTextureFiltering"] = false,
												["Hide"] = false,
												["Name"] = "",
												["Translucent"] = false,
												["IgnoreZ"] = false,
												["Angles"] = Angle(0.00026296227588318, 69.596160888672, -0.00026466982671991),
												["AngleOffset"] = Angle(0, 0, 0),
												["PositionOffset"] = Vector(0, 0, 0),
												["IsDisturbing"] = false,
												["ClassName"] = "clip2",
												["EyeAngles"] = false,
												["EditorExpand"] = false,
											},
										},
									},
									["self"] = {
										["Skin"] = 0,
										["UniqueID"] = "3047609664",
										["NoLighting"] = false,
										["AimPartName"] = "",
										["IgnoreZ"] = false,
										["AimPartUID"] = "",
										["Materials"] = "",
										["Name"] = "",
										["LevelOfDetail"] = 0,
										["NoTextureFiltering"] = false,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["EyeAngles"] = false,
										["DrawOrder"] = 0,
										["TargetEntityUID"] = "",
										["Alpha"] = 1,
										["Material"] = "models/debug/debugwhite",
										["Invert"] = false,
										["ForceObjUrl"] = false,
										["Bone"] = "head",
										["Angles"] = Angle(-14.536490440369, -2.2932224965189e-05, 89.999946594238),
										["AngleOffset"] = Angle(0, 0, 0),
										["BoneMerge"] = false,
										["Color"] = Vector(0, 0, 0),
										["Position"] = Vector(-2.18798828125, 2.947021484375, -2.9091796875),
										["ClassName"] = "model2",
										["Brightness"] = 1,
										["Hide"] = false,
										["NoCulling"] = false,
										["Scale"] = Vector(1.6000000238419, 1.1000000238419, 1.1000000238419),
										["LegacyTransform"] = false,
										["EditorExpand"] = false,
										["Size"] = 0.75,
										["ModelModifiers"] = "",
										["Translucent"] = true,
										["BlendMode"] = "",
										["EyeTargetUID"] = "",
										["Model"] = "models/player/items/soldier/skull_horns_b3.mdl",
									},
								},
								[3] = {
									["children"] = {
										[1] = {
											["children"] = {
											},
											["self"] = {
												["DrawOrder"] = 2,
												["UniqueID"] = "3151738601",
												["TargetEntityUID"] = "",
												["Alpha"] = 1,
												["SizeX"] = 30,
												["SizeY"] = 1,
												["NoTextureFiltering"] = false,
												["Bone"] = "head",
												["BlendMode"] = "",
												["Translucent"] = true,
												["IgnoreZ"] = true,
												["IsDisturbing"] = false,
												["Position"] = Vector(0, -0.3310546875, -0.001708984375),
												["AimPartUID"] = "",
												["AngleOffset"] = Angle(0, 0, 0),
												["Hide"] = false,
												["Name"] = "",
												["AimPartName"] = "",
												["EditorExpand"] = false,
												["Angles"] = Angle(0, 0, 0),
												["Size"] = 1,
												["PositionOffset"] = Vector(0, 0, 0),
												["Color"] = Vector(255, 0, 0),
												["ClassName"] = "sprite",
												["EyeAngles"] = false,
												["SpritePath"] = "sprites/glow04_noz",
											},
										},
										[2] = {
											["children"] = {
											},
											["self"] = {
												["DrawOrder"] = 2,
												["UniqueID"] = "227651118",
												["TargetEntityUID"] = "",
												["Alpha"] = 1,
												["SizeX"] = 5,
												["SizeY"] = 5,
												["NoTextureFiltering"] = false,
												["Bone"] = "head",
												["BlendMode"] = "",
												["Translucent"] = true,
												["IgnoreZ"] = true,
												["IsDisturbing"] = false,
												["Position"] = Vector(0, -0.3310546875, -0.001708984375),
												["AimPartUID"] = "",
												["AngleOffset"] = Angle(0, 0, 0),
												["Hide"] = false,
												["Name"] = "",
												["AimPartName"] = "",
												["EditorExpand"] = false,
												["Angles"] = Angle(0, 0, 0),
												["Size"] = 1,
												["PositionOffset"] = Vector(0, 0, 0),
												["Color"] = Vector(255, 0, 0),
												["ClassName"] = "sprite",
												["EyeAngles"] = false,
												["SpritePath"] = "sprites/glow04_noz",
											},
										},
									},
									["self"] = {
										["Skin"] = 0,
										["Invert"] = false,
										["LightBlend"] = 1,
										["CellShade"] = 0,
										["AimPartName"] = "",
										["IgnoreZ"] = false,
										["AimPartUID"] = "",
										["Passes"] = 1,
										["Name"] = "default 1",
										["Angles"] = Angle(0, 0, 0),
										["DoubleFace"] = false,
										["PositionOffset"] = Vector(0, 0, 0),
										["BlurLength"] = 0,
										["OwnerEntity"] = false,
										["Brightness"] = 1,
										["DrawOrder"] = 999,
										["BlendMode"] = "",
										["TintColor"] = Vector(0, 0, 0),
										["Alpha"] = 0,
										["LodOverride"] = -1,
										["TargetEntityUID"] = "",
										["BlurSpacing"] = 0,
										["UsePlayerColor"] = false,
										["Material"] = "",
										["UseWeaponColor"] = false,
										["EyeAngles"] = false,
										["UseLegacyScale"] = false,
										["Bone"] = "head",
										["Color"] = Vector(255, 173, 143),
										["Fullbright"] = false,
										["BoneMerge"] = false,
										["IsDisturbing"] = false,
										["Position"] = Vector(1.63671875, 2.7607421875, 1.3880615234375),
										["NoTextureFiltering"] = false,
										["AlternativeScaling"] = false,
										["Hide"] = false,
										["Translucent"] = true,
										["Scale"] = Vector(1.5, 0, 1.3999999761581),
										["ClassName"] = "model",
										["EditorExpand"] = true,
										["Size"] = 0.061875004321337,
										["ModelFallback"] = "",
										["AngleOffset"] = Angle(0, 0, 0),
										["TextureFilter"] = 3,
										["Model"] = "models/pac/default.mdl",
										["UniqueID"] = "2058969870",
									},
								},
								[4] = {
									["children"] = {
										[1] = {
											["children"] = {
											},
											["self"] = {
												["DrawOrder"] = 999,
												["UniqueID"] = "3845548656",
												["TargetEntityUID"] = "",
												["Alpha"] = 1,
												["SizeX"] = 30,
												["SizeY"] = 1,
												["NoTextureFiltering"] = false,
												["Bone"] = "head",
												["BlendMode"] = "",
												["Translucent"] = true,
												["IgnoreZ"] = true,
												["IsDisturbing"] = false,
												["Position"] = Vector(0, -0.3310546875, -0.001708984375),
												["AimPartUID"] = "",
												["AngleOffset"] = Angle(0, 0, 0),
												["Hide"] = false,
												["Name"] = "",
												["AimPartName"] = "",
												["EditorExpand"] = false,
												["Angles"] = Angle(0, 0, 0),
												["Size"] = 1,
												["PositionOffset"] = Vector(0, 0, 0),
												["Color"] = Vector(255, 0, 0),
												["ClassName"] = "sprite",
												["EyeAngles"] = false,
												["SpritePath"] = "sprites/glow04_noz",
											},
										},
										[2] = {
											["children"] = {
											},
											["self"] = {
												["DrawOrder"] = 999,
												["UniqueID"] = "2038038086",
												["TargetEntityUID"] = "",
												["Alpha"] = 1,
												["SizeX"] = 5,
												["SizeY"] = 5,
												["NoTextureFiltering"] = false,
												["Bone"] = "head",
												["BlendMode"] = "",
												["Translucent"] = true,
												["IgnoreZ"] = true,
												["IsDisturbing"] = false,
												["Position"] = Vector(0, -0.3310546875, -0.001708984375),
												["AimPartUID"] = "",
												["AngleOffset"] = Angle(0, 0, 0),
												["Hide"] = false,
												["Name"] = "",
												["AimPartName"] = "",
												["EditorExpand"] = false,
												["Angles"] = Angle(0, 0, 0),
												["Size"] = 1,
												["PositionOffset"] = Vector(0, 0, 0),
												["Color"] = Vector(255, 0, 0),
												["ClassName"] = "sprite",
												["EyeAngles"] = false,
												["SpritePath"] = "sprites/glow04_noz",
											},
										},
									},
									["self"] = {
										["Skin"] = 0,
										["Invert"] = false,
										["LightBlend"] = 1,
										["CellShade"] = 0,
										["AimPartName"] = "",
										["IgnoreZ"] = false,
										["AimPartUID"] = "",
										["Passes"] = 1,
										["Name"] = "default 2",
										["Angles"] = Angle(0, 0, 0),
										["DoubleFace"] = false,
										["PositionOffset"] = Vector(0, 0, 0),
										["BlurLength"] = 0,
										["OwnerEntity"] = false,
										["Brightness"] = 1,
										["DrawOrder"] = 999,
										["BlendMode"] = "",
										["TintColor"] = Vector(0, 0, 0),
										["Alpha"] = 0,
										["LodOverride"] = -1,
										["TargetEntityUID"] = "",
										["BlurSpacing"] = 0,
										["UsePlayerColor"] = false,
										["Material"] = "",
										["UseWeaponColor"] = false,
										["EyeAngles"] = false,
										["UseLegacyScale"] = false,
										["Bone"] = "head",
										["Color"] = Vector(255, 173, 143),
										["Fullbright"] = false,
										["BoneMerge"] = false,
										["IsDisturbing"] = false,
										["Position"] = Vector(1.6748046875, 2.77099609375, -1.3441162109375),
										["NoTextureFiltering"] = false,
										["AlternativeScaling"] = false,
										["Hide"] = false,
										["Translucent"] = true,
										["Scale"] = Vector(1.5, 0, 1.3999999761581),
										["ClassName"] = "model",
										["EditorExpand"] = true,
										["Size"] = 0.061875004321337,
										["ModelFallback"] = "",
										["AngleOffset"] = Angle(0, 0, 0),
										["TextureFilter"] = 3,
										["Model"] = "models/pac/default.mdl",
										["UniqueID"] = "3592180950",
									},
								},
							},
							["self"] = {
								["Skin"] = 0,
								["Invert"] = false,
								["LightBlend"] = 1,
								["CellShade"] = 0,
								["AimPartName"] = "",
								["IgnoreZ"] = false,
								["AimPartUID"] = "",
								["Passes"] = 1,
								["Name"] = "HEAD LOOKS AT YOU",
								["Angles"] = Angle(-4.3033664951508e-06, 21.812532424927, 180),
								["DoubleFace"] = false,
								["PositionOffset"] = Vector(0, 0, 0),
								["BlurLength"] = 0,
								["OwnerEntity"] = false,
								["Brightness"] = 1,
								["DrawOrder"] = 0,
								["BlendMode"] = "",
								["TintColor"] = Vector(0, 0, 0),
								["Alpha"] = 0,
								["LodOverride"] = -1,
								["TargetEntityUID"] = "",
								["BlurSpacing"] = 0,
								["UsePlayerColor"] = false,
								["Material"] = "",
								["UseWeaponColor"] = false,
								["EyeAngles"] = false,
								["UseLegacyScale"] = false,
								["Bone"] = "head",
								["Color"] = Vector(255, 255, 255),
								["Fullbright"] = false,
								["BoneMerge"] = false,
								["IsDisturbing"] = false,
								["Position"] = Vector(1.063720703125, -2.65869140625, 0.0009765625),
								["NoTextureFiltering"] = false,
								["AlternativeScaling"] = false,
								["Hide"] = false,
								["Translucent"] = true,
								["Scale"] = Vector(1, 1, 1),
								["ClassName"] = "model",
								["EditorExpand"] = true,
								["Size"] = 1,
								["ModelFallback"] = "",
								["AngleOffset"] = Angle(0, 0, 0),
								["TextureFilter"] = 3,
								["Model"] = "models/pac/default.mdl",
								["UniqueID"] = "52652501",
							},
						},
						[2] = {
							["children"] = {
							},
							["self"] = {
								["Velocity"] = 1,
								["UniqueID"] = "3599378042",
								["StickStartSize"] = 20,
								["DrawManual"] = false,
								["3D"] = false,
								["StartSize"] = 1,
								["PositionSpread2"] = Vector(0, 0, 0),
								["EndSize"] = 0.10000000149012,
								["Collide"] = true,
								["AngleOffset"] = Angle(0, 0, 0),
								["AimPartName"] = "",
								["IgnoreZ"] = true,
								["Additive"] = false,
								["BlendMode"] = "",
								["Gravity"] = Vector(0, 0, 20),
								["EditorExpand"] = true,
								["StickLifetime"] = 2,
								["Translucent"] = true,
								["Sliding"] = true,
								["NoTextureFiltering"] = false,
								["PositionSpread"] = 20,
								["Name"] = "",
								["FireDelay"] = 0.050000000745058,
								["Hide"] = false,
								["Angles"] = Angle(0, 4.4595257350011e-05, 0),
								["StartLength"] = 1,
								["PositionOffset"] = Vector(0, 0, 0),
								["IsDisturbing"] = false,
								["DrawOrder"] = 0,
								["EyeAngles"] = false,
								["ParticleAngleVelocity"] = Vector(50, 50, 50),
								["ParticleAngle"] = Angle(0, 0, 0),
								["Follow"] = true,
								["StickEndSize"] = 0,
								["StickToSurface"] = true,
								["RandomColor"] = false,
								["Color1"] = Vector(0, 0, 0),
								["TargetEntityUID"] = "",
								["NumberParticles"] = 2,
								["EndAlpha"] = 50,
								["FireOnce"] = false,
								["Color2"] = Vector(0, 0, 0),
								["Material"] = "particle/sparkles",
								["ZeroAngle"] = true,
								["Bone"] = "none",
								["StartAlpha"] = 255,
								["AirResistance"] = 5,
								["AddFrametimeLife"] = false,
								["Lighting"] = true,
								["Position"] = Vector(0, 0, 11.5654296875),
								["EndLength"] = 0,
								["Spread"] = 0,
								["Bounce"] = 5,
								["AlignToSurface"] = true,
								["StickStartAlpha"] = 255,
								["ClassName"] = "particles",
								["RandomRollSpeed"] = 0,
								["DoubleSided"] = true,
								["AimPartUID"] = "",
								["OwnerVelocityMultiplier"] = 0,
								["StickEndAlpha"] = 0,
								["DieTime"] = 4,
								["RollDelta"] = 0,
							},
						},
						[3] = {
							["children"] = {
								[1] = {
									["children"] = {
									},
									["self"] = {
										["Jiggle"] = false,
										["DrawOrder"] = 0,
										["UniqueID"] = "2598769318",
										["TargetEntityUID"] = "",
										["AimPartName"] = "",
										["FollowPartUID"] = "",
										["Bone"] = "j 3",
										["ScaleChildren"] = false,
										["AngleOffset"] = Angle(0, 0, 0),
										["MoveChildrenToOrigin"] = false,
										["Position"] = Vector(0, 0, 0),
										["AimPartUID"] = "",
										["Angles"] = Angle(-0.00018014627858065, 0.00010672173084458, 20.996105194092),
										["Hide"] = false,
										["Name"] = "",
										["Scale"] = Vector(0.5, 0.5, 1),
										["EditorExpand"] = false,
										["ClassName"] = "bone",
										["Size"] = 1,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["AlternativeBones"] = false,
										["EyeAngles"] = false,
										["FollowAnglesOnly"] = false,
									},
								},
								[2] = {
									["children"] = {
									},
									["self"] = {
										["Jiggle"] = false,
										["DrawOrder"] = 0,
										["UniqueID"] = "3999409270",
										["TargetEntityUID"] = "",
										["AimPartName"] = "",
										["FollowPartUID"] = "",
										["Bone"] = "j 8",
										["ScaleChildren"] = false,
										["AngleOffset"] = Angle(0, 0, 0),
										["MoveChildrenToOrigin"] = false,
										["Position"] = Vector(0, 0, 0),
										["AimPartUID"] = "",
										["Angles"] = Angle(0, 0, 0),
										["Hide"] = false,
										["Name"] = "",
										["Scale"] = Vector(0, 0, 0.69999998807907),
										["EditorExpand"] = false,
										["ClassName"] = "bone",
										["Size"] = 1,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["AlternativeBones"] = false,
										["EyeAngles"] = false,
										["FollowAnglesOnly"] = false,
									},
								},
								[3] = {
									["children"] = {
									},
									["self"] = {
										["Jiggle"] = false,
										["DrawOrder"] = 0,
										["UniqueID"] = "353946254",
										["TargetEntityUID"] = "",
										["AimPartName"] = "",
										["FollowPartUID"] = "",
										["Bone"] = "j 4",
										["ScaleChildren"] = false,
										["AngleOffset"] = Angle(0, 0, 0),
										["MoveChildrenToOrigin"] = false,
										["Position"] = Vector(0, 0, 0),
										["AimPartUID"] = "",
										["Angles"] = Angle(-8.5377378127305e-06, -1.2379719919409e-05, -11.494819641113),
										["Hide"] = false,
										["Name"] = "",
										["Scale"] = Vector(0.5, 0.5, 1),
										["EditorExpand"] = false,
										["ClassName"] = "bone",
										["Size"] = 1,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["AlternativeBones"] = false,
										["EyeAngles"] = false,
										["FollowAnglesOnly"] = false,
									},
								},
								[4] = {
									["children"] = {
									},
									["self"] = {
										["Jiggle"] = false,
										["DrawOrder"] = 0,
										["UniqueID"] = "2722573497",
										["TargetEntityUID"] = "",
										["AimPartName"] = "",
										["FollowPartUID"] = "",
										["Bone"] = "j 2",
										["ScaleChildren"] = false,
										["AngleOffset"] = Angle(0, 0, 0),
										["MoveChildrenToOrigin"] = false,
										["Position"] = Vector(0, 0, 0),
										["AimPartUID"] = "",
										["Angles"] = Angle(-0.00016477833560202, 7.6839642133564e-06, 23.724090576172),
										["Hide"] = false,
										["Name"] = "",
										["Scale"] = Vector(0.5, 0.5, 1),
										["EditorExpand"] = false,
										["ClassName"] = "bone",
										["Size"] = 1,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["AlternativeBones"] = false,
										["EyeAngles"] = false,
										["FollowAnglesOnly"] = false,
									},
								},
								[5] = {
									["children"] = {
									},
									["self"] = {
										["Jiggle"] = false,
										["DrawOrder"] = 0,
										["UniqueID"] = "2942624324",
										["TargetEntityUID"] = "",
										["AimPartName"] = "",
										["FollowPartUID"] = "",
										["Bone"] = "j 6",
										["ScaleChildren"] = false,
										["AngleOffset"] = Angle(0, 0, 0),
										["MoveChildrenToOrigin"] = false,
										["Position"] = Vector(0, 0, 0),
										["AimPartUID"] = "",
										["Angles"] = Angle(-1.0245285920973e-05, -1.9209908714402e-05, -25.715524673462),
										["Hide"] = false,
										["Name"] = "",
										["Scale"] = Vector(0.5, 0.5, 1),
										["EditorExpand"] = false,
										["ClassName"] = "bone",
										["Size"] = 1,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["AlternativeBones"] = false,
										["EyeAngles"] = false,
										["FollowAnglesOnly"] = false,
									},
								},
								[6] = {
									["children"] = {
									},
									["self"] = {
										["Jiggle"] = false,
										["DrawOrder"] = 0,
										["UniqueID"] = "3973708013",
										["TargetEntityUID"] = "",
										["AimPartName"] = "",
										["FollowPartUID"] = "",
										["Bone"] = "j 5",
										["ScaleChildren"] = false,
										["AngleOffset"] = Angle(0, 0, 0),
										["MoveChildrenToOrigin"] = false,
										["Position"] = Vector(0, 0, 0),
										["AimPartUID"] = "",
										["Angles"] = Angle(-1.0245285920973e-05, -1.9209908714402e-05, -25.715524673462),
										["Hide"] = false,
										["Name"] = "",
										["Scale"] = Vector(0.5, 0.5, 1),
										["EditorExpand"] = false,
										["ClassName"] = "bone",
										["Size"] = 1,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["AlternativeBones"] = false,
										["EyeAngles"] = false,
										["FollowAnglesOnly"] = false,
									},
								},
								[7] = {
									["children"] = {
									},
									["self"] = {
										["Jiggle"] = false,
										["DrawOrder"] = 0,
										["UniqueID"] = "1998668702",
										["TargetEntityUID"] = "",
										["AimPartName"] = "",
										["FollowPartUID"] = "",
										["Bone"] = "j 7",
										["ScaleChildren"] = false,
										["AngleOffset"] = Angle(0, 0, 0),
										["MoveChildrenToOrigin"] = false,
										["Position"] = Vector(0, 2.5, 0),
										["AimPartUID"] = "",
										["Angles"] = Angle(-1.0245285920973e-05, -1.9209908714402e-05, -25.715524673462),
										["Hide"] = false,
										["Name"] = "",
										["Scale"] = Vector(1, 2, -1.8999999761581),
										["EditorExpand"] = false,
										["ClassName"] = "bone",
										["Size"] = 1,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["AlternativeBones"] = false,
										["EyeAngles"] = false,
										["FollowAnglesOnly"] = false,
									},
								},
								[8] = {
									["children"] = {
									},
									["self"] = {
										["Jiggle"] = false,
										["DrawOrder"] = 0,
										["UniqueID"] = "841153018",
										["TargetEntityUID"] = "",
										["AimPartName"] = "",
										["FollowPartUID"] = "",
										["Bone"] = "head",
										["ScaleChildren"] = true,
										["AngleOffset"] = Angle(0, 0, 0),
										["MoveChildrenToOrigin"] = false,
										["Position"] = Vector(-0.9033203125, -0.0009765625, -0.00244140625),
										["AimPartUID"] = "",
										["Angles"] = Angle(-8.3456383435987e-05, -3.2443400414195e-05, -16.999628067017),
										["Hide"] = false,
										["Name"] = "",
										["Scale"] = Vector(1, 1, 1),
										["EditorExpand"] = true,
										["ClassName"] = "bone",
										["Size"] = 0.375,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["AlternativeBones"] = false,
										["EyeAngles"] = false,
										["FollowAnglesOnly"] = false,
									},
								},
								[9] = {
									["children"] = {
									},
									["self"] = {
										["Jiggle"] = false,
										["DrawOrder"] = 0,
										["UniqueID"] = "3843086972",
										["TargetEntityUID"] = "",
										["AimPartName"] = "",
										["FollowPartUID"] = "",
										["Bone"] = "j 1",
										["ScaleChildren"] = false,
										["AngleOffset"] = Angle(0, 0, 0),
										["MoveChildrenToOrigin"] = false,
										["Position"] = Vector(0, 0, 0),
										["AimPartUID"] = "",
										["Angles"] = Angle(-0.0002723538200371, -0.00010714860400185, 28.145303726196),
										["Hide"] = false,
										["Name"] = "",
										["Scale"] = Vector(0.5, 0.5, 1),
										["EditorExpand"] = false,
										["ClassName"] = "bone",
										["Size"] = 1,
										["PositionOffset"] = Vector(0, 0, 0),
										["IsDisturbing"] = false,
										["AlternativeBones"] = false,
										["EyeAngles"] = false,
										["FollowAnglesOnly"] = false,
									},
								},
							},
							["self"] = {
								["Skin"] = 0,
								["Invert"] = false,
								["LightBlend"] = 1,
								["CellShade"] = 0,
								["AimPartName"] = "",
								["IgnoreZ"] = false,
								["AimPartUID"] = "",
								["Passes"] = 1,
								["Name"] = "Tail",
								["Angles"] = Angle(4.6917872428894, -45.278316497803, 88.27001953125),
								["DoubleFace"] = false,
								["PositionOffset"] = Vector(0, 0, 0),
								["BlurLength"] = 0,
								["OwnerEntity"] = false,
								["Brightness"] = 1,
								["DrawOrder"] = 0,
								["BlendMode"] = "",
								["TintColor"] = Vector(0, 0, 0),
								["Alpha"] = 1,
								["LodOverride"] = -1,
								["TargetEntityUID"] = "",
								["BlurSpacing"] = 0,
								["UsePlayerColor"] = false,
								["Material"] = "models/debug/debugwhite",
								["UseWeaponColor"] = false,
								["EyeAngles"] = false,
								["UseLegacyScale"] = false,
								["Bone"] = "spine",
								["Color"] = Vector(0, 0, 0),
								["Fullbright"] = false,
								["BoneMerge"] = false,
								["IsDisturbing"] = false,
								["Position"] = Vector(0.3955078125, -1.6416015625, -0.142333984375),
								["NoTextureFiltering"] = false,
								["AlternativeScaling"] = false,
								["Hide"] = false,
								["Translucent"] = true,
								["Scale"] = Vector(1, 1, 1),
								["ClassName"] = "model",
								["EditorExpand"] = true,
								["Size"] = 1,
								["ModelFallback"] = "",
								["AngleOffset"] = Angle(0, 0, 0),
								["TextureFilter"] = 3,
								["Model"] = "models/pac/jiggle/base_jiggle_2.mdl",
								["UniqueID"] = "388862639",
							},
						},
					},
					["self"] = {
						["DrawOrder"] = 0,
						["UniqueID"] = "118427589",
						["Hide"] = false,
						["TargetEntityUID"] = "",
						["EditorExpand"] = true,
						["OwnerName"] = "self",
						["IsDisturbing"] = false,
						["Name"] = "main",
						["Duplicate"] = false,
						["ClassName"] = "group",
					},
				},
			},
			["self"] = {
				["DrawOrder"] = 0,
				["UniqueID"] = "4230755705",
				["Hide"] = false,
				["TargetEntityUID"] = "",
				["EditorExpand"] = true,
				["OwnerName"] = "self",
				["IsDisturbing"] = false,
				["Name"] = "my outfit",
				["Duplicate"] = false,
				["ClassName"] = "group",
			},
		},
	}

	local NPC_INDEX = -1
	local function apply_pac()
		local npc = Entity(NPC_INDEX)
		if not IsValid(npc) then return false end
		if npc.mining_blood_ore then return true end

		if pac then
			pac.SetupENT(npc)
			npc:AttachPACPart(DEMON_OUTFIT)
		end

		local mat = Material("models/debug/debugwhite")
		function npc:RenderOverride()
			render.SetLightingMode(2)
			render.SetColorModulation(0.0001, 0.0001, 0.0001)
			render.MaterialOverride(mat)
			self:DrawModel()
			render.MaterialOverride()
			render.SetColorModulation(0, 0, 0)
			render.SetLightingMode(0)
		end

		function npc:Draw() self:DrawModel() end

		npc.mining_blood_ore = true
		return true
	end

	local function doSpook()
		local Tag2 = Tag .. FrameNumber()
		local textToDisplay = "B̴̮̉ḻ̷͑o̸̬̓o̷̧͂d̵̙̆.̷̰͑.̷̓ͅ.̴͈̍ ̴͚͘f̴͔͘o̶̤̽r̸̡͘ ̴͉̎t̸͙̿ḧ̴̙́e̶̜͂ ̸̠͛b̶̝̈l̶̼̆o̷͖͊ö̸͇́ď̷̲ ̴͙̉g̶̩̍o̶̫̓d̷̻̋.̵̯̊.̴̩͋.̶̖͆"

		surface.CreateFont("BIGFONT", {
			font = "Tahoma",
			size = "150"
		})

		local TEXTUREFLAGS_CLAMPS = 0x00000004
		local TEXTUREFLAGS_CLAMPT = 0x00000008
		local iTexFlags = bit.bor(TEXTUREFLAGS_CLAMPS, TEXTUREFLAGS_CLAMPT)
		local sz = ScrW()
		local rt = GetRenderTargetEx(Tag2, sz, sz, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, iTexFlags, 0, IMAGE_FORMAT_RGBA8888)

		local mat = CreateMaterial(Tag2, "UnlitGeneric", {
			["$vertexalpha"] = "1",
			["$vertexcolor"] = "1"
		})

		mat:SetTexture("$basetexture", rt)
		local DrawText = surface.DrawText
		local SetTextPos = surface.SetTextPos
		local PopModelMatrix = cam.PopModelMatrix
		local PushModelMatrix = cam.PushModelMatrix
		local surface = surface
		local matrix = Matrix()
		local matrixAngle = Angle(0, 0, 0)
		local matrixScale = Vector(0, 0, 0)
		local matrixTranslation = Vector(0, 0, 0)

		local function TextRotated(text, x, y, xScale, yScale, angle)
			matrixAngle.y = angle
			matrix:SetAngles(matrixAngle)
			matrixTranslation.x = x
			matrixTranslation.y = y
			matrix:SetTranslation(matrixTranslation)
			matrixScale.x = xScale
			matrixScale.y = yScale
			matrix:SetScale(matrixScale)
			SetTextPos(0, 0)
			PushModelMatrix(matrix)
			DrawText(text)
			PopModelMatrix()
		end

		local snd = "http://g1cf.metastruct.net/m3assets/322589__stereo-surgeon__timpani.ogg"
		local function prepare_sound(cb)
			sound.PlayURL(snd, "noplay", function(station)
				if IsValid(station) then
					station:Play()
				end

				cb()
			end)
		end

		prepare_sound(function()
			local startt = RealTime()

			hook.Add("HUDPaint", Tag .. "_spook", function()
				local now = RealTime()
				local elapsed = now - startt
				local f1 = (elapsed - 6.5) / 0.5
				local f2 = (elapsed - 13) / 3
				local f3 = (elapsed - 6.5) / 7
				f1 = f1 > 1 and 1 or f1 < 0 and 0 or f1
				f2 = f2 > 1 and 1 or f2 < 0 and 0 or f2
				f3 = f3 > 1 and 1 or f3 < 0 and 0 or f3
				f1 = f1 * (1 - f2)
				local sw, sh = ScrW(), ScrH()
				surface.SetMaterial(mat)
				surface.SetDrawColor(255, 255, 255, 255 * f1)
				surface.DrawTexturedRect(sw * .5 - sz * .5, sh * .5 - sz * .5, sz, sz)

				if f2 == 1 then
					hook.Remove("HUDPaint", Tag .. "_spook")
				end
			end)

			hook.Add("Think", Tag .. "_spook", function()
				local now = RealTime()
				local elapsed = now - startt
				local f1 = (elapsed - 6.5) / 0.5
				local f2 = (elapsed - 13) / 3
				local f3 = (elapsed - 6.5) / 7
				f1 = f1 > 1 and 1 or f1 < 0 and 0 or f1
				f2 = f2 > 1 and 1 or f2 < 0 and 0 or f2
				f3 = f3 > 1 and 1 or f3 < 0 and 0 or f3

				if f2 == 1 then
					hook.Remove("Think", Tag .. "_spook")
				end

				f1 = f1 * (1 - f2)
				f1 = 1
				surface.SetFont("MGN_Countdown")
				local tw, th = surface.GetTextSize(textToDisplay)
				render.PushRenderTarget(rt)
				local sw, sh = ScrW(), ScrH()
				render.OverrideAlphaWriteEnable(true, true)

				if f2 == 0 then
					render.Clear(0, 0, 0, 0)
					cam.Start2D()
					local tx, ty = sw * .5 - tw * .5, sh * .5 - th * .5

					for i = 1, 3 do
						local p = (i / 7) * math.pi * 2
						local ox, oy = math.sin(p), math.cos(p)
						surface.SetTextColor(15, 15, 15, f1 * 150)
						surface.SetTextPos(tx + ox * f3 * 50, ty + oy * f3 * 50)
						--surface.DrawText(textToDisplay)
						TextRotated(textToDisplay, tx + ox * f3 * 100, ty + oy * f3 * 100, 1 + f3 * .5, 1 + f3 * .5, 0)
					end

					surface.SetTextColor(200, 0, 0, f1 * 255)
					surface.SetTextPos(tx, ty)
					surface.DrawText(textToDisplay)
					cam.End2D()
				end

				render.OverrideAlphaWriteEnable(false)
				render.PopRenderTarget()
				local t = RealTime() * 4
				local q = .7
				render.OverrideAlphaWriteEnable(true, true)
				render.BlurRenderTarget(rt, 1 + q + q * math.sin(t), 1 + q + q * math.cos(t), 1)
				render.OverrideAlphaWriteEnable(false)
			end)
		end)
	end

	local curState = false
	hook.Add("Think", Tag .. "_flesh_world_state", function()
		local newState = LocalPlayer().IsInZone and LocalPlayer():IsInZone("cave") and IsValid(Entity(NPC_INDEX))
		if newState ~= curState then
			if newState then
				start_flesh_world()
			else
				stop_flesh_world()
			end

			curState = newState
		end
	end)

	net.Receive(Tag .. "_npc", function()
		local entIndex = net.ReadInt(32)
		NPC_INDEX = entIndex

		doSpook()

		local success = apply_pac()
		if not success then
			timer.Create(Tag .. "_npc", 1, 0, function()
				if apply_pac() then
					timer.Remove(Tag .. "_npc")
				end
			end)
		end
	end)
end