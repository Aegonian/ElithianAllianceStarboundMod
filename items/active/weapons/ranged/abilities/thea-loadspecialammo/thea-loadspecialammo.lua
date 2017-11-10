TheaLoadSpecialAmmo = WeaponAbility:new()

--Basic summary - TO-DO

function TheaLoadSpecialAmmo:init()
  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
  
  animator.setParticleEmitterActive("ammoIndicator", false)
  self.ammoWasLoaded = false
end

function TheaLoadSpecialAmmo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) then
    self:setState(self.loadAmmo)
  end
end

function TheaLoadSpecialAmmo:loadAmmo()
  if not self.defaultAbility then
	self.defaultAbility = self:backupAbility()
  end
  
  if not self.ammoWasLoaded then
	self:adaptAbility()
	
	animator.playSound("loadAmmo")
	animator.setParticleEmitterActive("ammoIndicator", true)

	self.weapon:setStance(self.stances.load)
	util.wait(self.stances.load.duration)
	
	self.ammoWasLoaded = true
  else
	self:resetAbility()
	
	animator.playSound("loadAmmo")
	animator.setParticleEmitterActive("ammoIndicator", false)

	self.weapon:setStance(self.stances.load)
	util.wait(self.stances.load.duration)
	
	self.ammoWasLoaded = false
  end
end

function TheaLoadSpecialAmmo:backupAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  local backup = {}
  
  backup.projectileType = ability.projectileType
  --backup.projectileParameters = ability.projectileParameters //Disabled because parameters would transfer into the primary ability, even after resetting. Use custom projectiles instead!
  backup.projectileCount = ability.projectileCount
  backup.baseDps = ability.baseDps
  backup.fireType = ability.fireType
  backup.burstTime = ability.burstTime
  backup.burstCount = ability.burstCount
  backup.fireTime = ability.fireTime
  backup.energyUsage = ability.energyUsage
  backup.inaccuracy = ability.inaccuracy
  
  return backup
end

function TheaLoadSpecialAmmo:adaptAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  local newAbility = {}
  
  --Check which stats should be updated, then add those to newAbility
  if self.adaptedStats.projectileType then
	newAbility.projectileType = self.specialAbility.projectileType
  end
  --if self.adaptedStats.projectileParameters then
	--newAbility.projectileParameters = self.specialAbility.projectileParameters
  --end
  if self.adaptedStats.projectileCount then
	newAbility.projectileCount = self.specialAbility.projectileCount
  end
  if self.adaptedStats.baseDps then
	newAbility.baseDps = self.specialAbility.baseDps
  end
  if self.adaptedStats.fireType then
	newAbility.fireType = self.specialAbility.fireType
  end
  if self.adaptedStats.burstTime then
	newAbility.burstTime = self.specialAbility.burstTime
  end
  if self.adaptedStats.burstCount then
	newAbility.burstCount = self.specialAbility.burstCount
  end
  if self.adaptedStats.fireTime then
	newAbility.fireTime = self.specialAbility.fireTime
  elseif self.adaptedStats.fireTimeMin then --Instead of setting a hard fire time, this offers the option to set a minimum fire time. Useful for 'spammy' ammo types which create lots of explosions or particles
	newAbility.fireTime = math.max(self.specialAbility.fireTimeMin, ability.fireTime)
  end
  if self.adaptedStats.energyUsage then
	newAbility.energyUsage = self.specialAbility.energyUsage
  end
  if self.adaptedStats.inaccuracy then
	newAbility.inaccuracy = self.specialAbility.inaccuracy
  end
  
  util.mergeTable(ability, newAbility)
end

function TheaLoadSpecialAmmo:resetAbility()
  local ability = self.weapon.abilities[self.adaptedAbilityIndex]
  util.mergeTable(ability, self.defaultAbility)
end

function TheaLoadSpecialAmmo:uninit()
end
