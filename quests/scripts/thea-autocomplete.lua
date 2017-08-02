require "/scripts/util.lua"
require "/quests/scripts/questutil.lua"
require("/quests/scripts/portraits.lua")

function init()
  setPortraits()
end

function questStart()
  quest.complete()
end

function questComplete()
  setPortraits()

  questutil.questCompleteActions()
end

function update(dt)  
  
end
