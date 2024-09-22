-- this is needed for entities to have access to orchestrator.RegisterInput and orchestrator.RegisterOutput

if type(_G.MA_Orchestrator) ~= "table" then
	include("mining/logic/automation/sh_orchestrator.lua")
end

return _G.MA_Orchestrator