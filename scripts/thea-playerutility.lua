require "/scripts/thea-eventutil.lua"
require "/scripts/util.lua"

local originalInit = init
local originalUpdate = update
local originalUninit = uninit

function init()
  originalInit()
  sb.logInfo("===== THEA PLAYER INITIALIZATION =====")
  sb.logInfo("Initializing general player utility script")
  
  --=====================================================================================
  -- Event Notification Handler
  --=====================================================================================
  sb.logInfo("Initializing Event Notification Handler")
  self.events = config.getParameter("thea-events")
  
  --Set up storage for the active event
  storage.activeEvent = storage.activeEvent or {}
  self.activeEvent = nil
  self.notificationWindupTimer = 1.0
  
  --For every configured event, check if it is active now
  local anyEventActive = false
  for _, event in ipairs(self.events) do
	if checkEventActive(event[1]) then
	  self.activeEvent = event
	  anyEventActive = true
	end
  end
  
  --If no event is active, reset the stored active event
  if not anyEventActive then
	storage.activeEvent = nil
  end
  
  --=====================================================================================
  -- Random Event Handler
  --=====================================================================================
  sb.logInfo("Initializing Random Event Handler")
  self.randomEvents = config.getParameter("thea-randomEvents")
  self.randomEventValidPlanetTypes = config.getParameter("thea-randomEventValidPlanetTypes")
  self.timeBewteenRandomEvents = config.getParameter("thea-timeBewteenRandomEvents")
  
  --Set up storage for random events
  storage.timeUntilNextEvent = storage.timeUntilNextEvent or math.random(self.timeBewteenRandomEvents[1], self.timeBewteenRandomEvents[2])
  
  --Set up message handler for checking if the region around the player was modified by a player
  message.setHandler("thea-regionUpdate", regionUpdate)
  self.regionIsPlayerModified = true
  self.dungeonIdAtPosition = 65535
  self.regionCheckTimer = 0
end

function update(args)
  originalUpdate(args)
  
  --=====================================================================================
  -- Event Notification Handler
  --=====================================================================================
  self.notificationWindupTimer = math.max(0, self.notificationWindupTimer - script.updateDt())
  
  --If an event is now active that wasn't active before, show the associated notification window
  --Must run this in update() as the interact action fails when used during init()
  if self.activeEvent then
	if self.activeEvent[1] ~= storage.activeEvent[1] and self.notificationWindupTimer == 0 and player.introComplete() and player.worldId() ~= player.ownShipWorldId() then
	  player.interact("ScriptPane", self.activeEvent[2], player.id())
	  storage.activeEvent = self.activeEvent
	end
  end
  
  if storage.activeEvent then
	sb.setLogMap("THEA - Active festive event", storage.activeEvent[1])
  else
	sb.setLogMap("THEA - Active festive event", "None")
  end
  
  --=====================================================================================
  -- Random Event Handler
  --=====================================================================================
  local currentWorldIsEventValid = world.inSurfaceLayer(entity.position()) and world.terrestrial() and validPlanetType()
  
  --While the player is on a planet's surface, count down the time until the next event
  if currentWorldIsEventValid then
	storage.timeUntilNextEvent = math.max(0, storage.timeUntilNextEvent - script.updateDt())
  end
  
  --Debugging function. Enable this line of code to set the timeUntilNextEvent to 30 seconds, then disable and reload.
  --storage.timeUntilNextEvent = 30
  
  --If the next event is nearly ready, start checking if the region around the player has been modified
  if storage.timeUntilNextEvent < 5 then
	self.regionCheckTimer = math.max(0, self.regionCheckTimer - script.updateDt())
	if self.regionCheckTimer == 0 then
	  world.spawnStagehand(entity.position(), "thea-checkregionmodified")
	  self.regionCheckTimer = 0.25
	end
	world.debugText("Position outside of dungeon: " .. sb.print((self.dungeonIdAtPosition > 65000)), vec2.add(entity.position(), {-3, -7}), "yellow")
	world.debugText("Region is player modified: " .. sb.print(self.regionIsPlayerModified), vec2.add(entity.position(), {-3, -8}), "yellow")
  end
  
  --If the next event is ready, check position and spawn the event stagehand
  if storage.timeUntilNextEvent == 0 then
	if playerIsNearGround() and not self.regionIsPlayerModified and (self.dungeonIdAtPosition > 65000) then
	  local randomEvent = util.randomChoice(self.randomEvents)
	  world.spawnStagehand(entity.position(), randomEvent)
	
	  sb.logInfo("Spawning random event stagehand of type: " .. randomEvent)
	  storage.timeUntilNextEvent = math.random(self.timeBewteenRandomEvents[1], self.timeBewteenRandomEvents[2])
	else
	  --Delay the spawning of the event stagehand until the player is at a suitable position
	end
  end
  
  sb.setLogMap("THEA - Time until next random event", storage.timeUntilNextEvent)
  sb.setLogMap("THEA - Type of world", world.type())
  sb.setLogMap("THEA - World type is valid", sb.print(validPlanetType()))
  sb.setLogMap("THEA - World is terrestrial", sb.print(world.terrestrial()))
end

function playerIsNearGround()
  local groundPositionAndNormal = world.lineTileCollisionPoint(entity.position(), vec2.add(entity.position(), {0, -100}))
  world.debugText("Distance to ground: " .. world.magnitude(entity.position(), groundPositionAndNormal[1]), vec2.add(entity.position(), {-3, -6}), "yellow")
  
  if world.magnitude(entity.position(), groundPositionAndNormal[1]) < 5 then
	return true
  else
	return false
  end
end

function validPlanetType()
  local planetTypeIsValid = false
  for _, planetType in ipairs(self.randomEventValidPlanetTypes) do
	if planetType == world.type() then
	  planetTypeIsValid = true
	end
  end
  return planetTypeIsValid
end

function regionUpdate(_, _, regionIsPlayerModified, dungeonIdAtPosition)
  self.regionIsPlayerModified = regionIsPlayerModified
  self.dungeonIdAtPosition = dungeonIdAtPosition
end

function uninit()
  originalUninit()
end