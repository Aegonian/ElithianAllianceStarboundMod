require("/scripts/vec2.lua")
require("/vehicles/thea-vehicletheft.lua")

--============================================================================================================
--============================================== INITIALIZATION ==============================================
--============================================================================================================

function init()
  --CONFIG FILE SETTINGS
  --Rotation settings
  self.levelApproachFactor = config.getParameter("levelApproachFactor")				--Speed at which to rotate to a level position
  self.spaceLevelApproachFactor = config.getParameter("spaceLevelApproachFactor")	--Speed at which to rotate to a level position when in zero-G
  self.angleApproachFactor = config.getParameter("angleApproachFactor")				--Speed at which to rotate based on terrain or control input
  --Hover settings
  self.maxGroundSearchDistance = config.getParameter("maxGroundSearchDistance")	--Max distance to check for the ground
  self.maxLiquidSearchDistance = config.getParameter("maxLiquidSearchDistance")	--Max distance to check for liquids. If closer than ground distance, rotation levels out
  self.maxAngle = config.getParameter("maxAngle") * math.pi / 180				--Maximum angle to rotate the vehicle to
  self.hoverTargetDistance = config.getParameter("hoverTargetDistance")			--Distance from the ground at which the vehicle will attempt to hover
  self.hoverVelocityFactor = config.getParameter("hoverVelocityFactor")			--Speed at which to push the vehicle up when hovering
  self.hoverControlForce = config.getParameter("hoverControlForce")				--How strongly the vehicle's hover distance is maintained
  --Speed settings
  self.targetHorizontalVelocity = config.getParameter("targetHorizontalVelocity")	--Horizontal movement speed of the vehicle
  self.horizontalControlForce = config.getParameter("horizontalControlForce")		--Acceleration of the vehicle's horizontal movement
  --Jump settings
  self.nearGroundDistance = config.getParameter("nearGroundDistance")			--Max distance from the ground from which jumping is enabled
  self.jumpVelocity = config.getParameter("jumpVelocity")						--Velocity on the Y axis of the vehicle's jump function
  self.jumpVelocityZeroG = config.getParameter("jumpVelocityZeroG")				--Velocity on the Y axis of the vehicle's jump function while in zero-G
  self.jumpTimeout = config.getParameter("jumpTimeout")							--Time between jumps
  self.jumpTimeoutZeroG = config.getParameter("jumpTimeoutZeroG")				--Time between jumps while in zero-G
  --Ground check positions settings
  self.backSpringPositions = config.getParameter("backSpringPositions")			--Back ground check positions
  self.frontSpringPositions = config.getParameter("frontSpringPositions")		--Front ground check positions
  self.bodySpringPositions = config.getParameter("bodySpringPositions")			--Middle ground check positions
  --Movement settings for controlling friction and platform detection
  self.movementSettings = config.getParameter("movementSettings")							--Movement settings when unoccupied
  self.occupiedMovementSettings = config.getParameter("occupiedMovementSettings")			--Movement settings when occupied
  self.occupiedMovementSettingsZeroG = config.getParameter("occupiedMovementSettingsZeroG")	--Movement settings when occupied and in zero-G
  --Health settings
  self.protection = config.getParameter("protection")	
  self.maxHealth = config.getParameter("maxHealth")
  --Collision settings
  self.minDamageCollisionAccel = config.getParameter("minDamageCollisionAccel")						--Minimum speed at which collisions deal crash damage 
  self.minNotificationCollisionAccel = config.getParameter("minNotificationCollisionAccel")			--Minimum speed at which collisions make a crash sound
  self.terrainCollisionDamage = config.getParameter("terrainCollisionDamage")						--Damage from high-speed collisions
  self.materialKind = config.getParameter("materialKind")											--The materialKind of the vehicle, for determining damage sound types
  self.terrainCollisionDamageSourceKind = config.getParameter("terrainCollisionDamageSourceKind")	--The damageKind used for collision damage
  self.accelerationTrackingCount = config.getParameter("accelerationTrackingCount")					--How many velocities to track for collision detection
  --Liquid behaviour settings
  self.maxLiquidImmersion = config.getParameter("maxLiquidImmersion")			--Maximum immersion before zero-G controls activate and the vehicle starts sinking
  self.liquidForceMultiplier = config.getParameter("liquidForceMultiplier")		--Force multiplier while underwater, to counter liquid movement resistance
  --Damage visuals and sounds
  self.damageStateNames = config.getParameter("damageStateNames")						--The configured names for the vehicle's damage states
  self.damageStateDriverEmotes = config.getParameter("damageStateDriverEmotes")			--The emotes the driver should plat for every damage state
  self.smokeThreshold =  config.getParameter("smokeParticleHealthThreshold")			--Health threshold before the vehicle starts emitting smoke
  self.fireThreshold =  config.getParameter("fireParticleHealthThreshold")				--Health threshold before the vehicle starts emitting small flames
  self.maxSmokeRate = config.getParameter("smokeRateAtZeroHealth")						--Absolute max emission rate for smoke
  self.maxFireRate = config.getParameter("fireRateAtZeroHealth")						--Absolute max emission rate for flames
  self.onFireThreshold =  config.getParameter("onFireHealthThreshold")					--Health threshold before the vehicle start burning
  self.damagePerSecondWhenOnFire =  config.getParameter("damagePerSecondWhenOnFire")	--Damage per second while the vehicle is burning
  self.engineDamageSoundThreshold =  config.getParameter("engineDamageSoundThreshold")	--Health threshold before the engine sounds change to a damaged variant
  self.intermittentDamageSoundThreshold = config.getParameter("intermittentDamageSoundThreshold")	--Health threshold before the engine starts making damage noises
  self.maxDamageSoundInterval = config.getParameter("maxDamageSoundInterval")			--Max time in between damage sounds
  self.minDamageSoundInterval = config.getParameter("minDamageSoundInterval")			--Min time in between damage sounds
  --Damage taken emotes
  self.damageTakenEmote = config.getParameter("damageTakenEmote")	--The emote to play upon taking damage
  self.damageEmoteTime = config.getParameter("damageEmoteTime")	--The emote to play upon taking damage
  --Engine sounds
  self.engineIdlePitch = config.getParameter("engineIdlePitch")		--Engine pitch while idle
  self.engineRevPitch = config.getParameter("engineRevPitch")		--Engine pitch while driving
  self.engineIdleVolume = config.getParameter("engineIdleVolume")	--Engine volume while idle
  self.engineRevVolume = config.getParameter("engineRevVolume")		--Engine volume while driving
  --Ability control types
  self.primaryControlType = config.getParameter("primaryControlType", "none")	--Which ability to activate when holding primaryFire
  self.altControlType = config.getParameter("altControlType", "none")			--Which ability to activate when holding altFire
  
  --STARTING STATS
  --Misc
  self.allowLiquidHover = false
  self.gateEffect = nil
  self.previousGateEffect = nil
  self.gateEffectTimer = 0
  self.zeroG = false
  self.worldBottomDeathLevel = 5
  self.driver = nil
  --Sounds
  self.loopPlaying = nil
  self.enginePitch = self.engineRevPitch
  self.engineVolume = self.engineIdleVolume
  --Vehicle animations and rotations
  self.facingDirection = config.getParameter("facingDirection") or 1 --Allow the spawner to set the starting facing direction
  self.angle = 0
  --Ability cooldowns
  self.jumpTimer = 0
  self.headlightCanToggle = true
  self.headlightsOn = false
  --Engine and horn sounds
  self.hornPlaying = false
  self.engineRevTimer = 0
  self.revEngine = false
  --Damage sound and emote timers
  self.damageSoundTimer = 0
  self.damageEmoteTimer = 0
  --Collision tracking
  self.lastPosition = mcontroller.position()
  self.collisionDamageTrackingVelocities = {}
  self.collisionNotificationTrackingVelocities = {}
  self.selfDamageNotifications = {}

  --STARTING ANIMATIONS
  animator.setGlobalTag("rearThrusterFrame", 1)
  animator.setGlobalTag("bottomThrusterFrame", 1)
  animator.setAnimationState("rearThruster", "off")
  animator.setAnimationState("bottomThruster", "off")
  if self.primaryControlType == "headLights" then
	animator.setAnimationState("headlights", "off")
  end
  
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
    animator.setAnimationState("movement", "idle")     
  else
    local startHealthFactor = config.getParameter("startHealthFactor")

    if (startHealthFactor == nil) then
        storage.health = self.maxHealth
    else
       storage.health = math.min(startHealthFactor * self.maxHealth, self.maxHealth)
    end    
    animator.setAnimationState("movement", "warpInPart1")  
  end

  --STORAGE
  --Setting up the vehicle controller storage functionality  
  message.setHandler("store",
	function(_, _, ownerKey)
	  if (self.ownerKey and self.ownerKey == ownerKey and self.driver == nil and animator.animationState("movement")=="idle") then
		animator.setAnimationState("movement", "warpOutPart1")
		switchHeadLights(1,1,false)
		animator.playSound("returnvehicle")
		return {storable = true, healthFactor = storage.health / self.maxHealth}
	  else
		return {storable = false, healthFactor = storage.health / self.maxHealth}
	  end
	end)

  --Setting the vehicle's initial visual effects
  updateVisualEffects(storage.health, 0, false)
end

--============================================================================================================
--============================================== UPDATE ======================================================
--============================================================================================================
function update()
  --Kill the vehicle if it falls to the bottom of the map
  if mcontroller.position()[2] < self.worldBottomDeathLevel and not mcontroller.zeroG() then
    vehicle.destroy()
    return
  end
  
  --Kill the vehicle if the animation is set to invisible (after being collected into a controller)
  if (animator.animationState("movement")=="invisible") then
    vehicle.destroy()
  --Lock the vehicle in place while it is being collected or while it's being spawned
  elseif (animator.animationState("movement")=="warpInPart1" or animator.animationState("movement")=="warpOutPart2") then
    mcontroller.setPosition(self.lastPosition)
    mcontroller.setVelocity({0,0})
  --When not warping (i.e. idle or in use)
  else
    local driverThisFrame = vehicle.entityLoungingIn("drivingSeat")

	--Code for detecting vehicle theft
	if not self.ownerKey and driverThisFrame and not self.driver then
	  local licenseItem = config.getParameter("licenseItem")
	  broadcastTheft(driverThisFrame, licenseItem)
	end
	
	--Prevent enemies from damaging the vehicle when it's unoccupied
    if (driverThisFrame ~= nil) then
      vehicle.setDamageTeam(world.entityDamageTeam(driverThisFrame))
    else
      vehicle.setDamageTeam({type = "passive"})
    end

	--Calculate health factor
    local healthFactor = storage.health / self.maxHealth

	--Run through all basic functions every update tick
    move()
    controls()
    animate()
    updateDamage()
    updateDriveEffects(healthFactor, driverThisFrame)
    updatePassengers(healthFactor)

    self.driver = driverThisFrame
  end
  
  --DEBUG VALUES
  --world.debugText(storage.health, mcontroller.position(), "red")
  --world.debugText(self.damageEmoteTimer, mcontroller.position(), "red")
  --world.debugText(mcontroller.liquidPercentage(), mcontroller.position(), "red")
  --world.debugText(math.floor(mcontroller.xVelocity()), mcontroller.position(), "red")
  --world.debugText(sb.printJson(self.allowLiquidHover), mcontroller.position(), "red")
end

--============================================================================================================
--============================================== PLAYER CONTROL ==============================================
--============================================================================================================

--Handling player control input for non-movement functionality
function controls()
  --PRIMARY FIRE FUNCTIONALITY
  --Headlight control
  if (vehicle.controlHeld("drivingSeat","PrimaryFire")) and self.primaryControlType == "headLights" then
    if (self.headlightCanToggle) then
      updateVisualEffects(storage.health, 0, (not self.headlightsOn))
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

  --ALT FIRE FUNCTIONALITY
  --Horn sound control
  if vehicle.controlHeld("drivingSeat","AltFire") and not self.hornPlaying and self.altControlType == "hornSound" then
    if (self.hornPlaying == false) then
      animator.stopAllSounds("horn")
      animator.playSound("horn")
      self.hornPlaying = true
    end
  elseif not vehicle.controlHeld("drivingSeat","AltFire") then
    self.hornPlaying = false
  end
end

--Functionality for turning on and off the vehicle's headlights
function switchHeadLights(oldIndex,newIndex,activate)
  if (activate ~= self.headlightsOn or oldIndex ~= newIndex) then
    local listOfLists = config.getParameter("lightsInDamageState")

    if (listOfLists ~= nil) then
      if (oldIndex ~= newIndex) then
        local listToSwitchOff = listOfLists[oldIndex]
        for i, name in ipairs(listToSwitchOff) do
          animator.setLightActive(name,false)
        end
      end

        local listToSwitchOn = listOfLists[newIndex]
        for i, name in ipairs(listToSwitchOn) do
        animator.setLightActive(name,activate)
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

--Handling player control input for movement functionality
function move()
  local groundDistance = minimumSpringDistance(self.bodySpringPositions)
  local nearGround = groundDistance < self.nearGroundDistance

  self.enginePitch = self.engineIdlePitch
  self.engineVolume = self.engineIdleVolume

  --Reset the vehicle's movement parameters to start fresh on every frame
  mcontroller.resetParameters(self.movementSettings)
  
  --ZERO-G DIRECTIONAL MOVEMENT SET-UP
  local directionVector = vec2.rotate({3 * self.facingDirection, 0}, self.angle)
  if mcontroller.zeroG() or mcontroller.liquidPercentage() > self.maxLiquidImmersion then
	world.debugLine(mcontroller.position(), vec2.add(mcontroller.position(), directionVector), "green")
	world.debugPoint(vec2.add(mcontroller.position(), directionVector), "green")
	self.zeroG = true
  else
	self.zeroG = false
  end
  
  --RACING GATE INTERACTION SET-UP
  --Check what (meta)material the tile at the vehicle's position consists of
  local materialAt = world.material(mcontroller.position(), "foreground")
  --Slow-down gate functionality
  if materialAt == "metamaterial:theaRacingGateFast" then
	self.gateEffect = "fast"
	self.gateEffectTimer = 0.5
  elseif materialAt == "metamaterial:theaRacingGateSlow" then
	self.gateEffect = "slow"
	self.gateEffectTimer = 0.5
  end
  
  --Apply any active gate effects
  local speedMultiplier = 1
  --SPEED UP GATE EFFECT
  if self.gateEffect == "fast" then
	speedMultiplier = 2
	--Tilt the vehicle upwards slightly, but not when in zero-G mode
	if self.facingDirection == 1 and not self.zeroG then
	  self.angle = 0.25
	elseif not self.zeroG then
	  self.angle = -0.25
	end
	--If this effect was just activated, play the associated sound effect
	if self.previousGateEffect ~= self.gateEffect then
	  animator.playSound("gateEffect_speedUp")
	  self.revEngine = true --Rev the engine so that the ventral thruster activates
	  self.engineRevTimer = 0.5
	end
	
  --SLOW DOWN GATE EFFECT
  elseif self.gateEffect == "slow" then
	--Slow down the vehicle if it is moving faster than the allowed max speed
	if mcontroller.xVelocity() > 3 then
	  mcontroller.setXVelocity(3)
	elseif mcontroller.xVelocity() < -3 then
	  mcontroller.setXVelocity(-3)
	end
	--Tilt the vehicle downwards slightly, but not when in zero-G mode
	if self.facingDirection == 1 and not self.zeroG then
	  self.angle = -0.25
	elseif not self.zeroG then
	  self.angle = 0.25
	end
	--If this effect was just activated, play the associated sound effect
	if self.previousGateEffect ~= self.gateEffect then
	  animator.playSound("gateEffect_slowDown")
	end
	
  --NO GATE EFFECT
  else
	speedMultiplier = 1
  end
  
  --While a gate effect is active, count down the timer
  if self.gateEffectTimer > 0 then
	self.gateEffectTimer = math.max(0, (self.gateEffectTimer - script.updateDt()))
  --If the gate effect timer has run out, reset all effects
  else
	self.gateEffect = nil
  end
  self.previousGateEffect = self.gateEffect
  --world.debugText(sb.printJson(materialAt), vec2.add(mcontroller.position(), {0,3}), "red")
  --world.debugText(sb.printJson(self.gateEffect), vec2.add(mcontroller.position(), {0,2}), "red")
  --world.debugText(self.gateEffectTimer, vec2.add(mcontroller.position(), {0,1}), "red")
  
  --LIQUID HOVER CONTROL SET-UP
  --If holding down the "down" button, disallow hovering over liquids (making the vehicle sink when above a liquid)
  if vehicle.controlHeld("drivingSeat", "down") or mcontroller.liquidPercentage() > self.maxLiquidImmersion or not self.driver then
	self.allowLiquidHover = false
  else
	self.allowLiquidHover = true
  end
  
  --While we have a driver, hover above the ground or above a liquid surface
  if self.driver then
    if mcontroller.zeroG() then
	  mcontroller.applyParameters(self.occupiedMovementSettingsZeroG)
	  self.maxAngle = config.getParameter("maxAngleZeroG") * math.pi / 180
	else
	  mcontroller.applyParameters(self.occupiedMovementSettings)
	  self.maxAngle = config.getParameter("maxAngle") * math.pi / 180
	end
	
	--If too close to the ground, push the vehicle up
	if groundDistance <= self.hoverTargetDistance then
      mcontroller.approachYVelocity((self.hoverTargetDistance - groundDistance) * self.hoverVelocityFactor, self.hoverControlForce)
    end
  end
  
  --ROTATIONAL MOVEMENT CONTROL
  --Rotate the vehicle to face upwards when "up" is held
  if vehicle.controlHeld("drivingSeat", "up") then
    local targetAngle = (self.facingDirection < 0) and -self.maxAngle or self.maxAngle
    self.angle = self.angle + (targetAngle - self.angle) * self.angleApproachFactor

    self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume
	self.revEngine = true --Rev the engine so that the ventral thruster activates
	self.engineRevTimer = 0.2

  --Rotate the vehicle to face downwards when "down" is held
  elseif vehicle.controlHeld("drivingSeat", "down") then
    local targetAngle = (self.facingDirection < 0) and self.maxAngle or -self.maxAngle
    self.angle = self.angle + (targetAngle - self.angle) * self.angleApproachFactor
  
  --If not manually controlling the rotation, rotate vehicle automatically
  else
    local frontSpringDistance = minimumSpringDistance(self.frontSpringPositions)
    local backSpringDistance = minimumSpringDistance(self.backSpringPositions)
    --If no ground points are detecting below the vehicle, rotate to a level position
	if frontSpringDistance == self.maxGroundSearchDistance and backSpringDistance == self.maxGroundSearchDistance then
      if self.zeroG then
		self.angle = self.angle - self.angle * self.spaceLevelApproachFactor
	  else
		self.angle = self.angle - self.angle * self.angleApproachFactor
	  end
    --If a ground point was detected, rotate based on terrain
	else
      self.angle = self.angle + math.atan((backSpringDistance - frontSpringDistance) * self.levelApproachFactor)
      self.angle = math.min(math.max(self.angle, -self.maxAngle), self.maxAngle)
    end
  end
  
  --LIQUID MOVEMENT MULTIPLIER
  --If submerged in liquid and manually controlling rotation, increase liquid movement force to counter liquid movement resistance
  local liquidMultiplier = 1
  if mcontroller.liquidPercentage() > self.maxLiquidImmersion then
	liquidMultiplier = self.liquidForceMultiplier
  end
  
  --DIRECTIONAL MOVEMENT CONTROL
  --Directional movement while in a gravity-affected region
  if vehicle.controlHeld("drivingSeat", "left") and not self.zeroG then
    mcontroller.approachXVelocity(-self.targetHorizontalVelocity, self.horizontalControlForce * speedMultiplier)

    self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume

    self.facingDirection = -1
  elseif vehicle.controlHeld("drivingSeat", "right") and not self.zeroG then
    mcontroller.approachXVelocity(self.targetHorizontalVelocity, self.horizontalControlForce * speedMultiplier)

    self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume

	self.facingDirection = 1
  --Directional movement while in a zero-G environment
  elseif vehicle.controlHeld("drivingSeat", "left") and self.zeroG then
    mcontroller.approachVelocityAlongAngle(self.angle, -self.targetHorizontalVelocity, self.horizontalControlForce * liquidMultiplier * speedMultiplier)

    self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume

    self.facingDirection = -1
  elseif vehicle.controlHeld("drivingSeat", "right") and self.zeroG then
    mcontroller.approachVelocityAlongAngle(self.angle, self.targetHorizontalVelocity, self.horizontalControlForce * liquidMultiplier * speedMultiplier)

    self.enginePitch = self.engineRevPitch
    self.engineVolume = self.engineRevVolume

	self.facingDirection = 1
  end

  --JUMP MOVEMENT CONTROL
  if nearGround or self.zeroG then
    if self.jumpTimer <= 0 and vehicle.controlHeld("drivingSeat", "jump") then
      if self.zeroG then
		mcontroller.setYVelocity(self.jumpVelocityZeroG)
      self.jumpTimer = self.jumpTimeoutZeroG
	  else
		mcontroller.setYVelocity(self.jumpVelocity)
      self.jumpTimer = self.jumpTimeout
	  end
      self.revEngine = true --Rev the engine so that the ventral thruster activates
	  self.engineRevTimer = 0.35
    else
      self.jumpTimer = self.jumpTimer - script.updateDt()
    end
  else
    self.jumpTimer = self.jumpTimeout
  end
end

--============================================================================================================
--============================================== ANIMATION ===================================================
--============================================================================================================

--Flipping the vehicle sprites based on our facing direction, and rotating based on the final calculated angle
function animate()
  animator.resetTransformationGroup("flip")
  if self.facingDirection < 0 then
    animator.scaleTransformationGroup("flip", {-1, 1})
  end

  --Rotate the movementController's hitbox
  mcontroller.setRotation(self.angle)
  --Rotate the vehicle's sprites
  animator.resetTransformationGroup("rotation")
  animator.rotateTransformationGroup("rotation", self.angle)
end

--Helper function for calculating spring distance from ground, used to calculate vehicle's target rotation
--Checks for line tile collision from every point, and return the shortest distance
function minimumSpringDistance(points)
  local minDistance = nil
  for _, point in ipairs(points) do
    point = vec2.rotate(point, self.angle)
    point = vec2.add(point, mcontroller.position())
    local distance = distanceToGround(point)
    if minDistance == nil or distance < minDistance then
      minDistance = distance
    end
  end
  return minDistance
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
  
  --If hovering over liquids is enabled, check ground distance against liquid distance
  if self.allowLiquidHover then
	local liquidDistance = distanceToLiquid(point)
	if distance > liquidDistance then
	  distance = liquidDistance
	end
  end
  
  return distance
end

--Helper function for calculating distance from liquids
function distanceToLiquid(point)
  local startPoint = vec2.add(mcontroller.position(), {0, -self.maxGroundSearchDistance})
  if point then
	startPoint = point
  end
  local endPoint = vec2.add(startPoint, {0, -self.maxGroundSearchDistance})
  local liquidPointsAndLevels = world.liquidAlongLine(startPoint, endPoint)
  local minDistance = nil
  
  for _, liquidPointAndLevel in ipairs(liquidPointsAndLevels) do
	local liquidPoint = liquidPointAndLevel[1]
	local liquidLevel = liquidPointAndLevel[2]
	--world.debugPoint(liquidPoint, "red")
	--To get the distance (vec2F) to the liquid surface, add the liquidLevel at the closest liquid position (vec2I) to that position's Y axis
    distanceVector = world.distance(startPoint, vec2.add(liquidPoint, {0, liquidLevel[2]}))
    distance = distanceVector[2]
    if minDistance == nil or distance < minDistance then
      minDistance = distance
    end
  end
  
  if minDistance then
	world.debugPoint(vec2.add(startPoint, {0, -minDistance}), {0, 255, 255, 255})
	return math.abs(minDistance) --Subtract 1 from the distance as tile position is in LOWER left corner
  else
	return self.maxGroundSearchDistance
  end
end

--Sound and animation effects for driving, entering, etc.
function updateDriveEffects(healthFactor, driverThisFrame)
  --Setting the engine start and loop names
  local startSoundName = "engineStart"
  local loopSoundName = "engineLoop"

  --If damaged past the appropriate health threshold, use damaged engine start and loop sounds instead
  if (healthFactor < self.engineDamageSoundThreshold) then
    startSoundName = "engineStartDamaged"
    loopSoundName = "engineLoopDamaged"
  end

  --ENGINE SOUNDS
  --If we have a driver, play engine sounds
  if driverThisFrame ~= nil then
	--If the vehicle was just entered, play the engine start sound once
    if self.driver == nil then
	  animator.playSound(startSoundName)
    end

    --If the currently playing loop sound is not the one that should be playing, stop the old sound and start looping the new sound
    if loopSoundName ~= self.loopPlaying then
	  if self.loopPlaying ~= nil then
        animator.playSound("damageIntermittent")
        animator.stopAllSounds(self.loopPlaying, 0.5)
      end
	  animator.playSound(loopSoundName, -1)
	  self.loopPlaying = loopSoundName
    end
  else
    --If there is no driver, stop any engine sound that are playing
    if self.loopPlaying ~= nil then
      animator.stopAllSounds(self.loopPlaying, 0.5)
      self.loopPlaying = nil
    end
  end

  --Reset the animation frames for thrusters
  local rearThrusterFrame = 0
  local ventralThrusterFrame = 0

  --If the engine loop sound is playing, animate the thrusters and control the engine loop sound volume and pitch
  if self.loopPlaying ~= nil then
    if (self.engineVolume == self.engineIdleVolume) then
      animator.setParticleEmitterActive("rearThrusterIdle", true)
      animator.setParticleEmitterActive("rearThrusterDrive", false)
    else
      animator.setParticleEmitterActive("rearThrusterIdle", false)
      animator.setParticleEmitterActive("rearThrusterDrive", true)
      rearThrusterFrame = 3
    end

    --If the engine is being revved, briefly animate the ventral thrusters to max
    if self.revEngine then
      animator.setSoundPitch(self.loopPlaying, self.engineRevPitch, self.engineRevTimer)
      animator.setSoundVolume(self.loopPlaying, self.engineRevVolume, self.engineRevTimer)

      animator.setParticleEmitterActive("ventralThrusterIdle", false)
      animator.setParticleEmitterActive("ventralThrusterJump", true)
      animator.burstParticleEmitter("ventralThrusterJump")
      ventralThrusterFrame = 3

      self.revEngine = false
    else
      --Continue revving the engine for a brief time after activating the revving
	  if self.engineRevTimer > 0  then
        self.engineRevTimer = math.max(0, self.engineRevTimer - script.updateDt())
        ventralThrusterFrame = 3
      --When no longer revving, revert thrusters and sounds to normal
	  else
        animator.setParticleEmitterActive("ventralThrusterIdle", true)
        animator.setParticleEmitterActive("ventralThrusterJump", false)

        animator.setSoundPitch(self.loopPlaying, self.enginePitch, 1.5)
        animator.setSoundVolume(self.loopPlaying, self.engineVolume, 1.5)
      end
    end

	--Activate the animations for the rear and bottom thrusters
    animator.setAnimationState("rearThruster", "on")
    animator.setAnimationState("bottomThruster", "on")

  --If the engine loop sound isn't playing and the engine is turned off, stop thruster animations and particle effects
  else
    animator.setParticleEmitterActive("rearThrusterIdle", false)
    animator.setParticleEmitterActive("rearThrusterDrive", false)
    animator.setParticleEmitterActive("ventralThrusterIdle", false)
    animator.setParticleEmitterActive("ventralThrusterJump", false)

    animator.setAnimationState("rearThruster", "off")
    animator.setAnimationState("bottomThruster", "off")
  end

  --If health is below the burning threshold, play burning sounds and make the vehicle jump randomly
  if (self.loopPlaying ~= nil or (self.onFireThreshold and healthFactor < self.onFireThreshold)) then
    --If the vehicle's health is below the intermittent damageSound threshold, enable timed damage bursts
    if healthFactor < self.intermittentDamageSoundThreshold then
      self.damageSoundTimer = math.max(0, self.damageSoundTimer - script.updateDt())

	  --If the damage sound timer has run out, play another damage sound and recalculate time between bursts
      if self.damageSoundTimer == 0 then
        animator.playSound("damageIntermittent")
        animator.burstParticleEmitter("damageIntermittent")

		--Set a damage emote time so no other emotes get activated for a short time
		self.damageEmoteTimer = self.damageEmoteTime
		
		--Calculate and apply a jumping bump
        local backfireMomentum = {0, self.jumpVelocity * 0.5}
        mcontroller.addMomentum(backfireMomentum)

        --Calculate a random time between burning bursts that speed up as health grows lower
        local randomMax = (healthFactor * self.maxDamageSoundInterval) + ((1.0 - healthFactor) * self.minDamageSoundInterval)
        self.damageSoundTimer = math.random() * randomMax
      end
    end
  end

  --THRUSTER ANIMATION FRAME CONTROL
  --Randomly select a rear thruster frame to play
  rearThrusterFrame = rearThrusterFrame + math.random(3)
  animator.setGlobalTag("rearThrusterFrame", rearThrusterFrame)
  
  --Randomly select a bottom thruster frame to play
  ventralThrusterFrame = ventralThrusterFrame + math.random(3)
  animator.setGlobalTag("bottomThrusterFrame", ventralThrusterFrame)
end

--Call this function to make the driver and passengers start playing their damage taken emotes
function setDamageEmotes()
  vehicle.setLoungeEmote("drivingSeat", self.damageTakenEmote)
  
  --Set a damage emote time so no other emotes get activated for a short time
  self.damageEmoteTimer = self.damageEmoteTime
end

--Make the driver and passengers dance and emote according to the damage state of the vehicle
function updatePassengers(healthFactor)
  if healthFactor > 0 then
    local damageStateIndex = maxDamageState

	--If we just took damage, prevent other emotes from activating
	if self.damageEmoteTimer > 0 then
      self.damageEmoteTimer = math.max(0, self.damageEmoteTimer - script.updateDt())
    else
      maxDamageState = #self.damageStateDriverEmotes
	  damageStateIndex = maxDamageState
	  damageStateIndex = (maxDamageState - math.ceil(healthFactor * maxDamageState)) + 1
	  vehicle.setLoungeEmote("drivingSeat", self.damageStateDriverEmotes[damageStateIndex])
    end
  end
end

--Update visual effects such as the vehicle's overall damage state and the dynamic fire/smoke particle effects
function updateVisualEffects(currentHealth, damage, headlights)
  local maxDamageState = #self.damageStateNames
  local prevHealthFactor = currentHealth / self.maxHealth
  local newHealthFactor = (currentHealth - damage) / self.maxHealth

  --Calculate what damage state the vehicle was in before taking damage
  local previousDamageStateIndex = maxDamageState
  if prevHealthFactor > 0 then
    previousDamageStateIndex = (maxDamageState - math.ceil(prevHealthFactor * maxDamageState)) + 1
  end
  --Calculate what damage state the vehicle should be in after taking damage
  local damageStateIndex = maxDamageState
  if newHealthFactor > 0 then
    damageStateIndex = (maxDamageState - math.ceil(newHealthFactor * maxDamageState)) + 1
  end

  --If the damage state has changed, burst the damage shard particles and play a damage sound
  if (damageStateIndex > previousDamageStateIndex) then
    animator.burstParticleEmitter("damageShards")
    animator.playSound("changeDamageState")
  end

  --If the vehicle has headlight controls, update the headlight now as they may turn off in some damage states
  if self.primaryControlType == "headLights" then
	switchHeadLights(previousDamageStateIndex, damageStateIndex, headlights)
  end

  --Update the animation tag to change the sprites used by the vehicle
  animator.setGlobalTag("damageState", self.damageStateNames[damageStateIndex])

  --PARTICLE EFFECT FUNCTIONALITY
  --If below the smoke threshold, activate smoke particles
  if (self.smokeThreshold > 0.0 and newHealthFactor < self.smokeThreshold) then
	local smokeFactor = 1.0 - (newHealthFactor / self.smokeThreshold)
	animator.setParticleEmitterActive("smoke", true)
	animator.setParticleEmitterEmissionRate("smoke", smokeFactor * self.maxSmokeRate)
  else
	animator.setParticleEmitterActive("smoke", false)
  end

  --If below the fire threshold, activate fire particles
  if (self.fireThreshold > 0.0 and newHealthFactor < self.fireThreshold) then
	local fireFactor = 1.0 - (newHealthFactor / self.fireThreshold)
	animator.setParticleEmitterActive("fire", true)
	animator.setParticleEmitterEmissionRate("fire", fireFactor * self.maxFireRate)
  else
	animator.setParticleEmitterActive("fire", false)
  end

  --If below the burning threshold, activate the burning animation
  if (self.onFireThreshold and newHealthFactor < self.onFireThreshold) then
	animator.setAnimationState("onFire", "on")
	animator.setParticleEmitterActive("onFire", true)
  else
	animator.setAnimationState("onFire", "off")
	animator.setParticleEmitterActive("onFire", false)
  end
end

--============================================================================================================
--============================================== HEALTH AND DAMAGE ===========================================
--============================================================================================================

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

  --Update health and damage, set damage emotes and update the vehicle's visual damage effects
  updateDamage()
  setDamageEmotes()
  updateVisualEffects(storage.health, damage, self.headlightsOn)
  
  --Calculate new vehicle health after taking damage
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

--Update vehicle health and damage, deal with death effects and handle impact damage
function updateDamage()
  --If the vehicle is burning, apply damage every second
  if animator.animationState("onFire") == "on" then
    setDamageEmotes()

    local damageThisFrame = self.damagePerSecondWhenOnFire * script.updateDt()
    updateVisualEffects(storage.health,damageThisFrame, self.headlightsOn)
    storage.health = storage.health - damageThisFrame
  end
  
  --If at zero health, destroy the vehicle
  if storage.health <= 0 then
    animator.burstParticleEmitter("damageShards")
    animator.burstParticleEmitter("wreckage")
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

  --IMPACT DAMAGE FUNCTIONALITY
  --Update the vehicle position, required for impact velocity detection
  local newPosition = mcontroller.position()
  local newVelocity = vec2.div(vec2.sub(newPosition, self.lastPosition), script.updateDt())
  self.lastPosition = newPosition

  --If the vehicle is colliding, check velocities and optionally apply damage effects
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

      updateVisualEffects(storage.health,  self.terrainCollisionDamage, self.headlightsOn)

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

  --Helper function to keep track of vehicle velocities
  function appendTrackingVelocity(trackedVelocities, newVelocity)
    table.insert(trackedVelocities, newVelocity)
    while #trackedVelocities > self.accelerationTrackingCount do
      table.remove(trackedVelocities, 1)
    end
  end

  --Update vehicle velocities
  appendTrackingVelocity(self.collisionDamageTrackingVelocities, newVelocity)
  appendTrackingVelocity(self.collisionNotificationTrackingVelocities, newVelocity)
end
