require "/scripts/util.lua"
require "/scripts/interp.lua"

--This ability uses both the primary and secondary ability slots - if combined with a separate alternate ability, the weapon WILL malfunction. Additionally, weapons with this ability are required to be two-handed, as both mouse buttons are required for the reloading mechanic. Primary fire fires the weapon like any regular gun, but consumes one unit of ammo, whilst secondary fire reloads the weapon. Running out of ammo will automatically start the reload sequence. Optionally, weapons with this ability can be configured to 'cycle' after each shot, playing a special animation after firing, or can be configured to play a firing animation after each shot.

-- Base gun fire ability
TheaAmmoFire = WeaponAbility:new()

function TheaAmmoFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
	animator.stopAllSounds("reloadLoop")
  end
  
  self.currentAmmo = config.getParameter("ammoCount", self.maxAmmo)
  
  animator.setAnimationState("gun", "readyState1")
end

function TheaAmmoFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
	and self.currentAmmo > 0 then

    if self.fireType == "auto" then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end
  
  --Reload automatically if clip is empty
  if self.currentAmmo == 0 and not self.weapon.currentAbility then
	if self.stances.preReloadTwirl then
	  self:setState(self.preReloadTwirl)
	else
	  self:setState(self.reload)
	end
  end
  
  --Manual reload
  if self.fireMode == "alt" and self.currentAmmo ~= self.maxAmmo and not self.weapon.currentAbility then
	if self.stances.preReloadTwirl then
	  self:setState(self.preReloadTwirl)
	else
	  self:setState(self.reload)
	end
  end
end

function TheaAmmoFire:auto()
  self.weapon:setStance(self.stances.fire)

  self:fireProjectile()
  self:muzzleFlash()
  
  --Remove ammo from the magazine, and cycle the weapon if needed
  self.currentAmmo = self.currentAmmo - 1
  activeItem.setInstanceValue("ammoCount", self.currentAmmo)
  
  --Optional firing animations
  if self.cycleAfterShot == true then
	if animator.animationState("gun") == "readyState1" then
	  animator.setAnimationState("gun", "startCycle1")
	elseif animator.animationState("gun") == "readyState2" then
	  animator.setAnimationState("gun", "startCycle2")
	end
  elseif self.fireAnimation == true then
	animator.setAnimationState("gun", "fire")
  end

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function TheaAmmoFire:burst()
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 do
    self:fireProjectile()
    self:muzzleFlash()
    shots = shots - 1

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end
  
  --Remove ammo from the magazine, and cycle the weapon if needed
  self.currentAmmo = self.currentAmmo - 1
  activeItem.setInstanceValue("ammoCount", self.currentAmmo)
  
  --Optional firing animations
  if self.cycleAfterShot == true then
	if animator.animationState("gun") == "readyState1" then
	  animator.setAnimationState("gun", "startCycle1")
	elseif animator.animationState("gun") == "readyState2" then
	  animator.setAnimationState("gun", "startCycle2")
	end
  elseif self.fireAnimation == true then
	animator.setAnimationState("gun", "fire")
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
end

function TheaAmmoFire:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

function TheaAmmoFire:preReloadTwirl()
  self.weapon:setStance(self.stances.preReloadTwirl)
  self.weapon:updateAim()

  animator.playSound("preReloadTwirl")
  
  local progress = 0
  util.wait(self.stances.preReloadTwirl.duration, function()

	self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.preReloadTwirl.weaponRotation, self.stances.preReloadTwirl.endWeaponRotation))
	self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.preReloadTwirl.armRotation, self.stances.preReloadTwirl.endArmRotation))

	progress = math.min(1.0, progress + (self.dt / self.stances.preReloadTwirl.duration))
  end)
  
  self:setState(self.reload)
end

function TheaAmmoFire:reload()
  self.weapon:setStance(self.stances.reload)
  self.weapon:updateAim()

  --Start the reload animation, sound and effects
  animator.setAnimationState("gun", "reload")
  animator.playSound("reloadLoop", -1)
  animator.burstParticleEmitter("reload")
  
  local timer = 0
  util.wait(self.stances.reload.duration, function()
	--FRONT ARM
	local frontArm = self.stances.reload.frontArmFrame or "rotation"
	if self.stances.reload.frontArmFrameSequence then
	  --Run through each sequence step and update arm frame accordingly
	  for i,step in ipairs(self.stances.reload.frontArmFrameSequence) do
		if timer > step[1] then
		  frontArm = step[2]
		end
	  end
	  self.stances.reload.frontArmFrame = frontArm
	  self.weapon:updateAim()
	end
	
	--BACK ARM
	local backArm = self.stances.reload.backArmFrame or "rotation"
	if self.stances.reload.backArmFrameSequence then
	  --Run through each sequence step and update arm frame accordingly
	  for i,step in ipairs(self.stances.reload.backArmFrameSequence) do
		if timer > step[1] then
		  backArm = step[2]
		end
	  end
	  self.stances.reload.backArmFrame = backArm
	  self.weapon:updateAim()
	end

	timer = timer + self.dt
  end)
  
  --Finish the reload animation, sound and effects, and update ammo values
  animator.playSound("reload")
  animator.stopAllSounds("reloadLoop")
  self.currentAmmo = self.maxAmmo
  activeItem.setInstanceValue("ammoCount", self.maxAmmo)
  
  if self.stances.reloadTwirl then
	self:setState(self.reloadTwirl)
  elseif self.readyTime then
	self.cooldownTimer = self.readyTime
  end
end

function TheaAmmoFire:reloadTwirl()
  self.weapon:setStance(self.stances.reloadTwirl)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.reloadTwirl.duration, function()

	self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.reloadTwirl.weaponRotation, self.stances.reloadTwirl.endWeaponRotation))
	self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.reloadTwirl.armRotation, self.stances.reloadTwirl.endArmRotation))

	progress = math.min(1.0, progress + (self.dt / self.stances.reloadTwirl.duration))
  end)
  
  if self.readyTime then
	self.cooldownTimer = self.readyTime
  end
end

function TheaAmmoFire:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function TheaAmmoFire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function TheaAmmoFire:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function TheaAmmoFire:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function TheaAmmoFire:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function TheaAmmoFire:uninit()
  activeItem.setInstanceValue("ammoCount", self.currentAmmo)
end