require "/items/active/weapons/weapon.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

TheaBowSpearTransform = WeaponAbility:new()

function TheaBowSpearTransform:init()
  self.comboStep = 1
  self.animKeyPrefix = self.animKeyPrefix or ""

  self:reset()
  self:computeDamageAndCooldowns()

  self.edgeTriggerTimer = 0
  self.cooldownTimer = self.cooldowns[1]
  
  self.transformCooldownTimer = self.transformCooldownTime
end

function TheaBowSpearTransform:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  --Adjust the weapon's aimOffset value to correct the aim for spear and bow modes
  if self.transformed then
	self.weapon.aimOffset = -1.0
  else
	self.weapon.aimOffset = 0.0
  end
  
  --Count down the cooldown timers
  self.transformCooldownTimer = math.max(0, self.transformCooldownTimer - self.dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  --Keep track of times in between button presses for the edge trigger time
  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= "primary" and fireMode == "primary" then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode
  
  --If not already in an ability, and we press alt fire, transform the weapon
  if not self.weapon.currentAbility
	and self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and self.transformCooldownTimer == 0
	and self.transformed == false then

	self:setState(self.transform)
  end
end

--=============================================================================================
--=================================== TRANSFORMATION ==========================================
--=============================================================================================
function TheaBowSpearTransform:transform()
  self.weapon:setStance(self.stances.transforming)
  self.weapon:updateAim()
	
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.setAnimationState("weapon", "transformToSpear")
  animator.playSound("transform")

  --util.wait(self.stances.transforming.duration)
  --Smoothly transition into the other form's stance
  local progress = 0
  util.wait(self.stances.transforming.duration, function()
    progress = math.min(self.stances.transforming.duration, progress + self.dt)
    local progressRatio = math.sin(progress / self.stances.transforming.duration * 1.57)
	world.debugText(progress, mcontroller.position(), "blue")
	world.debugText(progressRatio, vec2.add(mcontroller.position(), {0, 1}), "red")
	
	local from = self.stances.transforming.weaponOffset or {0,0}
    local to = self.stances.aiming.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progressRatio, from[1], to[1]), interp.linear(progressRatio, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(progressRatio, {self.stances.transforming.weaponRotation, self.stances.transforming.endWeaponRotation}))
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(progressRatio, {self.stances.transforming.armRotation, self.stances.transforming.endArmRotation}))
  end)
  
  self.transformed = true
  self.transformCooldownTimer = self.transformCooldownTime
  self:setState(self.aiming)
end

function TheaBowSpearTransform:revert()
  self.weapon:setStance(self.stances.reverting)
  self.weapon:updateAim()
	
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.setAnimationState("weapon", "transformToBow")
  animator.playSound("transform")

  util.wait(self.stances.reverting.duration)
  
  self.transformed = false
  self.transformCooldownTimer = self.transformCooldownTime
end

--=============================================================================================
--=================================== MELEE COMBOS ============================================
--=============================================================================================

--=========== AIMING/IDLE STATE ===========
function TheaBowSpearTransform:aiming()
  self.weapon:setStance(self.stances.aiming)
  
  --Loops this function to keep the weapon in its spear shape
  while self.transformed do
	self.weapon:updateAim()
	
	--Using primary fire now activates the melee combo
	if self:shouldActivate() then
	  self:setState(self.windup)
	end
	
	--Using alt fire again will revert the gun to sword mode
	if self.fireMode == "alt" and self.transformCooldownTimer == 0 then
	  self:setState(self.revert)
	end
	
	coroutine.yield()
  end
  
  --If we are no longer transformed for whatever reason, revert the weapon properly
  self:setState(self.revert)
end

--=========== WINDUP STATE ===========
function TheaBowSpearTransform:windup()  
  local stance = self.stances["windup"..self.comboStep]

  self.weapon:setStance(stance)

  self.edgeTriggerTimer = 0

  if stance.hold then
    while self.fireMode == "primary" do
      coroutine.yield()
    end
  else
    util.wait(stance.duration)
  end

  if self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

--=========== PRESLASH STATE ===========
--Brief frame in between windup and fire for smoother animations
function TheaBowSpearTransform:preslash()  
  local stance = self.stances["preslash"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)

  self:setState(self.fire)
end

--=========== FIRE/SWING STATE ===========
function TheaBowSpearTransform:fire()  
  local stance = self.stances["fire"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  util.wait(stance.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
  end)

  --If we haven't reached the end of the combo yet, go to wait state
  --If we HAVE reached the end of the combo, return to melee aiming state
  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
	self:setState(self.aiming)
  end
end

--=========== WAIT STATE ===========
--Wait for next combo input
function TheaBowSpearTransform:wait()  
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
  
  --Return to melee aiming state
  self:setState(self.aiming)
end

--=============================================================================================
--=================================== UTILITY =================================================
--=============================================================================================

--Computing damage values and cooldown times for every combo step
function TheaBowSpearTransform:computeDamageAndCooldowns()
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

--Check for input to determine if the next combo step should be initiated
function TheaBowSpearTransform:shouldActivate()
  if self.cooldownTimer == 0 then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == "primary"
    end
  end
end

--=============================================================================================
--=================================== RESET & UNINIT ==========================================
--=============================================================================================
function TheaBowSpearTransform:reset()
  animator.setAnimationState("weapon", "bow")
  self.transformed = false
end

function TheaBowSpearTransform:uninit()
  self:reset()
end
