
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

function bansquery(querystr, callback)
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

local function Core_AddBan( calling_ply, target_ply, minutes, reason )
	if !target_ply or !minutes then return end
	local time = tonumber(minutes)
	local nick = calling_ply
	--if calling_ply then nick = calling_ply:Nick() end
	if !reason then reason = "" end
	
	bansquery("INSERT INTO bans (steamid64, minutes, reason, admin, server ) VALUES ('"..target_ply:SteamID64().."', "..minutes..", '"..reason.."', '"..nick.."', "..server..") ")


end

function ULib.addBan( steamid, time, reason, name, admin ) --Replace ULIb
	local strTime = time ~= 0 and string.format( "for %s minute(s)", time ) or "permanently"
	local showReason = string.format( "Banned %s: %s", strTime, reason )
	local banned_ply
	local players = player.GetAll()
	for i=1, #players do
		if players[ i ]:SteamID() == steamid then
			ULib.kick( players[ i ], showReason, admin )
			banned_ply = players[ i ]
		end
	end

	-- Remove all semicolons from the reason to prevent command injection
	showReason = string.gsub(showReason, ";", "")

	-- This redundant kick code is to ensure they're kicked -- even if they're joining
	game.ConsoleCommand( string.format( "kickid %s %s\n", steamid, showReason or "" ) )
	game.ConsoleCommand( string.format( "banid %f %s kick\n", time, steamid ) )
	game.ConsoleCommand( "writeid\n" )

	local admin_name
	if admin then
		admin_name = "(Console)"
		if admin:IsValid() then
			admin_name = admin:Name()
		end
	end

	local t = {}
	if ULib.bans[ steamid ] then
		t = ULib.bans[ steamid ]
		t.modified_admin = admin_name
		t.modified_time = os.time()
	else
		t.admin = admin_name
	end
	t.time = t.time or os.time()
	if time > 0 then
		t.unban = ( ( time * 60 ) + os.time() )
	else
		t.unban = 0
	end
	if reason then
		t.reason = reason
	end
	if name then
		t.name = name
	end
	ULib.bans[ steamid ] = t
	ULib.fileWrite( ULib.BANS_FILE, ULib.makeKeyValues( ULib.bans ) )
	
	Core_AddBan(admin_name, banned_ply, time, reason )

end

function ULib.kick( ply, reason, calling_ply )
	if reason and calling_ply ~= nil then
		local nick = calling_ply:IsValid() and string.format( "%s(%s)", calling_ply:Nick(), calling_ply:SteamID() ) or "Console"
		ply:Kick( string.format( "Kicked by %s (%s)", nick, reason or "[ULX] Kicked from server" ) )
		Core_AddBan(calling_ply:Nick(), ply, 1, reason )
	else
		ply:Kick( reason or "[ULX] Kicked from server" )
		Core_AddBan(calling_ply:Nick(), ply, 1, " " )
	end
end


