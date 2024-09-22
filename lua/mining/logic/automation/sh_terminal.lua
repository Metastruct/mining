module("ms", package.seeall)
Ores = Ores or {}

local NET_MSG = "MA_TERMINAL"
local NET_MSG_TYPE_UPGRADE = 1
local NET_MSG_TYPE_PURCHASE = 2
local NET_MSG_RANKING = 3
local NET_MSG_AUTOBUY = 4

local REVERSE_UNLOCK_DATA = {}

local function init_items()
	if not msitems then return end

	for class_name, _ in pairs(Ores.Automation.PurchaseData) do
		local ent_table = scripted_ents.Get(class_name)
		if not istable(ent_table) then continue end

		msitems.StartItem(class_name .. "_item")
			ITEM.WorldModel = "models/Items/item_item_crate.mdl"
			ITEM.EquipSound = "ambient/machines/catapult_throw.wav"
			ITEM.State = "entity"
			ITEM.Inventory = {
				name = ent_table.PrintName .. " Materials Crate",
				info = ("A crate containing materials necessary to build a %s"):format(ent_table.PrintName:lower())
			}

			function ITEM:OnEquip(ply)
				local tr = ply:GetEyeTrace()
				local ent = ent_table:SpawnFunction(ply, tr, class_name)
				if ent.CPPISetOwner then
					ent:CPPISetOwner(ply)
				end

				self:Remove()
				return false
			end
		msitems.EndItem()
	end

	if not SERVER then return end

	-- none of the item hooks work so remove item entities....
	hook.Add("OnEntityCreated", "ma_terminal_remove_bad_items", function(ent)
		local class_name = ent:GetClass()
		if class_name:match("ma%_.*%_item%_item%_sent$") then
			local owner = ent.CPPIGetOwner and ent:CPPIGetOwner()
			if IsValid(owner) then
				local tr = owner:GetEyeTrace()
				local actual_class_name = class_name:gsub("_item_item_sent$", "")
				local ent_table = scripted_ents.Get(actual_class_name)
				if istable(ent_table) then
					local new_ent = ent_table:SpawnFunction(owner, tr, actual_class_name)
					if new_ent.CPPISetOwner then
						new_ent:CPPISetOwner(owner)
					end
				end
			end

			SafeRemoveEntityDelayed(ent, 0.1)
		end
	end)
end

local function init()
	for lvl_required, class_names in pairs(Ores.Automation.UnlockData) do
		for _, class_name in ipairs(class_names) do
			REVERSE_UNLOCK_DATA[class_name] = lvl_required * 10
		end
	end

	init_items()
end

hook.Add("InitPostEntity", "ma_terminal", init)
init()

if SERVER then
	util.AddNetworkString(NET_MSG)

	local function upgrade_mining_automation(ply)
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

	local function purchase_mining_equipment(ply, class_name)
		if not ply.GetCoins or not ply.TakeCoins then return end
		if not REVERSE_UNLOCK_DATA[class_name] then return end

		local cur_lvl = ply:GetNWInt("ms.Ores.MiningAutomation", 0)

		-- if we made the shop deal dont check level
		if ply:GetNWString("MA_BloodDeal", "") ~= "SHOP_DEAL" then
			local lvl_required = REVERSE_UNLOCK_DATA[class_name]
			if cur_lvl < lvl_required then return false, "not unlocked" end
		end

		local price = Ores.Automation.PurchaseData[class_name] * Ores.GetPlayerMultiplier(ply)
		-- if we have the shop deal, double the prices
		if ply:GetNWString("MA_BloodDeal", "") == "SHOP_DEAL" then
			price = price * 2
		end

		if ply:GetCoins() < price then return false, "not enough coins" end

		if ply.GiveItem then
			ply:GiveItem(class_name .. "_item", 1, "Mining Terminal")
		end

		ply:TakeCoins(price, "Mining Terminal: purchased " .. class_name)
		return true
	end

	net.Receive(NET_MSG, function(_, ply)
		local msg_type = net.ReadInt(8)
		if msg_type == NET_MSG_TYPE_UPGRADE then
			upgrade_mining_automation(ply)
		elseif msg_type == NET_MSG_TYPE_PURCHASE then
			local class_name = net.ReadString()
			purchase_mining_equipment(ply, class_name)
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

		-- dont go further if player is already hitting the limit
		if not Ores.Automation.CheckLimit(ply, class_name) then return false end

		local count = ply:GetItemCount(class_name .. "_item")
		if not isnumber(count) or count < 1 then
			local ent_table = scripted_ents.Get(class_name)
			local name = ent_table and ent_table.PrintName or class_name

			if ply:GetInfoNum("mining_automation_autobuy", 0) == 0 then
				Ores.SendChatMessage(ply, 1, "You don't own enough materials to create a " .. name .. "! You can get some at the mining terminal.")

				net.Start(NET_MSG)
				net.WriteInt(NET_MSG_AUTOBUY, 8)
				net.WriteString(class_name)
				net.Send(ply)
			else
				local purchased, reason = purchase_mining_equipment(ply, class_name)
				if purchased then return end

				if purchased == false then
					Ores.SendChatMessage(ply, 1, ("Could not auto-buy materials for %s: %s"):format(name, reason))
				end
			end

			return false
		end
	end)

	-- need this otherwise some stuff doesnt call PlayerSpawnSENT
	hook.Add("OnEntityCreated", "ma_terminal", function(ent)
		if not ent.CPPIGetOwner then return end

		local class_name = ent:GetClass()
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

			owner:TakeItem(class_name .. "_item", 1, "Mining Terminal")
		end)
	end)

	local function send_ranking(ranking)
		net.Start(NET_MSG)
		net.WriteInt(NET_MSG_RANKING, 8)
		net.WriteTable(ranking)
		net.Broadcast()
	end

	local function refresh_ranking()
		if not _G.co or not _G.db then return end

		co(function()
			local ret = db([[SELECT * FROM mining_savedata ORDER BY mult DESC LIMIT 10]])
			if not ret then return end

			local ranking = {}
			for _, data in pairs(ret) do
				table.insert(ranking, { AccountId = data.accountid, Multiplier = data.mult })
			end

			send_ranking(ranking)
		end)
	end

	timer.Create("ma_terminal_ranking", 30, 0, refresh_ranking)
	hook.Add("InitPostEntity", "ma_terminal_ranking", refresh_ranking)
end

if CLIENT then
	local CVAR_AUTOBUY = CreateConVar("mining_automation_autobuy", "0", { FCVAR_ARCHIVE, FCVAR_USERINFO }, "Auto-buys mining equipment when you spawn it if possible.", 0, 1)
	local RANKING_DATA = {}
	local function get_player_name(account_id, callback)
		local steamid_64 = util.SteamID64FromAccountID(tonumber(account_id))
		local ply = player.GetBySteamID64(steamid_64)
		if IsValid(ply) then
			local name = ply:Nick()
			callback(name)
			return
		end

		steamworks.RequestPlayerInfo(steamid_64, callback)
	end

	local function update_ranking_data(rankings)
		local new_ranking_data = {}
		local count = #rankings
		local req_count = 0
		for _, data in pairs(rankings) do
			get_player_name(data.AccountId, function(name)
				table.insert(new_ranking_data, { Name = name, Multiplier = tostring(data.Multiplier) })
				req_count = req_count + 1
				if req_count >= count then
					table.sort(new_ranking_data, function(a, b)
						return tonumber(a.Multiplier) > tonumber(b.Multiplier)
					end)

					RANKING_DATA = new_ranking_data
				end
			end)
		end
	end

	local prompt_opened = false
	net.Receive(NET_MSG, function()
		local msg_type = net.ReadInt(8)
		if msg_type == NET_MSG_RANKING then
			local rankings = net.ReadTable()
			update_ranking_data(rankings)
		elseif msg_type == NET_MSG_AUTOBUY then
			local class_name = net.ReadString()
			local purchase_value = Ores.Automation.PurchaseData[class_name]
			local ent_table = scripted_ents.Get(class_name)
			if purchase_value and istable(ent_table) and cookie.GetNumber("mining_automation_autobuy_prompt", 0) ~= 1 then

				local ply = LocalPlayer()
				local real_purchase_value = purchase_value * Ores.GetPlayerMultiplier(ply)
				-- if we have the shop deal, double the prices
				if ply:GetNWString("MA_BloodDeal", "") == "SHOP_DEAL" then
					real_purchase_value = real_purchase_value * 2
				end

				-- necessary if someone pastes a dupe
				if not prompt_opened then
					prompt_opened = true

					Derma_Query(
						("You are trying to spawn %s, which costs %d coins. Would you like to auto-buy your equipment next time?"):format(ent_table.PrintName, real_purchase_value),
						"Auto-buy",
						"Yes", function()
							CVAR_AUTOBUY:SetInt(1)
							prompt_opened = false
						end,
						"No", function()
							prompt_opened = false
						end
					)

					cookie.Set("mining_automation_autobuy_prompt", "1")
				end
			end
		end
	end)

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
		size = 15,
		weight = 800,
	})

	surface.CreateFont("ma_terminal_btn", {
		font = "Sevastopol Interface",
		size = 15,
	})

	local function add_sheet(sheet, name, title, margin_top, active_tab_name)
		local container = vgui.Create("DPanel", sheet)

		container:Dock(FILL)
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

		local sheet_data = sheet:AddSheet(name, container)
		sheet_data.Button:SetText("")
		sheet_data.Button:SetTall(80 * COEF_H)
		sheet_data.Button:SetWide(200 * COEF_W)
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

	function Ores.Automation.OpenTerminal(active_tab_name)
		local ply = LocalPlayer()
		local cur_lvl = ply:GetNWInt("ms.Ores.MiningAutomation", 0)
		local cur_points = ply:GetNWInt(ms.Ores._nwPoints, 0)
		local upgrade_cost = math.floor(math.max(2000, cur_lvl * 2000))
		local can_upgrade = cur_points >= upgrade_cost
		local max_lvl = cur_lvl == 50

		local frame = vgui.Create("DPanel")
		frame:SetSize(1400 * COEF_W, 1000 * COEF_H)
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

		-- multiplier leaderboard
		do
			local ranking_panel = add_sheet(sheet, "RANKING", "TOP 10 HIGHEST MINING MULTIPLIERS", true, active_tab_name)

			local content_left = ranking_panel:Add("DPanel")
			content_left:Dock(LEFT)
			content_left:SetWide(400 * COEF_W)
			function content_left:Paint() end

			local content_right = ranking_panel:Add("DPanel")
			content_right:Dock(FILL)
			function content_right:Paint() end

			local column_header_left = content_left:Add("DLabel")
			column_header_left:SetText("PLAYER")
			column_header_left:SetTall(20)
			column_header_left:Dock(TOP)
			column_header_left:DockMargin(20 * COEF_W, 20 * COEF_H, 20 * COEF_W, 5 * COEF_H)
			column_header_left:SetFont("ma_terminal_content")

			local column_header_right = content_right:Add("DLabel")
			column_header_right:SetText("MULTIPLIER")
			column_header_right:SetTall(20)
			column_header_right:Dock(TOP)
			column_header_right:DockMargin(20 * COEF_W, 20 * COEF_H, 20 * COEF_W, 5 * COEF_H)
			column_header_right:SetFont("ma_terminal_content")

			local function add_player_rank(name, multiplier)
				local ply_name = content_left:Add("DLabel")
				ply_name:SetTall(20)
				ply_name:Dock(TOP)
				ply_name:DockMargin(20 * COEF_W, 5 * COEF_H, 20 * COEF_W, 5 * COEF_H)
				ply_name:SetFont("ma_terminal_content")
				ply_name:SetText(name)

				local ply_mult = content_right:Add("DLabel")
				ply_mult:SetTall(20)
				ply_mult:Dock(TOP)
				ply_mult:DockMargin(20 * COEF_W, 5 * COEF_H, 20 * COEF_W, 5 * COEF_H)
				ply_mult:SetFont("ma_terminal_content")
				ply_mult:SetText(tostring(multiplier))
			end

			if #RANKING_DATA == 0 then
				add_player_rank("LOADING", 0)
			else
				for i = 1, 10 do
					local rank_data = RANKING_DATA[i]
					if not rank_data then continue end
					add_player_rank(rank_data.Name, rank_data.Multiplier)
				end
			end
		end

		-- stat upgrade
		do
			local upgrade_panel = add_sheet(sheet, "UPGRADE", "ACCESS NEW RESOURCES", false, active_tab_name)
			local header = upgrade_panel:Add("DPanel")
			header:Dock(TOP)
			header:SetTall(60)
			function header:Paint() end

			local stat_name = header:Add("DLabel")
			stat_name:Dock(LEFT)
			stat_name:DockMargin(5 * COEF_W, 20 * COEF_H, 20 * COEF_W, 20 * COEF_H)
			stat_name:SetWide(300 * COEF_W)
			stat_name:SetText(("CURRENT LVL %d"):format(cur_lvl))
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
				if not can_upgrade then return end
				if max_lvl then return end

				net.Start(NET_MSG)
				net.WriteInt(NET_MSG_TYPE_UPGRADE, 8)
				net.SendToServer()

				-- keep the UI up to date
				cur_lvl = math.min(50, cur_lvl + 1)
				cur_points = math.max(0, ply:GetNWInt(ms.Ores._nwPoints, 0) - upgrade_cost)
				upgrade_cost = math.floor(math.max(2000, cur_lvl * 2000))
				can_upgrade = cur_points >= upgrade_cost

				stat_name:SetText(("CURRENT LVL %d"):format(cur_lvl))
				self:SetText(not max_lvl and (can_upgrade and "UPGRADE (%s .PTS)" or "NOT ENOUGH POINTS (%s .PTS)"):format(string.Comma(upgrade_cost)) or "MAXED")
				self:SetTextColor(can_upgrade and COLOR_BLACK or COLOR_WHITE)
				build_unlock_list()

				surface.PlaySound("buttons/weapon_confirm.wav")
			end

			build_unlock_list()
		end

		-- equipment shop
		do
			local shop_panel = add_sheet(sheet, "SHOP", "BUY MINING EQUIPMENT", false, active_tab_name)
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
					local has_lvl = ply:GetNWString("MA_BloodDeal", "") == "SHOP_DEAL" or cur_lvl >= lvl_required
					local real_purchase_value = purchase_value * ms.Ores.GetPlayerMultiplier(ply)
					if ply:GetNWString("MA_BloodDeal", "") == "SHOP_DEAL" then
						real_purchase_value = real_purchase_value * 2
					end

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

		do
			local guide_panel = add_sheet(sheet, "HELP", "LEARN ABOUT AUTOMATION", false, active_tab_name)
			local guide_menu = guide_panel:Add("DColumnSheet")
			guide_menu:Dock(FILL)

			local getting_started_panel = add_sheet(guide_menu, "INTRO", "GETTING STARTED")
			getting_started_panel:Dock(FILL)

			local intro_text = getting_started_panel:Add("RichText")
			intro_text:DockMargin(20 * COEF_W, 20 * COEF_H, 20 * COEF_W, 0)
			intro_text:Dock(FILL)
			intro_text:SetFontInternal("ma_terminal_content")
			intro_text:SetUnderlineFont("ma_terminal_content")
			intro_text:AppendText([[WELCOME TO META MINING!

Until now you may have descended in the mines to get your trusty crowbar and smash some rocks to get ores. While this is a great way to obtain ores it is also not the ONLY way.

INTRODUCING AUTOMATION!

Anywhere in MetaConstruct™ you can place mining equipment. This mining equipment can be used to automate mining. To start your first automation setup you need to head into the SHOP and buy some equipment (I would recommend starting buying drills!). If the equipment you want is locked you first need to unlock it by leveling up your mining automation level in the UGPRADE menu.

To spawn mining equipment, open your spawnmenu (Q by default), head to the "entities" tab and "mining". There you will find all the equipment currently available.

Once you have spawned your equipment you must link it all together, for that you can use the MINING LINKER. This is a tool also available in your spawnmenu, under "Mining". Using the MINING LINKER you can look at your spawned mining equipment and figure out what interfaces they have and what can be linked together.

Each equipment has interfaces (e.g inputs and outputs). These interfaces connect between each others, for example the generator can be linked to drills to power them.
One output may be connected to as many inputs as you want. However one input may only be connected to one output. In practise this means that I can link my generator to many drills but that I can't link my drill to many generators.

THAT'S IT FOR THE BASICS AND GOOD LUCK!]])

			function intro_text:PerformLayout()
				self:SetFontInternal("ma_terminal_content")
				self:SetUnderlineFont("ma_terminal_content")
			end

			local function add_entity_guide_page(class_name)
				local ent_table = scripted_ents.Get(class_name)
				if not istable(ent_table) then return end

				local page_panel = add_sheet(guide_menu, ent_table.PrintName:upper(), ent_table.PrintName:upper())
				local description = ent_table.Description or "No description provided."

				local header = page_panel:Add("DPanel")
				header:Dock(TOP)
				header:DockMargin(5 * COEF_W, 20 * COEF_H, 5 * COEF_W, 20 * COEF_H)
				header:SetTall(100)
				function header:Paint() end

				local picture = header:Add("ContentIcon")
				picture:Dock(LEFT)
				picture:SetMaterial("entities/" .. class_name .. ".png")
				picture:SetName(ent_table.PrintName)

				local text = header:Add("DLabel")
				text:Dock(FILL)
				text:DockMargin(10 * COEF_W, 0, 0, 0, 0)
				text:SetText(description)
				text:SetWrap(true)
				text:SetFont("ma_terminal_content")

				local interfaces_container = page_panel:Add("DScrollPanel")
				interfaces_container:Dock(FILL)

				local ma_data = ent_table.MiningAutomationData
				local input_count, output_count =
					ma_data.Inputs and table.Count(ma_data.Inputs) or 0,
					ma_data.Outputs and table.Count(ma_data.Outputs) or 0

				if input_count > 0 then
					local inputs = interfaces_container:Add("DLabel")
					inputs:SetText(("INPUTS (%d):"):format(input_count))
					inputs:SetFont("ma_terminal_content")
					inputs:Dock(TOP)
					inputs:DockMargin(20 * COEF_W, 20 * COEF_H, 0, 0)

					for _, input_data in pairs(ma_data.Inputs) do
						local input_name = interfaces_container:Add("DLabel")
						input_name:SetText("- " .. input_data.Name)
						input_name:SetFont("ma_terminal_content")
						input_name:Dock(TOP)
						input_name:DockMargin(20 * COEF_W, 5 * COEF_H, 0, 0)

						local input_desc = interfaces_container:Add("DLabel")
						input_desc:SetText("    " .. input_data.Description)
						input_desc:SetFont("ma_terminal_content")
						input_desc:Dock(TOP)
						input_desc:DockMargin(20 * COEF_W, 0, 0, 0)
						input_desc:SetWrap(true)
						input_desc:SetTall(30)
					end
				end

				if output_count > 0 then
					local outputs = interfaces_container:Add("DLabel")
					outputs:SetText(("OUTPUTS (%d):"):format(output_count))
					outputs:SetFont("ma_terminal_content")
					outputs:Dock(TOP)
					outputs:DockMargin(20 * COEF_W, 20 * COEF_H, 0, 0, 0)

					for _, output_data in pairs(ma_data.Outputs) do
						local output_name = interfaces_container:Add("DLabel")
						output_name:SetText("- " .. output_data.Name)
						output_name:SetFont("ma_terminal_content")
						output_name:Dock(TOP)
						output_name:DockMargin(20 * COEF_W, 5 * COEF_H, 0, 0)

						local output_desc = interfaces_container:Add("DLabel")
						output_desc:SetText("    " .. output_data.Description)
						output_desc:SetFont("ma_terminal_content")
						output_desc:Dock(TOP)
						output_desc:DockMargin(20 * COEF_W, 0, 0, 0)
						output_desc:SetWrap(true)
						output_desc:SetTall(30)
					end
				end
			end

			for class_name, _ in pairs(_G.MA_Orchestrator.WatchedClassNames) do
				add_entity_guide_page(class_name)
			end
		end
	end

	concommand.Add("mining_automation_terminal", function()
		Ores.Automation.OpenTerminal()
	end)
end