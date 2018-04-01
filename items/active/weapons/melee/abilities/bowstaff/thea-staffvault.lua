require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/poly.lua"
require "/items/active/weapons/weapon.lua"

TheaStaffVault = WeaponAbility:new()

function TheaStaffVault:init()
  self.cooldownTimer = self.cooldownTime
  self.dashCooldownTimer = self.dashCooldownTime
  
  self.dashesLeft = config.getParameter("dashCount", self.maxDashes)
  self.airTime = 0
  self.spaceTime = 0
  self.stickCooldownTimer = 0
  
  self.queryDamageSince = 0
  
  self:reset()
end

function TheaStaffVault:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if mcontroller.onGround() then
	self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  end
  self.dashCooldownTimer = math.max(0, self.dashCooldownTimer - self.dt)
  self.stickCooldownTimer = math.max(0, self.stickCooldownTimer - self.dt)
  
  --Debug code for checking impact polys
  world.debugPoly(poly.translate(poly.handPosition(animator.partPoly("blade", "groundImpactPoly")), mcontroller.position()), "red")
  world.debugPoly(poly.translate(poly.handPosition(animator.partPoly("blade", "wallImpactPolySticking")), mcontroller.position()), "green")
  world.debugPoly(poly.translate(poly.handPosition(animator.partPoly("blade", "wallImpactPoly")), mcontroller.position()), "blue")
  world.debugText(self.dashesLeft, mcontroller.position(), "red")
  
  --Calculate our time spent in the air for potential aerial moves
  if mcontroller.onGround() then
	self.airTime = 0
  else
	self.airTime = math.min(5.0, self.airTime + self.dt)
  end
  
  --Reset dash count when hitting the ground or a liquid
  if mcontroller.onGround() or (self.restoreDashesOnSwim and mcontroller.liquidMovement()) then
	self.dashesLeft = self.maxDashes
	activeItem.setInstanceValue("dashCount", self.dashesLeft)
  end
  
  --Reset dash count if we spent enough time in zeroG
  if mcontroller.zeroG() then
	self.spaceTime = math.min(5.0, self.spaceTime + self.dt)
  else
	self.spaceTime = 0
  end
  if self.spaceTime > self.minSpaceTime and self.restoreDashesInSpace then
	self.dashesLeft = self.maxDashes
	activeItem.setInstanceValue("dashCount", self.dashesLeft)
  end
  
  --Set animation state of the dash counter
  if self.dashesLeft == 0 then
	animator.setAnimationState("dashCounter", "inactive")
  else
	animator.setAnimationState("dashCounter", "active")
  end
  
  --If grounded, go to vault windup
  if self.weapon.currentAbility == nil and self.fireMode == "alt" and mcontroller.onGround() and not status.resourceLocked("energy") and self.cooldownTimer == 0 then
    self:setState(self.windup)
  end
  
  --If so configured, restore dashes upon landing a hit on an enemy
  if self.restoreDashesOnHit then
	local damageNotifications, nextStep = status.inflictedDamageSince(self.queryDamageSince)
    self.queryDamageSince = nextStep
    for _, notification in ipairs(damageNotifications) do
      if notification.healthLost > 0 and notification.sourceEntityId ~= notification.targetEntityId then
		self.dashesLeft = self.maxDashes
		activeItem.setInstanceValue("dashCount", self.dashesLeft)
        break
      end
    end
  end
  
  --If in the air, perform a dash
  if self.weapon.currentAbility == nil and self.fireMode == "alt" and self.airTime > 0.15 and not status.resourceLocked("energy") and self.dashesLeft > 0 and self.dashCooldownTimer == 0 and status.overConsumeResource("energy", self.dashEnergy) then
    self:setState(self.dash)
  end
end

-- Windup for the vaulting move
function TheaStaffVault:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0

  animator.playSound("windupLoop", -1)
  
  --Smoothly rotate into the vaulting animation
  local progress = 0
  --Linear progression
  --util.wait(self.stances.windup.duration, function()
    --local from = self.stances.windup.weaponOffset or {0,0}
    --local to = self.stances.vault.weaponOffset or {0,0}
    --self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    --self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.windup.weaponRotation, self.stances.vault.weaponRotation))
    --self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.windup.armRotation, self.stances.vault.armRotation))

    --progress = math.min(1.0, progress + (self.dt / self.stances.windup.duration))
  --end)
  --Sine wave progression
  util.wait(self.stances.windup.duration, function()
    progress = math.min(self.stances.windup.duration, progress + self.dt)
    local progressRatio = math.sin(progress / self.stances.windup.duration * 1.57)
	world.debugText(progress, mcontroller.position(), "blue")
	world.debugText(progressRatio, vec2.add(mcontroller.position(), {0, 1}), "red")
	
	local from = self.stances.windup.weaponOffset or {0,0}
    local to = self.stances.prevault.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progressRatio, from[1], to[1]), interp.linear(progressRatio, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(progressRatio, {self.stances.windup.weaponRotation, self.stances.vault.weaponRotation}))
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(progressRatio, {self.stances.windup.armRotation, self.stances.vault.armRotation}))
  end)

  animator.stopAllSounds("windupLoop")
  
  self:setState(self.prevault)
end

-- Brief frame before vaulting
function TheaStaffVault:prevault()
  self.weapon:setStance(self.stances.prevault)
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0

  util.wait(self.stances.prevault.duration)

  local groundImpact = world.polyCollision(poly.translate(poly.handPosition(animator.partPoly("blade", "groundImpactPoly")), mcontroller.position()))
  if groundImpact or mcontroller.onGround() then
	if status.overConsumeResource("energy", self.vaultEnergy) then
	  self:setState(self.vault)
	end
  end
end

-- Vaulting move
function TheaStaffVault:vault()
  self.weapon:setStance(self.stances.vault)
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.setParticleEmitterActive("dash", true)
  animator.burstParticleEmitter("vaultBurst")

  animator.setAnimationState("thruster", "active")
  
  util.wait(self.stances.vault.duration, function()
    mcontroller.setYVelocity(self.vaultingVelocity)
  end)
  
  self.cooldownTimer = self.cooldownTime
  self.dashCooldownTimer = self.dashCooldownTime
  
  animator.setParticleEmitterActive("dash", false)
end

--Dashing move
function TheaStaffVault:dash()
  self.weapon:setStance(self.stances.dash)
  self.weapon:updateAim()

  animator.setParticleEmitterActive("dash", true)
  animator.burstParticleEmitter("dashBurst")

  animator.setAnimationState("thruster", "active")
  
  self.dashesLeft = self.dashesLeft - 1
  activeItem.setInstanceValue("dashCount", self.dashesLeft)
  
  util.wait(self.stances.dash.duration, function(dt)
	--Determine in what direction we should charge
    local aimDirection = {mcontroller.facingDirection() * math.cos(self.weapon.aimAngle), math.sin(self.weapon.aimAngle)}
	--Set our velocity
    mcontroller.setVelocity(vec2.mul(vec2.norm(aimDirection), self.dashVelocity))
	--Disable gravity and friction for the duration of the charge
    mcontroller.controlParameters({
      airFriction = 0,
      groundFriction = 0,
      liquidFriction = 0,
      gravityEnabled = false
    })
	
	self.dashCooldownTimer = self.dashCooldownTime
	
	local wallImpact = world.polyCollision(poly.translate(poly.handPosition(animator.partPoly("blade", "wallImpactPoly")), mcontroller.position()))
	if wallImpact and self.fireMode == "alt" and self.stickCooldownTimer == 0 then
	  animator.setParticleEmitterActive("dash", false)
	  animator.setAnimationState("thruster", "inactive")
  
	  self:setState(self.stick)
	end
  end)
  
  local stopVelocity = vec2.mul(mcontroller.velocity(), self.retainVelocityFactor)
  mcontroller.setVelocity(stopVelocity)
  
  animator.setParticleEmitterActive("dash", false)
end

--Sticking to the wall from a dash
function TheaStaffVault:stick()
  self.weapon:setStance(self.stances.stick)
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.playSound("stick")

  local stickPosition = mcontroller.position()
  local canStick = true
  local minimumStickTimer = 0.1 --Prevents the stick from disabling immediately if a wall was hit at an angle, and there was no wallImpact because the weapon was rotating
  
  while self.fireMode == "alt" and canStick do
	mcontroller.setVelocity({0,0})
	mcontroller.setPosition(stickPosition)
	
	self.stickCooldownTimer = self.stickCooldownTime
	
	minimumStickTimer = math.max(0, minimumStickTimer - self.dt)
	
	local wallImpact = world.polyCollision(poly.translate(poly.handPosition(animator.partPoly("blade", "wallImpactPolySticking")), mcontroller.position()))
	if not wallImpact and minimumStickTimer == 0 then
	  canStick = false
	end
	coroutine.yield()
  end
end

--Reset and uninit functions
function TheaStaffVault:reset()
  animator.setAnimationState("thruster", "inactive")
  animator.stopAllSounds("windupLoop")
  animator.setParticleEmitterActive("dash", false)
end

function TheaStaffVault:uninit()
  self:reset()
end
