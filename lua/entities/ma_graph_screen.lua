AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Graph Screen"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = true
ENT.ClassName = "ma_graph_screen"

if SERVER then
	resource.AddFile("materials/entities/ma_merger_v2.png")

	function ENT:Initialize()
		self:SetModel("models/hunter/plates/plate1x1.mdl")
		self:SetMaterial("models/debug/debugwhite")
		self:SetColor(Color(0, 0, 0, 255))
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()

		Ores.Automation.PrepareForDuplication(self)
	end
end

if CLIENT then
	surface.CreateFont("ma_terminal_connection", {
		font = "Arial",
		size = 20,
		weight = 800,
		outline = true,
	})

	surface.CreateFont("ma_terminal_node", {
		font = "Roboto",
		size = 25,
		weight = 500,
		outline = true,
	})

	local MAX_MAP_SIZE = 32768
	local MAX_MAP_OFFSET = Vector(MAX_MAP_SIZE / 2, MAX_MAP_SIZE / 2, 0)

	local function graph(ply, real_width, real_height)
		local graph_padding = 50
		local max_width, max_height = real_width - graph_padding * 3, real_height - graph_padding * 6
		local min_x, max_x = 2e9, -2e9
		local min_y, max_y = 2e9, -2e9

		local ply_ents = {}
		for _, ent in ipairs(ents.FindByClass("ma_*")) do
			if ent:GetClass() == "ma_graph_screen" then continue end
			if ent.CPPIGetOwner and ent:CPPIGetOwner() ~= ply then continue end

			table.insert(ply_ents, ent)

			local pos = ent:WorldSpaceCenter() + MAX_MAP_OFFSET
			if pos.x > max_x then
				max_x = pos.x
			end

			if pos.x < min_x then
				min_x = pos.x
			end

			if pos.y > max_y then
				max_y = pos.y
			end

			if pos.y < min_y then
				min_y = pos.y
			end
		end

		local graph_width, graph_height = max_x - min_x, max_y - min_y
		local coef_w, coef_h = (max_width / MAX_MAP_SIZE) + (max_width / graph_width), (max_height / MAX_MAP_SIZE) + (max_height / graph_height)
		local grid_size = 10 * coef_w
		local time = CurTime()

		surface.SetDrawColor(0, 0, 0, 255)
		surface.DrawRect(0, 0, real_width, real_height)

		for i = 1, real_width / grid_size do
			surface.SetDrawColor(36, 36, 36, 255)
			surface.DrawLine(grid_size * i, 0, grid_size * i, real_height)
			surface.DrawLine(0, grid_size * i, real_width, grid_size * i)
		end

		for _, ent in ipairs(ply_ents) do
			if ent:GetClass() == "ma_graph_screen" then continue end
			local pos = ent:WorldSpaceCenter() + MAX_MAP_OFFSET
			local pos_x, pos_y = (pos.x - min_x) * coef_w + graph_padding, (pos.y - min_y) * coef_h + graph_padding

			local data = _G.MA_Orchestrator.LinkData[ent:EntIndex()]
			if not data then continue end
			for input_id, link_data in pairs(data) do
				local input_data = _G.MA_Orchestrator.GetInputData(ent, input_id)
				if not input_data then continue end

				local target_ent = Entity(link_data.EntIndex)
				if not IsValid(target_ent) then continue end

				local target_pos = target_ent:WorldSpaceCenter() + MAX_MAP_OFFSET
				local target_pos_x, target_pos_y = (target_pos.x - min_x) * coef_w + graph_padding, (target_pos.y - min_y) * coef_h + graph_padding
				local target_canot_work = isfunction(target_ent.CanWork) and not target_ent:CanWork(time)

				if not target_canot_work then
					surface.SetDrawColor(255, 255, 255)
				else
					surface.SetDrawColor(255, 0, 0, 255)
				end

				surface.DrawLine(pos_x, pos_y, target_pos_x, target_pos_y)

				if not target_canot_work then
					local function get_point_on_line(t)
						local x = pos_x + t * (target_pos_x - pos_x)
						local y = pos_y + t * (target_pos_y - pos_y)
						return x, y
					end

					local dist_squared = (target_pos_x - pos_x) ^ 2 + (target_pos_y - pos_y) ^ 2
					local max_flow_points = math.min(5, math.ceil(dist_squared / 500000))
					for i = 1, max_flow_points do
						local flow_x, flow_y = get_point_on_line(((CurTime() * -100 + (100 * i)) % 1000) / 1000)
						surface.DrawRect(flow_x - 2.5, flow_y - 2.5, 5, 5)

						surface.SetTextColor(255, 255, 255, 255)
						surface.SetFont("DermaDefaultBold")
						local tw, th = surface.GetTextSize(input_data.Type)
						surface.SetTextPos(flow_x - tw / 2, flow_y - th / 2)
						surface.DrawText(input_data.Type)
					end
				end

				surface.SetFont("ma_terminal_connection")
				if not target_canot_work then
					surface.SetTextColor(0, 255, 0, 255)
				else
					surface.SetTextColor(255, 0, 0, 255)
				end
				local text = input_data.Name:upper()
				local tw, th = surface.GetTextSize(text)
				surface.SetTextPos((pos_x + target_pos_x) / 2 - tw / 2, (pos_y + target_pos_y) / 2 - th / 2)
				surface.DrawText(text)
			end
		end

		local legend = {}
		for _, ent in ipairs(ply_ents) do
			if ent:GetClass() == "ma_graph_screen" then continue end
			local pos = ent:WorldSpaceCenter() + MAX_MAP_OFFSET
			local pos_x, pos_y = (pos.x - min_x) * coef_w + graph_padding, (pos.y - min_y) * coef_h + graph_padding

			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawRect(pos_x - 20, pos_y - 20, 40, 40)
			if isfunction(ent.CanWork) and not ent:CanWork(time) then
				surface.SetDrawColor(255, 0, 0)
			else
				surface.SetDrawColor(0, 255, 0)
			end
			surface.DrawOutlinedRect(pos_x - 20, pos_y - 20, 40, 40, 2)

			surface.SetFont("ma_terminal_node")
			surface.SetTextColor(255, 255, 255, 255)

			local words = ent.PrintName:Split(" ")
			local ent_name = (words[1][1] .. (words[2] or "")[1]):upper()
			legend[ent_name] = ent.PrintName

			local tw, th = surface.GetTextSize(ent_name)
			surface.SetTextPos(pos_x - tw / 2, pos_y - th / 2)
			surface.DrawText(ent_name)
		end

		local i = 0
		local legend_margin = 100
		local legend_width = table.Count(legend) * (40 + legend_margin)

		surface.SetDrawColor(36, 36, 36, 255)
		surface.DrawRect(real_width / 2 - legend_width / 2 - 80, real_height - 140, legend_width + 20, 120)

		for symbol, name in pairs(legend) do
			local pos_x, pos_y = real_width / 2 - legend_width / 2 + i * (40 + legend_margin), real_height - 100

			surface.SetDrawColor(0, 0, 0, 255)
			surface.DrawRect(pos_x - 20, pos_y - 20, 40, 40)
			surface.SetDrawColor(0, 255, 0, 255)
			surface.DrawOutlinedRect(pos_x - 20, pos_y - 20, 40, 40, 2)

			surface.SetFont("ma_terminal_node")
			local tw, th = surface.GetTextSize(symbol)
			surface.SetTextPos(pos_x - tw / 2, pos_y - th / 2)
			surface.DrawText(symbol)

			surface.SetFont("DermaDefault")
			tw, th = surface.GetTextSize(name)
			surface.SetTextPos(pos_x - tw / 2, pos_y + 40 + 5)
			surface.DrawText(name)

			i = i + 1
		end
	end

	function ENT:Draw()
		self:DrawModel()

		local ply = self.CPPIGetOwner and self:CPPIGetOwner()
		if not IsValid(ply) then return end

		local maxs = self:OBBMaxs()
		local scale = (maxs.x * 2) / 1440

		cam.Start3D2D(self:GetPos() + self:GetRight() * -maxs.x + self:GetForward() * -maxs.y + self:GetUp() * maxs.z, self:GetAngles(), scale)
			graph(ply, 1440, 1440)
		cam.End3D2D()
	end
end