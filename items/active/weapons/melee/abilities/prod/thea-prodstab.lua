-- Melee primary ability
TheaProdStab = WeaponAbility:new()

function TheaProdStab:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime
  self.holdDamageConfig.baseDamage = self.holdDamageMultiplier * self.damageConfig.baseDamage

  self.energyUsage = self.energyUsage or 0

  self.weapon:setStance(self.stances.idle)
  
  animator.setAnimationState("swoosh", "idle")
  animator.setParticleEmitterActive("holdparticles", false)
  animator.stopAllSounds("holdLoop")

  self.cooldownTimer = self:cooldownTime()

  self.weapon.onLeaveAbility = function()
	self.weapon:setStance(self.stances.idle)
	animator.setAnimationState("swoosh", "idle")
	animator.setParticleEmitterActive("holdparticles", false)
	animator.stopAllSounds("holdLoop")
  end
end

-- Ticks on every update regardless if this is the active ability
function TheaProdStab:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    self:setState(self.windup)
  end
end

-- State: windup
function TheaProdStab:windup()
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
function TheaProdStab:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()

  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

-- State: fire
function TheaProdStab:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("swoosh", "fire")
  animator.playSound(self.fireSound or "fire")
  animator.burstParticleEmitter((self.elementalType or self.weapon.elementalType) .. "swoosh")

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
  end)

  self.cooldownTimer = self:cooldownTime()
  
  if self.fireMode == "primary" and self.allowHold ~= false then
    self:setState(self.hold)
  end
end

function TheaProdStab:hold()
  self.weapon:setStance(self.stances.hold)
  self.weapon:updateAim()

  --Activate the hold particles and play hold sounds
  animator.setParticleEmitterActive("holdparticles", true)
  animator.playSound("holdLoop", -1)
  
  while self.fireMode == "primary" do
    local damageArea = partDamageArea("blade")
    self.weapon:setDamage(self.holdDamageConfig, damageArea)
    coroutine.yield()
  end

  --If the player stops holding out the weapon, recet the swoosh animation, deactivate particles and stop sounds
  animator.setAnimationState("swoosh", "idle")
  animator.setParticleEmitterActive("holdparticles", false)
  animator.stopAllSounds("holdLoop")
  
  self.cooldownTimer = self:cooldownTime()
end

function TheaProdStab:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function TheaProdStab:uninit()
  self.weapon:setDamage()
end
