require "/scripts/util.lua"
require "/quests/scripts/questutil.lua"
require("/quests/scripts/portraits.lua")
require('/quests/scripts/conditions/gather.lua')
require('/quests/scripts/conditions/ship.lua')
require('/quests/scripts/conditions/scanning.lua')
require('/quests/scripts/messages.lua')

function init()
  buildMessageHandlers()
  setPortraits()
  
  sb.logInfo("THEA MOD INFO: Started an invisible quest to kickstart a THEA storyline")
end

function questStart()
  --The quest is automatically completed upon completing or skipping the intro
  if player.introComplete() then
    quest.complete()
    return
  end
end

function questComplete()
  setPortraits()

  questutil.questCompleteActions()
end

function update(dt)
  promises:update()
  
  --The quest is automatically completed upon completing or skipping the intro
  if player.introComplete() then
    quest.complete()
    return
  end
end
