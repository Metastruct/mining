ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.ClassName = "mining_rock"

ENT.Spawnable = false
ENT.PhysgunDisabled = true
ENT.m_tblToolsAllowed = {}
function ENT:CanConstruct() return false end
function ENT:CanTool() return false end

ENT.OffsetPos = vector_origin
ENT.Models = {
	Large = {
		{
			Mdl = "models/props_wasteland/rockgranite02a.mdl",
			Offset = vector_origin
		},
		{
			Mdl = "models/props_wasteland/rockgranite02c.mdl",
			Offset = vector_origin
		}
	},
	Medium = {
		{
			Mdl = "models/props_wasteland/rockgranite03a.mdl",
			Offset = Vector(0, 0, 3)
		},
		{
			Mdl = "models/props_wasteland/rockgranite03b.mdl",
			Offset = Vector(0, 0, 2)
		},
		{
			Mdl = "models/props_debris/concrete_chunk07a.mdl",
			Offset = Vector(0, -1, 1)
		},
		{
			Mdl = "models/props_debris/concrete_spawnchunk001f.mdl",
			Offset = Vector(-23, 12, 0)
		}
	},
	Small = {
		{
			Mdl = "models/props_junk/rock001a.mdl",
			Offset = vector_origin
		},
		{
			Mdl = "models/props_debris/concrete_chunk03a.mdl",
			Offset = vector_origin
		},
		{
			Mdl = "models/props_debris/concrete_spawnchunk001i.mdl",
			Offset = Vector(6, 20, -3)
		},
		{
			Mdl = "models/props_debris/concrete_spawnchunk001j.mdl",
			Offset = Vector(19, 35, 0)
		},
		{
			Mdl = "models/props_debris/concrete_spawnchunk001k.mdl",
			Offset = Vector(28, 12, -2)
		}
	}
}

function ENT:SetupDataTables()
	self:NetworkVar("Int",0,"HealthEx")
	self:NetworkVar("Int",1,"MaxHealthEx")
	self:NetworkVar("Int",2,"Size")
	self:NetworkVar("Int",3,"Rarity")
	self:NetworkVar("Int",4,"BonusSpotCount")
	self:NetworkVar("Int",5,"BonusSpotSeed")
	self:NetworkVar("Int",6,"BonusSpotHit")
	self:NetworkVar("Vector",0,"OffsetPos")
end

function ENT:GetRotatedOffset()
	local offset = self:GetOffsetPos()
	offset:Rotate(self:GetAngles())

	return offset
end

function ENT:GetCorrectedPos()
	return self:GetPos() - self:GetRotatedOffset()
end

function ENT:GetSizeName(size)
	return size > 1 and "Large" or (size == 1 and "Medium" or "Small")
end

duplicator.RegisterEntityClass(ENT.ClassName,function() return end,"Model","Pos","Ang","Data")