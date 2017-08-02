require "/scripts/vec2.lua"

function init()
  --Settings form config file
  self.movementSettings = config.getParameter("movementSettings")
  self.protection = config.getParameter("protection")
  self.maxHealth = config.getParameter("maxHealth")
  self.materialKind = config.getParameter("materialKind")
  self.fireProjectile = config.getParameter("fireProjectile")
  self.fireProjectileConfig = config.getParameter("fireProjectileConfig")
  self.explosionProjectile = config.getParameter("explosionProjectile")
  self.explosionProjectileConfig = config.getParameter("explosionProjectileConfig")
  self.flyingSpeed = config.getParameter("flyingSpeed")
  self.flyControlForce = config.getParameter("flyControlForce")
  self.chargeTime = config.getParameter("chargeTime")
  self.cooldownTime = config.getParameter("cooldownTime")
  self.minimumTargetDistance = config.getParameter("minimumTargetDistance")
  self.firingOffset = config.getParameter("firingOffset")
  self.damagedThreshold = config.getParameter("damagedThreshold")
  self.wreckedThreshold = config.getParameter("wreckedThreshold")

  --Starting stats
  self.targetPosition = mcontroller.position()
  self.lastTargetPosition = self.targetPosition
  self.aimAngle = {1, 1}
  self.chargeTimer = self.chargeTime
  self.cooldownTimer = self.cooldownTime
  self.chargeStarted = false
  self.controlHeld = "none"
  self.shouldDespawn = false
  
  --Functions setup
  self.selfDamageNotifications = {}
  
  --Health setup
  if not storage.health then
	local startHealthFactor = config.getParameter("startHealthFactor")
	if startHealthFactor == nil then
	  storage.health = self.maxHealth
	else
	  storage.health = math.min(startHealthFactor * self.maxHealth, self.maxHealth)
	end
	animator.setAnimationState("warp", "warpInPart1")
	animator.setAnimationState("body", "invisible")
	animator.setAnimationState("damage", "invisible")
	self.isWarping = true
  end
  
  --Owner setup
  self.ownerKey = config.getParameter("ownerKey")
  if self.ownerKey then
	vehicle.setPersistent(true)
	vehicle.setDamageTeam({type = "friendly"})
  else
	vehicle.setPersistent(false)
	vehicle.setDamageTeam({type = "passive"})
  end
  
  vehicle.setInteractive(false)
  message.setHandler("updateInputParameters", updateInputParameters)
  message.setHandler("killVehicle", killVehicle)
  message.setHandler("storeVehicle", storeVehicle)
  
  --Update damage visuals if we aren't warping
  if not self.isWarping then
	updateDamageEffects()
  end
end

--Currently unused, but allows us to see if we got interacted with by an entity holding the controller with the righ key
function onInteraction(args)
  local interactingEntityId = args.sourceId
  local item = world.entityHandItemDescriptor(interactingEntityId, "primary")

  if item.parameters.key == self.ownerKey then
	--Interaction success
  end
end

function update()
  --Check which warp phase we are in
  if animator.animationState("warp") == "warpInPart1" then
	self.isWarping = true
  elseif animator.animationState("warp") == "warpInPart2" then
	self.isWarping = true
	animator.setAnimationState("body", "idle")
	updateDamageEffects()
  elseif animator.animationState("warp") == "warpOutPart1" then
	self.isWarping = true
  elseif animator.animationState("warp") == "warpOutPart2" then
	self.isWarping = true
	animator.setAnimationState("body", "invisible")
	animator.setAnimationState("damage", "invisible")
  else
	self.isWarping = false
  end
  
  --If we got collected and need to despawn
  if self.shouldDespawn and animator.animationState("warp") == "invisible" then
	vehicle.destroy()
  end
  
  --Functions to cycle through on each frame, unless we are warping or despawning
  if not self.isWarping and not self.shouldDespawn then
	move()
	setDirection()
  
	self.cooldownTimer = math.max(0, self.cooldownTimer - script.updateDt())
  
	--Kill vehicle if at zero health
	if storage.health <= 0 then
	  killVehicle()
	end
  end
  
  --Reset certain parameters if we didn't get contacted by a controller last frame
  if self.gotInputOnLastFrame == false then
	self.controlHeld = "none"
  end
  self.lastTargetPosition = self.targetPosition
  self.gotInputOnLastFrame = false
end

--Function is remotely called by the controller. Translates owner input into local variables
--Ownerkey is used to determine if the message sender is the same entity as the one who created the vehicle
function updateInputParameters(_, _, aimPosition, controlHeld, ownerShiftHeld, ownerKey, ownerEntityId)
  if ownerKey == self.ownerKey then
	if aimPosition ~= nil then
	  self.targetPosition = aimPosition
	else
	  self.targetPosition = mcontroller.position()
	  self.lastTargetPosition = self.targetPosition
	end
	self.controlHeld = controlHeld
	if self.controlHeld == nil then
	  self.controlHeld = "none"
	end
	self.ownerEntityId = ownerEntityId
	self.gotInputOnLastFrame = true
  end
end

--Kills the vehicle. Can be called remotely by the controller
function killVehicle()
  animator.burstParticleEmitter("explosion")
  world.spawnProjectile(self.explosionProjectile, mcontroller.position(), 0, {0, 0}, false, self.explosionProjectileConfig)
  vehicle.destroy()
end

--Stores the vehicle. Can be called remotely by the controller
function storeVehicle(_, _, ownerKey)
  if self.ownerKey and ownerKey == self.ownerKey then
	self.shouldDespawn = true
	animator.setAnimationState("warp", "warpOutPart1")
	animator.playSound("returnvehicle")
	return {storeVehicleSuccess = true, healthFactor = storage.health / self.maxHealth}
  else
	return {storeVehicleSuccess = false, healthFactor = storage.health / self.maxHealth}
  end
end

--Set the vehicle's facing direction
function setDirection()
  local offset = world.distance(self.lastTargetPosition, mcontroller.position())
  local aimAngle = math.atan(offset[2], offset[1])
  self.vehicleFlipped = aimAngle > math.pi / 2 or aimAngle < -math.pi / 2
  if self.vehicleFlipped == true then
	animator.setFlipped(true)
	self.firingOffset[1] = -config.getParameter("firingOffset")[1]
  else
	animator.setFlipped(false)
	self.firingOffset[1] = config.getParameter("firingOffset")[1]
  end
end

--Function for controlling the vehicle movement and firing behaviour
function move()
  --Code for calculating the aim
  local offset = world.distance(self.targetPosition, mcontroller.position())
  self.aimAngle = vec2.norm(offset)
  
  --If the owner holds down primary fire, move the vehicle towards the owner aim position
  if self.controlHeld == "primary" and vec2.mag(offset) > self.minimumTargetDistance then
	if animator.animationState("body") ~= "idle" then
	  animator.setAnimationState("body", "idle")
	end
	mcontroller.approachVelocity(vec2.mul(vec2.norm(offset), self.flyingSpeed), self.flyControlForce)
  end
	
  --If the owner holds down secondary fire, start firing the vehicle's weapon
  if self.controlHeld == "alt" then
	if self.cooldownTimer == 0 then
	  if self.chargeStarted == false then
		animator.playSound("charge")
		animator.setAnimationState("body", "firewindup")
		self.chargeStarted = true
	  end
	  
	  self.chargeTimer = math.max(0, self.chargeTimer - script.updateDt())
	  
	  if self.chargeTimer == 0 then
		local firePosition = vec2.add(mcontroller.position(), self.firingOffset)
		local sourceEntityId = entity.id()
		if self.ownerEntityId and world.entityExists(self.ownerEntityId) then
		  sourceEntityId = self.ownerEntityId
		end
		world.spawnProjectile(self.fireProjectile, firePosition, sourceEntityId, self.aimAngle, false, self.fireProjectileConfig)
		animator.playSound("fire")
		animator.stopAllSounds("charge")
		animator.setAnimationState("body", "fire")
		self.cooldownTimer = self.cooldownTime
		self.chargeTimer = self.chargeTime
		self.chargeStarted = false
	  end
	end
  else
	animator.stopAllSounds("charge")
	self.chargeTimer = self.chargeTime
	self.chargeStarted = false
  end
	
  --If the owner isn't holding down any mouse button, reset it
  if self.controlHeld == "none" then
	if animator.animationState("body") ~= "idle" and animator.animationState("body") ~= "fire" then
	  animator.setAnimationState("body", "idle")
	end
  end
end

--Creates visual effects to simulate damage
function updateDamageEffects()
  if storage.health > self.damagedThreshold then
	animator.setAnimationState("damage", "undamaged")
	animator.setParticleEmitterActive("sparks", false)
  elseif storage.health <= self.damagedThreshold and storage.health > self.wreckedThreshold then
	animator.setAnimationState("damage", "damaged")
	animator.setParticleEmitterActive("sparks", true)
  elseif storage.health <= self.wreckedThreshold then
	animator.setAnimationState("damage", "wrecked")
	animator.setParticleEmitterActive("sparks", true)
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
  
  local healthLost = math.min(damage, storage.health)
  storage.health = storage.health - healthLost
  
  updateDamageEffects()

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

--Damage notification setup
function selfDamageNotifications()
  local sdn = self.selfDamageNotifications
  self.selfDamageNotifications = {}
  return sdn
end

--Function is called by the controller's entityQuery. Returns a boolean to the activeitem stating whether or not the ownerKeys correspond
--Couldn't get it to work, but keeping the code for future reference. Most likely doesn't work because world.callScriptedEntity does not seem to work between activeitems and vehicles
function requestIsControlled(senderKey)
  if senderKey == self.ownerKey then
	return true
  else
	return true
  end
end
