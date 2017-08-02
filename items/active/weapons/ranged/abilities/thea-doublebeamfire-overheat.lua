require "/scripts/interp.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"

TheaDoubleBeamFireOverheat = WeaponAbility:new()

function TheaDoubleBeamFireOverheat:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  self.impactSoundTimer = 0
  self.impactDamageTimer = self.impactDamageTimeout

  self.weapon.onLeaveAbility = function()
    self.weapon:setDamage()
    activeItem.setScriptedAnimationParameter("chains", {})
    animator.setParticleEmitterActive("beamCollision", false)
    animator.stopAllSounds("fireLoop")
    self.weapon:setStance(self.stances.idle)
  end
end

function TheaDoubleBeamFireOverheat:update(dt, fireMode, shiftHeld)
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

function TheaDoubleBeamFireOverheat:fire()
  self.weapon:setStance(self.stances.fire)

  animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)

  local wasColliding = false
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", (self.energyUsage or 0) * self.dt) do
    -- ========================================= PRIMARY BEAM =========================================
	local primaryBeamStart = self:firePosition()
    local primaryBeamEnd = vec2.add(primaryBeamStart, vec2.mul(vec2.norm(self:aimVector(0)), self.beamLength))
    local primaryBeamLength = self.beamLength
	local primaryBeamIsColliding = false

	--Do a line collision check on terrain
    local primaryCollidePoint = world.lineCollision(primaryBeamStart, primaryBeamEnd)
	if primaryCollidePoint then
	  primaryBeamIsColliding = true
	end
	
	if self.laserPiercing == false then
	  local targets = world.entityLineQuery(primaryBeamStart, primaryBeamEnd, {
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
		  if not world.lineCollision(primaryBeamStart, targetPosition) then
			local targetDistance = world.magnitude(primaryBeamStart, targetPosition)
			--If the target currently being processed is closer than the nearest target found so far, make this target the nearest target
			if targetDistance < nearestTargetDistance then
			  nearestTargetDistance = targetDistance
			  local beamDirection = vec2.rotate({1, 0}, self.weapon.aimAngle)
			  beamDirection[1] = beamDirection[1] * mcontroller.facingDirection()
			  local beamVector = vec2.mul(beamDirection, nearestTargetDistance)
			  primaryCollidePoint = vec2.add(primaryBeamStart, beamVector)
			  primaryBeamIsColliding = true
			end
		  end
		end
	  end
	end
	
    if primaryBeamIsColliding == true then
      primaryBeamEnd = primaryCollidePoint

      primaryBeamLength = world.magnitude(primaryBeamStart, primaryBeamEnd)

      animator.setParticleEmitterActive("beamCollision", true)
      animator.resetTransformationGroup("beamEnd")
      animator.translateTransformationGroup("beamEnd", {primaryBeamLength, 0})

      if self.impactSoundTimer == 0 then
        animator.setSoundPosition("beamImpact", {primaryBeamLength, 0})
        animator.playSound("beamImpact")
        self.impactSoundTimer = self.fireTime
      end
	  
	  if self.spawnImpactProjectile then
		--Spawn a projectile at beamend, which damages terrain
		if self.impactDamageTimer == 0 then
		  world.spawnProjectile(
			self.impactProjectile,
			primaryCollidePoint,
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
	animator.setParticleEmitterEmissionRate("beamParticles", primaryBeamLength*2)
	animator.resetTransformationGroup("beam")
	animator.scaleTransformationGroup("beam", {primaryBeamLength*2, 0})
	animator.translateTransformationGroup("beam", vec2.add(self.weapon.muzzleOffset, {primaryBeamLength/2, 0}))

    self.weapon:setDamage(self.damageConfig, {self.weapon.muzzleOffset, {self.weapon.muzzleOffset[1] + primaryBeamLength, self.weapon.muzzleOffset[2]}}, self.fireTime)

    self:drawBeam(primaryBeamEnd, primaryCollidePoint)

    coroutine.yield()
  end

  self:reset()
  animator.playSound("fireEnd")

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function TheaDoubleBeamFireOverheat:drawBeam(endPos, didCollide)
  local newChain = copy(self.chain)
  newChain.startOffset = self.weapon.muzzleOffset
  newChain.endPosition = endPos

  if didCollide then
    newChain.endSegmentImage = nil
  end

  activeItem.setScriptedAnimationParameter("chains", {newChain})
end

function TheaDoubleBeamFireOverheat:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  util.wait(self.stances.cooldown.duration, function()

  end)
end

function TheaDoubleBeamFireOverheat:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaDoubleBeamFireOverheat:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaDoubleBeamFireOverheat:uninit()
  self:reset()
end

function TheaDoubleBeamFireOverheat:reset()
  self.weapon:setDamage()
  activeItem.setScriptedAnimationParameter("chains", {})
  animator.setParticleEmitterActive("beamCollision", false)
  animator.setParticleEmitterActive("beamParticles", false)
  animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")
end
