require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

TheaZaheedThrow = WeaponAbility:new()

function TheaZaheedThrow:init()
  self:reset()
  
  self.targetPosition = nil
  
  self.projectileGravityMultiplier = root.projectileGravityMultiplier(self.projectileType)
end

function TheaZaheedThrow:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  if not self.weapon.currentAbility
	and self.fireMode == (self.activatingFireMode or self.abilitySlot)
	and self.cooldownTimer == 0
	and self.windupTimer > 0
	and not status.resourceLocked("energy") then
	  self:setState(self.windup)
  end
end

function TheaZaheedThrow:windup()
  self.weapon:updateAim()

  while self.windupTimer > 0 and self.fireMode == (self.activatingFireMode or self.abilitySlot) do
	
	self.windupTimer = math.max(0, self.windupTimer - self.dt)
	activeItem.emote("sleep")

	if self.walkWhileFiring then mcontroller.controlModifiers({runningSuppressed = true}) end

	--Force the aim angle into a set position
	self.weapon.aimAngle = 0
	self.weapon:setStance(self.stances.windup)
    coroutine.yield()
  end
  
  self:setState(self.aiming)
end

function TheaZaheedThrow:aiming()
  if self.windupTimer == 0 then
	self.weapon:setStance(self.stances.aiming)
	activeItem.emote("annoyed")
  end
  
  --While holding the mouse button, update our aim and wait for player to release
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.windupTimer == 0 do
    --Code from zenshot.lua for doing a ballistic aim towards the mouse position
	local aimVec = self:idealAimVector()
    aimVec[1] = aimVec[1] * self.weapon.aimDirection
    self.weapon.aimAngle = (4 * self.weapon.aimAngle + vec2.angle(aimVec)) / 5
	
	if self.walkWhileFiring then mcontroller.controlModifiers({runningSuppressed = true}) end
	
	coroutine.yield()
  end
  
  if self.windupTimer == 0 then
	self:setState(self.fire)
  else
    self:reset()
  end
end

function TheaZaheedThrow:fire()
  self.weapon:setStance(self.stances.fire)
  
  if not world.pointTileCollision(self:firePosition()) and status.overConsumeResource("energy", self.energyPerShot) then
    local params = copy(self.projectileParameters)
	params.power = params.power * config.getParameter("damageLevelMultiplier")
    params.powerMultiplier = activeItem.ownerPowerMultiplier()

    self.swordProjectile = world.spawnProjectile(
	  self.projectileType,
	  self:firePosition(),
	  activeItem.ownerEntityId(),
	  self:idealAimVector(),
	  false,
	  params
	)

	--Play the throwing sound and hide the weapon using animation states
    animator.playSound("throw")
	animator.setAnimationState("blade", "hidden")

    self.windupTimer = 0
  end
  
  if self.swordProjectile then
    self:setState(self.cooldown)
  end
end

function TheaZaheedThrow:cooldown()
  
  while world.entityExists(self.swordProjectile) do
    --Arm animation
	self.throwingAnimationTimer = math.max(0, self.throwingAnimationTimer - self.dt)
	
	if self.throwingAnimationTimer == 0 then
	  self.weapon:updateAim()
	  self.weapon.aimAngle = 0
	  self.weapon:setStance(self.stances.cooldown)
	end
	
	world.debugText("Active projectiles detected!", mcontroller.position(), "yellow")
	
	self.targetPosition = world.entityPosition(self.swordProjectile)
	
	--Make sure we don't wait don't wait too long, and kill the projectile otherwise
	self.waitTimer = math.max(0, self.waitTimer - self.dt)
	if self.waitTimer == 0 then
	  if self.swordProjectile then
		world.sendEntityMessage(self.swordProjectile, "kill")
		--self.targetPosition = nil
	  end
	end
    coroutine.yield()
  end
  
  --Make sure the arm position is reset correctly
  self.weapon:updateAim()
  self.weapon.aimAngle = 0
  self.weapon:setStance(self.stances.cooldown)
  
  --Attempt to teleport the player
  self:setState(self.attemptTeleport)
  
  --Return the weapon to the player's hand
  animator.setAnimationState("blade", "returning")
end

function TheaZaheedThrow:attemptTeleport()
  if self.targetPosition ~= nil then
	local lastPosition = mcontroller.position()
	local resolvedPoint = world.resolvePolyCollision(mcontroller.collisionPoly(), vec2.add(self.targetPosition, self.teleportOffset), self.teleportTolerance)
	if resolvedPoint and self.targetPosition ~= nil then
	  --The target position is valid for teleportation, now check if it isn't too far away
	  if world.magnitude(mcontroller.position(), resolvedPoint) <= self.maxTeleportDistance then
		world.debugText("We got teleported!", self.targetPosition, "green")
		world.debugPoint(resolvedPoint, "orange")
		
		--Create a teleport out effect at our last position
		world.spawnProjectile("zaheedsword-teleportout", lastPosition)
		
		--Create the teleportation effect
		status.addEphemeralEffect("zaheedteleport")
		
		--Make the player immune to damage upon teleport
		status.addEphemeralEffect("invulnerable", 0.5)
		
		--Increase the player's power 
		status.addEphemeralEffect("zaheedpower")
		
		--Reset player momentum, prevents fall damage
		mcontroller.setXVelocity(0,0)
		mcontroller.setYVelocity(0,0)
		mcontroller.setPosition(resolvedPoint)
	  end
	else
	  --The teleport failed
	  world.debugText("Teleportation failed!", self.targetPosition, "red")
	end
  end
  
  --Return the weapon to the player's hand
  animator.setAnimationState("blade", "returning")
end

function TheaZaheedThrow:idealAimVector()
  --If we are at a zero G position, use regular aiming instead of arc-adjusted aiming
  if mcontroller.zeroG() then
	local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle)
	aimVector[1] = aimVector[1] * mcontroller.facingDirection()
	return aimVector
  else
	local targetOffset = world.distance(activeItem.ownerAimPosition(), self:firePosition())
	return util.aimVector(targetOffset, self.projectileParameters.speed, self.projectileGravityMultiplier, false)
  end
end

function TheaZaheedThrow:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function TheaZaheedThrow:reset()
  self.windupTimer = self.windupTime
  self.cooldownTimer = self.cooldownTime
  self.waitTimer = self.maxWaitTime
  self.throwingAnimationTimer = self.stances.fire.duration
  self.targetPosition = nil
  if animator.animationState("blade") == "hidden" then
	--Return the weapon to the player's hand
	animator.setAnimationState("blade", "returning")
  end
end

function TheaZaheedThrow:uninit()
  if self.swordProjectile then
	world.sendEntityMessage(self.swordProjectile, "kill")
  end
  self:reset()
end
