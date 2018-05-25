require "/scripts/vec2.lua"

-- Bow primary ability
TheaLineBowShot = WeaponAbility:new()

function TheaLineBowShot:init()
  self.energyPerShot = self.energyPerShot or 0

  self.drawTimer = 0
  self.drawPercentage = 0
  self.cooldownTimer = self.cooldownTime
  self.animationTimer = self.animationTime
  self.animationFrame = 1
  self.wasFullyDrawn = false

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function TheaLineBowShot:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyPerShot == 0 or not status.resourceLocked("energy")) then
    self:setState(self.draw)
  end
end

function TheaLineBowShot:draw()
  self.weapon:setStance(self.stances.draw)

  animator.playSound("draw")
  animator.setParticleEmitterActive("chargeparticles", true)

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
    if self.walkWhileFiring then mcontroller.controlModifiers({runningSuppressed = true}) end

    self.drawTimer = math.min(self.drawTime, self.drawTimer + self.dt)
	
	--Calculate how far along the charge is
	self.drawPercentage = self.drawTimer / self.drawTime
	--Calculate the correct draw frame to use. Subtract the total drawLevels by 1, as the final drawLevel should only be displayed once fully charged
	self.drawFrame = math.ceil(self.drawPercentage * (self.drawLevels - 1))
	--If fully charged, use the final drawLevel as our drawFrame
	if self.drawPercentage == 1 then
	  self.drawFrame = self.drawLevels
	end
	--world.debugText(self.drawPercentage, vec2.add(mcontroller.position(), {0,1}), "red")
	--world.debugText(self.drawFrame, vec2.add(mcontroller.position(), {0,2}), "red")
	--If at max charge level, alternate draw frames to animate the charge
	if self.drawFrame == self.drawLevels then
	  self.animationTimer = math.max(0, self.animationTimer - self.dt)
	  if self.animationTimer == 0 then
		if self.animationFrame == 0 then
		  self.animationFrame = 1
		  self.animationTimer = self.animationTime
		else
		  self.animationFrame = 0
		  self.animationTimer = self.animationTime
		end
	  animator.setGlobalTag("drawFrame", self.drawLevels + self.animationFrame)
	  end
	else
	  animator.setGlobalTag("drawFrame", self.drawFrame)
	end
    self.stances.draw.frontArmFrame = self.drawArmFrames[self.drawFrame]
	
	--Actions to perform once when max draw time is reached
	if self.drawFrame == self.drawLevels and self.wasFullyDrawn == false then
	  animator.setParticleEmitterActive("chargeparticles", false)
	  animator.playSound("fullyDrawnLoop", -1)
	  self.wasFullyDrawn = true
	end
	
	--Set the first lightning effect
	local lightningCharge = self.lightningChargeLevels[self.drawFrame]
    self:setLightning(lightningCharge[1], lightningCharge[2], lightningCharge[3], lightningCharge[4], lightningCharge[5], lightningCharge[6], lightningCharge[7])
	--Set the second lightning effect
	local lightningCharge2 = self.lightningChargeLevels2[self.drawFrame]
    self:setLightning2(lightningCharge2[1], lightningCharge2[2], lightningCharge2[3], lightningCharge2[4], lightningCharge2[5], lightningCharge2[6], lightningCharge2[7])

    coroutine.yield()
  end

  self:setState(self.fire)
end

function TheaLineBowShot:fire()
  self.weapon:setStance(self.stances.fire)

  animator.stopAllSounds("draw")
  animator.stopAllSounds("fullyDrawnLoop")
  animator.setGlobalTag("drawFrame", "0")
  activeItem.setScriptedAnimationParameter("lightning", {})
  activeItem.setScriptedAnimationParameter("lightning2", {})
  animator.setParticleEmitterActive("chargeparticles", false)
  
  local adjustedProjectileType = self.projectileType
  if self.usePowerProjectile then
	if self.drawPercentage >= 1 then
	  adjustedProjectileType = self.powerProjectileType
	end
  end

  if not world.pointTileCollision(self:firePosition()) and status.overConsumeResource("energy", self.energyPerShot) and self.drawFrame >= self.minimumDrawFrame then
    for i = 1, (self.projectileCount or 1) do
	  world.spawnProjectile(
        adjustedProjectileType,
        self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(self.inaccuracy),
        false,
        self:currentProjectileParameters()
      )
	end

	animator.playSound("release")

    util.wait(self.stances.fire.duration)
  else
	animator.playSound("discharge")
  end
  
  self.drawFrame = 0
  self.drawTimer = 0
  self.drawPercentage = 0
  self.animationFrame = 0
  self.cooldownTimer = self.cooldownTime
  self.wasFullyDrawn = false
end

function TheaLineBowShot:currentProjectileParameters()
  local params = copy(self.projectileParameters or {})
  local projectileConfig = root.projectileConfig(self.projectileType)
  --params.power = params.power or projectileConfig.power
  params.power = self.baseDamage * self.weapon.damageLevelMultiplier * self.drawPercentage
  params.powerMultiplier = activeItem.ownerPowerMultiplier()

  return params
end

function TheaLineBowShot:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaLineBowShot:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaLineBowShot:setLightning(amount, width, forks, displacement, color, startOffset, endOffset)
  local lightning = {}
  for i = 1, amount do
    local bolt = {
      minDisplacement = 0.125,
      forks = forks,
      forkAngleRange = 0.75,
      width = width,
	  displacement = displacement,
      color = color
    }	
	bolt.itemStartPosition = vec2.add(self.weapon.muzzleOffset, startOffset)
	bolt.itemEndPosition = vec2.add(self.weapon.muzzleOffset, endOffset)
    table.insert(lightning, bolt)
  end
  activeItem.setScriptedAnimationParameter("lightning", lightning)
end

function TheaLineBowShot:setLightning2(amount, width, forks, displacement, color, startOffset, endOffset)
  local lightning = {}
  for i = 1, amount do
    local bolt = {
      minDisplacement = 0.125,
      forks = forks,
      forkAngleRange = 0.75,
      width = width,
	  displacement = displacement,
      color = color
    }	
	bolt.itemStartPosition = vec2.add(self.weapon.muzzleOffset, startOffset)
	bolt.itemEndPosition = vec2.add(self.weapon.muzzleOffset, endOffset)
    table.insert(lightning, bolt)
  end
  activeItem.setScriptedAnimationParameter("lightning2", lightning)
end

function TheaLineBowShot:uninit()
  self:reset()
end

function TheaLineBowShot:reset()
  animator.stopAllSounds("draw")
  animator.stopAllSounds("fullyDrawnLoop")
  animator.setGlobalTag("drawFrame", "0")
  self.weapon:setStance(self.stances.idle)
  activeItem.setScriptedAnimationParameter("lightning", {})
  activeItem.setScriptedAnimationParameter("lightning2", {})
  animator.setParticleEmitterActive("chargeparticles", false)
  self.wasFullyDrawn = false
end
