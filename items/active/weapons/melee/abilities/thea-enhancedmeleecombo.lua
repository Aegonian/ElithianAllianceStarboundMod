--An advanced melee combo ability. Allows any of the combo steps to include a weapon spin animation, and allows for completed combos to reset cooldown times

-- Melee primary ability
TheaEnhancedMeleeCombo = WeaponAbility:new()

function TheaEnhancedMeleeCombo:init()
  self.comboStep = 1
  self.airTime = 0

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
  end
end

-- Ticks on every update regardless if this is the active ability
function TheaEnhancedMeleeCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
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

  self.edgeTriggerTimer = 0

  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(stance.duration)
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

  util.wait(stance.duration, function()
    if self:shouldActivate() then
      self:setState(self.windup)
      return
    end
  end)

  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
  self.comboStep = 1
end

-- State: preslash
-- Brief frame in between windup and fire, allows for large movements to look more natural
function TheaEnhancedMeleeCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)

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
  
  --If this move has a velocity modifier, add it to our movement controller
  if stance.xVelocity then
	if stance.onlyInAir and self.airTime > 0.15 and not (stance.notInLiquid and mcontroller.liquidMovement()) or
	not stance.onlyInAir and self.airTime < 0.1 and not (stance.notInLiquid and mcontroller.liquidMovement()) then
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
	if stance.onlyInAir and self.airTime > 0.15 and not (stance.notInLiquid and mcontroller.liquidMovement()) or
	not stance.onlyInAir and self.airTime < 0.1 and not (stance.notInLiquid and mcontroller.liquidMovement()) then
	  if not stance.maxAimAngle or self.weapon.aimAngle <= stance.maxAimAngle then
		if stance.addVelocity then
		  mcontroller.setYVelocity(vec2.add(stance.yVelocity, mcontroller.yVelocity()))
		else
		  mcontroller.setYVelocity(stance.yVelocity)
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

function TheaEnhancedMeleeCombo:uninit()
  self.weapon:setDamage()
end
