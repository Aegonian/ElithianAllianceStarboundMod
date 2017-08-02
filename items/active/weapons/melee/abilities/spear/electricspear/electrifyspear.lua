-- Melee primary ability
ElectrifySpear = WeaponAbility:new()

function ElectrifySpear:init()
  self.cooldownTimer = self.cooldownTime

  self.active = false
end

function ElectrifySpear:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.active and not status.overConsumeResource("energy", self.energyPerSecond * self.dt) then
    self.active = false
  end

  if fireMode == "alt"
      and not self.weapon.currentAbility
      and self.cooldownTimer == 0
      and not status.resourceLocked("energy")
	  and self.active == false then

	  self:setState(self.electrify)
  end
  
  if fireMode == "alt"
      and not self.weapon.currentAbility
      and self.cooldownTimer == 0
      and not status.resourceLocked("energy")
	  and self.active == true then

	  self:setState(self.deactivate)
  end
end

function ElectrifySpear:electrify()
  self.cooldownTimer = self.cooldownTime

  --Force the aim angle into a set position
  self.weapon.aimAngle = 0
  
  self.weapon:setStance(self.stances.electrify)

  animator.playSound("electrify")
  animator.setAnimationState("swoosh", "electrify")
  util.wait(self.stances.electrify.duration)
  
  self.active = true
end

function ElectrifySpear:deactivate()
  self.cooldownTimer = self.cooldownTime
  
  animator.playSound("deactivate")
  self.active = false
end

function ElectrifySpear:uninit()
  
end
