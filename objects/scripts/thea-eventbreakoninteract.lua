require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/thea-eventutil.lua"

function init()
  self.event = config.getParameter("event")
  self.events = config.getParameter("events")
  self.debugResults = config.getParameter("debugResults", false)
  
  self.eventActive = false
  self.eventActiveChecked = false
  
  object.setInteractive(false)
  
  animator.setAnimationState("objectState", "hidden")
end

function onInteraction(args)
  object.smash(false)
end

function update(dt)
  --If region is active we haven't check yet and no NPC has been spawned, check if the event should activate
  if world.regionActive(regionCheckArea()) and not self.eventActiveChecked and self.event then
	self.eventActive, self.currentMonth, self.currentDay, self.leapYear = checkEventActive(self.event)
	self.eventActiveChecked = true
	
  --Variation for objects with multiple configured events
  elseif world.regionActive(regionCheckArea()) and not self.eventActiveChecked and self.events then	
	for _, event in ipairs(self.events) do
	  if checkEventActive(event) then
		self.eventActive = event
	  end
	end
	self.eventActiveChecked = true
  end
  
  --Set the object's animation state based on event active check results
  if self.eventActive then
	if config.getParameter("multiEventAppearance") then
	  animator.setAnimationState("objectState", self.eventActive)
	else
	  animator.setAnimationState("objectState", "visible")
	end
	if config.getParameter("activeLightColor") then
	  object.setLightColor(config.getParameter("activeLightColor"))
	end
	object.setInteractive(true)
  else
	animator.setAnimationState("objectState", "hidden")
	if config.getParameter("inactiveLightColor") then
	  object.setLightColor(config.getParameter("inactiveLightColor"))
	end
	object.setInteractive(false)
  end
    
  --If we have checked if the event is active, show the results in debug mode without running the check function again. Only usable for objects with only a single configured event
  if self.eventActiveChecked and self.debugResults and self.event then
	local eventConfig = root.assetJson("/thea-eventschedules.config:" .. self.event)
	world.debugText("Event active: " .. sb.print(self.eventActive), vec2.add(entity.position(), {0,0}), "yellow")
	world.debugText("Event Name: " .. sb.print(eventConfig.eventName), vec2.add(entity.position(), {0,-0.75}), "yellow")
	
	world.debugText("Current Month: " .. sb.print(self.currentMonth), vec2.add(entity.position(), {0,1}), "yellow")
	world.debugText("Event Month: " .. sb.print(eventConfig.eventActiveMonth), vec2.add(entity.position(), {0,1.75}), "yellow")
	
	world.debugText("Current Day: " .. sb.print(self.currentDay), vec2.add(entity.position(), {0,3}), "yellow")
	world.debugText("Event Days: " .. sb.print(eventConfig.eventStartDay) .. " until " .. sb.print(eventConfig.eventEndDay), vec2.add(entity.position(), {0,3.75}), "yellow")
	
	world.debugText("Leap Year: " .. sb.print(self.leapYear), vec2.add(entity.position(), {0,5}), "yellow")
  elseif self.eventActiveChecked and not self.debugResults then
	script.setUpdateDelta(0)
  end
end

--This function is used to calculate a region around the stagehand position
--If this region is active/loaded, the rest of the stagehand behaviour can run
function regionCheckArea()
  local area = {-1, -1, 1, 1}
  local pos = entity.position()
  return {
	area[1] + pos[1],
	area[2] + pos[2],
	area[3] + pos[1],
	area[4] + pos[2]
  }
end