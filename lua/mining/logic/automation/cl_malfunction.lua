module("ms", package.seeall)
Ores = Ores or {}

local ARC_MAT = CreateMaterial("ma_malfunction_arc", "UnlitGeneric", {
	["$basetexture"] = "sprites/lgtning",
	["$additive"] = 1,
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
})
local GLOW_MAT = Material("sprites/light_glow02_add")
local ARC_COLOR = Color(140, 210, 255)
local GLOW_COLOR = Color(180, 230, 255)

local FX_DISTANCE = 3000
local ARC_SEGMENTS = 8
local MAX_ARCS = 64

local CRACKLE_SOUNDS = {
	"ambient/energy/spark1.wav",
	"ambient/energy/spark2.wav",
	"ambient/energy/spark3.wav",
	"ambient/energy/spark4.wav",
	"ambient/energy/spark5.wav",
	"ambient/energy/spark6.wav",
}

local malfunction_fx_ents = {}
timer.Create("MA_MalfunctionTrack", 1, 0, function()
	malfunction_fx_ents = {}

	local eye_pos = EyePos()
	for class in pairs(Ores.Automation.EntityClasses) do
		for _, ent in ipairs(ents.FindByClass(class)) do
			if not ent:GetNWBool("IsMalfunctioning", false) then continue end
			if eye_pos:DistToSqr(ent:WorldSpaceCenter()) > FX_DISTANCE * FX_DISTANCE then continue end

			malfunction_fx_ents[#malfunction_fx_ents + 1] = ent
		end
	end
end)

-- random point on the shell of the entity's OBB, so arcs hug the model
-- instead of spawning inside it
local function random_surface_point(ent)
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local p = Vector(
		math.Rand(mins.x, maxs.x),
		math.Rand(mins.y, maxs.y),
		math.Rand(mins.z, maxs.z)
	)

	local axis = math.random(3)
	local snap_max = math.random(2) == 1
	if axis == 1 then
		p.x = snap_max and maxs.x or mins.x
	elseif axis == 2 then
		p.y = snap_max and maxs.y or mins.y
	else
		p.z = snap_max and maxs.z or mins.z
	end

	return ent:LocalToWorld(p)
end

local active_arcs = {}
local function spawn_arc(ent)
	if #active_arcs >= MAX_ARCS then return end

	local from = random_surface_point(ent)
	local to = random_surface_point(ent)
	local jitter = from:Distance(to) * 0.12

	local points = { from }
	for i = 1, ARC_SEGMENTS - 1 do
		local p = LerpVector(i / ARC_SEGMENTS, from, to)
		points[#points + 1] = p + VectorRand() * jitter
	end
	points[#points + 1] = to

	local life = math.Rand(0.15, 0.35)
	active_arcs[#active_arcs + 1] = {
		points = points,
		width = math.Rand(3, 7),
		die_time = CurTime() + life,
		life = life,
	}
end

local next_fx = {}
hook.Add("Think", "MA_MalfunctionFX", function()
	local now = CurTime()
	for _, ent in ipairs(malfunction_fx_ents) do
		if not IsValid(ent) then continue end

		local next_time = next_fx[ent]
		if next_time and now < next_time then continue end

		for _ = 1, math.random(2, 4) do
			spawn_arc(ent)
		end

		if math.random() < 0.5 then
			local fx = EffectData()
			fx:SetOrigin(random_surface_point(ent))
			fx:SetMagnitude(2)
			fx:SetScale(1)
			fx:SetRadius(3)
			util.Effect("Sparks", fx)
		end

		if math.random() < 0.35 then
			ent:EmitSound(CRACKLE_SOUNDS[math.random(#CRACKLE_SOUNDS)], 65, math.random(90, 120))
		end

		next_fx[ent] = now + math.Rand(0.05, 0.25)
	end

	for ent in pairs(next_fx) do
		if not IsValid(ent) then
			next_fx[ent] = nil
		end
	end
end)

hook.Add("PostDrawTranslucentRenderables", "MA_MalfunctionFX", function(depth, skybox)
	if depth or skybox then return end
	if #active_arcs == 0 then return end

	local now = CurTime()
	for i = #active_arcs, 1, -1 do
		local arc = active_arcs[i]
		if now >= arc.die_time then
			table.remove(active_arcs, i)
			continue
		end

		local alpha = 255 * ((arc.die_time - now) / arc.life)
		local color = Color(ARC_COLOR.r, ARC_COLOR.g, ARC_COLOR.b, alpha)
		local halo_color = Color(ARC_COLOR.r, ARC_COLOR.g, ARC_COLOR.b, alpha * 0.4)

		render.SetMaterial(ARC_MAT)
		-- wide faint halo pass behind the core to make arcs pop in bright scenes
		render.StartBeam(#arc.points)
		for j, point in ipairs(arc.points) do
			render.AddBeam(point, arc.width * 2.5, j * 0.5, halo_color)
		end
		render.EndBeam()

		render.StartBeam(#arc.points)
		for j, point in ipairs(arc.points) do
			render.AddBeam(point, arc.width, j * 0.5, color)
		end
		render.EndBeam()

		render.SetMaterial(GLOW_MAT)
		local glow_size = arc.width * 3
		render.DrawSprite(arc.points[1], glow_size, glow_size, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, alpha))
		render.DrawSprite(arc.points[#arc.points], glow_size, glow_size, Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, alpha))
	end
end)
