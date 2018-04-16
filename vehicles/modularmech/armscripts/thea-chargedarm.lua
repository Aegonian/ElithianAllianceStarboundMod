require "/vehicles/modularmech/armscripts/base.lua"

TheaChargedArm = MechArm:extend()

function TheaChargedArm:init()
  self.windupTimer = 0
  self.cooldownTimer = 0
  self.fireTimer = 0
  self.chargeStarted = false
end

function TheaChargedArm:update(dt)
  --Count down fire and cooldown timers every frame
  self.fireTimer = math.max(0, self.fireTimer - dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)
  
  --Activate charge muzzle particles if in windup state
  if animator.animationState(self.armName) == "windup" and self.chargeMuzzleParticles then
	animator.setParticleEmitterActive(self.armName .. "ChargeMuzzle", true)
  elseif self.chargeMuzzleParticles then
	animator.setParticleEmitterActive(self.armName .. "ChargeMuzzle", false)
  end
  
  --Activate muzzle particles if in windup state
  if animator.animationState(self.armName) == ( "windup" or "active" ) and self.chargeParticles then
	animator.setParticleEmitterActive(self.armName .. "Charge", true)
  elseif self.chargeParticles then
	animator.setParticleEmitterActive(self.armName .. "Charge", false)
  end
  
  --While holding down fire, charge the weapon or fire when ready
  if self.isFiring and self.cooldownTimer == 0 then
	if not self.chargeStarted then
	  animator.setAnimationState(self.armName, "windup")
	  animator.playSound(self.armName .. "Charge", -1)
	  self.chargeStarted = true
	else
	  self.windupTimer = math.min(self.windupTimer + dt, self.windupTime)
	  
	  if self.windupTimer == self.windupTime then
		if self.repeatFire and self.fireTimer == 0 then
		  self:fire()

		  animator.burstParticleEmitter(self.armName .. "Fire")
		  animator.playSound(self.armName .. "Fire")
		  animator.stopAllSounds(self.armName .. "Charge")

		  self.fireTimer = self.fireTime
		else
		  self:fire()

		  animator.burstParticleEmitter(self.armName .. "Fire")
		  animator.playSound(self.armName .. "Fire")
		  animator.stopAllSounds(self.armName .. "Charge")

		  self.chargeStarted = false
		  self.windupTimer = 0
		  self.cooldownTimer = self.cooldownTime
		  animator.setAnimationState(self.armName, "winddown")
		end
	  end
	end
  --If we stopped firing
  elseif self.wasFiring and not self.isFiring and self.chargeStarted == true then
	self.fireTimer = 0
	
	--Stop charge sounds, and play discharge sound if the charge was unfinished
	animator.stopAllSounds(self.armName .. "Charge")
	if self.windupTimer ~= self.windupTime then
	  animator.playSound(self.armName .. "Discharge")
	end
	
	self.chargeStarted = false
	self.windupTimer = 0
	self.cooldownTimer = self.cooldownTime
	animator.setAnimationState(self.armName, "rotate")
  end
  
  --While we have a driver and we are active
  if self.driverId and (self.isFiring or self.cooldownTimer > 0) then
	animator.rotateTransformationGroup(self.armName, self.aimAngle, self.shoulderOffset)
	
	self.bobLocked = true
  else
	animator.setAnimationState(self.armName, "idle")

    self.bobLocked = false
  end
end

function TheaChargedArm:fire()
  local projectileIds = {}

  if self.aimAngle and self.aimVector and self.firePosition and self:rayCheck(self.firePosition) then
    local pParams = copy(self.projectileParameters)
    if not self.projectileTrackSource and self.projectileInheritVelocity and mcontroller.zeroG() then
      pParams.referenceVelocity = mcontroller.velocity()
    else
      pParams.referenceVelocity = nil
    end
    pParams.processing = self.directives

    local pCount = self.projectileCount or 1
    local pSpread = self.projectileSpread or 0
    local inacc = self.projectileInaccuracy or 0
    local aimVec = vec2.rotate(self.aimVector, -0.5 * (pCount - 1) * pSpread)

    local firePos = self.firePosition
    local pSpacing
    if self.projectileSpacing and pCount > 1 then
      pSpacing = vec2.mul(vec2.rotate(self.projectileSpacing, self.aimAngle), {self.facingDirection, 1})
      firePos = vec2.add(firePos, vec2.mul(pSpacing, (pCount - 1) * -0.5))
    end

    for i = 1, pCount do
      local thisFirePos = firePos
      if self.projectileRandomOffset then
        thisFirePos = vec2.add(thisFirePos, {(math.random() - 0.5) * self.projectileRandomOffset[1], (math.random() - 0.5) * self.projectileRandomOffset[2]})
      end
	  
      local thisAimVec = aimVec
      if self.projectileInaccuracy then
        thisAimVec = vec2.rotate(thisAimVec, sb.nrand(self.projectileInaccuracy, 0))
      end

      if self.projectileRandomSpeed then
        pParams.speed = util.randomInRange(self.projectileRandomSpeed)
      end

      local projectileId = world.spawnProjectile(
          self.projectileType,
          thisFirePos,
          self.driverId,
          thisAimVec,
          self.projectileTrackSource,
          pParams)

      if projectileId then
        table.insert(projectileIds, projectileId)
      end

      aimVec = vec2.rotate(aimVec, pSpread)
      if pSpacing then
        firePos = vec2.add(firePos, pSpacing)
      end
    end
  end

  return projectileIds
end
