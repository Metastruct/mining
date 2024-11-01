-- Shared event registration and handling system for mining rock events
local EVENTS = {}

if SERVER then
    util.AddNetworkString("mining_rock_event")
end

local function RegisterRockEvent(eventData)
    -- Validate required fields
    assert(eventData.Id, "Event must have an Id property")
    assert(eventData.Chance, "Event must have a Chance property")
    assert(eventData.OnDestroyed, "Event must have an OnDestroyed handler")

    EVENTS[eventData.Id] = eventData
end

-- Get all registered events
local function GetEvents()
    return EVENTS
end

-- Get a specific event
local function GetEvent(id)
    return EVENTS[id]
end

if SERVER then
    -- Mark rocks with events on creation
    hook.Add("OnEntityCreated", "mining_rock_events", function(ent)
        if not IsValid(ent) then return end
        if ent:GetClass() ~= "mining_rock" then return end

        timer.Simple(0, function()
            if not IsValid(ent) then return end
            if ent:GetClass() == "mining_rock" and not ent.OriginalRock then return end

            -- Only allow one event per rock
            for id, event in pairs(EVENTS) do
                if event.CheckValid and not event.CheckValid(ent) then continue end

                if math.random(0, 100) <= event.Chance then
                    ent.RockEvent = id
                    if event.OnMarked then
                        event.OnMarked(ent)

                        -- Network to clients
                        net.Start("mining_rock_event")
                        net.WriteString("OnMarked")
                        net.WriteString(id)
                        net.WriteEntity(ent)
                        net.Broadcast()
                    end

                    break
                end
            end
        end)
    end)

    -- Handle rock damage
    hook.Add("EntityTakeDamage", "mining_rock_events", function(ent, dmg)
        if not ent.RockEvent then return end

        local event = EVENTS[ent.RockEvent]
        if not event or not event.OnDamaged then return end

        event.OnDamaged(ent, dmg)

        -- Network to clients
        net.Start("mining_rock_event")
        net.WriteString("OnDamaged")
        net.WriteString(ent.RockEvent)
        net.WriteEntity(ent)
        net.WriteFloat(dmg:GetDamage())
        net.Broadcast()
    end)

    -- Handle rock destruction
    hook.Add("PlayerDestroyedMiningRock", "mining_rock_events", function(ply, rock, inflictor)
        if not rock.RockEvent then return end

        local event = EVENTS[rock.RockEvent]
        if not event then return end

        if event.OnDestroyed then
            event.OnDestroyed(ply, rock, inflictor)

            -- Network to clients
            net.Start("mining_rock_event")
            net.WriteString("OnDestroyed")
            net.WriteString(rock.RockEvent)
            net.WriteEntity(ply)
            net.WriteEntity(rock)
            net.WriteEntity(inflictor)
            net.Broadcast()
        end
    end)
end

if CLIENT then
    net.Receive("mining_rock_event", function()
        local eventType = net.ReadString()
        local eventId = net.ReadString()
        local event = EVENTS[eventId]

        if not event then return end

        if eventType == "OnMarked" then
            local ent = net.ReadEntity()
            if event.OnMarked then
                event.OnMarked(ent)
            end
        elseif eventType == "OnDamaged" then
            local ent = net.ReadEntity()
            local damage = net.ReadFloat()
            if event.OnDamaged then
                event.OnDamaged(ent, damage)
            end
        elseif eventType == "OnDestroyed" then
            local ply = net.ReadEntity()
            local rock = net.ReadEntity()
            local inflictor = net.ReadEntity()
            if event.OnDestroyed then
                event.OnDestroyed(ply, rock, inflictor)
            end
        end
    end)
end

-- Make functions available globally
ms.Ores.RegisterRockEvent = RegisterRockEvent
ms.Ores.GetRockEvents = GetEvents
ms.Ores.GetRockEvent = GetEvent