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
		nextRarity,
		ambSoundPath,
		ambSoundPitch,
		ambSoundVolume,
		hidden)
	Ores.__R[id] = {
		Name = name,
		Health = health,
		Worth = worth,
		PhysicalColor = physicalCol,
		HudColor = hudCol,
		SparkleInterval = sparkleInterval or 1, -- Doubled for mining_ore
		NextRarityId = nextRarity,
		AmbientSound = ambSoundPath,
		AmbientPitch = ambSoundPitch,
		AmbientVolume = ambSoundVolume and ambSoundVolume/3,
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
	0.7,
	1
)

AddOre(1,
	"Silver",
	65,
	300,
	Color(255,255,255),
	Color(200,235,235),
	0.5,
	2
)

AddOre(2,
	"Gold",
	90,
	1200,
	Color(255,255,0),
	Color(225,225,0),
	0.3,
	3,
	"ambient/levels/labs/machine_ring_resonance_loop1.wav",30,0.6
)

AddOre(3,
	"Platinum",
	115,
	2000,
	Color(153,255,237),
	Color(140,255,235),
	0.3,
	nil,
	"ambient/levels/citadel/field_loop3.wav",65,0.9,
	true
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

function Ores.GetPlayerMultiplier(self)
	assert(self and self:IsPlayer(),"[Ores] First argument is not a player")

	return math.Clamp((SERVER and Ores.WorthMultiplier or (Ores.SpecialDay and Ores.SpecialDay.WorthMultiplier or 1)),1,5)+self:GetNWFloat(Ores._nwMult,0)
end