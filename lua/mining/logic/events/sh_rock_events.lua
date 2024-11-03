module("ms", package.seeall)
Ores = Ores or {}

-- Shared event registration and handling system for mining rock events
local EVENTS = Ores.GetRockEvents and Ores.GetRockEvents() or {}

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

            local pickedEvents = {}
            for id, event in pairs(EVENTS) do
                if event.CheckValid and not event.CheckValid(ent) then continue end

                if math.random(0, 100) <= event.Chance then
                    table.insert(pickedEvents, id)
                end
            end

            table.sort(pickedEvents, function(a, b)
                return EVENTS[a].Chance < EVENTS[b].Chance
            end)

            if #pickedEvents > 0 then
                local eventId = pickedEvents[1] -- Prioritize lower chance events
                local event = EVENTS[eventId]

                ent:SetNWString("RockEvent", eventId)
                if event.OnMarked then
                    event.OnMarked(ent)

                    -- Network to clients
                    net.Start("mining_rock_event")
                    net.WriteString("OnMarked")
                    net.WriteString(eventId)
                    net.WriteEntity(ent)
                    net.Broadcast()
                end
            end
        end)
    end)

    -- Handle rock damage
    hook.Add("EntityTakeDamage", "mining_rock_events", function(ent, dmg)
        local eventId = ent:GetNWString("RockEvent", "")
        if eventId == "" then return end

        local event = EVENTS[eventId]
        if not event or not event.OnDamaged then return end

        event.OnDamaged(ent, dmg)

        -- Network to clients
        net.Start("mining_rock_event")
        net.WriteString("OnDamaged")
        net.WriteString(eventId)
        net.WriteEntity(ent)
        net.WriteFloat(dmg:GetDamage())
        net.Broadcast()
    end)

    -- Handle rock destruction
    hook.Add("PlayerDestroyedMiningRock", "mining_rock_events", function(ply, rock, inflictor)
        local eventId = rock:GetNWString("RockEvent", "")
        if eventId == "" then return end

        local event = EVENTS[eventId]
        if not event then return end

        if event.OnDestroyed then
            event.OnDestroyed(ply, rock, inflictor)

            -- Network to clients
            net.Start("mining_rock_event")
            net.WriteString("OnDestroyed")
            net.WriteString(eventId)
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
Ores.RegisterRockEvent = RegisterRockEvent
Ores.GetRockEvents = GetEvents
Ores.GetRockEvent = GetEvent