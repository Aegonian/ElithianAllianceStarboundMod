local originalInit = init
local originalUpdate = update
local originalUninit = uninit

function init()
  originalInit()
  sb.logInfo("===== THEA PLAYER INITIALIZATION =====")
  sb.logInfo("Initializing general player utility script")
end

function update(args)
  originalUpdate(args)
end

function uninit()
  originalUninit()
end