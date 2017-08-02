-- Melee primary ability
TheaSuicideBomb = WeaponAbility:new()

function TheaSuicideBomb:init()
  self.hasExploded = false
  self.soundIsPlaying = false

  self.weapon:setStance(self.stances.idle)

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function TheaSuicideBomb:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.soundIsPlaying == false then
	animator.playSound("loop", -1)
	self.soundIsPlaying = true
  end
  
  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) then
    self:setState(self.activate)
  end
end

-- Activate the bomb, check whter or not it has exploded already
function TheaSuicideBomb:activate()
  self.weapon:setStance(self.stances.activate)
  self.weapon:updateAim()

  if self.hasExploded == false then
	util.wait(self.stances.activate.duration)

	self:setState(self.explode)
  end
end

-- Make the weapon explode
function TheaSuicideBomb:explode()
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self.baseDamage * activeItem.ownerPowerMultiplier()
  
  world.spawnProjectile(
	self.projectileType,
	self:firePosition(),
	activeItem.ownerEntityId(),
	{0, 0},
	false,
	params
  )
  
  self.hasExploded = true
  
  status.setResource("health", 0)
end

function TheaSuicideBomb:uninit()
  if self.hasExploded == false then
	local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
	params.power = self.baseDamage * activeItem.ownerPowerMultiplier()
  
	world.spawnProjectile(
	  self.projectileType,
	  self:firePosition(),
	  activeItem.ownerEntityId(),
	  {0, 0},
	  false,
	  params
	)
  
	self.hasExploded = true
	
	status.setResource("health", 0)
  end
end

function TheaSuicideBomb:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition())
end
