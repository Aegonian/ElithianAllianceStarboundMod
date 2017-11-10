-- Melee primary ability
TheaAltMeleeSlash = WeaponAbility:new()

function TheaAltMeleeSlash:init()
  self.damageConfig.baseDamage = self.baseDamage or self.baseDps * self.fireTime

  self.energyUsage = self.energyUsage or 0

  self.cooldownTimer = self:cooldownTime()
end

-- Ticks on every update regardless if this is the active ability
function TheaAltMeleeSlash:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == "alt" and self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    self:setState(self.windup)
  end
end

-- State: windup
function TheaAltMeleeSlash:windup()
  self.weapon:setStance(self.stances.windup)

  if self.stances.windup.hold then
    while self.fireMode == "alt" do
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
function TheaAltMeleeSlash:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()

  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

-- State: fire
function TheaAltMeleeSlash:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("altSwoosh", "fire")
  animator.playSound(self.fireSound or "altFire")
  animator.burstParticleEmitter("altSwoosh")

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("altSwoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
  end)

  self.cooldownTimer = self:cooldownTime()
end

function TheaAltMeleeSlash:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function TheaAltMeleeSlash:uninit()
  self.weapon:setDamage()
end
