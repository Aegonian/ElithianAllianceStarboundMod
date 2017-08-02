require "/items/active/weapons/weapon.lua"
require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"

TheaLegionGun = WeaponAbility:new()

function TheaLegionGun:init()
  self.fireTimer = self.fireTime
  self.cooldownTimer = self.cooldownTime
  
  self.transformed = false
  
  self:reset()
end

function TheaLegionGun:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  if animator.animationState("muzzleflash") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end
  
  if not self.weapon.currentAbility
	and self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not status.resourceLocked("energy")
    and self.cooldownTimer == 0
	and self.transformed == false then

	self:setState(self.transform)
  end
end

function TheaLegionGun:transform()
  self.weapon:setStance(self.stances.transforming)
  self.weapon:updateAim()
	
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.setAnimationState("weapon", "transformToGun")
  animator.playSound("transform")

  util.wait(self.stances.transforming.duration)
  
  self.transformed = true
  self.cooldownTimer = self.cooldownTime
  self:setState(self.aiming)
end

function TheaLegionGun:aiming()
  self.weapon:setStance(self.stances.aiming)

  local params = copy(self.projectileParameters)
  params.power = self.baseDps * self.fireTime * config.getParameter("damageLevelMultiplier")
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  
  --Loops this function while firing and/or the revert timer is still counting down, to keep the weapon in its gun shape
  while not status.resourceLocked("energy") do
	self.weapon:updateAim()
	
	--TEMP DEBUG CODE
	world.debugPoint(self:firePosition(), "red")
	
	self.fireTimer = math.max(0, self.fireTimer - self.dt)
	
	--Using primary fire will now fire projectiles, instead of swinging the weapon
	if self.fireMode == "primary"
	  and self.fireTimer == 0
	  and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
		
		--Calculate fire parameters
		local aim = self.weapon.aimAngle + util.randomInRange({-self.inaccuracy, self.inaccuracy})
		
		
		if status.overConsumeResource("energy", self:energyPerShot()) then
		  --Fire the projectile and play effects
		  world.spawnProjectile(self.projectileType, self:firePosition(), activeItem.ownerEntityId(), {mcontroller.facingDirection() * math.cos(aim), math.sin(aim)}, false, params)
		
		  animator.setAnimationState("muzzleflash", "fire")
		  animator.playSound("gunfire")
		  animator.setLightActive("muzzleFlash", true)
		
		  --Code for weapon recoil
		  self.weapon:setStance(self.stances.gunfire)
		
		  local progress = 0
		  util.wait(self.stances.gunfire.duration, function()
			local from = self.stances.gunfire.weaponOffset or {0,0}
			local to = self.stances.aiming.weaponOffset or {0,0}
			self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

			self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.gunfire.weaponRotation, self.stances.aiming.weaponRotation))
			self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.gunfire.armRotation, self.stances.aiming.armRotation))

			progress = math.min(1.0, progress + (self.dt / self.stances.gunfire.duration))
		  end)
		
		  --Reset fire time
		  self.fireTimer = self.fireTime
		end
	end
	
	--Using alt fire again will revert the gun to sword mode
	if self.fireMode == "alt" and self.cooldownTimer == 0 then
	  self:setState(self.revert)
	end
	
	coroutine.yield()
  end
  
  --If we run out of energy, revert to sword
  self:setState(self.revert)
end

function TheaLegionGun:revert()
  self.weapon:setStance(self.stances.transforming)
  self.weapon:updateAim()
	
  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  animator.setAnimationState("weapon", "transformToSword")
  animator.playSound("transform")

  util.wait(self.stances.transforming.duration)
  
  self.transformed = false
  self.cooldownTimer = self.cooldownTime
end

function TheaLegionGun:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end

function TheaLegionGun:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function TheaLegionGun:reset()
  animator.setAnimationState("weapon", "sword")
  self.transformed = false
end

function TheaLegionGun:uninit()
  self:reset()
end
