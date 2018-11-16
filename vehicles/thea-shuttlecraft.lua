require("/scripts/vec2.lua")
require("/vehicles/thea-vehicletheft.lua")

--============================================================================================================
--============================================== INITIALIZATION ==============================================
--============================================================================================================
function init()
  --CONFIG FILE SETTINGS
  --Flight settings
  self.flySpeedX = config.getParameter("flySpeedX")
  self.flySpeedY = config.getParameter("flySpeedY")
  self.flyControlForceX = config.getParameter("flyControlForceX")
  self.flyControlForceY = config.getParameter("flyControlForceY")
  self.stopControlForce = config.getParameter("stopControlForce")
  self.verticalMovementAngle = config.getParameter("verticalMovementAngle")
  self.brakingAngle = config.getParameter("brakingAngle")
  self.movementSettings = config.getParameter("movementSettings")
  self.occupiedMovementSettings = config.getParameter("occupiedMovementSettings")
  --Liquid settings
  self.maxLiquidImmersion = config.getParameter("maxLiquidImmersion")
  self.liquidBuoyancy = config.getParameter("liquidBuoyancy")
  --Health settings
  self.protection = config.getParameter("protection")
  self.maxHealth = config.getParameter("maxHealth")
  self.materialKind = config.getParameter("materialKind")
  self.damageStateNames = config.getParameter("damageStateNames")
  self.smokeHealthFactor = config.getParameter("smokeHealthFactor")
  self.fireHealthFactor = config.getParameter("fireHealthFactor")
  self.warningHealthFactor = config.getParameter("warningHealthFactor")
  --Collision settings
  self.minDamageCollisionAccel = config.getParameter("minDamageCollisionAccel")
  self.minNotificationCollisionAccel = config.getParameter("minNotificationCollisionAccel")
  self.terrainCollisionDamage = config.getParameter("terrainCollisionDamage")
  self.terrainCollisionDamageSourceKind = config.getParameter("terrainCollisionDamageSourceKind")
  self.accelerationTrackingCount = config.getParameter("accelerationTrackingCount")
  --Rotation settings
  self.levelApproachFactor = config.getParameter("levelApproachFactor")
  self.angleApproachFactor = config.getParameter("angleApproachFactor")
  self.maxGroundSearchDistance = config.getParameter("maxGroundSearchDistance")
  self.maxAngle = config.getParameter("maxAngle") * math.pi / 180
  --Spring positions
  self.frontSpringPositions = config.getParameter("frontSpringPositions")
  self.backSpringPositions = config.getParameter("backSpringPositions")
  --Sound effects
  self.engineIdlePitch = config.getParameter("engineIdlePitch")
  self.engineRevPitch = config.getParameter("engineRevPitch")
  self.engineIdleVolume = config.getParameter("engineIdleVolume")
  self.engineRevVolume = config.getParameter("engineRevVolume")
  self.idleEngineTime = config.getParameter("idleEngineTime")
  --Emote settings
  self.damageTakenEmote = config.getParameter("damageTakenEmote")
  self.driverEmote = config.getParameter("driverEmote")
  self.driverEmoteDamaged = config.getParameter("driverEmoteDamaged")
  self.driverEmoteNearDeath = config.getParameter("driverEmoteNearDeath")
  self.damageEmoteTimer = 0
  
  --Starting stats
  self.selfDamageNotifications = {}
  self.collisionDamageTrackingVelocities = {}
  self.collisionNotificationTrackingVelocities = {}
  self.hasBeenCollected = false
  self.lastPosition = mcontroller.position()
  self.angle = 0
  self.lastXVelocity = mcontroller.xVelocity()
  self.headlightCanToggle = true
  self.headlightsOn = false
  self.collisionLoopSoundPlaying = false
  self.idleLoopSoundPlaying = false
  self.loopSoundPlaying = false
  self.enginePitch = self.engineRevPitch
  self.engineVolume = self.engineIdleVolume
  self.idleEngineTimer = 0
  self.warningSoundIsPlaying = false
  animator.stopAllSounds("warning")
  self.nullifyImpactDamage = true
  self.nullifyImpactDamageTimer = 0

  self.driver = nil
  self.facingDirection = config.getParameter("facingDirection") or 1 --Allow the spawner to set the starting facing direction
  
  --Starting animations
  animator.setGlobalTag("rearThrusterFrame", 1)
  animator.setGlobalTag("bottomThrusterFrame", 1)

  animator.setAnimationState("rearThruster", "off")
  animator.setAnimationState("bottomThruster", "off")

  animator.setAnimationState("headlights", "off")
  
  --OWNER KEY
  --Inherited from vehicle controller to see what vehicle belongs to what controller
  self.ownerKey = config.getParameter("ownerKey")
  vehicle.setPersistent(self.ownerKey)
  
  --VEHICLE PERSISTANCE
  --Function for making vehicles spawned from stagehands persistent
  message.setHandler("setPersistent", function(_, _)
      vehicle.setPersistent(true)
	  storage.isPersistent = true
    end)
  if storage.isPersistent then
	vehicle.setPersistent(true)
  end

  --STARTING HEALTH CONFIG
  --Inherit health factor from vehicle controller and set initial health values
  if (storage.health) then
    animator.setAnimationState("body", "idle")
  else
    local startHealthFactor = config.getParameter("startHealthFactor")

    if (startHealthFactor == nil) then
        storage.health = self.maxHealth
    else
       storage.health = math.min(startHealthFactor * self.maxHealth, self.maxHealth)
    end    
    animator.setAnimationState("body", "warpInPart1")
  end

  --STORAGE
  --Setting up the vehicle controller storage functionality  
  message.setHandler("store",
	function(_, _, ownerKey)
	  if (self.ownerKey and self.ownerKey == ownerKey and self.driver == nil and animator.animationState("body")=="idle") then
		animator.setAnimationState("body", "warpOutPart1")
		animator.playSound("returnvehicle")
		self.hasBeenCollected = true
		return {storable = true, healthFactor = storage.health / self.maxHealth}
	  else
		return {storable = false, healthFactor = storage.health / self.maxHealth}
	  end
	end)
end

--============================================================================================================
--============================================== UPDATE ======================================================
--============================================================================================================
function update()
  --Nullify collision damage for a short time after spawning
  self.nullifyImpactDamageTimer = math.min(10, self.nullifyImpactDamageTimer + script.updateDt())
  if self.nullifyImpactDamageTimer > 2.0 then
	self.nullifyImpactDamage = false
  end
  
  --Remove vehicle if animation was set to invisible
  if (animator.animationState("body")=="invisible") then
    vehicle.destroy()
	world.debugText("I was destroyed! You shouldn't be seeing this...", mcontroller.position(), "yellow")
  --Freeze the vehicle when it is being collected
  elseif (animator.animationState("body")=="warpInPart1" or animator.animationState("body")=="warpOutPart2") then
    --Lock the vehicle in place spawning/despawning
    mcontroller.setPosition(self.lastPosition)
    mcontroller.setVelocity({0,0})
	world.debugText("I am being collected", mcontroller.position(), "yellow")
	--Hide landing gear and passenger door while warping
	animator.setAnimationState("landingGear", "invisible")
	animator.setAnimationState("passengerDoor", "invisible")
  --Optionally raise the landing gear when starting warp
  elseif (animator.animationState("body")=="warpInPart2" or animator.animationState("body")=="warpOutPart1") then
	if config.getParameter("raiseLandingGearInWarp") then
	  animator.setAnimationState("landingGear", "up")
	end
  --When not warping (i.e. idle or in use)
  else
    local driverThisFrame = vehicle.entityLoungingIn("drivingSeat")
	local passengerThisFrame = vehicle.entityLoungingIn("passengerSeat")
	
	--Code for detecting vehicle theft
	if not self.ownerKey and driverThisFrame and not self.driver then
	  local licenseItem = config.getParameter("licenseItem")
	  broadcastTheft(driverThisFrame, licenseItem)
	end

	--Make the vehicle's damage team passive when not in use, to prevent enemies from damaging it
    if (driverThisFrame ~= nil) then
      vehicle.setDamageTeam(world.entityDamageTeam(driverThisFrame))
    else
      vehicle.setDamageTeam({type = "passive"})
	  if self.hasBeenCollected == false then
	  end
    end
	
	--Count down the idle engine sound timer
	if self.headlightsOn or driverThisFrame then
	  self.idleEngineTimer = self.idleEngineTime
	end
	self.idleEngineTimer = math.max(0, self.idleEngineTimer - script.updateDt())

	--Calculate health factor
    local healthFactor = storage.health / self.maxHealth

	--Run through all basic functions every update tick
	control(driverThisFrame)
	animate(driverThisFrame)
	updateDamage(0, self.headlightsOn)
	updateDriveEffects(healthFactor, driverThisFrame)
	updatePassengers(healthFactor)
	
	--Passenger door control
	if passengerThisFrame then
	  if animator.animationState("passengerDoor") == "open" then
		animator.setAnimationState("passengerDoor", "closing")
	  end
	else
	  if animator.animationState("passengerDoor") == "closed" then
		animator.setAnimationState("passengerDoor", "opening")
	  elseif animator.animationState("passengerDoor") == "invisible" then
		animator.setAnimationState("passengerDoor", "open")
	  end
	end
	
    self.driver = driverThisFrame
  end
  
  --world.debugText(self.idleEngineTimer, vec2.add(mcontroller.position(), {0,1}), "green")
  --world.debugText(sb.printJson(self.idleLoopSoundPlaying), mcontroller.position(), "green")
end

--============================================================================================================
--============================================== PLAYER CONTROL ==============================================
--============================================================================================================

--Handling player control input, as well as automated controls when driverless
function control(driverThisFrame)
  mcontroller.resetParameters(self.movementSettings)
  if self.driver then
    mcontroller.applyParameters(self.occupiedMovementSettings)
  end
  
  --Engine sound control
  self.enginePitch = self.engineIdlePitch
  self.engineVolume = self.engineIdleVolume
  
  --Headlight control
  if (vehicle.controlHeld("drivingSeat","PrimaryFire")) then
    if (self.headlightCanToggle) then
      updateDamage(0, (not self.headlightsOn))
      if (self.headlightsOn) then
        animator.playSound("headlightSwitchOn")
      else
        animator.playSound("headlightSwitchOff")
      end
      self.headlightCanToggle = false
    end
  else
    self.headlightCanToggle = true
  end
  
  --MOVING LEFT
  if vehicle.controlHeld("drivingSeat", "left") and not vehicle.controlHeld("drivingSeat", "jump") then
	mcontroller.approachXVelocity(-self.flySpeedX, self.flyControlForceX)
	self.facingDirection = -1
	if mcontroller.xVelocity() < self.lastXVelocity and mcontroller.xVelocity() > 0 then
	  self.angle = self.angle + (self.verticalMovementAngle - self.angle) * self.angleApproachFactor
	end
	
	self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume
  end
  
  --MOVING RIGHT
  if vehicle.controlHeld("drivingSeat", "right") and not vehicle.controlHeld("drivingSeat", "jump") then
	mcontroller.approachXVelocity(self.flySpeedX, self.flyControlForceX)
	self.facingDirection = 1
	if mcontroller.xVelocity() > self.lastXVelocity and mcontroller.xVelocity() < 0 then
	  self.angle = self.angle + (-self.verticalMovementAngle - self.angle) * self.angleApproachFactor
	end
	
	self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume
  end
  
  --MOVING DOWN
  if vehicle.controlHeld("drivingSeat", "down") and not vehicle.controlHeld("drivingSeat", "jump") then
	mcontroller.approachYVelocity(-self.flySpeedY, self.flyControlForceY)
	--Code for rotating the vehicle
	if vehicle.controlHeld("drivingSeat", "right") then
	  self.angle = self.angle + (-self.verticalMovementAngle - self.angle) * self.angleApproachFactor
	elseif vehicle.controlHeld("drivingSeat", "left")then
	  self.angle = self.angle + (self.verticalMovementAngle - self.angle) * self.angleApproachFactor
	else
	  self.angle = self.angle + (0 - self.angle) * self.angleApproachFactor
	end
  end
  
  --MOVING UP
  if vehicle.controlHeld("drivingSeat", "up") and not vehicle.controlHeld("drivingSeat", "jump") then
	mcontroller.approachYVelocity(self.flySpeedY, self.flyControlForceY)
	--Code for rotating the vehicle
	if vehicle.controlHeld("drivingSeat", "right") then
	  self.angle = self.angle + (self.verticalMovementAngle - self.angle) * self.angleApproachFactor
	elseif vehicle.controlHeld("drivingSeat", "left") then
	  self.angle = self.angle + (-self.verticalMovementAngle - self.angle) * self.angleApproachFactor
	else
	  self.angle = self.angle + (0 - self.angle) * self.angleApproachFactor
	end
	
	self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume
  end
  
  --NO MOVEMENT
  if not vehicle.controlHeld("drivingSeat", "up") and not vehicle.controlHeld("drivingSeat", "down") then
	if not vehicle.controlHeld("drivingSeat", "right") and not vehicle.controlHeld("drivingSeat", "left") then
	  --Facing right
	  if self.facingDirection > 0 then
		if mcontroller.xVelocity() < self.lastXVelocity and mcontroller.xVelocity() > 10 and mcontroller.yVelocity() >= 0 then
		  self.angle = self.angle + (-self.brakingAngle - self.angle) * self.angleApproachFactor
		elseif mcontroller.xVelocity() < self.lastXVelocity and mcontroller.xVelocity() > 10 and mcontroller.yVelocity() < 0 then
		  self.angle = self.angle + (self.brakingAngle - self.angle) * self.angleApproachFactor
		else
		  self.angle = self.angle + (0 - self.angle) * self.angleApproachFactor
		end
	  --Facing left
	  elseif self.facingDirection < 0 then
		if mcontroller.xVelocity() > self.lastXVelocity and mcontroller.xVelocity() < -10 and mcontroller.yVelocity() >= 0 then
		  self.angle = self.angle + (self.brakingAngle - self.angle) * self.angleApproachFactor
		elseif mcontroller.xVelocity() > self.lastXVelocity and mcontroller.xVelocity() < -10 and mcontroller.yVelocity() < 0 then
		  self.angle = self.angle + (-self.brakingAngle - self.angle) * self.angleApproachFactor
		else
		  self.angle = self.angle + (0 - self.angle) * self.angleApproachFactor
		end
	  end
	else
	  self.angle = self.angle + (0 - self.angle) * self.angleApproachFactor
	end
  end
  
  --STOP MOVEMENT
  if vehicle.controlHeld("drivingSeat", "jump") then
	mcontroller.approachVelocity({0,0}, self.stopControlForce)
  end
  
  --CONTROLS WHILE DRIVERLESS
  --If driverless and in a liquid, but not underwater, make the vehicle float
  if not driverThisFrame then
	local waterLevel = mcontroller.liquidPercentage()
	
	if waterLevel > 0 and waterLevel < self.maxLiquidImmersion then
	  mcontroller.applyParameters({liquidBuoyancy = self.liquidBuoyancy})
	end
  end
  
  self.lastXVelocity = mcontroller.xVelocity()
end

--============================================================================================================
--============================================== ANIMATION ===================================================
--============================================================================================================

--Flipping the vehicle sprites based on our facing direction, and rotating based on terrain if no driver is present
function animate(driverThisFrame)
  --Setting facing direction
  animator.resetTransformationGroup("flip")
  animator.setGlobalTag("direction", "default")
  if self.facingDirection < 0 then
    animator.scaleTransformationGroup("flip", {-1, 1})
	animator.setGlobalTag("direction", "flipped")
  end
  
  if driverThisFrame then
	--Let the intended angle be calculated by flight ballistics and controls
	
	--Rear thruster animation control
	if (vehicle.controlHeld("drivingSeat", "right") or vehicle.controlHeld("drivingSeat", "left")) and not vehicle.controlHeld("drivingSeat", "jump") then
	  animator.setAnimationState("rearThruster", "active")
	else
	  animator.setAnimationState("rearThruster", "idle")
	end
	
	--Bottom thruster animation control
	if vehicle.controlHeld("drivingSeat", "up") and not vehicle.controlHeld("drivingSeat", "jump") then
	  animator.setAnimationState("bottomThruster", "active")
	else
	  animator.setAnimationState("bottomThruster", "idle")
	end
	
	--Landing gear control
	if animator.animationState("landingGear") == "down" then
	  animator.setAnimationState("landingGear", "raise")
	end
  else
	--Calculate target angle according the the terrain
    local frontSpringDistance = minimumSpringDistance(self.frontSpringPositions)
    local backSpringDistance = minimumSpringDistance(self.backSpringPositions)
    if frontSpringDistance == self.maxGroundSearchDistance and backSpringDistance == self.maxGroundSearchDistance then
      self.angle = self.angle - self.angle * self.angleApproachFactor
    else
      self.angle = self.angle + math.atan((backSpringDistance - frontSpringDistance) * self.levelApproachFactor)
      self.angle = math.min(math.max(self.angle, -self.maxAngle), self.maxAngle)
    end
	
	--Rear thruster animation control
	animator.setAnimationState("rearThruster", "off")

	--Bottom thruster animation control
	animator.setAnimationState("bottomThruster", "off")
	
	--Landing gear control
	if animator.animationState("landingGear") == "up" then
	  animator.setAnimationState("landingGear", "lower")
	elseif animator.animationState("landingGear") == "invisible" then
	  animator.setAnimationState("landingGear", "down")
	end
  end
  
  --Random frame selection for thrusters
  local rearThrusterFrame = 0
  local bottomThrusterFrame = 0
  
  rearThrusterFrame = rearThrusterFrame + math.random(3)
  animator.setGlobalTag("rearThrusterFrame", rearThrusterFrame)
  
  bottomThrusterFrame = bottomThrusterFrame + math.random(3)
  animator.setGlobalTag("bottomThrusterFrame", bottomThrusterFrame)
  
  --Setting vehicle rotation
  animator.resetTransformationGroup("rotation")
  animator.rotateTransformationGroup("rotation", self.angle)
  mcontroller.setRotation(self.angle)
end

--Function for calculating spring distance from ground, used to calculate vehicle's target rotation
function minimumSpringDistance(points)
  local min = nil
  for _, point in ipairs(points) do
    point = vec2.rotate(point, self.angle)
    point = vec2.add(point, mcontroller.position())
    local d = distanceToGround(point)
    if min == nil or d < min then
      min = d
    end
  end
  return min
end

--Calculating distance from ground
function distanceToGround(point)
  local endPoint = vec2.add(point, {0, -self.maxGroundSearchDistance})

  world.debugLine(point, endPoint, {255, 255, 0, 255})
  local intPoint = world.lineCollision(point, endPoint)

  if intPoint then
    world.debugPoint(intPoint, {255, 255, 0, 255})
    return point[2] - intPoint[2]
  else
    return self.maxGroundSearchDistance
  end
end

--Sound and animation effects for driving, entering, etc.
function updateDriveEffects(healthFactor, driverThisFrame)
  --Do we have a driver?
  if (driverThisFrame ~= nil) then
	--If we had no driver before this tick
    if (self.driver == nil) then
	  animator.playSound("engineStart")
    end
	
	--Disable idle engine sounds as there is a driver
	animator.stopAllSounds("engineLoopIdle")
	self.idleLoopSoundPlaying = false
	
	--If it isn't playing yet, start playing the engine loop sound
	if self.loopSoundPlaying == false then
	  animator.playSound("engineLoop", -1)
	  self.loopSoundPlaying = true
	else
	  --Adjust the engine sound pitch and volume
	  animator.setSoundPitch("engineLoop", self.enginePitch, 1.5)
	  animator.setSoundVolume("engineLoop", self.engineVolume, 1.5)
	end
	
	--If we are moving and colliding, play a looping collision sound
	if mcontroller.isColliding() and vec2.mag(mcontroller.velocity()) > 1 then
	  if self.collisionLoopSoundPlaying == false then
		animator.playSound("collisionLoop", -1)
		self.collisionLoopSoundPlaying = true
	  else
		local volumeAdjustment = math.min(1.0, math.max(0.1, vec2.mag(mcontroller.velocity()) * 0.05))
		animator.setSoundVolume("collisionLoop", volumeAdjustment, 0.1)
	  end
	else
	  animator.stopAllSounds("collisionLoop")
	  self.collisionLoopSoundPlaying = false
	end
  else
	--Disable active engine sounds as there is no driver
	animator.stopAllSounds("engineLoop")
	self.loopSoundPlaying = false
	
	--Enable temporary idle engine sound after exiting the vehicle
	if self.idleEngineTimer > 0 then
	  if not self.idleLoopSoundPlaying then
		animator.playSound("engineLoopIdle", -1)
		self.idleLoopSoundPlaying = true
	  end
	else
	  animator.stopAllSounds("engineLoopIdle")
	  self.idleLoopSoundPlaying = false
	end
  end
  
  --If we are at critical health, loop a warning sound
  if healthFactor <= self.warningHealthFactor and self.warningSoundIsPlaying == false then
	animator.playSound("warning", -1)
	self.warningSoundIsPlaying = true
  elseif healthFactor > self.warningHealthFactor and self.warningSoundIsPlaying == true then
	animator.stopAllSounds("warning")
	self.warningSoundIsPlaying = false
  end
end

--Call this function to make the driver and passengers start playing their damage taken emotes
function setDamageEmotes()
  self.damageEmoteTimer = config.getParameter("damageEmoteTime")
  vehicle.setLoungeEmote("drivingSeat",self.damageTakenEmote)
end

--Make the driver and passengers dance and emote according to the damage state of the vehicle
function updatePassengers(healthFactor)
  if healthFactor > 0 then
    --If the damage taken emote should be played
    if self.damageEmoteTimer > 0 then
      self.damageEmoteTimer = self.damageEmoteTimer - script.updateDt()
	  vehicle.setLoungeEmote("drivingSeat",self.damageTakenEmote)
    --Set emote state based on vehicle health factor
	else
	  if healthFactor > 0.5 then
        vehicle.setLoungeEmote("drivingSeat",self.driverEmote)
	  elseif healthFactor < 0.25 then
	    vehicle.setLoungeEmote("drivingSeat",self.driverEmoteNearDeath)
	  elseif healthFactor < 0.5 then
	    vehicle.setLoungeEmote("drivingSeat",self.driverEmoteDamaged)
	  else
	    --Failsafe
	    vehicle.setLoungeEmote("drivingSeat",self.driverEmote)
	  end
    end
  end
end

--Headlight activation and deactivation
function switchHeadLights(oldIndex, newIndex, activate)
  if (activate ~= self.headlightsOn or oldIndex ~= newIndex) then
    local listOfLists = config.getParameter("lightsInDamageState")

    if (listOfLists ~= nil) then
      if (oldIndex ~= newIndex) then
        local listToSwitchOff = listOfLists[oldIndex]
        for i, name in ipairs(listToSwitchOff) do
          animator.setLightActive(name, false)
        end
      end

        local listToSwitchOn = listOfLists[newIndex]
        for i, name in ipairs(listToSwitchOn) do
        animator.setLightActive(name, activate)
      end
    end
    self.headlightsOn = activate

    if (self.headlightsOn) then
      animator.setAnimationState("headlights", "on")
    else
      animator.setAnimationState("headlights", "off")
    end
  end
end

--============================================================================================================
--============================================== HEALTH AND DAMAGE ===========================================
--============================================================================================================

--Call this function to apply damage to the vehicle
function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" then
    if self.isSprinting then
	  damage = damage + root.evalFunction2("protection", damageRequest.damage, self.sprintProtection) --Optional change to damage resistance while sprinting
	else
	  damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
	end
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  else
    return {}
  end

  --Update the damage effects
  updateDamage(damage, self.headlightsOn)
  
  --Burst the damage particle effects and play hurt noise, but only if the damageRequest actually deals damage
  if damage > 0 then
	--Set the driver's emote to the damage emote
    setDamageEmotes()
  end
  
  --Reduce health by damage amount
  local healthLost = math.min(damage, storage.health)
  storage.health = storage.health - healthLost

  --Send the damage notification back to the damage dealer so they can register the hit
  --This should also create the floating damage numbers
  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damage,
    healthLost = healthLost,
    hitType = "Hit",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = self.materialKind,
    killed = storage.health <= 0
  }}
end

--This function can be called elsewhere to apply damage caused by the vehicle itself
function selfDamageNotifications()
  local sdn = self.selfDamageNotifications
  self.selfDamageNotifications = {}
  return sdn
end

--Update damage effects, handle death and collision damage
function updateDamage(damage, headlights)
  local maxDamageState = #self.damageStateNames
  local prevHealthFactor = storage.health / self.maxHealth

  --Calculate updated health factor
  local newHealthFactor = (storage.health - damage) / self.maxHealth

  --Work out what damage state we are in before damage occurs
  local previousDamageStateIndex = maxDamageState
  if prevHealthFactor > 0 then
    previousDamageStateIndex = (maxDamageState - math.ceil(prevHealthFactor * maxDamageState))+1
  end
  --Now the damage state after damage occurs
  local damageStateIndex = maxDamageState
  if newHealthFactor > 0 then
    damageStateIndex = (maxDamageState - math.ceil(newHealthFactor * maxDamageState))+1
  end

  --If we've changed damage state perform some animation and/or effects
  if (damageStateIndex > previousDamageStateIndex) then
    animator.burstParticleEmitter("damageShards")
    animator.playSound("changeDamageState")
  end
  
  --Updated the global damage tag, which changes the vehicle's visual appearance
  animator.setGlobalTag("damageState", self.damageStateNames[damageStateIndex])
  
  --Set the damage particle emitters
  if newHealthFactor < self.smokeHealthFactor then
	animator.setParticleEmitterActive("smoke", true)
  else
	animator.setParticleEmitterActive("smoke", false)
  end
  if newHealthFactor < self.fireHealthFactor then
	animator.setParticleEmitterActive("fire", true)
  else
	animator.setParticleEmitterActive("fire", false)
  end
  
  --Update headlight state
  switchHeadLights(previousDamageStateIndex, damageStateIndex, headlights)
  
  --If at zero health, destroy the vehicle
  if storage.health <= 0 then
    animator.burstParticleEmitter("damageShards")
    animator.burstParticleEmitter("wreckShards")
    animator.burstParticleEmitter("wreck")
    animator.playSound("explode")

    local projectileConfig = {
      damageTeam = { type = "indiscriminate" },
      power = config.getParameter("explosionDamage"),
      onlyHitTerrain = false,
      timeToLive = 0,
      actionOnReap = {
        {
          action = "config",
          file =  config.getParameter("explosionConfig")
        }
      }
    }
    world.spawnProjectile("invisibleprojectile", mcontroller.position(), 0, {0, 0}, false, projectileConfig)
	
    vehicle.destroy()
  end

  --Track velocity changes and perform actions on collide
  local newPosition = mcontroller.position()
  local newVelocity = vec2.div(vec2.sub(newPosition, self.lastPosition), script.updateDt())
  self.lastPosition = newPosition

  if mcontroller.isColliding() then
    function findMaxAccel(trackedVelocities)
      local maxAccel = 0
      for _, v in ipairs(trackedVelocities) do
        local accel = vec2.mag(vec2.sub(newVelocity, v))
        if accel > maxAccel then
          maxAccel = accel
        end
      end
      return maxAccel
    end

    if findMaxAccel(self.collisionDamageTrackingVelocities) >= self.minDamageCollisionAccel and not self.nullifyImpactDamage then
      animator.playSound("collisionDamage")
      setDamageEmotes()

      storage.health = storage.health - self.terrainCollisionDamage
      self.collisionDamageTrackingVelocities = {}
      self.collisionNotificationTrackingVelocities = {}

      table.insert(self.selfDamageNotifications, {
        sourceEntityId = entity.id(),
        targetEntityId = entity.id(),
        position = mcontroller.position(),
        damageDealt = self.terrainCollisionDamage,
        healthLost = self.terrainCollisionDamage,
        hitType = "Hit",
        damageSourceKind = self.terrainCollisionDamageSourceKind,
        targetMaterialKind = self.materialKind,
        killed = storage.health <= 0
      })
    end

    if findMaxAccel(self.collisionNotificationTrackingVelocities) >= self.minNotificationCollisionAccel then
      animator.playSound("collisionNotification")
      self.collisionNotificationTrackingVelocities = {}
    end
  end

  function appendTrackingVelocity(trackedVelocities, newVelocity)
    table.insert(trackedVelocities, newVelocity)
    while #trackedVelocities > self.accelerationTrackingCount do
      table.remove(trackedVelocities, 1)
    end
  end

  appendTrackingVelocity(self.collisionDamageTrackingVelocities, newVelocity)
  appendTrackingVelocity(self.collisionNotificationTrackingVelocities, newVelocity)
end
