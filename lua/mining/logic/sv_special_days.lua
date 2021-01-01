module("ms",package.seeall)

local str = string.format
local next = next

Ores = Ores or {}

util.AddNetworkString("ms.Ores_UpdateSpecialDay")
function Ores.SendSpecialDayInfo(pl)
	net.Start("ms.Ores_UpdateSpecialDay")
	if Ores.SpecialDays.ActiveId then
		net.WriteString(Ores.SpecialDays.Days[Ores.SpecialDays.ActiveId].Name)
		net.WriteFloat(Ores.WorthMultiplier)
	end
	net.Send(pl)
end

local function BuildSpecialDay(name,from,to,mult)
	return table.insert(Ores.SpecialDays.Days,{
		Name = name,
		Date = {
			From = {
				Month = from[1],
				Day = from[2],
				Hour = from[3]
			},
			To = {
				Month = to[1],
				Day = to[2],
				Hour = to[3]
			}
		},
		Multiplier = mult
	})
end

Ores.WorthMultiplier = Ores.WorthMultiplier or 1
Ores.SpecialDays = {Days = {}}

BuildSpecialDay("Meta Construct's Birthday",{1,23,0},{1,24,0},2.5)
BuildSpecialDay("Anniversary of Mining 2.0",{1,25,0},{1,26,0},2)
BuildSpecialDay("Valentine's Day",{2,14,0},{2,15,0},2)
BuildSpecialDay("April Fools",{4,1,0},{4,2,0},1.5)
BuildSpecialDay("Independence Day",{7,4,0},{7,5,0},2)
BuildSpecialDay("Halloween",{10,31,0},{11,1,0},1.5)
BuildSpecialDay("GMod's Birthday",{11,29,0},{11,30,0},1.5)
BuildSpecialDay("Christmas",{12,24,0},{12,27,0},2)	-- Christmas Period, 24-26

function Ores.NotifySpecialDay(pl)
	if pl == nil or (istable(pl) and #pl == 0) then return end
	if not Ores.SpecialDays.ActiveId then return end

	local day = Ores.SpecialDays.Days[Ores.SpecialDays.ActiveId]
	local toTime = os.date("!*t")
	toTime.month = day.Date.To.Month
	toTime.day = day.Date.To.Day
	toTime.hour = day.Date.To.Hour
	toTime.min = 0
	toTime.sec = 1

	Ores.SendChatMessage(pl,str("In celebration of %s, get +%d%% payout when turning in your ores! Celebration ends in %s!",day.Name,(day.Multiplier-1)*100,string.NiceTime(os.time(toTime)-os.time())))
end

function Ores.CheckForSpecialDay()
	local year = os.date("!*t").year
	local unix = os.time()
	for k,v in next,Ores.SpecialDays.Days do
		if os.time({
			year = year,
			month = v.Date.From.Month,
			day = v.Date.From.Day,
			hour = v.Date.From.Hour,
			min = 0,
			sec = 0}) <= unix
		and os.time({
			year = year+(v.Date.From.Month > v.Date.To.Month and 1 or 0),
			month = v.Date.To.Month,
			day = v.Date.To.Day,
			hour = v.Date.To.Hour,
			min = 0,
			sec = 0}) >= unix
		then
			local activatingDay = not Ores.SpecialDays.ActiveId

			Ores.SpecialDays.ActiveId = k
			Ores.WorthMultiplier = v.Multiplier

			if activatingDay then
				local pls = player.GetHumans()

				Ores.Print(str("Activating special day \"%s\" with x%s payout mutliplier, until %s-%s-%s %s:00...",v.Name,v.Multiplier,year,v.Date.To.Month,v.Date.To.Day,v.Date.To.Hour))
				Ores.SendSpecialDayInfo(pls)
				Ores.NotifySpecialDay(pls)
			end
			return
		end
	end

	if Ores.SpecialDays.ActiveId then
		local pls = player.GetHumans()
		local dayName = Ores.SpecialDays.Days[Ores.SpecialDays.ActiveId].Name

		Ores.Print(str("Deactivating special day \"%s\"...",dayName))
		Ores.SendSpecialDayInfo(pls)
		Ores.SendChatMessage(pls,str("The celebration of %s has ended! Thank you for taking part!",dayName))
	end

	Ores.SpecialDays.ActiveId = nil
	Ores.WorthMultiplier = 1
end

local sdTag = "ms.Ores_SpecialDays"
local function specialDayTimer()
	-- Recalculate time or we slowly start going out of sync
	local date = os.date("!*t")
	timer.Adjust(sdTag,((60-date.min)*60)-date.sec+10,0,specialDayTimer)

	Ores.CheckForSpecialDay()
end

timer.Create(sdTag,1,0,specialDayTimer)