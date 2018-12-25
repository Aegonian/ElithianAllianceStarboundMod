-- Melee primary ability
TheaLanceThrust = WeaponAbility:new()

function TheaLanceThrust:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.energyUsage = self.energyUsage or 0

  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self:cooldownTime()

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function TheaLanceThrust:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    self:setState(self.windup)
  end
end

-- State: windup
function TheaLanceThrust:windup()
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
function TheaLanceThrust:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()

  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

-- State: fire
function TheaLanceThrust:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("swoosh", "fire")
  animator.playSound(self.fireSound or "fire")
  animator.burstParticleEmitter((self.elementalType or self.weapon.elementalType) .. "swoosh")

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime - 0.1) --Manually adjust the damage timeout because for some unknown reason, it won't function properly on lances
  end)

  self.cooldownTimer = self:cooldownTime()
end

function TheaLanceThrust:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function TheaLanceThrust:uninit()
  self.weapon:setDamage()
end
