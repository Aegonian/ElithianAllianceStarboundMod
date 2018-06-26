require "/items/active/weapons/melee/abilities/spear/spearthrow/spearthrow.lua"

TheaZaheedThrow = SpearThrow:new()

function TheaZaheedThrow:fire()
  self.weapon:setStance(self.stances.fire)
  
  if not world.pointTileCollision(self:firePosition()) and status.overConsumeResource("energy", self.energyPerShot) then
    local params = copy(self.projectileParameters)
	params.power = params.power * config.getParameter("damageLevelMultiplier")
    params.powerMultiplier = activeItem.ownerPowerMultiplier()

    self.thrownProjectile = world.spawnProjectile(
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
	
	util.wait(self.stances.fire.duration, function()	  
	  if world.entityExists(self.thrownProjectile) then
		world.debugText("Active projectiles detected!", mcontroller.position(), "green")
		self.targetPosition = world.entityPosition(self.thrownProjectile)
	  else
		--Return the weapon to the player's hand
		animator.setAnimationState("blade", "returning")
		
		--Attempt to teleport the player
		self:setState(self.attemptTeleport)
	  end
	end)
  end
  
  if self.thrownProjectile then
    self:setState(self.cooldown)
  end
end

function TheaZaheedThrow:cooldown()
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  self.weapon:setStance(self.stances.cooldown)
  
  while world.entityExists(self.thrownProjectile) do	
	world.debugText("Active projectiles detected!", mcontroller.position(), "green")
	
	self.targetPosition = world.entityPosition(self.thrownProjectile)
	
	--Make sure we don't wait don't wait too long, and kill the projectile otherwise
	self.waitTimer = math.max(0, self.waitTimer - self.dt)
	if self.waitTimer == 0 then
	  if self.thrownProjectile then
		world.sendEntityMessage(self.thrownProjectile, "kill")
		--self.targetPosition = nil
	  end
	end
	
	activeItem.setHoldingItem(false)
    coroutine.yield()
  end
  
  --Make sure the arm position is reset correctly
  self.weapon:updateAim()
  self.weapon.aimAngle = 0
  self.weapon:setStance(self.stances.cooldown)
  
  --Return the weapon to the player's hand
  animator.setAnimationState("blade", "returning")
  activeItem.setHoldingItem(true)
  
  --Attempt to teleport the player
  self:setState(self.attemptTeleport)
end

function TheaZaheedThrow:attemptTeleport()
  world.debugText("Attempting teleport!", mcontroller.position(), "yellow")

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
  self:reset(true)
end

function TheaZaheedThrow:reset(forceCooldown)
  self.windupTimer = self.windupTime
  if forceCooldown then
	self.cooldownTimer = self.cooldownTime
  end
  self.waitTimer = self.maxWaitTime
  self.targetPosition = nil
  if animator.animationState("blade") == "hidden" then
	--Return the weapon to the player's hand
	animator.setAnimationState("blade", "returning")
  end
end