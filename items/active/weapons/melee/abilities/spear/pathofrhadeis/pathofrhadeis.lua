require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

PathOfRhadeis = WeaponAbility:new()

function PathOfRhadeis:init()
  self:reset()
  
  animator.setAnimationState("dashSwoosh", "idle")
end

function PathOfRhadeis:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.weapon.currentAbility == nil and self.fireMode == "alt" and not status.resourceLocked("energy") then
    self:setState(self.charge)
  end
end

function PathOfRhadeis:charge()
  self.weapon:setStance(self.stances.charge)
  self.weapon:updateAim()

  animator.setAnimationState("charge", "charging")
  animator.playSound("chargeStart")
  
  local chargeTimer = 0
  local chargeLevel = 0
  local previousChargeLevel = 0
  while self.fireMode == "alt" and (chargeLevel == self.chargeLevels or status.overConsumeResource("energy", (self.maxEnergyUsage / (self.chargeTimePerLevel * self.maxChargeLevel)) * self.dt)) do
    chargeTimer = math.min(self.chargeTimePerLevel, chargeTimer + self.dt)
	--If we reach the charge time max, increase charge level unless already at max
	if chargeTimer >= self.chargeTimePerLevel and chargeLevel < self.maxChargeLevel then
	  chargeLevel = chargeLevel + 1
	  chargeTimer = 0
	end
	
	--Update the charge animation
	if chargeLevel == 1 and previousChargeLevel ~= 1 then
	  animator.setAnimationState("charge", "transitionLow")
	  animator.playSound("chargedLow")
	  previousChargeLevel = 1
	elseif chargeLevel == 2 and previousChargeLevel ~= 2 then
	  animator.setAnimationState("charge", "transitionMedium")
	  animator.playSound("chargedMedium")
	  previousChargeLevel = 2
	elseif chargeLevel == 3 and previousChargeLevel ~= 3 then
	  animator.setAnimationState("charge", "transitionHigh")
	  animator.playSound("chargedHigh")
	  previousChargeLevel = 3
	end
	
    coroutine.yield()
  end

  animator.stopAllSounds("chargeStart")
  
  if chargeLevel > 0 then
    self:setState(self.dash, chargeLevel)
  end
end

function PathOfRhadeis:dash(chargeLevel)
  self.weapon:setStance(self.stances.dash)
  self.weapon:updateAim()

  animator.setAnimationState("charge", "idle")
  animator.setAnimationState("dashSwoosh", "active")
  animator.playSound("dash")
  
  --Make the player immune to damage while dashing
  status.addEphemeralEffect("invulnerable")

  util.wait(self.minDashTime + (self.dashTimePerLevel * chargeLevel), function(dt)
	--Determine in what direction we should charge
    local aimDirection = {mcontroller.facingDirection() * math.cos(self.weapon.aimAngle), math.sin(self.weapon.aimAngle)}
	--Set our velocity
    mcontroller.controlApproachVelocity(vec2.mul(aimDirection, self.dashMaxSpeed), self.dashControlForce)
	--Disable gravity and friction for the duration of the charge
    mcontroller.controlParameters({
      airFriction = 0,
      groundFriction = 0,
      liquidFriction = 0,
      gravityEnabled = false
    })

    local damageArea = partDamageArea("dashSwoosh")
    self.damageConfig.baseDamage = self.baseDamage + (self.damagePerLevel * chargeLevel)
    self.weapon:setDamage(self.damageConfig, damageArea)
  end)
  
  --Remove the invulnerability effect
  status.removeEphemeralEffect("invulnerable")
  
  local stopVelocity = vec2.mul(mcontroller.velocity(), self.retainVelocityFactor)
  mcontroller.setVelocity(stopVelocity)
  animator.setAnimationState("dashSwoosh", "stop")
end

function PathOfRhadeis:reset()
  animator.setAnimationState("charge", "idle")
  --Remove the invulnerability effect
  status.removeEphemeralEffect("invulnerable")
end

function PathOfRhadeis:uninit()
  self:reset()
end
