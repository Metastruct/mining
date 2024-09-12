--local TOOL = {}
--_G.MA_Orchestrator.TOOL = TOOL

TOOL.Mode = "mining_linker"
TOOL.Name = "Mining Linker"
TOOL.Category = "Mining"
TOOL.CurrentIndex = 0
TOOL.Command		= nil
TOOL.ConfigName		= ""

function TOOL:LeftClick(tr)
	if not CLIENT then return false end
	if not IsValid(tr.Entity) then return false end

	local ent = tr.Entity
	if ent.CPPIGetOwner and ent:CPPIGetOwner() ~= LocalPlayer() then
		surface.PlaySound("buttons/button8.wav")
		return false
	end

	local interfaces = self.SelectedOutput and _G.MA_Orchestrator.GetInputs(ent) or _G.MA_Orchestrator.GetOutputs(ent)
	local interface_count = table.Count(interfaces)
	if interface_count == 0 then return false end

	local cur_index = (self.CurrentIndex % table.Count(interfaces)) + 1
	local interface_data = interfaces[cur_index]
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
	if not CLIENT then return false end
	if not IsValid(tr.Entity) then return false end

	local ent = tr.Entity
	if ent.CPPIGetOwner and ent:CPPIGetOwner() ~= LocalPlayer() then
		surface.PlaySound("buttons/button8.wav")
		return false
	end

	local interfaces = self.SelectedOutput and _G.MA_Orchestrator.GetInputs(ent) or _G.MA_Orchestrator.GetOutputs(ent)
	local interface_count = table.Count(interfaces)
	if interface_count == 0 then return false end

	self.CurrentIndex = self.CurrentIndex + 1
	surface.PlaySound("ui/buttonrollover.wav")

	return true
end

function TOOL:Reload(tr)
	if not CLIENT then return false end

	if self.SelectedOutput then
		self.SelectedOutput = nil
		surface.PlaySound("ui/buttonclickrelease.wav")
		return false
	end

	if not IsValid(tr.Entity) then return false end

	local ent = tr.Entity
	if ent.CPPIGetOwner and ent:CPPIGetOwner() ~= LocalPlayer() then
		surface.PlaySound("buttons/button8.wav")
		return false
	end

	local outputs = _G.MA_Orchestrator.GetOutputs(ent)
	local outputs_count = table.Count(outputs)
	if outputs_count == 0 then return false end

	local cur_index = (self.CurrentIndex % table.Count(outputs)) + 1

	local output_data = outputs[cur_index]
	if not output_data then return false end

	_G.MA_Orchestrator.Unlink(true, output_data)
	surface.PlaySound("ui/buttonclickrelease.wav")

	return true
end

if CLIENT then
	function TOOL:GetSelectedOutput()
		return self.SelectedOutput
	end
end

--[[hook.Add("PlayerBindPress", "ma_tool_debugger", function(ply, bind, pressed)
	if not pressed then return end
	if ply ~= LocalPlayer() then return end

	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) then return end
	if wep:GetClass() ~= "none" then return end

	local tr = ply:GetEyeTrace()
	if bind == "+attack" then
		TOOL:LeftClick(tr)
	elseif bind == "+attack2" then
		TOOL:RightClick(tr)
	elseif bind == "+reload" then
		TOOL:Reload(tr)
	end
end)]]