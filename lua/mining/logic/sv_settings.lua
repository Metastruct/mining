module("ms",package.seeall)

Ores = Ores or {}

Ores.Settings = {
	BonusSpots = CreateConVar("mining_rock_bonusspots",1,FCVAR_ARCHIVE,"Enables bonus spot generation on mining rocks."),
	VerbosePrint = CreateConVar("mining_verbose",0,FCVAR_NONE,"Enables verbose printing in the console for debugging mining.")
}