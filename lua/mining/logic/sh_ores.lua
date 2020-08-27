module("ms",package.seeall)

if CLIENT then
	-- No need for a cl_mine file yet
	net.Receive("ms.Ores_ChatMSG",function()
		local txt = net.ReadString()
		chat.AddText(Color(230,130,65)," ♦ [Ores] ",color_white,txt)
	end)

	net.Receive("ms.Ores_UpdateSpecialDay",function()
		local name = net.ReadString()

		if name and name != "" then
			local mult = net.ReadFloat()

			Ores.SpecialDay = {
				Name = name,
				WorthMultiplier = mult
			}
		else
			Ores.SpecialDay = nil
		end
	end)
end

-- Ore Functions
local function AddOre(
		id,
		name,
		health,
		worth,
		physicalCol,
		hudCol,
		sparkleInterval,
		ambSoundPath,
		ambSoundPitch,
		hidden)
	Ores.__R[id] = {
		Name = name,
		Health = health,
		Worth = worth,
		PhysicalColor = physicalCol,
		HudColor = hudCol,
		SparkleInterval = sparkleInterval or 1, -- Doubled for mining_ore
		AmbientSound = ambSoundPath,
		AmbientPitch = ambSoundPitch,
		Hidden = hidden or false
	}
end

Ores = Ores or {}
Ores.__E = {}
Ores.__R = {}

-- Ore Definition
AddOre(0,
	"Copper",
	40,
	100,
	Color(255,77,0),
	Color(225,100,40),
	0.7
)

AddOre(1,
	"Silver",
	65,
	300,
	Color(255,255,255),
	Color(200,235,235),
	0.5
)

AddOre(2,
	"Gold",
	90,
	1200,
	Color(255,255,0),
	Color(225,225,0),
	0.3,
	"ambient/levels/labs/machine_ring_resonance_loop1.wav",30
)
-- -- --

for k,v in next,Ores.__R do
	Ores.__E[v.Name:upper()] = k
end

function Ores.GetPlayerOre(self,rarity)
	assert(self and self:IsPlayer(),"[Ores] First argument is not a player")
	assert(isnumber(rarity) and Ores.__R and Ores.__R[rarity],"[Ores] Rarity argument is invalid")

	return self:GetNWInt(Ores._nwPrefix..Ores.__R[rarity].Name,0)
end