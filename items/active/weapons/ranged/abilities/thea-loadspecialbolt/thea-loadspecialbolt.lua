TheaLoadSpecialBolt = WeaponAbility:new()

function TheaLoadSpecialBolt:init()
  self.cooldownTimer = 0
  self.boltLoaded = false
  
  animator.setAnimationState("specialBolt", "hidden")
  animator.setParticleEmitterActive("specialBolt", false)
end

function TheaLoadSpecialBolt:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  
  --Briefly disable the particle effect if the arrow is loosed
  if self.boltLoaded and animator.animationState("bow") == "loosed" then
	animator.setParticleEmitterActive("specialBolt", false)
  elseif self.boltLoaded then
	animator.setParticleEmitterActive("specialBolt", true)
  end
  
  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 then
    self:setState(self.loadBolt)
  end
end

function TheaLoadSpecialBolt:loadBolt()
  if not self.defaultAbility then
	self.defaultAbility = self:backupAbility()
  end
  
  if not self.boltLoaded then
	self:adaptAbility()
	
	self.weapon:setStance(self.stances.unload)
	animator.setAnimationState("bow", "fire")
	util.wait(self.stances.unload.duration)
	animator.setAnimationState("bow", "idle")
	
	animator.playSound("loadBolt")
	animator.setAnimationState("specialBolt", "visible")
	animator.setParticleEmitterActive("specialBolt", true)

	self.weapon:setStance(self.stances.load)
	util.wait(self.stances.load.duration)
	
	self.cooldownTimer = self.cooldownTime
	self.boltLoaded = true
  else
	self:resetAbility()
	
	self.weapon:setStance(self.stances.unload)
	animator.setAnimationState("bow", "fire")
	util.wait(self.stances.unload.duration)
	animator.setAnimationState("bow", "idle")
	
	animator.playSound("loadBolt")
	animator.setAnimationState("specialBolt", "hidden")
	animator.setParticleEmitterActive("specialBolt", false)

	self.weapon:setStance(self.stances.load)
	util.wait(self.stances.load.duration)
	
	self.cooldownTimer = self.cooldownTime
	self.boltLoaded = false
  end
end

function TheaLoadSpecialBolt:backupAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  local backup = {}
  
  backup.projectileType = ability.projectileType
  backup.powerProjectileType = ability.powerProjectileType
  backup.projectileCount = ability.projectileCount
  backup.baseDamage = ability.baseDamage
  backup.baseEnergyUsage = ability.baseEnergyUsage
  backup.inaccuracy = ability.inaccuracy
  backup.cooldownTime = ability.cooldownTime
  
  return backup
end

function TheaLoadSpecialBolt:adaptAbility()
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
  if self.adaptedStats.baseDamage then
	newAbility.baseDamage = self.specialAbility.baseDamage
  end
  if self.adaptedStats.baseEnergyUsage then
	newAbility.baseEnergyUsage = self.specialAbility.baseEnergyUsage
  end
  if self.adaptedStats.inaccuracy then
	newAbility.inaccuracy = self.specialAbility.inaccuracy
  end
  if self.adaptedStats.cooldownTime then
	newAbility.cooldownTime = self.specialAbility.cooldownTime
  end
  
  util.mergeTable(ability, newAbility)
end

function TheaLoadSpecialBolt:resetAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  util.mergeTable(ability, self.defaultAbility)
end

function TheaLoadSpecialBolt:uninit()
end
