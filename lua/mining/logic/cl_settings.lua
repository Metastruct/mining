module("ms",package.seeall)

Ores = Ores or {}

Ores.Settings = {
	EntityFrames = CreateConVar("mining_automation_entity_frames", 1, FCVAR_USERINFO, "Should the mining automation entities spawn with frames"),
	RockLights = CreateConVar("mining_rock_lights",1,FCVAR_ARCHIVE,"Enables the light emitted from mining rocks."),
	ReduceMessages = CreateConVar("mining_reducemessages",0,FCVAR_ARCHIVE,"Reduces messages displayed in the chat about mining. Number is loosely based on importance.\n0 = See all messages\n1 = Hide tutorials (eg. when you pick up ore)\n2 = Also hide warnings (eg. warnings about noclip)\n3 = Also hide alerts (eg. event notices)")
}