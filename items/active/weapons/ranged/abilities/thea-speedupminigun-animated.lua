require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

TheaSpeedUpMinigunAnimated = WeaponAbility:new()

function TheaSpeedUpMinigunAnimated:init()
  self.weapon:setStance(self.stances.idle)
  
  animator.setAnimationState("weapon", "idle")
  animator.setAnimationState("charge", "off")
  animator.setGlobalTag("transitionFrame", "0")

  self.timeSpentFiring = 0
  self.adjustedFireTime = self.minFiringSpeed
  self.cooldownTimer = 0
  self.resetTimer = self.resetTime
  
  self.transitionFrame = 0
  self.transitionTimer = 0
  self.transitionProgress = 0
  
  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaSpeedUpMinigunAnimated:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  --If the weapon is opened, count down the reset timer and gradually increase rate of fire
  if self.transitionProgress == 1 then
	animator.setAnimationState("weapon", "fire")
	
	if self.fireMode == (self.activatingFireMode or self.abilitySlot) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
	  self.timeSpentFiring = math.min(self.maxFiringTime, self.timeSpentFiring + self.dt)
	  self.fireSpeedFactor = self.timeSpentFiring / self.maxFiringTime
	  self.adjustedFireTime = self.minFiringSpeed - (self.fireSpeedFactor * (self.minFiringSpeed - self.maxFiringSpeed))
	  world.debugText("FIRING", vec2.add(mcontroller.position(), {0,2}), "red")
	else
	  self.resetTimer = math.max(0, self.resetTimer - self.dt)
	  world.debugText("RESETTING", vec2.add(mcontroller.position(), {0,2}), "red")
	end
	
	if self.resetTimer == 0 then
	  self:setState(self.closeWeapon)
	end
  else
	self.timeSpentFiring = math.max(0, self.timeSpentFiring - (self.dt * self.decayMultiplier))
	self.fireSpeedFactor = self.timeSpentFiring / self.maxFiringTime
	self.adjustedFireTime = self.minFiringSpeed - (self.fireSpeedFactor * (self.minFiringSpeed - self.maxFiringSpeed))
  end
  
  --Optionally animate a charge
  if self.animatedCharge and self.transitionProgress > 0 then
	animator.setAnimationState("charge", "active")
  end
  
  world.debugText("Time Until Reset:  " .. self.resetTimer, vec2.add(mcontroller.position(), {0,1}), "yellow")
  world.debugText("Time Spent Firing: " .. self.timeSpentFiring, vec2.add(mcontroller.position(), {0,0}), "yellow")

  --If holding fire, and nothing is holding back the charging process
  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
	and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
	and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    self:setState(self.openWeapon)
  elseif world.lineTileCollision(mcontroller.position(), self:firePosition()) and self.transitionProgress < 1 then
	self:setState(self.closeWeapon)
  end
end

function TheaSpeedUpMinigunAnimated:openWeapon()
  animator.setAnimationState("weapon", "transition")
  
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) and self.transitionProgress < 1 do
	self.transitionTimer = math.min(self.transitionTime, self.transitionTimer + self.dt)
	self.transitionProgress = self.transitionTimer / self.transitionTime
	self.transitionFrame = math.floor(self.transitionProgress * self.transitionFrames)
	animator.setGlobalTag("transitionFrame", self.transitionFrame)
	
	--Prevent energy regen while opening
	status.setResourcePercentage("energyRegenBlock", 0.6)
	
	world.debugText("OPENING", vec2.add(mcontroller.position(), {0,2}), "red")
	
    coroutine.yield()
  end
  
  if self.transitionProgress == 1 and not world.lineTileCollision(mcontroller.position(), self:firePosition()) and status.overConsumeResource("energy", self:energyPerShot()) then
	self:setState(self.fire)
  elseif world.lineTileCollision(mcontroller.position(), self:firePosition()) then
	--Do nothing
  else
	self:setState(self.closeWeapon)
  end
end

function TheaSpeedUpMinigunAnimated:closeWeapon()
  animator.setAnimationState("weapon", "transition")
  
  while self.transitionProgress > 0 do
	if self.fireMode == (self.activatingFireMode or self.abilitySlot) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
      self:setState(self.openWeapon)
      return true
    end
	
	self.transitionTimer = math.max(0, self.transitionTimer - self.dt)
	self.transitionProgress = self.transitionTimer / self.transitionTime
	self.transitionFrame = math.floor(self.transitionProgress * self.transitionFrames)
	animator.setGlobalTag("transitionFrame", self.transitionFrame)
	
	world.debugText("CLOSING", vec2.add(mcontroller.position(), {0,2}), "red")
	
    coroutine.yield()
  end
  
  if self.transitionProgress == 0 then
	animator.setAnimationState("weapon", "idle")
  end
end

function TheaSpeedUpMinigunAnimated:fire()
  self.weapon:setStance(self.stances.fire)
  
  --Fire a projectile and show a muzzleflash, then continue on with this state
  self:fireProjectile()
  self:muzzleFlash()
  self.resetTimer = self.resetTime

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end
  
  self.cooldownTimer = self.adjustedFireTime
  self:setState(self.cooldown)
end

function TheaSpeedUpMinigunAnimated:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
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

function TheaSpeedUpMinigunAnimated:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function TheaSpeedUpMinigunAnimated:cooldown()
  if self.shouldDischarge == true then
    self.weapon:updateAim()
	self.weapon:setStance(self.stances.discharge)
	self.shouldDischarge = false
	
	local progress = 0
    util.wait(self.stances.discharge.duration, function()
      local from = self.stances.discharge.weaponOffset or {0,0}
      local to = self.stances.idle.weaponOffset or {0,0}
      self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

      self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.discharge.weaponRotation, self.stances.idle.weaponRotation))
      self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.discharge.armRotation, self.stances.idle.armRotation))

      progress = math.min(1.0, progress + (self.dt / self.stances.discharge.duration))
    end)
  else
    self.weapon:updateAim()
	self.weapon:setStance(self.stances.cooldown)
	
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
end

function TheaSpeedUpMinigunAnimated:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaSpeedUpMinigunAnimated:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaSpeedUpMinigunAnimated:energyPerShot()
  return self.energyUsage * self.minFiringSpeed * (self.energyUsageMultiplier or 1.0)
end

function TheaSpeedUpMinigunAnimated:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.minFiringSpeed)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function TheaSpeedUpMinigunAnimated:uninit()
  self:reset()
end

function TheaSpeedUpMinigunAnimated:reset()
  self.weapon:setStance(self.stances.idle)
end