module("ms",package.seeall)

if CLIENT then
	-- No need for a cl_mine file yet
	net.Receive("ms.Ores_ChatMSG",function()
		local txt = net.ReadString()
		local importanceLvl = net.ReadUInt(3)

		-- Check if the client wants to see the message
		if (importanceLvl or 0) < Ores.Settings.ReduceMessages:GetInt() then return end

		chat.AddText(Color(230, 130, 65)," ♦ [Ores] ", color_white, txt)
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
		suffix,
		health,
		worth,
		physicalCol,
		hudCol,
		sparkleInterval,
		nextRarity,
		ambSoundPath,
		ambSoundPitch,
		ambSoundVolume,
		ambSoundLevel,
		hidden)

	Ores.__R[id] = {
		Name = name,
		Suffix = suffix, -- Placed after the ore's name on the HUD
		Health = health,
		Worth = worth,
		PhysicalColor = physicalCol,
		HudColor = hudCol,
		SparkleInterval = sparkleInterval or 1, -- Doubled for mining_ore
		NextRarityId = nextRarity,
		AmbientSound = ambSoundPath,
		AmbientPitch = ambSoundPitch,
		AmbientVolume = ambSoundVolume and ambSoundVolume / 3,
		AmbientLevel = ambSoundLevel,
		Hidden = hidden or false
	}
end

Ores = Ores or {}
Ores.__E = {}
Ores.__R = {}

-- Ore Definition
AddOre(0,
	"Coal",
	"",
	10,
	5,
	Color(25, 25, 25),
	Color(75, 75, 75),
	2,
	nil,
	nil,nil,nil,nil,
	true
)

AddOre(1,
	"Copper",
	nil,
	40,
	25,
	Color(255, 77, 0),
	Color(225, 100, 40),
	0.7,
	2
)

AddOre(2,
	"Silver",
	nil,
	65,
	75,
	Color(255, 255, 255),
	Color(200, 235, 235),
	0.5,
	3
)

AddOre(3,
	"Gold",
	nil,
	90,
	300,
	Color(255, 255, 0),
	Color(225, 225, 0),
	0.3,
	4,
	"ambient/levels/labs/machine_ring_resonance_loop1.wav", 30, 0.6, 75
)

AddOre(4,
	"Platinum",
	nil,
	115,
	500,
	Color(153, 255, 237),
	Color(140, 255, 235),
	0.3,
	nil,
	"ambient/levels/citadel/field_loop3.wav", 65, 0.9, 78,
	true
)

-- magma cave ores
AddOre(18,
	"Argonite",
	nil,
	40,
	1,
	Color(255, 20, 50),
	Color(255, 20, 50),
	0.3,
	nil,
	nil, nil, nil, nil,
	true
)

AddOre(19,
	"Detonite",
	nil,
	1,
	1,
	Color(255, 0, 0),
	Color(255, 0, 0),
	0.3,
	nil,
	"hl1/ambience/labdrone2.wav", 25, 0.3, 78,
	true
)

-- -- --

for k,v in next,Ores.__R do
	Ores.__E[v.Name:upper()] = k
end

function Ores.GetPlayerOre(self, rarity)
	assert(self and self:IsPlayer(), "[Ores] First argument is not a player")
	assert(isnumber(rarity) and Ores.__R and Ores.__R[rarity], "[Ores] Rarity argument is invalid")

	return self:GetNWInt(Ores._nwPrefix .. Ores.__R[rarity].Name, 0)
end

function Ores.GetPlayerMultiplier(self)
	assert(self and self:IsPlayer(), "[Ores] First argument is not a player")

	return math.Clamp(SERVER and Ores.WorthMultiplier or (Ores.SpecialDay and Ores.SpecialDay.WorthMultiplier or 1), 1, 5) + self:GetNWFloat(Ores._nwMult, 0)
end

local cache = {}
function Ores.GetOreRarityByName(name)
	name = name:lower()

	if cache[name] then return cache[name] end

	for rarity, rarityData in pairs(Ores.__R) do
		if rarityData.Name:lower() == name then
			cache[name] = rarity
			return rarity
		end
	end

	return -1
end