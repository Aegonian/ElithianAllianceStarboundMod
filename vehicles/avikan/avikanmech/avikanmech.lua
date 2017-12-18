require "/scripts/vec2.lua"

function init()
  --Settings form config file
  self.movementSettings = config.getParameter("movementSettings")
  self.occupiedMovementSettings = config.getParameter("occupiedMovementSettings")
  self.noPlatformMovementSettings = config.getParameter("noPlatformMovementSettings")
  self.protection = config.getParameter("protection")
  self.maxHealth = config.getParameter("maxHealth")
  self.worldBottomDeathLevel = 8
  self.materialKind = config.getParameter("materialKind")
  self.damageTakenEmote = config.getParameter("damageTakenEmote")
  self.mechAimLimit = config.getParameter("mechAimLimit") * math.pi / 180
  self.fireTime = config.getParameter("fireTime")
  self.fireProjectile = config.getParameter("fireProjectile")
  self.fireProjectileConfig = config.getParameter("fireProjectileConfig")
  self.secondaryFireTime = config.getParameter("secondaryFireTime")
  self.secondaryFireBurstTime = config.getParameter("secondaryFireBurstTime")
  self.secondaryFireProjectile = config.getParameter("secondaryFireProjectile")
  self.secondaryFireProjectileCount = config.getParameter("secondaryFireProjectileCount")
  self.secondaryFireInaccuracy = config.getParameter("secondaryFireInaccuracy")
  self.secondaryFireProjectileConfig = config.getParameter("secondaryFireProjectileConfig")
  self.explosionProjectile = config.getParameter("explosionProjectile")
  self.explosionProjectileConfig = config.getParameter("explosionProjectileConfig")
  self.mechWalkingSpeed = config.getParameter("mechWalkingSpeed")
  self.mechJumpVelocity = config.getParameter("mechJumpVelocity")
  self.jumpCooldownTime = config.getParameter("jumpCooldownTime")
  self.minAirTime = config.getParameter("minAirTime")
  self.mechBoostVelocityUp = config.getParameter("mechBoostVelocityUp")
  self.mechBoostVelocitySideways = config.getParameter("mechBoostVelocitySideways")
  self.mechBoostControlForce = config.getParameter("mechBoostControlForce")
  self.minFallTime = config.getParameter("minFallTime")
  self.fallControlSpeed = config.getParameter("fallControlSpeed")
  self.warningHealthFactor = config.getParameter("warningHealthFactor")
  self.maxBoostTime = config.getParameter("maxBoostTime")

  --Starting stats
  self.driver = nil;
  self.facingDirection = config.getParameter("facingDirection") or 1 --Allow the spawner to set the starting facing direction
  if self.facingDirection > 0 then
	self.mechFlipped = false
  elseif self.facingDirection < 0 then
	self.mechFlipped = true
  else
	self.mechFlipped = false
  end
  self.jumpTimer = 0
  self.lastPosition = mcontroller.position()
  self.fireTimer = self.fireTime
  self.secondaryFireTimer = self.secondaryFireTime
  self.secondaryFireBurstTimer = self.secondaryFireBurstTime
  self.secondaryBurstsLeft = self.secondaryFireProjectileCount
  self.lastGunFired = 0 -- 0 is back gun, 1 is front gun
  self.onGroundTime = 0
  self.jumpCooldownTimer = 0
  self.airTime = 0
  self.isWarping = false
  self.isMoving = false
  self.groundFrames = 1
  self.currentDriver = false
  self.vehicleClosed = false
  self.justLanded = false
  self.landTimer = config.getParameter("landRecoveryTime")
  self.boostingDirection = 0
  self.boostSoundIsPlaying = false
  self.warningSoundIsPlaying = false
  self.boostTimeLeft = self.maxBoostTime
  
  --Setting up damage phase storage
  if not storage.damagePhase then
	storage.damagePhase = 4
  end
  if not storage.previousDamagePhase then
	storage.previousDamagePhase = 4
  end
  
  --Functions setup
  self.selfDamageNotifications = {}

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
    animator.setAnimationState("mech", "idle")     
  else
    local startHealthFactor = config.getParameter("startHealthFactor")

    if (startHealthFactor == nil) then
        storage.health = self.maxHealth
    else
       storage.health = math.min(startHealthFactor * self.maxHealth, self.maxHealth)
    end    
    animator.setAnimationState("mech", "warpInPart1")
  end

  --Setup for the storage functionality  
  message.setHandler("store",
	function(_, _, ownerKey)
	  if (self.ownerKey and self.ownerKey == ownerKey and self.driver == nil and animator.animationState("mech")=="idleOpen") then
		animator.setAnimationState("mech", "warpOutPart1")
		animator.playSound("returnvehicle")
		return {storable = true, healthFactor = storage.health / self.maxHealth}
	  else
		return {storable = false, healthFactor = storage.health / self.maxHealth}
	  end
	end)

  --Update the current damage phase on startup
  updateDamagePhase()
end

function update()
  --Kill the vehicle if it falls to the bottom of the map
  if mcontroller.position()[2] < self.worldBottomDeathLevel then
    vehicle.destroy()
    return
  end
  
  --Destroy the vehicle if it was collected
  if (animator.animationState("mech")=="invisible") then
    vehicle.destroy()
  end
  
  --Hide the guns and damage if the mech is hidden
  if animator.animationState("mech")=="warpInPart1" or animator.animationState("mech")=="warpOutPart2" then
	animator.setAnimationState("foregroundgun", "invisible")
	animator.setAnimationState("foregroundgunmuzzle", "invisible")
	animator.setAnimationState("backgroundgun", "invisible")
	animator.setAnimationState("backgroundgunmuzzle", "invisible")
	animator.setAnimationState("damage", "invisible")
  else
	if not animator.animationState("foregroundgunmuzzle")=="firing" then
	  animator.setAnimationState("foregroundgunmuzzle", "invisible")
	end
	if not animator.animationState("backgroundgunmuzzle")=="firing" then
	  animator.setAnimationState("backgroundgunmuzzle", "invisible")
	end
	animator.setAnimationState("foregroundgun", "idle")
	animator.setAnimationState("backgroundgun", "idle")
  end
  
  --If we just made the mech visible, update the damage phase
  if animator.animationState("mech")=="warpInPart2" then
	updateDamagePhase()
  end
  
  --Check animation state to see if we are moving or warping
  if animator.animationState("mech")=="warpInPart1"
	or animator.animationState("mech")=="warpInPart2"
	or animator.animationState("mech")=="warpOutPart1"
	or animator.animationState("mech")=="warpOutPart2"
	or animator.animationState("mech")=="invisible" then
	  self.isWarping = true
  else
    self.isWarping = false
  end
  if animator.animationState("mech")=="walking"
	or animator.animationState("mech")=="walkingBackwards"
	or animator.animationState("mech")=="jumping"
	or animator.animationState("mech")=="boosting"
	or animator.animationState("mech")=="falling"
	or animator.animationState("mech")=="landing" then
	  self.isMoving = true
  else
    self.isMoving = false
  end
  
  self.currentDriver = vehicle.entityLoungingIn("drivingSeat")
  --Close the mech if it is currently open, and we have a driver
  if self.currentDriver ~= nil
	and self.vehicleClosed == false
	and not self.isWarping
	and not self.isMoving
	and animator.animationState("mech")=="idleOpen" then
	  animator.setAnimationState("mech", "closing")
	  animator.playSound("powerup")
  end
  if self.vehicleClosed == false and animator.animationState("mech")=="idle" then
	self.vehicleClosed = true
  end
  
  if self.forceDespawn then
    --Remove the vehicle from the world
	vehicle.destroy()
  elseif self.isWarping then
	--Lock the vehicle in place while warping
    mcontroller.setPosition(self.lastPosition)
    mcontroller.setVelocity({0,0})
  else
	--Set the current driver
    local driverThisFrame = vehicle.entityLoungingIn("drivingSeat")

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
	self.secondaryFireTimer = math.max(0, self.secondaryFireTimer - script.updateDt())
	self.secondaryFireBurstTimer = math.max(0, self.secondaryFireBurstTimer - script.updateDt())

	--Cycle through these functions every frame
    setDirection()
	move()
	aim()

    self.driver = driverThisFrame
  end
  
  --Play the booster flame animation and sound if boosting
  local diff = world.distance(vehicle.aimPosition("drivingSeat"), mcontroller.position())
  aimAngle = math.atan(diff[2], diff[1])
  local facingDirection = (aimAngle > math.pi / 2 or aimAngle < -math.pi / 2) and -1 or 1
  if self.isBoosting then
	if self.boostingDirection ~= 0 then
	  if self.boostingDirection ~= facingDirection then
		animator.setAnimationState("boosterflame", "boostingback")
	  else
		animator.setAnimationState("boosterflame", "boostingforward")
	  end
	else
	  animator.setAnimationState("boosterflame", "boostingup")
	end
	if self.boostSoundIsPlaying == false then
	  animator.playSound("boost", -1)
	  self.boostSoundIsPlaying = true
	end
  else
	animator.setAnimationState("boosterflame", "invisible")
	self.boostSoundIsPlaying = false
	animator.stopAllSounds("boost")
  end
  
  --Falling/impact without a driver
  if self.currentDriver == nil and self.airTime >= 0.1 then
	if mcontroller.onGround() then
	  animator.burstParticleEmitter("landingDust")
	  animator.playSound("landing")
	end
  end
  
  --Calculating the time spent airborne
  if mcontroller.onGround() then
	self.jumpCooldownTimer = math.max(0, self.jumpCooldownTimer - script.updateDt())
	self.airTime = 0
	self.boostTimeLeft = self.maxBoostTime
  else
	self.airTime = self.airTime + script.updateDt()
  end
  
  --If we are underwater, grant infinite boosters
  if world.liquidAt(mcontroller.position()) then
	self.boostTimeLeft = self.maxBoostTime
  end
  
  --Code for disabling control shortly after landing
  if self.justLanded == true then
	self.landTimer = math.max(0, self.landTimer - script.updateDt())
  end
  if self.landTimer <= 0 then
	self.justLanded = false
  end
  
  --Open the mech if we aren't warping, and we have no driver
  if self.currentDriver == nil
	and self.vehicleClosed == true
	and not self.isWarping then
	  animator.setAnimationState("mech", "opening")
	  self.vehicleClosed = false
	  animator.playSound("powerdown")
	  --Stop any ongoing secondary fire attacks
	  self.secondaryBurstsLeft = self.secondaryFireProjectileCount
	  self.secondaryFireTimer = self.secondaryFireTime
	  self.secondaryIsFiring = false
  end
  
  self.lastPosition = mcontroller.position()
end

--Make the driver play an emote when damaged
function setdamageTakenEmotes()
  vehicle.setLoungeEmote("drivingSeat",self.damageTakenEmote)
end

--Visual effects for vehicle damage
function updateDamagePhase()
  local healthFactor = storage.health / self.maxHealth
  storage.damagePhase = math.ceil(healthFactor * 4)
  --Damage phase can be 4, 3, 2 or 1. Phase 4 is undamaged, phase 1 is max damage!
  if storage.damagePhase == 4 then
	animator.setAnimationState("damage", "undamaged")
	animator.setParticleEmitterActive("sparks", false)
	animator.setParticleEmitterActive("fire", false)
  elseif storage.damagePhase == 3 then
	animator.setAnimationState("damage", "scratched")
	animator.setParticleEmitterActive("sparks", false)
	animator.setParticleEmitterActive("fire", false)
  elseif storage.damagePhase == 2 then
	animator.setAnimationState("damage", "dented")
	animator.setParticleEmitterActive("sparks", true)
	animator.setParticleEmitterActive("fire", false)
  elseif storage.damagePhase == 1 then
	animator.setAnimationState("damage", "wrecked")
	animator.setParticleEmitterActive("sparks", true)
	animator.setParticleEmitterActive("fire", true)
  end
  
  if healthFactor <= self.warningHealthFactor and self.warningSoundIsPlaying == false then
	animator.playSound("warning", -1)
	self.warningSoundIsPlaying = true
  elseif healthFactor > self.warningHealthFactor and self.warningSoundIsPlaying == true then
	animator.stopAllSounds("warning")
	self.warningSoundIsPlaying = false
  end
  
  --If the damage phase changed, create particles
  if storage.previousDamagePhase ~= storage.damagePhase then
	animator.burstParticleEmitter("damageShards")
  end
  storage.previousDamagePhase = storage.damagePhase
  
  --Vehicle destruction code
  if storage.health <= 0 then
	animator.burstParticleEmitter("explosion")
	world.spawnProjectile(self.explosionProjectile, mcontroller.position(), 0, {0, 0}, false, self.explosionProjectileConfig)
	vehicle.destroy()
  end
end

--Function for applying damage to the vehicle
function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" then
    damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  else
    return {}
  end

  setdamageTakenEmotes()
  updateDamagePhase()
  
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

--Set the vehicle's facing direction
function setDirection()
  animator.resetTransformationGroup("flip")
  local diff = world.distance(vehicle.aimPosition("drivingSeat"), mcontroller.position())
  aimAngle = math.atan(diff[2], diff[1])
  self.mechFlipped = aimAngle > math.pi / 2 or aimAngle < -math.pi / 2
  if self.mechFlipped then
    animator.scaleTransformationGroup("flip", {-1, 1})
  end
end

--Function for controlling the vehicle movement
function move()
  --Reset the movement parameters in case we lost our driver
  mcontroller.resetParameters(self.movementSettings)
  local onGround = mcontroller.onGround()
  local offGroundFrames = config.getParameter("offGroundFrames")
  --Only if we have a driver, and we are not closing the mech, continue on with the function
  if self.driver and self.vehicleClosed then
    mcontroller.applyParameters(self.occupiedMovementSettings)
	
	local diff = world.distance(vehicle.aimPosition("drivingSeat"), mcontroller.position())
	aimAngle = math.atan(diff[2], diff[1])
	local facingDirection = (aimAngle > math.pi / 2 or aimAngle < -math.pi / 2) and -1 or 1
	local movingDirection = 0
	
	--Moving left
	if vehicle.controlHeld("drivingSeat", "left") and onGround and not self.justLanded then
	  mcontroller.setXVelocity(-self.mechWalkingSpeed)
	  movingDirection = -1
	end
	--Moving right
	if vehicle.controlHeld("drivingSeat", "right") and onGround and not self.justLanded then
	  mcontroller.setXVelocity(self.mechWalkingSpeed)
	  movingDirection = 1
	end
	
	--Code for smoothing out the walking animation on uneven terrain
	if onGround then
	  self.groundFrames = offGroundFrames
	else
	  self.groundFrames = self.groundFrames - 1
	end
	
	--Jumping
	if vehicle.controlHeld("drivingSeat", "jump") and not vehicle.controlHeld("drivingSeat", "down") and self.jumpCooldownTimer <= 0 and onGround and not self.justLanded then
	  mcontroller.setYVelocity(self.mechJumpVelocity[2])
	  if vehicle.controlHeld("drivingSeat", "right") then
		mcontroller.setXVelocity(self.mechJumpVelocity[1] * 1)
	  elseif vehicle.controlHeld("drivingSeat", "left") then
		mcontroller.setXVelocity(self.mechJumpVelocity[1] * -1)
	  end
	  self.groundFrames = 0
	  self.jumpCooldownTimer = self.jumpCooldownTime
	  animator.playSound("jump")
	end
	
	--Boosting
	self.boostingDirection = 0
	if vehicle.controlHeld("drivingSeat", "jump") and self.airTime >= self.minAirTime and self.boostTimeLeft > 0 then
	  local targetVelocity = {self.mechBoostVelocityUp,self.mechBoostVelocitySideways}
	  if vehicle.controlHeld("drivingSeat", "right") then
		targetVelocity[1] = self.mechBoostVelocitySideways
		self.boostingDirection = 1
	  elseif vehicle.controlHeld("drivingSeat", "left") then
		targetVelocity[1] = -self.mechBoostVelocitySideways
		self.boostingDirection = -1
	  else
		targetVelocity[1] = 0
	  end
	  mcontroller.approachVelocity(targetVelocity, self.mechBoostControlForce)
	  self.isBoosting = true
	  self.boostTimeLeft = math.max(0, self.boostTimeLeft - script.updateDt())
	else
	  self.isBoosting = false
	end
	
	--Landing
	if self.airTime >= self.minFallTime then
	  if mcontroller.onGround() then
		animator.burstParticleEmitter("landingDust")
		animator.playSound("landing")
		self.justLanded = true
		self.landTimer = config.getParameter("landRecoveryTime")
	  end
	end
	
	--Animation control
	if self.groundFrames <= 0 then
	  if mcontroller.velocity()[2] > 0 and not self.isBoosting then
		animator.setAnimationState("mech", "jumping")
	  elseif self.isBoosting then
		if self.boostingDirection ~= 0 then
		  if self.boostingDirection ~= facingDirection then
			animator.setAnimationState("mech", "boostingback")
		  else
			animator.setAnimationState("mech", "boostingforward")
		  end
		else
		  animator.setAnimationState("mech", "boostingup")
		end
	  else
		animator.setAnimationState("mech", "falling")
	  end
	elseif movingDirection ~= 0 then
	  if facingDirection ~= movingDirection then
		animator.setAnimationState("mech", "walkingBackwards")
	  else
		animator.setAnimationState("mech", "walking")
	  end
	elseif onGround then
	  if self.justLanded == true then
		animator.setAnimationState("mech", "landing")
	  else
		animator.setAnimationState("mech", "idle")
	  end
	end
	
	--Falling control
	if animator.animationState("mech")=="falling" then
	  if vehicle.controlHeld("drivingSeat", "right") then
		mcontroller.setXVelocity(self.fallControlSpeed * 1)
	  elseif vehicle.controlHeld("drivingSeat", "left") then
		mcontroller.setXVelocity(self.fallControlSpeed * -1)
	  end
	end
	
	--Enable dropping from a platform
	if vehicle.controlHeld("drivingSeat", "jump") and vehicle.controlHeld("drivingSeat", "down") then
	  mcontroller.applyParameters(self.noPlatformMovementSettings)
	elseif vehicle.controlHeld("drivingSeat", "down") and mcontroller.yVelocity() < -4.0 then
	  mcontroller.applyParameters(self.noPlatformMovementSettings)
	end
  end
end

--Function for aiming the guns
function aim()
  --Only if we have a driver, continue on with the function
  if self.driver then
    --Figure out which way to face
	local diff = world.distance(vehicle.aimPosition("drivingSeat"), mcontroller.position())
	self.aimAngle = math.atan(diff[2], diff[1])
	local facingDirection = (self.aimAngle > math.pi / 2 or self.aimAngle < -math.pi / 2) and -1 or 1
	
	--Rotate the guns
	if self.mechFlipped then
	  if self.aimAngle > 0 then
		self.aimAngle = math.max(self.aimAngle, math.pi - self.mechAimLimit)
	  else
		self.aimAngle = math.min(self.aimAngle, -math.pi + self.mechAimLimit)
	  end
	  animator.rotateGroup("guns", math.pi - self.aimAngle)
	else
	  if self.aimAngle > 0 then
        self.aimAngle = math.min(self.aimAngle, self.mechAimLimit)
      else
        self.aimAngle = math.max(self.aimAngle, -self.mechAimLimit)
      end	  
	  animator.rotateGroup("guns", self.aimAngle)
	end
	
	--Firing behaviour
	if vehicle.controlHeld("drivingSeat", "primaryFire") then
	  if self.fireTimer <= 0 then
		if self.lastGunFired == 0 then
		  world.spawnProjectile(self.fireProjectile, vec2.add(mcontroller.position(), animator.partPoint("foregroundgun", "firePoint")), vehicle.entityLoungingIn("drivingSeat"), {math.cos(self.aimAngle), math.sin(self.aimAngle)}, false, self.fireProjectileConfig)
		  animator.setAnimationState("foregroundgunmuzzle", "firing")
		  animator.playSound("fire")
		  self.fireTimer = self.fireTime
		  self.lastGunFired = 1
		elseif self.lastGunFired == 1 then
		  world.spawnProjectile(self.fireProjectile, vec2.add(mcontroller.position(), animator.partPoint("backgroundgun", "firePoint")), vehicle.entityLoungingIn("drivingSeat"), {math.cos(self.aimAngle), math.sin(self.aimAngle)}, false, self.fireProjectileConfig)
		  animator.setAnimationState("backgroundgunmuzzle", "firing")
		  animator.playSound("fire")
		  self.fireTimer = self.fireTime
		  self.lastGunFired = 0
		end
	  end
	end
	
	--Secondary firing behaviour
	if vehicle.controlHeld("drivingSeat", "altFire") then
	  if self.secondaryFireTimer <= 0 and not self.secondaryIsFiring then
		self.secondaryIsFiring = true
	  end
	end
	
	--Secondary firing behaviour, part 2
	if self.secondaryIsFiring then
	  if self.secondaryFireBurstTimer <= 0 and self.secondaryBurstsLeft > 0 then
		local aimVector = vec2.rotate({1*facingDirection, 2}, sb.nrand(self.secondaryFireInaccuracy, 0))
		world.spawnProjectile(self.secondaryFireProjectile, vec2.add(mcontroller.position(), animator.partPoint("seat", "secondaryFirePosition")), vehicle.entityLoungingIn("drivingSeat"), aimVector, false, self.secondaryFireProjectileConfig)
		animator.playSound("secondaryFire")
		self.secondaryFireBurstTimer = self.secondaryFireBurstTime
		self.secondaryBurstsLeft = self.secondaryBurstsLeft - 1
	  elseif self.secondaryBurstsLeft == 0 then
		self.secondaryBurstsLeft = self.secondaryFireProjectileCount
		self.secondaryFireTimer = self.secondaryFireTime
		self.secondaryIsFiring = false
	  end
	end
  end
end
