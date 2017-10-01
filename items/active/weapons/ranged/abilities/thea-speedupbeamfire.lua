require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

TheaBeamFire = WeaponAbility:new()

function TheaBeamFire:init()
  self.damageConfig.baseDamage = self.baseDps * self.minFiringSpeed

  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.minFiringSpeed
  self.impactSoundTimer = 0
  self.impactDamageTimer = self.impactDamageTimeout

  --Reset the rate of fire
  self.adjustedFireTime = self.minFiringSpeed
  self.timeSpentFiring = 0
  self.fireSpeedFactor = 0
  self.firespeedMultiplier = 0.01
  
  self.weapon.onLeaveAbility = function()
    self.weapon:setDamage()
    activeItem.setScriptedAnimationParameter("chains", {})
    animator.setParticleEmitterActive("beamCollision", false)
    animator.stopAllSounds("fireLoop")
    self.weapon:setStance(self.stances.idle)
  end
end

function TheaBeamFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.impactSoundTimer = math.max(self.impactSoundTimer - self.dt, 0)
  self.impactDamageTimer = math.max(self.impactDamageTimer - self.dt, 0)

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy") then

    self:setState(self.fire)
  end
end

function TheaBeamFire:fire()
  self.weapon:setStance(self.stances.fire)

  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)
  
  local wasColliding = false
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) and not world.lineTileCollision(mcontroller.position(), self:firePosition()) do
    --Calculate our intended rate of fire
	self.timeSpentFiring = math.min(self.maxFiringTime, self.timeSpentFiring + self.dt)
	self.fireSpeedFactor = self.timeSpentFiring / self.maxFiringTime
	self.firespeedMultiplier = math.max(0.01, (self.minFiringSpeed / self.maxFiringSpeed) * self.fireSpeedFactor) * self.soundPitchMultiplier
	
	self.adjustedFireTime = self.minFiringSpeed - (self.fireSpeedFactor * (self.minFiringSpeed - self.maxFiringSpeed))
	
	--Adjust the firing sound pitch based on our rate of fire
	animator.setSoundPitch("fireLoop", self.firespeedMultiplier, 0)
	world.debugText(self.fireSpeedFactor, mcontroller.position(), "red")
	world.debugText(self.firespeedMultiplier, vec2.add(mcontroller.position(), {0, 1}), "green")
	
	--Do the beam fire attack
	local beamStart = self:firePosition()
    local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
    local beamLength = self.beamLength
	local beamIsColliding = false

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
        animator.setSoundPosition("beamImpact", {beamLength, 0})
        animator.playSound("beamImpact")
        self.impactSoundTimer = self.adjustedFireTime
      end
	  
	  if self.spawnImpactProjectile then
		--Spawn a projectile at beamend, which damages terrain
		if self.impactDamageTimer == 0 then
		  world.spawnProjectile(
			self.impactProjectile,
			collidePoint,
			activeItem.ownerEntityId()
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

	self.weapon:setDamage() --Reset the damage field to ensure it gets updated properly
    self.weapon:setDamage(self.damageConfig, {self.weapon.muzzleOffset, {self.weapon.muzzleOffset[1] + beamLength, self.weapon.muzzleOffset[2]}}, self.adjustedFireTime)

    self:drawBeam(beamEnd, collidePoint)

    coroutine.yield()
  end

  self:reset()
  animator.playSound("fireEnd")

  self.cooldownTimer = self.adjustedFireTime
  self:setState(self.cooldown)
end

function TheaBeamFire:drawBeam(endPos, didCollide)
  local newChain = copy(self.chain)
  newChain.startOffset = vec2.add(self.weapon.muzzleOffset, self.chain.startOffset or 0)
  newChain.endPosition = endPos
  newChain.waveform.frequency = self.chain.waveform.frequency * self.firespeedMultiplier
  newChain.waveform.amplitude = self.chain.waveform.amplitude * self.firespeedMultiplier

  if didCollide then
    newChain.endSegmentImage = nil
  end

  activeItem.setScriptedAnimationParameter("chains", {newChain})
end

function TheaBeamFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  self.adjustedFireTime = self.minFiringSpeed
  self.timeSpentFiring = 0
  self.fireSpeedFactor = 0
  
  util.wait(self.stances.cooldown.duration, function()
	--Nothing here
  end)
end

function TheaBeamFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaBeamFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaBeamFire:uninit()
  self:reset()
end

function TheaBeamFire:reset()
  self.weapon:setDamage()
  activeItem.setScriptedAnimationParameter("chains", {})
  animator.setParticleEmitterActive("beamCollision", false)
  animator.setParticleEmitterActive("beamParticles", false)
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")
  
  --Reset the rate of fire
  self.adjustedFireTime = self.minFiringSpeed
  self.timeSpentFiring = 0
  self.fireSpeedFactor = 0
  self.firespeedMultiplier = 0.01
end
