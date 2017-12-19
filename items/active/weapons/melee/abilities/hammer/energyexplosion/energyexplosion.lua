require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/items/active/weapons/weapon.lua"

EnergyExplosion = WeaponAbility:new()

function EnergyExplosion:init()
  self.groundWasHit = false
  self:reset()
end

function EnergyExplosion:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.weapon.currentAbility == nil and self.fireMode == "alt" and mcontroller.onGround() and not status.resourceLocked("energy") then
    self:setState(self.windup)
  end
  
  if self.startLine and self.endLine then
	world.debugLine(self.startLine, self.endLine, "red")
	world.debugPoint(self.endLine, "red")
  end
end

-- Attack state: windup
function EnergyExplosion:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0

  animator.playSound("charge")

  local wasFull = false
  local chargeTimer = 0
  while self.fireMode == "alt" and (chargeTimer == self.chargeTime and not self.releaseOnReady or status.overConsumeResource("energy", (self.energyUsage / self.chargeTime) * self.dt)) and not (chargeTimer == self.chargeTime and self.releaseOnReady) do
    chargeTimer = math.min(self.chargeTime, chargeTimer + self.dt)

    if chargeTimer == self.chargeTime and not wasFull then
      wasFull = true
      animator.stopAllSounds("charge")
      animator.playSound("chargefull", -1)
    end

    local chargeRatio = math.sin(chargeTimer / self.chargeTime * 1.57)
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.armRotation, self.stances.windup.endArmRotation}))
    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.weaponRotation, self.stances.windup.endWeaponRotation}))
	
	if self.stances.windup.endWeaponOffset then
	  local from = self.stances.windup.weaponOffset or {0,0}
	  local to = self.stances.windup.endWeaponOffset or {0,0}
	  self.weapon.weaponOffset = {interp.linear(chargeRatio, from[1], to[1]), interp.linear(chargeRatio, from[2], to[2])}
	end

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
function EnergyExplosion:fire(charge)
  self.weapon:setStance(self.stances.fire)
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0

  self:fireExplosion(charge)
  animator.playSound("chargefire")

  util.wait(self.stances.fire.duration, function()
	if self.groundWasHit == true then
	  animator.setAnimationState("blade", "inactive")
	end
  end)
  if self.groundWasHit == true then
	self.weapon:setStance(self.stances.cooldown)
	util.wait(self.stances.cooldown.duration)
	
	animator.setAnimationState("blade", "extend")
	self.activeTimer = self.activeTime
  end
end

function EnergyExplosion:reset()
  animator.stopAllSounds("chargefire")
  animator.stopAllSounds("chargefull")
  
  self.startLine = nil
  self.endLine = nil
end

function EnergyExplosion:uninit()
  self:reset()
end

-- Helper functions
function EnergyExplosion:fireExplosion(charge)
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
  else
	self.groundWasHit = false
  end
end

function EnergyExplosion:impactPosition()
  local dir = mcontroller.facingDirection()
  self.startLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[1], {dir, 1}))
  self.endLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[2], {dir, 1}))
  
  local blocks = world.collisionBlocksAlongLine(self.startLine, self.endLine, {"Null", "Block"})
  if #blocks > 0 then
    return vec2.add(blocks[1], {0.5, 0.5}), self.endLine[2] - blocks[1][2] + 1
  end
end
