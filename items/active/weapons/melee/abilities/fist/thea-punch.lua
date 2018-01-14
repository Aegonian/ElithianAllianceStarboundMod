--Custom fist punch script which allows for aimed fist attacks. When attacking in the air, movement will also only freeze on the Y axis

require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

-- fist weapon primary attack
TheaPunch = WeaponAbility:new()

function TheaPunch:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self:cooldownTime()

  self.freezesLeft = self.freezeLimit
  self.freezeTimer = 0

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
	self.weapon:updateAim()
  end
end

-- Ticks on every update regardless if this is the active ability
function TheaPunch:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  self.freezeTimer = math.max(0, self.freezeTimer - dt)
  if self.freezeTimer > 0 and not mcontroller.onGround() and math.abs(world.gravity(mcontroller.position())) > 0 then
	mcontroller.controlApproachYVelocity(0, 1000)
  end
end

function TheaPunch:canStartAttack()
  return not self.weapon.currentAbility and self.cooldownTimer == 0
end

-- used by fist weapon combo system
function TheaPunch:startAttack()
  self:setState(self.windup)

  if self.weapon.freezesLeft > 0 then
    self.weapon.freezesLeft = self.weapon.freezesLeft - 1
    self.freezeTimer = self.freezeTime or 0
  end
end

-- State: windup
function TheaPunch:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  util.wait(self.stances.windup.duration)

  self:setState(self.windup2)
end

-- State: windup2
function TheaPunch:windup2()
  self.weapon:setStance(self.stances.windup2)
  self.weapon:updateAim()

  util.wait(self.stances.windup2.duration)

  self:setState(self.fire)
end

-- State: fire
function TheaPunch:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("attack", "fire")
  animator.playSound("fire")

  status.addEphemeralEffect("invulnerable", self.stances.fire.duration + 0.05)

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("swoosh")
    
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
  end)

  --onLeaveAbility doesn't work for some strange reason, so perform reset code here instead
  self.cooldownTimer = self:cooldownTime()
  self.weapon:setStance(self.stances.idle)
  self.weapon:updateAim()
end

function TheaPunch:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

function TheaPunch:uninit(unloaded)
  self.weapon:setDamage()
end
