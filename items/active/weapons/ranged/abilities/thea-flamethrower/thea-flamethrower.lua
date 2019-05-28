require "/items/active/weapons/ranged/gunfire.lua"

TheaFlamethrowerAttack = GunFire:new()

function TheaFlamethrowerAttack:init()
  GunFire.init(self)

  self.active = false
end

function TheaFlamethrowerAttack:update(dt, fireMode, shiftHeld)
  GunFire.update(self, dt, fireMode, shiftHeld)

  if self.weapon.currentAbility == self then
    if not self.active then self:activate() end
  elseif self.active then
    self:deactivate()
  end
end

function TheaFlamethrowerAttack:muzzleFlash()
  --disable normal muzzle flash
end

function TheaFlamethrowerAttack:activate()
  self.active = true
  --animator.playSound("fireStart")
  animator.playSound("fireLoop", -1)
end

function TheaFlamethrowerAttack:deactivate()
  self.active = false
  --animator.stopAllSounds("fireStart")
  animator.stopAllSounds("fireLoop")
  --animator.playSound("fireEnd")
end

function TheaFlamethrowerAttack:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
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
