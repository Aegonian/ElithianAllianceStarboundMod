require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/interp.lua"
require "/items/active/weapons/weapon.lua"
require "/items/active/weapons/ranged/gunfire.lua"

function init()
  self.cursor = item.instanceValue("cursor")
  --self.cursorCharging = item.instanceValue("cursorCharging")
  
  if (self.cursor) then
    activeItem.setCursor(self.cursor)
  else
    activeItem.setCursor("/cursors/reticle0.cursor")
  end
  
  animator.setGlobalTag("paletteSwaps", item.instanceValue("paletteSwaps", ""))

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, 0)
  self.weapon:addTransformationGroup("muzzle", self.weapon.muzzleOffset, 0)

  local primaryAttack = setupPrimaryAttack()
  self.weapon:addAbility(primaryAttack)

  local secondaryAttack = getAltAbility(self.weapon.elementalType)
  if secondaryAttack then
    self.weapon:addAbility(secondaryAttack)
  end
  
  self.weapon:init()
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)
end

function uninit()
  self.weapon:uninit()
end

function setupPrimaryAttack()
  local flamethrowerAttack = GunFire:new(item.instanceValue("primaryAttack"), item.instanceValue("stances"))

  function flamethrowerAttack:init()
    GunFire.init(self)

    self.active = false
  end

  function flamethrowerAttack:update(dt, fireMode, shiftHeld)
    GunFire.update(self, dt, fireMode, shiftHeld)

    if self.weapon.currentAbility == self then
      if not self.active then self:activate() end
    elseif self.active then
      self:deactivate()
    end
  end

  function flamethrowerAttack:muzzleFlash()
    --disable normal muzzle flash
  end

  function flamethrowerAttack:activate()
    self.active = true
    animator.playSound("fireStart")
    animator.playSound("fireLoop", -1)
  end

  function flamethrowerAttack:deactivate()
    self.active = false
    animator.stopAllSounds("fireStart")
    animator.stopAllSounds("fireLoop")
    animator.playSound("fireEnd")
  end

  return flamethrowerAttack
end
