require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Base gun fire ability
TheaAccuracyGunFire = WeaponAbility:new()

function TheaAccuracyGunFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  self.inaccuracy = self.startInaccuracy
  self.timeSpentFiring = 0
  self.fireTimeFactor = 0
  self.idleTime = self.maxIdleTime
  
  activeItem.setCursor(self.cursorFrames[1])

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function TheaAccuracyGunFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end
  
  --Code for calculating the current accuracy, based on time spent firing
  self.fireTimeFactor = self.timeSpentFiring / self.maxAccuracyTime
  if mcontroller.walking() or mcontroller.running() or mcontroller.jumping() or mcontroller.falling() or mcontroller.flying() then
	--world.debugText("MOVING!", mcontroller.position(), "red")
	--While moving, limit the maximum accuracy of the weapon
	self.fireTimeFactor = math.min(self.fireTimeFactor, self.movementAccuracyLimit)
  end
  self.inaccuracy = self.startInaccuracy - (self.fireTimeFactor * (self.startInaccuracy - self.finalInaccuracy))
  
  --Code for calculating which cursor to use
  local cursorFrame = math.max(math.ceil(self.fireTimeFactor * #self.cursorFrames), 1)
  activeItem.setCursor(self.cursorFrames[cursorFrame])
  
  --world.debugText(cursorFrame, mcontroller.position(), "red")
  world.debugText(self.fireTimeFactor, mcontroller.position(), "red")

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
	
	--While firing, prevent the idle timer from going up
	self.idleTime = 0

    if self.fireType == "auto" and status.overConsumeResource("energy", self:energyPerShot()) then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  else
	self.idleTime = math.min(self.maxIdleTime, self.idleTime + self.dt)
  end
  
  --If idle for too long, start degrading accuracy
  if self.idleTime == self.maxIdleTime then
	self.timeSpentFiring = math.max(0, self.timeSpentFiring - self.dt)
  --If not idle, then start increasing accuracy
  else
	if mcontroller.crouching() then
	  self.timeSpentFiring = math.min(self.maxAccuracyTime, self.timeSpentFiring + (self.dt * self.crouchIncreaseVector))
	else
	  self.timeSpentFiring = math.min(self.maxAccuracyTime, self.timeSpentFiring + self.dt)
	end
  end
end

function TheaAccuracyGunFire:auto()
  self.weapon:setStance(self.stances.fire)

  self:fireProjectile()
  self:muzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function TheaAccuracyGunFire:burst()
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 and status.overConsumeResource("energy", self:energyPerShot()) do
    self:fireProjectile()
    self:muzzleFlash()
    shots = shots - 1

	local adjustedWeaponRotation = self.stances.fire.weaponRotationMax - (self.fireTimeFactor * (self.stances.fire.weaponRotationMax - self.stances.fire.weaponRotationMin))
	local adjustedArmRotation = self.stances.fire.armRotationMax - (self.fireTimeFactor * (self.stances.fire.armRotationMax - self.stances.fire.armRotationMin))
	
    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, adjustedWeaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, adjustedArmRotation))

    util.wait(self.burstTime)
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
end

function TheaAccuracyGunFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}
	
	local adjustedWeaponRotation = self.stances.cooldown.weaponRotationMax - (self.fireTimeFactor * (self.stances.cooldown.weaponRotationMax - self.stances.cooldown.weaponRotationMin))
	local adjustedArmRotation = self.stances.cooldown.armRotationMax - (self.fireTimeFactor * (self.stances.cooldown.armRotationMax - self.stances.cooldown.armRotationMin))

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, adjustedWeaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, adjustedArmRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

function TheaAccuracyGunFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function TheaAccuracyGunFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function TheaAccuracyGunFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaAccuracyGunFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaAccuracyGunFire:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function TheaAccuracyGunFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function TheaAccuracyGunFire:uninit()
end
