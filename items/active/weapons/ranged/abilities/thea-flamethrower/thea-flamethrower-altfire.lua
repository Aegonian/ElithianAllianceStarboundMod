require "/items/active/weapons/ranged/gunfire.lua"

TheaFlamethrowerAltfire = GunFire:new()

function TheaFlamethrowerAltfire:init()
  GunFire.init(self)

  self.active = false
end

function TheaFlamethrowerAltfire:update(dt, fireMode, shiftHeld)
  GunFire.update(self, dt, fireMode, shiftHeld)
  
  if self.weapon.currentAbility == self then
    if not self.active then self:activate() end
  elseif self.active then
    self:deactivate()
  end
end

function TheaFlamethrowerAltfire:muzzleFlash()
  --disable normal muzzle flash
end

function TheaFlamethrowerAltfire:activate()
  self.active = true
  animator.playSound("fireStartAlt")
  animator.playSound("fireLoopAlt", -1)
  
  if self.muzzleParticles then
	animator.setParticleEmitterActive("muzzleFlash", true)
  end
end

function TheaFlamethrowerAltfire:deactivate()
  self.active = false
  animator.stopAllSounds("fireStartAlt")
  animator.stopAllSounds("fireLoopAlt")
  animator.playSound("fireEndAlt")
  if self.muzzleParticles then
	animator.setParticleEmitterActive("muzzleFlash", false)
  end
end

function TheaFlamethrowerAltfire:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
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
        self.trackSourceEntity or false,
        params
      )
  end
  return projectileId
end
