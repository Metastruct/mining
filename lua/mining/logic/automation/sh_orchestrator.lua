local orchestrator = _G.MA_Orchestrator or {}
_G.MA_Orchestrator = orchestrator
orchestrator.WatchedEntities = orchestrator.WatchedEntities or {}

function orchestrator.RegisterInput(ent, id, type, name, description)
	if not IsValid(ent) then return end

	ent.MiningAutomationData = ent.MiningAutomationData or {}
	ent.MiningAutomationData.Inputs = ent.MiningAutomationData.Inputs or {}

	ent.MiningAutomationData.Inputs[id] = {
		Id = id,
		Name = name,
		Description = description,
		Type = type,
		Ent = ent,
		Link = { Ent = NULL, Id = "" },
	}

	if SERVER then
		orchestrator.WatchedEntities[ent] = true
	end
end

function orchestrator.RegisterOutput(ent, id, type, name, description)
	if not IsValid(ent) then return end

	ent.MiningAutomationData = ent.MiningAutomationData or {}
	ent.MiningAutomationData.Outputs = ent.MiningAutomationData.Outputs or {}

	ent.MiningAutomationData.Outputs[id] = {
		Id = id,
		Name = name,
		Description = description,
		Type = type,
		Ent = ent,
		Links = {},
	}

	if SERVER then
		orchestrator.WatchedEntities[ent] = true
	end
end

function orchestrator.GetOutputs(ent)
	if not IsValid(ent) then return {} end

	if ent.MiningAutomationData and ent.MiningAutomationData.Outputs then
		return table.ClearKeys(ent.MiningAutomationData.Outputs)
	else
		return {}
	end
end

function orchestrator.GetInputs(ent)
	if not IsValid(ent) then return {} end

	if ent.MiningAutomationData and ent.MiningAutomationData.Inputs then
		return table.ClearKeys(ent.MiningAutomationData.Inputs)
	else
		return {}
	end
end

function orchestrator.GetInputData(ent, id)
	if ent.MiningAutomationData and ent.MiningAutomationData.Inputs and ent.MiningAutomationData.Inputs[id] then
		return ent.MiningAutomationData.Inputs[id]
	end
end

function orchestrator.GetOutputData(ent, id)
	if ent.MiningAutomationData and ent.MiningAutomationData.Outputs and ent.MiningAutomationData.Outputs[id] then
		return ent.MiningAutomationData.Outputs[id]
	end
end

local NET_MSG_NAME = "net_mining_automation"
local NET_TYPE_LINK = 1
local NET_TYPE_UNLINK = 2
local NET_TYPE_FULL_SYNC = 3
local NET_TYPE_PARTIAL_SYNC = 4

if SERVER then
	util.AddNetworkString(NET_MSG_NAME)

	net.Receive(NET_MSG_NAME, function(_, ply)
		local msg_type = net.ReadInt(8)
		if msg_type == NET_TYPE_LINK then
			local output_ent = net.ReadEntity()
			local output_id = net.ReadString()

			local input_ent = net.ReadEntity()
			local input_id = net.ReadString()

			if output_ent.CPPIGetOwner and output_ent:CPPIGetOwner() ~= ply then return end
			if input_ent.CPPIGetOwner and input_ent:CPPIGetOwner() ~= ply then return end

			local input_data = orchestrator.GetInputData(input_ent, input_id)
			if orchestrator.IsInputLinked(input_data) then
				-- if the input is already linked, unlink it before
				orchestrator.UnlinkInput(input_data)
			end

			orchestrator.Link(orchestrator.GetOutputData(output_ent, output_id), input_data)
		elseif msg_type == NET_TYPE_UNLINK then
			local is_output = net.ReadBool()
			local interface_ent = net.ReadEntity()
			local interface_id = net.ReadString()

			if interface_ent.CPPIGetOwner and interface_ent:CPPIGetOwner() ~= ply then return end

			if is_output then
				orchestrator.UnlinkOutput(orchestrator.GetOutputData(interface_ent, interface_id))
			else
				orchestrator.UnlinkInput(orchestrator.GetInputData(interface_ent, interface_id))
			end
		end
	end)

	local function call_entity_fn(ent, name, ...)
		if not IsValid(ent) then return end

		local fn = ent["MA_" .. name]
		if isfunction(fn) then
			return fn(ent, ...)
		end
	end

	function orchestrator.Execute(output_data, input_data)
		if output_data.Type ~= input_data.Type then return end
		if not IsValid(output_data.Ent) or not IsValid(input_data.Ent) then return end

		local ret = call_entity_fn(input_data.Ent, "CanProcessOutput", output_data, input_data)
		if ret == false then return end

		ret = call_entity_fn(output_data.Ent, "CanProcessInput", input_data, output_data)
		if ret == false then return end

		return call_entity_fn(input_data.Ent, "Execute", output_data, input_data)
	end

	function orchestrator.IsInputLinked(input_data)
		return IsValid(input_data.Link.Ent) and input_data.Link.Id ~= ""
	end

	local VECTOR_ZERO = Vector(0, 0, 0)
	function orchestrator.Link(output_data, input_data)
		if output_data.Type ~= input_data.Type then return end
		if not IsValid(output_data.Ent) or not IsValid(input_data.Ent) then return end
		if output_data.Ent == input_data.Ent then return end

		-- input is already linked, can't link to multiple outputs
		if orchestrator.IsInputLinked(input_data) then return end

		local ret = call_entity_fn(input_data.Ent, "CanLink", output_data, input_data)
		if ret == false then return end

		ret = call_entity_fn(output_data.Ent, "CanLink", input_data, output_data)
		if ret == false then return end

		local cable = constraint.CreateKeyframeRope(input_data.Ent:WorldSpaceCenter(), 1, "cable/cable2", input_data.Ent, input_data.Ent, VECTOR_ZERO, 0, output_data.Ent, VECTOR_ZERO, 0, {})
		output_data.Links[input_data.Ent] = output_data.Links[input_data.Ent] or {}
		output_data.Links[input_data.Ent][input_data.Id] = true
		input_data.Link = { Ent = output_data.Ent, Id = output_data.Id, Cable = cable }

		call_entity_fn(input_data.Ent, "OnLink", output_data, input_data)

		local owner = input_data.Ent.CPPIGetOwner and input_data.Ent:CPPIGetOwner()
		orchestrator.SendPartialLinkData(owner, false, output_data, input_data)
	end

	function orchestrator.UnlinkOutput(output_data)
		if not IsValid(output_data.Ent) then return end

		for ent, input_ids in pairs(output_data.Links) do
			for input_id, _ in pairs(input_ids) do
				local input_data = orchestrator.GetInputData(ent, input_id)
				if not input_data then continue end

				SafeRemoveEntity(input_data.Link.Cable)
				input_data.Link = { Ent = NULL, Id = "" }
				call_entity_fn(input_data.Ent, "OnUnlink", output_data, input_data)

				local owner = input_data.Ent.CPPIGetOwner and input_data.Ent:CPPIGetOwner()
				orchestrator.SendPartialLinkData(owner, true, output_data, input_data)
			end
		end
	end

	function orchestrator.UnlinkInput(input_data)
		if not IsValid(input_data.Ent) then return end
		if not orchestrator.IsInputLinked(input_data) then return end

		local output_data = orchestrator.GetOutputData(input_data.Link.Ent, input_data.Link.Id)
		if output_data.Links[input_data.Ent] then
			output_data.Links[input_data.Ent][input_data.Id] = nil

			if table.Count(output_data.Links[input_data.Ent]) < 1 then
				output_data.Links[input_data.Ent] = nil
			end
		end

		SafeRemoveEntity(input_data.Link.Cable)
		input_data.Link = { Ent = NULL, Id = "" }

		call_entity_fn(input_data.Ent, "OnUnlink", output_data, input_data)

		local owner = input_data.Ent.CPPIGetOwner and input_data.Ent:CPPIGetOwner()
		orchestrator.SendPartialLinkData(owner, true, output_data, input_data)
	end

	function orchestrator.SendOutputReadySignal(output_data)
		if not IsValid(output_data.Ent) then return end

		for ent, input_ids in pairs(output_data.Links) do
			if not IsValid(ent) then
				output_data.Links[ent] = nil
				continue
			end

			for input_id, _ in pairs(input_ids) do
				local input_data = orchestrator.GetInputData(ent, input_id)
				if not input_data then continue end

				call_entity_fn(ent, "OnOutputReady", output_data, input_data)
			end
		end
	end

	function orchestrator.SendLinkData(ply)
		local data = {}
		for ent, _ in pairs(orchestrator.WatchedEntities) do
			if not IsValid(ent) then
				orchestrator.WatchedEntities[ent] = nil
				continue
			end

			if ent.CPPIGetOwner and ent:CPPIGetOwner() ~= ply then continue end

			local inputs = orchestrator.GetInputs(ent)
			for _, input_data in ipairs(inputs) do
				if not orchestrator.IsInputLinked(input_data) then continue end

				local link_data = {
					InputEnt = ent:EntIndex(),
					InputId = input_data.Id,
					OutputEnt = input_data.Link.Ent:EntIndex(),
					OutputId = input_data.Link.Id,
					LinkEnt = input_data.Cable:EntIndex(),
				}

				table.insert(data, link_data)
			end
		end

		net.Start(NET_MSG_NAME)
			net.WriteInt(NET_TYPE_FULL_SYNC, 8)
			net.WriteTable(data)
		net.Send(ply or player.GetAll())
	end

	function orchestrator.SendPartialLinkData(ply, is_unlink, output_data, input_data)
		net.Start(NET_MSG_NAME)
			net.WriteInt(NET_TYPE_PARTIAL_SYNC, 8)
			net.WriteBool(is_unlink)

			net.WriteInt(output_data.Ent:EntIndex(), 32)
			net.WriteString(output_data.Id)

			net.WriteInt(input_data.Ent:EntIndex(), 32)
			net.WriteString(input_data.Id)

			if not is_unlink then
				net.WriteInt(input_data.Link.Cable:EntIndex(), 32)
			end
		net.Send(ply or player.GetAll())
	end

	hook.Add("EntityRemoved", "ma_orchestrator", function(ent)
		if not orchestrator.WatchedEntities[ent] then return end

		for _, output_data in ipairs(orchestrator.GetOutputs()) do
			orchestrator.UnlinkOutput(output_data)
		end

		for _, input_data in ipairs(orchestrator.GetInputs()) do
			orchestrator.UnlinkInput(input_data)
		end

		orchestrator.WatchedEntities[ent] = nil
	end)
end

if CLIENT then
	orchestrator.LinkData = orchestrator.LinkData or {}

	net.Receive(NET_MSG_NAME, function()
		local msg_type = net.ReadInt(8)
		if msg_type == NET_TYPE_PARTIAL_SYNC then
			local is_unlink = net.ReadBool()

			local output_ent_index = net.ReadInt(32)
			local output_id = net.ReadString()

			local input_ent_index = net.ReadInt(32)
			local input_id = net.ReadString()

			if is_unlink then
				if not orchestrator.LinkData[input_ent_index] then return end
				if not orchestrator.LinkData[input_ent_index][input_id] then return end

				orchestrator.LinkData[input_ent_index][input_id] = nil
				if table.Count(orchestrator.LinkData[input_ent_index]) == 0 then
					orchestrator.LinkData[input_ent_index] = nil
				end
			else
				local cable_ent_index = net.ReadInt(32)
				if not orchestrator.LinkData[input_ent_index] then
					orchestrator.LinkData[input_ent_index] = {}
				end

				orchestrator.LinkData[input_ent_index][input_id] = {
					EntIndex = output_ent_index,
					Id = output_id,
					CableEntIndex = cable_ent_index
				}
			end
		end
	end)

	function orchestrator.IsInputLinked(input_data)
		local data = orchestrator.LinkData[input_data.Ent:EntIndex()]
		if not data then return false end
		if not data[input_data.Id] then return false end

		return true
	end

	function orchestrator.Link(output_data, input_data)
		if not IsValid(output_data.Ent) then return end
		if not IsValid(input_data.Ent) then return end

		net.Start(NET_MSG_NAME)
			net.WriteInt(NET_TYPE_LINK, 8)

			net.WriteEntity(output_data.Ent)
			net.WriteString(output_data.Id)

			net.WriteEntity(input_data.Ent)
			net.WriteString(input_data.Id)
		net.SendToServer()
	end

	function orchestrator.Unlink(is_output, interface_data)
		if not IsValid(interface_data.Ent) then return end

		net.Start(NET_MSG_NAME)
			net.WriteInt(NET_TYPE_UNLINK, 8)

			net.WriteBool(is_output)
			net.WriteEntity(interface_data.Ent)
			net.WriteString(interface_data.Id)
		net.SendToServer()
	end

	surface.CreateFont("ma_hud_title", {
		font = "Arial",
		extended = false,
		size = 25,
		weight = 600,
	})

	surface.CreateFont("ma_hud_text", {
		font = "Arial",
		extended = true,
		size = 20,
		weight = 500,
	})

	local BLUR = Material("pp/blurscreen")
	local function blur_rect(x, y, w, h, layers, quality)
		surface.SetMaterial(BLUR)
		surface.SetDrawColor(255, 255, 255)

		render.SetScissorRect(x, y, x + w, y + h, true)
			for i = 1, layers do
				BLUR:SetFloat("$blur", (i / layers) * quality)
				BLUR:Recompute()

				render.UpdateScreenEffectTexture()
				surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
			end
		render.SetScissorRect(0, 0, 0, 0, false)
	end

	local looked_at = {}
	hook.Add("HUDPaint", "ma_orchestrator", function()
		looked_at[1] = nil

		local ply = LocalPlayer()
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) then return end
		if wep:GetClass() ~= "gmod_tool" then return end

		local tool = wep:GetToolObject()
		if not tool then return end
		if tool.Mode ~= "mining_linker" then return end

		local ent = ply:GetEyeTrace().Entity
		if not IsValid(ent) then return end
		if not ent:GetClass():match("^ma_") then return end

		surface.SetFont("ma_hud_title")

		local selected_output = tool:GetSelectedOutput()
		if selected_output and selected_output.Ent == ent then return end

		local interfaces = selected_output and orchestrator.GetInputs(ent) or orchestrator.GetOutputs(ent)
		if #interfaces == 0 then return end

		table.sort(interfaces, function(a, b) return a.Name < b.Name end)

		looked_at[1] = ent

		local title_font_height = draw.GetFontHeight("ma_hud_title") + 10
		local font_height = draw.GetFontHeight("ma_hud_text")
		local margin = 15
		local max_width, _ = surface.GetTextSize(ent.PrintName:upper())
		local max_height = (#interfaces + 1) * (font_height + margin) + (title_font_height + margin)

		surface.SetFont("ma_hud_text")
		for _, interface_data in ipairs(interfaces) do
			local interface_name = (" %s [%s]"):format(interface_data.Name, interface_data.Type)
			if selected_output and orchestrator.IsInputLinked(interface_data) then
				interface_name = interface_name .. " (L) "
			end

			local tw, _ = surface.GetTextSize(interface_name)
			if tw > max_width then
				max_width = tw
			end
		end

		local base_x, base_y = ScrW() / 2 - max_width / 2, ScrH() / 2 - max_height / 2
		blur_rect(base_x - 10, base_y - 10, max_width + 20, max_height + 20, 10, 2)

		surface.SetDrawColor(0, 0, 0, 100)
		surface.DrawRect(base_x - 10, base_y - 10, max_width + 20, max_height + 20)

		surface.SetFont("ma_hud_title")
		surface.SetTextColor(255, 255, 255, 255)
		surface.SetTextPos(base_x, base_y)
		surface.DrawText(ent.PrintName:upper())

		surface.SetDrawColor(72, 72, 72, 255)
		surface.DrawRect(base_x, base_y + font_height + margin, max_width, 2)

		surface.SetFont("ma_hud_text")
		surface.SetTextPos(base_x, base_y + font_height + margin + margin / 2)
		if selected_output then
			surface.SetTextColor(180, 139, 255)
			surface.DrawText("« [INPUTS]")
		else
			surface.SetTextColor(255, 0, 89)
			surface.DrawText("[OUTPUTS] »")
		end

		local text_base_y = base_y + title_font_height + margin
		for i, interface_data in ipairs(interfaces) do
			surface.SetDrawColor(0, 0, 0, 150)
			surface.DrawRect(base_x, text_base_y + ((font_height + margin) * i) - margin / 2, max_width, font_height + margin)

			if selected_output then
				if selected_output.Type ~= interface_data.Type then
					surface.SetTextColor(200, 75, 75, 255)
				elseif orchestrator.IsInputLinked(interface_data) then
					surface.SetTextColor(116, 189, 116)
				else
					surface.SetTextColor(255, 255, 255, 255)
				end
			else
				surface.SetTextColor(255, 255, 255, 255)
			end

			surface.SetTextPos(base_x, text_base_y + ((font_height + margin) * i))
			local interface_name = (" %s [%s]"):format(interface_data.Name, interface_data.Type)
			if selected_output and orchestrator.IsInputLinked(interface_data) then
				interface_name = interface_name .. " (L) "
			end

			surface.DrawText(interface_name)

			if i == ((tool.CurrentIndex % #interfaces) + 1) then
				surface.SetDrawColor(255, 200, 0, 255)
				surface.DrawOutlinedRect(base_x, text_base_y + ((font_height + margin) * i) - margin / 2, max_width, font_height + margin, 2)
			end
		end

		if selected_output then
			surface.SetTextColor(255, 255, 255, 255)
			surface.SetTextPos(base_x - 10, base_y + max_height + 20)

			local text = ("Selected Output: %s [%s]"):format(selected_output.Name, selected_output.Ent.PrintName)
			surface.DrawText(text)
		end
	end)

	local COLOR_SELECTED = Color(255, 200, 0, 255)
	hook.Add("PreDrawHalos", "ma_orchestrator", function()
		halo.Add(looked_at, COLOR_SELECTED, 5, 5, 2)
	end)
end