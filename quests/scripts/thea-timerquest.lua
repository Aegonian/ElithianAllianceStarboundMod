--This quest script sets a worldProperty (as configured by the quest template) to save a property across play sessions and visited worlds
--This worldProperty will remain active (true) for the duration of a single day. The next day, the property will be reset (nil)
--This worldProperty can then be used by any other script to check if the player already performed a specific action that day

require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/quests/scripts/questutil.lua"
require "/quests/scripts/portraits.lua"
require "/scripts/thea-eventutil.lua"

function init()
  storage.startYear = storage.startYear or getCurrentYear()
  storage.startDay = storage.startDay or getCurrentDay()
  
  self.worldProperty = config.getParameter("worldProperty")
  self.debugText = config.getParameter("debugText")
  self.debugTextPosition = config.getParameter("debugTextPosition")
end

function questStart()
  
end

function update(dt)  
  self.currentYear = getCurrentYear()
  self.currentDay = getCurrentDay()
  
  --world.debugText("Start Year : " .. storage.startYear, vec2.add(entity.position(), {0,2}), "yellow")
  --world.debugText("Start Day  : " .. storage.startDay, vec2.add(entity.position(), {0,1}), "yellow")
  --world.debugText("Current Year : " .. self.currentYear, vec2.add(entity.position(), {0,-1}), "yellow")
  --world.debugText("Current Day  : " .. self.currentDay, vec2.add(entity.position(), {0,-2}), "yellow")
  
  if self.currentYear == storage.startYear and self.currentDay == storage.startDay then
	world.setProperty(self.worldProperty .. tostring(entity.id()), true)
	world.debugText(self.debugText, vec2.add(entity.position(), self.debugTextPosition), "pink")
  else
	quest.complete()
  end
end

function uninit()
  world.setProperty(self.worldProperty .. tostring(entity.id()), nil)
end

function questComplete()
  world.setProperty(self.worldProperty .. tostring(entity.id()), nil)
end
