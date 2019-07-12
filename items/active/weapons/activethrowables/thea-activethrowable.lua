require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

TheaActiveThrowable = WeaponAbility:new()

function TheaActiveThrowable:init()
  self.weapon:setStance(self.stances.idle)
  animator.setAnimationState("weapon", "visible")
  
  self.consumeItemPromise = false
  self.cooldownTimer = 0
  
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
	animator.setAnimationState("weapon", "visible")
  end
end

function TheaActiveThrowable:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

	self:setState(self.prepare)
  end
end

function TheaActiveThrowable:prepare()
  self.weapon:setStance(self.stances.prepare)
  self.weapon:updateAim()

  if self.stances.prepare.duration then
    util.wait(self.stances.prepare.duration)
  end

  self:setState(self.throw)
end

function TheaActiveThrowable:throw()
  self.weapon:setStance(self.stances.throw)
  self.weapon:updateAim()
  
  if not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
	animator.playSound("throw")
	animator.setAnimationState("weapon", "invisible")
  
	--Set up the item consume behaviour
	self.consumeItemPromise = true
  
	--Set up projectile type
	local projectileType = self.projectileType
	if type(projectileType) == "table" then
	  projectileType = projectileType[math.random(#projectileType)]
	end
  
	--Set up projectile parameters
	local params = self.projectileParameters
	params.power = self.baseDamage / self.projectileCount
	params.powerMultiplier = activeItem.ownerPowerMultiplier()
  
	--For every projectileCount, fire a projectile
	for i = 1, self.projectileCount do
	  if params.timeToLive then
		params.timeToLive = util.randomInRange(params.timeToLive)
	  end
	  params.speed = util.randomInRange(params.speed)

	  world.spawnProjectile(
		projectileType,
		firePosition or self:firePosition(),
		activeItem.ownerEntityId(),
		self:aimVector(self.inaccuracy, i),
		false,
		params
	  )
	end
  
	if self.stances.throw.duration then
	  util.wait(self.stances.throw.duration)
	end
  
	--Consume the item and fulfill our consume promise
	item.consume(self.ammoUsage)
	self.consumeItemPromise = false
  end
  
  self.cooldownTimer = self.cooldownTime
end

function TheaActiveThrowable:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.fireOffset))
end

function TheaActiveThrowable:updateAim()
  self.aimAngle, self.aimDirection = activeItem.aimAngleAndDirection(self.aimOffset, activeItem.ownerAimPosition())
  activeItem.setArmAngle(self.aimAngle)
  activeItem.setFacingDirection(self.aimDirection)
end

function TheaActiveThrowable:aimVector(inaccuracy, shotNumber)
  local aimVector = {}
  if self.angleAdjustmentsPerShot then
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0) + self.angleAdjustmentsPerShot[shotNumber])
  else
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  end
  
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaActiveThrowable:uninit()
  if self.consumeItemPromise then
	item.consume(self.ammoUsage)
	self.consumeItemPromise = false
  end
end
