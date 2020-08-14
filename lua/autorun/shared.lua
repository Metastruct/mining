-- Small helpers similar to those found in "metastruct/preinit.lua" of the metastruct repo
local function includeShared(f)
	if SERVER then AddCSLuaFile(f..".lua") end
	include(f..".lua")
end

local function includeClient(f)
	if SERVER then
		AddCSLuaFile(f..".lua")
	else
		include(f..".lua")
	end
end

local function includeServer(f)
	if SERVER then include(f..".lua") end
end

local function includeGuiFiles()
	local tag = "ms.Ores.IncludeGui"
	local files = file.Find("mining/gui/*.lua","LUA")

	if SERVER then
		for k,v in next,files do
			AddCSLuaFile("mining/gui/"..v..".lua")
		end
	else
		hook.Add("InitPostEntity",tag,function()
			for k,v in next,files do
				include("mining/gui/"..v..".lua")
			end

			hook.Remove("InitPostEntity",tag)
		end)
	end
end

-- File initialisation starts here...
includeShared("mining/logic/sh_ores")
includeServer("mining/logic/sv_ores")
includeShared("mining/logic/sh_miner")
includeServer("mining/logic/sv_miner")
includeShared("mining/logic/sh_pickaxe")
includeServer("mining/logic/sv_pickaxe")
includeGuiFiles("mining/gui/miner_menu")