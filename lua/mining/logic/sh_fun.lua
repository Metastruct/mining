module("ms",package.seeall)

Ores = Ores or {}

if SERVER then
	resource.AddSingleFile("sound/mining/cave.mp3")
	return
end

local tag = "ms.Ores_Fun"
local col,maxDist = Vector(0,1,0.9),129600 --360hu

local me

local function getBehindPlayer()
	local backDir = -EyeVector()
	backDir.z = 0

	local pos = EyePos()
	local tr = util.TraceLine({
		start = pos,
		endpos = pos+(backDir*128),
		filter = me,
		mask = MASK_SOLID
	})

	pos = tr.Hit and tr.HitPos-(backDir*18) or tr.HitPos
	tr = util.TraceLine({
		start = pos,
		endpos = pos-(vector_up*128),
		mask = MASK_SOLID
	})

	return tr.HitPos,(-backDir):Angle()
end

local function spawnHim(pos,ang)
	local eyePos = EyePos()

	if pos:DistToSqr(eyePos) < 144 then return end --Too close at 12hu, cancel
	if IsValid(Ores._him) and not Ores._him._t then
		Ores._him:Remove()
	end

	local g = ClientsideModel("models/player/police.mdl",RENDERMODE_TRANSCOLOR)
	g:SetPos(pos)
	g:SetAngles(ang)
	g:ResetSequence(g:LookupSequence("idle_all_01"))

	g.GetPlayerColor = function() return col end
	g._delta = RealTime()

	local checkTimerId = tag.."_HimCheck"
	timer.Create(checkTimerId,1,0,function()
		if not IsValid(g) then
			timer.Remove(checkTimerId)
			return
		end

		if g._delta < RealTime()-5 then
			local gPos = g:GetPos()+Vector(0,0,38)
			local dist = gPos:DistToSqr(EyePos())

			if dist > maxDist then
				local newPos,newAng = getBehindPlayer()

				g:SetPos(newPos)
				g:SetAngles(newAng)
			end
		end
	end)

	g.RenderOverride = function(self)
		local time = RealTime()
		local ePos = EyePos()

		if self._delta < time then
			local ang = ((ePos+(me:GetVelocity()*0.5))-self:GetPos()):Angle()
			ang.p = 0

			self:SetAngles(ang)
		end
		self._delta = time+0.25

		if not self._t then
			local gPos = self:GetPos()+Vector(0,0,38)
			local dist = gPos:DistToSqr(ePos)

			if dist > maxDist then
				local newPos,newAng = getBehindPlayer()

				self:SetPos(newPos)
				self:SetAngles(newAng)
				return
			end

			local dot = EyeVector():Dot((gPos-ePos):GetNormalized())

			local activate = dot > 0.5

			if not activate and me:GetVelocity():LengthSqr() > 1048576 then --1024hu, moving too fast
				activate = true
			end

			if not activate then
				local tr = util.TraceLine({
					start = ePos,
					endpos = gPos,
					filter = player.GetAll(),
					mask = MASK_SOLID
				})

				activate = not tr.Hit
			end

			if activate then
				self._t = time

				EmitSound("mining/cave.mp3",gPos,-1,CHAN_AUTO,0.4,75,0,100)
			end
		end

		local blend = self._t and 0.8-((time-self._t)*0.6) or 0.8

		if blend > 0 then
			render.SetBlend(blend)
			self:DrawModel()
			render.SetBlend(1)
		else
			if IsValid(Ores._him) then
				Ores._him:Remove()
			end
		end
	end

	g:CallOnRemove("cleanup",function()
		Ores._him = nil
		timer.Remove(checkTimerId)
	end)

	Ores._him = g

	if GetConVar("developer"):GetBool() then
		print("He's here.")
	end
end

local timerId = tag.."_Him"
hook.Add("PlayerEnteredZone",tag,function(pl,zone)
	if zone != "cave" then return end

	timer.Create(timerId,30,0,function()
		if math.random() <= 0.01 or Ores._himm then
			me = me or LocalPlayer()
			spawnHim(getBehindPlayer())

			Ores._himm = nil
		end
	end)
end)
hook.Add("PlayerExitedZone",tag,function(pl,zone)
	if zone != "cave" then return end

	timer.Remove(timerId)
	if IsValid(Ores._him) then
		Ores._him:Remove()
	end
end)