
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

	bansquery("INSERT INTO bans (steamid64, name, minutes, reason, admin, server ) VALUES ('"..nick.."'', "..steamid64.."', "..minutes..", '"..reason.."', '"..nick.."', "..server..") ")
end

function ULib.addBan( steamid, time, reason, name, admin )
	if reason == "" then reason = nil end

	local admin_name
	local admin_nick = "ADMIN"

	if admin then
		admin_name = "(Console)"
		admin_nick = "(Console)"
		if admin:IsValid() then
			admin_name = string.format( "%s(%s)", admin:Name(), admin:SteamID() )
			admin_nick = admin:Name()
		end
	end

	local t = {}
	local timeNow = os.time()
	if ULib.bans[ steamid ] then
		t = ULib.bans[ steamid ]
		t.modified_admin = admin_name
		t.modified_time = timeNow
	else
		t.admin = admin_name
	end
	t.time = t.time or timeNow
	if time > 0 then
		t.unban = ( ( time * 60 ) + timeNow )
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

	local strTime = time ~= 0 and ULib.secondsToStringTime( time*60 )
	local shortReason = "Banned for " .. (strTime or "eternity")
	if reason then
		shortReason = shortReason .. ": " .. reason
	end

	local longReason = shortReason
	if reason or strTime or admin then -- If we have something useful to show
		longReason = "\n" .. ULib.getBanMessage( steamid ) .. "\n" -- Newlines because we are forced to show "Disconnect: <msg>."
	end


	local ply_nick = ""

	local ply = player.GetBySteamID( steamid )
	if ply then
		ULib.kick( ply, longReason, nil, true)
		ply_nick = ply:Name()
	end

	-- Remove all semicolons from the reason to prevent command injection
	shortReason = string.gsub(shortReason, ";", "")
	Core_AddBan(admin_name, steamid, ply_nick, time, reason )
	-- This redundant kick code is to ensure they're kicked -- even if they're joining
	game.ConsoleCommand( string.format( "kickid %s %s\n", steamid, shortReason or "" ) )
	game.ConsoleCommand( string.format( "banid %f %s kick\n", time, steamid ) )
	game.ConsoleCommand( "writeid\n" )

	ULib.fileWrite( ULib.BANS_FILE, ULib.makeKeyValues( ULib.bans ) )
	hook.Call( ULib.HOOK_USER_BANNED, _, steamid, t )
end

function ULib.kick( ply, reason, calling_ply )
	local nick = calling_ply and calling_ply:IsValid() and
		(string.format( "%s(%s)", calling_ply:Nick(), calling_ply:SteamID() ) or "Console")
	local steamid = ply:SteamID()
	if reason and nick then
		ply:Kick( string.format( "Kicked by %s - %s", nick, reason ) )
		Core_AddBan(nick, steamid, nick, 1, reason )
	elseif nick then
		ply:Kick( "Kicked by " .. nick )
		Core_AddBan(nick, steamid, ply, 1, " " )
	else
		ply:Kick( reason or "[ULX] Kicked from server" )
	end
	hook.Call( ULib.HOOK_USER_KICKED, _, steamid, reason or "[ULX] Kicked from server", calling_ply )
end

if server == 3 then
	local reason = "Karma too low"
	function KARMA.CheckAutoKick(ply)
		if ply:GetBaseKarma() <= config.kicklevel:GetInt() then
			if hook.Call("TTTKarmaLow", GAMEMODE, ply) == false then
				return
			end
			ServerLog(ply:Nick() .. " autokicked/banned for low karma.\n")
			ply.karma_kicked = true
			if config.persist:GetBool() then
				local k = math.Clamp(config.starting:GetFloat() * 0.8, config.kicklevel:GetFloat() * 1.1, config.max:GetFloat())
				ply:SetPData("karma_stored", k)
				KARMA.RememberedPlayers[ply:SteamID()] = k
			end
			if config.autoban:GetBool() then
				ply:KickBan(config.bantime:GetInt(), reason)
				Core_AddBan("CONSOLE", ply:SteamID(),ply:Nick(), config.bantime:GetInt(), reason )
			else
				ply:Kick(reason)
				Core_AddBan("CONSOLE", ply:SteamID(),ply:Nick(), 1, reason )
			end
		end
	end
end
