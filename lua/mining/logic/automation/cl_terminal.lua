if true then return end

local UNLOCK_DATA = { -- *10
	[1] = { "ma_drill_v2", "ma_gen_v2", "ma_transformer_v2", "ma_storage_v2" },
	[2] = { "ma_merger_v2"  },
	[3] = { "ma_oil_extractor_v2", "ma_smelter_v2" },
	[4] = { "ma_minter_v2", "ma_refinery" },
	[5] = { "ma_chip_router_v2", "ma_drone_controller_v2" },
}

surface.CreateFont("ma_terminal_header", {
	font = "Sevastopol Interface",
	size = 20
})

surface.CreateFont("ma_terminal_content", {
	font = "Sevastopol Interface",
	size = 15
})

local frame = vgui.Create("DFrame")
frame:SetSize(800, 600)
frame:Center()
frame:MakePopup(0)
frame:SetTitle("")

frame.btnMaxim:Hide()
frame.btnMinim:Hide()
frame.btnClose:Hide()

function frame.btnClose:Paint(w, h)
	surface.SetDrawColor(14, 92, 59)
	surface.DrawRect(0, 0, w, h)
end

local MONITOR_MODEL = "models/props_lab/monitor01b.mdl"
local MONITOR_SCALE = Vector(1, 1.05, 0.78)
local ply = LocalPlayer()
function frame:Paint(w, h)
	-- Set up the 3D camera
	cam.Start3D(ply:EyePos(), ply:EyeAngles())

	-- Set the position and angle of the model
	local pos = ply:EyePos() + ply:GetAimVector() * 16 + ply:GetUp() * 0.35 + ply:GetRight() * -1.1  -- Position in the world (adjust accordingly)
	local ang = ply:EyeAngles()  -- Angle of the model
	ang:RotateAroundAxis(ply:GetRight(), 180)
	--ang.pitch = 194

	-- Draw the model
	local ent = ClientsideModel(MONITOR_MODEL, RENDERGROUP_OPAQUE)
	if ent then
		ent:SetMaterial("phoenix_storms/OfficeWindow_1-1")
		ent:SetPos(pos)
		ent:SetAngles(ang)

		local mtx = Matrix()
		mtx:Scale(MONITOR_SCALE)
		ent:EnableMatrix("RenderMultiply", mtx)

		render.SetLightingMode(2)
		ent:DrawModel()
		render.SetLightingMode(0)

		ent:Remove()  -- Clean up after drawing
	end

	cam.End3D()

	surface.SetDrawColor(23, 47, 25, 255)
	surface.DrawRect(0, 0, w, h)

	surface.SetDrawColor(15, 180, 104)
	surface.DrawRect(5, 5, w - 10, 20)

	surface.SetTextColor(23, 47, 25, 255)
	surface.SetTextPos(7, 7)
	surface.SetFont("ma_terminal_header")
	surface.DrawText("PERSONAL TERMINAL")

	surface.SetTextColor(15, 180, 104)
	surface.SetTextPos(15, 60)
	surface.DrawText("FOLDERS")
end

local TERMINAL_MAT = Material("effects/combine_binocoverlay")
function frame:PaintOver(w, h)
	surface.SetMaterial(TERMINAL_MAT)
	surface.SetDrawColor(0, 255, 0, 1)
	surface.DrawTexturedRect(-50, -50, w + 100, h + 100)
end

local sheet = frame:Add("DColumnSheet")
sheet:Dock(FILL)

local function add_sheet(name, title, margin_top)
	local container = vgui.Create("DPanel", sheet)

	container:DockMargin(20, 0, 0, 0)
	function container:Paint(w, h) end

	local title_panel = container:Add("DLabel")
	title_panel:Dock(TOP)
	title_panel:DockMargin(5, 20, 5, 5)
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
	inner_panel:DockMargin(5, 5, 5, 5)
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

	local old_DoClick = sheet_data.Button.DoClick
	function sheet_data.Button:DoClick()
		old_DoClick(self)
		surface.PlaySound("buttons/button16.wav")
	end

	if margin_top then
		sheet_data.Button:DockMargin(0, 50, 0, 0)
	else
		sheet_data.Button:DockMargin(0, 5, 0, 0)
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
	local can_upgrade = true
	local cur_lvl = 40

	local upgrade_panel = add_sheet("UPGRADE", "ACCESS NEW RESOURCES", true)
	local header = upgrade_panel:Add("DPanel")
	header:Dock(TOP)
	header:SetTall(60)
	function header:Paint() end

	local stat_name = header:Add("DLabel")
	stat_name:Dock(LEFT)
	stat_name:DockMargin(5, 20, 20, 20)
	stat_name:SetWide(400)
	stat_name:SetText(("CURRENT LVL %d %s"):format(cur_lvl, can_upgrade and "[UPGRADE POSSIBLE]" or ""))
	stat_name:SetColor(Color(255, 255, 255, 255))
	stat_name:SetFont("ma_terminal_header")

	local stat_upgrade = header:Add("DButton")
	stat_upgrade:Dock(FILL)
	stat_upgrade:DockMargin(20, 20, 5, 20)
	stat_upgrade:SetText("UPGRADE")
	stat_upgrade:SetTextColor(Color(0, 0, 0, 255))
	stat_upgrade:SetFont("ma_terminal_header")

	function stat_upgrade:DoClick()
		surface.PlaySound("buttons/weapon_confirm.wav")
	end

	function stat_upgrade:Paint(w, h)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawRect(0, 0, w, h)
	end

	local content = upgrade_panel:Add("DPanel")
	content:Dock(FILL)
	function content:Paint() end

	local content_left = content:Add("DPanel")
	content_left:Dock(LEFT)
	content_left:SetWide(400)
	function content_left:Paint() end

	local content_right = content:Add("DPanel")
	content_right:Dock(FILL)
	function content_right:Paint() end

	for i = 1, #UNLOCK_DATA do
		local lvl_required = i * 10
		local class_names = UNLOCK_DATA[i]
		for _, class_name in ipairs(class_names) do
			local ent_table = scripted_ents.Get(class_name)
			if not ent_table then continue end

			local equipment = content_left:Add("DLabel")
			equipment:Dock(TOP)
			equipment:DockMargin(20, 5, 20, 5)
			equipment:SetFont("ma_terminal_content")
			equipment:SetText("- " .. ent_table.PrintName:upper())

			local equipment_status = content_right:Add("DLabel")
			equipment_status:Dock(TOP)
			equipment_status:DockMargin(20, 5, 20, 5)
			equipment_status:SetFont("ma_terminal_content")
			equipment_status:SetTextColor(lvl_required <= cur_lvl and Color(255, 255, 255, 255) or Color(220, 150, 0, 255))
			equipment_status:SetText(lvl_required <= cur_lvl and "[ UNLOCKED ]" or ("[ LVL. %d ]"):format(lvl_required))
		end
	end
end

-- equipment shop
do
	local shop_panel = add_sheet("SHOP", "BUY MINING EQUIPMENT")

end


add_sheet("GUIDE", "LEARN ABOUT AN EQUIPMENT")

timer.Simple(20, function()
	if not IsValid(frame) then return end

	frame:Remove()
end)