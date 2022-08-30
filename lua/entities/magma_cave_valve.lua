AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Author = "Earu"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.ms_notouch = true
ENT.PrintName = "Valve"
ENT.ClassName = "magma_cave_valve"
ENT.ms_notouch = true
ENT.ms_nogoto = "no cheating!"
ENT.PhysgunDisabled = true

if SERVER then
	local function freeze_ent(ent)
		ent.ms_notouch = true
		ent.ms_nogoto = "no cheating!"
		ent.PhysgunDisabled = true

		local phys = ent:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
			phys:EnableMotion(false)
		end
	end

	function ENT:Initialize()
		self:SetModel("models/props_pipes/pipeset32d_128_001a.mdl")
		self:SetModelScale(4, 0.0001)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetSolid(SOLID_VPHYSICS)
		self:Activate()

		self:SetAngles(Angle(90, 0, 0))

		freeze_ent(self)

		local board = ents.Create("prop_physics")
		board:SetModel("models/props_canal/winch02.mdl")
		board:SetPos(self:GetPos() + self:GetUp() * 10 + self:GetForward() * 75 + self:GetRight() * -40)
		board:SetAngles(Angle(90, 90, 0))
		board:SetParent(self)
		board:Spawn()

		freeze_ent(board)

		local valve = ents.Create("prop_physics")
		valve:SetModel("models/props_pipes/valvewheel001.mdl")
		valve:SetModelScale(2)
		valve:SetPos(board:GetPos() + board:GetUp() * 15 + board:GetRight() * 17 + board:GetForward() * -15)
		valve:SetAngles(Angle(90, 90, 0))
		valve:SetParent(board)
		valve:Spawn()
		valve:Activate()
		valve:SetUseType(SIMPLE_USE)
		valve.VolcanoValve = true

		freeze_ent(valve)
	end
end
