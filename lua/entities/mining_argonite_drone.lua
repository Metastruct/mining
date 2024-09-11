AddCSLuaFile()

module("ms", package.seeall)
Ores = Ores or {}

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Argonite Drone"
ENT.Author = "Earu"
ENT.Category = "Mining"
ENT.RenderGroup = RENDERGROUP_OPAQUE
ENT.Spawnable = false
ENT.ClassName = "mining_argonite_drone"
ENT.LaserDistance = 300 * 300
ENT.Nodes = {
	Vector(5871.525390625, -245.04811096191, -15307.4765625),
	Vector(5695.3134765625, 763.93371582031, -15302.787109375),
	Vector(5685.3090820312, 1952.9719238281, -15309.538085938),
	Vector(6140.3984375, 2447.4885253906, -15296.720703125),
	Vector(6696.1630859375, 2549.5446777344, -15315.948242188),
	Vector(5026.3447265625, 2495.0036621094, -15299.805664062),
	Vector(3348.6557617188, 1879.5523681641, -15310.637695312),
	Vector(3402.2387695312, -94.821678161621, -15315.1328125),
	Vector(4747.6547851562, -589.49505615234, -15316.27734375),
	Vector(5262.8051757812, -572.69165039062, -15287.276367188)
}

function ENT:TraceToGround()
	local pos = self:WorldSpaceCenter()
	return util.TraceLine({
		start = pos,
		endpos = pos + Vector(0, 0, -2e6),
		mask = MASK_SOLID_BRUSHONLY,
	})
end

function ENT:HasTarget() return IsValid(self:GetNWEntity("Target")) end
function ENT:GetTarget() return self:GetNWEntity("Target") end

local RED_COLOR = Color(255, 0, 0)
if SERVER then
	function ENT:Initialize()
		self:SetSolid(SOLID_VPHYSICS)
		self:SetModel("models/maxofs2d/hover_rings.mdl")
		self:SetNotSolid(true)

		self:PhysicsInit(SOLID_VPHYSICS)
		self:PhysWake()

		self:StartMotionController()
		self.ShadowParams = {}
		self.NextTargetCheck = 0

		util.SpriteTrail(self, 0, RED_COLOR, false, 15, 1, 1, 1 / (15 + 1) * 0.5, "trails/laser")
	end

	local function distance(a, b)
		return (a - b):Length()  -- Euclidean distance between 3D vectors
	end

	local function a_star_pathfinding(startPos, endPos, nodes)
		-- Set up the open and closed lists
		local openList = {}
		local closedList = {}

		-- Add the start position to the open list
		table.insert(openList, {
			pos = startPos,
			g = 0,
			h = distance(startPos, endPos),
			f = 0,
			parent = nil
		})

		while #openList > 0 do
			-- Sort openList based on 'f' value (g + h)
			table.sort(openList, function(a, b) return a.f < b.f end)
			-- Take the node with the lowest 'f' value (best candidate for the path)
			local currentNode = table.remove(openList, 1)

			-- If the current node is the end node, build the path by tracing back through the parents
			-- Tolerance for reaching the end point (adjust as necessary)
			if distance(currentNode.pos, endPos) < 600 then
				local path = {}

				while currentNode do
					table.insert(path, 1, currentNode.pos) -- Insert at the start to reverse the path
					currentNode = currentNode.parent
				end
				-- Return the built path

				table.insert(path, endPos)
				return path
			end

			-- Add current node to the closed list
			table.insert(closedList, currentNode)

			-- Loop through all nodes (neighbors)
			for _, neighborPos in ipairs(nodes) do
				-- Skip if the neighbor is already in the closed list
				local inClosedList = false

				for _, closedNode in ipairs(closedList) do
					if closedNode.pos == neighborPos then
						inClosedList = true
						break
					end
				end

				if inClosedList then
					goto skip
				end

				-- Calculate g, h, and f values for the neighbor
				local g = currentNode.g + distance(currentNode.pos, neighborPos)
				local h = distance(neighborPos, endPos)
				local f = g + h

				-- Check if the neighbor is already in the open list with a lower f value
				local inOpenList = false
				for _, openNode in ipairs(openList) do
					if openNode.pos == neighborPos and openNode.f <= f then
						inOpenList = true
						break
					end
				end

				-- If the neighbor is not in the open list or has a better f value, add/update it
				if not inOpenList then
					table.insert(openList, {
						pos = neighborPos,
						g = g,
						h = h,
						f = f,
						parent = currentNode
					})
				end

				::skip::
			end
		end
		-- If no path is found, return an empty table

		return {}
	end

	function ENT:SetTarget(target)
		if self:HasTarget() then
			local old_target = self:GetNWEntity("Target")
			if IsValid(old_target) then
				old_target.ArgoniteDrone = nil
				self:SetNWEntity("Target", nil)
			end
		end

		if not IsValid(target) then return end

		target.ArgoniteDrone = self
		self:SetNWEntity("Target", target)

		self.Path = a_star_pathfinding(self:WorldSpaceCenter(), target:WorldSpaceCenter(), self.Nodes)
		self.PathIndex = 1
	end

	function ENT:SetRarity(rarity)
		self.RarityOverride = rarity
	end

	function ENT:GetClosestRock()
		local target = NULL
		local mindist = 2e6
		local argonite_rarity = self.RarityOverride or ms.Ores.Automation.GetOreRarityByName("copper")
		for _, ent in ipairs(ents.FindByClass("mining_rock")) do
			if ent:GetRarity() ~= argonite_rarity then continue end
			if IsValid(ent.ArgoniteDrone) then continue end

			local dist = ent:WorldSpaceCenter():Distance(self:WorldSpaceCenter())
			if dist < mindist then
				mindist = dist
				target = ent
			end
		end

		return target
	end

	function ENT:MoveOn(exception)
		local rocks = {}
		local argonite_rarity = self.RarityOverride or ms.Ores.Automation.GetOreRarityByName("copper")
		for _, ent in ipairs(ents.FindByClass("mining_rock")) do
			if ent:GetRarity() ~= argonite_rarity then continue end
			if IsValid(ent.ArgoniteDrone) then continue end
			if ent == exception then continue end

			table.insert(rocks, ent)
		end

		if #rocks < 1 then return end

		local new_rock = rocks[math.random(#rocks)]
		self:SetTarget(new_rock)
	end

	function ENT:PhysicsSimulate(phys,delta)
		phys:Wake()

		local pos = Vector(0, 0, 0)
		if self:HasTarget() and #self.Path > 0 then
			pos = self.Path[self.PathIndex] + Vector(0, 0, 50)

			if pos:Distance(self:GetPos()) < 100 then
				self.PathIndex = math.min(#self.Path, self.PathIndex + 1)
			end
		else
			local tr = self:TraceToGround()
			pos = tr.HitPos + Vector(0, 0, 50)

			if self.NextTargetCheck < CurTime() then
				self:SetTarget(self:GetClosestRock())
				self.NextTargetCheck = CurTime() + 1
			end
		end

		self.ShadowParams.secondstoarrive = 1
		self.ShadowParams.pos = pos
		self.ShadowParams.angle = Angle(0, 0, 0)
		self.ShadowParams.maxangular = 5000
		self.ShadowParams.maxangulardamp = 10000
		self.ShadowParams.maxspeed = 1000000
		self.ShadowParams.maxspeeddamp = 10000
		self.ShadowParams.dampfactor = 0.8
		self.ShadowParams.teleportdistance = 2000
		self.ShadowParams.deltatime = delta

		phys:ComputeShadowControl(self.ShadowParams)
	end

	local function try_damage_target(self)
		if not self.CPPIGetOwner then return end
		if not self:HasTarget() then return end

		local owner = self:CPPIGetOwner()
		if not IsValid(owner) then return end

		local target = self:GetTarget()
		if not IsValid(target) then return end

		local timer_name = ("mining_argonite_drone_[%d]_target_[%d]"):format(self:EntIndex(), target:EntIndex())
		if not timer.Exists(timer_name) then
			timer.Create(timer_name, 20, 1, function()
				if not IsValid(self) then return end
				if target == self:GetTarget() then
					self:MoveOn(target)
				end
			end)
		end

		if self:WorldSpaceCenter():DistToSqr(target:WorldSpaceCenter()) < self.LaserDistance then
			local dmg = DamageInfo()
			dmg:SetAttacker(owner)
			dmg:SetInflictor(self)
			dmg:SetDamage(20)
			dmg:SetDamageType(DMG_ENERGYBEAM)

			target:TakeDamageInfo(dmg)

			return true
		end
	end

	function ENT:Think()
		local success = try_damage_target(self)
		if success then
			if not self.LaserSound then
				self.LaserSound = CreateSound(self, "ambient/energy/force_field_loop1.wav")
				self.LaserSound:Play()
			elseif not self.LaserSound:IsPlaying() then
				self.LaserSound:Stop()
				self.LaserSound:Play()
			end

			self.LaserSound:ChangePitch(85, 0)
			self.LaserSound:ChangeVolume(0.4)
		else
			if self.LaserSound then
				self.LaserSound:Stop()
			end
		end

		self:NextThink(CurTime() + 1)
		return true
	end

	function ENT:OnRemove()
		if self.LaserSound then
			self.LaserSound:Stop()
		end
	end
end

if CLIENT then
	local BEAM_MAT = Material("trails/physbeam")
	function ENT:Draw()
		self:DrawModel()

		local target = self:GetTarget()
		if IsValid(target) and self:WorldSpaceCenter():DistToSqr(target:WorldSpaceCenter()) < self.LaserDistance then
			render.SetMaterial(BEAM_MAT)
			render.DrawBeam(self:WorldSpaceCenter(), target:WorldSpaceCenter(), 5, 1, 1, RED_COLOR)
		end
	end
end