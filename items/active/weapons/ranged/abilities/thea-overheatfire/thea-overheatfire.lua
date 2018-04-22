require "/scripts/util.lua"
require "/scripts/interp.lua"

--Modified gunfire behaviour. Doesn't consume energy when firing, but increases the weapon's heat value. If it goes past a threshold, the weapon overheats and must cool down before being used again

-- Base gun fire ability
TheaOverheatFire = WeaponAbility:new()

function TheaOverheatFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  self.heat = config.getParameter("heat", 0)
  self.overheated = config.getParameter("overheated", false)
  self.idleTimer = 0
  
  animator.setParticleEmitterActive("venting", self.overheated)

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function TheaOverheatFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.idleTimer = math.min(self.coolingIdleTime, self.idleTimer + self.dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  --Determine target animation state based on current heat value
  if self.heat >= self.overheatThreshold then
	self.overheated = true
	activeItem.setInstanceValue("overheated", true)
  elseif self.heat >= self.hotThreshold and not self.overheated then
	animator.setAnimationState("weapon", "hot")
  elseif self.heat >= self.mediumThreshold and not self.overheated then
	animator.setAnimationState("weapon", "medium")
  elseif self.heat >= self.coolThreshold and not self.overheated then
	animator.setAnimationState("weapon", "cool")
  else
	animator.setAnimationState("weapon", "idle")
  end
  
  --Passive cooling while not overheated
  if self.idleTimer == self.coolingIdleTime and not self.overheated then
	self.heat = math.max(0, self.heat - (self.heatLossRate * self.dt))
	activeItem.setInstanceValue("heat", self.heat)
  end
  
  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not self.overheated
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    if self.fireType == "auto" then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  elseif self.overheated then
	self:setState(self.overheat)
  end
  
  world.debugText(self.heat, mcontroller.position(), "red")
  world.debugText(self.idleTimer, vec2.add(mcontroller.position(), {0,1}), "red")
  world.debugText(sb.printJson(self.overheated), vec2.add(mcontroller.position(), {0,2}), "red")
end

function TheaOverheatFire:auto()
  self.weapon:setStance(self.stances.fire)

  self:fireProjectile()
  self:muzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function TheaOverheatFire:burst()
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 do
    self:fireProjectile()
    self:muzzleFlash()
    shots = shots - 1

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
end

function TheaOverheatFire:cooldown()
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

function TheaOverheatFire:overheat()
  self.weapon:setStance(self.stances.overheat)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0

  while self.heat > 0 do
	animator.setParticleEmitterActive("venting", true)
	animator.setAnimationState("weapon", "overheated")
  
	self.heat = math.max(0, self.heat - (self.heatLossRateOverheated * self.dt))
	activeItem.setInstanceValue("heat", self.heat)
	coroutine.yield()
  end
  
  self.overheated = false
  activeItem.setInstanceValue("overheated", false)
  animator.setParticleEmitterActive("venting", false)
end

function TheaOverheatFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function TheaOverheatFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  --Increase heat
  self.heat = self.heat + self.heatPerShot
  activeItem.setInstanceValue("heat", self.heat)
  self.idleTimer = 0
  
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

function TheaOverheatFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaOverheatFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaOverheatFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function TheaOverheatFire:uninit()
end
