
local server = 1 --[[
	1 = Deathrun
	2 = Surf
	3 = TTT
	4 = DarkRP
	5 = Jailbreak
]]--

require( "mysqloo" )

local DATABASE_HOST = "127.0.0.1"
local DATABASE_PORT = 3306
local DATABASE_NAME = ""
local DATABASE_USERNAME = ""
local DATABASE_PASSWORD = ""

local function ConnectToDatabase()

	bansdb = mysqloo.connect(DATABASE_HOST, DATABASE_USERNAME, DATABASE_PASSWORD, DATABASE_NAME, DATABASE_PORT)

	function bansdb:onConnected()
		print("\n*** BANLIST DATABASE CONNECTED ***")
	end

	function bansdb:onConnectionFailed( err )
		print( "Connection to database failed!" )
		print( "Error:", err )
	end

	bansdb:connect()

end
hook.Add("Initialize", "Initialize_banlistdatabse", ConnectToDatabase)

local function bansquery(querystr, callback)
	if !querystr then print("Querystr failed") return end
	if !bansdb then ConnectToDatabase(); timer.Simple(1.5, function() bansquery(querystr, callback); end) end

	local status = bansdb:status()
	if status == 2 or status == 3 then
		print("Status Failed")
		return
	end

	local Query = bansdb:query(querystr)

	if Query == nil then timer.Simple(1, function() bansquery(querystr, callback); print("Query Failed... retrying") end) return end

	function Query.onSuccess( userdata )
		if callback then
			callback(Query:getData())
		end
	end

  function Query:onError( err, sql )
      print( "Query errored!" )
      print( "Query:", sql )
      print( "Error:", err )
  end
    Query:start()
end

local function Core_AddBan( calling_ply, steamid, nick, minutes, reason )
	if !minutes then return end
	local time = tonumber(minutes)
	if !reason then reason = "" end
	if !nick then nick = "" end
	local steamid64 = util.SteamIDTo64(steamid)
	print(nick..", "..steamid64..", "..minutes..", "..reason..", "..nick..", "..server)
	bansquery("INSERT INTO bans (steamid64, name, minutes, reason, admin, server ) VALUES ('"..nick.."', "..steamid64.."', "..minutes..", '"..reason.."', '"..nick.."', "..server..") ")
end

local function Core_Banfunction( steamid, data )
	Core_AddBan( data.admin, util.SteamIDTo64(steamid), data.name, data.unban - data.time, data.reason )
end
hook.Add("ULibPlayerBanned", "Core_Banfunction", Core_Banfunction)

local function Core_Kickfunction( steamid, reason, caller )
	local clr = ""
	if caller then
		clr = caller:Nick();
	end
	Core_AddBan( clr, util.SteamIDTo64(steamid), "", 1, reason)
end
hook.Add("ULibPlayerKicked", "Core_Kickfunction", Core_Kickfunction)
