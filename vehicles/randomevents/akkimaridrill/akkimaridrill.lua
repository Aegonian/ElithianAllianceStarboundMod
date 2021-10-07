require "/scripts/vec2.lua"

function init()
  --HOVER CONFIG SETTINGS
  self.maxGroundSearchDistance = config.getParameter("maxGroundSearchDistance")
  self.hoverTargetDistance = config.getParameter("hoverTargetDistance")
  self.hoverVelocityFactor = config.getParameter("hoverVelocityFactor")
  self.hoverControlForce = config.getParameter("hoverControlForce")
  self.hoverWaveCycle = config.getParameter("hoverWaveCycle")
  self.hoverWaveDistance = config.getParameter("hoverWaveDistance")
  --CAPTURE CONFIG SETTINGS
  self.rotationRateWhileIdle = config.getParameter("rotationRateWhileIdle")
  self.rotationRateWhileCapturing = config.getParameter("rotationRateWhileCapturing")
  self.captureRadius = config.getParameter("captureRadius")
  self.timeToCapture = config.getParameter("timeToCapture")
  self.notifyPlayerRadius = config.getParameter("notifyPlayerRadius")
  self.startRadioMessage = config.getParameter("startRadioMessage")
  self.successRadioMessage = config.getParameter("successRadioMessage")
  self.treasurePool = config.getParameter("treasurePool")
  self.treasureSpawnPosition = config.getParameter("treasureSpawnPosition")
  --SPAWN CONFIG SETTINGS
  self.spawnProfile = config.getParameter("spawnProfile")
  --ANIMATION CONFIG SETTINGS
  self.drillingDistance = config.getParameter("drillingDistance")
  
  self.lastPosition = mcontroller.position()
  self.hoverTimer = 0
  self.captureTimer = 0
  self.notifiedPlayerIds = {}
  self.groupsSpawned = {}
  self.successMessagePlayed = false
  self.drillSoundPlaying = false
  
  vehicle.setPersistent(false)
  vehicle.setInteractive(false)
end

function update()  
  --========================= General Behaviour =========================
  self.groundDistance = distanceToGround(mcontroller.position())
  self.spawning = (animator.animationState("body") == "spawn" or animator.animationState("body") == "despawn" or animator.animationState("body") == "invisible")
  
  --If we are spawning or despawning, freeze the vehicle in place
  if self.spawning then
	mcontroller.setPosition(self.lastPosition)
    mcontroller.setVelocity({0,0})
  end
  
  if animator.animationState("body") == "invisible" then
	vehicle.destroy()
  end
  
  --========================= Animation Behaviour =========================
  if self.groundDistance < self.drillingDistance and not self.spawning then
	animator.setAnimationState("body", "drilling")
	
	local region = {0, -self.groundDistance, 0, -self.groundDistance}
	animator.setParticleEmitterOffsetRegion("drillSmoke", region)
	animator.setParticleEmitterActive("drillSmoke", true)
  elseif not self.spawning then
	animator.setAnimationState("body", "idle")
	animator.setParticleEmitterActive("drillSmoke", false)
  else
	animator.setParticleEmitterActive("drillSmoke", false)
  end
  
  if not self.drillSoundPlaying and self.groundDistance < self.drillingDistance and not self.spawning then
	animator.playSound("drilling", -1)
	self.drillSoundPlaying = true
  elseif not (self.groundDistance < self.drillingDistance) or self.spawning then
	animator.stopAllSounds("drilling")
	self.drillSoundPlaying = false
  end
  
  
  --========================= Capturing Behaviour =========================
  local newPlayers = world.playerQuery(mcontroller.position(), self.notifyPlayerRadius)	--Create an updated list of nearby players
  local playerList = table.concat(self.notifiedPlayerIds, ",")							--Convert the list of already notified players to a string so we can retrace IDs
  for _, playerId in ipairs(newPlayers) do
	if not string.find(playerList, playerId) then
	  table.insert(self.notifiedPlayerIds, playerId)									--Insert previously unregistered players into the list of notified players
	  world.sendEntityMessage(playerId, "queueRadioMessage", self.startRadioMessage)	--Send a radioMessage to the newly registered player
	end
  end
  
  if self.groundDistance < self.drillingDistance and not self.spawning then
	local rotation = 0
	
	local nearbyPlayers = world.playerQuery(mcontroller.position(), self.captureRadius)
	if #nearbyPlayers > 0 then
	  animator.setAnimationState("zone", "capturing")
	  rotation = self.rotationRateWhileCapturing
	  self.captureTimer = math.min(self.timeToCapture, self.captureTimer + script.updateDt())
	else
	  animator.setAnimationState("zone", "idle")
	  rotation = self.rotationRateWhileIdle
	end
	
	rotation = rotation * script.updateDt()
	animator.rotateTransformationGroup("zone", rotation)
  else
	animator.setAnimationState("zone", "invisible")
  end
  
  if self.captureTimer == self.timeToCapture then
	if not self.successMessagePlayed then
	  local nearbyPlayers = world.playerQuery(mcontroller.position(), self.notifyPlayerRadius)
	  for _, playerId in ipairs(nearbyPlayers) do
		world.sendEntityMessage(playerId, "queueRadioMessage", self.successRadioMessage)
	  end
	  
	  world.spawnTreasure(vec2.add(mcontroller.position(), self.treasureSpawnPosition), self.treasurePool, world.threatLevel())
	  
	  animator.setAnimationState("body", "despawn")
	  self.successMessagePlayed = true
	end
  end
  
  self.captureProgress = self.captureTimer / self.timeToCapture
  animator.resetTransformationGroup("progressbar")
  animator.scaleTransformationGroup("progressbar", {self.captureProgress, 1}, {-3.0, 0.0})
  
  --========================= Spawning Behaviour =========================
  local spawnedGroupsList = table.concat(self.groupsSpawned, ",")
  for i = 1, #self.spawnProfile do
	local profile = self.spawnProfile[i]
	if profile[1] <= self.captureProgress and not string.find(spawnedGroupsList, i) and not self.spawning then
	  world.spawnStagehand(mcontroller.position(), profile[2])
	  table.insert(self.groupsSpawned, i)
	end
  end
  
  --========================= Hover Behaviour =========================
  self.hoverTimer = self.hoverTimer + script.updateDt()
  local targetDistance = (math.sin(self.hoverTimer / self.hoverWaveCycle) * self.hoverWaveDistance) + self.hoverTargetDistance
  
  --If too close to the ground, push the vehicle up
  if self.groundDistance <= targetDistance then
	mcontroller.approachYVelocity((targetDistance - self.groundDistance) * self.hoverVelocityFactor, self.hoverControlForce)
  end
  
  self.lastPosition = mcontroller.position()
  
  
  --========================= Debug Behaviour =========================
  world.debugText("Capture Timer: " .. self.captureTimer .. " / " .. self.timeToCapture, vec2.add(mcontroller.position(), {0,0}), "yellow")
  world.debugText("Capture Progress: " .. self.captureProgress, vec2.add(mcontroller.position(), {0,-1}), "yellow")
  world.debugText("Start message sent to players: " .. playerList, vec2.add(mcontroller.position(), {0,-2}), "yellow")
  world.debugText("Enemy groups spawned: " .. spawnedGroupsList, vec2.add(mcontroller.position(), {0,-3}), "yellow")
end

--Helper function for calculating distance from ground
function distanceToGround(point)
  local endPoint = vec2.add(point, {0, -self.maxGroundSearchDistance})
  local distance = self.maxGroundSearchDistance

  world.debugLine(point, endPoint, {255, 255, 0, 255})
  local intPoint = world.lineCollision(point, endPoint)
  if intPoint then
	distance = point[2] - intPoint[2]
	world.debugPoint(intPoint, {255, 255, 0, 255})
  end
  
  return distance
end
