require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Bow primary ability
TheaLineRifleAltFire = WeaponAbility:new()

function TheaLineRifleAltFire:init()

  self.chargeTimer = self.chargeTime
  self.cooldownTimer = self.cooldownTime
  
  self.chargeHasStarted = false
  self.shouldDischarge = false

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaLineRifleAltFire:update(dt, fireMode, shiftHeld)
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

function TheaLineRifleAltFire:charge()
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
	
	--Calculate how far into the charge we are. Do 1 - X because we count from 1 to 0, not 0 to 1
	local chargePercentage = 1 - (self.chargeTimer / self.chargeTime)
	--Update the lightning charge level. This function also call the draw lightning code
	self.chargeLevel = self:setChargeLevel(chargePercentage, self.chargeLevel)
	
    coroutine.yield()
  end
  
  --If the charge is ready, we have line of sight and plenty of energy, go to firing state
  if self.chargeTimer == 0 and status.overConsumeResource("energy", self:energyPerShot()) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    self:setState(self.fire)
  --If not charging and charge isn't ready, go to cooldown
  else
    self.shouldDischarge = true
	animator.playSound("discharge")
    self:setState(self.cooldown)
  end
end

function TheaLineRifleAltFire:fire()
  self.weapon:setStance(self.stances.fire)
  
  animator.stopAllSounds("chargeLoopAlt")
  animator.setAnimationState("chargeAlt", "off")
  animator.setParticleEmitterActive("chargeparticlesAlt", false)
  
  self.chargeHasStarted = false
  
  --Disable the lightning animation
  activeItem.setScriptedAnimationParameter("lightning", {})
  
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

function TheaLineRifleAltFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
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
  end
  return projectileId
end

function TheaLineRifleAltFire:setChargeLevel(chargePercentage, currentLevel)
  local level = math.ceil(chargePercentage * self.chargeLevels)
  if currentLevel < level then
    local lightningCharge = self.lightningChargeLevels[level]
    self:setLightning(lightningCharge[1], lightningCharge[2], lightningCharge[3], lightningCharge[4], lightningCharge[5], lightningCharge[6], lightningCharge[7])
  end
  return level
end

function TheaLineRifleAltFire:setLightning(amount, width, forks, displacement, color, startOffset, endOffset)
  local lightning = {}
  for i = 1, amount do
    local bolt = {
      minDisplacement = 0.125,
      forks = forks,
      forkAngleRange = 0.75,
      width = width,
	  displacement = displacement,
      color = color
    }	
	bolt.itemStartPosition = vec2.add(self.weapon.muzzleOffset, startOffset)
	bolt.itemEndPosition = vec2.add(self.weapon.muzzleOffset, endOffset)
    table.insert(lightning, bolt)
  end
  activeItem.setScriptedAnimationParameter("lightning", lightning)
end

function TheaLineRifleAltFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fireAlt")

  animator.setLightActive("muzzleFlash", true)
end

function TheaLineRifleAltFire:cooldown()
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

function TheaLineRifleAltFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaLineRifleAltFire:aimVector(inaccuracy, shotNumber)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0) + self.angleAdjustmentsPerShot[shotNumber])
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaLineRifleAltFire:energyPerShot()
  return self.baseEnergyUsage * (self.energyUsageMultiplier or 1.0)
end

function TheaLineRifleAltFire:damagePerShot()
  return self.baseDamage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function TheaLineRifleAltFire:uninit()
  self:reset()
end

function TheaLineRifleAltFire:reset()
  animator.setAnimationState("chargeAlt", "off")
  
  --Reset the lightning charge level
  self.chargeLevel = 0
  
  animator.setParticleEmitterActive("chargeparticlesAlt", false)
  activeItem.setScriptedAnimationParameter("lightning", {})
  self.chargeHasStarted = false
  self.weapon:setStance(self.stances.idle)
end