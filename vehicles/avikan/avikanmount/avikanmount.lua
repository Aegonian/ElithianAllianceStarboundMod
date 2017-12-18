require("/scripts/vec2.lua")
require("/vehicles/thea-vehicletheft.lua")

function init()
  --Settings from config file
  self.runSpeed = config.getParameter("runSpeed")
  self.sprintSpeed = config.getParameter("sprintSpeed")
  self.swimSpeed = config.getParameter("swimSpeed")
  self.jumpVelocity = config.getParameter("jumpVelocity")
  self.jumpTimeout = config.getParameter("jumpTimeout")
  self.movementSettings = config.getParameter("movementSettings")
  self.occupiedMovementSettings = config.getParameter("occupiedMovementSettings")
  self.noPlatformMovementSettings = config.getParameter("noPlatformMovementSettings")
  self.protection = config.getParameter("protection")
  self.sprintProtection = config.getParameter("sprintProtection")
  self.maxHealth = config.getParameter("maxHealth")
  self.materialKind = config.getParameter("materialKind")
  self.swimmingUpVelocity = config.getParameter("swimmingUpVelocity")
  self.swimmingUpControlForce = config.getParameter("swimmingUpControlForce")
  self.maxFallDistance = config.getParameter("maxFallDistance")
  self.fallDamageMultiplier = config.getParameter("fallDamageMultiplier")
  self.currentFallDistance = 0
  self.lastYPosition = mcontroller.yPosition()
  
  self.worldBottomDeathLevel = 5
  
  self.bloodDripMaxRate = config.getParameter("bloodDripMaxRate")
  self.bloodDripHealthThreshold = config.getParameter("bloodDripHealthThreshold")
  
  --Starting stats
  self.groundFrames = 1
  self.startedFalling = false
  self.wasPreviouslyOnGround = false
  self.isSwimming = false
  self.fallTime = 0
  self.airTime = 0
  self.selfDamageNotifications = {}
  self.damageSoundTimeOut = config.getParameter("damageSoundTimeOut")
  self.damageSoundTimer = 0
  self.hasBeenCollected = false
  self.lastPosition = mcontroller.position()
  self.collisionDamageTrackingVelocities = {}
  self.justLanded = false
  self.landTimer = config.getParameter("landRecoveryTime")
  self.isSprinting = false

  self.driver = nil;
  self.facingDirection = config.getParameter("facingDirection") or 1 --Allow the spawner to set the starting facing direction
  self.jumpTimer = 0
  
  --Emote settings
  self.damageTakenEmote = config.getParameter("damageTakenEmote")
  self.driverEmote = config.getParameter("driverEmote")
  self.driverEmoteDamaged = config.getParameter("driverEmoteDamaged")
  self.driverEmoteNearDeath = config.getParameter("driverEmoteNearDeath")
  self.damageEmoteTimer=0.0

  --Owner Key, given to us by the vehicle controller
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

  --Assume maxhealth
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
	  if (self.ownerKey and self.ownerKey == ownerKey and self.driver == nil and animator.animationState("body")=="inactive") then
		animator.setAnimationState("body", "warpOutPart1")
		animator.playSound("returnvehicle")
		self.hasBeenCollected = true
		return {storable = true, healthFactor = storage.health / self.maxHealth}
	  elseif (self.ownerKey and self.ownerKey == ownerKey and self.driver == nil and animator.animationState("body")=="swim") then
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
  --Kill the vehicle if it falls to the bottom of the map
  if mcontroller.position()[2] < self.worldBottomDeathLevel then
    vehicle.destroy()
    return
  end

  --Remove vehicle if animation was set to invisible
  if (animator.animationState("body")=="invisible") then
    vehicle.destroy()
	world.debugText("I was destroyed! You shouldn't be seeing this...", mcontroller.position(), "yellow")
  --Freeze the vehicle when it is being collected
  elseif (animator.animationState("body")=="warpInPart1" or animator.animationState("body")=="warpOutPart2") then
    --lock it solid whilst spawning/despawning
    mcontroller.setPosition(self.lastPosition)
    mcontroller.setVelocity({0,0})
	world.debugText("I am being collected", mcontroller.position(), "yellow")
  --When not warping
  else
    local driverThisFrame = vehicle.entityLoungingIn("drivingSeat")
	
	--Code for detecting vehicle theft
	if not self.ownerKey and driverThisFrame and not self.driver then
	  local licenseItem = config.getParameter("licenseItem")
	  broadcastTheft(driverThisFrame, licenseItem)
	end

    if (driverThisFrame ~= nil) then
      vehicle.setDamageTeam(world.entityDamageTeam(driverThisFrame))
    else
      vehicle.setDamageTeam({type = "passive"})
	  if self.hasBeenCollected == false and self.isSwimming == false then
	    animator.setAnimationState("body", "inactive")
	  end
    end

    local healthFactor = storage.health / self.maxHealth

	move(driverThisFrame)
	animate()
	updateDamage()
	updateDriveEffects(driverThisFrame)

	updatePassengers(healthFactor)

    self.driver = driverThisFrame
	
	--Code for pushing enemies away while sprinting
	if animator.animationState("body") == "sprint" then
	  self.isSprinting = true
	  vehicle.setDamageSourceEnabled("bumper", true)
	else
	  self.isSprinting = false
	  vehicle.setDamageSourceEnabled("bumper", false)
	end
	
	if healthFactor < self.bloodDripHealthThreshold then
	  local bloodDripRate = 1.0 - (healthFactor / self.bloodDripHealthThreshold)
	  animator.setParticleEmitterActive("bloodDripping", true)
      animator.setParticleEmitterEmissionRate("bloodDripping", bloodDripRate * self.bloodDripMaxRate)
	  --Debug the blood drip rate
	  local debugPosition5 = vec2.add(mcontroller.position(), {0,-3.0})
	  world.debugText(bloodDripRate * self.bloodDripMaxRate, debugPosition5, "red")
	else
	  animator.setParticleEmitterActive("bloodDripping", false)
	end
	
	--Code for disabling control shortly after landing
	if self.justLanded == true then
	  self.landTimer = math.max(0, self.landTimer - script.updateDt())
	end
	if self.landTimer <= 0 then
	  self.justLanded = false
	end
	
	--Set a cooldown timer for the damage sound
    if self.damageSoundTimer > 0 then
	  self.damageSoundTimer = self.damageSoundTimer - script.updateDt()
	end
  end
end

--make the driver and passenger dance and emote according to the damage state of the vehicle
function updatePassengers(healthFactor)
  if healthFactor > 0 then
    --if we have a scared face on because of taking damage
    if self.damageEmoteTimer > 0 then
      self.damageEmoteTimer = self.damageEmoteTimer - script.updateDt()
	  local debugPosition6 = vec2.add(mcontroller.position(), {0,-3.75})
	  world.debugText(self.damageTakenEmote, debugPosition6, "red")
	  vehicle.setLoungeEmote("drivingSeat",self.damageTakenEmote)
    else
	  if healthFactor > 0.5 then
        vehicle.setLoungeEmote("drivingSeat",self.driverEmote)
		local debugPosition6 = vec2.add(mcontroller.position(), {0,-3.75})
	    world.debugText(self.driverEmote, debugPosition6, "red")
	  elseif healthFactor < 0.25 then
	    vehicle.setLoungeEmote("drivingSeat",self.driverEmoteNearDeath)
		local debugPosition6 = vec2.add(mcontroller.position(), {0,-3.75})
	    world.debugText(self.driverEmoteNearDeath, debugPosition6, "red")
	  elseif healthFactor < 0.5 then
	    vehicle.setLoungeEmote("drivingSeat",self.driverEmoteDamaged)
		local debugPosition6 = vec2.add(mcontroller.position(), {0,-3.75})
	    world.debugText(self.driverEmoteDamaged, debugPosition6, "red")
	  else
	    --Failsafe
	    vehicle.setLoungeEmote("drivingSeat",self.driverEmote)
	  end
    end
  end
end


function updateDriveEffects(driverThisFrame)
 
  local startSoundName="mountStart"

  --do we have a driver ?
  if (driverThisFrame~=nil) then

  --has someone got in ?
    if (self.driver==nil) then
	  animator.playSound(startSoundName)    --start sound, plays once.
    end
  end
end


function setDamageEmotes()
  self.damageEmoteTimer=config.getParameter("damageEmoteTime")
  vehicle.setLoungeEmote("drivingSeat",self.damageTakenEmote)
end


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

  --Burst the damage particle effects and play hurt noise, but only if the damageRequest actually deals damage
  if damage > 0 then
    animator.burstParticleEmitter("bloodBurst")
	--Set the driver's emote to the damage emote
    setDamageEmotes()
    if self.damageSoundTimer <= 0 and damage > 0 then
      animator.playSound("hurt")
	  self.damageSoundTimer = self.damageSoundTimeOut
	end
  end
  
  --Reduce health by damage amount
  local healthLost = math.min(damage, storage.health)
  storage.health = storage.health - healthLost

  --Create the floating damage numbers
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


function move(driverThisFrame)

  mcontroller.resetParameters(self.movementSettings)
  if self.driver then
    mcontroller.applyParameters(self.occupiedMovementSettings)
  end
  
  if self.wasPreviouslyOnGround == false and mcontroller.onGround() then
    self.wasPreviouslyOnGround = true
  end
  
  local waterLevel = mcontroller.liquidPercentage()
  local debugPosition7 = vec2.add(mcontroller.position(), {0,-4.5})
  world.debugText(waterLevel, debugPosition7, "pink")
  
  if waterLevel > 0.75 then
    self.isSwimming = true
	self.wasPreviouslyOnGround = false
	self.startedFalling = false
	mcontroller.approachYVelocity(self.swimmingUpVelocity, self.swimmingUpControlForce)
  elseif waterLevel < 0.55 or mcontroller.onGround() and waterLevel < 0.7 then
    self.isSwimming = false
  end
  
  if self.isSwimming == true and self.hasBeenCollected == false then
    animator.setAnimationState("body", "swim")
	local debugPosition8 = vec2.add(mcontroller.position(), {0,-5.25})
    world.debugText("I am swimming", debugPosition8, "pink")
  else
    local debugPosition8 = vec2.add(mcontroller.position(), {0,-5.25})
    world.debugText("I am not swimming", debugPosition8, "pink")
  end
  
  if not mcontroller.onGround() then
    self.airTime = self.airTime + script.updateDt()
  else
    self.airTime = 0
  end  
  
  --Code for smoothing out the walking animation on uneven terrain
  local offGroundFrames = config.getParameter("offGroundFrames")
  if mcontroller.onGround() then
	self.groundFrames = offGroundFrames
  else
	self.groundFrames = self.groundFrames - 1
  end
  
  --Enable jumping while on the ground or very shortly after starting a fall, or while swimming
  if self.airTime < 0.15 and not self.justLanded or self.isSwimming == true then
    if self.jumpTimer <= 0 and vehicle.controlHeld("drivingSeat", "jump") and not vehicle.controlHeld("drivingSeat", "down") then
      mcontroller.setYVelocity(self.jumpVelocity)
      self.jumpTimer = self.jumpTimeout
	  self.groundFrames = 0
    else
      self.jumpTimer = self.jumpTimer - script.updateDt()
    end
  else
    self.jumpTimer = self.jumpTimeout
  end
  
  --Set jump animation and effects
  if mcontroller.yVelocity() > 0.05 and not mcontroller.onGround() and self.isSwimming == false and self.hasBeenCollected == false then
    animator.setAnimationState("body", "jump")
	if self.wasPreviouslyOnGround == true then
	  --Create dust effect
	  animator.burstParticleEmitter("jumpSmoke")
	  self.wasPreviouslyOnGround = false
	end
  --Set fall animation if moving down and not on the ground or in a liquid
  elseif mcontroller.yVelocity() < -0.1 and not mcontroller.onGround() and self.isSwimming == false and self.hasBeenCollected == false then
    self.fallTime = self.fallTime + script.updateDt()
	if self.groundFrames <= 0 then
	  animator.setAnimationState("body", "fall")
	  self.startedFalling = true
	end
  end
  
  --Move Left and animate if not in the air
  if vehicle.controlHeld("drivingSeat", "left") and not self.justLanded then
    if self.isSwimming == false then
	  if vehicle.controlHeld("drivingSeat", "primaryFire") then
		mcontroller.setXVelocity(-self.sprintSpeed)
	  else
		mcontroller.setXVelocity(-self.runSpeed)
	  end
	elseif self.isSwimming == true then
	  mcontroller.setXVelocity(-self.swimSpeed)
	end
	--Set run animation if on ground and not swimming
	if mcontroller.onGround() and self.hasBeenCollected == false and self.isSwimming == false then
	  if vehicle.controlHeld("drivingSeat", "primaryFire") then
		animator.setAnimationState("body", "sprint")
	  else
		animator.setAnimationState("body", "run")
	  end
	end
    self.facingDirection = -1
  end

  --Move right and animate if not in the air
  if vehicle.controlHeld("drivingSeat", "right") and not self.justLanded then
    if self.isSwimming == false then
	  if vehicle.controlHeld("drivingSeat", "primaryFire") then
		mcontroller.setXVelocity(self.sprintSpeed)
	  else
		mcontroller.setXVelocity(self.runSpeed)
	  end
	elseif self.isSwimming == true then
	  mcontroller.setXVelocity(self.swimSpeed)
	end
	--Set run animation if on ground and not swimming
	if mcontroller.onGround() and self.hasBeenCollected == false and self.isSwimming == false then
	  if vehicle.controlHeld("drivingSeat", "primaryFire") then
		animator.setAnimationState("body", "sprint")
	  else
		animator.setAnimationState("body", "run")
	  end
	end
    self.facingDirection = 1
  end
  
  --Stop movement if not pressing any buttons and not in the air
  if not vehicle.controlHeld("drivingSeat", "left") and not vehicle.controlHeld("drivingSeat", "right") and mcontroller.onGround() then
    mcontroller.setXVelocity(0)
	if mcontroller.onGround() and self.hasBeenCollected == false and self.isSwimming == false and not self.justLanded then
	  animator.setAnimationState("body", "idle")
	end  
  --Stop movement if not pressing any buttons and not in the air
  elseif not vehicle.controlHeld("drivingSeat", "left") and not vehicle.controlHeld("drivingSeat", "right") and self.isSwimming == true then
    mcontroller.setXVelocity(0)
  end
  
  --Enable dropping from a platform
  if vehicle.controlHeld("drivingSeat", "jump") and vehicle.controlHeld("drivingSeat", "down") then
    mcontroller.applyParameters(self.noPlatformMovementSettings)
  elseif vehicle.controlHeld("drivingSeat", "down") and mcontroller.yVelocity() < -4.0 then
    mcontroller.applyParameters(self.noPlatformMovementSettings)
  end
  
  --Set inactive animation if not falling and there is no driver
  if (driverThisFrame == nil) and mcontroller.onGround() and self.hasBeenCollected == false and self.isSwimming == false then
    animator.setAnimationState("body", "inactive")
  end
  
  --================= Start the procedures required for fall damage calculation =================
  
  local currentYPosition = mcontroller.yPosition()
  local yPositionChange = currentYPosition - (self.lastYPosition or currentYPosition)
  
  --Debug text for checking last and current Y position, plus the position change/fall distance
  world.debugText(currentYPosition, mcontroller.position(), "yellow")
  local debugPosition2 = vec2.add(mcontroller.position(), {0,-0.75})
  world.debugText(self.lastYPosition, debugPosition2, "yellow")
  local debugPosition3 = vec2.add(mcontroller.position(), {0,-1.5})
  world.debugText(yPositionChange, debugPosition3, "yellow")
  local debugPosition4 = vec2.add(mcontroller.position(), {0,-2.25})
  world.debugText(storage.health, debugPosition4, "green")
  
  --Do things when hitting the ground after falling
  if self.startedFalling == true and mcontroller.onGround() then
    --Create dust effect
	animator.burstParticleEmitter("jumpSmoke")
	animator.setAnimationState("body", "land")
	animator.playSound("land")
	self.startedFalling = false
	self.fallTime = 0
	self.justLanded = true
	self.landTimer = config.getParameter("landRecoveryTime")
	
	--Do damage if the fall distance is high enough
	if yPositionChange < -self.maxFallDistance then
	  --Set the driver's emote to the damage emote
	  setDamageEmotes()
	  --Burst the damage particle effects and play hurt noise
	  animator.burstParticleEmitter("bloodBurst")
	  if self.damageSoundTimer <= 0 then
		animator.playSound("hurt")
		self.damageSoundTimer = self.damageSoundTimeOut
	  end
	  
	  --Calculate the fall damage
	  local fallDamage = -yPositionChange * self.fallDamageMultiplier
	  
	  --Reduce health
	  local healthLost = math.min(fallDamage, storage.health)
	  storage.health = storage.health - healthLost
	  
	  --Create the floating damage numbers
	  table.insert(self.selfDamageNotifications, {
        sourceEntityId = entity.id(),
        targetEntityId = entity.id(),
        position = mcontroller.position(),
        damageDealt = fallDamage,
        healthLost = healthLost,
        hitType = "Hit",
        damageSourceKind = "falling",
        targetMaterialKind = self.materialKind,
        killed = storage.health <= 0
      })
	end
  elseif mcontroller.onGround() and self.fallTime > 0 then
    self.fallTime = 0
  end
  
  --Set last Y position as the last positon where we were on the ground, or when we were last going up
  if mcontroller.onGround() then
    self.lastYPosition = mcontroller.yPosition()
  elseif mcontroller.yVelocity() > 0 then
    self.lastYPosition = mcontroller.yPosition()
  end
end

--FLipping the vehicle sprites based on our facing direction
function animate()
  animator.resetTransformationGroup("flip")
  if self.facingDirection < 0 then
    animator.scaleTransformationGroup("flip", {-1, 1})
  end
end

function updateDamage()
  if storage.health <= 0 then
    animator.playSound("death")
	animator.burstParticleEmitter("deathPoof")
    vehicle.destroy()
  end

  local newPosition = mcontroller.position()
  local newVelocity = vec2.div(vec2.sub(newPosition, self.lastPosition), script.updateDt())
  self.lastPosition = newPosition
end
