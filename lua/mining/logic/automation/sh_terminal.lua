module("ms", package.seeall)
Ores = Ores or {}

local NET_MSG = "MA_TERMINAL"
local NET_MSG_TYPE_UPGRADE = 1
local NET_MSG_TYPE_PURCHASE = 2

local REVERSE_UNLOCK_DATA = {}

local function init_items()
	if not msitems then return end

	for class_name, _ in pairs(Ores.Automation.PurchaseData) do
		local ent_table = scripted_ents.Get(class_name)
		if not istable(ent_table) then continue end

		msitems.StartItem(class_name .. "_item")
			ITEM.WorldModel = "models/Items/item_item_crate.mdl"
			ITEM.EquipSound = "ambient/machines/catapult_throw.wav"
			ITEM.DontReturnToInventory = true
			ITEM.State = "entity"
			ITEM.Inventory = {
				name = ent_table.PrintName,
				info = ("A crate containing materials necessary to build a %s"):format(ent_table.PrintName:lower())
			}

			local function activate(self)
				if CLIENT then return end

				local owner = self.Owner
				if not IsValid(owner) then
					SafeRemoveEntity(self)
					return
				end

				if not owner:IsPlayer() then
					SafeRemoveEntity(self)
					return
				end

				local tr = owner:GetEyeTrace()
				ent_table:SpawnFunction(owner, tr, class_name)
				SafeRemoveEntity(self)
			end

			ITEM.OnDrop = activate
			ITEM.OnUse = activate
		msitems.EndItem()
	end
end

hook.Add("InitPostEntity", "ma_terminal", function()
	for lvl_required, class_names in pairs(Ores.Automation.UnlockData) do
		for _, class_name in ipairs(class_names) do
			REVERSE_UNLOCK_DATA[class_name] = lvl_required * 10
		end
	end

	init_items()
end)

-- debug
hook.GetTable().InitPostEntity.ma_terminal()

if SERVER then
	util.AddNetworkString(NET_MSG)

	local function upgradeMiningAutomation(ply)
		ms.Ores.GetSavedPlayerDataAsync(ply, function(data)
			local level = data.MiningAutomation
			if level >= 50 then return end

			local points = data._points
			local cost = math.floor(math.max(2000, level * 2000))

			if points < cost then return end

			level = level + 1

			ms.Ores.SetSavedPlayerData(ply, "points", points - cost)
			ms.Ores.SetSavedPlayerData(ply, "miningautomation", level)

			ply:SetNWInt(ms.Ores._nwPoints, points - cost)
			ply:SetNWInt("ms.Ores.MiningAutomation", level)
		end, { "MiningAutomation" })
	end

	net.Receive(NET_MSG, function(_, ply)
		local msg_type = net.ReadInt(8)
		local cur_lvl = ply:GetNWInt("ms.Ores.MiningAutomation", 0)
		if msg_type == NET_MSG_TYPE_UPGRADE then
			upgradeMiningAutomation(ply)
		elseif msg_type == NET_MSG_TYPE_PURCHASE then
			local class_name = net.ReadString()
			if not ply.GetCoins or not ply.TakeCoins then return end
			if not REVERSE_UNLOCK_DATA[class_name] then return end

			local lvl_required = REVERSE_UNLOCK_DATA[class_name]
			if cur_lvl < lvl_required then return end

			local price = Ores.Automation.PurchaseData[class_name] * Ores.GetPlayerMultiplier(ply)
			if ply:GetCoins() < price then return end

			if ply.GiveItem then
				ply:GiveItem(class_name .. "_item", 1, "Mining Terminal")
			end

			ply:TakeCoins(price, "Mining Terminal: purchased " .. class_name)
		end
	end)

	hook.Add("PlayerInitialSpawn", "ma_terminal", function(ply)
		ms.Ores.GetSavedPlayerDataAsync(ply, function(data)
			if not IsValid(ply) then return end
			ply:SetNWInt("ms.Ores.MiningAutomation", data.MiningAutomation)
		end, { "MiningAutomation" })
	end)

	hook.Add("PlayerSpawnSENT", "ma_terminal", function(ply, class_name)
		if not ply.GetItemCount then return end
		if not ply.TakeItem then return end
		if not Ores.Automation.PurchaseData[class_name] then return end

		local count = ply:GetItemCount(class_name .. "_item")
		if not isnumber(count) or count < 1 then
			return false
		end

		ply:TakeItem(class_name .. "_item", 1, "Mining Terminal")
	end)

	-- need this otherwise some stuff doesnt call PlayerSpawnSENT
	hook.Add("OnEntityCreated", "ma_terminal", function(ent)
		if not ent.CPPIGetOwner then return end
		if not Ores.Automation.PurchaseData[class_name] then return end

		timer.Simple(0, function()
			if not IsValid(ent) then return end

			local owner = ent:CPPIGetOwner()
			if not IsValid(owner) then return end
			if not owner.GetItemCount then return end
			if not owner.TakeItem then return end

			local count = owner:GetItemCount(class_name .. "_item")
			if not isnumber(count) or count < 1 then
				SafeRemoveEntity(ent)
				return
			end

			ply:TakeItem(class_name .. "_item", 1, "Mining Terminal")
		end)
	end)
end

if CLIENT then
	local COEF_W, COEF_H = ScrW() / 2560, ScrH() / 1440
	local COLOR_WHITE = Color(255, 255, 255, 255)
	local COLOR_BLACK = Color(0, 0, 0, 255)
	local COLOR_WARN = Color(220, 150, 0, 255)

	surface.CreateFont("ma_terminal_header", {
		font = "Sevastopol Interface",
		size = math.max(17, 20 * COEF_H)
	})

	surface.CreateFont("ma_terminal_content", {
		font = "Sevastopol Interface",
		size = math.max(13, 15 * COEF_H),
		weight = 800,
	})

	surface.CreateFont("ma_terminal_btn", {
		font = "Sevastopol Interface",
		size = math.max(13, 15 * COEF_H),
	})

	function Ores.Automation.OpenTerminal(active_tab_name)
		local ply = LocalPlayer()
		local cur_lvl = ply:GetNWInt("ms.Ores.MiningAutomation", 0)
		local cur_points = ply:GetNWInt(ms.Ores._nwPoints, 0)
		local upgrade_cost = math.floor(math.max(2000, cur_lvl * 2000))
		local can_upgrade = cur_points >= upgrade_cost
		local max_lvl = cur_lvl == 50

		local frame = vgui.Create("DPanel")
		frame:SetSize(1000 * COEF_W, 760 * COEF_H)
		frame:Center()
		frame:MakePopup()

		hook.Add("OnPauseMenuShow", frame, function()
			frame:Remove()
			surface.PlaySound("buttons/lightswitch2.wav")

			return false
		end)

		function frame:Paint(w, h)
			surface.DisableClipping(true)

			surface.SetDrawColor(50, 50, 50, 255)
			surface.DrawRect(-20, -20, w + 40, h + 40)

			surface.SetDrawColor(36, 36, 36, 255)
			surface.DrawOutlinedRect(-20, -20, w + 40, h + 40, 1)
			surface.DrawOutlinedRect(-4, -4, w + 8, h + 8, 4)

			surface.DisableClipping(false)

			surface.SetDrawColor(23, 47, 25, 255)
			surface.DrawRect(0, 0, w, h)

			surface.SetDrawColor(15, 180, 104)
			surface.DrawRect(5, 5, w - 10, 20)

			surface.SetTextColor(23, 47, 25, 255)
			surface.SetTextPos(7, 7)
			surface.SetFont("ma_terminal_header")
			surface.DrawText("PERSONAL TERMINAL")

			surface.SetTextColor(15, 180, 104)
			surface.SetTextPos(15, 60 * COEF_H)
			surface.DrawText("FOLDERS")
		end

		local TERMINAL_MAT = Material("effects/combine_binocoverlay")
		function frame:PaintOver(w, h)
			surface.SetMaterial(TERMINAL_MAT)
			surface.SetDrawColor(0, 255, 0, 1)
			surface.DrawTexturedRect(-50, -50, w + 100, h + 100)
		end

		local top_padding = frame:Add("DPanel")
		top_padding:Dock(TOP)
		top_padding:DockMargin(0, 0, 0, 0)
		top_padding:DockPadding(0, 0, 0, 0)
		top_padding:SetTall(25 * COEF_H)
		function top_padding:Paint() end

		local sheet = frame:Add("DColumnSheet")
		sheet:Dock(FILL)

		local function add_sheet(name, title, margin_top)
			local container = vgui.Create("DPanel", sheet)

			container:DockMargin(20 * COEF_W, 0, 0, 0)
			function container:Paint(w, h) end

			local title_panel = container:Add("DLabel")
			title_panel:Dock(TOP)
			title_panel:DockMargin(5 * COEF_W, 20 * COEF_H, 5 * COEF_W, 5 * COEF_H)
			title_panel:SetText("")
			title_panel:SetTall(40)

			function title_panel:Paint(w, h)
				surface.SetDrawColor(20, 101, 64, 255)
				surface.DrawRect(0, 0, w, h)

				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawOutlinedRect(0, 0, w, h)

				surface.SetTextColor(255, 255, 255, 255)
				surface.SetFont("ma_terminal_header")
				surface.SetTextPos(5, 10)
				surface.DrawText(title)
			end

			local inner_panel = container:Add("DPanel")
			inner_panel:Dock(FILL)
			inner_panel:DockMargin(5 * COEF_W, 5 * COEF_H, 5 * COEF_W, 5 * COEF_H)
			function inner_panel:Paint(w, h)
				surface.SetDrawColor(15, 180, 104)
				surface.DrawOutlinedRect(0, 0, w, h)

				surface.DrawRect(0, 0, w, 10)
			end

			container:Dock(FILL)

			local sheet_data = sheet:AddSheet(name, container)
			sheet_data.Button:SetText("")
			sheet_data.Button:SetTall(80)
			sheet_data.Button:SetWide(200)
			sheet_data.Button:DockMargin(0, margin_top and 50 * COEF_H or 5 * COEF_H, 0, 0)

			if active_tab_name == name then
				sheet:SetActiveButton(sheet_data.Button)
			end

			local old_DoClick = sheet_data.Button.DoClick
			function sheet_data.Button:DoClick()
				old_DoClick(self)
				surface.PlaySound("buttons/button16.wav")
			end

			function sheet_data.Button:Paint(w, h)
				surface.SetDrawColor(15, 180, 104)
				surface.DrawOutlinedRect(0, 0, w, h)

				if self == sheet:GetActiveButton() then
					surface.SetTextColor(255, 255, 255)
				else
					surface.SetTextColor(15, 180, 104)
				end

				surface.SetFont("ma_terminal_header")
				surface.SetTextPos(5, 5)
				surface.DrawText(name)
			end

			function sheet_data.Button:PaintOver(w, h)
				if self ~= sheet:GetActiveButton() then return end

				surface.SetDrawColor(255, 255, 255)
				surface.DrawOutlinedRect(0, 0, w, h)

				surface.DisableClipping(true)
				surface.DrawRect(-10, 0, 10, self:GetTall())
				surface.DrawRect(self:GetWide(), 0, 10, self:GetTall())

				local _, parent_y = sheet:LocalToScreen()
				local _, self_y = self:LocalToScreen()
				local target_y = -(self_y - parent_y) + 40

				surface.DrawLine(w, h / 2, w + 20, h / 2)
				surface.DrawLine(w + 20, h / 2, w + 20, target_y)
				surface.DrawLine(w + 20, target_y, w + 40, target_y)

				surface.DisableClipping(false)
			end

			return inner_panel
		end

		-- stat upgrade
		do
			local upgrade_panel = add_sheet("UPGRADE", "ACCESS NEW RESOURCES", true)
			local header = upgrade_panel:Add("DPanel")
			header:Dock(TOP)
			header:SetTall(60)
			function header:Paint() end

			local stat_name = header:Add("DLabel")
			stat_name:Dock(LEFT)
			stat_name:DockMargin(5 * COEF_W, 20 * COEF_H, 20 * COEF_W, 20 * COEF_H)
			stat_name:SetWide(400)
			stat_name:SetText(("CURRENT LVL %d %s"):format(cur_lvl, (can_upgrade and not max_lvl) and "[UPGRADE POSSIBLE]" or ""))
			stat_name:SetColor(COLOR_WHITE)
			stat_name:SetFont("ma_terminal_header")

			local stat_upgrade = header:Add("DButton")
			stat_upgrade:Dock(FILL)
			stat_upgrade:DockMargin(20 * COEF_W, 20 * COEF_H, 5 * COEF_W, 20 * COEF_H)
			stat_upgrade:SetText(not max_lvl and (can_upgrade and "UPGRADE (%s .PTS)" or "NOT ENOUGH POINTS (%s .PTS)"):format(string.Comma(upgrade_cost)) or "MAXED")
			stat_upgrade:SetTextColor(can_upgrade and COLOR_BLACK or COLOR_WHITE)
			stat_upgrade:SetFont("ma_terminal_header")

			function stat_upgrade:Paint(w, h)
				if not can_upgrade then
					surface.SetDrawColor(COLOR_WARN:Unpack())
					surface.DrawOutlinedRect(0, 0, w, h)
				else
					surface.SetDrawColor(COLOR_WHITE:Unpack())
					surface.DrawRect(0, 0, w, h)
				end
			end

			local content = upgrade_panel:Add("DPanel")
			content:Dock(FILL)
			function content:Paint() end

			local content_left = content:Add("DPanel")
			content_left:Dock(LEFT)
			content_left:SetWide(400 * COEF_W)
			function content_left:Paint() end

			local content_right = content:Add("DPanel")
			content_right:Dock(FILL)
			function content_right:Paint() end

			local function build_unlock_list()
				content_left:Clear()
				content_right:Clear()

				for i = 1, #Ores.Automation.UnlockData do
					local lvl_required = i * 10
					local class_names = Ores.Automation.UnlockData[i]
					for _, class_name in ipairs(class_names) do
						local ent_table = scripted_ents.Get(class_name)
						if not ent_table then continue end

						local equipment = content_left:Add("DLabel")
						equipment:Dock(TOP)
						equipment:DockMargin(20 * COEF_W, 5 * COEF_H, 20 * COEF_W, 5 * COEF_H)
						equipment:SetFont("ma_terminal_content")
						equipment:SetText("- " .. ent_table.PrintName:upper())

						local equipment_status = content_right:Add("DLabel")
						equipment_status:Dock(TOP)
						equipment_status:DockMargin(20 * COEF_W, 5 * COEF_H, 20 * COEF_W, 5 * COEF_H)
						equipment_status:SetFont("ma_terminal_content")
						equipment_status:SetTextColor(lvl_required <= cur_lvl and COLOR_WHITE or COLOR_WARN)
						equipment_status:SetText(lvl_required <= cur_lvl and "[ UNLOCKED ]" or ("[ LVL. %d ]"):format(lvl_required))
					end
				end
			end

			function stat_upgrade:DoClick()
				if not can_upgrade and not max_lvl then return end

				net.Start(NET_MSG)
				net.WriteInt(NET_MSG_TYPE_UPGRADE, 8)
				net.SendToServer()

				-- keep the UI up to date
				cur_lvl = math.min(50, cur_lvl + 1)
				cur_points = math.max(0, ply:GetNWInt(ms.Ores._nwPoints, 0) - upgrade_cost)
				upgrade_cost = math.floor(math.max(2000, cur_lvl * 2000))
				can_upgrade = cur_points >= upgrade_cost

				stat_name:SetText(("CURRENT LVL %d %s"):format(cur_lvl, can_upgrade and "[UPGRADE POSSIBLE]" or ""))
				self:SetText((can_upgrade and "UPGRADE (%s .PTS)" or "NOT ENOUGH POINTS (%s .PTS)"):format(string.Comma(upgrade_cost)))
				self:SetTextColor(can_upgrade and COLOR_BLACK or COLOR_WHITE)
				build_unlock_list()

				surface.PlaySound("buttons/weapon_confirm.wav")
			end

			build_unlock_list()
		end

		-- equipment shop
		do
			local shop_panel = add_sheet("SHOP", "BUY MINING EQUIPMENT")
			local content_left = shop_panel:Add("DPanel")
			content_left:Dock(LEFT)
			content_left:SetWide(400 * COEF_W)
			function content_left:Paint() end

			local content_right = shop_panel:Add("DPanel")
			content_right:Dock(FILL)
			function content_right:Paint() end

			local coins = ply:GetCoins()
			local inv = ply.GetInventory and ply:GetInventory() or {}
			for i = 1, #Ores.Automation.UnlockData do
				local class_names = Ores.Automation.UnlockData[i]
				for j, class_name in ipairs(class_names) do
					local purchase_value = Ores.Automation.PurchaseData[class_name]
					if not purchase_value then continue end

					local ent_table = scripted_ents.Get(class_name)
					if not ent_table then continue end

					local lvl_required = i * 10
					local has_lvl = cur_lvl >= lvl_required
					local real_purchase_value = purchase_value * ms.Ores.GetPlayerMultiplier(ply)
					local is_first = (i == 1 and j == 1)
					local equipment_count = inv[class_name .. "_item"] and inv[class_name .. "_item"].count or 0

					local equipment = content_left:Add("DLabel")
					equipment:SetTall(20)
					equipment:Dock(TOP)
					equipment:DockMargin(20 * COEF_W, is_first and 20 * COEF_H or 5 * COEF_H, 20 * COEF_W, 5 * COEF_H)
					equipment:SetFont("ma_terminal_content")
					equipment:SetText(equipment_count > 0 and ("%s (OWNED X%d)"):format(ent_table.PrintName:upper(), equipment_count) or ent_table.PrintName:upper())

					local purchase_btn = content_right:Add("DButton")
					purchase_btn:SetTall(20)
					purchase_btn:Dock(TOP)
					purchase_btn:DockMargin(20 * COEF_W, is_first and 20 * COEF_H or 5 * COEF_H, 20 * COEF_W, 5 * COEF_H)
					purchase_btn:SetFont("ma_terminal_content")
					purchase_btn:SetTextColor((not has_lvl or real_purchase_value > coins) and COLOR_WHITE or COLOR_BLACK)

					if has_lvl then
						purchase_btn:SetText(real_purchase_value > coins
							and ("NOT ENOUGH COINS (%sc)"):format(string.Comma(real_purchase_value))
							or ("PURCHASE (%sc)"):format(string.Comma(real_purchase_value))
						)

						function purchase_btn:DoClick()
							if real_purchase_value > coins then return end

							net.Start(NET_MSG)
							net.WriteInt(NET_MSG_TYPE_PURCHASE, 8)
							net.WriteString(class_name)
							net.SendToServer()

							equipment_count = equipment_count + 1
							coins = math.max(0, coins - real_purchase_value)

							equipment:SetText(equipment_count > 0 and ("%s (OWNED X%d)"):format(ent_table.PrintName:upper(), equipment_count) or ent_table.PrintName:upper())

							if real_purchase_value > coins then
								self:SetTextColor(COLOR_WHITE)
								self:SetText(("NOT ENOUGH COINS (%sc)"):format(string.Comma(real_purchase_value)))
							else
								self:SetTextColor(COLOR_BLACK)
								self:SetText(("PURCHASE (%sc)"):format(string.Comma(real_purchase_value)))
							end

							surface.PlaySound("buttons/weapon_confirm.wav")
						end
					else
						purchase_btn:SetText("LOCKED")
					end

					function purchase_btn:Paint(w, h)
						if real_purchase_value > coins or not has_lvl then
							surface.SetDrawColor(COLOR_WARN:Unpack())
							surface.DrawOutlinedRect(0, 0, w, h)
							self:SetTextColor(COLOR_WHITE)
							self:SetText(has_lvl and ("NOT ENOUGH COINS (%sc)"):format(string.Comma(real_purchase_value)) or "LOCKED")
						else
							surface.SetDrawColor(COLOR_WHITE:Unpack())
							surface.DrawRect(0, 0, w, h)
							self:SetTextColor(COLOR_BLACK)
							self:SetText(("PURCHASE (%sc)"):format(string.Comma(real_purchase_value)))
						end
					end
				end
			end
		end

		--add_sheet("GUIDE", "LEARN ABOUT AN EQUIPMENT")
	end

	concommand.Add("mining_automation_terminal", function()
		Ores.Automation.OpenTerminal()
	end)
end