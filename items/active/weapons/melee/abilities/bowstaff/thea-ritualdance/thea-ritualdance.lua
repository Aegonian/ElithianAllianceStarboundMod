require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/scripts/poly.lua"
require "/items/active/weapons/weapon.lua"
require "/scripts/rails.lua"

TheaRitualDance = WeaponAbility:new()

function TheaRitualDance:init()
  self.cooldownTimer = self.cooldownTime
  self.hookCooldownTimer = self.hookCooldownTime or 1.0
  self.danceLevel = 1
  
  self.currentParticleEmitter = nil
  
  --Rail hook init
  self.railRider = Rails.createRider(self.railConfig)
  self.railRider:init()

  self.onRail = false
  self.volumeAdjustTimer = 0.0
  self.volumeAdjustTime = 0.1

  self.effectGroupName = "railhook" .. activeItem.hand()
  
  self:reset()
end

function TheaRitualDance:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.hookCooldownTimer = math.max(0, self.hookCooldownTimer - self.dt)
  
  world.debugText(self.danceLevel, vec2.add(mcontroller.position(), {0, 2}), "yellow")
  
  --If grounded, go to dance start
  if self.weapon.currentAbility == nil and self.fireMode == "alt" and mcontroller.onGround() and not status.resourceLocked("energy") and self.cooldownTimer == 0 then
    self:setState(self.danceStart)
  --If in the air, attempt to latch onto rails
  elseif self.weapon.currentAbility == nil and self.fireMode == "alt" and not mcontroller.onGround() and self.allowRailHook and self.hookCooldownTimer == 0 then
	self:setState(self.railHook)
  end
end

-- Dance move start
function TheaRitualDance:danceStart()
  local stance = self.stances["danceStart"..self.danceLevel]
  self.weapon:setStance(stance)
  
  if self.currentParticleEmitter then
	animator.setParticleEmitterActive(self.currentParticleEmitter, false)
  end
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  if stance.shake then
	animator.playSound("shakeLoop", -1)
  end
  if stance.emote then
	activeItem.emote(stance.emote)
  end
  
  local timer = 0
  util.wait(stance.duration, function()
	mcontroller.controlModifiers({runningSuppressed=true})
	
	if stance.particleEmitter then
	  animator.setParticleEmitterActive(stance.particleEmitter, true)
	  self.currentParticleEmitter = stance.particleEmitter
	end
	
	if stance.shake then
	  local wavePeriod = (stance.shakeWavePeriod or 0.125) / (2 * math.pi)
	  local waveAmplitude = stance.shakeWaveAmplitude or 0.075
	  local rotation = waveAmplitude * math.sin(timer / wavePeriod)
	
	  self.weapon.relativeWeaponRotation = rotation + util.toRadians(stance.weaponRotation) --Add weaponRotation again, as relativeWeaponRotation overwrites it
	  self.weapon.relativeArmRotation = rotation + util.toRadians(stance.armRotation) --Add armRotation again, as armWeaponRotation overwrites it
	  
	  animator.setAnimationState("weapon", "shakeLoop")
	end
	
	timer = timer + self.dt
	--world.debugText("STARTING DANCE", mcontroller.position(), "green")
	--world.debugText(timer, vec2.add(mcontroller.position(), {0, -1}), "green")
  end)
  
  animator.stopAllSounds("shakeLoop")
  animator.setAnimationState("weapon", "idle")
  
  if self.fireMode == "alt" or self.danceLevel > 1 then
	self:setState(self.danceEnd)
  else
	self:reset()
  end
end

-- Dance move end
function TheaRitualDance:danceEnd()
  local stance = self.stances["danceEnd"..self.danceLevel]
  self.weapon:setStance(stance)
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  if stance.shake then
	animator.playSound("shakeLoop", -1)
  end
  if stance.emote then
	activeItem.emote(stance.emote)
  end
  
  local timer = 0
  util.wait(stance.duration, function()
	mcontroller.controlModifiers({runningSuppressed=true})
	
	if stance.particleEmitter then
	  animator.setParticleEmitterActive(stance.particleEmitter, true)
	  self.currentParticleEmitter = stance.particleEmitter
	end
	
	if stance.shake then
	  local wavePeriod = (stance.shakeWavePeriod or 0.125) / (2 * math.pi)
	  local waveAmplitude = stance.shakeWaveAmplitude or 0.075
	  local rotation = waveAmplitude * math.sin(timer / wavePeriod)
	
	  self.weapon.relativeWeaponRotation = rotation + util.toRadians(stance.weaponRotation) --Add weaponRotation again, as relativeWeaponRotation overwrites it
	  self.weapon.relativeArmRotation = rotation + util.toRadians(stance.armRotation) --Add armRotation again, as armWeaponRotation overwrites it
	  
	  animator.setAnimationState("weapon", "shakeLoop")
	end
	
	timer = timer + self.dt
	--world.debugText("ENDING DANCE", mcontroller.position(), "red")
	--world.debugText(timer, vec2.add(mcontroller.position(), {0, -1}), "red")
  end)
  
  animator.stopAllSounds("shakeLoop")
  animator.setAnimationState("weapon", "idle")
  
  if self.fireMode == "alt" and self.danceLevel < self.danceLevels then
	self.danceLevel = self.danceLevel + 1
	self:setState(self.danceStart)
  else
	self:releaseWindup()
  end
end

-- Release clouds based on the dance level we achieved
function TheaRitualDance:releaseWindup()
  self.weapon:setStance(self.stances.releaseWindup)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.playSound("windupLoop", -1)
  if self.stances.releaseWindup.emote then
	activeItem.emote(self.stances.releaseWindup.emote)
  end
  
  --Smoothly rotate into the vaulting animation
  local progress = 0
  util.wait(self.stances.releaseWindup.duration, function()
    mcontroller.controlModifiers({runningSuppressed=true})
	
	progress = math.min(self.stances.releaseWindup.duration, progress + self.dt)
    local progressRatio = math.sin(progress / self.stances.releaseWindup.duration * 1.57)
	
	local from = self.stances.releaseWindup.weaponOffset or {0,0}
    local to = self.stances.releaseWindup.endWeaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progressRatio, from[1], to[1]), interp.linear(progressRatio, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(progressRatio, {self.stances.releaseWindup.weaponRotation, self.stances.releaseWindup.endWeaponRotation}))
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(progressRatio, {self.stances.releaseWindup.armRotation, self.stances.releaseWindup.endArmRotation}))
	
	--world.debugText("RELEASE WINDUP", mcontroller.position(), "blue")
  end)
  
  animator.stopAllSounds("windupLoop")
  
  self:setState(self.releaseClouds)
end

-- Release clouds based on the dance level we achieved
function TheaRitualDance:releaseClouds()
  self.weapon:setStance(self.stances.release)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.playSound("release")
  animator.playSound("shakeLoop", -1)
  animator.setAnimationState("weapon", "releaseClouds")
  if self.stances.release.emote then
	activeItem.emote(self.stances.release.emote)
  end
  
  --Set up for projectile spawning
  local firePosition = vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint("blade", "projectileFirePoint") or {0,0}))
  local params = self.projectileParameters or {}
  params.power = self.projectileDamage * config.getParameter("damageLevelMultiplier")
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)
	
  world.debugPoint(firePosition, "red")

  if not world.lineTileCollision(mcontroller.position(), firePosition) then
	for i = 1, (self.projectileCount or 1) do
	  local aimVector = vec2.rotate({1, 0}, -self.weapon.relativeWeaponRotation + sb.nrand(self.projectileInaccuracy or 0, 0) + (self.projectileAimAngleOffset or 0))
	  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
		
	  world.spawnProjectile(
		self.danceProjectiles[self.danceLevel],
		firePosition,
		nil,
		aimVector,
		false,
		params
	  )
	end
  end
  
  local timer = 0
  util.wait(self.stances.release.duration, function()
    mcontroller.controlModifiers({movementSuppressed=true})
	
	local wavePeriod = (self.stances.release.shakeWavePeriod or 0.125) / (2 * math.pi)
	local waveAmplitude = self.stances.release.shakeWaveAmplitude or 0.075
	local rotation = waveAmplitude * math.sin(timer / wavePeriod)
	
	self.weapon.relativeWeaponRotation = rotation + util.toRadians(self.stances.release.weaponRotation) --Add weaponRotation again, as relativeWeaponRotation overwrites it
	self.weapon.relativeArmRotation = rotation + util.toRadians(self.stances.release.armRotation) --Add armRotation again, as armWeaponRotation overwrites it
	
	timer = timer + self.dt
	
	--world.debugText("RELEASING", mcontroller.position(), "blue")
  end)
  
  animator.stopAllSounds("shakeLoop")
end

--Rail hook functions
function TheaRitualDance:railHook()
  self.weapon:setStance(self.stances.railHook)
  self.weapon:updateAim()
  
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  if not self.railRider:onRail() then
	self:engageHook()
  end
  
  while self.fireMode == "alt" and not mcontroller.isColliding() do
	self.railRider:updateConnectionOffset(self.connectionOffset)
	self.railRider:update(self.dt)
	
	world.debugPoint(vec2.add(mcontroller.position(), self.connectionOffset), "yellow")
	
	if self.railRider:onRail() then
	  --world.debugText("On Rail", vec2.add(mcontroller.position(), {0,-1}), "green")
	  mcontroller.controlModifiers(
		{jumpingSuppressed = true, movementSuppressed = true}
	  )
	  mcontroller.controlParameters(
		{airForce = 0}
	  )	  
	  status.setPersistentEffects(self.effectGroupName, {{stat = "activeMovementAbilities", amount = 1}})
	else
	  --world.debugText("Off Rail", vec2.add(mcontroller.position(), {0,-1}), "red")
	  status.clearPersistentEffects(self.effectGroupName)
	end
	
	--Overwrite the friction amount of the rail type we are currently attached to
	if self.railRider.onRailType then
	  self.railRider.railTypes[self.railRider.onRailType].friction = self.railFriction
	  --world.debugText(sb.printJson(self.railRider.onRailType), mcontroller.position(), "red")
	  --world.debugText(sb.printJson(self.railRider.railTypes[self.railRider.onRailType].friction), vec2.add(mcontroller.position(), {0,-1}), "red")
	end
	
	--Animation and sounds for the rail hook
	local onRail = self.railRider:onRail() and self.railRider.moving and self.railRider.speed > 0.01
	if onRail then
	  animator.setParticleEmitterActive("sparks", true)
	  animator.setParticleEmitterEmissionRate("sparks", math.floor(self.railRider.speed) * 2)

	  local volumeAdjustment = math.max(0.5, math.min(1.0, self.railRider.speed / 20))

	  if not self.onRail then
		self.onRail = true
		animator.playSound("grind", -1)
		animator.setSoundVolume("grind", volumeAdjustment, 0)
	  end

	  self.volumeAdjustTimer = math.max(0, self.volumeAdjustTimer - self.dt)
	  if self.volumeAdjustTimer == 0 then
		animator.setSoundVolume("grind", volumeAdjustment, self.volumeAdjustTime)
		self.volumeAdjustTimer = self.volumeAdjustTime
	  end
	else
	  animator.setParticleEmitterActive("sparks", false)

	  self.onRail = false
	  self.volumeAdjustTimer = self.volumeAdjustTime
	  animator.stopAllSounds("grind")
	end
	
	coroutine.yield()
  end
  
  self:disengageHook()
end

function TheaRitualDance:engageHook()
  self.railRider:reset()
  self.railRider.connectionOffset = self.connectionOffset
end

function TheaRitualDance:disengageHook()
  self.onRail = false
  self.hookCooldownTimer = self.hookCooldownTime or 1.0
  animator.setParticleEmitterActive("sparks", false)
  animator.stopAllSounds("grind")
  self.railRider:reset()
end

--Reset and uninit functions
function TheaRitualDance:reset()
  animator.stopAllSounds("shakeLoop")
  animator.stopAllSounds("windupLoop")
  animator.setAnimationState("weapon", "idle")
  self.cooldownTimer = self.cooldownTime
  self.danceLevel = 1
  if self.currentParticleEmitter then
	animator.setParticleEmitterActive(self.currentParticleEmitter, false)
  end
  animator.setParticleEmitterActive("sparks", false)
end

function TheaRitualDance:uninit()
  self:reset()
  status.clearPersistentEffects(self.effectGroupName)
end
