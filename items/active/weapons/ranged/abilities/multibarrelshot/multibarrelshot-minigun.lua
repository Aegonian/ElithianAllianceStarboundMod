require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

-- Bow primary ability
MultiBarrelShotMinigun = WeaponAbility:new()

function MultiBarrelShotMinigun:init()

  self.chargeTimer = self.chargeTime
  self.cooldownTimer = self.fireTime
  
  self.chargeHasStarted = false
  self.shouldDischarge = false
  self.windupReady = false
  
  self.chargeSoundIsPlaying = false
  self.holdSoundIsPlaying = false
  
  self.currentBarrel = 1
  self.firePosition1 = self.primaryFiringOffset
  self.firePosition2 = self.secondaryFiringOffset
  
  self.resetTimer = self.resetTime

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function MultiBarrelShotMinigun:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  --If holding fire, and nothing is holding back the charging process
  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
	and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
	and not world.lineTileCollision(mcontroller.position(), self:firePositionDefault()) then

    self:setState(self.charge)
	
  --Count down the reset timer (how long the charge remains after the player stops firing)
  elseif self.windupReady == true and (self.fireMode ~= (self.activatingFireMode or self.abilitySlot) or world.lineTileCollision(mcontroller.position(), self:firePositionDefault())) then
    self.resetTimer = math.max(0, self.resetTimer - self.dt)
	--If the reset timer hits zero
	if self.resetTimer == 0 then
	  animator.stopAllSounds("holdLoop")
	  self.holdSoundIsPlaying = false
	  self.chargeSoundIsPlaying = false
	  self.chargeHasStarted = false
	  self.windupReady = false
	  animator.setAnimationState("charge", "off")
	  animator.setAnimationState("chargehold", "off")
	  self.chargeTimer = self.chargeTime
	  self.resetTimer = self.resetTime
	end
	
  --If we run out of energy while firing
  elseif self.windupReady == true and status.resourceLocked("energy") then
    animator.stopAllSounds("holdLoop")
	self.holdSoundIsPlaying = false
	self.chargeSoundIsPlaying = false
	self.chargeHasStarted = false
	self.windupReady = false
	animator.setAnimationState("charge", "off")
	animator.setAnimationState("chargehold", "off")
	self.chargeTimer = self.chargeTime
	self.resetTimer = self.resetTime
  
  --If the charge was prematurily stopped or somehow interrupted
  elseif self.chargeHasStarted == true and (self.fireMode ~= (self.activatingFireMode or self.abilitySlot) or world.lineTileCollision(mcontroller.position(), self:firePositionDefault())) then
    animator.stopAllSounds("chargeLoop")
	self.chargeSoundIsPlaying = false
	animator.setAnimationState("charge", "off")
	self.chargeTimer = self.chargeTime
  end
  
  --Movement suppressor
  if self.walkWhileFiring == true and (self.chargeHasStarted == true or self.windupReady == true) then
    mcontroller.controlModifiers({runningSuppressed=true})
  end
  
  --Charge/hold animation manager
  if self.chargeHasStarted == true then
    animator.setAnimationState("charge", "charging")
  elseif self.windupReady == true then
    animator.setAnimationState("chargehold", "on")
  end
end

function MultiBarrelShotMinigun:charge()
  self.weapon:setStance(self.stances.charge)
  
  --While charging, but not yet ready, count down the charge timer
  while self.chargeTimer > 0 and self.fireMode == (self.activatingFireMode or self.abilitySlot) and not world.lineTileCollision(mcontroller.position(), self:firePositionDefault()) do
    self.chargeTimer = math.max(0, self.chargeTimer - self.dt)
	
	self.chargeHasStarted = true
	
	--Prevent energy regen while charging
	status.setResourcePercentage("energyRegenBlock", 0.6)
	
	if self.chargeSoundIsPlaying == false then
	  animator.playSound("chargeLoop", -1)
	  self.chargeSoundIsPlaying = true
	end

    coroutine.yield()
  end
  
  --If the charge is ready, keep on firing so long as we have energy left
  if self.chargeTimer == 0 and status.overConsumeResource("energy", self:energyPerShot()) then    
	self.resetTimer = self.resetTime
	self.chargeHasStarted = false
	self.windupReady = true
	
	if self.holdSoundIsPlaying == false then
	  animator.playSound("holdLoop", -1)
	  animator.stopAllSounds("chargeLoop")
	  self.chargeSoundIsPlaying = false
	  self.holdSoundIsPlaying = true
	end
	
	if self.fireType == "auto" then
	  self:setState(self.auto)
	elseif self.fireType == "burst" then
	  self:setState(self.burst)
	end
  --If not charging and charge isn't ready, go to cooldown
  else
	animator.playSound("discharge")
	self.shouldDischarge = true
    self:setState(self.cooldown)
  end
end

function MultiBarrelShotMinigun:auto()
  self.weapon:setStance(self.stances.fire)

  self:fireProjectile()
  self:muzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function MultiBarrelShotMinigun:burst()
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

function MultiBarrelShotMinigun:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
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
        self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function MultiBarrelShotMinigun:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function MultiBarrelShotMinigun:cooldown()
  
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

function MultiBarrelShotMinigun:firePositionDefault()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function MultiBarrelShotMinigun:firePosition()
  --Code for alternating barrels/muzzle positions
  if self.currentBarrel == 1 then
    self.currentFirePosition = self.firePosition1
	self.currentBarrel = 2
  elseif self.currentBarrel == 2 then
    self.currentFirePosition = self.firePosition2
	self.currentBarrel = 1
  else
    self.currentFirePosition = self.firePosition1
	self.currentBarrel = 2
  end
	
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.currentFirePosition))
end

function MultiBarrelShotMinigun:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function MultiBarrelShotMinigun:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function MultiBarrelShotMinigun:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function MultiBarrelShotMinigun:uninit()
  self:reset()
end

function MultiBarrelShotMinigun:reset()
  animator.setAnimationState("charge", "off")
  --animator.setAnimationState("chargehold", "off")
  self.chargeHasStarted = false
  self.weapon:setStance(self.stances.idle)
end