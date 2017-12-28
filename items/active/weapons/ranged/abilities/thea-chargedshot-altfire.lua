require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Bow primary ability
TheaChargedShotAltFire = WeaponAbility:new()

function TheaChargedShotAltFire:init()

  self.chargeTimer = self.chargeTime
  self.cooldownTimer = self.cooldownTime
  
  self.chargeHasStarted = false
  self.shouldDischarge = false

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaChargedShotAltFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  --If holding fire, and nothing is holding back the charging process
  if self.fireMode == "alt"
    and not self.weapon.currentAbility
	and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
	and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    self:setState(self.charge)
  --If the charge was prematurily stopped or interrupted somehow
  elseif self.chargeHasStarted == true and (self.fireMode ~= "alt" or world.lineTileCollision(mcontroller.position(), self:firePosition())) then
    animator.stopAllSounds("chargeLoopAlt")
	animator.setAnimationState("chargeAlt", "off")
	animator.setParticleEmitterActive("chargeparticlesAlt", false)
	self.chargeTimer = self.chargeTime
  end

end

function TheaChargedShotAltFire:charge()
  self.weapon:setStance(self.stances.charge)
  
  self.chargeHasStarted = true

  animator.playSound("chargeLoopAlt", -1)
  animator.setAnimationState("chargeAlt", "charging")
  animator.setParticleEmitterActive("chargeparticlesAlt", true)
  
  --While charging, but not yet ready, count down the charge timer
  while self.chargeTimer > 0 and self.fireMode == (self.activatingFireMode or self.abilitySlot) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) do
    self.chargeTimer = math.max(0, self.chargeTimer - self.dt)

	--Prevent energy regen while charging
	status.setResourcePercentage("energyRegenBlock", 0.6)
	
	--Enable walk while firing
	if self.walkWhileFiring == true then
      mcontroller.controlModifiers({runningSuppressed=true})
	end

    coroutine.yield()
  end
  
  --If the charge is ready, we have line of sight and plenty of energy, go to firing state
  if self.chargeTimer == 0 and status.overConsumeResource("energy", self:energyPerShot()) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    self:setState(self.fire)
  --If not charging and charge isn't ready, go to cooldown
  else
    self.shouldDischarge = true
	animator.playSound("dischargeAlt")
    self:setState(self.cooldown)
  end
end

function TheaChargedShotAltFire:fire()
  self.weapon:setStance(self.stances.fire)
  
  animator.stopAllSounds("chargeLoopAlt")
  animator.setAnimationState("chargeAlt", "off")
  animator.setParticleEmitterActive("chargeparticlesAlt", false)
  
  self.chargeHasStarted = false
  
  --Fire a projectile and show a muzzleflash, then continue on with this state
  self:fireProjectile()
  self:muzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.chargeTimer = self.chargeTime
  
  self.cooldownTimer = self.cooldownTime
  self:setState(self.cooldown)
end

function TheaChargedShotAltFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
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
  
  local shotNumber = 0

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end
	
	shotNumber = i

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(self.inaccuracy, shotNumber),
        false,
        params
      )
	
	--If the ability config has this set to true, then the projectile fired will align with the player's aimVector shortly after being fired (as in the Rocket Burst ability) 
	if self.alignProjectiles then
	  world.callScriptedEntity(projectileId, "setApproach", self:aimVector(0, 1))
	end
  end
  
  return projectileId
end

function TheaChargedShotAltFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fireAlt")

  animator.setLightActive("muzzleFlash", true)
end

function TheaChargedShotAltFire:cooldown()
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

function TheaChargedShotAltFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaChargedShotAltFire:aimVector(inaccuracy, shotNumber)
  local angleAdjustmentList = self.angleAdjustmentsPerShot or {}
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0) + (angleAdjustmentList[shotNumber] or 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaChargedShotAltFire:energyPerShot()
  return self.baseEnergyUsage * (self.energyUsageMultiplier or 1.0)
end

function TheaChargedShotAltFire:damagePerShot()
  return self.baseDamage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function TheaChargedShotAltFire:uninit()
  self:reset()
end

function TheaChargedShotAltFire:reset()
  animator.setAnimationState("chargeAlt", "off")
  animator.setParticleEmitterActive("chargeparticlesAlt", false)
  self.chargeHasStarted = false
  self.weapon:setStance(self.stances.idle)
end