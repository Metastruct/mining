local orchestrator = _G.MA_Orchestrator or {}
_G.MA_Orchestrator = orchestrator
orchestrator.WatchedEntities = orchestrator.WatchedEntities or {}
orchestrator.WatchedClassNames = orchestrator.WatchedClassNames or {}

function orchestrator.RegisterInput(ent_table, id, type, name, description)
	assert(isstring(ent_table.ClassName), "ENT.ClassName was not provided")

	ent_table.MiningAutomationData = ent_table.MiningAutomationData or {}
	ent_table.MiningAutomationData.Inputs = ent_table.MiningAutomationData.Inputs or {}

	ent_table.MiningAutomationData.Inputs[id] = {
		Id = id,
		Name = name,
		Description = description,
		Type = type,
		Ent = NULL,
		Link = { Ent = NULL, Id = "" },
	}

	orchestrator.WatchedClassNames[ent_table.ClassName] = true
end

function orchestrator.RegisterOutput(ent_table, id, type, name, description)
	assert(isstring(ent_table.ClassName), "ENT.ClassName was not provided")

	ent_table.MiningAutomationData = ent_table.MiningAutomationData or {}
	ent_table.MiningAutomationData.Outputs = ent_table.MiningAutomationData.Outputs or {}

	ent_table.MiningAutomationData.Outputs[id] = {
		Id = id,
		Name = name,
		Description = description,
		Type = type,
		Ent = NULL,
		Links = {},
	}

	orchestrator.WatchedClassNames[ent_table.ClassName] = true
end

function orchestrator.GetOutputs(ent)
	if not IsValid(ent) then return {} end

	if ent.MiningAutomationData and ent.MiningAutomationData.Outputs then
		local ret = {}
		for _, output_data in pairs(ent.MiningAutomationData.Outputs) do
			output_data.Ent = ent
			table.insert(ret, output_data)
		end

		return ret
	else
		return {}
	end
end

function orchestrator.GetInputs(ent)
	if not IsValid(ent) then return {} end

	if ent.MiningAutomationData and ent.MiningAutomationData.Inputs then
		local ret = {}
		for _, input_data in pairs(ent.MiningAutomationData.Inputs) do
			input_data.Ent = ent
			table.insert(ret, input_data)
		end

		return ret
	else
		return {}
	end
end

function orchestrator.GetInputData(ent, id)
	if ent.MiningAutomationData and ent.MiningAutomationData.Inputs and ent.MiningAutomationData.Inputs[id] then
		local input_data = ent.MiningAutomationData.Inputs[id]
		if input_data then
			input_data.Ent = ent
		end

		return input_data
	end
end

function orchestrator.GetOutputData(ent, id)
	if ent.MiningAutomationData and ent.MiningAutomationData.Outputs and ent.MiningAutomationData.Outputs[id] then
		local output_data = ent.MiningAutomationData.Outputs[id]
		if output_data then
			output_data.Ent = ent
		end

		return output_data
	end
end

function orchestrator.EntityTimer(name, ent, delay, occurences, callback)
	if not IsValid(ent) then return end

	local timer_name = ("%s_[%d]"):format(name, ent:EntIndex())
	timer.Create(timer_name, delay, occurences, function()
		if not IsValid(ent) then
			timer.Remove(timer_name)
			return
		end

		local succ = xpcall(callback, _G.ErrorNoHaltWithStack)
		if not succ then
			print(timer_name, "failed!")
		end
	end)
end

function orchestrator.RemoveEntityTimer(name, ent)
	if not IsValid(ent) then return end

	local timer_name = ("%s_[%d]"):format(name, ent:EntIndex())
	timer.Remove(timer_name)
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

			if output_ent.CPPIGetOwner and input_ent.CPPIGetOwner then
				local ret = hook.Run("CanMiningLink", ply, output_ent, output_id, input_ent, input_id)
				if ret == false then return end -- if we got false, then just deny it

				-- if we got true, force through
				if ret ~= true then
					-- disallow on two props of different owners
					if output_ent:CPPIGetOwner() ~= input_ent:CPPIGetOwner() then return end

					-- otherwise if we got nil, apply default behavior
					if not (_G.prop_owner and isfunction(_G.prop_owner.CanMiningLink)) then
						if not ret and output_ent:CPPIGetOwner() ~= ply then return end
						if not ret and input_ent:CPPIGetOwner() ~= ply then return end
					end
				end
			end

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

			if interface_ent.CPPIGetOwner then
				local ret = hook.Run("CanMiningUnlink", ply, interface_ent, interface_id, is_output)
				if ret == false then return end -- if we got false, then just deny it

				-- if we got true, force through
				if ret ~= true then
					-- otherwise if we got nil, apply default behavior
					if not (_G.prop_owner and isfunction(_G.prop_owner.CanMiningUnlink)) then
						if not ret and interface_ent:CPPIGetOwner() ~= ply then return end
					end
				end
			end

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

		local owner = input_data.Ent.CPPIGetOwner and input_data.Ent:CPPIGetOwner()
		local rope_mat = "cable/cable2"
		if IsValid(owner) then
			local ply_mat_name = owner:GetInfo("mining_automation_wiring_mat")
			if not ply_mat_name or ply_mat_name:Trim() == "" then
				rope_mat = nil
			elseif not Material(ply_mat_name):IsError() then
				rope_mat = ply_mat_name
			end
		end

		local cable
		if rope_mat then
			cable = constraint.CreateKeyframeRope(input_data.Ent:WorldSpaceCenter(), 1, rope_mat, input_data.Ent, input_data.Ent, VECTOR_ZERO, 0, output_data.Ent, VECTOR_ZERO, 0, {})
			cable:SetKeyValue("Slack", "100") -- this gives the rope a more dangling aspect
		end

		output_data.Links[input_data.Ent] = output_data.Links[input_data.Ent] or {}
		output_data.Links[input_data.Ent][input_data.Id] = true
		input_data.Link = { Ent = output_data.Ent, Id = output_data.Id, Cable = cable }

		call_entity_fn(input_data.Ent, "OnLink", output_data, input_data)
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
		if not IsValid(ply) then return end

		local data = {}
		for ent, _ in pairs(orchestrator.WatchedEntities) do
			if not IsValid(ent) then
				orchestrator.WatchedEntities[ent] = nil
				continue
			end

			local inputs = orchestrator.GetInputs(ent)
			for _, input_data in ipairs(inputs) do
				if not orchestrator.IsInputLinked(input_data) then continue end

				local link_data = {
					InputEntIndex = ent:EntIndex(),
					InputId = input_data.Id,
					OutputEntIndex = input_data.Link.Ent:EntIndex(),
					OutputId = input_data.Link.Id,
				}

				table.insert(data, link_data)
			end
		end

		net.Start(NET_MSG_NAME)
			net.WriteInt(NET_TYPE_FULL_SYNC, 8)
			net.WriteTable(data)
		net.Send(ply)
	end

	function orchestrator.SendPartialLinkData(ply, is_unlink, output_data, input_data)
		net.Start(NET_MSG_NAME)
			net.WriteInt(NET_TYPE_PARTIAL_SYNC, 8)
			net.WriteBool(is_unlink)

			net.WriteInt(output_data.Ent:EntIndex(), 32)
			net.WriteString(output_data.Id)

			net.WriteInt(input_data.Ent:EntIndex(), 32)
			net.WriteString(input_data.Id)
		net.Broadcast()
	end

	hook.Add("EntityRemoved", "ma_orchestrator", function(ent)
		if not orchestrator.WatchedEntities[ent] then return end

		for _, output_data in ipairs(orchestrator.GetOutputs(ent)) do
			orchestrator.UnlinkOutput(output_data)
		end

		for _, input_data in ipairs(orchestrator.GetInputs(ent)) do
			orchestrator.UnlinkInput(input_data)
		end

		orchestrator.WatchedEntities[ent] = nil
	end)

	hook.Add("OnEntityCreated", "ma_orchestrator", function(ent)
		if not orchestrator.WatchedClassNames[ent:GetClass()] then return end

		orchestrator.WatchedEntities[ent] = true
	end)

	hook.Add("PlayerFullyConnected", "ma_orchestrator", orchestrator.SendLinkData)
end

if CLIENT then
	CreateConVar("mining_automation_wiring_mat", "cable/cable2", { FCVAR_ARCHIVE, FCVAR_USERINFO})

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
				if not orchestrator.LinkData[input_ent_index] then
					orchestrator.LinkData[input_ent_index] = {}
				end

				orchestrator.LinkData[input_ent_index][input_id] = {
					EntIndex = output_ent_index,
					Id = output_id,
				}
			end
		elseif msg_type == NET_TYPE_FULL_SYNC then
			local data = net.ReadTable()

			orchestrator.LinkData = {}
			for _, link_data in pairs(data) do
				if not orchestrator.LinkData[link_data.InputEntIndex] then
					orchestrator.LinkData[link_data.InputEntIndex] = {}
				end

				orchestrator.LinkData[link_data.InputEntIndex][link_data.InputId] = {
					EntIndex = link_data.OutputEntIndex,
					Id = link_data.OutputId,
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
		font = "Sevastopol Interface",
		extended = false,
		size = 25,
		weight = 600,
	})

	surface.CreateFont("ma_hud_text", {
		font = "Sevastopol Interface",
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
	local hide_weapon_selection = false
	hook.Add("HUDPaint", "ma_orchestrator", function()
		looked_at[1] = nil
		hide_weapon_selection = false

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
		hide_weapon_selection = true

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

		surface.SetDrawColor(0, 0, 0, 220)
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

			if i == tool.CurrentIndex then
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

	local HUD_ELEMENT_NAME = "CHudWeaponSelection"
	hook.Add("HUDShouldDraw", "ma_orchestrator", function(name)
		if hide_weapon_selection and name == HUD_ELEMENT_NAME then
			return false
		end
	end)
end