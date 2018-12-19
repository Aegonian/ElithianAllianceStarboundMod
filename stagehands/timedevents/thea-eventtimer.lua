require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/thea-eventutil.lua"

function init()
  self.event = config.getParameter("event")
  self.debugResults = config.getParameter("debugResults", false)
  
  storage.spawnedNPC = storage.spawnedNPC or false
  self.npcSpecies = config.getParameter("npcSpecies")
  self.npcType = config.getParameter("npcType")
  self.npcLevel = config.getParameter("npcLevel") or world.threatLevel()
  
  self.eventActive = false
  self.eventActiveChecked = false
  
  self.dieAfterSpawning = config.getParameter("stagehandDieAfterSpawning", true)
end

function update(dt)
  --If region is active we haven't checked event dates yet, check if the event should activate
  if world.regionActive(regionCheckArea()) and not self.eventActiveChecked then
	self.eventActive, self.currentMonth, self.currentDay, self.leapYear = checkEventActive(self.event)
	self.eventActiveChecked = true
  end
  
  --If the event is active and the NPC has not yet been spawned, do so now
  if self.eventActive and not storage.spawnedNPC then
	local species = util.randomChoice(self.npcSpecies)
	world.spawnNpc(entity.position(), species, self.npcType, self.npcLevel)
	storage.spawnedNPC = true
  end
  
  --If configured to die after spawning an NPC, do so here
  if storage.spawnedNPC and self.dieAfterSpawning then
	stagehand.die()
  end
    
  --If we have checked if the event is active, show the results in debug mode without running the check function again
  if self.eventActiveChecked and self.debugResults then
	local eventConfig = root.assetJson("/thea-eventschedules.config:" .. self.event)
	world.debugText("Event active: " .. sb.print(self.eventActive), vec2.add(entity.position(), {0,0}), "yellow")
	world.debugText("Event Name: " .. sb.print(eventConfig.eventName), vec2.add(entity.position(), {0,-0.75}), "yellow")
	
	world.debugText("Current Month: " .. sb.print(self.currentMonth), vec2.add(entity.position(), {0,1}), "yellow")
	world.debugText("Event Month: " .. sb.print(eventConfig.eventActiveMonth), vec2.add(entity.position(), {0,1.75}), "yellow")
	
	world.debugText("Current Day: " .. sb.print(self.currentDay), vec2.add(entity.position(), {0,3}), "yellow")
	world.debugText("Event Days: " .. sb.print(eventConfig.eventStartDay) .. " until " .. sb.print(eventConfig.eventEndDay), vec2.add(entity.position(), {0,3.75}), "yellow")
	
	world.debugText("Leap Year: " .. sb.print(self.leapYear), vec2.add(entity.position(), {0,5}), "yellow")
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
