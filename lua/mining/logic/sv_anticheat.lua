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

	local now = CurTime()

	-- This forgives if you haven't mined yet
	local secondsSinceLastMineAction = now - (pl._lastMiningAction or -999999)

	if secondsSinceLastMineAction > 60 * 5 then return end

	-- This forgives once every 8 minutes and warns on the first try
	local secondsSinceLastForgiveCooldown = now - (pl._miningNoclipForgiveTimer or -999999)
	if secondsSinceLastForgiveCooldown > 60 * 8 then
		pl._miningNoclipForgiveTimer = now

		if not pl._miningNoclipForgiveMsgd then
			pl._miningNoclipForgiveMsgd = true

			Ores.SendChatMessage(pl,1,"WARNING: Noclipping/teleporting prevents mining for a while!")
			pl:EmitSound("vo/npc/female01/thehacks02.wav")
		end

		return
	end

	pl._miningCooldown = now + 20
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

			Ores.SendChatMessage(pl,1,"The merchant was startled by your sudden appearance and refuses to accept your ores at this time...")
			pl._receivedOre = false
		end
	end)
end)

hook.Add("CanPlyTeleport",Tag,applyMiningCooldown)

util.OnInitialize(function()
	local function addToChipsOwned(pl,ent)
		pl._miningChipsOwned = pl._miningChipsOwned or {}
		pl._miningChipsOwned[ent] = true

		pl._miningBlocked = true
	end

	local chipClasses = {}

	if istable(_G.E2Lib) then
		local registerCallback = _G.E2Lib.registerCallback or registerCallback

		if registerCallback then
			registerCallback("construct",function(data)
				if data.player and data.player:IsValid() then
					addToChipsOwned(data.player,data.entity)
				end
			end)

			chipClasses.gmod_wire_expression2 = true
		end
	end

	if istable(_G.SF) then
		hook.Add("PlayerLoadedStarfall","ms.Ores_ChipChecks",function(pl,ent,mainFile,allFiles)
			addToChipsOwned(pl,ent)
		end)

		chipClasses.starfall_processor = true
	end

	if next(chipClasses) then
		hook.Add("EntityRemoved","ms.Ores_ChipChecks",function(ent)
			if not chipClasses[ent:GetClass()] then return end

			local pl = ent.owner or ent.player or (ent.CPPIGetOwner and ent:CPPIGetOwner())

			if pl and pl:IsValid() and pl._miningChipsOwned then
				pl._miningChipsOwned[ent] = nil

				-- If the player still has chips spawned, don't remove the _miningBlocked flag yet
				if next(pl._miningChipsOwned) then return end

				pl._miningChipsOwned = nil
				pl._miningBlocked = nil
				pl._miningCooldown = CurTime()+30
			end
		end)
	else
		addToChipsOwned = nil
		chipClasses = nil
	end
end)