require "/items/active/weapons/weapon.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/poly.lua"
require "/scripts/interp.lua"

TheaGunHammerTransform = WeaponAbility:new()

function TheaGunHammerTransform:init()
  self.damageConfig.baseDamage = self.baseDps * self.fireTime

  self:reset()

  self.cooldownTimer = self:cooldownTime()
  
  self.transformCooldownTimer = self.transformCooldownTime
end

function TheaGunHammerTransform:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  --Adjust the weapon's aimOffset value to correct the aim for hammer and gun modes
  if self.transformed then
	self.weapon.aimOffset = -1.0
  else
	self.weapon.aimOffset = 0.0
  end
  
  --Count down the cooldown timers
  self.transformCooldownTimer = math.max(0, self.transformCooldownTimer - self.dt)
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  --Reset the flash directive
  animator.setGlobalTag("bladeDirectives", "")
  
  --Show the ground impact poly in debug mode
  world.debugPoly(poly.translate(poly.handPosition(animator.partPoly("middle", "groundImpactPoly")), mcontroller.position()), "red")
  
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
function TheaGunHammerTransform:transform()
  self.weapon:setStance(self.stances.transforming)
  self.weapon:updateAim()
	
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.setAnimationState("weapon", "transformToHammer")
  animator.playSound("transform")

  --Smoothly transition into the other form's stance
  local progress = 0
  util.wait(self.stances.transforming.duration, function()
    progress = math.min(self.stances.transforming.duration, progress + self.dt)
    local progressRatio = math.sin(progress / self.stances.transforming.duration * 1.57)
	
	local from = self.stances.transforming.weaponOffset or {0,0}
    local to = self.stances.aiming.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progressRatio, from[1], to[1]), interp.linear(progressRatio, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(progressRatio, {self.stances.transforming.weaponRotation, self.stances.aiming.weaponRotation}))
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(progressRatio, {self.stances.transforming.armRotation, self.stances.aiming.armRotation}))
  end)
  
  self.transformed = true
  self.transformCooldownTimer = self.transformCooldownTime
  self:setState(self.aiming)
end

function TheaGunHammerTransform:revert()
  self.weapon:setStance(self.stances.reverting)
  self.weapon:updateAim()
	
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.setAnimationState("weapon", "transformToGun")
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
function TheaGunHammerTransform:aiming()
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
function TheaGunHammerTransform:windup(windupProgress)
  self.weapon:setStance(self.stances.windup)

  local windupProgress = windupProgress or 0
  local flashTime = self.flashTime
  while self.fireMode == "primary" and (self.allowHold ~= false or windupProgress < 1) do
    --Calculate relative arm and weapon angles based on charge progress
	local progressRatio = math.sin(windupProgress / self.stances.windup.duration * 1.57)
	if windupProgress < 1 then
	  windupProgress = math.min(1, windupProgress + (self.dt / self.stances.windup.duration))
	  
	  self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(progressRatio, {self.stances.windup.weaponRotation, self.stances.windup.endWeaponRotation}))
	  self.weapon.relativeArmRotation = util.toRadians(util.lerp(progressRatio, {self.stances.windup.armRotation, self.stances.windup.endArmRotation}))
    elseif flashTime > 0 then
      animator.setGlobalTag("bladeDirectives", self.flashDirectives)
	  flashTime = math.max(0, flashTime - self.dt)
    end
	
	--If the weapon has configured aim angle modifiers, multiply the player's aim angle by these modifiers
	if self.maxAimAngleModifier and self.minAimAngleModifier then
	  local aimAngle, aimDirection = activeItem.aimAngleAndDirection(self.weapon.aimOffset, activeItem.ownerAimPosition())
	  if aimAngle > 0 then
		self.weapon.aimAngle = (aimAngle * self.maxAimAngleModifier * progressRatio) --Multiply by modifier and progressRatio for smooth transitions!
	  else
		self.weapon.aimAngle = (aimAngle * self.minAimAngleModifier * progressRatio) --Multiply by modifier and progressRatio for smooth transitions!
	  end
	end
	
    coroutine.yield()
  end

  --If the charge was completed, go to fire or preslash
  if windupProgress >= 1.0 then
    if self.stances.preslash then
      self:setState(self.preslash)
    else
      self:setState(self.fire)
    end
  --If the charge was incomplete, go to winddown but save our progress
  else
    self:setState(self.winddown, windupProgress)
  end
end

--=========== WINDDOWN STATE ===========
function TheaGunHammerTransform:winddown(windupProgress)
  self.weapon:setStance(self.stances.windup)

  while windupProgress > 0 do
    --If primary fire is resumed while charging, go back to windup and save our progress
	if self.fireMode == "primary" then
      self:setState(self.windup, windupProgress)
      return true
    end

	--Calculate relative arm and weapon angles based on charge progress
    windupProgress = math.max(0, windupProgress - (self.dt / self.stances.windup.duration))
	local progressRatio = math.sin(windupProgress / self.stances.windup.duration * 1.57)
	  
	self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(progressRatio, {self.stances.windup.weaponRotation, self.stances.windup.endWeaponRotation}))
	self.weapon.relativeArmRotation = util.toRadians(util.lerp(progressRatio, {self.stances.windup.armRotation, self.stances.windup.endArmRotation}))
	
	--If the weapon has configured aim angle modifiers, multiply the player's aim angle by these modifiers
	if self.maxAimAngleModifier and self.minAimAngleModifier then
	  local aimAngle, aimDirection = activeItem.aimAngleAndDirection(self.weapon.aimOffset, activeItem.ownerAimPosition())
	  if aimAngle > 0 then
		self.weapon.aimAngle = (aimAngle * self.maxAimAngleModifier * progressRatio) --Multiply by modifier and progressRatio for smooth transitions!
	  else
		self.weapon.aimAngle = (aimAngle * self.minAimAngleModifier * progressRatio) --Multiply by modifier and progressRatio for smooth transitions!
	  end
	end
	
    coroutine.yield()
  end
  
  --Return to aim state to prevent transforming back automatically
  self:setState(self.aiming)
end

--=========== PRESLASH STATE ===========
--Brief frame in between windup and fire for smoother animations
function TheaGunHammerTransform:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()
  
  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

--=========== FIRE/SWING STATE ===========
function TheaGunHammerTransform:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("swoosh", "fire")
  animator.playSound("swing")
  animator.burstParticleEmitter("swoosh")
  
  if world.polyCollision(poly.translate(poly.handPosition(animator.partPoly("middle", "groundImpactPoly")), mcontroller.position())) then
	animator.playSound("groundImpact")
  end

  util.wait(self.stances.fire.duration, function()
      --local damageArea = partDamageArea("swoosh")
      local damageArea = partDamageArea("swoosh")
      self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)
    end)

  self.cooldownTimer = self:cooldownTime()
  
  --Return to aim state to prevent transforming back automatically
  self:setState(self.aiming)
end

--=============================================================================================
--=================================== UTILITY =================================================
--=============================================================================================

--Utility function for calculating cooldown time in between attacks
function TheaGunHammerTransform:cooldownTime()
  return self.fireTime - self.stances.windup.duration - self.stances.fire.duration
end

--=============================================================================================
--=================================== RESET & UNINIT ==========================================
--=============================================================================================
function TheaGunHammerTransform:reset()
  animator.setGlobalTag("bladeDirectives", "")
  animator.setAnimationState("weapon", "idle")
  self.transformed = false
  self.weapon:setDamage()
end

function TheaGunHammerTransform:uninit()
  self:reset()
end
