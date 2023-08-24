local Tag = "mining_blood_ore"

ms.Ores.__R[666] = {
	AmbientLevel    = 78,
	AmbientPitch    = 65,
	AmbientSound    = "ambient/levels/citadel/field_loop3.wav",
	AmbientVolume   = 0.3,
	Health          = 10,
	Hidden          = true,
	HudColor        = Color(200, 0, 0),
	Name            = "Blood",
	PhysicalColor   = Color(55, 0, 0),
	SparkleInterval = 0.3,
	Worth           = 0,
	Suffix          = "",
}

if SERVER then
	util.AddNetworkString(Tag)

	hook.Add("EntityTakeDamage", Tag, function(target, dmg)
		if not IsValid(target) then return end

		local atck = dmg:GetAttacker()
		if not IsValid(atck) then return end
		if not atck:IsPlayer() then return end

		local inflictor = dmg:GetInflictor()
		if not IsValid(inflictor) then return end
		if inflictor:GetClass() ~= "mining_pickaxe" then return end


		if not target:IsPlayer() then return end

		if not target.NextBloodOre then
			target.NextBloodOre = 0
		end

		if target:IsPlayer() and (target:GetInfoNum("cl_dmg_mode", 1) == 1 or target:HasGodMode() or (target.IsInZone and not target:IsInZone("cave"))) then
			return
		end

		if target.NextBloodOre < CurTime() then
			local blood = ents.Create("mining_rock")
			blood:SetRarity(666)
			blood:SetSize(math.random(0.1, 0.33))
			blood:SetPos(target:WorldSpaceCenter())
			blood:Spawn()
			blood:SetCollisionGroup(COLLISION_GROUP_WEAPON)
			blood:SetSize(math.random(0.1, 0.33))
			blood:SetMaterial("models/flesh")
			blood:EmitSound(")physics/flesh/flesh_squishy_impact_hard" .. math.random(1, 4) .. ".wav")

			local phys = blood:GetPhysicsObject()
			if IsValid(phys) then
				phys:EnableMotion(true)
				phys:Wake()

				constraint.NoCollide(blood, target)
				timer.Simple(0, function()
					if not IsValid(phys) then return end
					phys:SetVelocity(VectorRand() * 500)
				end)
			end

			SafeRemoveEntityDelayed(blood, 20)
			target.NextBloodOre = CurTime() + 2
		end
	end)

	hook.Add("PlayerReceivedOre", Tag, function(ply, _, rarity)
		if ply.BloodGodDone then return end
		if rarity ~= 666 then return end

		local count = ms.Ores.GetPlayerOre(ply, 666)
		if count >= 66 then
			net.Start(Tag)
			net.Send(ply)

			ply.BloodGodDone = true
		end
	end)
end

if CLIENT then
	local Tag2 = Tag .. FrameNumber()
	local textToDisplay = "B̴̮̉ḻ̷͑o̸̬̓o̷̧͂d̵̙̆.̷̰͑.̷̓ͅ.̴͈̍ ̴͚͘f̴͔͘o̶̤̽r̸̡͘ ̴͉̎t̸͙̿ḧ̴̙́e̶̜͂ ̸̠͛b̶̝̈l̶̼̆o̷͖͊ö̸͇́ď̷̲ ̴͙̉g̶̩̍o̶̫̓d̷̻̋.̵̯̊.̴̩͋.̶̖͆"

	surface.CreateFont("BIGFONT", {
		font = "Tahoma",
		size = "150"
	})

	TEXTUREFLAGS_POINTSAMPLE = 0x00000001
	TEXTUREFLAGS_TRILINEAR = 0x00000002
	TEXTUREFLAGS_CLAMPS = 0x00000004
	TEXTUREFLAGS_CLAMPT = 0x00000008
	TEXTUREFLAGS_ANISOTROPIC = 0x00000010
	TEXTUREFLAGS_HINT_DXT5 = 0x00000020
	TEXTUREFLAGS_NOCOMPRESS = 0x00000040
	TEXTUREFLAGS_NORMAL = 0x00000080
	TEXTUREFLAGS_NOMIP = 0x00000100
	TEXTUREFLAGS_NOLOD = 0x00000200
	TEXTUREFLAGS_MINMIP = 0x00000400
	TEXTUREFLAGS_PROCEDURAL = 0x00000800
	TEXTUREFLAGS_ONEBITALPHA = 0x00001000
	TEXTUREFLAGS_EIGHTBITALPHA = 0x00002000
	TEXTUREFLAGS_ENVMAP = 0x00004000
	TEXTUREFLAGS_RENDERTARGET = 0x00008000
	TEXTUREFLAGS_DEPTHRENDERTARGET = 0x00010000
	TEXTUREFLAGS_NODEBUGOVERRIDE = 0x00020000
	TEXTUREFLAGS_SINGLECOPY = 0x00040000
	TEXTUREFLAGS_ONEOVERMIPLEVELINALPHA = 0x00080000
	TEXTUREFLAGS_PREMULTCOLORBYONEOVERMIPLEVEL = 0x00100000
	TEXTUREFLAGS_NORMALTODUDV = 0x00200000
	TEXTUREFLAGS_ALPHATESTMIPGENERATION = 0x00400000
	TEXTUREFLAGS_NODEPTHBUFFER = 0x00800000
	TEXTUREFLAGS_NICEFILTERED = 0x01000000
	TEXTUREFLAGS_CLAMPU = 0x02000000
	local iTexFlags = bit.bor(TEXTUREFLAGS_CLAMPS, TEXTUREFLAGS_CLAMPT)
	local sz = ScrW()
	local rt = GetRenderTargetEx(Tag2, sz, sz, RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_NONE, iTexFlags, 0, IMAGE_FORMAT_RGBA8888)

	local mat = CreateMaterial(Tag2, "UnlitGeneric", {
		["$vertexalpha"] = "1",
		["$vertexcolor"] = "1"
	})

	mat:SetTexture("$basetexture", rt)
	local DrawText = surface.DrawText
	local SetTextPos = surface.SetTextPos
	local PopModelMatrix = cam.PopModelMatrix
	local PushModelMatrix = cam.PushModelMatrix
	local surface = surface
	local matrix = Matrix()
	local matrixAngle = Angle(0, 0, 0)
	local matrixScale = Vector(0, 0, 0)
	local matrixTranslation = Vector(0, 0, 0)

	local function TextRotated(text, x, y, xScale, yScale, angle)
		matrixAngle.y = angle
		matrix:SetAngles(matrixAngle)
		matrixTranslation.x = x
		matrixTranslation.y = y
		matrix:SetTranslation(matrixTranslation)
		matrixScale.x = xScale
		matrixScale.y = yScale
		matrix:SetScale(matrixScale)
		SetTextPos(0, 0)
		PushModelMatrix(matrix)
		DrawText(text)
		PopModelMatrix()
	end

	local snd = "http://g1cf.metastruct.net/m3assets/322589__stereo-surgeon__timpani.ogg"
	local function prepare_sound(cb)
		sound.PlayURL(snd, "noplay", function(station)
			if IsValid(station) then
				station:Play()
			end

			cb()
		end)
	end

	local function doSpook()
		prepare_sound(function()
			local startt = RealTime()

			hook.Add("HUDPaint", Tag, function()
				local now = RealTime()
				local elapsed = now - startt
				local f1 = (elapsed - 6.5) / 0.5
				local f2 = (elapsed - 13) / 3
				local f3 = (elapsed - 6.5) / 7
				f1 = f1 > 1 and 1 or f1 < 0 and 0 or f1
				f2 = f2 > 1 and 1 or f2 < 0 and 0 or f2
				f3 = f3 > 1 and 1 or f3 < 0 and 0 or f3
				f1 = f1 * (1 - f2)
				local sw, sh = ScrW(), ScrH()
				surface.SetMaterial(mat)
				surface.SetDrawColor(255, 255, 255, 255 * f1)
				surface.DrawTexturedRect(sw * .5 - sz * .5, sh * .5 - sz * .5, sz, sz)

				if f2 == 1 then
					hook.Remove("HUDPaint", Tag)
				end
			end)

			hook.Add("Think", Tag, function()
				local now = RealTime()
				local elapsed = now - startt
				local f1 = (elapsed - 6.5) / 0.5
				local f2 = (elapsed - 13) / 3
				local f3 = (elapsed - 6.5) / 7
				f1 = f1 > 1 and 1 or f1 < 0 and 0 or f1
				f2 = f2 > 1 and 1 or f2 < 0 and 0 or f2
				f3 = f3 > 1 and 1 or f3 < 0 and 0 or f3

				if f2 == 1 then
					hook.Remove("Think", Tag)
				end

				f1 = f1 * (1 - f2)
				f1 = 1
				surface.SetFont("MGN_Countdown")
				local tw, th = surface.GetTextSize(textToDisplay)
				render.PushRenderTarget(rt)
				local sw, sh = ScrW(), ScrH()
				render.OverrideAlphaWriteEnable(true, true)

				if f2 == 0 then
					render.Clear(0, 0, 0, 0)
					cam.Start2D()
					local tx, ty = sw * .5 - tw * .5, sh * .5 - th * .5

					for i = 1, 3 do
						local p = (i / 7) * math.pi * 2
						local ox, oy = math.sin(p), math.cos(p)
						surface.SetTextColor(15, 15, 15, f1 * 150)
						surface.SetTextPos(tx + ox * f3 * 50, ty + oy * f3 * 50)
						--surface.DrawText(textToDisplay)
						TextRotated(textToDisplay, tx + ox * f3 * 100, ty + oy * f3 * 100, 1 + f3 * .5, 1 + f3 * .5, 0)
					end

					surface.SetTextColor(200, 0, 0, f1 * 255)
					surface.SetTextPos(tx, ty)
					surface.DrawText(textToDisplay)
					cam.End2D()
				end

				render.OverrideAlphaWriteEnable(false)
				render.PopRenderTarget()
				local t = RealTime() * 4
				local q = .7
				render.OverrideAlphaWriteEnable(true, true)
				render.BlurRenderTarget(rt, 1 + q + q * math.sin(t), 1 + q + q * math.cos(t), 1)
				render.OverrideAlphaWriteEnable(false)
			end)
		end)
	end

	net.Receive(Tag, doSpook)
end