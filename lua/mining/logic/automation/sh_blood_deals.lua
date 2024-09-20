local TAG = "mining_blood_ore"
local ITEMS = {
	skull = {
		id = "skull",
		name = "Skull Totem",
		model = "models/Gibs/HGIBS.mdl",
		price = 30,
		description = "Looks like a humanoid skull, it seems its owner perished not too long ago...",
		deal = {
			bonus = "25% Increase in Coin Minter output.",
			malus = "Batteries are 2 times slower to complete.",
		},
	},
	spine = {
		id = "spine",
		name = "Spine Totem",
		model = "models/Gibs/HGIBS_spine.mdl",
		price = 60,
		description = "Old remains of what looks like a human spine, you don't even dare to imagine how it was obtained.",
		deal = {
			bonus = "Ores mined by drills have 50% chance to be of better quality for 1h.",
			malus = "Drills have a chance to break-down and explode.",
		},
	},
	rib = {
		id = "rib",
		name = "Rib Totem",
		model = "models/Gibs/HGIBS_rib.mdl",
		price = 15,
		description = "A piece of a rib cage, its origin is unknown but somehow even if you could know, you wouldnt want to know.",
		deal = {
			bonus = "Unlock every mining equipment temporarily.",
			malus = "All the equipments are twice as expensive in the shop.",
		},
	},
	soul = {
		id = "soul",
		name = "Your Soul",
		model = "models/props_lab/huladoll.mdl",
		price = 9999,
		description = "WAIT, WHAT?!",
		deal = {
			bonus = "Get your humanity back.",
			malus = "???",
		},
	},
}

if SERVER then
	util.AddNetworkString(TAG)
	util.AddNetworkString(TAG .. "_npc")

	local function remove_blood_rocks()
		for _, rock in ipairs(ents.FindByClass("mining_rock")) do
			if rock:GetRarity() == 666 then
				SafeRemoveEntity(rock)
			end
		end
	end

	local function remove_blood_god(npc)
		SafeRemoveEntity(npc)
		remove_blood_rocks()
	end

	net.Receive(TAG, function(_, ply)
		local item_id = net.ReadString()
		local npc = net.ReadEntity()

		local inv = ply.GetInventory and ply:GetInventory()
		if inv and inv.soul and inv.soul > 0 then
			-- player got soul back, disable deals
			ms.Ores.SendChatMessage(ply, "Mortal, you already got your soul back, the deals are off!")
			return
		end

		if item_id == "nodeal" then return end
		if not ITEMS[item_id] then return end
		if not IsValid(npc) then return end
		if npc:GetClass() ~= "lua_npc" and npc:GetClass() ~= "player" then return end

		local item = ITEMS[item_id]
		local cur_blood = ms.Ores.GetPlayerOre(ply, 666)
		if item.price > cur_blood then
			ms.Ores.SendChatMessage(ply, "Do you take me for an idiot mortal? Come back with blood.")
			ply:Kill()
			remove_blood_god(npc)
			return
		end

		if item_id == "soul" then
			hook.Run("SoulGottenBack", ply)
		end

		ms.Ores.TakePlayerOre(ply, 666, item.price)

		if ply.GiveItem then
			ply:GiveItem(item_id, 1, "bloodgod")
		end

		ms.Ores.SendChatMessage(player.GetAll(), "The creature made a deal with " .. ply:Nick() .. ". But it will probably be back soon... (1h)")
		remove_blood_god(npc)
	end)

	local MAX_NPC_DIST = 300 * 300
	hook.Add("KeyPress", TAG, function(ply,key)
		if key ~= IN_USE then return end

		local npc = ply:GetEyeTrace().Entity
		if not npc:IsValid() then return end

		if npc.role == "bloodgod" and npc:GetPos():DistToSqr(ply:GetPos()) <= MAX_NPC_DIST then
			net.Start(TAG)
			net.WriteEntity(npc)
			net.Send(ply)

			if ply.LookAt then
				ply:LookAt(npc, 1, 2)
			end
		end
	end)

	hook.Add("EntityTakeDamage", TAG, function(target, dmg)
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

	local next_blood_god = 0
	local BLOOD_GOD_NPC
	local BLOOD_GOD_OFFSET = Vector(-355, -497, 28)
	hook.Add("PlayerReceivedOre", TAG, function(ply, _, rarity)
		if rarity ~= 666 then return end
		if CurTime() < next_blood_god then return end
		if IsValid(BLOOD_GOD_NPC) then return end

		local count = ms.Ores.GetPlayerOre(ply, 666)
		if count >= 66 then
			local cave_trigger = ms and ms.GetTrigger and ms.GetTrigger("cave1")
			local pos = IsValid(cave_trigger)
				and (cave_trigger:GetPos() - BLOOD_GOD_OFFSET)
				or (ply:GetPos() + ply:GetForward() * 200 + Vector(0, 0, 50))

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

				timer.Simple(60 * 5, function()
					if not IsValid(BLOOD_GOD_NPC) then return end

					ms.Ores.SendChatMessage(player.GetAll(), "The creature is gone for now, but it will probably be back soon... (1h)")
					remove_blood_god(BLOOD_GOD_NPC)
				end)
			end
		end

		if not IsValid(BLOOD_GOD_NPC) then return end

		next_blood_god = CurTime() + (60 * 60) -- in an hour

		for _, rock in ipairs(ents.FindByClass("mining_rock")) do
			rock:SetRarity(666)
		end

		ms.Ores.SendChatMessage(player.GetAll(), "An otherwordly creature appeared in the mines... Best be careful.")

		net.Start(TAG .. "_npc")
		net.WriteInt(BLOOD_GOD_NPC:EntIndex(), 32)
		net.Broadcast(ply)
	end)

	hook.Add("OnEntityCreated", TAG, function(ent)
		local class_name = ent:GetClass()
		if ITEMS[class_name:gsub("_item_sent$", "")] then
			SafeRemoveEntityDelayed(ent, 0.1)
			return
		end

		if not IsValid(BLOOD_GOD_NPC) then return end

		if class_name  == "mining_rock" then
			timer.Simple(0, function()
				if not IsValid(ent) then return end

				ent:SetRarity(666)
			end)
		end
	end)
end

if CLIENT then
	ITEMS = table.ClearKeys(ITEMS)

	local NO_DEAL_DATA = {
		id = "nodeal",
		name = "NO DEAL",
		model = "models/props_c17/streetsign004e.mdl",
		price = 0,
		description = "NO DEAL! Escape this horrible situation!",
	}

	local ATMOS_SOUND = "sound/ambient/atmosphere/corridor.wav"
	local WORLD_MAT = CreateMaterial("world_flesh_" .. FrameNumber(), "LightmappedGeneric", {
		["$basetexture"] = "models/flesh",
	})

	local SPLASH_MAT_BLACK = CreateMaterial("dwd_splash_black_" .. FrameTime(), "UnlitGeneric", {
		["$basetexture"] = "models/barnacle/roots",
		["$translucent"] = 1,
		["$color"] = "[0 0 0]",
	})

	local SPLASH_MAT = CreateMaterial("dwd_splash_" .. FrameTime(), "UnlitGeneric", {
		["$basetexture"] = "models/barnacle/roots",
		["$translucent"] = 1,
		["$color"] = "[1 0 0]",
	})

	local COLOR_SETTINGS = {
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

	local atmos_station
	local function start_flesh_world()
		sound.PlayFile(ATMOS_SOUND, "noplay", function(station, err_code, err_str)
			if IsValid(station) then
				station:EnableLooping(true)
				station:Play()
				atmos_station = station
			end
		end)

		hook.Add("RenderScene", TAG, function()
			render.WorldMaterialOverride(WORLD_MAT)
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

		hook.Add("RenderScreenspaceEffects", TAG, function()
			DrawColorModify(COLOR_SETTINGS)
			DrawBloom(0.65, 2, 9, 9, 1, 1, 1, 1, 1)
			DrawToyTown(2, ScrH() / 2)
			DrawMotionBlur(0.4, 0.8, 0.01)
		end)

		hook.Add("PlayerFootstep", TAG, function(ply, _, _, _, _, _)
			ply:EmitSound("npc/antlion_grub/squashed.wav", 20, math.random(50, 75))

			return true
		end)
	end

	local function stop_flesh_world()
		hook.Remove("RenderScene", TAG)
		hook.Remove("RenderScreenspaceEffects", TAG)
		hook.Remove("PlayerFootstep", TAG)
		hook.Remove("Think", TAG)
		hook.Remove("HUDPaint", TAG)

		if IsValid(atmos_station) then
			atmos_station:Stop()
		end
	end

	local COEF_W, COEF_H = ScrW() / 2560, ScrH() / 1440

	surface.CreateFont("dwd_blood_bg_text", {
		font = "Ghastly Panic",
		extended = true,
		size = math.max(75, 100 * COEF_H),
	})

	surface.CreateFont("dwd_title", {
		font = "Ghastly Panic",
		size = math.max(125, 200 * COEF_H),
		outline = true,
	})

	surface.CreateFont("dwd_item_name", {
		font = "Ghastly Panic",
		size = math.max(50, 75 * COEF_H),
		outline = false,
	})

	surface.CreateFont("dwd_item_desc", {
		font = "Arial",
		size = math.max(12, 20 * COEF_H),
		weight = 600,
		outline = false,
	})

	local hovering_btns = 0
	local blood_texts = {}
	local next_blood_text = 0
	local function draw_soul_btn_background(offsetx, offsety)
		local time = CurTime()

		if hovering_btns > 0 and time >= next_blood_text then
			local count = math.random(2, 8)

			for _ = 1, count do
				local lifetime = math.random(1, 3)

				table.insert(blood_texts, {
					x = math.random(10, ScrW() - 10) - offsetx,
					y = math.random(10, ScrH() - 10) - offsety,
					endtime = CurTime() + lifetime,
					lifetime = lifetime,
					red = math.random() * 255,
				})
			end

			surface.PlaySound("ambient/hallow0" .. math.random(4, 8) .. ".wav")
			next_blood_text = time + 1
		end

		for i, text_data in ipairs(blood_texts) do
			local diff = text_data.endtime - CurTime()
			local unit = 255 / text_data.lifetime
			local alpha = (diff * unit)

			if alpha <= 0 then
				table.remove(blood_texts, i)
				continue
			end

			surface.SetFont("dwd_blood_bg_text")
			surface.SetTextPos(text_data.x, text_data.y)
			surface.SetTextColor(text_data.red, 0, 0, alpha)
			surface.DrawText("BLOOD")
		end
	end

	local COLOR_WHITE = Color(255, 255, 255, 255)
	local COLOR_RED = Color(255, 44, 44)
	local menu_toggled = false
	local function shop(npc, real_width, real_height)
		if menu_toggled then return end

		menu_toggled = true

		local frame = vgui.Create("DPanel")
		frame:SetSize(real_width, real_height)
		frame:Center()
		frame:MakePopup()

		function frame:Paint(w, h)
			Derma_DrawBackgroundBlur(self, 0)
			surface.SetDrawColor(0, 0, 0, 100)
			surface.DrawRect(0, 0, w, h)

			surface.DisableClipping(true)
				draw_soul_btn_background(self:LocalToScreen())
			surface.DisableClipping(false)

			surface.SetFont("dwd_title")
			surface.SetTextColor(224, 0, 41)

			local text = "Blood Deals"
			local tw, _ = surface.GetTextSize(text)

			surface.SetTextPos(w / 2 - tw / 2, 5 * COEF_H)
			surface.DrawText(text)
		end

		local function add_item(item_id, item_data, is_first)
			local panel = frame:Add("DPanel")
			panel:Dock(TOP)
			panel:SetTall(200 * COEF_H)
			panel:DockMargin(real_width / 6 + 200 * COEF_W, (is_first and 200 or 50) * COEF_H, real_width / 6, 0)
			panel:SetCursor("hand")

			local function is_hovered()
				local x, y = gui.MouseX(), gui.MouseY()
				local panel_x, panel_y = panel:LocalToScreen()

				if (x >= panel_x and x <= panel_x + panel:GetWide()) and (y >= panel_y and y <= panel_y + panel:GetTall()) then
					hovering_btn = true
					return true
				end

				hovering_btn = false
				return false
			end

			hook.Add("VGUIMousePressed", panel, function()
				if is_hovered() then
					if item_id ~= "nodeal" then
						net.Start(TAG)
						net.WriteString(item_id)
						net.WriteEntity(npc)
						net.SendToServer()
					end

					menu_toggled = false
					frame:Remove()
					surface.PlaySound("ambient/voices/squeal1.wav")
					surface.PlaySound("ambient/atmosphere/cave_hit2.wav")
				end
			end)

			local state = is_hovered()
			function panel:Paint(w, h)
				local cur_state = is_hovered()
				if cur_state then
					surface.SetDrawColor(255, 255, 255, 255)
					surface.SetMaterial(SPLASH_MAT)
				else
					surface.SetDrawColor(0, 0, 0, 255)
					surface.SetMaterial(SPLASH_MAT_BLACK)
				end

				if cur_state ~= state then
					state = cur_state
					if state then
						surface.PlaySound("npc/barnacle/barnacle_crunch" .. math.random(2, 3) .. ".wav")
						hovering_btns = hovering_btns + 1
					else
						hovering_btns = hovering_btns - 1
					end
				end

				surface.DrawTexturedRect(-100 * COEF_W, -15 * COEF_H, w + 100 * COEF_W, h)
				surface.DrawTexturedRect(-150 * COEF_W, 10 * COEF_H, w + 100 * COEF_W, h)
			end

			local item_view = panel:Add("DModelPanel")
			item_view:Dock(LEFT)
			item_view:SetModel(item_data.model)
			item_view:SetWide(200 * COEF_W)
			item_view:SetCursor("hand")

			local ent = item_view:GetEntity()
			local pos = ent:GetPos()
			local ang = ent:GetAngles()
			local tab = PositionSpawnIcon(ent, pos, true)
			ent:SetAngles(ang)

			if tab then
				item_view:SetCamPos(tab.origin)
				item_view:SetFOV(tab.fov)
				item_view:SetLookAng(tab.angles)
			end

			local old_Paint = item_view.Paint
			function item_view:Paint(w, h)
				surface.DisableClipping(true)

				if is_hovered() then
					surface.SetDrawColor(255, 255, 255, 255)
					surface.SetMaterial(SPLASH_MAT)
				else
					surface.SetDrawColor(0, 0, 0, 255)
					surface.SetMaterial(SPLASH_MAT_BLACK)
				end

				surface.DrawTexturedRect(-20 * COEF_W, -20 * COEF_H, w + 40 * COEF_W, h + 40 * COEF_H)
				surface.DisableClipping(false)

				old_Paint(self, w, h)
			end

			local item_name = panel:Add("DLabel")
			item_name:Dock(TOP)
			item_name:DockMargin(10 * COEF_W, 20 * COEF_H, 0, 0)
			item_name:SetFont("dwd_item_name")
			item_name:SetTall(draw.GetFontHeight("dwd_item_name") - 25 * COEF_H)
			item_name:SetText(item_data.name:upper())
			item_name:SetTextColor(COLOR_WHITE)
			item_name:SetCursor("hand")

			if item_data.deal then
				local deal = panel:Add("DPanel")
				deal:Dock(TOP)
				deal:SetTall(50 * COEF_H)
				deal:SetCursor("hand")
				function deal:Paint() end

				local deal_bonus = deal:Add("DLabel")
				deal_bonus:Dock(TOP)
				deal_bonus:SetTextColor(COLOR_WHITE)
				deal_bonus:SetFont("dwd_item_desc")
				deal_bonus:SetText("▲ " .. item_data.deal.bonus:upper())
				deal_bonus:SetCursor("hand")

				local deal_malus = deal:Add("DLabel")
				deal_malus:Dock(TOP)
				deal_malus:SetTextColor(COLOR_RED)
				deal_malus:SetFont("dwd_item_desc")
				deal_malus:SetText("▼ " .. item_data.deal.malus:upper())
				deal_malus:SetCursor("hand")

				function deal:PerformLayout(w, h)
					deal_bonus:SizeToContents()
					deal_malus:SizeToContents()
					self:SizeToContents()
				end
			end

			local item_desc = panel:Add("DLabel")
			item_desc:Dock(TOP)
			item_desc:DockMargin(10 * COEF_W, 0, 0, 20 * COEF_H)
			item_desc:SetFont("dwd_item_desc")
			item_desc:SetText(item_data.description)
			item_desc:SetTextColor(COLOR_WHITE)
			item_desc:SetWrap(true)
			item_desc:SetCursor("hand")

			local price
			if item_data.price > 0 then
				price = panel:Add("DLabel")
				price:SetFont("dwd_item_desc")
				price:SetText("REQUIRES X" .. item_data.price .. " BLOOD")
				price:SetTextColor(COLOR_WHITE)

				function price:Paint(w, h)
					surface.DisableClipping(true)
					surface.SetDrawColor(255, 255, 255, 200)
					surface.DrawOutlinedRect(-10 * COEF_W, -5 * COEF_H, w + 20 * COEF_W, h + 10 * COEF_H)
					surface.DisableClipping(false)
				end
			end

			function panel:PerformLayout(w, h)
				if price then
					item_name:SizeToContentsX()
					local x, _ = item_name:GetPos()
					price:SetPos(x + item_name:GetWide() + 40 * COEF_W, draw.GetFontHeight("dwd_item_name") / 2 - price:GetTall() / 2)
					price:SizeToContentsX()
				end

				item_desc:SizeToContents()
			end
		end

		local inv = LocalPlayer().GetInventory and LocalPlayer():GetInventory()
		for i, item_data in ipairs(ITEMS) do
			if item_data.id == "soul" and inv and inv.soul and inv.soul and inv.soul.count > 0 then continue end
			if item_data.id == "nodeal" then continue end

			add_item(item_data.id, item_data, i == 1)
		end

		add_item(NO_DEAL_DATA.id, NO_DEAL_DATA, false)
	end

	net.Receive(TAG, function()
		local npc = net.ReadEntity()
		shop(npc, ScrW(), ScrH())
	end)

	local DEMON_OUTFIT = {}
	hook.Add("Initialize", TAG, function()
		if not pac then return end

		http.Fetch("https://raw.githubusercontent.com/Metastruct/mining/refs/heads/master/external/demon.txt", function(content)
			DEMON_OUTFIT = luadata.Decode(content)
		end)
	end)

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

	surface.CreateFont("BIGFONT", {
		font = "Tahoma",
		size = "150"
	})

	local SPOOK_TEXT = "B̴̮̉ḻ̷͑o̸̬̓o̷̧͂d̵̙̆.̷̰͑.̷̓ͅ.̴͈̍ ̴͚͘f̴͔͘o̶̤̽r̸̡͘ ̴͉̎t̸͙̿ḧ̴̙́e̶̜͂ ̸̠͛b̶̝̈l̶̼̆o̷͖͊ö̸͇́ď̷̲ ̴͙̉g̶̩̍o̶̫̓d̷̻̋.̵̯̊.̴̩͋.̶̖͆"
	local TEXTUREFLAGS_CLAMPS = 0x00000004
	local TEXTUREFLAGS_CLAMPT = 0x00000008
	local TEXTURE_FLAGS = bit.bor(TEXTUREFLAGS_CLAMPS, TEXTUREFLAGS_CLAMPT)
	local function do_spook()
		local spook_id = TAG .. FrameNumber()

		local sz = ScrW()
		local rt = GetRenderTargetEx(spook_id, sz, sz, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, TEXTURE_FLAGS, 0, IMAGE_FORMAT_RGBA8888)

		local mat = CreateMaterial(spook_id, "UnlitGeneric", {
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
		local matrix_ang = Angle(0, 0, 0)
		local matrix_scale = Vector(0, 0, 0)
		local matrix_translation = Vector(0, 0, 0)

		local function text_rotated(text, x, y, x_scale, y_scale, angle)
			matrix_ang.y = angle
			matrix:SetAngles(matrix_ang)
			matrix_translation.x = x
			matrix_translation.y = y
			matrix:SetTranslation(matrix_translation)
			matrix_scale.x = x_scale
			matrix_scale.y = y_scale
			matrix:SetScale(matrix_scale)
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
			local start = RealTime()

			hook.Add("HUDPaint", TAG .. "_spook", function()
				local now = RealTime()
				local elapsed = now - start
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
					hook.Remove("HUDPaint", TAG .. "_spook")
				end
			end)

			hook.Add("Think", TAG .. "_spook", function()
				local now = RealTime()
				local elapsed = now - start
				local f1 = (elapsed - 6.5) / 0.5
				local f2 = (elapsed - 13) / 3
				local f3 = (elapsed - 6.5) / 7
				f1 = f1 > 1 and 1 or f1 < 0 and 0 or f1
				f2 = f2 > 1 and 1 or f2 < 0 and 0 or f2
				f3 = f3 > 1 and 1 or f3 < 0 and 0 or f3

				if f2 == 1 then
					hook.Remove("Think", TAG .. "_spook")
				end

				f1 = f1 * (1 - f2)
				f1 = 1
				surface.SetFont("MGN_Countdown")
				local tw, th = surface.GetTextSize(SPOOK_TEXT)
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
						--surface.DrawText(SPOOK_TEXT)
						text_rotated(SPOOK_TEXT, tx + ox * f3 * 100, ty + oy * f3 * 100, 1 + f3 * .5, 1 + f3 * .5, 0)
					end

					surface.SetTextColor(200, 0, 0, f1 * 255)
					surface.SetTextPos(tx, ty)
					surface.DrawText(SPOOK_TEXT)
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

	local flesh_world_state = false
	hook.Add("Think", TAG .. "_flesh_world_state", function()
		local npc = Entity(NPC_INDEX)
		local new_state = menu_toggled or (LocalPlayer().IsInZone and LocalPlayer():IsInZone("cave") and IsValid(npc) and npc.IsBloodGod)
		if new_state ~= flesh_world_state then
			if new_state then
				start_flesh_world()
			else
				stop_flesh_world()
			end

			flesh_world_state = new_state
		end
	end)

	net.Receive(TAG .. "_npc", function()
		local ent_index = net.ReadInt(32)
		NPC_INDEX = ent_index

		Entity(NPC_INDEX).IsBloodGod = true
		do_spook()

		local success = apply_pac()
		if not success then
			timer.Create(TAG .. "_npc", 1, 0, function()
				if apply_pac() then
					Entity(NPC_INDEX).IsBloodGod = true
					timer.Remove(TAG .. "_npc")
				end
			end)
		end
	end)
end