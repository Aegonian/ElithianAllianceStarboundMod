--Custom altFire attack which has the added option to play an altFire animation, or if "animateWeapon" is configured, set the weapon's animation state to "active" when firing

require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"
require "/items/active/weapons/ranged/gunfire.lua"

TheaAltFireAttack = GunFire:new()

function TheaAltFireAttack:new(abilityConfig)
  local primary = config.getParameter("primaryAbility")
  return GunFire.new(self, sb.jsonMerge(primary, abilityConfig))
end

function TheaAltFireAttack:init()
  self.cooldownTimer = self.fireTime
end

function TheaAltFireAttack:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.fireMode == "alt"
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    
    if self.fireType == "auto" and status.overConsumeResource("energy", self:energyPerShot()) then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end
end

function TheaAltFireAttack:auto()
  self.weapon:setStance(self.stances.fire)
  if self.animateWeapon then
	animator.setAnimationState("weapon", "active")
  end

  self:fireProjectile()
  self:muzzleFlash()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function TheaAltFireAttack:burst()
  self.weapon:setStance(self.stances.fire)
  if self.animateWeapon then
	animator.setAnimationState("weapon", "active")
  end

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

function TheaAltFireAttack:muzzleFlash()
  if not self.hidePrimaryMuzzleFlash then
    animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
    animator.setAnimationState("firing", "fire")
    animator.setLightActive("muzzleFlash", true)
  end
  
  if self.useParticleEmitter == nil or self.useParticleEmitter then
    animator.burstParticleEmitter("altMuzzleFlash", true)
  end
  
  if self.playAltFireAnimation then
    animator.setAnimationState("altFire", "fire")
  end

  if self.usePrimaryFireSound then
    animator.playSound("fire")
  else
    animator.playSound("altFire")
  end
end

function TheaAltFireAttack:firePosition()
  if self.firePositionPart then
    return vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint(self.firePositionPart, "firePosition")))
  else
    return GunFire.firePosition(self)
  end
end
