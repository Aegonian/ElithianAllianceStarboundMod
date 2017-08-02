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
