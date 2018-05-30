--An advanced melee combo ability. Allows any of the combo steps to include a weapon spin animation, allows for completed combos to reset cooldown times, allows for firing of projectiles and many other small features

-- Melee primary ability
TheaEnhancedMeleeCombo = WeaponAbility:new()

function TheaEnhancedMeleeCombo:init()
  self.comboStep = 1
  self.airTime = 0
  self.currentParticleEmitter = nil

  self.energyUsage = self.energyUsage or 0

  self:computeDamageAndCooldowns()

  self.weapon:setStance(self.stances.idle)
  animator.setAnimationState("swoosh", "idle")

  self.edgeTriggerTimer = 0
  self.flashTimer = 0
  self.cooldownTimer = self.cooldowns[1]

  self.animKeyPrefix = self.animKeyPrefix or ""

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
	animator.setAnimationState("swoosh", "idle")
	self.weapon.aimAngle = 0 --Force aim angle to reset to 0 to properly go back into a non-rotatable stance after exiting a rotatable one
  end
end

-- Ticks on every update regardless if this is the active ability
function TheaEnhancedMeleeCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  --Debug functionality
  world.debugPoint(vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("blade", "projectileFirePoint") or {0,0})), "red")
  
  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 and self.useReadyFlash then
      self:readyFlash()
    end
  end

  if self.flashTimer > 0 then
    self.flashTimer = math.max(0, self.flashTimer - self.dt)
    if self.flashTimer == 0 then
      animator.setGlobalTag("bladeDirectives", "")
    end
  end

  --Calculate our time spent in the air for potential aerial moves
  if mcontroller.onGround() then
	self.airTime = 0
  else
	self.airTime = math.min(1.0, self.airTime + self.dt)
  end
  
  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) and fireMode == (self.activatingFireMode or self.abilitySlot) then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode

  if not self.weapon.currentAbility and self:shouldActivate() then
    self:setState(self.windup)
  end
end

-- State: windup
-- Windup animation before swinging
function TheaEnhancedMeleeCombo:windup()
  local stance = self.stances["windup"..self.comboStep]

  self.weapon:setStance(stance)
  
  --Optionally flash the weapon
  if stance.flashTime then
	self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end

  self.edgeTriggerTimer = 0

  --Timer used for optional shaking
  local timer = 0
  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
	util.wait(stance.duration, function()
	  --Optional particle emitter
	  if stance.particleEmitter then
		animator.setParticleEmitterActive(stance.particleEmitter, true)
		self.currentParticleEmitter = stance.particleEmitter
	  end
	  if stance.shake then
		local wavePeriod = (stance.shakeWavePeriod or 0.125) / (2 * math.pi)
		local waveAmplitude = stance.shakeWaveAmplitude or 0.075
		
		timer = timer + self.dt
		local rotation = waveAmplitude * math.sin(timer / wavePeriod)
		
		self.weapon.relativeWeaponRotation = rotation + util.toRadians(stance.weaponRotation) --Add weaponRotation again, as relativeWeaponRotation overwrites it
	  end
	end)
	if stance.particleEmitter then
	  animator.setParticleEmitterActive(stance.particleEmitter, false)
	end
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: wait
-- Waiting for next combo input
function TheaEnhancedMeleeCombo:wait()
  local stance = self.stances["wait"..(self.comboStep - 1)]

  self.weapon:setStance(stance)
  
  --Optionally flash the weapon
  if stance.flashTime then
	self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end

  util.wait(stance.duration, function()
    --Optional particle emitter
	if stance.particleEmitter then
	  animator.setParticleEmitterActive(stance.particleEmitter, true)
	  self.currentParticleEmitter = stance.particleEmitter
    end
    if self:shouldActivate() then
      self:setState(self.windup)
      return
    end
  end)
  if stance.particleEmitter then
	animator.setParticleEmitterActive(stance.particleEmitter, false)
  end

  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
  self.comboStep = 1
end

-- State: preslash
-- Brief frame in between windup and fire, allows for large movements to look more natural
function TheaEnhancedMeleeCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()
  
  --Optionally flash the weapon
  if stance.flashTime then
	self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end

  util.wait(stance.duration, function()
    --Optional particle emitter
	if stance.particleEmitter then
	  animator.setParticleEmitterActive(stance.particleEmitter, true)
	  self.currentParticleEmitter = stance.particleEmitter
    end
  end)
  if stance.particleEmitter then
	animator.setParticleEmitterActive(stance.particleEmitter, false)
  end

  self:setState(self.fire)
end

-- State: fire
function TheaEnhancedMeleeCombo:fire()
  local stance = self.stances["fire"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)
  
  --Optionally flash the weapon
  if stance.flashTime then
	self:animatedFlash(stance.flashTime, stance.flashDirectives or self.flashDirectives)
  end
  
  --Optionally fire a projectile
  if stance.projectile then
	local firePosition = vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("blade", "projectileFirePoint") or {0,0}))
	local params = stance.projectileParameters or {}
	params.power = stance.projectileDamage * config.getParameter("damageLevelMultiplier")
	params.powerMultiplier = activeItem.ownerPowerMultiplier()
	params.speed = util.randomInRange(params.speed)
	
	world.debugPoint(firePosition, "red")
	
	if not world.lineTileCollision(mcontroller.position(), firePosition) then
	  for i = 1, (stance.projectileCount or 1) do
		local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(stance.projectileInaccuracy or 0, 0) + (stance.projectileAimAngleOffset or 0))
		aimVector[1] = aimVector[1] * mcontroller.facingDirection()
		
		world.spawnProjectile(
		  stance.projectile,
		  firePosition,
		  activeItem.ownerEntityId(),
		  aimVector,
		  false,
		  params
		)
	  end
	end
  end
  
  --If this move has a velocity modifier, add it to our movement controller
  if stance.xVelocity then
	if stance.onlyInAir and self.airTime > 0.15 and not (stance.notInLiquid and mcontroller.liquidMovement()) and not (stance.notInSpace and mcontroller.zeroG()) or
	not stance.onlyInAir and self.airTime < 0.1 and not (stance.notInLiquid and mcontroller.liquidMovement()) and not (stance.notInSpace and mcontroller.zeroG()) or
	stance.anywhere then
	  if not stance.maxAimAngle or self.weapon.aimAngle <= stance.maxAimAngle then
		if stance.addVelocity then
		  mcontroller.setXVelocity(vec2.add(stance.xVelocity, mcontroller.xVelocity()))
		else
		  mcontroller.setXVelocity(stance.xVelocity)
		end
	  end
	end
  end
  if stance.yVelocity then
	if stance.onlyInAir and self.airTime > 0.15 and not (stance.notInLiquid and mcontroller.liquidMovement()) and not (stance.notInSpace and mcontroller.zeroG()) or
	not stance.onlyInAir and self.airTime < 0.1 and not (stance.notInLiquid and mcontroller.liquidMovement()) and not (stance.notInSpace and mcontroller.zeroG()) or
	stance.anywhere then
	  if not stance.maxAimAngle or self.weapon.aimAngle <= stance.maxAimAngle then
		if stance.addVelocity then
		  mcontroller.setYVelocity(vec2.add(stance.yVelocity, mcontroller.yVelocity()))
		else
		  mcontroller.setYVelocity(stance.yVelocity)
		end
	  end
	end
  end
  if stance.directionalVelocity then
	if stance.onlyInAir and self.airTime > 0.15 and not (stance.notInLiquid and mcontroller.liquidMovement()) and not (stance.notInSpace and mcontroller.zeroG()) or
	not stance.onlyInAir and self.airTime < 0.1 and not (stance.notInLiquid and mcontroller.liquidMovement()) and not (stance.notInSpace and mcontroller.zeroG()) or
	stance.anywhere then
	  if not stance.maxAimAngle or self.weapon.aimAngle <= stance.maxAimAngle then
		local targetVelocity = vec2.mul(vec2.norm(vec2.mul(self:aimVector(0), 1)), stance.directionalVelocity)
		if stance.jump then
		  mcontroller.controlJump()
		end
		if stance.addVelocity then
		  mcontroller.setVelocity(vec2.add(targetVelocity, mcontroller.velocity()))
		elseif stance.addMomentum then
		  mcontroller.setYVelocity(0)
		  mcontroller.addMomentum(targetVelocity)
		else
		  mcontroller.setVelocity(targetVelocity)
		end
	  end
	end
  end
  
  --If this step is configured as a "spin" move, spin the weapon
  if stance.spinRate then
	util.wait(stance.duration, function()
	  local damageArea = partDamageArea("swoosh")
	  self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
	
	  --Remove the weapon from the player's hand, allowing it to rotate freely
	  activeItem.setOutsideOfHand(true)
	
	  --Spin the weapon
	  self.weapon.relativeWeaponRotation = self.weapon.relativeWeaponRotation + util.toRadians(stance.spinRate * self.dt)
	
	  --Optionally force the player to walk while in this stance
	  if stance.forceWalking then
		mcontroller.controlModifiers({runningSuppressed=true})
	  end
	  
	  --Optionally freeze the player in place if so configured
	  if stance.freezePlayer then
		mcontroller.setVelocity({0,0})
	  end
	end)
	animator.setAnimationState("swoosh", "idle")
  --If this step is a regular attack, simply set the damage area for the duration of the step
  else
	util.wait(stance.duration, function()
	  local damageArea = partDamageArea("swoosh")
	  self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
	  
	  --Optionally freeze the player in place if so configured
	  if stance.freezePlayer then
		mcontroller.setVelocity({0,0})
	  end
	end)
  end
  
  --If this wasn't the last combo step, go to next step
  --Else, go to cooldown
  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    if self.fullComboCooldown then
	  self.cooldownTimer = self.fullComboCooldown
	else
	  self.cooldownTimer = self.cooldowns[self.comboStep]
	end
    self.comboStep = 1
  end
end

function TheaEnhancedMeleeCombo:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function TheaEnhancedMeleeCombo:readyFlash()
  animator.setGlobalTag("bladeDirectives", self.flashDirectives)
  self.flashTimer = self.flashTime
end

function TheaEnhancedMeleeCombo:animatedFlash(flashTime, flashDirectives)
  animator.setGlobalTag("bladeDirectives", flashDirectives)
  self.flashTimer = flashTime or self.flashTime
end

function TheaEnhancedMeleeCombo:computeDamageAndCooldowns()
  local attackTimes = {}
  for i = 1, self.comboSteps do
    local attackTime = self.stances["windup"..i].duration + self.stances["fire"..i].duration
    if self.stances["preslash"..i] then
      attackTime = attackTime + self.stances["preslash"..i].duration
    end
    table.insert(attackTimes, attackTime)
  end

  self.cooldowns = {}
  local totalAttackTime = 0
  local totalDamageFactor = 0
  for i, attackTime in ipairs(attackTimes) do
    self.stepDamageConfig[i] = util.mergeTable(copy(self.damageConfig), self.stepDamageConfig[i])
    self.stepDamageConfig[i].timeoutGroup = "primary"..i

    local damageFactor = self.stepDamageConfig[i].baseDamageFactor
    self.stepDamageConfig[i].baseDamage = damageFactor * self.baseDps * self.fireTime

    totalAttackTime = totalAttackTime + attackTime
    totalDamageFactor = totalDamageFactor + damageFactor

    local targetTime = totalDamageFactor * self.fireTime
    local speedFactor = 1.0 * (self.comboSpeedFactor ^ i)
    table.insert(self.cooldowns, (targetTime - totalAttackTime) * speedFactor)
  end
end

--Aim vector for firing projectiles
function TheaEnhancedMeleeCombo:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaEnhancedMeleeCombo:uninit()
  self.weapon:setDamage()
  if self.currentParticleEmitter then
	animator.setParticleEmitterActive(self.currentParticleEmitter, false)
  end
end
