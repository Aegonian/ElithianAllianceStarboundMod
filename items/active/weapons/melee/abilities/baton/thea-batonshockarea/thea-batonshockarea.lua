require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

TheaBatonShockArea = WeaponAbility:new()

function TheaBatonShockArea:init()
  self.groundWasHit = false
  
  self.active = config.getParameter("active")
  
  if self.active then
	self.rechargeTimer = 0
  else
	self.rechargeTimer = self.rechargeTime
  end
end

function TheaBatonShockArea:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  self.active = config.getParameter("active")
  self.rechargeTimer = math.max(0, self.rechargeTimer - self.dt)
  
  if not self.active and self.rechargeTimer == 0 and self.weapon.currentAbility ~= self then
	--Activate the weapon
	animator.setAnimationState("blade", "active")
	activeItem.setInstanceValue("active", true)
  end

  if self.weapon.currentAbility == nil and self.fireMode == "alt" and mcontroller.onGround() and not status.resourceLocked("energy") and self.active then
    self:setState(self.windup)
  end
end

-- Attack state: windup
function TheaBatonShockArea:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0

  animator.playSound("charge")

  local wasFull = false
  local chargeTimer = 0
  while self.fireMode == "alt" and (chargeTimer == self.chargeTime or status.overConsumeResource("energy", (self.energyUsage / self.chargeTime) * self.dt)) do
    chargeTimer = math.min(self.chargeTime, chargeTimer + self.dt)

    if chargeTimer == self.chargeTime and not wasFull then
      wasFull = true
      animator.stopAllSounds("charge")
      animator.playSound("chargefull", -1)
    end

    local chargeRatio = math.sin(chargeTimer / self.chargeTime * 1.57)
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.armRotation, self.stances.windup.endArmRotation}))
    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.weaponRotation, self.stances.windup.endWeaponRotation}))

    mcontroller.controlModifiers({
      jumpingSuppressed = true,
      runningSuppressed = true
    })
	
	--Disable energy regen while charging
	status.setResourcePercentage("energyRegenBlock", 0.6)

    coroutine.yield()
  end

  animator.stopAllSounds("charge")
  animator.stopAllSounds("chargefull")

  if chargeTimer > self.minChargeTime then
    self:setState(self.fire, chargeTimer / self.chargeTime)
  end
end

-- Attack state: fire
function TheaBatonShockArea:fire(charge)
  self.weapon:setStance(self.stances.fire)
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0

  self:fireExplosion(charge)
  animator.playSound("chargefire")

  util.wait(self.stances.fire.duration, function()
	if self.groundWasHit == true then
	  --Unused
	end
  end)
  if self.groundWasHit == true then
	self.rechargeTimer = self.rechargeTime
  end
end

function TheaBatonShockArea:reset()
  animator.stopAllSounds("chargefire")
  animator.stopAllSounds("chargefull")
end

function TheaBatonShockArea:uninit()
  self:reset()
end

-- Helper functions
function TheaBatonShockArea:fireExplosion(charge)
  local impact, impactHeight = self:impactPosition()

  if impact then
	self.groundWasHit = true
	if self.useDynamicOffset == true then
	  self.weapon.weaponOffset = {0, impactHeight + self.impactWeaponOffset}
	end
	
	local projectilePosition = vec2.add(self:impactPosition(), self.projectileOffset or {0,0})
	
	local params = copy(self.projectileParameters)
	params.powerMultiplier = activeItem.ownerPowerMultiplier()
	params.power = params.power * config.getParameter("damageLevelMultiplier")

    world.spawnProjectile(self.projectileType, projectilePosition, activeItem.ownerEntityId(), {0,0}, false, params)
	
	--Consume the rest of our energy reserves
	status.overConsumeResource("energy", self.dischargeEnergyCost)
	
	--Deactivate the weapon
	animator.setAnimationState("blade", "recharge")
	activeItem.setInstanceValue("active", false)
	self.active = false
  else
	self.groundWasHit = false
  end
end

function TheaBatonShockArea:impactPosition()
  local dir = mcontroller.facingDirection()
  local startLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[1], {dir, 1}))
  local endLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[2], {dir, 1}))
  
  local blocks = world.collisionBlocksAlongLine(startLine, endLine, {"Null", "Block"})
  if #blocks > 0 then
    return vec2.add(blocks[1], {0.5, 0.5}), endLine[2] - blocks[1][2] + 1
  end
end
