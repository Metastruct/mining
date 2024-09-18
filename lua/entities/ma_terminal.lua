AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Mining Terminal"
ENT.Author = "Earu"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.ClassName = "ma_terminal"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.CanConstruct = function() return false end
ENT.ms_notouch = true

if SERVER then
	function ENT:Initialize()
		self:SetModel("models/props_lab/monitor01a.mdl")
		self:SetMaterial("phoenix_storms/MetalSet_1-2")
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysWake()
		self:SetUseType(SIMPLE_USE)
	end

	function ENT:Use(ply)
		if not IsValid(ply) then return end
		if not ply:IsPlayer() then return end

		if ply.LookAt then
			ply:LookAt(self)
		end

		ply:EmitSound("buttons/lightswitch2.wav")
		ply:ConCommand("mining_automation_terminal")
	end
end

if CLIENT then
	surface.CreateFont("ma_terminal_world_title", {
		font = "Sevastopol Interface",
		size = 150,
		weight = 800,
		outline = false,
	})

	surface.CreateFont("ma_terminal_world_sub", {
		font = "Sevastopol Interface",
		size = 50,
		weight = 800,
		outline = false,
	})

	local USE_KEY = (input.LookupBinding("+use") or "?"):upper()
	local TERMINAL_MAT = Material("effects/combine_binocoverlay")
	function ENT:WaitScreen(real_width, real_height)
		surface.SetDrawColor(24, 48, 26, 255)
		surface.DrawRect(0, 0, real_width, real_height)

		surface.SetFont("ma_terminal_world_title")
		local text = "MINING TERMINAL"
		local tw, th = surface.GetTextSize(text)

		local pos_x, pos_y = real_width / 2 - tw / 2, real_height / 2 - th / 2 - 200
		surface.SetDrawColor(17, 185, 106, 255)
		surface.DrawRect(pos_x - 5, pos_y - 5, tw + 10, th + 10)

		surface.SetTextColor(23, 47, 25, 255)
		surface.SetTextPos(pos_x, pos_y)
		surface.DrawText(text)

		surface.SetTextColor(255, 255, 255, 255)
		surface.SetFont("ma_terminal_world_sub")
		text = "Powered by Metastruct"
		tw, _ = surface.GetTextSize(text)
		pos_x, pos_y = real_width / 2 - tw / 2, real_height / 2 + th / 2 + 50 - 200
		surface.SetTextPos(pos_x, pos_y)
		surface.DrawText(text)

		text = ("(Press [%s] to continue)"):format(USE_KEY)
		tw, _ = surface.GetTextSize(text)
		pos_x, pos_y = real_width / 2 - tw / 2, real_height - 300
		surface.SetTextPos(pos_x, pos_y)
		surface.DrawText(text)

		surface.SetMaterial(TERMINAL_MAT)
		surface.SetDrawColor(0, 255, 0, 1)
		surface.DrawTexturedRect(-50, -50, real_width + 100, real_height + 100)
	end

	function ENT:Draw()
		self:DrawModel()

		local maxs = self:OBBMaxs()
		local scale = (maxs.x * 2) / 1440
		local w, h = 1440, 1440
		local ang = self:GetAngles()

		ang:RotateAroundAxis(self:GetForward(), 180)
		ang:RotateAroundAxis(self:GetRight(), 90)
		ang:RotateAroundAxis(self:GetForward(), -90)
		ang:RotateAroundAxis(self:GetRight(), 4.5)

		cam.Start3D2D(self:GetPos() + self:GetRight() * 9.4 + self:GetForward() * 11.72 + self:GetUp() * 12, ang, scale / 1.5)
			self:WaitScreen(w, h)
		cam.End3D2D()
	end
end