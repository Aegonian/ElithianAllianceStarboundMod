TheaNockSpecialArrow = WeaponAbility:new()

function TheaNockSpecialArrow:init()
  self.cooldownTimer = 0
  self.arrowNocked = false
  
  animator.setAnimationState("specialArrow", "hidden")
  animator.setParticleEmitterActive("specialArrow", false)
end

function TheaNockSpecialArrow:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  --Briefly disable the particle effect if the arrow is loosed
  if self.arrowNocked and animator.animationState("bow") == "loosed" then
	animator.setParticleEmitterActive("specialArrow", false)
  elseif self.arrowNocked then
	animator.setParticleEmitterActive("specialArrow", true)
  end
  
  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 then
    self:setState(self.nockArrow)
  end
end

function TheaNockSpecialArrow:nockArrow()
  if not self.defaultAbility then
	self.defaultAbility = self:backupAbility()
  end
  
  if not self.arrowNocked then
	self:adaptAbility()
	
	self.weapon:setStance(self.stances.unnock)
	animator.setAnimationState("bow", "loosed")
	util.wait(self.stances.unnock.duration)
	animator.setAnimationState("bow", "idle")
	
	animator.playSound("nockArrow")
	animator.setAnimationState("specialArrow", "visible")
	animator.setParticleEmitterActive("specialArrow", true)

	self.weapon:setStance(self.stances.nock)
	util.wait(self.stances.nock.duration)
	
	self.cooldownTimer = self.cooldownTime
	self.arrowNocked = true
  else
	self:resetAbility()
	
	self.weapon:setStance(self.stances.unnock)
	animator.setAnimationState("bow", "loosed")
	util.wait(self.stances.unnock.duration)
	animator.setAnimationState("bow", "idle")
	
	animator.playSound("nockArrow")
	animator.setAnimationState("specialArrow", "hidden")
	animator.setParticleEmitterActive("specialArrow", false)

	self.weapon:setStance(self.stances.nock)
	util.wait(self.stances.nock.duration)
	
	self.cooldownTimer = self.cooldownTime
	self.arrowNocked = false
  end
end

function TheaNockSpecialArrow:backupAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  local backup = {}
  
  backup.projectileType = ability.projectileType
  backup.powerProjectileType = ability.powerProjectileType
  backup.projectileCount = ability.projectileCount
  backup.drawTime = ability.drawTime
  backup.energyPerShot = ability.energyPerShot
  backup.holdEnergyUsage = ability.holdEnergyUsage
  backup.inaccuracy = ability.inaccuracy
  backup.staticDamageMultiplier = ability.staticDamageMultiplier
  backup.dynamicDamageMultiplier = ability.dynamicDamageMultiplier
  
  return backup
end

function TheaNockSpecialArrow:adaptAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  local newAbility = {}
  
  --Check which stats should be updated, then add those to newAbility
  if self.adaptedStats.projectileType then
	newAbility.projectileType = self.specialAbility.projectileType
  end
  if self.adaptedStats.powerProjectileType then
	newAbility.powerProjectileType = self.specialAbility.powerProjectileType
  end
  if self.adaptedStats.projectileCount then
	newAbility.projectileCount = self.specialAbility.projectileCount
  end
  if self.adaptedStats.drawTime then
	newAbility.drawTime = self.specialAbility.drawTime
  end
  if self.adaptedStats.energyPerShot then
	newAbility.energyPerShot = self.specialAbility.energyPerShot
  end
  if self.adaptedStats.holdEnergyUsage then
	newAbility.holdEnergyUsage = self.specialAbility.holdEnergyUsage
  end
  if self.adaptedStats.inaccuracy then
	newAbility.inaccuracy = self.specialAbility.inaccuracy
  end
  if self.adaptedStats.staticDamageMultiplier then
	newAbility.staticDamageMultiplier = self.specialAbility.staticDamageMultiplier
  end
  if self.adaptedStats.dynamicDamageMultiplier then
	newAbility.dynamicDamageMultiplier = self.specialAbility.dynamicDamageMultiplier
  end
  
  util.mergeTable(ability, newAbility)
end

function TheaNockSpecialArrow:resetAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  util.mergeTable(ability, self.defaultAbility)
end

function TheaNockSpecialArrow:uninit()
end
