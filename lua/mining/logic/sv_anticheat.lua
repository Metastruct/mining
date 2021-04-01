module("ms", package.seeall)
local Tag = "mineanticheat"
local Ores = assert(Ores)

local maxMinerRange = 340*340

local function playerNearMiningNPC(pl)
	local pos = pl:GetPos()

	for k,npc in next,ents.FindByClass("lua_npc") do
		if npc.role == "miner" and npc:GetPos():DistToSqr(pos) < maxMinerRange then return npc end
	end
end

local function takeAllOres(pl)
	for k,v in next,Ores.__R do
		local n = Ores.GetPlayerOre(pl,k)
		if n <= 0 then continue end

		Ores.TakePlayerOre(pl,k,n)
	end
end

local function playerHasOres(pl)
	for k,v in next,Ores.__R do
		local n = Ores.GetPlayerOre(pl,k)
		if n > 0 then return true end
	end
end

FindMetaTable("Player").HasOres = playerHasOres

-- Anti-cheat Hooks
-- Hinder mining bots by setting a cooldown where rocks and ores can't be interacted with, normal players shouldn't notice this

--TODO: dont block if last mine action was ages ago!!

local function applyMiningCooldown(pl)
	if not pl._receivedOre then return end

    -- This forgives if you haven't mined yet
    local secondsSinceLastMineAction = CurTime()-(pl._lastMiningAction or -999999)
    -- if not playerHasOres(pl) then return end -- TODO: Check if exploitable?

    if secondsSinceLastMineAction > 60*5 then return end

    -- This forgives once every 8 minutes and warns on the first try
    local secondsSinceLastForgiveCooldown = CurTime()-(pl._miningNoclipForgiveTimer or -999999)
	if secondsSinceLastForgiveCooldown > 60*8 then
		pl._miningNoclipForgiveTimer = CurTime()

		if not pl._miningNoclipForgiveMsgd then
			pl._miningNoclipForgiveMsgd = true

			Ores.SendChatMessage(pl,"WARNING: Noclipping/teleporting prevents mining for a minute!")
			pl:EmitSound("vo/npc/female01/thehacks02.wav")
		end

		return
	end

	pl._miningCooldown = CurTime()+45
end

local function setLastMiningAction(pl)
	pl._lastMiningAction = CurTime()
end

hook.Add("PlayerNoClip",Tag,function(pl,enable)
	if not enable then
		applyMiningCooldown(pl)
	end
end)

hook.Add("PlayerDestroyedMiningRock",Tag,setLastMiningAction)
hook.Add("PlayerReceivedOre",Tag,setLastMiningAction)

--TODO
hook.Add("PlayerSoldOre",Tag,setLastMiningAction)

hook.Add("CanPlyGoto",Tag,function(pl)
    if not pl:IsPlayer() then return end
	if not pl._receivedOre then return end

    applyMiningCooldown(pl)

	if not playerHasOres(pl) then return end
	if playerNearMiningNPC(pl) then return end
	-- must block trading here before timer, otherwise race condition
	pl._receivedOre = false

	timer.Create("ms.Ores_CheckMiningNPC"..pl:EntIndex(),0.1,1,function()
		pl._receivedOre = true
		local npc = playerNearMiningNPC(pl)

		if npc then
			timer.Simple(math.Rand(0.01,0.1),function()
				npc:EmitSound("vo/npc/female01/startle01.wav")

				timer.Simple(math.Rand(0.2,0.5),function()
					npc:EmitSound(")vo/npc/male01/thehacks02.wav")
				end)
			end)

			Ores.SendChatMessage(pl,"The merchant was startled by your sudden appearance and refuses to accept your ores at this time...")
			-- takeAllOres(pl) -- too harsh
			pl._receivedOre = false
		end
	end)
end)

hook.Add("CanPlyTeleport",Tag,applyMiningCooldown)

util.OnInitialize(function()
	if istable(_G.SF) then
		local processorClass = "starfall_processor"

		hook.Add("PlayerLoadedStarfall","ms.Ores_SFChecks",function(pl,ent,mainFile,allFiles)
			pl._miningBlocked = true
		end)

		hook.Add("EntityRemoved","ms.Ores_SFChecks",function(ent)
			if ent:GetClass() != processorClass then return end

			local pl = ent.owner or (ent.CPPIGetOwner and ent:CPPIGetOwner())
			if pl and pl:IsValid() and pl._miningBlocked then
				-- Check the player's other Starfall processors, only remove the _miningBlocked flag if they're all clear
				for k,v in next,ents.FindByClass(processorClass) do
					if (v.owner or (v.CPPIGetOwner and v:CPPIGetOwner())) == pl then return end
				end

				pl._miningBlocked = nil
				pl._miningCooldown = CurTime()+30
			end
		end)
	end
end)