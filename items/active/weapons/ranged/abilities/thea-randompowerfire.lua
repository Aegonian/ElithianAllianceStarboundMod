require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Base gun fire ability
RandomPowerFire = WeaponAbility:new()

function RandomPowerFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function RandomPowerFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
    animator.setLightActive("powerMuzzleFlash", false)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    if self.fireType == "auto" and status.overConsumeResource("energy", self:energyPerShot()) then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end
end

-- ========================================= FIRING TYPES =========================================
function RandomPowerFire:auto()
  local number = math.random()
  if number <= self.powerProjectileChance then
	self.weapon:setStance(self.stances.powerFire)
	
	self:firePowerProjectile()
	self:powerMuzzleFlash()

	if self.stances.powerFire.duration then
	  util.wait(self.stances.powerFire.duration)
	end
  else
	self.weapon:setStance(self.stances.fire)
	
	self:fireProjectile()
	self:muzzleFlash()

	if self.stances.fire.duration then
	  util.wait(self.stances.fire.duration)
	end
  end

  self.cooldownTimer = self.fireTime
  if number <= self.powerProjectileChance then
	self:setState(self.powerCooldown)
  else
	self:setState(self.cooldown)
  end
end

function RandomPowerFire:burst()
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 and status.overConsumeResource("energy", self:energyPerShot()) do
    self:fireProjectile()
    self:muzzleFlash()
    shots = shots - 1

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
end

-- ========================================= COOLDOWNS =========================================
function RandomPowerFire:powerCooldown()
  self.weapon:setStance(self.stances.powerCooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.powerCooldown.duration, function()
    local from = self.stances.powerCooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.powerCooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.powerCooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.powerCooldown.duration))
  end)
end

function RandomPowerFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

-- ========================================= MUZZLE FLASHES =========================================
function RandomPowerFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function RandomPowerFire:powerMuzzleFlash()
  animator.setPartTag("powerMuzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "powerFire")
  animator.burstParticleEmitter("powerMuzzleFlash")
  animator.playSound("powerFire")

  animator.setLightActive("powerMuzzleFlash", true)
end

-- ========================================= PROJECTILE FIRING =========================================
function RandomPowerFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
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
	  self:aimVector(inaccuracy or self.inaccuracy),
	  false,
	  params
	)
  end
  return projectileId
end

function RandomPowerFire:firePowerProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.powerProjectileParameters, projectileParams or {})
  params.power = self:damagePerShot() * self.powerProjectileDamageMultiplier
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.powerProjectileType
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
	  self:aimVector(inaccuracy or self.inaccuracy),
	  false,
	  params
	)
  end
  return projectileId
end

-- ========================================= GENERAL UTILITIES =========================================
function RandomPowerFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function RandomPowerFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function RandomPowerFire:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function RandomPowerFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function RandomPowerFire:uninit()
end
