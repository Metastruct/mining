-- Small helpers similar to those found in "metastruct/preinit.lua" of the metastruct repo
local function includeShared(f)
    if SERVER then
        AddCSLuaFile(f .. ".lua")
    end

    include(f .. ".lua")
end

local function includeClient(f)
    if SERVER then
        AddCSLuaFile(f .. ".lua")
    else
        include(f .. ".lua")
    end
end

local function includeServer(f)
    if SERVER then
        include(f .. ".lua")
    end
end

local guiFiles = {}

local function includeGuiFile(f)
    if SERVER then
        AddCSLuaFile(f .. ".lua")
    else
        guiFiles[#guiFiles + 1] = f .. ".lua"
    end
end

local tag = "ms.Ores.IncludeGui"

hook.Add("InitPostEntity", tag, function()
    for k, v in next, guiFiles do
        include(v)
    end

    hook.Remove("InitPostEntity", tag)
end)

-- File initialisation starts here...
includeShared("mining/logic/sh_ores")
includeServer("mining/logic/sv_ores")
includeShared("mining/logic/automation/sh_config")
includeServer("mining/logic/automation/sv_compat")
includeShared("mining/logic/automation/sh_orchestrator")
includeClient("mining/logic/automation/cl_hud")
includeClient("mining/logic/automation/cl_power_hud")
includeShared("mining/logic/automation/sh_terminal")
includeShared("mining/logic/automation/sh_blood_deals")
includeShared("mining/logic/caves/sh_miner")
includeServer("mining/logic/caves/sv_miner")
includeClient("mining/logic/caves/cl_miner")
includeShared("mining/logic/caves/sh_pickaxe")
includeServer("mining/logic/caves/sv_pickaxe")
includeServer("mining/logic/caves/sv_rock_spawning")
includeServer("mining/logic/sv_savedata")
includeServer("mining/logic/sv_settings")
includeServer("mining/logic/caves/sv_special_days")
includeClient("mining/logic/cl_settings")
includeGuiFile("mining/gui/miner_menu")
includeServer("mining/logic/sv_anticheat")
includeShared("mining/logic/events/sh_rock_events")
includeServer("mining/logic/events/sv_mine_collapse")
includeShared("mining/logic/events/sh_toxic_gas")
includeServer("mining/logic/events/sv_rocklions")
includeShared("mining/logic/events/sh_quantum_rock")
includeServer("mining/logic/events/sv_haunted_rock")
includeShared("mining/logic/events/sh_fun")
includeShared("mining/logic/magma_caves/sh_magma_cave")
includeServer("mining/logic/magma_caves/sv_argonite")
includeServer("mining/logic/magma_caves/sv_detonite")
includeShared("mining/logic/magma_caves/sh_extraction")