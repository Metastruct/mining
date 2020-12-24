ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.ClassName = "mining_xen_crystal"

ENT.Spawnable = false
ENT.PhysgunDisabled = true
ENT.m_tblToolsAllowed = {}
function ENT:CanConstruct() return false end
function ENT:CanTool() return false end

function ENT:SetupDataTables()
	self:NetworkVar("Bool",0,"Unlodged")
	self:NetworkVar("Bool",1,"Departing")

	if CLIENT then
		self:NetworkVarNotify("Departing",function(ent,var,old,new)
			if new != true then return end

			ent:CreateBeamPoints(ent:GetPos(),true)
			ent.FadeTime = RealTime()+0.6

			if ent.AmbientSound then
				ent.AmbientSound:Stop()
				ent.AmbientSound = nil
				ent.AmbientSettings = nil
			end
		end)
	end
end

duplicator.RegisterEntityClass(ENT.ClassName,function() return end,"Model","Pos","Ang","Data")