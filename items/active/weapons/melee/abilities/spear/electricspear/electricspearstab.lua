-- Melee primary ability
ElectricSpearStab = WeaponAbility:new()

function ElectricSpearStab:init()
  self.inactiveDamageConfig.baseDamage = self.baseDps * self.fireTime
  self.activeDamageConfig.baseDamage = self.activeDps * self.fireTime
  self.inactiveHoldDamageConfig.baseDamage = self.inactiveHoldDamageMultiplier * self.inactiveDamageConfig.baseDamage
  self.activeHoldDamageConfig.baseDamage = self.activeHoldDamageMultiplier * self.activeDamageConfig.baseDamage

  self.energyUsage = self.energyUsage or 0

  self.weapon:setStance(self.stances.idle)
  
  animator.setAnimationState("swoosh", "idle")
  animator.setParticleEmitterActive("holdparticles", false)
  animator.stopAllSounds("holdLoop")
  self.loopSoundIsPlaying = false

  self.cooldownTimer = self:cooldownTime()

  self.weapon.onLeaveAbility = function()
	self.weapon:setStance(self.stances.idle)
	if self.active == true then
	  animator.setAnimationState("swoosh", "active")
	else
	  animator.setAnimationState("swoosh", "idle")
	end
	animator.setParticleEmitterActive("holdparticles", false)
	animator.stopAllSounds("holdLoop")
	animator.stopAllSounds("idleLoop")
  end
end

-- Ticks on every update regardless if this is the active ability
function ElectricSpearStab:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  --Play a looping sound effect if active, but not attacking
  if not self.weapon.currentAbility and self.active == true and self.loopSoundIsPlaying == false then
	animator.playSound("idleLoop", -1)
	self.loopSoundIsPlaying = true
  end
  
  --Reset sound boolean if we deactivate 
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

-- State: windup
function ElectricSpearStab:windup()
  self.weapon:setStance(self.stances.windup)

  if self.stances.windup.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(self.stances.windup.duration)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances.preslash then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: preslash
-- brief frame in between windup and fire
function ElectricSpearStab:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()

  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

-- State: fire
function ElectricSpearStab:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()
  
  if self.active == true then
	self.loopSoundIsPlaying = false
	animator.stopAllSounds("idleLoop")
	
	animator.setAnimationState("swoosh", "fireActive")
	animator.playSound("fireActive")
	animator.burstParticleEmitter("electricswoosh")
  else
	animator.setAnimationState("swoosh", "fireInactive")
	animator.playSound("fireInactive") 
  end

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("swoosh")
	if self.active == true then
	  self.weapon:setDamage(self.activeDamageConfig, damageArea, self.fireTime)
	else
	  self.weapon:setDamage(self.inactiveDamageConfig, damageArea, self.fireTime)
	end
  end)

  self.cooldownTimer = self:cooldownTime()
  
  if self.fireMode == "primary" and self.allowHold ~= false then
    self:setState(self.hold)
  end
end

function ElectricSpearStab:hold()
  self.weapon:setStance(self.stances.hold)
  self.weapon:updateAim()

  if self.active == true then
	animator.setParticleEmitterActive("holdparticles", true)
	animator.playSound("holdLoop", -1)
  end
  
  while self.fireMode == "primary" and status.resourcePositive("energy") do
    local damageArea = partDamageArea("blade")
	if self.active == true then
	  self.weapon:setDamage(self.activeHoldDamageConfig, damageArea)
	else
	  self.weapon:setDamage(self.inactiveHoldDamageConfig, damageArea)
	end
    coroutine.yield()
  end

  if self.active == true then
	animator.setAnimationState("swoosh", "active")
	animator.setParticleEmitterActive("holdparticles", false)
	animator.stopAllSounds("holdLoop")
  else
	animator.setAnimationState("swoosh", "idle")
  end
  
  self.cooldownTimer = self:cooldownTime()
end

function ElectricSpearStab:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function ElectricSpearStab:uninit()
  animator.stopAllSounds("holdLoop")
  animator.stopAllSounds("idleLoop")
  self.weapon:setDamage()
end
