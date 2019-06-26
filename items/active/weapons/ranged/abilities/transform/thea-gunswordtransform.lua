require "/items/active/weapons/weapon.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

TheaGunSwordTransform = WeaponAbility:new()

function TheaGunSwordTransform:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime
  self.comboStep = 1
  self.edgeTriggerTimer = 0
  self.flashTimer = 0
  self.animKeyPrefix = self.animKeyPrefix or ""
  
  self.reloaded = false --Used to share data with primary ability

  self:computeDamageAndCooldowns()
  self:reset()

  self.cooldownTimer = self.cooldowns[1]
  
  self.transformCooldownTimer = self.transformCooldownTime
end

function TheaGunSwordTransform:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  --Adjust the weapon's aimOffset value to correct the aim for hammer and gun modes
  if self.transformed then
	self.weapon.aimOffset = -1.0
  else
	self.weapon.aimOffset = 0.0
  end
  
  --Optionally allow the weapon to flash when the combo cooldown is done
  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
      animator.setGlobalTag("bladeDirectives", self.flashDirectives)
	  self.flashTimer = self.flashTime
    end
  end
  
  --Combo edge trigger behaviour
  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= "primary" and fireMode == "primary" then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode
  
  --Count down the cooldown timers
  self.transformCooldownTimer = math.max(0, self.transformCooldownTimer - self.dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  --Reset the flash directive
  animator.setGlobalTag("bladeDirectives", "")
  
  world.debugText(self.edgeTriggerTimer, vec2.add(mcontroller.position(), {0,2}), "yellow")
  world.debugText(sb.print(self.comboStep), vec2.add(mcontroller.position(), {0,3}), "yellow")
  
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
function TheaGunSwordTransform:transform()
  self.weapon:setStance(self.stances.transforming)
  self.weapon:updateAim()
	
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.setAnimationState("gun", "transformToSword")
  animator.playSound("transform")
  
  if self.reloadOnTransform then
	animator.burstParticleEmitter("reload")
	animator.playSound("reloadLoop", -1)
  end
  
  --Smoothly transition into the other form's stance
  local progress = 0
  util.wait(self.stances.transforming.duration, function()
    progress = math.min(self.stances.transforming.duration, progress + self.dt)
    local progressRatio = math.sin(progress / self.stances.transforming.duration * 1.57)
	
	local from = self.stances.transforming.weaponOffset or {0,0}
    local to = self.stances.transforming.endWeaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progressRatio, from[1], to[1]), interp.linear(progressRatio, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(progressRatio, {self.stances.transforming.weaponRotation, self.stances.transforming.endWeaponRotation}))
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(progressRatio, {self.stances.transforming.armRotation, self.stances.transforming.endArmRotation}))
  end)
  
  --Optionally reload the weapon
  if self.reloadOnTransform then
	self.primaryAbility = getPrimaryAbility()
	
	animator.playSound("reload")
	animator.stopAllSounds("reloadLoop")
	self.reloaded = true
  end
  
  self.transformed = true
  self.transformCooldownTimer = self.transformCooldownTime
  self:setState(self.aiming)
end

function TheaGunSwordTransform:revert()
  self.weapon:setStance(self.stances.reverting)
  self.weapon:updateAim()
	
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.setAnimationState("gun", "transformToGun")
  animator.playSound("transform")

  --Smoothly transition into the other form's stance
  local progress = 0
  util.wait(self.stances.reverting.duration, function()
    progress = math.min(self.stances.reverting.duration, progress + self.dt)
    local progressRatio = math.sin(progress / self.stances.reverting.duration * 1.57)
	
	local from = self.stances.reverting.weaponOffset or {0,0}
    local to = self.stances.reverting.endWeaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progressRatio, from[1], to[1]), interp.linear(progressRatio, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(progressRatio, {self.stances.reverting.weaponRotation, self.stances.reverting.endWeaponRotation}))
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(progressRatio, {self.stances.reverting.armRotation, self.stances.reverting.endArmRotation}))
  end)
  
  self.transformed = false
  self.transformCooldownTimer = self.transformCooldownTime
end

--=============================================================================================
--=================================== MELEE COMBOS ============================================
--=============================================================================================

--=========== AIMING/IDLE STATE ===========
function TheaGunSwordTransform:aiming()
  self.weapon:setStance(self.stances.aiming)
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  --Loops this function to keep the weapon in its spear shape
  while self.transformed do
	self.weapon:updateAim()
	
	--Using primary fire now activates the melee combo
	if self.fireMode == "primary" and self.cooldownTimer == 0 then
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
function TheaGunSwordTransform:windup()
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

--=========== PRESLASH STATE ===========
--Brief time period to wait for next input after a combo slash
function TheaGunSwordTransform:wait()
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
  
  --Return to aim state to prevent transforming back automatically
  self:setState(self.aiming)
end

--=========== PRESLASH STATE ===========
--Brief frame in between windup and fire for smoother animations
function TheaGunSwordTransform:preslash()
  local stance = self.stances["preslash"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)

  self:setState(self.fire)
end

--=========== FIRE/SWING STATE ===========
function TheaGunSwordTransform:fire()
  local stance = self.stances["swing"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "swing"..self.comboStep or "swing")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)

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
	self:setState(self.aiming)
  end
end

--=============================================================================================
--=================================== UTILITY =================================================
--=============================================================================================

--Utility function for determining if a button input should trigger the next combo step while waiting for input
function TheaGunSwordTransform:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == "primary"
    end
  end
end

--Utility function for calculating cooldown time in between attacks
function TheaGunSwordTransform:computeDamageAndCooldowns()
  local attackTimes = {}
  for i = 1, self.comboSteps do
    local attackTime = self.stances["windup"..i].duration + self.stances["swing"..i].duration
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

--=============================================================================================
--=================================== RESET & UNINIT ==========================================
--=============================================================================================
function TheaGunSwordTransform:reset()
  animator.setGlobalTag("bladeDirectives", "")
  if self.reloadOnTransform then
	animator.stopAllSounds("reloadLoop")
  end
  self.transformed = false
  self.weapon:setDamage()
end

function TheaGunSwordTransform:uninit()
  self:reset()
end
