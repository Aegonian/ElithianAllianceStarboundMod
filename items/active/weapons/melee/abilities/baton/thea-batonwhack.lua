require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/items/active/weapons/melee/meleeslash.lua"

BatonWhack = MeleeSlash:new()

function BatonWhack:init()
  self.inactiveDamageConfig.baseDamage = self.baseDps * self.fireTime
  self.activeDamageConfig.baseDamage = self.activeDps * self.fireTime
  
  self.stances.windup.duration = self.fireTime - self.stances.fire.duration
  
  --Initial set-up for storing weapon state
  self.active = config.getParameter("active", true)
  activeItem.setInstanceValue("active", self.active)
  
  self.weapon:setStance(self.stances.idle)
  
  --Initial stats
  self.cooldownTimer = self:cooldownTime()
  self.isFiring = false
  animator.setAnimationState("swoosh", "idle")
  animator.setParticleEmitterActive("activeParticles", false)
  animator.stopAllSounds("idleLoop")
  self.loopSoundIsPlaying = false

  self.weapon.onLeaveAbility = function()
	self.weapon:setStance(self.stances.idle)
	self.isFiring = false
	self.active = config.getParameter("active")
	if self.active == true then
	  animator.setAnimationState("swoosh", "active")
	else
	  animator.setAnimationState("swoosh", "idle")
	  animator.stopAllSounds("idleLoop")
	  self.loopSoundIsPlaying = false
	end
	animator.setParticleEmitterActive("activeParticles", self.active)
  end
  self:setupInterpolation()
end

function BatonWhack:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.active = config.getParameter("active")
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  --If we just got activated
  if self.active == true and self.loopSoundIsPlaying == false and self.isFiring == false then
	animator.playSound("idleLoop", -1)
	self.loopSoundIsPlaying = true
	animator.setAnimationState("swoosh", "active")
  end
  
  --If we just got deactivated
  if self.active == false and self.loopSoundIsPlaying == true then
	animator.stopAllSounds("idleLoop")
	self.loopSoundIsPlaying = false
  end
  
  --If not attacking, and not active, disable all swoosh animations
  if not self.weapon.currentAbility and self.active == false then
	animator.setAnimationState("swoosh", "idle")
  end

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    self:setState(self.windup)
  end
end

function BatonWhack:windup(windupProgress)
  self.weapon:setStance(self.stances.windup)

  local windupProgress = windupProgress or 0
  local bounceProgress = 0
  while self.fireMode == "primary" and (self.allowHold ~= false or windupProgress < 1) do
    if windupProgress < 1 then
      windupProgress = math.min(1, windupProgress + (self.dt / self.stances.windup.duration))
      self.weapon.relativeWeaponRotation, self.weapon.relativeArmRotation = self:windupAngle(windupProgress)
    else
      bounceProgress = math.min(1, bounceProgress + (self.dt / self.stances.windup.bounceTime))
      self.weapon.relativeWeaponRotation = self:bounceWeaponAngle(bounceProgress)
    end
    coroutine.yield()
  end

  if windupProgress >= 1.0 then
    if self.stances.preslash then
      self:setState(self.preslash)
    else
      self:setState(self.fire)
    end
  else
    self:setState(self.winddown, windupProgress)
  end
end

function BatonWhack:winddown(windupProgress)
  self.weapon:setStance(self.stances.windup)

  while windupProgress > 0 do
    if self.fireMode == "primary" then
      self:setState(self.windup, windupProgress)
      return true
    end

    windupProgress = math.max(0, windupProgress - (self.dt / self.stances.windup.duration))
    self.weapon.relativeWeaponRotation, self.weapon.relativeArmRotation = self:windupAngle(windupProgress)
    coroutine.yield()
  end
end

function BatonWhack:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  self.isFiring = true
  
  self.active = config.getParameter("active")
  if self.active then
	animator.setAnimationState("swoosh", "fireActive")
	animator.playSound("fireActive")
	animator.burstParticleEmitter("activeSwoosh")
  else
	animator.setAnimationState("swoosh", "fireInactive")
	animator.playSound("fireInactive")
	animator.burstParticleEmitter("inactiveSwoosh")
  end

  util.wait(self.stances.fire.duration, function()
      local damageArea = partDamageArea("swoosh")
	  if self.active then
		self.weapon:setDamage(self.activeDamageConfig, damageArea, self.fireTime)
	  else
		self.weapon:setDamage(self.inactiveDamageConfig, damageArea, self.fireTime)
	  end
    end)

  self.cooldownTimer = self:cooldownTime()
  self.isFiring = false
end

function BatonWhack:setupInterpolation()
  for i, v in ipairs(self.stances.windup.bounceWeaponAngle) do
    v[2] = interp[v[2]]
  end
  for i, v in ipairs(self.stances.windup.weaponAngle) do
    v[2] = interp[v[2]]
  end
  for i, v in ipairs(self.stances.windup.armAngle) do
    v[2] = interp[v[2]]
  end
end

function BatonWhack:bounceWeaponAngle(ratio)
  return util.toRadians(interp.ranges(ratio, self.stances.windup.bounceWeaponAngle))
end

function BatonWhack:windupAngle(ratio)
  local weaponRotation = interp.ranges(ratio, self.stances.windup.weaponAngle)
  local armRotation = interp.ranges(ratio, self.stances.windup.armAngle)

  return util.toRadians(weaponRotation), util.toRadians(armRotation)
end
