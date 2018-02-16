require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

SpearThrow = WeaponAbility:new()

function SpearThrow:init()
  self:reset()
  
  self.projectileGravityMultiplier = root.projectileGravityMultiplier(self.projectileType)
end

function SpearThrow:update(dt, fireMode, shiftHeld)
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

function SpearThrow:windup()
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

function SpearThrow:aiming()
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

function SpearThrow:fire()
  self.weapon:setStance(self.stances.fire)
  
  if not world.pointTileCollision(self:firePosition()) and status.overConsumeResource("energy", self.energyPerShot) then
    local params = copy(self.projectileParameters)
	params.power = params.power * config.getParameter("damageLevelMultiplier")
    params.powerMultiplier = activeItem.ownerPowerMultiplier()

    self.spearProjectile = world.spawnProjectile(
	  self.projectileType,
	  self:firePosition(),
	  activeItem.ownerEntityId(),
	  self:idealAimVector(),
	  false,
	  params
	)

	--Play the throwing sound and hide the weapon using animation states
    animator.playSound("throw")
	animator.setAnimationState("weapon", "hidden")

    self.windupTimer = 0

    util.wait(self.stances.fire.duration)
  end
  
  if self.spearProjectile then
    self:setState(self.cooldown)
  end
end

function SpearThrow:cooldown()
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  self.weapon:setStance(self.stances.cooldown)
  
  while world.entityExists(self.spearProjectile) do
    world.debugText("Active projectiles detected!", mcontroller.position(), "yellow")
	activeItem.setHoldingItem(false)
    coroutine.yield()
  end
  
  --Return the weapon to the player's hand
  animator.setAnimationState("weapon", "returning")
  activeItem.setHoldingItem(true)
end

function SpearThrow:idealAimVector()
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

function SpearThrow:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function SpearThrow:reset()
  self.windupTimer = self.windupTime
  self.cooldownTimer = self.cooldownTime
  if animator.animationState("weapon") ~= "visible" then
	--Return the weapon to the player's hand
	animator.setAnimationState("weapon", "returning")
  end
end

function SpearThrow:uninit()
  if self.spearProjectile then
	world.sendEntityMessage(self.spearProjectile, "kill")
  end
  self:reset()
end
