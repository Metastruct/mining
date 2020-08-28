module("ms",package.seeall)

local sqlTableName = "Mining_Savedata"
local sqlLevelPrefix = "lvl"

local function checkLibraries()
	assert(type(co) == "table","Helper library/function for coroutines 'co' is not present in '_G'. Mining savedata is unavailable!")
	assert(type(db) == "table","Helper library for using PostgreSQL 'db' is not present in '_G'. Mining savedata is unavailable!")
end

Ores = Ores or {}

function Ores.GetSavedPlayerDataAsync(pl,callback)
	checkLibraries()

	db.Query(("SELECT * FROM %s WHERE accountId = %d LIMIT 1"):format(sqlTableName,pl:AccountID()),function(data)
		if not data then
			pl._noMiningData = true
		end

		data = data[1]

		local result = {_points = data and data.points or 0}
		for k,v in next,Ores.__PStats do
			local value = data[sqlLevelPrefix..v.VarName]
			result[v.VarName] = value and tonumber(value) or 0
		end

		callback(result)
	end)
end

function Ores.SetSavedPlayerData(pl,field,value)
	checkLibraries()

	if field != "points" then
		field = sqlLevelPrefix..field
	end

	co(function()
		if pl._noMiningData then
			db.Query(("INSERT INTO %s(accountId) VALUES(%d)"):format(sqlTableName,pl:AccountID()))
			pl._noMiningData = nil
		end

		db.Query(("UPDATE %s SET %s = %d WHERE accountId = %d"):format(sqlTableName,field,pl:AccountID()))
	end)
end

function Ores.InitSavedPlayerData()
	checkLibraries()

	-- Auto-create and setup the mining savedata table in the database
	co(function()
		db.Query(("CREATE TABLE IF NOT EXISTS %s(accountId integer NOT NULL PRIMARY KEY, points integer DEFAULT 0)"):format(sqlTableName))

		local columns = ""
		for k,v in next,Ores.__PStats do
			columns = columns..("ADD COLUMN IF NOT EXISTS %s%s integer DEFAULT 0,"):format(sqlLevelPrefix,v.VarName)
		end

		if columns != "" then
			db.Query(("ALTER TABLE %s %s"):format(sqlTableName,columns))
		end
	end)
end

Ores.InitSavedPlayerData()