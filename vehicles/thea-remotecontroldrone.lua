require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  --Settings from config file
  self.movementSettings = config.getParameter("movementSettings")
  self.protection = config.getParameter("protection")
  self.maxHealth = config.getParameter("maxHealth")
  self.materialKind = config.getParameter("materialKind")
  self.explosionProjectile = config.getParameter("explosionProjectile")
  self.explosionProjectileConfig = config.getParameter("explosionProjectileConfig")
  self.flyingSpeed = config.getParameter("flyingSpeed")
  self.flyControlForce = config.getParameter("flyControlForce")
  self.minimumTargetDistance = config.getParameter("minimumTargetDistance")
  self.damagedThreshold = config.getParameter("damagedThreshold")
  self.wreckedThreshold = config.getParameter("wreckedThreshold")
  self.edgeOfRangeDistance = config.getParameter("edgeOfRangeDistance")
  self.signalLossTimout = config.getParameter("signalLossTimout")
  
  --Altfire ability settings from config file
  self.fireMode = config.getParameter("fireMode", nil)
  self.fireProjectile = config.getParameter("fireProjectile", nil)
  self.fireProjectileConfig = config.getParameter("fireProjectileConfig", {})
  self.chargeTime = config.getParameter("chargeTime", 0)
  self.cooldownTime = config.getParameter("cooldownTime", 0)
  self.firingOffset = config.getParameter("firingOffset", {0,0})
  
  --Starting stats
  self.targetPosition = mcontroller.position()
  self.lastTargetPosition = self.targetPosition
  self.aimAngle = {1, 1}
  self.chargeTimer = self.chargeTime
  self.cooldownTimer = self.cooldownTime
  self.chargeStarted = false
  self.controlHeld = "none"
  self.shouldDespawn = false
  self.signalLossTimer = 0
  self.flashlightActive = false
  self.flashLightWasToggled = false
  if self.fireMode == "flashlight" then
	animator.setLightActive("flashlight", false)
	animator.setAnimationState("flashlight", "off")
  end
  
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
	animator.setAnimationState("antenna", "invisible")
	if self.fireMode == "flashlight" then
	  animator.setAnimationState("flashlight", "invisible")
	end
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
  message.setHandler("requestIsControlled", requestIsControlled)
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
	animator.setAnimationState("antenna", "invisible")
	if self.fireMode == "flashlight" then
	  animator.setAnimationState("flashlight", "invisible")
	end
  else
	self.isWarping = false
  end
  
  --If we have an owner, set out uniqueId to the ownerKey that we received
  --Currently disabled, but kept for future reference/reactivation. Vehicles cannot have uniqueIds in the current version of Starbound, making remotely controlled vehicles difficult to handle
  if self.ownerKey then
	--world.setUniqueId(entity.id(), self.ownerKey)
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
  
  world.debugText("Self ID = " .. sb.printJson(entity.id()), vec2.add(mcontroller.position(), {0,1}), "red")
  world.debugText("Owner Key = " .. sb.printJson(self.ownerKey), vec2.add(mcontroller.position(), {0,2}), "red")
  world.debugText("Owner ID = " .. sb.printJson(self.ownerEntityId), vec2.add(mcontroller.position(), {0,3}), "red")
  world.debugPoint(vec2.add(mcontroller.position(), self.firingOffset), "red")
  
  --Antenna animation
  self.signalLossTimer = math.max(0, self.signalLossTimer - script.updateDt())
  if self.signalLossTimer > 0 then
	if self.ownerEntityId and world.entityExists(self.ownerEntityId) then
	  local distanceToOwner = world.magnitude(mcontroller.position(), world.entityPosition(self.ownerEntityId))
	  if distanceToOwner > self.edgeOfRangeDistance then
		animator.setAnimationState("antenna", "edgeOfRange")
	  else
		animator.setAnimationState("antenna", "inRange")
	  end
	else
	  animator.setAnimationState("antenna", "outOfRange")
	end
  else
	animator.setAnimationState("antenna", "outOfRange")
  end
  
  --Reset certain parameters if we didn't get contacted by a controller last frame
  if self.gotInputOnLastFrame == false then
	--self.controlHeld = "none"
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
	self.signalLossTimer = self.signalLossTimout
	
	--After receiving input from our owner, send a message in return to our owner
	if world.entityExists(ownerEntityId) then
	  world.sendEntityMessage(ownerEntityId, "receiveVehicleResponse", self.ownerKey, entity.id())
	end
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
	self.firingOffset[1] = -config.getParameter("firingOffset", {0,0})[1]
  else
	animator.setFlipped(false)
	self.firingOffset[1] = config.getParameter("firingOffset", {0,0})[1]
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
	
  --If the owner holds down secondary fire, perform the altFire move
  if self.controlHeld == "alt" then
	--Charged Fire
	if self.fireMode == "charged" then
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
	--Automatic Fire
	elseif self.fireMode == "auto" then
	  if self.cooldownTimer == 0 then
		local firePosition = vec2.add(mcontroller.position(), self.firingOffset)
		local sourceEntityId = entity.id()
		if self.ownerEntityId and world.entityExists(self.ownerEntityId) then
		  sourceEntityId = self.ownerEntityId
		end
		world.spawnProjectile(self.fireProjectile, firePosition, sourceEntityId, self.aimAngle, false, self.fireProjectileConfig)
		animator.playSound("fire")
		animator.setAnimationState("body", "fire")
		self.cooldownTimer = self.cooldownTime
	  end
	--Flashlight
	elseif self.fireMode == "flashlight" then
	  if not self.flashLightWasToggled then
		self.flashlightActive = not self.flashlightActive
		animator.setLightActive("flashlight", self.flashlightActive)
		animator.playSound("fire")
		if self.flashlightActive then
		  animator.setAnimationState("flashlight", "on")
		else
		  animator.setAnimationState("flashlight", "off")
		end
		self.flashLightWasToggled = true
	  end
	end
  --If not holding altFire, reset certain parameters
  else
	if animator.hasSound("charge") then
	  animator.stopAllSounds("charge")
	end
	self.chargeTimer = self.chargeTime
	self.flashLightWasToggled = false
	self.chargeStarted = false
  end

  --If a flashlight should be active, update its rotation
  if self.flashlightActive then
	local aimAngle = {self.aimAngle[1], self.aimAngle[2]}
	if aimAngle[1] < 0 then
	  aimAngle[1] = aimAngle[1] * -1
	end
	local flashlightAngle = math.atan(aimAngle[2], aimAngle[1]) * 55
	animator.setLightPointAngle("flashlight", flashlightAngle)
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
  world.debugText("Sender Key = " .. sb.printJson(senderKey), vec2.add(mcontroller.position(), {0,3}), "blue")
  world.debugText(" Owner Key = " .. sb.printJson(self.ownerKey), vec2.add(mcontroller.position(), {0,4}), "blue")
  if senderKey == self.ownerKey then
	return true
  else
	return true
  end
end
