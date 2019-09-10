require "/scripts/util.lua"

local originalInit = init
local originalUpdate = update
local originalUninit = uninit

function init()
  originalInit()
  sb.logInfo("===== THEA PLAYER COMPANIONS INITIALIZATION =====")
  sb.logInfo("Initializing player companions utility script")
  
  message.setHandler("theaRequestCompanions", function()
	return playerCompanions.getCompanions("followers")
  end)
end

function update(args)
  originalUpdate(args)
end

function uninit()
  originalUninit()
end