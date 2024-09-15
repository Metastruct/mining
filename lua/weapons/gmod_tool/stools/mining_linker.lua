TOOL.Mode = "mining_linker"
TOOL.Name = "Mining Linker"
TOOL.Category = "Mining"
TOOL.CurrentIndex = 1
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.Information = {
	{
		name = "left",
		icon = "gui/lmb.png",
	},
	{
		name = "right",
		icon = "gui/rmb.png",
	},
	{
		name = "reload",
		icon = "gui/r.png",
	},
}

function TOOL:LeftClick()
	return true
end

function TOOL:RightClick()
	return false
end

function TOOL:Reload()
	return true
end

if CLIENT then
	language.Add("tool.mining_linker.name", "Mining Linker")
	language.Add("tool.mining_linker.desc", "Link mining entities together")
	language.Add("tool.mining_linker.0", "Primary: Select an output or apply a link. Secondary: Change selection. Reload: Unlink an output or release current selection.")
	language.Add("tool.mining_linker.left", "Select an output or apply a link.")
	language.Add("tool.mining_linker.right", "Change selection.")
	language.Add("tool.mining_linker.reload", "Unlink an output or release current selection.")
	language.Add("tool.mining_linker.material", "Link material.")

	function TOOL:LeftClick(tr)
		if not IsFirstTimePredicted() then return end
		if not IsValid(tr.Entity) then return false end

		local ent = tr.Entity
		local interfaces = self.SelectedOutput and _G.MA_Orchestrator.GetInputs(ent) or _G.MA_Orchestrator.GetOutputs(ent)
		local interface_count = table.Count(interfaces)
		if interface_count == 0 then return false end

		table.sort(interfaces, function(a, b) return a.Name < b.Name end) -- match hud

		local interface_data = interfaces[self.CurrentIndex]
		if not interface_data then return false end

		if not self.SelectedOutput then
			self.SelectedOutput = interface_data
			surface.PlaySound("ui/buttonclick.wav")
		else
			if self.SelectedOutput.Type ~= interface_data.Type then
				surface.PlaySound("buttons/button8.wav")
				return false
			end

			_G.MA_Orchestrator.Link(self.SelectedOutput, interface_data)
			self.SelectedOutput = nil

			surface.PlaySound("buttons/button4.wav")
		end

		return true
	end

	function TOOL:RightClick(tr)
		if not IsFirstTimePredicted() then return end
		if not IsValid(tr.Entity) then return false end

		local ent = tr.Entity
		local interfaces = self.SelectedOutput and _G.MA_Orchestrator.GetInputs(ent) or _G.MA_Orchestrator.GetOutputs(ent)
		local interface_count = table.Count(interfaces)
		if interface_count == 0 then return false end

		self.CurrentIndex = input.IsShiftDown() and (self.CurrentIndex - 1) or (self.CurrentIndex + 1)
		self.LastEntity = ent

		if self.CurrentIndex > #interfaces then
			self.CurrentIndex = 1
		elseif self.CurrentIndex < 1 then
			self.CurrentIndex = #interfaces
		end

		surface.PlaySound("ui/buttonrollover.wav")

		return false
	end

	local function try_get_linker()
		local ply = LocalPlayer()
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) then return end
		if wep:GetClass() ~= "gmod_tool" then return end

		local tool = wep:GetToolObject()
		if not tool then return end
		if tool.Mode ~= "mining_linker" then return end

		return tool
	end

	hook.Add("PlayerButtonDown", "mining_linker", function(ply, btn)
		if not IsFirstTimePredicted() then return end
		if ply ~= LocalPlayer() then return end
		if btn ~= MOUSE_WHEEL_DOWN and btn ~= MOUSE_WHEEL_UP then return end

		local linker = try_get_linker()
		if not linker then return end

		local tr = ply:GetEyeTrace()
		if not IsValid(tr.Entity) then return end

		local interfaces = linker.SelectedOutput and _G.MA_Orchestrator.GetInputs(tr.Entity) or _G.MA_Orchestrator.GetOutputs(tr.Entity)
		local interface_count = table.Count(interfaces)
		if interface_count == 0 then return false end

		linker.CurrentIndex = btn == MOUSE_WHEEL_UP and (linker.CurrentIndex - 1) or (linker.CurrentIndex + 1)
		linker.LastEntity = tr.Entity

		if linker.CurrentIndex > #interfaces then
			linker.CurrentIndex = 1
		elseif linker.CurrentIndex < 1 then
			linker.CurrentIndex = #interfaces
		end

		surface.PlaySound("ui/buttonrollover.wav")
	end)

	function TOOL:Reload(tr)
		if not IsFirstTimePredicted() then return end

		if self.SelectedOutput then
			self.SelectedOutput = nil
			surface.PlaySound("ui/buttonclickrelease.wav")
			return false
		end

		if not IsValid(tr.Entity) then return false end

		local ent = tr.Entity
		local outputs = _G.MA_Orchestrator.GetOutputs(ent)
		local outputs_count = table.Count(outputs)
		if outputs_count == 0 then return false end

		table.sort(outputs, function(a, b) return a.Name < b.Name end)

		local output_data = outputs[self.CurrentIndex]
		if not output_data then return false end

		_G.MA_Orchestrator.Unlink(true, output_data)
		surface.PlaySound("ui/buttonclickrelease.wav")

		return true
	end

	function TOOL:GetSelectedOutput()
		return self.SelectedOutput
	end

	function TOOL:Think()
		local owner = self:GetOwner()
		if not IsValid(owner) then return end

		local tr = owner:GetEyeTrace()
		if (IsValid(tr.Entity) and tr.Entity ~= self.LastEntity) or not IsValid(tr.Entity) then
			self.CurrentIndex = 1
			self.LastEntity = tr.Entity
		end
	end

	function TOOL.BuildCPanel( CPanel )
		CPanel:AddControl( "Header", { Description = "#tool.mining_linker.desc" } )
		CPanel:AddControl( "RopeMaterial", { Label = "#tool.mining_linker.material", ConVar = "mining_automation_wiring_mat" } )
	end
end