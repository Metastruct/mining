-- Haunted Rock Event
local GHOST_CHANCE = 10 -- 10% chance for a rock to be haunted
local GHOST_MODEL = "models/Humans/Group01/male_07.mdl"
local GHOST_SOUNDS = {
    "ambient/voices/crying_loop1.wav",
    "ambient/voices/crying_loop2.wav",
    "npc/stalker/go_alert2a.wav",
    "ambient/creatures/town_child_scream1.wav",
    "ambient/voices/m_scream1.wav"
}

hook.Add("PlayerShouldTakeDamage", "HauntedRockGhostDamage", function(ply, attacker)
    if attacker.IsMiningGhost then
        return true
    end
end)

local function createGhostEffect(pos)
    -- Create tesla effect
    local tesla = ents.Create("point_tesla")
    tesla:SetPos(pos)
    tesla:SetKeyValue("texture", "effects/blueflare1.vmt")
    tesla:SetKeyValue("m_Color", "180 200 255")
    tesla:SetKeyValue("m_flRadius", "100")
    tesla:SetKeyValue("beamcount_min", "4")
    tesla:SetKeyValue("beamcount_max", "8")
    tesla:SetKeyValue("lifetime_min", "0.3")
    tesla:SetKeyValue("lifetime_max", "0.6")
    tesla:SetKeyValue("interval_min", "0.1")
    tesla:SetKeyValue("interval_max", "0.2")
    tesla:Spawn()
    tesla:Fire("DoSpark", "", 0)

    timer.Simple(0.8, function()
        if IsValid(tesla) then tesla:Remove() end
    end)

    -- Add smoke effect
    local smoke = ents.Create("env_smoketrail")
    smoke:SetPos(pos)
    smoke:SetKeyValue("startsize", "10")
    smoke:SetKeyValue("endsize", "50")
    smoke:SetKeyValue("spawnrate", "20")
    smoke:SetKeyValue("opacity", "0.3")
    smoke:SetKeyValue("lifetime", "1")
    smoke:SetKeyValue("startcolor", "180 200 255")
    smoke:SetKeyValue("endcolor", "100 120 255")
    smoke:Spawn()

    timer.Simple(1, function()
        if IsValid(smoke) then smoke:Remove() end
    end)
end

local EVENT = {
    Id = "haunted_rock",
    Chance = GHOST_CHANCE,

    OnMarked = function(rock)
        -- Create ambient ghost sounds
        timer.Create("HauntedRockAmbient" .. rock:EntIndex(), math.random(4, 8), 0, function()
            if not IsValid(rock) then return end
            rock:EmitSound(table.Random(GHOST_SOUNDS), 75, math.random(80, 110), 0.6)
            createGhostEffect(rock:GetPos() + VectorRand() * 30)
        end)

        -- Add ghostly particle trail
        util.SpriteTrail(rock, 0, Color(180, 200, 255, 100), false, 15, 0, 2, 1 / (15 + 1) * 0.5, "trails/plasma.vmt")
    end,

    OnDamaged = function(rock, dmg)
        -- Play a random spooky sound when damaged
        rock:EmitSound(table.Random(GHOST_SOUNDS), 75, math.random(90, 120), 0.5)
        createGhostEffect(rock:GetPos() + VectorRand() * 20)
    end,

    OnDestroyed = function(ply, rock, attacker)
        timer.Remove("HauntedRockAmbient" .. rock:EntIndex())

        -- Bonus rewards
        ms.Ores.GivePlayerOre(ply, rock:GetRarity(), 2)
        ply:EmitSound("ambient/atmosphere/cave_hit" .. math.random(1,6) .. ".wav")

        -- Create ghost NPC
        local ghost = ents.Create("npc_citizen")
        ghost:SetModel(GHOST_MODEL)
        ghost:SetPos(rock:GetPos())
        ghost:SetRenderMode(RENDERMODE_TRANSALPHA)
        ghost:SetColor(Color(180, 200, 255, 180))
        ghost:Spawn()
        ghost:Give("weapon_crowbar")
        ghost:SetMaxHealth(1e9)
        ghost:SetHealth(1e9)

        -- Track ghost NPC
        ghost.IsMiningGhost = true

        -- Add ghostly effects to NPC
        util.SpriteTrail(ghost, 0, Color(180, 200, 255, 100), false, 20, 0, 3, 1 / (20 + 1) * 0.5, "trails/plasma.vmt")

        timer.Create("GhostEffects" .. ghost:EntIndex(), 0.5, 0, function()
            if not IsValid(ghost) then return end
            createGhostEffect(ghost:GetPos() + Vector(0,0,30))
        end)

        -- Make ghost hostile and attack player
        ghost:AddRelationship("player D_HT 99")
        ghost:SetSchedule(SCHED_COMBAT_FACE)
        ghost:SetEnemy(ply)
        ghost:SetNPCState(NPC_STATE_COMBAT)

        -- Remove ghost after delay with dramatic effect
        timer.Simple(10, function()
            if IsValid(ghost) then
                local pos = ghost:GetPos()

                -- Create final dramatic effects
                for i = 1, 5 do
                    timer.Simple(i * 0.2, function()
                        createGhostEffect(pos + Vector(0,0,i * 10))
                    end)
                end

                ghost:EmitSound("ambient/creatures/town_child_scream1.wav", 100, 70)
                ghost:Remove()
            end
        end)
    end
}

local function isOctober()
    return os.date("%m") == "10"
end

local function isFridayThe13th()
    return os.date("%w") == "5" and os.date("%d") == "13"
end

if isOctober() or isFridayThe13th() then
    ms.Ores.RegisterRockEvent(EVENT)
end