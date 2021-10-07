-- Melee primary ability
TheaShieldBladeCombo = WeaponAbility:new()

function TheaShieldBladeCombo:init()
  self.comboStep = 1

  self.wasActive = false
  self.energyUsage = self.energyUsage or 0
  storage.chargeAnimationTimer = storage.chargeAnimationTimer or 0
  storage.chargeCooldownTimer = storage.chargeCooldownTimer or 0

  self:computeDamageAndCooldowns()

  self.weapon:setStance(self.stances.idle)

  self.edgeTriggerTimer = 0
  self.flashTimer = 0
  self.cooldownTimer = self.cooldowns[1]

  self.animKeyPrefix = self.animKeyPrefix or ""
  
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function TheaShieldBladeCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  --Swap frames for when the weapon is in the front or back hand
  animator.setGlobalTag("hand", self.weapon:isFrontHand() and "front" or "back")

  --Charge functionality
  storage.chargeCooldownTimer = math.max(0, storage.chargeCooldownTimer - self.dt)
  if storage.chargeCooldownTimer == 0 then
	storage.chargeAnimationTimer = math.min(self.chargeAnimationTime, storage.chargeAnimationTimer + self.dt)
	local animationFrame = math.ceil((storage.chargeAnimationTimer / self.chargeAnimationTime) * self.chargeAnimationFrames)
	local animationTag = "active." .. animationFrame
	animator.setGlobalTag("state", animationTag)
	animator.setLightActive("glow", true)
	
	if not self.wasActive then
	  animator.playSound("activate")
	  self.wasActive = true
	end
	
	--world.debugText(animationFrame, vec2.add(mcontroller.position(), {0,2}), "yellow")
	--world.debugText(animationTag, vec2.add(mcontroller.position(), {0,3}), "yellow")
  else
	animator.setGlobalTag("state", "idle")
	animator.setLightActive("glow", false)
	storage.chargeAnimationTimer = 0
	self.wasActive = false
  end
  
  world.debugPoint(vec2.add(mcontroller.position(), activeItem.handPosition(self.projectileOffset)), "red")
  --world.debugText(storage.chargeCooldownTimer, vec2.add(mcontroller.position(), {0,0}), "yellow")
  --world.debugText(self.chargeAnimationTimer, vec2.add(mcontroller.position(), {0,1}), "yellow")

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
function TheaShieldBladeCombo:windup()
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
-- waiting for next combo input
function TheaShieldBladeCombo:wait()
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
-- brief frame in between windup and fire
function TheaShieldBladeCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)

  self:setState(self.fire)
end

-- State: fire
function TheaShieldBladeCombo:fire()
  local stance = self.stances["fire"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)
  
  --If charge is ready, fling a projectile
  if storage.chargeCooldownTimer == 0 and stance.allowProjectile then
	animator.playSound("fling")
	animator.burstParticleEmitter("fling")
	storage.chargeCooldownTimer = self.chargeCooldownTime
	
	local params = sb.jsonMerge(self.projectileParameters, {})
	params.power = self.projectileDamage * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
	params.powerMultiplier = activeItem.ownerPowerMultiplier()
	params.speed = util.randomInRange(params.speed)
	
	world.spawnProjectile(
        self.projectileType,
        vec2.add(mcontroller.position(), activeItem.handPosition(self.projectileOffset)),
        activeItem.ownerEntityId(),
        self:aimVector(self.projectileInaccuracy),
        false,
        params
      )
  end

  util.wait(stance.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
  end)

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
  end
end

function TheaShieldBladeCombo:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function TheaShieldBladeCombo:readyFlash()
  animator.setGlobalTag("bladeDirectives", self.flashDirectives)
  self.flashTimer = self.flashTime
end

function TheaShieldBladeCombo:computeDamageAndCooldowns()
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

function TheaShieldBladeCombo:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaShieldBladeCombo:uninit()
  self.weapon:setDamage()
end
