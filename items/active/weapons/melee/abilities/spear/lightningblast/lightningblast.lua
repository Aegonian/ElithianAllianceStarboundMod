require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

LightningBlast = WeaponAbility:new()

function LightningBlast:init()
  self:reset()
end

function LightningBlast:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.weapon.currentAbility == nil and self.fireMode == (self.activatingFireMode or self.abilitySlot) and not status.resourceLocked("energy") then
    self:setState(self.charge)
  end
end

function LightningBlast:charge()
  self.weapon:setStance(self.stances.charge)
  self.weapon:updateAim()
  
  local chargeTimer = 0
  while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy", self.energyUsage * self.dt) do
    chargeTimer = math.min(self.minChargeTime, chargeTimer + self.dt)
	
	world.debugText(chargeTimer, mcontroller.position(), "red")
	
	if chargeTimer < self.minChargeTime then
	  animator.setAnimationState("swoosh", "charging")
	  if self.chargeSoundIsPlaying == false then
		animator.playSound("chargeLoop", -1)
		self.chargeSoundIsPlaying = true
	  end
	elseif chargeTimer >= self.minChargeTime then
	  animator.setAnimationState("swoosh", "arcing")
	  animator.stopAllSounds("chargeLoop")
	  if self.arcSoundIsPlaying == false then
		animator.playSound("arcLoop", -1)
		self.arcSoundIsPlaying = true
	  end
	end
	
    coroutine.yield()
  end

  animator.stopAllSounds("chargeLoop")
  animator.stopAllSounds("arcLoop")
  
  if chargeTimer == self.minChargeTime then
    self:setState(self.blast)
  end
end

function LightningBlast:blast()
  self.weapon:setStance(self.stances.blast)
  self.weapon:updateAim()

  animator.setAnimationState("swoosh", "blast")
  animator.playSound("blast")

  util.wait(self.stances.blast.duration, function()
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.damageConfig, damageArea)
  end)
end

function LightningBlast:reset()
  animator.setAnimationState("swoosh", "idle")
  animator.stopAllSounds("chargeLoop")
  animator.stopAllSounds("arcLoop")
  self.chargeSoundIsPlaying = false
  self.arcSoundIsPlaying = false
end

function LightningBlast:uninit()
  self:reset()
end
