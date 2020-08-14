ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.ClassName = "mining_ore"

ENT.Spawnable = false
ENT.PhysgunDisabled = true
ENT.m_tblToolsAllowed = {}
function ENT:CanConstruct() return false end
function ENT:CanTool() return false end

function ENT:SetupDataTables()
	self:NetworkVar("Int",0,"Rarity")
end

duplicator.RegisterEntityClass(ENT.ClassName,function() return end,"Model","Pos","Ang","Data")