require "/scripts/vec2.lua"
require "/vehicles/thea-vehicletheft.lua"

function init()
  --CONFIG FILE SETTINGS
  --Flight settings
  self.flySpeedX = config.getParameter("flySpeedX")
  self.flySpeedY = config.getParameter("flySpeedY")
  self.flyControlForceX = config.getParameter("flyControlForceX")
  self.flyControlForceY = config.getParameter("flyControlForceY")
  self.boostSpeedMultiplier = config.getParameter("boostSpeedMultiplier")
  self.highMovementAngle = config.getParameter("highMovementAngle")
  self.mediumMovementAngle = config.getParameter("mediumMovementAngle")
  self.lowMovementAngle = config.getParameter("lowMovementAngle")
  self.movementSettings = config.getParameter("movementSettings")
  self.occupiedMovementSettings = config.getParameter("occupiedMovementSettings")
  --Liquid settings
  self.maxLiquidImmersion = config.getParameter("maxLiquidImmersion")
  self.liquidBuoyancy = config.getParameter("liquidBuoyancy")
  --Rotation settings
  self.levelApproachFactor = config.getParameter("levelApproachFactor")
  self.angleApproachFactor = config.getParameter("angleApproachFactor")
  --Health settings
  self.protection = config.getParameter("protection")
  self.maxHealth = config.getParameter("maxHealth")
  self.materialKind = config.getParameter("materialKind")
  self.sparksHealthFactor = config.getParameter("sparksHealthFactor")
  self.fireHealthFactor = config.getParameter("fireHealthFactor")
  self.warningHealthFactor = config.getParameter("warningHealthFactor")
  --Weaponry settings
  self.aimLimitHigh = config.getParameter("aimLimitHigh") * math.pi / 180
  self.aimLimitLow = config.getParameter("aimLimitLow") * math.pi / 180
  self.idleAimAngle = config.getParameter("idleAimAngle") * math.pi / 180
  self.warpAimAngle = config.getParameter("warpAimAngle") * math.pi / 180
  self.aimOffset = config.getParameter("aimOffset")
  self.fireTime = config.getParameter("fireTime")
  self.fireProjectile = config.getParameter("fireProjectile")
  self.fireProjectileConfig = config.getParameter("fireProjectileConfig")
  self.fireInaccuracy = config.getParameter("fireInaccuracy")
  --Sound effects
  self.engineIdlePitch = config.getParameter("engineIdlePitch")
  self.engineRevPitch = config.getParameter("engineRevPitch")
  self.engineBoostPitch = config.getParameter("engineBoostPitch")
  self.engineIdleVolume = config.getParameter("engineIdleVolume")
  self.engineRevVolume = config.getParameter("engineRevVolume")
  self.engineBoostVolume = config.getParameter("engineBoostVolume")
  --Collision settings
  self.minDamageCollisionAccel = config.getParameter("minDamageCollisionAccel")
  self.minNotificationCollisionAccel = config.getParameter("minNotificationCollisionAccel")
  self.terrainCollisionDamage = config.getParameter("terrainCollisionDamage")
  self.terrainCollisionDamageSourceKind = config.getParameter("terrainCollisionDamageSourceKind")
  self.accelerationTrackingCount = config.getParameter("accelerationTrackingCount")

  --Starting stats
  self.driver = nil
  self.facingDirection = config.getParameter("facingDirection") or 1 --Allow the spawner to set the starting facing direction
  self.lastPosition = mcontroller.position()
  self.lastXVelocity = mcontroller.xVelocity()
  self.angle = 0
  self.fireTimer = self.fireTime
  self.targetEngineAngle = "forward"
  self.warningSoundIsPlaying = false
  self.selfDamageNotifications = {}
  self.collisionDamageTrackingVelocities = {}
  self.collisionNotificationTrackingVelocities = {}
  self.collisionLoopSoundPlaying = false
  self.loopSoundPlaying = false
  self.enginePitch = self.engineRevPitch
  self.engineVolume = self.engineIdleVolume
  self.warningSoundIsPlaying = false
  animator.stopAllSounds("warning")
  
  --Starting animations
  animator.setGlobalTag("thrusterFrame", 0)
  animator.setGlobalTag("balanceThrusterFrame", 0)
  animator.setAnimationState("thrusters", "forward")
  
  --Emote settings
  self.damageTakenEmote = config.getParameter("damageTakenEmote")
  self.driverEmote = config.getParameter("driverEmote")
  self.driverEmoteDamaged = config.getParameter("driverEmoteDamaged")
  self.driverEmoteNearDeath = config.getParameter("driverEmoteNearDeath")
  self.damageEmoteTimer = 0

  --Setting the unique key for linking together the vehicle and the controller
  --If there is a unique key, make the vehicle persistent
  self.ownerKey = config.getParameter("ownerKey")
  vehicle.setPersistent(self.ownerKey)
  
  --Function for making vehicles spawned from stagehands persistent
  message.setHandler("setPersistent", function(_, _)
      vehicle.setPersistent(true)
	  storage.isPersistent = true
    end)
  if storage.isPersistent then
	vehicle.setPersistent(true)
  end

  --Setting the initial health factor, and playing warp in animation
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

  --Setup the store functionality
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

function update()
  --Hide the gun and damage if the mech is hidden
  if animator.animationState("body") == "warpInPart1" or animator.animationState("body") == "warpOutPart2" then
	animator.setAnimationState("gun", "invisible")
	animator.setAnimationState("gunmuzzle", "invisible")
  --Return gun to idle states when not firing
  else
	if not animator.animationState("gunmuzzle") == "firing" then
	  animator.setAnimationState("gunmuzzle", "invisible")
	end
	animator.setAnimationState("gun", "idle")
  end
  
  --Check animation state to see if we are moving or warping
  if animator.animationState("body")=="warpInPart1"
	or animator.animationState("body")=="warpInPart2"
	or animator.animationState("body")=="warpOutPart1"
	or animator.animationState("body")=="warpOutPart2"
	or animator.animationState("body")=="invisible" then
	  self.isWarping = true
	  aim(false)
  else
    self.isWarping = false
  end
  
  --Remove vehicle if animation was set to invisible
  if (animator.animationState("body")=="invisible") then
    vehicle.destroy()
  elseif self.isWarping then
	--Lock the vehicle in place while warping
    mcontroller.setPosition(self.lastPosition)
    mcontroller.setVelocity({0,0})
	animator.setAnimationState("thrusters", "forward")
  else
	--Set the current driver
    local driverThisFrame = vehicle.entityLoungingIn("drivingSeat")
	
	--Code for detecting vehicle theft
	if not self.ownerKey and driverThisFrame and not self.driver then
	  local licenseItem = config.getParameter("licenseItem")
	  broadcastTheft(driverThisFrame, licenseItem)
	end

	--Set the vehicle's damage team based on driver presence
    if (driverThisFrame ~= nil) then
      vehicle.setDamageTeam(world.entityDamageTeam(driverThisFrame))
    else
      vehicle.setDamageTeam({type = "passive"})
    end

	--Current health factor
    local healthFactor = storage.health / self.maxHealth
	
	--Count down the firing timers
	self.fireTimer = math.max(0, self.fireTimer - script.updateDt())

	--Cycle through these functions every frame
	control(driverThisFrame)
	aim(driverThisFrame)
    setDirection(driverThisFrame)
	animate(driverThisFrame)
	updateDamage(0)
	updateDriveEffects(healthFactor, driverThisFrame)
	updatePassengers(healthFactor)

    self.driver = driverThisFrame
  end
  
  self.lastPosition = mcontroller.position()
  
  --world.debugText(math.ceil(storage.health) .. "/" .. self.maxHealth, mcontroller.position(), "green")
  --world.debugText(storage.health / self.maxHealth, vec2.add(mcontroller.position(), {0, -1}), "green")
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
  
  --MOVING LEFT
  if vehicle.controlHeld("drivingSeat", "left") then
	mcontroller.approachXVelocity(-self.flySpeedX, self.flyControlForceX)
	
	--Rotation
	if vehicle.controlHeld("drivingSeat", "up") then
	  self.angle = self.angle + (self.lowMovementAngle - self.angle) * self.angleApproachFactor
	elseif vehicle.controlHeld("drivingSeat", "down") then
	  self.angle = self.angle + (self.highMovementAngle - self.angle) * self.angleApproachFactor
	else
	  self.angle = self.angle + (self.mediumMovementAngle - self.angle) * self.angleApproachFactor
	end
	
	self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume
  end
  
  --MOVING RIGHT
  if vehicle.controlHeld("drivingSeat", "right") then
	mcontroller.approachXVelocity(self.flySpeedX, self.flyControlForceX)
	
	--Rotation
	if vehicle.controlHeld("drivingSeat", "up") then
	  self.angle = self.angle + (-self.lowMovementAngle - self.angle) * self.angleApproachFactor
	elseif vehicle.controlHeld("drivingSeat", "down") then
	  self.angle = self.angle + (-self.highMovementAngle - self.angle) * self.angleApproachFactor
	else
	  self.angle = self.angle + (-self.mediumMovementAngle - self.angle) * self.angleApproachFactor
	end
	
	self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume
  end
  
  --MOVING DOWN
  if vehicle.controlHeld("drivingSeat", "down") then
	mcontroller.approachYVelocity(-self.flySpeedY, self.flyControlForceY)
  end
  
  --MOVING UP
  if vehicle.controlHeld("drivingSeat", "up") then
	mcontroller.approachYVelocity(self.flySpeedY, self.flyControlForceY)
	
	self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume
  end
  
  --NO MOVEMENT
  if not vehicle.controlHeld("drivingSeat", "left") and not vehicle.controlHeld("drivingSeat", "right") then
	self.angle = self.angle + (0 - self.angle) * self.angleApproachFactor
  end
  
  --BOOSTER ANGLE CONTROL
  if self.facingDirection < 0 then --Facing left
	if vehicle.controlHeld("drivingSeat", "right") or (mcontroller.xVelocity() > self.lastXVelocity and mcontroller.xVelocity() < -10) then
	  self.targetEngineAngle = "backward"
	else
	  self.targetEngineAngle = "forward"
	end
  elseif self.facingDirection > 0 then --Facing right
	if vehicle.controlHeld("drivingSeat", "left") or (mcontroller.xVelocity() < self.lastXVelocity and mcontroller.xVelocity() > 10) then
	  self.targetEngineAngle = "backward"
	else
	  self.targetEngineAngle = "forward"
	end
  end
  
  --world.debugText(self.targetEngineAngle, vec2.add(mcontroller.position(), {0,3}), "red")
  --world.debugText(math.floor(mcontroller.xVelocity() * 10) / 10, vec2.add(mcontroller.position(), {0,4}), "red")
  
  --BOOST SPEED
  if vehicle.controlHeld("drivingSeat", "jump") then
	self.flySpeedX = config.getParameter("flySpeedX") * self.boostSpeedMultiplier
	self.flySpeedY = config.getParameter("flySpeedY") * self.boostSpeedMultiplier
	self.lowMovementAngle = config.getParameter("lowMovementAngle") * self.boostSpeedMultiplier
	self.mediumMovementAngle = config.getParameter("mediumMovementAngle") * self.boostSpeedMultiplier
	self.highMovementAngle = config.getParameter("highMovementAngle") * self.boostSpeedMultiplier
	
	self.enginePitch = self.engineBoostPitch
    self.engineVolume = self.engineBoostVolume
  else
	self.flySpeedX = config.getParameter("flySpeedX")
	self.flySpeedY = config.getParameter("flySpeedY")
	self.lowMovementAngle = config.getParameter("lowMovementAngle")
	self.mediumMovementAngle = config.getParameter("mediumMovementAngle")
	self.highMovementAngle = config.getParameter("highMovementAngle")
  end
  
  --CONTROLS WHILE DRIVERLESS
  if not driverThisFrame then
	local waterLevel = mcontroller.liquidPercentage()
	
	if waterLevel > 0 and waterLevel < self.maxLiquidImmersion then
	  mcontroller.applyParameters({liquidBuoyancy = self.liquidBuoyancy})
	end
  end
  
  self.lastXVelocity = mcontroller.xVelocity()
end

--Function for aiming and firing the guns
function aim(driverThisFrame)
  --Only if we have a driver, continue on with the function
  if driverThisFrame then
    --Figure out which way to face
	local diff = world.distance(vec2.add(vehicle.aimPosition("drivingSeat"), self.aimOffset), mcontroller.position())
	self.aimAngle = math.atan(diff[2], diff[1]) - self.angle
	self.fireAngle = math.atan(diff[2], diff[1])
	local facingDirection = (self.aimAngle > math.pi / 2 or self.aimAngle < -math.pi / 2) and -1 or 1
	
	--Rotate the guns
	if self.facingDirection < 0 then --Facing left
	  if self.aimAngle > 0 then
		self.aimAngle = math.max(self.aimAngle, math.pi - self.aimLimitHigh)
		self.fireAngle = math.max(self.fireAngle, math.pi - self.aimLimitHigh)
	  else
		self.aimAngle = math.min(self.aimAngle, -math.pi + self.aimLimitLow)
		self.fireAngle = math.min(self.fireAngle, -math.pi + self.aimLimitLow)
	  end
	  animator.rotateGroup("guns", math.pi - self.aimAngle)
	else --Facing right
	  if self.aimAngle > 0 then
        self.aimAngle = math.min(self.aimAngle, self.aimLimitHigh)
        self.fireAngle = math.min(self.fireAngle, self.aimLimitHigh)
      else
        self.aimAngle = math.max(self.aimAngle, -self.aimLimitLow)
        self.fireAngle = math.max(self.fireAngle, -self.aimLimitLow)
      end	  
	  animator.rotateGroup("guns", self.aimAngle)
	end
	
	--Firing behaviour
	if vehicle.controlHeld("drivingSeat", "primaryFire") then
	  if self.fireTimer <= 0 then
		local finalFireAngle = vec2.rotate({1, 0}, self.fireAngle + sb.nrand(self.fireInaccuracy, 0))
		world.spawnProjectile(self.fireProjectile, vec2.add(mcontroller.position(), animator.partPoint("gun", "firePoint")), vehicle.entityLoungingIn("drivingSeat"), finalFireAngle, false, self.fireProjectileConfig)
		animator.setAnimationState("gunmuzzle", "firing")
		animator.playSound("fire")
		self.fireTimer = self.fireTime
	  end
	end
	
	--Debug firing positions
	local gunPosition = vec2.add(mcontroller.position(), animator.partPoint("gun", "firePoint"))
	world.debugPoint(gunPosition, "red")
	
	--Debug firing angles
	local gunAimAngle = vec2.add(gunPosition, vec2.rotate({1, 0}, self.fireAngle))
	world.debugLine(gunPosition, gunAimAngle, "red")
  else
	--Rotate the guns into their idle limits
	if self.facingDirection < 0 then
	  if self.isWarping then
		animator.rotateGroup("guns", math.pi + self.warpAimAngle)
	  else
		animator.rotateGroup("guns", math.pi + self.idleAimAngle)
	  end
	else
	  if self.isWarping then
		animator.rotateGroup("guns", math.pi + self.warpAimAngle)
	  else
		animator.rotateGroup("guns", math.pi + self.idleAimAngle)
	  end
	end
  end
end

--============================================================================================================
--============================================== ANIMATION ===================================================
--============================================================================================================

--Set the vehicle's facing direction
function setDirection(driverThisFrame)
  animator.resetTransformationGroup("flip")
  animator.setGlobalTag("direction", "default")
  if driverThisFrame then
	local diff = world.distance(vehicle.aimPosition("drivingSeat"), mcontroller.position())
	local aimAngle = math.atan(diff[2], diff[1])
	self.facingDirection = (aimAngle > math.pi / 2 or aimAngle < -math.pi / 2) and -1 or 1
  end
  if self.facingDirection < 0 then
    animator.scaleTransformationGroup("flip", {-1, 1})
	animator.setGlobalTag("direction", "flipped")
  end
end

--Rotating the vehicle based on calculated intended angle
function animate(driverThisFrame)
  if driverThisFrame then
	--Let the intended angle be calculated by flight ballistics and controls
	
	--Engine animation control
	if self.targetEngineAngle == "forward" and animator.animationState("thrusters") == "landed" then
	  animator.setAnimationState("thrusters", "retracting")
	elseif self.targetEngineAngle == "forward" and animator.animationState("thrusters") == "backward" then
	  animator.setAnimationState("thrusters", "transitionToForward")
	elseif self.targetEngineAngle == "backward" and animator.animationState("thrusters") == "forward" then
	  animator.setAnimationState("thrusters", "transitionToBackward")
	end
	
	--Thruster Animation Control
	local thrusterFrame = 0
	if vehicle.controlHeld("drivingSeat", "jump") then
	  thrusterFrame = thrusterFrame + math.random(2) + 1
	else
	  thrusterFrame = thrusterFrame + math.random(2)
	end
	animator.setGlobalTag("thrusterFrame", thrusterFrame)
	
	local balanceThrusterFrame = 0
	balanceThrusterFrame = balanceThrusterFrame + math.random(2)
	animator.setGlobalTag("balanceThrusterFrame", balanceThrusterFrame)
	animator.setAnimationState("balancer", "active")
	
	--Particle Control
	--Disable all particles
	animator.setParticleEmitterActive("thrusters-forward", false)
	animator.setParticleEmitterActive("thrusters-forward2", false)
	animator.setParticleEmitterActive("thrusters-halfForward", false)
	animator.setParticleEmitterActive("thrusters-halfForward2", false)
	animator.setParticleEmitterActive("thrusters-halfBackward", false)
	animator.setParticleEmitterActive("thrusters-halfBackward2", false)
	animator.setParticleEmitterActive("thrusters-backward", false)
	animator.setParticleEmitterActive("thrusters-backward2", false)
	--Enable applicable particles
	if animator.animationState("thrusters") == "forward" then
	  animator.setParticleEmitterActive("thrusters-forward", true)
	  animator.setParticleEmitterActive("thrusters-forward2", true)
	elseif animator.animationState("thrusters") == "transitionToForward" or animator.animationState("thrusters") == "transitionToBackward2" then
	  animator.setParticleEmitterActive("thrusters-halfForward", true)
	  animator.setParticleEmitterActive("thrusters-halfForward2", true)
	elseif animator.animationState("thrusters") == "transitionToForward2" or animator.animationState("thrusters") == "transitionToBackward" then
	  animator.setParticleEmitterActive("thrusters-halfBackward", true)
	  animator.setParticleEmitterActive("thrusters-halfBackward2", true)
	elseif animator.animationState("thrusters") == "backward" then
	  animator.setParticleEmitterActive("thrusters-backward", true)
	  animator.setParticleEmitterActive("thrusters-backward2", true)
	end
  else
	--Engine animation control
	if animator.animationState("thrusters") == "forward" then
	  animator.setAnimationState("thrusters", "transitionToBackward")
	elseif animator.animationState("thrusters") == "backward" then
	  animator.setAnimationState("thrusters", "landing")
	end
	
	--Thruster animation control
	animator.setGlobalTag("thrusterFrame", 0)
	animator.setAnimationState("balancer", "invisible")
	
	--Particle Control
	animator.setParticleEmitterActive("thrusters-forward", false)
	animator.setParticleEmitterActive("thrusters-forward2", false)
	animator.setParticleEmitterActive("thrusters-halfForward", false)
	animator.setParticleEmitterActive("thrusters-halfForward2", false)
	animator.setParticleEmitterActive("thrusters-halfBackward", false)
	animator.setParticleEmitterActive("thrusters-halfBackward2", false)
	animator.setParticleEmitterActive("thrusters-backward", false)
	animator.setParticleEmitterActive("thrusters-backward2", false)
	
	--Rotate the vehicle back to level when not occupied
	self.angle = self.angle + (0 - self.angle) * self.angleApproachFactor
  end
  
  --Setting vehicle rotation
  animator.resetTransformationGroup("rotation")
  animator.rotateTransformationGroup("rotation", self.angle)
  mcontroller.setRotation(self.angle)
end

--Sound and animation effects for driving, entering, etc.
function updateDriveEffects(healthFactor, driverThisFrame)
  --Do we have a driver?
  if (driverThisFrame ~= nil) then
	--If we had no driver before this tick
    if (self.driver == nil) then
	  animator.playSound("engineStart")
    end
	
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

--============================================================================================================
--============================================== HEALTH AND DAMAGE ===========================================
--============================================================================================================

--Call this function to make the driver and passengers start playing their damage taken emotes
function setDamageEmotes()
  self.damageEmoteTimer = config.getParameter("damageEmoteTime")
  vehicle.setLoungeEmote("drivingSeat", self.damageTakenEmote)
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

--Call this function to apply damage to the vehicle
function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" then
    damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  else
    return {}
  end

  --Update the damage effects
  updateDamage(damage)
  
  --Burst the damage particle effects and play hurt noise, but only if the damageRequest actually deals damage
  if damage > 0 then
	--Set the driver's emote to the damage emote
    setDamageEmotes()
  end
  
  local healthLost = math.min(damage, storage.health)
  storage.health = storage.health - healthLost

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

function selfDamageNotifications()
  local sdn = self.selfDamageNotifications
  self.selfDamageNotifications = {}
  return sdn
end

--Update damage effects, handle death and collision damage
function updateDamage(damage)
  local prevHealthFactor = storage.health / self.maxHealth
  local newHealthFactor = (storage.health - damage) / self.maxHealth
  
  --Set the damage particle emitters
  if newHealthFactor < self.sparksHealthFactor then
	animator.setParticleEmitterActive("sparks", true)
  else
	animator.setParticleEmitterActive("sparks", false)
  end
  if newHealthFactor < self.fireHealthFactor then
	animator.setParticleEmitterActive("fire", true)
  else
	animator.setParticleEmitterActive("fire", false)
  end
  
  --If at zero health, destroy the vehicle
  if storage.health <= 0 then
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

    if findMaxAccel(self.collisionDamageTrackingVelocities) >= self.minDamageCollisionAccel then
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
