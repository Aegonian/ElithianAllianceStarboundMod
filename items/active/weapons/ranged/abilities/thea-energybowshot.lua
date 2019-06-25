require "/scripts/vec2.lua"

-- Bow primary ability
TheaEnergyBowShot = WeaponAbility:new()

function TheaEnergyBowShot:init()
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

function TheaEnergyBowShot:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyPerShot == 0 or not status.resourceLocked("energy")) then
    self:setState(self.draw)
  end
end

function TheaEnergyBowShot:draw()
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

	--Optionally update the charge intake particles
	if self.useChargeParticles and not self.wasFullyDrawn then
	  self:updateChargeIntake(self.drawTime - self.drawTimer)
	elseif self.useChargeParticles and self.wasFullyDrawn then
	  activeItem.setScriptedAnimationParameter("particles", {})
	end

    coroutine.yield()
  end
  
  --Optionally reset the charge intake particles
  if self.useChargeParticles then
	activeItem.setScriptedAnimationParameter("particles", {})
  end

  self:setState(self.fire)
end

function TheaEnergyBowShot:fire()
  self.weapon:setStance(self.stances.fire)

  animator.stopAllSounds("draw")
  animator.stopAllSounds("fullyDrawnLoop")
  animator.setGlobalTag("drawFrame", "0")
  animator.setParticleEmitterActive("chargeparticles", false)
  
  local adjustedProjectileType = self.projectileType or ""
  local adjustedProjectileTypeList = self.projectileList or {}
  local powerProjectile = false
  
  if self.projectileList then
	if self.usePowerProjectile then
	  if self.drawPercentage >= 1 then
		adjustedProjectileTypeList = self.powerProjectileList
		powerProjectile = true
	  end
	end
  else
	if self.usePowerProjectile then
	  if self.drawPercentage >= 1 then
		adjustedProjectileType = self.powerProjectileType
		powerProjectile = true
	  end
	end
  end

  if not world.pointTileCollision(self:firePosition()) and status.overConsumeResource("energy", self.energyPerShot) and self.drawFrame >= self.minimumDrawFrame then
    if self.projectileList then
	  for i = 1, (#adjustedProjectileTypeList or 1) do
		world.spawnProjectile(
		  adjustedProjectileTypeList[i],
		  self:firePosition(),
		  activeItem.ownerEntityId(),
		  self:aimVector(self.inaccuracy, i, powerProjectile),
		  false,
		  self:currentProjectileParameters(adjustedProjectileTypeList, i)
		)
	  end
	else
	  for i = 1, (self.projectileCount or 1) do
		world.spawnProjectile(
		  adjustedProjectileType,
		  self:firePosition(),
		  activeItem.ownerEntityId(),
		  self:aimVector(self.inaccuracy, i, powerProjectile),
		  false,
		  self:currentProjectileParameters()
		)
	  end
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

function TheaEnergyBowShot:currentProjectileParameters(projectileList, index)
  local params = copy(self.projectileParameters or {})
  local projectileConfig = root.projectileConfig(self.projectileType or projectileList[index])
  if projectileList then
	params.power = self.baseDamage * self.weapon.damageLevelMultiplier * self.drawPercentage / #projectileList
  else
	params.power = self.baseDamage * self.weapon.damageLevelMultiplier * self.drawPercentage
  end
  params.powerMultiplier = activeItem.ownerPowerMultiplier()

  return params
end

function TheaEnergyBowShot:aimVector(inaccuracy, shotNumber, powerProjectile)
  local aimVector = {}
  if self.angleAdjustmentsPerShot and not powerProjectile then
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0) + self.angleAdjustmentsPerShot[shotNumber])
  elseif self.angleAdjustmentsPerPowerShot and powerProjectile then
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0) + self.angleAdjustmentsPerPowerShot[shotNumber])
  else
	aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  end
  
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaEnergyBowShot:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaEnergyBowShot:updateChargeIntake(chargeTimeLeft)
  --Update existing charge particles
  for i,particle in ipairs(self.chargeParticles) do
	particle.muzzlePosition = self:firePosition()
	particle.lifeTime = particle.lifeTime - self.dt
  end
  
  --If not yet at max particle count, add a new particle to the list
  self.particleCooldown = math.max(0, self.particleCooldown - self.dt)
  if self.particleCooldown == 0 and #self.chargeParticles < self.maxChargeParticles and chargeTimeLeft > self.particleLifetime then
	local particle = {
      muzzlePosition = self:firePosition(),
      vector = vec2.rotate({self.maxParticleDistance, 0}, math.random() * (2 * math.pi)),
	  lifeTime = self.particleLifetime,
	  maxLifeTime = self.particleLifetime
    }
    table.insert(self.chargeParticles, particle)
	
	self.particleCooldown = self.timeBewteenParticles
  end
  
  --Filter the existing particle list by particle lifetime to remove particles with negative lifetime
  local newChargeParticles = {}
  for i,particle in ipairs(self.chargeParticles) do	
	if particle.lifeTime > 0 then
	  newChargeParticles[#newChargeParticles+1] = particle
	end
  end
  self.chargeParticles = newChargeParticles
  
  activeItem.setScriptedAnimationParameter("particles", self.chargeParticles)
end

function TheaEnergyBowShot:uninit()
  self:reset()
end

function TheaEnergyBowShot:reset()
  animator.stopAllSounds("draw")
  animator.stopAllSounds("fullyDrawnLoop")
  animator.setGlobalTag("drawFrame", "0")
  self.weapon:setStance(self.stances.idle)
  animator.setParticleEmitterActive("chargeparticles", false)
  self.wasFullyDrawn = false
  
  --Charge particle set-up
  if self.useChargeParticles then
	self.chargeParticles = {}
	self.particleCooldown = 0
	activeItem.setScriptedAnimationParameter("particles", {})
  end
end
