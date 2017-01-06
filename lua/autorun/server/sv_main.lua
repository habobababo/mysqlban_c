
function Core_BanPlayer(steamid, time, reason, name, admin )
  if !reason then reason = "" end
  if !name then name = "" end
  if !admin then 
    admin = "" 
  else
    admin = admin:Nick()
  end
  if !steamid then return end
  
  corequery("INSERT INTO bans (steamid, time, reason, name, admin) VALUES ('"..steamid.."', '"..time.."', '"..reason.."', '"..name.."', '"..admin.."') ")
		end
	end)
end

function Core_KickPlayer(steamid, reason, name, admin)
  if !reason then reason = "" end
  if !name then name = "" end
  if !admin then 
    admin = "" 
  else
    admin = admin:Nick()
  end
  if !steamid then return end

  corequery("INSERT INTO bans (steamid, reason, name, admin) VALUES ('"..steamid.."', '"..reason.."', '"..name.."', '"..admin.."') ")
    end
  end)
end
