require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

TheaChargedBeamAltFire = WeaponAbility:new()

function TheaChargedBeamAltFire:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.weapon:setStance(self.stances.idle)

  self.chargeTimer = self.chargeTime
  self.cooldownTimer = self.cooldownTime
  self.impactSoundTimer = 0
  self.impactDamageTimer = self.impactDamageTimeout
  self.timeSpentFiring = 0
  
  self.chargeHasStarted = false
  self.shouldDischarge = false

  self.chainAnimationTimer = 0

  self:reset()

  self.weapon.onLeaveAbility = function()
    self.weapon:setDamage()
    activeItem.setScriptedAnimationParameter("chains", {})
    animator.setParticleEmitterActive("beamCollision", false)
    animator.stopAllSounds("altBeamLoop")
	animator.stopAllSounds("chargeLoopAlt")
    self.weapon:setStance(self.stances.idle)
	self:reset()
  end
end

function TheaChargedBeamAltFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.impactSoundTimer = math.max(self.impactSoundTimer - self.dt, 0)
  self.impactDamageTimer = math.max(self.impactDamageTimer - self.dt, 0)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    self:setState(self.charge)
  end
end

function TheaChargedBeamAltFire:charge()
  self.weapon:setStance(self.stances.charge)
  
  self.chargeHasStarted = true

  animator.playSound("chargeLoopAlt", -1)
  animator.setAnimationState("chargeAlt", "charging")
  animator.setParticleEmitterActive("chargeparticlesAlt", true)
  
  --While charging, but not yet ready, count down the charge timer
  while self.chargeTimer > 0 and self.fireMode == (self.activatingFireMode or self.abilitySlot) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) do
    self.chargeTimer = math.max(0, self.chargeTimer - self.dt)

	--Prevent energy regen while charging
	status.setResourcePercentage("energyRegenBlock", 0.6)

	--Optionally update the charge intake particles
	if self.useChargeParticles then
	  self:updateChargeIntake(self.chargeTimer)
	end
	
	--Enable walk while firing
	if self.walkWhileFiring == true then
      mcontroller.controlModifiers({runningSuppressed=true})
	end
	
    coroutine.yield()
  end
  
  --Optionally reset the charge intake particles
  if self.useChargeParticles then
	activeItem.setScriptedAnimationParameter("particles", {})
  end
  
  --If the charge is ready, we have line of sight and plenty of energy, go to firing state
  if self.chargeTimer == 0 and not status.resourceLocked("energy") and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    self:setState(self.fire)
  --If not charging and charge isn't ready, go to cooldown
  else
    self.shouldDischarge = true
	animator.playSound("discharge")
    self:setState(self.cooldown)
  end
end

function TheaChargedBeamAltFire:fire()
  self.weapon:setStance(self.stances.fire)

  animator.stopAllSounds("chargeLoopAlt")
  
  animator.playSound("altBeamStart")
  animator.playSound("altBeamLoop", -1)

  if self.recoilKnockbackVelocity and not (self.crouchStopsRecoil and mcontroller.crouching()) then
	mcontroller.controlJump()
  end
  
  local wasColliding = false
  while (self.fireMode == (self.activatingFireMode or self.abilitySlot) or (self.minFiringTime and self.timeSpentFiring < self.minFiringTime)) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) and not (self.maxFiringTime and self.timeSpentFiring > self.maxFiringTime) do
    local beamStart = self:firePosition()
    local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
    local beamLength = self.beamLength
	local beamIsColliding = false
	
	--Count up the firing time
	self.timeSpentFiring = self.timeSpentFiring + self.dt
	
	--Enable walk while firing
	if self.walkWhileFiring == true then
      mcontroller.controlModifiers({runningSuppressed=true})
	end

	--Do a line collision check on terrain
    local collidePoint = world.lineCollision(beamStart, beamEnd)
	if collidePoint then
	  beamIsColliding = true
	end
	
	if self.laserPiercing == false then
	  local targets = world.entityLineQuery(beamStart, beamEnd, {
		withoutEntityId = activeItem.ownerEntityId(),
		includedTypes = {"creature"},
		order = "nearest"
	  })
	  --Set the default distance to nearest target to max search distance
	  local nearestTargetDistance = beamLength
	  for _, target in ipairs(targets) do
		--Make sure we can damage the targeted entity
		if world.entityCanDamage(activeItem.ownerEntityId(), target) then
		  local targetPosition = world.entityPosition(target)
		  --Make sure we have line of sight on this entity
		  if not world.lineCollision(beamStart, targetPosition) then
			local targetDistance = world.magnitude(beamStart, targetPosition)
			--If the target currently being processed is closer than the nearest target found so far, make this target the nearest target
			if targetDistance < nearestTargetDistance then
			  nearestTargetDistance = targetDistance
			  local beamDirection = vec2.rotate({1, 0}, self.weapon.aimAngle)
			  beamDirection[1] = beamDirection[1] * mcontroller.facingDirection()
			  local beamVector = vec2.mul(beamDirection, nearestTargetDistance)
			  collidePoint = vec2.add(beamStart, beamVector)
			  beamIsColliding = true
			end
		  end
		end
	  end
	end
	
    if beamIsColliding == true then
      beamEnd = collidePoint

      beamLength = world.magnitude(beamStart, beamEnd)

      animator.setParticleEmitterActive("beamCollision", true)
      animator.resetTransformationGroup("beamEnd")
      animator.translateTransformationGroup("beamEnd", {beamLength, 0})

      if self.impactSoundTimer == 0 then
        animator.setSoundPosition("altBeamImpact", {beamLength, 0})
        animator.playSound("altBeamImpact")
        self.impactSoundTimer = self.fireTime
      end
	  
	  if self.spawnImpactProjectile then
		--Spawn a projectile at beamend, which damages terrain
		if self.impactDamageTimer == 0 then
		  local params = {}
		  params.power = self:damagePerImpactProjectile()
		  params.powerMultiplier = activeItem.ownerPowerMultiplier()
		  
		  world.spawnProjectile(
			self.impactProjectile,
			collidePoint,
			activeItem.ownerEntityId(),
			self:aimVector(0),
			false,
			params
		  )
		self.impactDamageTimer = self.impactDamageTimeout
		end
	  end
    else
      animator.setParticleEmitterActive("beamCollision", false)
    end
	
	--Code for particles along the length of the beam
	animator.setParticleEmitterActive("beamParticles", true)
	animator.setParticleEmitterEmissionRate("beamParticles", beamLength*2)
	animator.resetTransformationGroup("beam")
	animator.scaleTransformationGroup("beam", {beamLength*2, 0})
	animator.translateTransformationGroup("beam", vec2.add(self.weapon.muzzleOffset, {beamLength/2, 0}))

	--Box collision type (uses beamWidth)
	if self.beamCollisionType == "box" then
	  local damagePoly = {
		vec2.add(self.weapon.muzzleOffset, {0, self.beamWidth/2}),
		vec2.add(self.weapon.muzzleOffset, {0, -self.beamWidth/2}),
		{self.weapon.muzzleOffset[1] + beamLength, self.weapon.muzzleOffset[2] - self.beamWidth/2},
		{self.weapon.muzzleOffset[1] + beamLength, self.weapon.muzzleOffset[2] + self.beamWidth/2}
	  }
	  self.weapon:setDamage(self.damageConfig, damagePoly, self.fireTime)
	
	--Taper collision type (uses beamWidth, tapers to a point)
	elseif self.beamCollisionType == "taper" then
	  local damagePoly = {
		vec2.add(self.weapon.muzzleOffset, {0, self.beamWidth/2}),
		vec2.add(self.weapon.muzzleOffset, {0, -self.beamWidth/2}),
		{self.weapon.muzzleOffset[1] + beamLength, self.weapon.muzzleOffset[2]}
	  }
	  self.weapon:setDamage(self.damageConfig, damagePoly, self.fireTime)
	
	--Line collision type (default)
	elseif self.beamCollisionType == "line" or not self.beamCollisionType then
	  self.weapon:setDamage(self.damageConfig, {self.weapon.muzzleOffset, {self.weapon.muzzleOffset[1] + beamLength, self.weapon.muzzleOffset[2]}}, self.fireTime)
	end
	
	--Draw the beam
    self:drawBeam(beamEnd, collidePoint)
	
	--Optionally apply knockback to the player
	if self.recoilKnockbackVelocity then
	  --If not crouching or if crouch does not impact recoil
	  if not (self.crouchStopsRecoil and mcontroller.crouching()) then
		local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.recoilKnockbackVelocity * self.dt)
		mcontroller.addMomentum(recoilVelocity)
	  --If crouching
	  elseif self.crouchRecoilKnockbackVelocity then
		local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), -1)), self.crouchRecoilKnockbackVelocity * self.dt)
		mcontroller.addMomentum(recoilVelocity)
	  end
	end
	
	--Optionally enable beam muzzle particles
	if self.beamMuzzleParticles then
	  animator.setParticleEmitterActive("beamMuzzleParticlesAlt", true)
	end

    coroutine.yield()
  end

  self:reset()
  animator.playSound("altBeamEnd")

  self.chargeTimer = self.chargeTime
  self.cooldownTimer = self.cooldownTime
  
  self:setState(self.cooldown)
end

function TheaChargedBeamAltFire:drawBeam(endPos, didCollide)
  local newChain = copy(self.chain)
  newChain.startOffset = self.weapon.muzzleOffset
  newChain.endPosition = endPos
  
  --Optionally animate the chain beam
  if self.animatedChain then
	self.chainAnimationTimer = math.min(self.chainAnimationTime, self.chainAnimationTimer + self.dt)
	if self.chainAnimationTimer == self.chainAnimationTime then
	  self.chainAnimationTimer = 0
	end
	
	local chainAnimationFrame = 1
	chainAnimationFrame = math.floor(self.chainAnimationTimer / self.chainAnimationTime * self.chainAnimationFrames)
	
	newChain.segmentImage = self.chain.segmentImage .. ":" .. chainAnimationFrame
  end
  
  if didCollide then
    newChain.endSegmentImage = nil
  end

  activeItem.setScriptedAnimationParameter("chains", {newChain})
end

function TheaChargedBeamAltFire:cooldown()
  self.timeSpentFiring = 0
  
  if self.shouldDischarge == true then
    self.weapon:updateAim()
	self.weapon:setStance(self.stances.discharge)
	self.shouldDischarge = false
	
	local progress = 0
    util.wait(self.stances.discharge.duration, function()
      local from = self.stances.discharge.weaponOffset or {0,0}
      local to = self.stances.idle.weaponOffset or {0,0}
      self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

      self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.discharge.weaponRotation, self.stances.idle.weaponRotation))
      self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.discharge.armRotation, self.stances.idle.armRotation))

      progress = math.min(1.0, progress + (self.dt / self.stances.discharge.duration))
    end)
  else
    self.weapon:updateAim()
	self.weapon:setStance(self.stances.cooldown)
	
    local progress = 0
    util.wait(self.stances.cooldown.duration, function()
      local from = self.stances.cooldown.weaponOffset or {0,0}
      local to = self.stances.idle.weaponOffset or {0,0}
      self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

      self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
      self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

      progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
    end)
  end
end

function TheaChargedBeamAltFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaChargedBeamAltFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaChargedBeamAltFire:updateChargeIntake(chargeTimeLeft)  
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

function TheaChargedBeamAltFire:damagePerImpactProjectile()
  return (self.impactProjectileDamage or (self.impactProjectileDps * self.impactDamageTimeout)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier")
end

function TheaChargedBeamAltFire:uninit()
  self:reset()
end

function TheaChargedBeamAltFire:reset()
  self.timeSpentFiring = 0
  
  --Charge reset
  animator.setAnimationState("chargeAlt", "off")
  animator.setParticleEmitterActive("chargeparticlesAlt", false)
  self.chargeHasStarted = false
  animator.setAnimationState("chargeAlt", "off")
  self.chargeTimer = self.chargeTime

  --Beam reset
  self.weapon:setDamage()
  activeItem.setScriptedAnimationParameter("chains", {})
  animator.setParticleEmitterActive("beamCollision", false)
  animator.setParticleEmitterActive("beamParticles", false)
  animator.stopAllSounds("altBeamStart")
  animator.stopAllSounds("altBeamLoop")
  animator.stopAllSounds("chargeLoopAlt")
  
  --Optionally enable beam muzzle particles
  if self.beamMuzzleParticles then
	animator.setParticleEmitterActive("beamMuzzleParticlesAlt", false)
  end
  
  --Charge particle set-up
  if self.useChargeParticles then
	self.chargeParticles = {}
	self.particleCooldown = 0
	activeItem.setScriptedAnimationParameter("particles", {})
  end
end
